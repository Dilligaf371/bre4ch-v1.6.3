// ── Event Feed Provider ──────────────────────────────────────────
// WebSocket-first with HTTP polling fallback.
// WS: subscribes to 'event' + 'headlines' channels.
// HTTP: polls HeadlinesService + LiveUAMap when WS is disconnected.
// Persistence: 60-day local cache via SharedPreferences.

// MED-04 FIX: Content-hash deduplication (SHA-256 of title+source+date).

import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/attack_event.dart';
import '../services/headlines_service.dart';
import '../services/liveuamap_service.dart';
import '../services/breach_socket_service.dart';
import '../config/api.dart';

// ── Persistence constants ────────────────────────────────────────
const String _eventCacheKey = 'event_cache_v1';
/// Retention covers from the start of the conflict (Oct 2023) to present.
/// Using 600 days to ensure all historical data is preserved.
const int _eventRetentionDays = 600;
const int _maxCachedEvents = 10000;

// ── Source URL mapping ───────────────────────────────────────────

const Map<String, Map<String, String>> _sourceUrls = {
  'CENTCOM':    {'name': 'CENTCOM',    'url': 'https://www.centcom.mil'},
  'Reuters':    {'name': 'Reuters',    'url': 'https://www.reuters.com/world/middle-east/'},
  'Al Jazeera': {'name': 'Al Jazeera', 'url': 'https://www.aljazeera.com/tag/iran/'},
  'AP':         {'name': 'AP News',    'url': 'https://apnews.com/hub/iran'},
  'IDF':        {'name': 'IDF',        'url': 'https://www.idf.il'},
  'DoD':        {'name': 'DoD',        'url': 'https://www.defense.gov'},
  'BBC':        {'name': 'BBC',        'url': 'https://www.bbc.com/news/world/middle_east'},
  // X (Twitter) — official gov accounts
  '@modgovae':      {'name': 'MOD UAE 🇦🇪',     'url': 'https://x.com/modgovae'},
  '@ABORON_uae':    {'name': 'MOI UAE 🇦🇪',     'url': 'https://x.com/ABORON_uae'},
  '@ABORON_ncema':  {'name': 'NCEMA 🇦🇪',       'url': 'https://x.com/ABORON_ncema'},
  '@WAaboron':      {'name': 'WAM 🇦🇪',         'url': 'https://x.com/WAaboron'},
  '@MoFAICaboron':  {'name': 'MoFA UAE 🇦🇪',    'url': 'https://x.com/MoFAICaboron'},
  // X — KSA
  '@modaboron':     {'name': 'MOD KSA 🇸🇦',     'url': 'https://x.com/modaboron'},
  '@SPaboron':      {'name': 'SPA 🇸🇦',         'url': 'https://x.com/SPaboron'},
  // X — OSINT accounts
  '@Aboron_Intel':  {'name': 'Intel OSINT',     'url': 'https://x.com/Conflicts'},
  // Instagram — official gov accounts
  'ncaboron':       {'name': 'NCEMA IG 🇦🇪',    'url': 'https://instagram.com/ncaboron'},
  'moiuae':         {'name': 'MOI IG 🇦🇪',      'url': 'https://instagram.com/moiuae'},
  'modgovae_ig':    {'name': 'MOD IG 🇦🇪',      'url': 'https://instagram.com/modgovae'},
  'maboron_uae':    {'name': 'MoFA IG 🇦🇪',     'url': 'https://instagram.com/maboron_uae'},
};

// ── Conflict keyword filter ──────────────────────────────────────

const List<String> _conflictKeywords = [
  'iran', 'israel', 'military', 'strike', 'missile', 'kill', 'attack', 'war',
  'drone', 'bomb', 'nuclear', 'hezbollah', 'gaza', 'gulf', 'navy', 'air force',
  'centcom', 'intercept', 'defense', 'defence', 'houthi', 'yemen', 'lebanon',
  // UAE / GCC specific
  'uae', 'emirates', 'dubai', 'abu dhabi', 'sharjah', 'bahrain', 'qatar',
  'kuwait', 'saudi', 'ksa', 'oman', 'muscat', 'doha', 'manama', 'riyadh',
  // Coalition / Axis
  'coalition', 'nato', 'pentagon', 'pmf', 'irgc', 'quds',
  // Arabic conflict terms
  'هجوم', 'صاروخ', 'طائرة مسيرة', 'ضربة', 'قتل', 'حرب', 'إجلاء',
  'دفاع', 'اعتراض', 'نووي',
  // Official source keywords (to catch MOI/MOD/MOFA announcements)
  'ministry of defense', 'ministry of interior', 'foreign affairs',
  'وزارة الدفاع', 'وزارة الداخلية', 'وزارة الخارجية',
];

// ── Target region detection ─────────────────────────────────────

String _detectTargetRegion(String text) {
  final lower = text.toLowerCase();
  if (lower.contains('uae') || lower.contains('dubai') || lower.contains('abu dhabi') ||
      lower.contains('sharjah') || lower.contains('emirates') || lower.contains('الإمارات') ||
      lower.contains('دبي')) return 'UAE';
  if (lower.contains('iran') || lower.contains('tehran') || lower.contains('isfahan')) return 'Iran';
  if (lower.contains('israel') || lower.contains('tel aviv') || lower.contains('jerusalem')) return 'Israel';
  if (lower.contains('saudi') || lower.contains('riyadh') || lower.contains('jeddah') ||
      lower.contains('ksa')) return 'KSA';
  if (lower.contains('kuwait')) return 'Kuwait';
  if (lower.contains('bahrain') || lower.contains('manama')) return 'Bahrain';
  if (lower.contains('qatar') || lower.contains('doha')) return 'Qatar';
  if (lower.contains('oman') || lower.contains('muscat')) return 'Oman';
  if (lower.contains('jordan') || lower.contains('amman')) return 'Jordan';
  if (lower.contains('lebanon') || lower.contains('beirut') || lower.contains('hezbollah')) return 'Lebanon';
  if (lower.contains('iraq') || lower.contains('baghdad') || lower.contains('pmf')) return 'Iraq';
  if (lower.contains('syria') || lower.contains('damascus')) return 'Syria';
  if (lower.contains('yemen') || lower.contains('houthi') || lower.contains('sanaa')) return 'Yemen';
  if (lower.contains('centcom') || lower.contains('pentagon') || lower.contains('washington')) return 'USA';
  if (lower.contains('britain') || lower.contains('uk ')) return 'UK';
  if (lower.contains('france') || lower.contains('french')) return 'France';
  return 'Iran Theater';
}

final _rng = Random();

String _randomId(String prefix) {
  final ts = DateTime.now().millisecondsSinceEpoch;
  final r = _rng.nextInt(0xFFFF).toRadixString(36);
  return '$prefix-$ts-$r';
}

/// MED-04: Content-based hash for deduplication (title + source + date).
String _contentHash(String title, String source, String date) {
  final input = '$title|$source|$date';
  return sha256.convert(utf8.encode(input)).toString().substring(0, 16);
}

// ── Convert live headline to AttackEvent ─────────────────────────

AttackEvent _liveHeadlineToEvent(Map<String, dynamic> h) {
  final title = h['title'] as String? ?? '';
  final src = h['source'] as String? ?? '';
  final pubDate = h['pubDate'] as String? ?? '';
  final link = h['link'] as String? ?? '';

  final lower = title.toLowerCase();

  AttackType type = AttackType.cruise;
  if (lower.contains('drone') || lower.contains('uav')) {
    type = AttackType.drone;
  } else if (lower.contains('missile') || lower.contains('ballistic') || lower.contains('rocket')) {
    type = AttackType.ballistic;
  } else if (lower.contains('cyber') || lower.contains('hack')) {
    type = AttackType.cyber;
  } else if (lower.contains('artillery') || lower.contains('shell')) {
    type = AttackType.artillery;
  } else if (lower.contains('sabotage') || lower.contains('explosion')) {
    type = AttackType.sabotage;
  }

  EventStatus status = EventStatus.ongoing;
  if (lower.contains('intercept') || lower.contains('shot down') || lower.contains('defended')) {
    status = EventStatus.intercepted;
  } else if (lower.contains('hit') || lower.contains('struck') || lower.contains('killed') || lower.contains('destroyed')) {
    status = EventStatus.impact;
  } else if (lower.contains('neutraliz')) {
    status = EventStatus.neutralized;
  }

  final srcInfo = _sourceUrls[src] ?? {'name': src, 'url': ''};

  int ts = DateTime.now().millisecondsSinceEpoch;
  if (pubDate.isNotEmpty) {
    final parsed = DateTime.tryParse(pubDate);
    if (parsed != null) ts = parsed.millisecondsSinceEpoch;
  }

  return AttackEvent(
    id: _randomId('live-evt'),
    timestamp: ts,
    type: type,
    origin: src,
    target: _detectTargetRegion(title),
    status: status,
    details: title,
    source: srcInfo['name'],
    sourceUrl: link.isNotEmpty ? link : srcInfo['url'],
  );
}

// ── Convert LiveUAMap event to AttackEvent ───────────────────────

AttackEvent _liveuamapToEvent(Map<String, dynamic> e) {
  final name = e['name'] as String? ?? '';
  final source = e['source'] as String? ?? 'LiveUAMap';
  final url = e['url'] as String? ?? '';
  final time = e['time'] as int? ?? 0;

  final lower = name.toLowerCase();
  AttackType type = AttackType.cruise;
  if (lower.contains('drone') || lower.contains('uav')) type = AttackType.drone;
  else if (lower.contains('missile') || lower.contains('ballistic')) type = AttackType.ballistic;
  else if (lower.contains('cyber')) type = AttackType.cyber;
  else if (lower.contains('artillery') || lower.contains('rocket')) type = AttackType.artillery;

  EventStatus status = EventStatus.ongoing;
  if (lower.contains('intercept')) status = EventStatus.intercepted;
  else if (lower.contains('hit') || lower.contains('struck') || lower.contains('kill')) status = EventStatus.impact;

  return AttackEvent(
    id: _randomId('uamap'),
    timestamp: time > 0 ? time * 1000 : DateTime.now().millisecondsSinceEpoch,
    type: type,
    origin: source,
    target: e['region'] as String? ?? 'Middle East',
    status: status,
    details: name,
    source: 'LiveUAMap',
    sourceUrl: url,
  );
}

// ── StateNotifier ────────────────────────────────────────────────

class EventFeedNotifier extends StateNotifier<List<AttackEvent>> {
  EventFeedNotifier(this._ref) : super([]) {
    _init();
  }

  final Ref _ref;
  Timer? _headlineTimer;
  Timer? _liveuamapTimer;
  Timer? _persistTimer;
  final Set<String> _injected = {};
  final Set<String> _seenIds = {};
  bool _cacheLoaded = false;

  StreamSubscription? _wsSub;
  StreamSubscription? _wsHeadlinesSub;
  StreamSubscription? _wsInitSub;
  StreamSubscription? _wsConnSub;
  bool _wsActive = false;

  // ── Persistence ──────────────────────────────────────────────────

  Future<void> _loadCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_eventCacheKey);
      if (raw == null || raw.isEmpty) { _cacheLoaded = true; return; }

      final List<dynamic> decoded = jsonDecode(raw);
      final cutoff = DateTime.now().subtract(const Duration(days: _eventRetentionDays)).millisecondsSinceEpoch;

      final cached = <AttackEvent>[];
      for (final item in decoded) {
        try {
          final evt = AttackEvent.fromJson(item as Map<String, dynamic>);
          if (evt.timestamp >= cutoff && _seenIds.add(evt.id)) {
            _injected.add(_contentHash(evt.details, evt.source ?? '', ''));
            cached.add(evt);
          }
        } catch (_) {}
      }

      if (cached.isNotEmpty && mounted) {
        cached.sort((a, b) => b.timestamp.compareTo(a.timestamp));
        state = cached.take(_maxCachedEvents).toList();
      }
      _cacheLoaded = true;
    } catch (_) {
      _cacheLoaded = true;
    }
  }

  Future<void> _saveCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cutoff = DateTime.now().subtract(const Duration(days: _eventRetentionDays)).millisecondsSinceEpoch;
      final toSave = state.where((e) => e.timestamp >= cutoff).take(_maxCachedEvents).toList();
      final encoded = jsonEncode(toSave.map((e) => e.toJson()).toList());
      await prefs.setString(_eventCacheKey, encoded);
    } catch (_) {}
  }

  void _scheduleSave() {
    _persistTimer?.cancel();
    _persistTimer = Timer(const Duration(seconds: 5), _saveCache);
  }

  // ── Merge helper (deduped + sorted + pruned) ─────────────────────

  void _mergeAndUpdate(List<AttackEvent> newItems) {
    if (newItems.isEmpty) return;
    final cutoff = DateTime.now().subtract(const Duration(days: _eventRetentionDays)).millisecondsSinceEpoch;
    final merged = [...newItems, ...state];
    merged.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    state = merged.where((e) => e.timestamp >= cutoff).take(_maxCachedEvents).toList();
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

    // ── Connection state: toggle HTTP polling fallback ──────────
    _wsConnSub = ws.connectionStream.listen((connected) {
      _wsActive = connected;
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
      final l = (map['title'] as String? ?? '').toLowerCase();
      return _conflictKeywords.any((kw) => l.contains(kw));
    }).toList();

    final newOnes = relevant.where((h) {
      final map = h as Map<String, dynamic>;
      final title = map['title'] as String? ?? '';
      final source = map['source'] as String? ?? '';
      final date = map['pubDate'] as String? ?? '';
      final hash = _contentHash(title, source, date);
      return title.isNotEmpty && !_injected.contains(hash);
    }).toList();
    if (newOnes.isEmpty) return;

    final events = newOnes.map((h) => _liveHeadlineToEvent(h as Map<String, dynamic>)).toList();
    for (final h in newOnes) {
      final map = h as Map<String, dynamic>;
      _injected.add(_contentHash(
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
        final l = (h['title'] as String? ?? '').toLowerCase();
        return _conflictKeywords.any((kw) => l.contains(kw));
      }).toList();

      final newOnes = relevant.where((h) {
        final title = h['title'] as String? ?? '';
        final source = h['source'] as String? ?? '';
        final date = h['pubDate'] as String? ?? '';
        final hash = _contentHash(title, source, date);
        return title.isNotEmpty && !_injected.contains(hash);
      }).toList();
      if (newOnes.isEmpty) return;

      final events = newOnes.map(_liveHeadlineToEvent).toList();
      for (final h in newOnes) {
        _injected.add(_contentHash(
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
        final hash = _contentHash(name, source, '');
        return name.isNotEmpty && !_injected.contains(hash);
      }).toList();
      if (newOnes.isEmpty) return;

      final attackEvents = newOnes.map(_liveuamapToEvent).toList();
      for (final e in newOnes) {
        _injected.add(_contentHash(
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
      _injected.add(_contentHash(evt.details, evt.source ?? '', ''));
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
