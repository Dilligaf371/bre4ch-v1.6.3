// ── Emergency Alerts Provider ────────────────────────────────────
// WebSocket-first: subscribes to 'headlines' + 'socmint' channels.
// Falls back to HTTP polling when WS is disconnected.
// v1.6.3: Arabic keywords, Instagram alert escalation with authority boost.

import 'dart:async';
import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/emergency_alert.dart';
import '../services/headlines_service.dart';
import '../services/breach_socket_service.dart';
import '../services/alert_sound_service.dart';
import '../config/api.dart';

// ── Keyword lists (EN + AR) ─────────────────────────────────────

const List<String> _extremeKeywords = [
  // English
  'nuclear', 'radiological', 'wmd', 'chemical weapon',
  'khamenei killed', 'leader killed', 'capital struck',
  'strait of hormuz closed', 'temple mount',
  'mass casualty', 'nato article 5',
  // Arabic
  'نووي', 'سلاح كيميائي', 'ضحايا جماعية',
];

const List<String> _severeKeywords = [
  // English
  'killed', 'strike', 'attack', 'war', 'breaking',
  'missile', 'drone', 'shot down', 'friendly fire',
  'airport shut', 'airport hit', 'warhead',
  'hezbollah', 'retaliation', 'sunk',
  'evacuation', 'evacuate', 'repatriation',
  'embassy closure', 'leave immediately',
  // Arabic
  'صاروخ', 'هجوم', 'طائرة مسيرة', 'ضربة', 'قتل',
  'حرب', 'رأس حربي', 'إعتراض',
  'إجلاء', 'مغادرة فورية',
];

const List<String> _moderateKeywords = [
  // English
  'iran', 'military', 'bomb', 'explosion',
  'airspace closed', 'intercepted', 'escalation',
  'casualties', 'wounded', 'deployment',
  'travel advisory', 'travel warning', 'do not travel',
  'nationals abroad', 'consular assistance',
  'departure flight', 'expats',
  // Arabic
  'عسكري', 'انفجار', 'مجال جوي مغلق', 'تصعيد', 'نشر',
  'تحذير سفر', 'رعايا', 'سفارة',
];

// ── Alert duration ───────────────────────────────────────────────

const Map<AlertLevel, int> _alertDuration = {
  AlertLevel.extreme:  120000,
  AlertLevel.severe:   90000,
  AlertLevel.moderate: 60000,
};

// ── Detection helpers ────────────────────────────────────────────

AlertLevel? _detectAlertLevel(String title) {
  final lower = title.toLowerCase();
  for (final kw in _extremeKeywords) {
    if (lower.contains(kw)) return AlertLevel.extreme;
  }
  for (final kw in _severeKeywords) {
    if (lower.contains(kw)) return AlertLevel.severe;
  }
  for (final kw in _moderateKeywords) {
    if (lower.contains(kw)) return AlertLevel.moderate;
  }
  return null;
}

String _detectRegion(String title) {
  final lower = title.toLowerCase();
  if (lower.contains('tehran') || lower.contains('isfahan') || lower.contains('natanz')) return 'IRAN';
  if (lower.contains('israel') || lower.contains('tel aviv') || lower.contains('jerusalem')) return 'ISRAEL';
  if (lower.contains('dubai') || lower.contains('uae') || lower.contains('abu dhabi')) return 'UAE';
  if (lower.contains('kuwait')) return 'KUWAIT';
  if (lower.contains('bahrain')) return 'BAHRAIN';
  if (lower.contains('qatar') || lower.contains('doha')) return 'QATAR';
  if (lower.contains('lebanon') || lower.contains('beirut')) return 'LEBANON';
  if (lower.contains('cyprus')) return 'CYPRUS';
  if (lower.contains('strait') || lower.contains('hormuz')) return 'STRAIT OF HORMUZ';
  if (lower.contains('gulf')) return 'PERSIAN GULF';
  return 'MIDDLE EAST THEATER';
}

AlertAuthority _detectAuthority(String region, String source) {
  if (region == 'UAE') return AlertAuthority.moi;
  if (source.contains('CENTCOM') || source.contains('DoD')) return AlertAuthority.centcom;
  if (source.contains('IDF')) return AlertAuthority.idf;
  if (region == 'KUWAIT' || region == 'BAHRAIN' || region == 'QATAR') return AlertAuthority.ncema;
  return AlertAuthority.coalition;
}

/// Detect authority from an Instagram handle.
AlertAuthority _detectInstagramAuthority(String handle) {
  if (handle.contains('ncaboron') || handle.contains('ncema')) return AlertAuthority.ncema;
  if (handle.contains('moiuae') || handle.contains('moaboron_sa') || handle.contains('moaboron_bh') ||
      handle.contains('moaboron_kw') || handle.contains('moaboron_qa')) return AlertAuthority.moi;
  if (handle.contains('modgovae') || handle.contains('modaboron') || handle.contains('modkuwait')) return AlertAuthority.mod;
  if (handle.contains('statedept')) return AlertAuthority.centcom;
  return AlertAuthority.coalition;
}

bool _isToday(int ts) {
  return DateTime.now().millisecondsSinceEpoch - ts < 24 * 60 * 60 * 1000;
}

final _rng = Random();

String _randomId(String prefix) {
  final ts = DateTime.now().millisecondsSinceEpoch;
  final r = _rng.nextInt(0xFFFF).toRadixString(36);
  return '$prefix-$ts-$r';
}

// ── SharedPreferences for read alerts ────────────────────────────

const String _prefsKey = 'roar-read-alerts';

Future<Set<String>> _loadReadAlerts() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getStringList(_prefsKey);
    if (stored != null) return stored.toSet();
  } catch (_) {}
  return {};
}

Future<void> _saveReadAlerts(Set<String> readSet) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_prefsKey, readSet.toList());
  } catch (_) {}
}

// ── State class ──────────────────────────────────────────────────

class EmergencyAlertsState {
  final List<EmergencyAlert> alerts;
  final List<EmergencyAlert> activeAlerts;
  final int activeCount;

  const EmergencyAlertsState({
    this.alerts = const [],
    this.activeAlerts = const [],
    this.activeCount = 0,
  });
}

// ── StateNotifier ────────────────────────────────────────────────

class EmergencyAlertsNotifier extends StateNotifier<EmergencyAlertsState> {
  EmergencyAlertsNotifier(this._ref)
      : super(const EmergencyAlertsState()) {
    _init();
  }

  final Ref _ref;
  Timer? _pollTimer;
  Timer? _expireTimer;
  final Set<String> _seen = {};
  Set<String> _readHeadlines = {};
  List<EmergencyAlert> _alerts = [];

  StreamSubscription? _wsHeadlinesSub;
  StreamSubscription? _wsSocmintSub;
  StreamSubscription? _wsConnSub;

  Future<void> _init() async {
    _readHeadlines = await _loadReadAlerts();

    final ws = BreachSocketService.instance;

    // ── WS headlines → instant alert detection ──────────────────
    _wsHeadlinesSub = ws.channel(WsMessageType.headlines).listen((data) {
      if (!mounted) return;
      _processHeadlines(data as List<dynamic>);
    });

    // ── WS socmint → Instagram official GOV alert escalation ────
    _wsSocmintSub = ws.channel(WsMessageType.socmint).listen((data) {
      if (!mounted) return;
      try {
        final m = data as Map<String, dynamic>;
        if (m['platform'] == 'instagram' && m['isOfficialGov'] == true) {
          _processInstagramAlert(m);
        }
      } catch (_) {}
    });

    // ── Connection fallback ─────────────────────────────────────
    _wsConnSub = ws.connectionStream.listen((connected) {
      if (connected) {
        _pollTimer?.cancel();
        _pollTimer = null;
      } else {
        _startHttpPolling();
      }
    });

    if (!ws.connected) _startHttpPolling();

    // Auto-dismiss expired alerts every 1s
    _expireTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      _autoDismissExpired();
    });
  }

  void _startHttpPolling() {
    _checkLiveHeadlines();
    _pollTimer ??= Timer.periodic(PollIntervals.alerts, (_) => _checkLiveHeadlines());
  }

  void _processHeadlines(List<dynamic> headlines) {
    final newAlerts = <EmergencyAlert>[];
    final now = DateTime.now().millisecondsSinceEpoch;

    for (final h in headlines) {
      final map = h as Map<String, dynamic>;
      final title = map['title'] as String? ?? '';
      if (title.isEmpty) continue;
      if (_seen.contains(title)) continue;
      if (_readHeadlines.contains(title.toUpperCase())) continue;

      final pubDate = map['pubDate'] as String? ?? '';
      int pubTime = 0;
      if (pubDate.isNotEmpty) {
        final parsed = DateTime.tryParse(pubDate);
        if (parsed != null) pubTime = parsed.millisecondsSinceEpoch;
      }
      if (pubTime > 0 && !_isToday(pubTime)) continue;

      final level = _detectAlertLevel(title);
      if (level == null) continue;

      _seen.add(title);
      final region = _detectRegion(title);
      final source = map['source'] as String? ?? '';
      final timestamp = pubTime > 0 ? pubTime : now;

      newAlerts.add(EmergencyAlert(
        id: _randomId('ea'),
        level: level,
        headline: title.toUpperCase(),
        body: title,
        source: '$source [LIVE]',
        sourceUrl: map['link'] as String?,
        authority: _detectAuthority(region, source),
        timestamp: timestamp,
        region: region,
        dismissed: false,
        readAt: null,
        expiresAt: now + (_alertDuration[level] ?? 60000),
      ));
    }

    if (newAlerts.isNotEmpty) {
      const order = {AlertLevel.extreme: 0, AlertLevel.severe: 1, AlertLevel.moderate: 2};
      newAlerts.sort((a, b) => (order[a.level] ?? 2).compareTo(order[b.level] ?? 2));
      _alerts = [...newAlerts.take(5), ..._alerts].take(30).toList();
      _emitState();
      // Play sound for highest-priority new alert
      AlertSoundService.instance.playForLevel(newAlerts.first.level);
    }
  }

  /// Process Instagram posts from official government accounts.
  /// Authority boost: moderate→severe, severe→extreme.
  void _processInstagramAlert(Map<String, dynamic> m) {
    final content = m['content'] as String? ?? '';
    if (content.isEmpty) return;
    if (_seen.contains(content)) return;

    var level = _detectAlertLevel(content);
    if (level == null) return;

    // Authority boost: official GCC Instagram → escalate one level
    if (level == AlertLevel.moderate) {
      level = AlertLevel.severe;
    } else if (level == AlertLevel.severe) {
      level = AlertLevel.extreme;
    }

    _seen.add(content);
    final region = _detectRegion(content);
    final source = m['source'] as String? ?? '';
    final now = DateTime.now().millisecondsSinceEpoch;
    final timestamp = m['timestamp'] as int? ?? now;

    final headline = content.length > 120
        ? content.substring(0, 120).toUpperCase()
        : content.toUpperCase();

    final alert = EmergencyAlert(
      id: _randomId('ig-ea'),
      level: level,
      headline: headline,
      body: content,
      source: 'Instagram $source [OFFICIAL]',
      sourceUrl: 'https://instagram.com/${source.replaceAll('@', '')}',
      authority: _detectInstagramAuthority(source),
      timestamp: timestamp,
      region: region,
      dismissed: false,
      readAt: null,
      expiresAt: now + (_alertDuration[level] ?? 60000),
    );

    _alerts = [alert, ..._alerts].take(30).toList();
    _emitState();
    AlertSoundService.instance.playForLevel(level);
  }

  Future<void> _checkLiveHeadlines() async {
    try {
      final headlines = await HeadlinesService.instance.fetchHeadlines();
      if (!mounted) return;
      _processHeadlines(headlines.map((h) => h as dynamic).toList());
    } catch (_) {}
  }

  void _autoDismissExpired() {
    final now = DateTime.now().millisecondsSinceEpoch;
    bool changed = false;
    _alerts = _alerts.map((a) {
      if (!a.dismissed && a.readAt != null && now > a.expiresAt) {
        changed = true;
        return a.copyWith(dismissed: true);
      }
      return a;
    }).toList();
    if (changed) _emitState();
  }

  void markAsRead(String id) {
    _alerts = _alerts.map((a) {
      if (a.id == id && a.readAt == null) {
        _readHeadlines.add(a.headline);
        _saveReadAlerts(_readHeadlines);
        return a.copyWith(
          readAt: DateTime.now().millisecondsSinceEpoch,
          expiresAt: DateTime.now().millisecondsSinceEpoch + 10000,
        );
      }
      return a;
    }).toList();
    _emitState();
  }

  void dismissAlert(String id) {
    _alerts = _alerts.map((a) => a.id == id ? a.copyWith(dismissed: true) : a).toList();
    _emitState();
  }

  void dismissAll() {
    _alerts = _alerts.map((a) => a.copyWith(dismissed: true)).toList();
    _emitState();
  }

  void _emitState() {
    final active = _alerts.where((a) => !a.dismissed).toList();
    state = EmergencyAlertsState(
      alerts: _alerts,
      activeAlerts: active,
      activeCount: active.length,
    );
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _expireTimer?.cancel();
    _wsHeadlinesSub?.cancel();
    _wsSocmintSub?.cancel();
    _wsConnSub?.cancel();
    super.dispose();
  }
}

final emergencyAlertsProvider =
    StateNotifierProvider<EmergencyAlertsNotifier, EmergencyAlertsState>((ref) {
  return EmergencyAlertsNotifier(ref);
});
