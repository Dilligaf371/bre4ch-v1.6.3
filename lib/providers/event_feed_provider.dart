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

// ── RFC 2822 date parser (shared with osint_provider) ────────────
/// Parses dates in RFC 2822 format (standard RSS), ISO 8601, or common
/// variants. Returns null if the string cannot be parsed at all.
///
/// Supported formats:
///   "Wed, 08 Mar 2026 12:00:00 +0000"  (RFC 2822)
///   "Wed, 08 Mar 2026 12:00:00 GMT"
///   "8 Mar 2026 12:00:00 +0400"
///   "2026-03-08T12:00:00Z"             (ISO 8601)
///   "2026-03-08"                        (date only)
DateTime? _parseDateRobust(String input) {
  if (input.isEmpty) return null;

  // Try ISO 8601 first (fast path)
  final iso = DateTime.tryParse(input);
  if (iso != null) return iso.toUtc();

  // RFC 2822 month abbreviation map
  const months = {
    'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4, 'may': 5, 'jun': 6,
    'jul': 7, 'aug': 8, 'sep': 9, 'oct': 10, 'nov': 11, 'dec': 12,
  };

  // Strip optional day-name prefix: "Wed, " or "Wednesday, "
  var s = input.trim();
  final commaIdx = s.indexOf(',');
  if (commaIdx >= 0 && commaIdx <= 10) s = s.substring(commaIdx + 1).trim();

  // Pattern: DD Mon YYYY HH:MM:SS ±HHMM | GMT | UTC | Z
  final rx = RegExp(
    r'(\d{1,2})\s+([A-Za-z]{3,})\s+(\d{4})'
    r'(?:\s+(\d{1,2}):(\d{2})(?::(\d{2}))?)?'
    r'(?:\s*([+-]\d{4}|[A-Z]{2,4}))?',
  );
  final m = rx.firstMatch(s);
  if (m == null) return null;

  final day = int.tryParse(m.group(1)!) ?? 0;
  final monStr = (m.group(2)!).toLowerCase().substring(0, 3);
  final month = months[monStr];
  if (month == null) return null;
  final year = int.tryParse(m.group(3)!) ?? 0;
  final hour = int.tryParse(m.group(4) ?? '0') ?? 0;
  final min = int.tryParse(m.group(5) ?? '0') ?? 0;
  final sec = int.tryParse(m.group(6) ?? '0') ?? 0;

  if (year < 2020 || day < 1 || day > 31) return null;

  var dt = DateTime.utc(year, month, day, hour, min, sec);

  // Apply timezone offset if present (e.g., +0400 → subtract 4h to get UTC)
  final tz = m.group(7) ?? '';
  if (tz.isNotEmpty && tz != 'UTC' && tz != 'GMT' && tz != 'Z') {
    final tzRx = RegExp(r'^([+-])(\d{2})(\d{2})$');
    final tzM = tzRx.firstMatch(tz);
    if (tzM != null) {
      final sign = tzM.group(1) == '+' ? 1 : -1;
      final tzH = int.parse(tzM.group(2)!);
      final tzMin = int.parse(tzM.group(3)!);
      dt = dt.subtract(Duration(hours: sign * tzH, minutes: sign * tzMin));
    }
  }

  return dt;
}

// ── Persistence constants ────────────────────────────────────────
const String _eventCacheKey = 'event_cache_v2'; // v2: strict conflict filter
/// Retention: from mission start (28 Feb 2026) onward. ~365 days is plenty.
const int _eventRetentionDays = 365;

// ── Mission start hard gate ─────────────────────────────────────
/// Reject ALL events before the Iran conflict started.
final int _missionStartMs = DateTime.utc(2026, 2, 28, 2, 0, 0).millisecondsSinceEpoch;

// ── Priority sources (trusted — bypass keyword filter) ──────────
const Set<String> _prioritySources = {
  '@modgovae', 'modgovae', 'MOD UAE', 'MOD UAE 🇦🇪',
  '@CENTCOM', 'CENTCOM', 'centcom',
  '@IDF', 'IDF', 'idf',
};
const int _maxCachedEvents = 10000;

// ── Source URL mapping ───────────────────────────────────────────

const Map<String, Map<String, String>> _sourceUrls = {
  // ── News agencies ──
  'CENTCOM':    {'name': 'CENTCOM',    'url': 'https://www.centcom.mil'},
  'Reuters':    {'name': 'Reuters',    'url': 'https://www.reuters.com/world/middle-east/'},
  'Al Jazeera': {'name': 'Al Jazeera', 'url': 'https://www.aljazeera.com/tag/iran/'},
  'AP':         {'name': 'AP News',    'url': 'https://apnews.com/hub/iran'},
  'IDF':        {'name': 'IDF',        'url': 'https://www.idf.il'},
  'DoD':        {'name': 'DoD',        'url': 'https://www.defense.gov'},
  'BBC':        {'name': 'BBC',        'url': 'https://www.bbc.com/news/world/middle_east'},
  // ── X (Twitter) — UAE ──
  '@modgovae':      {'name': 'MOD UAE 🇦🇪',     'url': 'https://x.com/modgovae'},
  '@ABORON_uae':    {'name': 'MOI UAE 🇦🇪',     'url': 'https://x.com/ABORON_uae'},
  '@ABORON_ncema':  {'name': 'NCEMA 🇦🇪',       'url': 'https://x.com/ABORON_ncema'},
  '@WAaboron':      {'name': 'WAM 🇦🇪',         'url': 'https://x.com/WAaboron'},
  '@MoFAICaboron':  {'name': 'MoFA UAE 🇦🇪',    'url': 'https://x.com/MoFAICaboron'},
  '@HaboronZayed':  {'name': 'Presidency UAE 🇦🇪','url': 'https://x.com/HaboronZayed'},
  // ── X — KSA ──
  '@modaboron_sa':  {'name': 'MOD KSA 🇸🇦',     'url': 'https://x.com/modaboron_sa'},
  '@moaboron_sa':   {'name': 'MOI KSA 🇸🇦',     'url': 'https://x.com/moaboron_sa'},
  '@kaboron_sa':    {'name': 'MoFA KSA 🇸🇦',    'url': 'https://x.com/kaboron_sa'},
  '@SPAaboron':     {'name': 'SPA 🇸🇦',         'url': 'https://x.com/SPAaboron'},
  // ── X — Kuwait ──
  '@modkuwait':     {'name': 'MOD Kuwait 🇰🇼',  'url': 'https://x.com/modkuwait'},
  '@moaboron_kw':   {'name': 'MOI Kuwait 🇰🇼',  'url': 'https://x.com/moaboron_kw'},
  '@maboron_kw':    {'name': 'MoFA Kuwait 🇰🇼', 'url': 'https://x.com/maboron_kw'},
  // ── X — Bahrain ──
  '@moaboron_bh':   {'name': 'MOI Bahrain 🇧🇭', 'url': 'https://x.com/moaboron_bh'},
  '@maboron_bh':    {'name': 'MoFA Bahrain 🇧🇭','url': 'https://x.com/maboron_bh'},
  '@BDFaboron':     {'name': 'MOD Bahrain 🇧🇭', 'url': 'https://x.com/BDFaboron'},
  // ── X — Qatar ──
  '@moaboron_qa':   {'name': 'MOI Qatar 🇶🇦',   'url': 'https://x.com/moaboron_qa'},
  '@moaboron_qa_mfa':{'name': 'MoFA Qatar 🇶🇦', 'url': 'https://x.com/moaboron_qa_mfa'},
  '@QNAaboron':     {'name': 'QNA 🇶🇦',         'url': 'https://x.com/QNAaboron'},
  // ── X — Oman ──
  '@moaboron_om':   {'name': 'MOD Oman 🇴🇲',    'url': 'https://x.com/moaboron_om'},
  '@maboron_om':    {'name': 'MoFA Oman 🇴🇲',   'url': 'https://x.com/maboron_om'},
  '@OMAaboron':     {'name': 'ONA 🇴🇲',         'url': 'https://x.com/OMAaboron'},
  // ── X — Jordan ──
  '@AFJordan':      {'name': 'MOD Jordan 🇯🇴',  'url': 'https://x.com/AFJordan'},
  '@PetraNewsAgency':{'name': 'Petra 🇯🇴',      'url': 'https://x.com/PetraNewsAgency'},
  // ── X — Lebanon ──
  '@LAFaboron':     {'name': 'MOD Lebanon 🇱🇧', 'url': 'https://x.com/LAFaboron'},
  '@NNAaboron':     {'name': 'NNA 🇱🇧',         'url': 'https://x.com/NNAaboron'},
  // ── X — Israel ──
  '@IDF':           {'name': 'IDF 🇮🇱',          'url': 'https://x.com/IDF'},
  '@IsraelMFA':     {'name': 'MoFA Israel 🇮🇱', 'url': 'https://x.com/IsraelMFA'},
  '@Israel':        {'name': 'Israel 🇮🇱',       'url': 'https://x.com/Israel'},
  // ── X — Iran ──
  '@IRGCaboron':    {'name': 'IRGC 🇮🇷',        'url': 'https://x.com/IRGCaboron'},
  '@IranMilitary':  {'name': 'MOD Iran 🇮🇷',    'url': 'https://x.com/IranMilitary'},
  // ── X — Coalition / Military ──
  '@CENTCOM':       {'name': 'CENTCOM',          'url': 'https://x.com/CENTCOM'},
  '@DeptofDefense': {'name': 'DoD 🇺🇸',         'url': 'https://x.com/DeptofDefense'},
  '@statedept':     {'name': 'State Dept 🇺🇸',  'url': 'https://x.com/statedept'},
  '@foreignoffice': {'name': 'FCDO 🇬🇧',        'url': 'https://x.com/foreignoffice'},
  '@francediplo':   {'name': 'MEAE 🇫🇷',        'url': 'https://x.com/francediplo'},
  '@NATO':          {'name': 'NATO',             'url': 'https://x.com/NATO'},
  // ── X — OSINT ──
  '@Conflicts':     {'name': 'X @Conflicts',    'url': 'https://x.com/Conflicts'},
  '@IntelCrab':     {'name': 'X @IntelCrab',    'url': 'https://x.com/IntelCrab'},
  '@sentdefender':  {'name': 'X @sentdefender', 'url': 'https://x.com/sentdefender'},
  '@OSINTdefender': {'name': 'X @OSINTdefender','url': 'https://x.com/OSINTdefender'},
  '@ELINTNews':     {'name': 'X @ELINTNews',   'url': 'https://x.com/ELINTNews'},
  // ── Instagram — official gov accounts ──
  'ncaboron':       {'name': 'NCEMA IG 🇦🇪',    'url': 'https://instagram.com/ncaboron'},
  'moiuae':         {'name': 'MOI IG 🇦🇪',      'url': 'https://instagram.com/moiuae'},
  'modgovae':       {'name': 'MOD IG 🇦🇪',      'url': 'https://instagram.com/modgovae'},
  'maboron_uae':    {'name': 'MoFA IG 🇦🇪',     'url': 'https://instagram.com/maboron_uae'},
  'modaboron_sa':   {'name': 'MOD IG 🇸🇦',      'url': 'https://instagram.com/modaboron_sa'},
  'moaboron_sa':    {'name': 'MOI IG 🇸🇦',      'url': 'https://instagram.com/moaboron_sa'},
  'moaboron_qa':    {'name': 'MOI IG 🇶🇦',      'url': 'https://instagram.com/moaboron_qa'},
  'moaboron_bh':    {'name': 'MOI IG 🇧🇭',      'url': 'https://instagram.com/moaboron_bh'},
  'moaboron_kw':    {'name': 'MOI IG 🇰🇼',      'url': 'https://instagram.com/moaboron_kw'},
  'modkuwait':      {'name': 'MOD IG 🇰🇼',      'url': 'https://instagram.com/modkuwait'},
  'moaboron_om':    {'name': 'MOD IG 🇴🇲',      'url': 'https://instagram.com/moaboron_om'},
};

// ── Official GOV handles (lowercase) for socmint→event bridge ────

final Set<String> _officialGovHandles = _sourceUrls.keys
    .where((k) => k.startsWith('@') || !k.contains(' '))
    .where((k) => k != 'CENTCOM' && k != 'Reuters' && k != 'Al Jazeera' &&
                   k != 'AP' && k != 'IDF' && k != 'DoD' && k != 'BBC')
    .map((k) => k.toLowerCase())
    .toSet();

// ── (GOV source detection removed — was randomly misattributing RSS
//    headlines to X/IG accounts. Real GOV posts are correctly handled
//    by _socmintGovToEvent via the WS socmint channel.) ──────────

// ── Conflict relevance filter ────────────────────────────────────
// STRICT: country/city names alone are NOT enough to pass.
// At least one actual military/conflict term is required.
// Country names are used ONLY in _detectTargetRegion for labeling.

const List<String> _conflictTerms = [
  // ── Core conflict terms ──
  'iran', 'israel', 'military', 'strike', 'missile', 'kill', 'attack', 'war',
  'drone', 'bomb', 'nuclear', 'hezbollah', 'gaza', 'navy', 'air force',
  'centcom', 'intercept', 'defense', 'defence', 'houthi', 'yemen', 'lebanon',
  'coalition', 'nato', 'pentagon', 'pmf', 'irgc', 'quds',
  // ── Extended military terms ──
  'ballistic', 'cruise missile', 'artillery', 'rocket', 'shell', 'mortar',
  'airstrike', 'airbase', 'warship', 'submarine', 'torpedo', 'shrapnel',
  'bunker', 'convoy', 'checkpoint', 'ceasefire', 'truce', 'invasion',
  'occupation', 'blockade', 'embargo', 'militia', 'insurgent', 'weapon',
  'ammunition', 'explosive', 'detonate', 'crater', 'debris', 'casualties',
  'wounded', 'martyr', 'shahid', 'retaliat', 'escalat', 'deploy', 'sanction',
  'sabotage', 'operation', 'evacuate', 'shelter', 'siren', 'alert', 'raid',
  'target', 'threat', 'combat', 'troops', 'infantry', 'armor', 'tank',
  'patriot missile', 'patriot battery', 'patriot system', 'thaad',
  'iron dome', 'arrow', 'air defense', 'shot down',
  'proxy', 'terror', 'hostage', 'negotiat', 'diplomat', 'ultimatum',
  // ── Arabic conflict terms ──
  'هجوم', 'صاروخ', 'طائرة مسيرة', 'ضربة', 'قتل', 'حرب', 'إجلاء',
  'دفاع', 'اعتراض', 'نووي', 'غارة', 'قصف', 'حصار', 'شهيد',
  'عسكري', 'جيش', 'درون', 'صاروخ باليستي', 'إيران',
  // ── Ministry/defense announcements ──
  'ministry of defense', 'ministry of interior', 'foreign affairs',
  'وزارة الدفاع', 'وزارة الداخلية', 'وزارة الخارجية',
];

// ── Exclusion terms (reject false positives: sport, entertainment, etc.) ──
const List<String> _exclusionTerms = [
  'football', 'soccer', 'player', 'coach', 'league', 'match', 'fixture',
  'goal', 'score', 'tournament', 'championship', 'cup final', 'transfer',
  'cricket', 'tennis', 'basketball', 'olympics', 'athlete', 'stadium',
  'entertainer', 'concert', 'album', 'movie', 'film', 'actor', 'actress',
  'recipe', 'cooking', 'fashion', 'celebrity', 'reality show',
];

/// Check if text is conflict-relevant (requires military terms + no exclusion).
bool _isConflictRelevant(String text) {
  final lower = text.toLowerCase();
  // Reject if any exclusion term is present (sport, entertainment, etc.)
  if (_exclusionTerms.any((kw) => lower.contains(kw))) return false;
  return _conflictTerms.any((kw) => lower.contains(kw));
}

/// Check if a source is a priority/trusted source (bypasses keyword filter).
bool _isPrioritySource(String source) {
  final lower = source.toLowerCase();
  return _prioritySources.any((p) => lower.contains(p.toLowerCase()));
}

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

/// MED-04: Content-based hash for deduplication.
/// Uses normalized title only (lowered, trimmed, no trailing punctuation).
/// Source and date are excluded to catch duplicates arriving from different
/// channels or with slightly different timestamps.
String _contentHash(String title, String source, String date) {
  // Normalize: lowercase, trim whitespace, strip trailing ellipsis/punctuation
  final normalized = title.toLowerCase().trim()
      .replaceAll(RegExp(r'[\s]+'), ' ')       // collapse whitespace
      .replaceAll(RegExp(r'[…\.]+$'), '')       // strip trailing ...
      .replaceAll(RegExp(r'https?://\S+'), ''); // strip URLs
  final input = '$normalized|${source.toLowerCase()}';
  return sha256.convert(utf8.encode(input)).toString().substring(0, 16);
}

// ── Convert live headline to AttackEvent ─────────────────────────

AttackEvent? _liveHeadlineToEvent(Map<String, dynamic> h) {
  final title = h['title'] as String? ?? '';
  final src = h['source'] as String? ?? '';
  final pubDate = h['pubDate'] as String? ?? '';
  final link = h['link'] as String? ?? '';

  final lower = title.toLowerCase();

  AttackType type = AttackType.general;
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

  // Source attribution: always use the actual RSS feed source.
  // GOV labels (MOD UAE, etc.) are only applied to posts that arrive
  // through the socmint channel (real X/IG posts from _socmintGovToEvent).
  // Headlines from news agencies (WAM, Reuters, etc.) keep their real source.
  final srcInfo = _sourceUrls[src] ?? {'name': src, 'url': ''};

  // Parse date robustly (handles RFC 2822 from RSS + ISO 8601).
  // Fall back to DateTime.now() only if pubDate is empty or truly unparseable.
  int ts = DateTime.now().millisecondsSinceEpoch;
  if (pubDate.isNotEmpty) {
    final parsed = _parseDateRobust(pubDate);
    if (parsed != null) ts = parsed.millisecondsSinceEpoch;
  }

  // ── DATE GATE: reject events before mission start (28 Feb 2026) ──
  if (ts < _missionStartMs) return null;

  return AttackEvent(
    id: _randomId('live-evt'),
    timestamp: ts,
    type: type,
    origin: src,
    target: _detectTargetRegion(title),
    status: status,
    details: title,
    source: srcInfo['name'],
    sourceUrl: link.isNotEmpty ? link : (srcInfo['url'] ?? ''),
  );
}

// ── Convert LiveUAMap event to AttackEvent ───────────────────────

AttackEvent _liveuamapToEvent(Map<String, dynamic> e) {
  final name = e['name'] as String? ?? '';
  final source = e['source'] as String? ?? 'LiveUAMap';
  final url = e['url'] as String? ?? '';
  final time = e['time'] as int? ?? 0;

  final lower = name.toLowerCase();
  AttackType type = AttackType.general;
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

// ── Convert SOCMINT GOV post to AttackEvent ─────────────────────

AttackEvent? _socmintGovToEvent(Map<String, dynamic> m) {
  final platform = m['platform'] as String? ?? '';
  final source = m['source'] as String? ?? '';
  final content = m['content'] as String? ?? '';
  final timestamp = m['timestamp'] as int? ?? DateTime.now().millisecondsSinceEpoch;

  if (platform != 'x' && platform != 'instagram') return null;

  // Only bridge official GOV accounts
  final normalized = source.toLowerCase();
  if (!_officialGovHandles.contains(normalized)) return null;

  // Date gate: reject pre-war posts
  if (timestamp < _missionStartMs) return null;

  // Priority sources (@modgovae, CENTCOM, IDF): pass everything
  // Other GOV accounts: require at least one conflict term
  final lowerContent = content.toLowerCase();
  if (!_isPrioritySource(source) && !_isConflictRelevant(lowerContent)) {
    return null;
  }

  // Lookup display name from _sourceUrls (try original case, then lowercase)
  final srcInfo = _sourceUrls[source] ??
      _sourceUrls[normalized] ??
      {'name': source, 'url': platform == 'x'
          ? 'https://x.com/${source.replaceAll('@', '')}'
          : 'https://instagram.com/${source.replaceAll('@', '')}'};

  // Detect attack type
  AttackType type = AttackType.general;
  if (lowerContent.contains('drone') || lowerContent.contains('uav')) {
    type = AttackType.drone;
  } else if (lowerContent.contains('missile') || lowerContent.contains('ballistic') ||
             lowerContent.contains('rocket')) {
    type = AttackType.ballistic;
  } else if (lowerContent.contains('cyber') || lowerContent.contains('hack')) {
    type = AttackType.cyber;
  } else if (lowerContent.contains('artillery') || lowerContent.contains('shell')) {
    type = AttackType.artillery;
  }

  EventStatus status = EventStatus.ongoing;
  if (lowerContent.contains('intercept') || lowerContent.contains('shot down')) {
    status = EventStatus.intercepted;
  } else if (lowerContent.contains('hit') || lowerContent.contains('struck') ||
             lowerContent.contains('killed') || lowerContent.contains('destroyed')) {
    status = EventStatus.impact;
  } else if (lowerContent.contains('neutraliz')) {
    status = EventStatus.neutralized;
  }

  // Include platform in source name so X/IG filters detect it.
  String displayName = srcInfo['name'] ?? source;
  if (platform == 'x' && !displayName.startsWith('X ') && !displayName.contains('@')) {
    displayName = 'X $displayName';
  }

  return AttackEvent(
    id: _randomId('gov-evt'),
    timestamp: timestamp,
    type: type,
    origin: platform == 'x' ? 'X $source' : 'IG $source',
    target: _detectTargetRegion(content),
    status: status,
    details: content,
    source: displayName,
    sourceUrl: srcInfo['url'],
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
  StreamSubscription? _wsSocmintSub;
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
          // Hard gate: only load events after mission start
          if (evt.timestamp >= _missionStartMs &&
              evt.timestamp >= cutoff &&
              _seenIds.add(evt.id)) {
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
    // Hard gate: only events after mission start AND within retention window
    state = merged
        .where((e) => e.timestamp >= _missionStartMs && e.timestamp >= cutoff)
        .take(_maxCachedEvents)
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

    // ── Subscribe to WS socmint (bridge GOV posts → events) ─────
    _wsSocmintSub = ws.channel(WsMessageType.socmint).listen((data) {
      if (!mounted) return;
      try {
        final evt = _socmintGovToEvent(data as Map<String, dynamic>);
        if (evt == null) return;
        final hash = _contentHash(evt.details, evt.source ?? '', '');
        if (_injected.contains(hash)) return; // dedupe
        _injected.add(hash);
        _mergeAndUpdate([evt]);
      } catch (_) {}
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
      final title = (map['title'] as String? ?? '');
      final src = (map['source'] as String? ?? '');
      // Priority sources always pass; others need conflict terms
      return _isPrioritySource(src) || _isConflictRelevant(title);
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

    final events = newOnes
        .map((h) => _liveHeadlineToEvent(h as Map<String, dynamic>))
        .whereType<AttackEvent>() // filter out nulls (pre-war date gate)
        .toList();
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
        final title = (h['title'] as String? ?? '');
        final src = (h['source'] as String? ?? '');
        return _isPrioritySource(src) || _isConflictRelevant(title);
      }).toList();

      final newOnes = relevant.where((h) {
        final title = h['title'] as String? ?? '';
        final source = h['source'] as String? ?? '';
        final date = h['pubDate'] as String? ?? '';
        final hash = _contentHash(title, source, date);
        return title.isNotEmpty && !_injected.contains(hash);
      }).toList();
      if (newOnes.isEmpty) return;

      final events = newOnes
          .map(_liveHeadlineToEvent)
          .whereType<AttackEvent>()
          .toList();
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
