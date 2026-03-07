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
import 'notification_preferences_provider.dart';

// ── Official X accounts (ALL countries) ─────────────────────────

class _XAccount {
  final String handle;
  final String country;        // notification pref code: 'uae', 'ksa', etc.
  final AlertAuthority authority;
  const _XAccount(this.handle, this.country, this.authority);
}

const List<_XAccount> _officialXAccountsList = [
  // ── UAE ──
  _XAccount('@modgovae',       'uae', AlertAuthority.mod),
  _XAccount('@ABORON_uae',     'uae', AlertAuthority.moi),
  _XAccount('@ABORON_ncema',   'uae', AlertAuthority.ncema),
  _XAccount('@WAaboron',       'uae', AlertAuthority.ncema),
  _XAccount('@MoFAICaboron',   'uae', AlertAuthority.ncema),
  _XAccount('@HaboronZayed',   'uae', AlertAuthority.ncema),
  // ── KSA ──
  _XAccount('@modaboron_sa',   'ksa', AlertAuthority.mod),
  _XAccount('@moaboron_sa',    'ksa', AlertAuthority.moi),
  _XAccount('@kaboron_sa',     'ksa', AlertAuthority.coalition),
  _XAccount('@SPAaboron',      'ksa', AlertAuthority.coalition),
  // ── Kuwait ──
  _XAccount('@modkuwait',      'kuwait', AlertAuthority.mod),
  _XAccount('@moaboron_kw',    'kuwait', AlertAuthority.moi),
  _XAccount('@maboron_kw',     'kuwait', AlertAuthority.ncema),
  // ── Bahrain ──
  _XAccount('@moaboron_bh',    'bahrain', AlertAuthority.moi),
  _XAccount('@maboron_bh',     'bahrain', AlertAuthority.ncema),
  _XAccount('@BDFaboron',      'bahrain', AlertAuthority.mod),
  // ── Qatar ──
  _XAccount('@moaboron_qa',    'qatar', AlertAuthority.moi),
  _XAccount('@moaboron_qa_mfa','qatar', AlertAuthority.ncema),
  _XAccount('@QNAaboron',      'qatar', AlertAuthority.coalition),
  // ── Oman ──
  _XAccount('@moaboron_om',    'oman', AlertAuthority.mod),
  _XAccount('@maboron_om',     'oman', AlertAuthority.coalition),
  _XAccount('@OMAaboron',      'oman', AlertAuthority.coalition),
  // ── Jordan ──
  _XAccount('@AFJordan',       'jordan', AlertAuthority.mod),
  _XAccount('@PetraNewsAgency','jordan', AlertAuthority.coalition),
  // ── Lebanon ──
  _XAccount('@LAFaboron',      'lebanon', AlertAuthority.mod),
  _XAccount('@NNAaboron',      'lebanon', AlertAuthority.coalition),
  // ── Israel ──
  _XAccount('@IDF',            'israel', AlertAuthority.idf),
  _XAccount('@IsraelMFA',      'israel', AlertAuthority.coalition),
  _XAccount('@Israel',         'israel', AlertAuthority.coalition),
  // ── Iran ──
  _XAccount('@IRGCaboron',     'iran', AlertAuthority.coalition),
  _XAccount('@IranMilitary',   'iran', AlertAuthority.coalition),
  // ── Coalition / Military ──
  _XAccount('@CENTCOM',        '', AlertAuthority.centcom),
  _XAccount('@DeptofDefense',  '', AlertAuthority.centcom),
  _XAccount('@statedept',      '', AlertAuthority.centcom),
  _XAccount('@foreignoffice',  '', AlertAuthority.coalition),
  _XAccount('@francediplo',    '', AlertAuthority.coalition),
  _XAccount('@ausaboron_amt',  '', AlertAuthority.coalition),
  _XAccount('@globalaffairscan','', AlertAuthority.coalition),
  _XAccount('@dfaboron_au',    '', AlertAuthority.coalition),
  _XAccount('@NATO',           '', AlertAuthority.coalition),
];

/// Lookup index: lowercase handle → _XAccount
final Map<String, _XAccount> _xAccountIndex = {
  for (final a in _officialXAccountsList) a.handle.toLowerCase(): a,
};

/// Region string → notification preference country code
String? _regionToCountryCode(String region) {
  switch (region) {
    case 'UAE': return 'uae';
    case 'IRAN': return 'iran';
    case 'ISRAEL': return 'israel';
    case 'KSA': return 'ksa';
    case 'KUWAIT': return 'kuwait';
    case 'BAHRAIN': return 'bahrain';
    case 'QATAR': return 'qatar';
    case 'OMAN': return 'oman';
    case 'LEBANON': return 'lebanon';
    case 'JORDAN': return 'jordan';
    default: return null; // MIDDLE EAST THEATER, STRAIT, etc. → always pass
  }
}

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
  if (lower.contains('jordan') || lower.contains('amman') || lower.contains('الأردن')) return 'JORDAN';
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

  /// Check notification preferences: should this alert produce a notification?
  /// Empty country set → all countries pass. Empty severity set → all pass.
  bool _shouldNotify(String region, AlertLevel level) {
    try {
      final prefs = _ref.read(notificationPreferencesProvider);
      // Severity filter
      if (prefs.severities.isNotEmpty &&
          !prefs.severities.contains(level.name)) {
        debugPrint('[ALERTS] Filtered out: severity ${level.name} not in ${prefs.severities}');
        return false;
      }
      // Country filter (empty = all countries)
      if (prefs.countries.isNotEmpty) {
        final code = _regionToCountryCode(region);
        // Known region not in user's list → filter out
        // Unknown region (MIDDLE EAST THEATER, STRAIT, etc.) → always pass
        if (code != null && !prefs.countries.contains(code)) {
          debugPrint('[ALERTS] Filtered out: country $code not in ${prefs.countries}');
          return false;
        }
      }
      return true;
    } catch (_) {
      return true; // If prefs not available yet, let it through
    }
  }

  Future<void> _init() async {
    _readHeadlines = await _loadReadAlerts();

    final ws = BreachSocketService.instance;

    // ── WS headlines → instant alert detection ──────────────────
    _wsHeadlinesSub = ws.channel(WsMessageType.headlines).listen((data) {
      if (!mounted) return;
      _processHeadlines(data as List<dynamic>);
    });

    // ── WS socmint → official GOV alert escalation (Instagram + X) ──
    _wsSocmintSub = ws.channel(WsMessageType.socmint).listen((data) {
      if (!mounted) return;
      try {
        final m = data as Map<String, dynamic>;
        final platform = m['platform'] as String? ?? '';
        if (platform == 'instagram' && m['isOfficialGov'] == true) {
          _processInstagramAlert(m);
        } else if (platform == 'x') {
          _processXAlert(m);
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

    // Preference filter: country + severity
    if (!_shouldNotify(region, level)) return;

    final isTest = _isTestAlert(content);
    final rawHeadline = title.isNotEmpty ? title.toUpperCase() : body.toUpperCase();
    final headline = isTest ? '[TEST] $rawHeadline' : rawHeadline;

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

      // Preference filter: country + severity
      if (!_shouldNotify(region, level)) continue;

      final isTest = _isTestAlert(title);
      final rawHeadline = title.toUpperCase();
      final headline = isTest ? '[TEST] $rawHeadline' : rawHeadline;

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

  /// Process X/Twitter posts — official GOV accounts get authority boost.
  /// All countries supported; user preferences filter notifications.
  void _processXAlert(Map<String, dynamic> m) {
    final content = m['content'] as String? ?? '';
    final source = m['source'] as String? ?? '';
    if (content.isEmpty) return;
    if (_seen.contains(content)) return;

    // Lookup official account
    final account = _xAccountIndex[source.toLowerCase()];
    final isOfficial = account != null;

    var level = _detectAlertLevel(content);
    // Official GOV X accounts: if no keyword match, default to SEVERE
    if (level == null) {
      if (isOfficial) {
        level = AlertLevel.severe;
      } else {
        return; // Non-official + no keyword = skip
      }
    }

    // Authority boost for official GOV X accounts
    if (isOfficial) {
      if (level == AlertLevel.moderate) {
        level = AlertLevel.severe;
      } else if (level == AlertLevel.severe) {
        level = AlertLevel.extreme;
      }
    }

    _seen.add(content);
    // Region: prefer account's country, fallback to content detection
    String region;
    if (account != null && account.country.isNotEmpty) {
      region = account.country.toUpperCase();
    } else {
      region = _detectRegion('$content $source');
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    final timestamp = m['timestamp'] as int? ?? now;

    // Preference filter: country + severity
    if (!_shouldNotify(region, level)) return;

    final isTest = _isTestAlert(content);
    final rawHeadline = content.length > 120
        ? content.substring(0, 120).toUpperCase()
        : content.toUpperCase();
    final headline = isTest ? '[TEST] $rawHeadline' : rawHeadline;

    final authority = account?.authority ?? AlertAuthority.coalition;
    final tag = isOfficial ? '[OFFICIAL]' : '[OSINT]';

    final alert = EmergencyAlert(
      id: _randomId('x-ea'),
      level: level,
      headline: headline,
      body: content,
      source: 'X $source $tag',
      sourceUrl: null,
      authority: authority,
      timestamp: timestamp,
      region: region,
      dismissed: false,
      readAt: null,
      expiresAt: now + (_alertDuration[level] ?? 90000),
    );

    _alerts = [alert, ..._alerts].take(30).toList();
    _emitState();
    AlertSoundService.instance.playForLevel(level);
    debugPrint('[ALERTS] X post → $level alert: $source ($region)');
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

    // Preference filter: country + severity
    if (!_shouldNotify(region, level)) return;

    final isTest = _isTestAlert(content);
    final rawHeadline = content.length > 120
        ? content.substring(0, 120).toUpperCase()
        : content.toUpperCase();
    final headline = isTest ? '[TEST] $rawHeadline' : rawHeadline;

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
