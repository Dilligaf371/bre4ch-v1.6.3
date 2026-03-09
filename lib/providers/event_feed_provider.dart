// ── Event Feed Provider ──────────────────────────────────────────
// WebSocket-first with HTTP polling fallback.
// WS: subscribes to 'event' + 'headlines' channels.
// HTTP: polls HeadlinesService + LiveUAMap when WS is disconnected.
// Persistence: 60-day local cache via SharedPreferences.

// MED-04 FIX: Content-hash deduplication (SHA-256 of title+source+date).

import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/attack_event.dart';
import '../services/headlines_service.dart';
import '../services/liveuamap_service.dart';
import '../services/breach_socket_service.dart';
import '../config/api.dart';
import '../utils/event_feed_helpers.dart';

// ── StateNotifier ────────────────────────────────────────────────

class EventFeedNotifier extends StateNotifier<List<AttackEvent>> {
  EventFeedNotifier(Ref ref) : super([]) {
    _init();
  }

  Timer? _headlineTimer;
  Timer? _liveuamapTimer;
  Timer? _persistTimer;
  final Set<String> _injected = {};
  final Set<String> _seenIds = {};
  StreamSubscription? _wsSub;
  StreamSubscription? _wsHeadlinesSub;
  StreamSubscription? _wsSocmintSub;
  StreamSubscription? _wsInitSub;
  StreamSubscription? _wsConnSub;
  // ── Persistence ──────────────────────────────────────────────────

  Future<void> _loadCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(eventCacheKey);
      if (raw == null || raw.isEmpty) { return; }

      final List<dynamic> decoded = jsonDecode(raw);
      final cutoff = DateTime.now().subtract(const Duration(days: eventRetentionDays)).millisecondsSinceEpoch;

      final cached = <AttackEvent>[];
      for (final item in decoded) {
        try {
          final evt = AttackEvent.fromJson(item as Map<String, dynamic>);
          // Hard gate: only load events after mission start
          if (evt.timestamp >= missionStartMs &&
              evt.timestamp >= cutoff &&
              _seenIds.add(evt.id)) {
            _injected.add(contentHash(evt.details, evt.source ?? '', ''));
            cached.add(evt);
          }
        } catch (_) {}
      }

      if (cached.isNotEmpty && mounted) {
        cached.sort((a, b) => b.timestamp.compareTo(a.timestamp));
        state = cached.take(maxCachedEvents).toList();
      }

    } catch (_) {

    }
  }

  Future<void> _saveCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cutoff = DateTime.now().subtract(const Duration(days: eventRetentionDays)).millisecondsSinceEpoch;
      final toSave = state.where((e) => e.timestamp >= cutoff).take(maxCachedEvents).toList();
      final encoded = jsonEncode(toSave.map((e) => e.toJson()).toList());
      await prefs.setString(eventCacheKey, encoded);
    } catch (_) {}
  }

  void _scheduleSave() {
    _persistTimer?.cancel();
    _persistTimer = Timer(const Duration(seconds: 5), _saveCache);
  }

  // ── Merge helper (deduped + sorted + pruned) ─────────────────────

  void _mergeAndUpdate(List<AttackEvent> newItems) {
    if (newItems.isEmpty) return;
    final cutoff = DateTime.now().subtract(const Duration(days: eventRetentionDays)).millisecondsSinceEpoch;
    final merged = [...newItems, ...state];
    merged.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    // Hard gate: only events after mission start AND within retention window
    state = merged
        .where((e) => e.timestamp >= missionStartMs && e.timestamp >= cutoff)
        .take(maxCachedEvents)
        .toList();
    _scheduleSave();
  }

  // ── Init ─────────────────────────────────────────────────────────

  void _init() async {
    await _loadCache();

    final ws = BreachSocketService.instance;

    // ── Subscribe to WS init (seed) ─────────────────────────────
    _wsInitSub = ws.channel(WsMessageType.init).listen((data) {
      if (!mounted) return;
      final json = data as Map<String, dynamic>;
      final events = json['events'] as List<dynamic>?;
      if (events == null || events.isEmpty) return;

      final parsed = events
          .map((e) => AttackEvent.fromJson(e as Map<String, dynamic>))
          .where((e) => _seenIds.add(e.id))
          .toList();
      _mergeAndUpdate(parsed);
    });

    // ── Subscribe to WS live events ─────────────────────────────
    _wsSub = ws.channel(WsMessageType.event).listen((data) {
      if (!mounted) return;
      try {
        final evt = AttackEvent.fromJson(data as Map<String, dynamic>);
        if (!_seenIds.add(evt.id)) return; // dedupe
        _mergeAndUpdate([evt]);
      } catch (_) {}
    });

    // ── Subscribe to WS headlines (real RSS pushed by server) ───
    _wsHeadlinesSub = ws.channel(WsMessageType.headlines).listen((data) {
      if (!mounted) return;
      _processHeadlines(data as List<dynamic>);
    });

    // ── Subscribe to WS socmint (bridge GOV posts -> events) ─────
    _wsSocmintSub = ws.channel(WsMessageType.socmint).listen((data) {
      if (!mounted) return;
      try {
        final evt = socmintGovToEvent(data as Map<String, dynamic>);
        if (evt == null) return;
        final hash = contentHash(evt.details, evt.source ?? '', '');
        if (_injected.contains(hash)) return; // dedupe
        _injected.add(hash);
        _mergeAndUpdate([evt]);
      } catch (_) {}
    });

    // ── Connection state: toggle HTTP polling fallback ──────────
    _wsConnSub = ws.connectionStream.listen((connected) {
      if (connected) {
        _headlineTimer?.cancel();
        _headlineTimer = null;
        _liveuamapTimer?.cancel();
        _liveuamapTimer = null;
      } else {
        _startHttpPolling();
      }
    });

    if (!ws.connected) {
      _startHttpPolling();
    }
  }

  // ── HTTP Polling (fallback) ───────────────────────────────────

  void _startHttpPolling() {
    _fetchLiveEvents();
    _fetchLiveuamapEvents();

    _headlineTimer ??= Timer.periodic(
      const Duration(seconds: 30),
      (_) => _fetchLiveEvents(),
    );

    _liveuamapTimer ??= Timer.periodic(
      PollIntervals.liveuamap,
      (_) => _fetchLiveuamapEvents(),
    );
  }

  void _processHeadlines(List<dynamic> headlines) {
    final relevant = headlines.where((h) {
      final map = h as Map<String, dynamic>;
      final title = (map['title'] as String? ?? '');
      final src = (map['source'] as String? ?? '');
      // Priority sources always pass; others need conflict terms
      return isPrioritySource(src) || isConflictRelevant(title);
    }).toList();

    final newOnes = relevant.where((h) {
      final map = h as Map<String, dynamic>;
      final title = map['title'] as String? ?? '';
      final source = map['source'] as String? ?? '';
      final date = map['pubDate'] as String? ?? '';
      final hash = contentHash(title, source, date);
      return title.isNotEmpty && !_injected.contains(hash);
    }).toList();
    if (newOnes.isEmpty) return;

    final events = newOnes
        .map((h) => liveHeadlineToEvent(h as Map<String, dynamic>))
        .whereType<AttackEvent>() // filter out nulls (pre-war date gate)
        .toList();
    for (final h in newOnes) {
      final map = h as Map<String, dynamic>;
      _injected.add(contentHash(
        map['title'] as String? ?? '',
        map['source'] as String? ?? '',
        map['pubDate'] as String? ?? '',
      ));
    }
    _mergeAndUpdate(events);
  }

  Future<void> _fetchLiveEvents() async {
    try {
      final headlines = await HeadlinesService.instance.fetchHeadlines();
      if (headlines.isEmpty || !mounted) return;

      final relevant = headlines.where((h) {
        final title = (h['title'] as String? ?? '');
        final src = (h['source'] as String? ?? '');
        return isPrioritySource(src) || isConflictRelevant(title);
      }).toList();

      final newOnes = relevant.where((h) {
        final title = h['title'] as String? ?? '';
        final source = h['source'] as String? ?? '';
        final date = h['pubDate'] as String? ?? '';
        final hash = contentHash(title, source, date);
        return title.isNotEmpty && !_injected.contains(hash);
      }).toList();
      if (newOnes.isEmpty) return;

      final events = newOnes
          .map(liveHeadlineToEvent)
          .whereType<AttackEvent>()
          .toList();
      for (final h in newOnes) {
        _injected.add(contentHash(
          h['title'] as String? ?? '',
          h['source'] as String? ?? '',
          h['pubDate'] as String? ?? '',
        ));
      }
      _mergeAndUpdate(events);
    } catch (_) {}
  }

  Future<void> _fetchLiveuamapEvents() async {
    try {
      final events = await LiveuamapService.instance.fetchEvents();
      if (events.isEmpty || !mounted) return;

      final newOnes = events.where((e) {
        final name = e['name'] as String? ?? '';
        final source = e['source'] as String? ?? 'LiveUAMap';
        final hash = contentHash(name, source, '');
        return name.isNotEmpty && !_injected.contains(hash);
      }).toList();
      if (newOnes.isEmpty) return;

      final attackEvents = newOnes.map(liveuamapToEvent).toList();
      for (final e in newOnes) {
        _injected.add(contentHash(
          e['name'] as String? ?? '',
          e['source'] as String? ?? 'LiveUAMap',
          '',
        ));
      }
      _mergeAndUpdate(attackEvents);
    } catch (_) {}
  }

  /// Refresh fetches new data but KEEPS cached items (no data loss).
  Future<void> refresh() async {
    _injected.clear();
    // Re-add existing hashes to avoid duplicates on re-fetch
    for (final evt in state) {
      _injected.add(contentHash(evt.details, evt.source ?? '', ''));
    }
    await Future.wait([_fetchLiveEvents(), _fetchLiveuamapEvents()]);
  }

  @override
  void dispose() {
    _headlineTimer?.cancel();
    _liveuamapTimer?.cancel();
    _persistTimer?.cancel();
    _wsSub?.cancel();
    _wsHeadlinesSub?.cancel();
    _wsSocmintSub?.cancel();
    _wsInitSub?.cancel();
    _wsConnSub?.cancel();
    _saveCache();
    super.dispose();
  }
}

// ── Provider ─────────────────────────────────────────────────────

final eventFeedProvider =
    StateNotifierProvider<EventFeedNotifier, List<AttackEvent>>((ref) {
  return EventFeedNotifier(ref);
});
