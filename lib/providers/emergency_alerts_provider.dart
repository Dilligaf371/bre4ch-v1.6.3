// ── Emergency Alerts Provider ────────────────────────────────────
// WebSocket-first: subscribes to 'headlines' + 'socmint' channels.
// Falls back to HTTP polling when WS is disconnected.
// v1.6.4: Missile→EXTREME, wider UAE detection, FCM→alerts bridge, sounds on notif.

import 'dart:async';
import 'dart:math';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/emergency_alert.dart';
import '../services/headlines_service.dart';
import '../services/breach_socket_service.dart';
import '../services/alert_sound_service.dart';
import '../services/push_notification_service.dart';
import '../config/api.dart';

// ── Keyword lists (EN + AR) ─────────────────────────────────────

const List<String> _extremeKeywords = [
  // English
  'nuclear', 'radiological', 'wmd', 'chemical weapon',
  'khamenei killed', 'leader killed', 'capital struck',
  'strait of hormuz closed', 'temple mount',
  'mass casualty', 'nato article 5',
  'missile', 'ballistic', 'warhead', 'icbm',
  // Arabic
  'نووي', 'سلاح كيميائي', 'ضحايا جماعية',
  'صاروخ', 'صاروخ باليستي', 'رأس حربي',
];

const List<String> _severeKeywords = [
  // English
  'killed', 'strike', 'attack', 'war', 'breaking',
  'drone', 'shot down', 'friendly fire',
  'airport shut', 'airport hit',
  'hezbollah', 'retaliation', 'sunk',
  'evacuation', 'evacuate', 'repatriation',
  'embassy closure', 'leave immediately',
  // Arabic
  'هجوم', 'طائرة مسيرة', 'ضربة', 'قتل',
  'حرب', 'إعتراض',
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

// ── Test / drill detection ───────────────────────────────────────

const List<String> _testKeywords = [
  'test', 'drill', 'exercise', 'simulation', 'rehearsal', 'mock',
  'تمرين', 'تجربة', 'محاكاة', 'اختبار',
];

bool _isTestAlert(String content) {
  final lower = content.toLowerCase();
  for (final kw in _testKeywords) {
    if (lower.contains(kw)) return true;
  }
  return false;
}

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
  if (lower.contains('tehran') || lower.contains('isfahan') || lower.contains('natanz') || lower.contains('ايران')) return 'IRAN';
  if (lower.contains('israel') || lower.contains('tel aviv') || lower.contains('jerusalem') || lower.contains('اسرائيل')) return 'ISRAEL';
  // UAE — extensive matching: cities, Arabic names, official accounts
  if (lower.contains('dubai') || lower.contains('uae') || lower.contains('abu dhabi') ||
      lower.contains('sharjah') || lower.contains('ajman') || lower.contains('fujairah') ||
      lower.contains('ras al khaimah') || lower.contains('rak') || lower.contains('al ain') ||
      lower.contains('emirates') || lower.contains('emirati') ||
      lower.contains('الإمارات') || lower.contains('دبي') || lower.contains('أبوظبي') ||
      lower.contains('الشارقة') || lower.contains('عجمان') || lower.contains('الفجيرة') ||
      lower.contains('رأس الخيمة') || lower.contains('العين') ||
      lower.contains('moiuae') || lower.contains('ncema') || lower.contains('modgovae')) return 'UAE';
  if (lower.contains('saudi') || lower.contains('riyadh') || lower.contains('jeddah') || lower.contains('السعودية')) return 'KSA';
  if (lower.contains('kuwait') || lower.contains('الكويت')) return 'KUWAIT';
  if (lower.contains('bahrain') || lower.contains('البحرين')) return 'BAHRAIN';
  if (lower.contains('qatar') || lower.contains('doha') || lower.contains('قطر')) return 'QATAR';
  if (lower.contains('oman') || lower.contains('muscat') || lower.contains('عمان')) return 'OMAN';
  if (lower.contains('lebanon') || lower.contains('beirut') || lower.contains('لبنان')) return 'LEBANON';
  if (lower.contains('cyprus')) return 'CYPRUS';
  if (lower.contains('strait') || lower.contains('hormuz') || lower.contains('هرمز')) return 'STRAIT OF HORMUZ';
  if (lower.contains('gulf') || lower.contains('الخليج')) return 'PERSIAN GULF';
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
  StreamSubscription? _fcmForegroundSub;
  StreamSubscription? _fcmTapSub;

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

    // ── FCM push notifications → create alerts + play sounds ────
    final push = PushNotificationService.instance;
    _fcmForegroundSub = push.onForegroundMessage.listen((message) {
      if (!mounted) return;
      _processPushNotification(message);
    });
    _fcmTapSub = push.onNotificationTap.listen((message) {
      if (!mounted) return;
      _processPushNotification(message);
    });
    // Handle cold-start notification
    final initial = await push.getInitialMessage();
    if (initial != null) _processPushNotification(initial);

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

  /// Bridge FCM push notifications into the alert system.
  void _processPushNotification(RemoteMessage message) {
    final title = message.notification?.title ?? message.data['title'] as String? ?? '';
    final body = message.notification?.body ?? message.data['body'] as String? ?? '';
    final content = '$title $body';
    if (content.trim().isEmpty) return;
    if (_seen.contains(title)) return;

    // Detect alert level from notification content
    var level = _detectAlertLevel(content);
    // If no keyword match, check data payload for severity
    if (level == null) {
      final severity = message.data['severity'] as String? ?? '';
      switch (severity.toLowerCase()) {
        case 'extreme': level = AlertLevel.extreme;
        case 'severe': level = AlertLevel.severe;
        case 'moderate': level = AlertLevel.moderate;
        default: level = AlertLevel.severe; // Default: any push = at least SEVERE
      }
    }

    _seen.add(title);
    final region = _detectRegion(content);
    final source = message.data['source'] as String? ?? 'PUSH';
    final now = DateTime.now().millisecondsSinceEpoch;

    // TEST detection: prefix headline for UAE test/drill alerts
    final isTest = _isTestAlert(content);
    final rawHeadline = title.isNotEmpty ? title.toUpperCase() : body.toUpperCase();
    final headline = (isTest && region == 'UAE') ? '[TEST] $rawHeadline' : rawHeadline;

    final alert = EmergencyAlert(
      id: _randomId('fcm'),
      level: level,
      headline: headline,
      body: body.isNotEmpty ? body : title,
      source: '$source [PUSH]',
      sourceUrl: message.data['url'] as String?,
      authority: _detectAuthority(region, source),
      timestamp: now,
      region: region,
      dismissed: false,
      readAt: null,
      expiresAt: now + (_alertDuration[level] ?? 90000),
    );

    _alerts = [alert, ..._alerts].take(30).toList();
    _emitState();

    // Play alert sound
    AlertSoundService.instance.playForLevel(level);
    debugPrint('[ALERTS] FCM notification → $level alert: $title ($region)');
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

      // TEST detection: prefix headline for UAE test/drill alerts
      final isTest = _isTestAlert(title);
      final rawHeadline = title.toUpperCase();
      final headline = (isTest && region == 'UAE') ? '[TEST] $rawHeadline' : rawHeadline;

      newAlerts.add(EmergencyAlert(
        id: _randomId('ea'),
        level: level,
        headline: headline,
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

    // TEST detection: prefix headline for UAE test/drill alerts
    final isTest = _isTestAlert(content);
    final rawHeadline = content.length > 120
        ? content.substring(0, 120).toUpperCase()
        : content.toUpperCase();
    final headline = (isTest && region == 'UAE') ? '[TEST] $rawHeadline' : rawHeadline;

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
    _fcmForegroundSub?.cancel();
    _fcmTapSub?.cancel();
    super.dispose();
  }
}

final emergencyAlertsProvider =
    StateNotifierProvider<EmergencyAlertsNotifier, EmergencyAlertsState>((ref) {
  return EmergencyAlertsNotifier(ref);
});
