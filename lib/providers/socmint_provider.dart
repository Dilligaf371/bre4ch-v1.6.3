// ── SOCMINT Feed Provider ────────────────────────────────────────
// WebSocket-first with HTTP polling fallback.
// WS: subscribes to 'socmint' + 'headlines' channels.
// HTTP: polls HeadlinesService when WS is disconnected.
// v1.6.3: Added Instagram as 4th platform with GCC/MAE/Coalition gov accounts.

import 'dart:async';
import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/socmint_item.dart';
import '../models/emergency_alert.dart';
import '../services/headlines_service.dart';
import '../services/breach_socket_service.dart';

// ── Source mapping for platforms ─────────────────────────────────

const Map<String, String> _sourceToXAccount = {
  'CENTCOM':    '@CENTCOM',
  'Reuters':    '@Reuters',
  'Al Jazeera': '@AJEnglish',
  'AP':         '@AP',
  'IDF':        '@IDF',
  'DoD':        '@DeptofDefense',
  'BBC':        '@BBCBreaking',
  // UAE — official government X accounts
  'WAM':            '@WAaboron',       // وكالة أنباء الإمارات
  'Gulf News':      '@gulf_news',
  'Khaleej Times':  '@khalaboron',
  'The National':   '@TheNationalNews',
  'Gulf Today':     '@gaboron_today',
  'Emirates 24|7':  '@aboron247',
};

// UAE official X (Twitter) accounts
const List<String> _uaeXAccounts = [
  '@modgovae',       // وزارة الدفاع | MOD UAE
  '@ABORON_uae',     // وزارة الداخلية | MOI UAE
  '@ABORON_ncema',   // NCEMA | الهيئة الوطنية لإدارة الطوارئ
  '@WAaboron',       // وكالة أنباء الإمارات | WAM
  '@MoFAICaboron',   // وزارة الخارجية | MoFA UAE
  '@HaboronZayed',   // رئيس الدولة
];

const List<String> _osintXAccounts = [
  '@Conflicts', '@IntelCrab', '@sentdefender',
  '@OSINTdefender', '@ELINTNews', '@GeoConfirmed',
  '@AuroraIntel', '@FaytuksNetwork', '@criticalthreats',
  '@RALee85',
];

// ── Instagram GCC / MAE / Coalition accounts ────────────────────

class _IgAccount {
  final String handle;
  final String displayName;
  final String country;
  final AlertAuthority authority;
  const _IgAccount(this.handle, this.displayName, this.country, this.authority);
}

const List<_IgAccount> _instagramGovAccounts = [
  // GCC — MOI / MOD / NCEMA
  _IgAccount('@ncaboron',        'NCEMA UAE',       'UAE',      AlertAuthority.ncema),
  _IgAccount('@moiuae',          'MOI UAE',         'UAE',      AlertAuthority.moi),
  _IgAccount('@modgovae',        'MOD UAE',         'UAE',      AlertAuthority.mod),
  _IgAccount('@modaboron_sa',    'MOD KSA',         'KSA',      AlertAuthority.coalition),
  _IgAccount('@moaboron_sa',     'MOI KSA',         'KSA',      AlertAuthority.coalition),
  _IgAccount('@moaboron_qa',     'MOI Qatar',       'QATAR',    AlertAuthority.ncema),
  _IgAccount('@moaboron_bh',     'MOI Bahrain',     'BAHRAIN',  AlertAuthority.ncema),
  _IgAccount('@moaboron_kw',     'MOI Kuwait',      'KUWAIT',   AlertAuthority.ncema),
  _IgAccount('@modkuwait',       'MOD Kuwait',      'KUWAIT',   AlertAuthority.ncema),
  _IgAccount('@moaboron_om',     'MOD Oman',        'OMAN',     AlertAuthority.coalition),
  // GCC — MFA (Affaires Étrangères — évacuation expats)
  _IgAccount('@maboron_uae',     'MoFA UAE',        'UAE',      AlertAuthority.ncema),
  _IgAccount('@kaboron_sa',      'MoFA KSA',        'KSA',      AlertAuthority.coalition),
  _IgAccount('@moaboron_qa_mfa', 'MoFA Qatar',      'QATAR',    AlertAuthority.ncema),
  _IgAccount('@maboron_bh',      'MoFA Bahrain',    'BAHRAIN',  AlertAuthority.ncema),
  _IgAccount('@maboron_kw',      'MoFA Kuwait',     'KUWAIT',   AlertAuthority.ncema),
  _IgAccount('@maboron_om',      'MoFA Oman',       'OMAN',     AlertAuthority.coalition),
  // Coalition — MFA / State Dept / Foreign Offices
  _IgAccount('@statedept',       'US State Dept',   'USA',      AlertAuthority.centcom),
  _IgAccount('@foreignoffice',   'UK FCDO',         'UK',       AlertAuthority.coalition),
  _IgAccount('@francediplo',     'France MEAE',     'FRANCE',   AlertAuthority.coalition),
  _IgAccount('@auswaertiges_amt','Germany AA',      'GERMANY',  AlertAuthority.coalition),
  _IgAccount('@globalaffairscan','Canada GAC',      'CANADA',   AlertAuthority.coalition),
  _IgAccount('@dfaboron_au',     'Australia DFAT',  'AUSTRALIA', AlertAuthority.coalition),
  _IgAccount('@farnesina',       'Italy Farnesina', 'ITALY',    AlertAuthority.coalition),
  _IgAccount('@dutchmfa',        'Netherlands MFA', 'NL',       AlertAuthority.coalition),
];

// Build country → accounts index
final Map<String, List<_IgAccount>> _countryAccounts = () {
  final idx = <String, List<_IgAccount>>{};
  for (final a in _instagramGovAccounts) {
    idx.putIfAbsent(a.country, () => []).add(a);
  }
  return idx;
}();

/// Pick an Instagram account based on detected region in headline.
_IgAccount _pickAccountForRegion(String title, Random rng) {
  final lower = title.toLowerCase();
  String? country;

  if (lower.contains('uae') || lower.contains('dubai') || lower.contains('abu dhabi')) {
    country = 'UAE';
  } else if (lower.contains('saudi') || lower.contains('riyadh') || lower.contains('ksa')) {
    country = 'KSA';
  } else if (lower.contains('qatar') || lower.contains('doha')) {
    country = 'QATAR';
  } else if (lower.contains('bahrain') || lower.contains('manama')) {
    country = 'BAHRAIN';
  } else if (lower.contains('kuwait')) {
    country = 'KUWAIT';
  } else if (lower.contains('oman') || lower.contains('muscat')) {
    country = 'OMAN';
  } else if (lower.contains('evacuat') || lower.contains('repatriat') || lower.contains('expat') ||
             lower.contains('embassy closure') || lower.contains('travel advisory') ||
             lower.contains('nationals abroad') || lower.contains('consular') ||
             lower.contains('إجلاء') || lower.contains('رعايا') || lower.contains('تحذير سفر')) {
    // Evacuation / MFA — pick a coalition or GCC MFA account
    final mfaAccounts = _instagramGovAccounts.where((a) =>
      a.displayName.contains('MoFA') || a.displayName.contains('State Dept') ||
      a.displayName.contains('FCDO') || a.displayName.contains('MEAE') ||
      a.displayName.contains('GAC') || a.displayName.contains('DFAT') ||
      a.displayName.contains('Farnesina') || a.displayName.contains('MFA') ||
      a.displayName.contains('AA')).toList();
    return mfaAccounts[rng.nextInt(mfaAccounts.length)];
  }

  if (country != null && _countryAccounts.containsKey(country)) {
    final accounts = _countryAccounts[country]!;
    return accounts[rng.nextInt(accounts.length)];
  }

  // Default: NCEMA UAE
  return _instagramGovAccounts[0];
}

// ── Severity detection (EN + AR) ────────────────────────────────

SocmintSeverity _detectSeverity(String title) {
  final lower = title.toLowerCase();
  // Critical
  if (lower.contains('kill') || lower.contains('strike') || lower.contains('attack') ||
      lower.contains('war') || lower.contains('dead') || lower.contains('breaking') ||
      lower.contains('قتل') || lower.contains('هجوم') || lower.contains('ضربة') ||
      lower.contains('حرب') || lower.contains('evacuation') || lower.contains('evacuate') ||
      lower.contains('إجلاء')) {
    return SocmintSeverity.critical;
  }
  // High
  if (lower.contains('iran') || lower.contains('military') ||
      lower.contains('missile') || lower.contains('bomb') || lower.contains('drone') ||
      lower.contains('صاروخ') || lower.contains('طائرة مسيرة') || lower.contains('عسكري') ||
      lower.contains('repatriation') || lower.contains('travel advisory') ||
      lower.contains('تحذير سفر') || lower.contains('رعايا')) {
    return SocmintSeverity.high;
  }
  // Medium
  if (lower.contains('middle east') || lower.contains('israel') ||
      lower.contains('gaza') || lower.contains('hezbollah') || lower.contains('gulf') ||
      lower.contains('إيران') || lower.contains('حزب الله') || lower.contains('expat') ||
      lower.contains('غزة')) {
    return SocmintSeverity.medium;
  }
  return SocmintSeverity.low;
}

// ── Helpers ──────────────────────────────────────────────────────

final _rng = Random();

String _randomId(String prefix) {
  final ts = DateTime.now().millisecondsSinceEpoch;
  final r = _rng.nextInt(0xFFFF).toRadixString(36);
  return '$prefix-$ts-$r';
}

SocmintItem _headlineToSocmint(Map<String, dynamic> h, double roll) {
  final title = h['title'] as String? ?? '';
  final src = h['source'] as String? ?? '';
  final pubDate = h['pubDate'] as String? ?? '';

  final severity = _detectSeverity(title);

  int ts = DateTime.now().millisecondsSinceEpoch;
  if (pubDate.isNotEmpty) {
    final parsed = DateTime.tryParse(pubDate);
    if (parsed != null) ts = parsed.millisecondsSinceEpoch;
  }

  // 45% X
  if (roll < 0.45) {
    // Check if headline is UAE-related → use official UAE X accounts
    final lowerTitle = title.toLowerCase();
    final isUae = lowerTitle.contains('uae') || lowerTitle.contains('dubai') ||
        lowerTitle.contains('abu dhabi') || lowerTitle.contains('sharjah') ||
        lowerTitle.contains('emirates') || lowerTitle.contains('الإمارات') ||
        lowerTitle.contains('دبي') || lowerTitle.contains('أبوظبي');

    String account;
    if (_sourceToXAccount.containsKey(src)) {
      account = _sourceToXAccount[src]!;
    } else if (isUae) {
      account = _uaeXAccounts[_rng.nextInt(_uaeXAccounts.length)];
    } else {
      account = _osintXAccounts[_rng.nextInt(_osintXAccounts.length)];
    }

    return SocmintItem(
      id: _randomId('socm-x'),
      platform: SocmintPlatform.x,
      source: account,
      content: '$title ($src)',
      timestamp: ts,
      severity: severity,
      language: 'EN',
      location: isUae ? 'UAE' : null,
      flagged: severity == SocmintSeverity.critical,
    );
  }

  // 25% Telegram (0.45 → 0.70)
  if (roll < 0.70) {
    String channel;
    if (src == 'CENTCOM') channel = 't.me/CentcomOfficial';
    else if (src == 'Al Jazeera') channel = 't.me/AJArabic';
    else if (src == 'Reuters') channel = 't.me/reuters';
    else if (src == 'IDF') channel = 't.me/IDFofficial';
    else channel = 't.me/IranDefenseWatch';

    return SocmintItem(
      id: _randomId('socm-tg'),
      platform: SocmintPlatform.telegram,
      source: channel,
      content: title,
      timestamp: ts,
      severity: severity,
      language: 'EN',
      flagged: severity == SocmintSeverity.critical,
    );
  }

  // 20% Instagram (0.70 → 0.90)
  if (roll < 0.90) {
    final account = _pickAccountForRegion(title, _rng);
    return SocmintItem(
      id: _randomId('socm-ig'),
      platform: SocmintPlatform.instagram,
      source: account.handle,
      content: '${account.displayName}: $title',
      timestamp: ts,
      severity: severity,
      language: 'EN',
      location: account.country,
      flagged: severity == SocmintSeverity.critical,
      isOfficialGov: true,
      country: account.country,
    );
  }

  // 10% Snapchat
  String location = 'Middle East';
  final lower = title.toLowerCase();
  if (lower.contains('dubai') || lower.contains('uae')) location = 'Dubai, UAE';
  else if (lower.contains('tehran')) location = 'Tehran, Iran';
  else if (lower.contains('israel') || lower.contains('tel aviv')) location = 'Tel Aviv, Israel';
  else if (lower.contains('kuwait')) location = 'Kuwait City';
  else if (lower.contains('bahrain')) location = 'Manama, Bahrain';
  else if (lower.contains('doha') || lower.contains('qatar')) location = 'Doha, Qatar';
  else if (lower.contains('beirut') || lower.contains('lebanon')) location = 'Beirut, Lebanon';

  return SocmintItem(
    id: _randomId('socm-snap'),
    platform: SocmintPlatform.snapchat,
    source: 'Snap Map $location',
    content: 'Geolocated $location: $title ($src)',
    timestamp: ts,
    severity: severity,
    language: 'EN',
    location: location,
    flagged: severity == SocmintSeverity.critical,
  );
}

SocmintPlatform _parsePlatform(String name) {
  switch (name) {
    case 'telegram':  return SocmintPlatform.telegram;
    case 'snapchat':  return SocmintPlatform.snapchat;
    case 'x':         return SocmintPlatform.x;
    case 'instagram': return SocmintPlatform.instagram;
    default:          return SocmintPlatform.x;
  }
}

SocmintSeverity _parseSeverity(String name) {
  switch (name) {
    case 'critical': return SocmintSeverity.critical;
    case 'high':     return SocmintSeverity.high;
    case 'medium':   return SocmintSeverity.medium;
    default:         return SocmintSeverity.low;
  }
}

SocmintItem _wsToSocmint(Map<String, dynamic> m) {
  return SocmintItem(
    id: m['id'] as String? ?? _randomId('socm'),
    platform: _parsePlatform(m['platform'] as String? ?? 'x'),
    source: m['source'] as String? ?? '',
    content: m['content'] as String? ?? '',
    timestamp: m['timestamp'] as int? ?? DateTime.now().millisecondsSinceEpoch,
    severity: _parseSeverity(m['severity'] as String? ?? 'low'),
    language: m['language'] as String? ?? 'EN',
    location: m['location'] as String?,
    flagged: m['flagged'] as bool? ?? false,
    imageUrl: m['imageUrl'] as String?,
    isOfficialGov: m['isOfficialGov'] as bool? ?? false,
    country: m['country'] as String?,
  );
}

// ── StateNotifier ────────────────────────────────────────────────

class SocmintNotifier extends StateNotifier<List<SocmintItem>> {
  SocmintNotifier(this._ref, {this.maxItems = 50}) : super([]) {
    _init();
  }

  final Ref _ref;
  final int maxItems;
  Timer? _headlineTimer;
  final Set<String> _injected = {};
  final Set<String> _seenIds = {};

  StreamSubscription? _wsInitSub;
  StreamSubscription? _wsSocmintSub;
  StreamSubscription? _wsHeadlinesSub;
  StreamSubscription? _wsConnSub;

  void _init() {
    final ws = BreachSocketService.instance;

    // ── WS init (seed) ──────────────────────────────────────────
    _wsInitSub = ws.channel(WsMessageType.init).listen((data) {
      if (!mounted) return;
      final json = data as Map<String, dynamic>;
      final socmint = json['socmint'] as List<dynamic>?;
      if (socmint == null || socmint.isEmpty) return;

      final parsed = <SocmintItem>[];
      for (final raw in socmint) {
        try {
          final m = raw as Map<String, dynamic>;
          final item = _wsToSocmint(m);
          if (_seenIds.add(item.id)) parsed.add(item);
        } catch (_) {}
      }
      if (parsed.isNotEmpty) state = parsed.take(maxItems).toList();
    });

    // ── WS live socmint ─────────────────────────────────────────
    _wsSocmintSub = ws.channel(WsMessageType.socmint).listen((data) {
      if (!mounted) return;
      try {
        final item = _wsToSocmint(data as Map<String, dynamic>);
        if (!_seenIds.add(item.id)) return;
        state = [item, ...state].take(maxItems).toList();
      } catch (_) {}
    });

    // ── WS headlines (transform to SOCMINT locally) ─────────────
    _wsHeadlinesSub = ws.channel(WsMessageType.headlines).listen((data) {
      if (!mounted) return;
      _processHeadlines(data as List<dynamic>);
    });

    // ── Connection fallback ─────────────────────────────────────
    _wsConnSub = ws.connectionStream.listen((connected) {
      if (connected) {
        _headlineTimer?.cancel();
        _headlineTimer = null;
      } else {
        _startHttpPolling();
      }
    });

    if (!ws.connected) _startHttpPolling();
  }

  void _processHeadlines(List<dynamic> headlines) {
    final newOnes = headlines.where((h) {
      final title = (h as Map<String, dynamic>)['title'] as String? ?? '';
      return title.isNotEmpty && !_injected.contains(title);
    }).toList();
    if (newOnes.isEmpty) return;

    final items = newOnes.map((h) {
      final title = (h as Map<String, dynamic>)['title'] as String? ?? '';
      _injected.add(title);
      return _headlineToSocmint(h, _rng.nextDouble());
    }).toList();

    final merged = [...items, ...state];
    merged.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    state = merged.take(maxItems).toList();
  }

  void _startHttpPolling() {
    _fetchLiveHeadlines();
    _headlineTimer ??= Timer.periodic(const Duration(seconds: 30), (_) => _fetchLiveHeadlines());
  }

  Future<void> _fetchLiveHeadlines() async {
    try {
      final headlines = await HeadlinesService.instance.fetchHeadlines();
      if (headlines.isEmpty || !mounted) return;
      final newOnes = headlines.where((h) {
        final title = h['title'] as String? ?? '';
        return title.isNotEmpty && !_injected.contains(title);
      }).toList();
      if (newOnes.isEmpty) return;
      final items = newOnes.map((h) {
        final title = h['title'] as String? ?? '';
        _injected.add(title);
        return _headlineToSocmint(h, _rng.nextDouble());
      }).toList();
      final merged = [...items, ...state];
      merged.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      state = merged.take(maxItems).toList();
    } catch (_) {}
  }

  @override
  void dispose() {
    _headlineTimer?.cancel();
    _wsInitSub?.cancel();
    _wsSocmintSub?.cancel();
    _wsHeadlinesSub?.cancel();
    _wsConnSub?.cancel();
    super.dispose();
  }
}

final socmintProvider =
    StateNotifierProvider<SocmintNotifier, List<SocmintItem>>((ref) {
  return SocmintNotifier(ref);
});
