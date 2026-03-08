// ── OSINT Feed Provider ──────────────────────────────────────────
// WebSocket-first with HTTP polling fallback.
// WS: subscribes to 'osint' + 'headlines' channels.
// HTTP: polls HeadlinesService + CentcomService when WS is disconnected.
// Persistence: 60-day local cache via SharedPreferences.

import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/osint_item.dart';
import '../services/headlines_service.dart';
import '../services/centcom_service.dart';
import '../services/breach_socket_service.dart';
import '../config/api.dart';

// ── Persistence constants ────────────────────────────────────────
const String _osintCacheKey = 'osint_cache_v2';
/// Only keep J (today) and J-1 (yesterday). Older articles are irrelevant.
const int _retentionDays = 2;
const int _maxCachedItems = 500;

// ── Source config ────────────────────────────────────────────────

const Map<OsintSource, OsintSourceConfig> sourceConfig = {
  OsintSource.reuters:      OsintSourceConfig(label: 'REUTERS',        colorValue: 0xFFFB923C),
  OsintSource.aljazeera:    OsintSourceConfig(label: 'AL JAZEERA',     colorValue: 0xFFFBBF24),
  OsintSource.dod:          OsintSourceConfig(label: 'DOD.GOV',        colorValue: 0xFF60A5FA),
  OsintSource.idf:          OsintSourceConfig(label: 'IDF.IL',         colorValue: 0xFF22D3EE),
  OsintSource.ap:           OsintSourceConfig(label: 'AP NEWS',        colorValue: 0xFF4ADE80),
  OsintSource.centcom:      OsintSourceConfig(label: 'CENTCOM',        colorValue: 0xFFC084FC),
  OsintSource.flightradar:  OsintSourceConfig(label: 'FR24/SIGINT',    colorValue: 0xFFFB7185),
  OsintSource.bloomberg:    OsintSourceConfig(label: 'BLOOMBERG',      colorValue: 0xFF818CF8),
  OsintSource.khaleejtimes: OsintSourceConfig(label: 'KHALEEJ TIMES',  colorValue: 0xFFE879F9),
  OsintSource.thenational:  OsintSourceConfig(label: 'THE NATIONAL',   colorValue: 0xFF34D399),
  OsintSource.gulfnews:     OsintSourceConfig(label: 'GULF NEWS',      colorValue: 0xFF2DD4BF),
  OsintSource.gulftoday:    OsintSourceConfig(label: 'GULF TODAY',     colorValue: 0xFF67E8F9),
  OsintSource.emirates247:  OsintSourceConfig(label: 'EMIRATES 24|7',  colorValue: 0xFFD946EF),
  OsintSource.arabnews:     OsintSourceConfig(label: 'ARAB NEWS',      colorValue: 0xFFA78BFA),
  OsintSource.saudigazette: OsintSourceConfig(label: 'SAUDI GAZETTE',  colorValue: 0xFF38BDF8),
  OsintSource.gulftimes:      OsintSourceConfig(label: 'GULF TIMES',     colorValue: 0xFF5EEAD4),
  OsintSource.peninsulaQatar: OsintSourceConfig(label: 'THE PENINSULA',  colorValue: 0xFFFDA4AF),
  OsintSource.qatarTribune:   OsintSourceConfig(label: 'QATAR TRIBUNE',  colorValue: 0xFFBAE6FD),
  OsintSource.gulfDailyNews:  OsintSourceConfig(label: 'GULF DAILY NEWS', colorValue: 0xFFFDE68A),
  OsintSource.dailyTribuneBh: OsintSourceConfig(label: 'DAILY TRIBUNE',   colorValue: 0xFFBFDBFE),
  OsintSource.timesOfOman:  OsintSourceConfig(label: 'TIMES OF OMAN',  colorValue: 0xFFFECA57),
  OsintSource.omanObserver: OsintSourceConfig(label: 'OMAN OBSERVER',  colorValue: 0xFFA3E635),
  OsintSource.wam:          OsintSourceConfig(label: 'WAM',            colorValue: 0xFFF87171),
  OsintSource.spa:          OsintSourceConfig(label: 'SPA',            colorValue: 0xFF6EE7B7),
  OsintSource.qna:          OsintSourceConfig(label: 'QNA',            colorValue: 0xFFA5B4FC),
  OsintSource.bna:          OsintSourceConfig(label: 'BNA',            colorValue: 0xFFFCD34D),
  OsintSource.kuna:         OsintSourceConfig(label: 'KUNA',           colorValue: 0xFF86EFAC),
  OsintSource.omanNews:     OsintSourceConfig(label: 'ONA',            colorValue: 0xFFFCA5A5),
  OsintSource.timesOfIsrael: OsintSourceConfig(label: 'TIMES OF ISR',  colorValue: 0xFF93C5FD),
  OsintSource.jpost:         OsintSourceConfig(label: 'JPOST',         colorValue: 0xFF7DD3FC),
};

// ── Source map (RSS name -> OsintSource) ─────────────────────────

const Map<String, OsintSource> sourceMap = {
  'CENTCOM': OsintSource.centcom, 'Reuters': OsintSource.reuters,
  'Al Jazeera': OsintSource.aljazeera, 'Al jazeera': OsintSource.aljazeera,
  'AP': OsintSource.ap, 'IDF': OsintSource.idf, 'DoD': OsintSource.dod,
  'BBC': OsintSource.reuters, 'Bbc': OsintSource.reuters,
  'Bloomberg': OsintSource.bloomberg, 'bloomberg': OsintSource.bloomberg,
  'Khaleej Times': OsintSource.khaleejtimes, 'KhaleejTimes': OsintSource.khaleejtimes, 'khaleejtimes': OsintSource.khaleejtimes,
  'The National': OsintSource.thenational, 'thenational': OsintSource.thenational,
  'Gulf News': OsintSource.gulfnews, 'GulfNews': OsintSource.gulfnews, 'gulfnews': OsintSource.gulfnews,
  'Gulf Today': OsintSource.gulftoday, 'GulfToday': OsintSource.gulftoday, 'gulftoday': OsintSource.gulftoday,
  'Emirates 24|7': OsintSource.emirates247, 'Emirates247': OsintSource.emirates247, 'emirates247': OsintSource.emirates247,
  'Arab News': OsintSource.arabnews, 'ArabNews': OsintSource.arabnews, 'arabnews': OsintSource.arabnews,
  'Saudi Gazette': OsintSource.saudigazette, 'SaudiGazette': OsintSource.saudigazette, 'saudigazette': OsintSource.saudigazette,
  'Gulf Times': OsintSource.gulftimes, 'GulfTimes': OsintSource.gulftimes, 'gulftimes': OsintSource.gulftimes,
  'The Peninsula': OsintSource.peninsulaQatar, 'Peninsula Qatar': OsintSource.peninsulaQatar, 'thepeninsulaqatar': OsintSource.peninsulaQatar,
  'Qatar Tribune': OsintSource.qatarTribune, 'QatarTribune': OsintSource.qatarTribune, 'qatartribune': OsintSource.qatarTribune,
  'Gulf Daily News': OsintSource.gulfDailyNews, 'GulfDailyNews': OsintSource.gulfDailyNews, 'gulfdailynews': OsintSource.gulfDailyNews,
  'Daily Tribune': OsintSource.dailyTribuneBh, 'DailyTribune': OsintSource.dailyTribuneBh, 'dailytribune': OsintSource.dailyTribuneBh,
  'Times of Oman': OsintSource.timesOfOman, 'TimesOfOman': OsintSource.timesOfOman, 'timesofoman': OsintSource.timesOfOman,
  'Oman Observer': OsintSource.omanObserver, 'OmanObserver': OsintSource.omanObserver, 'omanobserver': OsintSource.omanObserver,
  'WAM': OsintSource.wam, 'wam': OsintSource.wam,
  'SPA': OsintSource.spa, 'spa': OsintSource.spa,
  'QNA': OsintSource.qna, 'qna': OsintSource.qna,
  'BNA': OsintSource.bna, 'bna': OsintSource.bna,
  'KUNA': OsintSource.kuna, 'kuna': OsintSource.kuna,
  'Oman News': OsintSource.omanNews, 'ONA': OsintSource.omanNews,
  'Times of Israel': OsintSource.timesOfIsrael, 'timesofisrael': OsintSource.timesOfIsrael,
  'Jerusalem Post': OsintSource.jpost, 'JPost': OsintSource.jpost, 'jpost': OsintSource.jpost,
};

// ── Date gate ────────────────────────────────────────────────────
/// Cutoff timestamp (J-1 midnight). Any item older than this is discarded.
int _recentCutoffMs() =>
    DateTime.now().subtract(const Duration(days: _retentionDays)).millisecondsSinceEpoch;

/// Returns true if [timestampMs] is within the J / J-1 window.
bool _isRecent(int timestampMs) => timestampMs >= _recentCutoffMs();

// ── Helpers ──────────────────────────────────────────────────────

final _rng = Random();

String _randomId(String prefix) {
  final ts = DateTime.now().millisecondsSinceEpoch;
  final r = _rng.nextInt(0xFFFF).toRadixString(36);
  return '$prefix-$ts-$r';
}

/// Converts a raw headline map to [OsintItem], or returns `null` if the
/// article's pubDate is older than J-1 (yesterday).
OsintItem? liveHeadlineToOsint(Map<String, dynamic> h) {
  final title = h['title'] as String? ?? '';
  final link = h['link'] as String? ?? '';
  final pubDate = h['pubDate'] as String? ?? '';
  final src = h['source'] as String? ?? '';

  // ── Date gate: reject articles older than J-1 ──────────────────
  int ts = DateTime.now().millisecondsSinceEpoch;
  if (pubDate.isNotEmpty) {
    final parsed = DateTime.tryParse(pubDate);
    if (parsed != null) {
      ts = parsed.millisecondsSinceEpoch;
      if (!_isRecent(ts)) return null; // Too old — discard
    }
  }

  final source = sourceMap[src] ?? OsintSource.reuters;

  final lower = title.toLowerCase();
  OsintPriority priority = OsintPriority.routine;
  if (lower.contains('breaking') || lower.contains('killed') || lower.contains('strike') || lower.contains('attack') || lower.contains('war')) {
    priority = OsintPriority.flash;
  } else if (lower.contains('iran') || lower.contains('military') || lower.contains('missile') || lower.contains('nuclear')) {
    priority = OsintPriority.immediate;
  } else if (lower.contains('middle east') || lower.contains('gulf') || lower.contains('israel') || lower.contains('hezbollah')) {
    priority = OsintPriority.priority;
  }

  String region = 'Middle East';
  if (lower.contains('uae') || lower.contains('dubai') || lower.contains('abu dhabi') || lower.contains('sharjah') || lower.contains('emirates') || lower.contains('الإمارات') || lower.contains('دبي')) region = 'UAE';
  else if (lower.contains('iran') || lower.contains('tehran') || lower.contains('isfahan')) region = 'Iran';
  else if (lower.contains('israel') || lower.contains('tel aviv') || lower.contains('jerusalem')) region = 'Israel';
  else if (lower.contains('saudi') || lower.contains('riyadh') || lower.contains('jeddah') || lower.contains('ksa')) region = 'KSA';
  else if (lower.contains('kuwait')) region = 'Kuwait';
  else if (lower.contains('bahrain') || lower.contains('manama')) region = 'Bahrain';
  else if (lower.contains('qatar') || lower.contains('doha')) region = 'Qatar';
  else if (lower.contains('oman') || lower.contains('muscat')) region = 'Oman';
  else if (lower.contains('jordan') || lower.contains('amman')) region = 'Jordan';
  else if (lower.contains('lebanon') || lower.contains('beirut') || lower.contains('hezbollah')) region = 'Lebanon';
  else if (lower.contains('iraq') || lower.contains('baghdad') || lower.contains('pmf')) region = 'Iraq';
  else if (lower.contains('syria') || lower.contains('damascus')) region = 'Syria';
  else if (lower.contains('yemen') || lower.contains('houthi') || lower.contains('sanaa')) region = 'Yemen';
  else if (lower.contains('centcom') || lower.contains('pentagon') || lower.contains('washington')) region = 'USA';
  else if (lower.contains('britain') || lower.contains('uk ')) region = 'UK';
  else if (lower.contains('france') || lower.contains('french')) region = 'France';

  return OsintItem(
    id: _randomId('live'),
    source: source,
    title: title,
    summary: '$src — ${pubDate.isEmpty ? 'just now' : pubDate}',
    timestamp: ts,
    priority: priority,
    region: region,
    url: link,
  );
}

OsintSource _mapOsintSource(String name) {
  final mapped = sourceMap[name];
  if (mapped != null) return mapped;
  final lower = name.toLowerCase();
  if (lower.contains('reuters')) return OsintSource.reuters;
  if (lower.contains('jazeera')) return OsintSource.aljazeera;
  if (lower.contains('centcom') || lower.contains('dod')) return OsintSource.centcom;
  if (lower.contains('idf') || lower.contains('israel')) return OsintSource.idf;
  if (lower.contains('ap')) return OsintSource.ap;
  return OsintSource.reuters;
}

OsintPriority _mapPriority(String name) {
  switch (name) {
    case 'flash': return OsintPriority.flash;
    case 'immediate': return OsintPriority.immediate;
    case 'priority': return OsintPriority.priority;
    default: return OsintPriority.routine;
  }
}

// ── StateNotifier ────────────────────────────────────────────────

class OsintNotifier extends StateNotifier<List<OsintItem>> {
  OsintNotifier(this._ref) : super([]) {
    _init();
  }

  final Ref _ref;
  Timer? _headlineTimer;
  Timer? _centcomTimer;
  Timer? _persistTimer;
  final Set<String> _injected = {};
  final Set<String> _seenIds = {};
  bool _cacheLoaded = false;

  StreamSubscription? _wsInitSub;
  StreamSubscription? _wsOsintSub;
  StreamSubscription? _wsHeadlinesSub;
  StreamSubscription? _wsConnSub;

  // ── Persistence ──────────────────────────────────────────────────

  Future<void> _loadCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_osintCacheKey);
      if (raw == null || raw.isEmpty) { _cacheLoaded = true; return; }

      final List<dynamic> decoded = jsonDecode(raw);
      final cutoff = DateTime.now().subtract(const Duration(days: _retentionDays)).millisecondsSinceEpoch;

      final cached = <OsintItem>[];
      for (final item in decoded) {
        try {
          final osint = OsintItem.fromJson(item as Map<String, dynamic>);
          if (osint.timestamp >= cutoff && _seenIds.add(osint.id)) {
            _injected.add(osint.title);
            cached.add(osint);
          }
        } catch (_) {}
      }

      if (cached.isNotEmpty && mounted) {
        cached.sort((a, b) => b.timestamp.compareTo(a.timestamp));
        state = cached.take(_maxCachedItems).toList();
      }
      _cacheLoaded = true;
    } catch (_) {
      _cacheLoaded = true;
    }
  }

  Future<void> _saveCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cutoff = DateTime.now().subtract(const Duration(days: _retentionDays)).millisecondsSinceEpoch;
      final toSave = state.where((i) => i.timestamp >= cutoff).take(_maxCachedItems).toList();
      final encoded = jsonEncode(toSave.map((i) => i.toJson()).toList());
      await prefs.setString(_osintCacheKey, encoded);
    } catch (_) {}
  }

  void _scheduleSave() {
    _persistTimer?.cancel();
    _persistTimer = Timer(const Duration(seconds: 5), _saveCache);
  }

  // ── Merge helper (deduped + sorted + pruned) ─────────────────────

  void _mergeAndUpdate(List<OsintItem> newItems) {
    if (newItems.isEmpty) return;
    final cutoff = DateTime.now().subtract(const Duration(days: _retentionDays)).millisecondsSinceEpoch;
    final merged = [...newItems, ...state];
    merged.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    state = merged.where((i) => i.timestamp >= cutoff).take(_maxCachedItems).toList();
    _scheduleSave();
  }

  // ── Init ─────────────────────────────────────────────────────────

  void _init() async {
    await _loadCache();

    final ws = BreachSocketService.instance;

    _wsInitSub = ws.channel(WsMessageType.init).listen((data) {
      if (!mounted) return;
      final json = data as Map<String, dynamic>;
      final osint = json['osint'] as List<dynamic>?;
      if (osint == null || osint.isEmpty) return;

      final parsed = <OsintItem>[];
      for (final raw in osint) {
        try {
          final m = raw as Map<String, dynamic>;
          final id = m['id'] as String? ?? '';
          if (id.isEmpty || !_seenIds.add(id)) continue;
          final ts = m['timestamp'] as int? ?? DateTime.now().millisecondsSinceEpoch;
          // Date gate: skip items older than J-1
          if (!_isRecent(ts)) continue;
          final item = OsintItem(
            id: id,
            source: _mapOsintSource(m['source'] as String? ?? ''),
            title: m['title'] as String? ?? '',
            summary: m['summary'] as String? ?? '',
            timestamp: ts,
            priority: _mapPriority(m['priority'] as String? ?? 'routine'),
            region: m['region'] as String? ?? 'Middle East',
            url: m['url'] as String?,
          );
          _injected.add(item.title);
          parsed.add(item);
        } catch (_) {}
      }
      _mergeAndUpdate(parsed);
    });

    _wsOsintSub = ws.channel(WsMessageType.osint).listen((data) {
      if (!mounted) return;
      try {
        final m = data as Map<String, dynamic>;
        final id = m['id'] as String? ?? '';
        if (id.isEmpty || !_seenIds.add(id)) return;
        final ts = m['timestamp'] as int? ?? DateTime.now().millisecondsSinceEpoch;
        // Date gate: skip items older than J-1
        if (!_isRecent(ts)) return;

        final item = OsintItem(
          id: id,
          source: _mapOsintSource(m['source'] as String? ?? ''),
          title: m['title'] as String? ?? '',
          summary: m['summary'] as String? ?? '',
          timestamp: ts,
          priority: _mapPriority(m['priority'] as String? ?? 'routine'),
          region: m['region'] as String? ?? 'Middle East',
          url: m['url'] as String?,
        );
        _injected.add(item.title);
        _mergeAndUpdate([item]);
      } catch (_) {}
    });

    _wsHeadlinesSub = ws.channel(WsMessageType.headlines).listen((data) {
      if (!mounted) return;
      _processHeadlines(data as List<dynamic>);
    });

    _wsConnSub = ws.connectionStream.listen((connected) {
      if (connected) {
        _headlineTimer?.cancel();
        _headlineTimer = null;
        _centcomTimer?.cancel();
        _centcomTimer = null;
      } else {
        _startHttpPolling();
      }
    });

    if (!ws.connected) _startHttpPolling();
  }

  void _processHeadlines(List<dynamic> headlines) {
    final newItems = headlines.where((h) {
      final title = (h as Map<String, dynamic>)['title'] as String? ?? '';
      return title.isNotEmpty && !_injected.contains(title);
    }).toList();
    if (newItems.isEmpty) return;

    final osintItems = <OsintItem>[];
    for (final h in newItems) {
      final item = liveHeadlineToOsint(h as Map<String, dynamic>);
      if (item != null) {
        _injected.add(item.title);
        osintItems.add(item);
      }
    }
    _mergeAndUpdate(osintItems);
  }

  void _startHttpPolling() {
    _fetchLiveHeadlines();
    _fetchCentcomBriefings();
    _headlineTimer ??= Timer.periodic(const Duration(seconds: 30), (_) => _fetchLiveHeadlines());
    _centcomTimer ??= Timer.periodic(PollIntervals.centcom, (_) => _fetchCentcomBriefings());
  }

  Future<void> _fetchLiveHeadlines() async {
    try {
      final headlines = await HeadlinesService.instance.fetchHeadlines();
      if (headlines.isEmpty || !mounted) return;
      final newItems = headlines.where((h) {
        final title = h['title'] as String? ?? '';
        return title.isNotEmpty && !_injected.contains(title);
      }).toList();
      if (newItems.isEmpty) return;
      final osintItems = <OsintItem>[];
      for (final h in newItems) {
        final item = liveHeadlineToOsint(h);
        if (item != null) {
          _injected.add(item.title);
          osintItems.add(item);
        }
      }
      _mergeAndUpdate(osintItems);
    } catch (_) {}
  }

  Future<void> _fetchCentcomBriefings() async {
    try {
      final briefings = await CentcomService.instance.fetchBriefings();
      if (briefings.isEmpty || !mounted) return;
      final newItems = briefings.where((b) {
        if (_injected.contains(b.title)) return false;
        // Date gate: reject briefings older than J-1
        final tsMs = b.timestamp * 1000;
        return _isRecent(tsMs);
      }).toList();
      if (newItems.isEmpty) return;
      final osintItems = newItems.map((b) => OsintItem(
        id: _randomId('centcom'),
        source: OsintSource.centcom,
        title: b.title,
        summary: b.summary.isNotEmpty ? b.summary : 'CENTCOM — ${b.pubDate}',
        timestamp: b.timestamp * 1000,
        priority: b.priority.index <= 1 ? OsintPriority.flash : OsintPriority.priority,
        region: 'CENTCOM AOR',
        url: b.link,
      )).toList();
      for (final item in osintItems) { _injected.add(item.title); }
      _mergeAndUpdate(osintItems);
    } catch (_) {}
  }

  /// Refresh fetches new data but KEEPS cached items (no data loss).
  Future<void> refresh() async {
    _injected.clear();
    // Re-add existing titles to avoid duplicates on re-fetch
    for (final item in state) {
      _injected.add(item.title);
    }
    await Future.wait([_fetchLiveHeadlines(), _fetchCentcomBriefings()]);
  }

  @override
  void dispose() {
    _headlineTimer?.cancel();
    _centcomTimer?.cancel();
    _persistTimer?.cancel();
    _wsInitSub?.cancel();
    _wsOsintSub?.cancel();
    _wsHeadlinesSub?.cancel();
    _wsConnSub?.cancel();
    // Final save on dispose
    _saveCache();
    super.dispose();
  }
}

final osintProvider =
    StateNotifierProvider<OsintNotifier, List<OsintItem>>((ref) {
  return OsintNotifier(ref);
});
