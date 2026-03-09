// ── Event Feed Helpers Tests ─────────────────────────────────────
// Tests for parseDateRobust, isConflictRelevant, isPrioritySource,
// detectTargetRegion, contentHash, liveHeadlineToEvent, etc.

import 'package:flutter_test/flutter_test.dart';
import 'package:breach/utils/event_feed_helpers.dart';
import 'package:breach/models/attack_event.dart';

void main() {
  // ── parseDateRobust ───────────────────────────────────────────

  group('parseDateRobust', () {
    test('parses ISO 8601 date-time', () {
      final dt = parseDateRobust('2026-03-08T12:00:00Z');
      expect(dt, isNotNull);
      expect(dt!.year, 2026);
      expect(dt.month, 3);
      expect(dt.day, 8);
      expect(dt.hour, 12);
      expect(dt.isUtc, isTrue);
    });

    test('parses ISO 8601 date only', () {
      // Date-only ISO strings are parsed as local time then converted to UTC,
      // so the day may shift depending on system timezone.
      final dt = parseDateRobust('2026-03-08');
      expect(dt, isNotNull);
      expect(dt!.year, 2026);
      expect(dt.month, 3);
      expect(dt.isUtc, isTrue);
    });

    test('parses RFC 2822 with day name', () {
      final dt = parseDateRobust('Sat, 08 Mar 2026 14:30:00 +0000');
      expect(dt, isNotNull);
      expect(dt!.year, 2026);
      expect(dt.month, 3);
      expect(dt.day, 8);
      expect(dt.hour, 14);
      expect(dt.minute, 30);
    });

    test('parses RFC 2822 without day name', () {
      final dt = parseDateRobust('08 Mar 2026 12:00:00 +0000');
      expect(dt, isNotNull);
      expect(dt!.day, 8);
      expect(dt.month, 3);
    });

    test('parses RFC 2822 with GMT timezone', () {
      final dt = parseDateRobust('Wed, 05 Mar 2026 09:00:00 GMT');
      expect(dt, isNotNull);
      expect(dt!.hour, 9);
      expect(dt.isUtc, isTrue);
    });

    test('applies positive timezone offset correctly', () {
      // +0400 means UTC+4, so 16:00+0400 = 12:00 UTC
      final dt = parseDateRobust('08 Mar 2026 16:00:00 +0400');
      expect(dt, isNotNull);
      expect(dt!.hour, 12);
      expect(dt.isUtc, isTrue);
    });

    test('applies negative timezone offset correctly', () {
      // -0500 means UTC-5, so 07:00-0500 = 12:00 UTC
      final dt = parseDateRobust('08 Mar 2026 07:00:00 -0500');
      expect(dt, isNotNull);
      expect(dt!.hour, 12);
    });

    test('parses full day name (Wednesday)', () {
      final dt = parseDateRobust('Wednesday, 08 Mar 2026 12:00:00 +0000');
      expect(dt, isNotNull);
      expect(dt!.day, 8);
    });

    test('parses date without time', () {
      final dt = parseDateRobust('08 Mar 2026');
      expect(dt, isNotNull);
      expect(dt!.hour, 0);
      expect(dt.minute, 0);
    });

    test('returns null for empty string', () {
      expect(parseDateRobust(''), isNull);
    });

    test('returns null for garbage input', () {
      expect(parseDateRobust('not a date'), isNull);
      expect(parseDateRobust('abc123'), isNull);
    });

    test('rejects years before 2020', () {
      expect(parseDateRobust('08 Mar 2019 12:00:00 +0000'), isNull);
    });

    test('rejects invalid day numbers', () {
      expect(parseDateRobust('0 Mar 2026 12:00:00 +0000'), isNull);
      expect(parseDateRobust('32 Mar 2026 12:00:00 +0000'), isNull);
    });

    test('handles case-insensitive month names', () {
      final dt = parseDateRobust('08 MAR 2026 12:00:00 +0000');
      expect(dt, isNotNull);
      expect(dt!.month, 3);
    });
  });

  // ── isConflictRelevant ────────────────────────────────────────

  group('isConflictRelevant', () {
    test('detects core conflict terms', () {
      expect(isConflictRelevant('Iran launches missile strike'), isTrue);
      expect(isConflictRelevant('drone attack reported'), isTrue);
      expect(isConflictRelevant('CENTCOM releases statement'), isTrue);
      expect(isConflictRelevant('hezbollah ceasefire negotiations'), isTrue);
    });

    test('detects Arabic conflict terms', () {
      expect(isConflictRelevant('صاروخ يستهدف القاعدة'), isTrue);
      expect(isConflictRelevant('هجوم بطائرة مسيرة'), isTrue);
    });

    test('rejects non-conflict text', () {
      expect(isConflictRelevant('weather forecast for tomorrow'), isFalse);
      expect(isConflictRelevant('new restaurant opening'), isFalse);
    });

    test('rejects sports false positives (exclusion terms)', () {
      expect(isConflictRelevant('Iran football player scores goal in league match'), isFalse);
      expect(isConflictRelevant('military-style tournament championship'), isFalse);
      expect(isConflictRelevant('Iran cricket team wins championship'), isFalse);
    });

    test('exclusion terms override conflict terms', () {
      // Contains both 'attack' (conflict) and 'soccer' (exclusion)
      expect(isConflictRelevant('soccer player attack on the pitch'), isFalse);
    });

    test('is case-insensitive', () {
      expect(isConflictRelevant('MISSILE STRIKE CONFIRMED'), isTrue);
      expect(isConflictRelevant('Drone Attack'), isTrue);
    });

    test('detects partial matches (retaliat, escalat)', () {
      expect(isConflictRelevant('Iran retaliates against Israel'), isTrue);
      expect(isConflictRelevant('conflict escalation feared'), isTrue);
    });
  });

  // ── isPrioritySource ──────────────────────────────────────────

  group('isPrioritySource', () {
    test('recognizes MOD UAE handle', () {
      expect(isPrioritySource('@modgovae'), isTrue);
      expect(isPrioritySource('modgovae'), isTrue);
    });

    test('recognizes CENTCOM', () {
      expect(isPrioritySource('CENTCOM'), isTrue);
      expect(isPrioritySource('@CENTCOM'), isTrue);
    });

    test('recognizes IDF', () {
      expect(isPrioritySource('IDF'), isTrue);
      expect(isPrioritySource('@IDF'), isTrue);
    });

    test('is case-insensitive', () {
      expect(isPrioritySource('centcom'), isTrue);
      expect(isPrioritySource('MODGOVAE'), isTrue);
    });

    test('rejects non-priority sources', () {
      expect(isPrioritySource('Reuters'), isFalse);
      expect(isPrioritySource('BBC'), isFalse);
      expect(isPrioritySource('@random_user'), isFalse);
    });
  });

  // ── detectTargetRegion ────────────────────────────────────────

  group('detectTargetRegion', () {
    test('detects UAE cities and names', () {
      expect(detectTargetRegion('explosion near Dubai airport'), 'UAE');
      expect(detectTargetRegion('Abu Dhabi air defense activated'), 'UAE');
      expect(detectTargetRegion('UAE military responds'), 'UAE');
      expect(detectTargetRegion('Sharjah residents evacuated'), 'UAE');
    });

    test('detects Iran', () {
      expect(detectTargetRegion('Tehran under alert'), 'Iran');
      expect(detectTargetRegion('Isfahan nuclear facility'), 'Iran');
    });

    test('detects Israel', () {
      expect(detectTargetRegion('Tel Aviv sirens sounding'), 'Israel');
      expect(detectTargetRegion('Jerusalem on alert'), 'Israel');
    });

    test('detects KSA', () {
      expect(detectTargetRegion('Saudi Arabia border alert'), 'KSA');
      expect(detectTargetRegion('Riyadh missile defense'), 'KSA');
    });

    test('detects smaller Gulf states', () {
      expect(detectTargetRegion('Kuwait airspace closed'), 'Kuwait');
      expect(detectTargetRegion('Bahrain naval base'), 'Bahrain');
      expect(detectTargetRegion('Doha diplomats meet'), 'Qatar');
      expect(detectTargetRegion('Oman Muscat quiet'), 'Oman');
    });

    test('detects Levant/Iraq', () {
      expect(detectTargetRegion('Lebanon Beirut explosion'), 'Lebanon');
      expect(detectTargetRegion('Iraq Baghdad PMF'), 'Iraq');
      expect(detectTargetRegion('Syria Damascus shelling'), 'Syria');
      expect(detectTargetRegion('Yemen Houthi drone'), 'Yemen');
    });

    test('detects Western allies', () {
      expect(detectTargetRegion('Pentagon statement released'), 'USA');
      expect(detectTargetRegion('Britain condemns attack'), 'UK');
      expect(detectTargetRegion('French military deploys'), 'France');
    });

    test('defaults to Iran Theater for unrecognized text', () {
      expect(detectTargetRegion('unknown location event'), 'Iran Theater');
    });

    test('matches first region found (priority order)', () {
      // UAE checked before Iran
      expect(detectTargetRegion('UAE Iran tensions rise'), 'UAE');
    });
  });

  // ── contentHash ───────────────────────────────────────────────

  group('contentHash', () {
    test('produces consistent hash for same input', () {
      final h1 = contentHash('Missile strike reported', 'Reuters', '');
      final h2 = contentHash('Missile strike reported', 'Reuters', '');
      expect(h1, h2);
    });

    test('is case-insensitive on title and source', () {
      final h1 = contentHash('MISSILE STRIKE', 'REUTERS', '');
      final h2 = contentHash('missile strike', 'reuters', '');
      expect(h1, h2);
    });

    test('normalizes whitespace', () {
      final h1 = contentHash('missile  strike   reported', 'Reuters', '');
      final h2 = contentHash('missile strike reported', 'Reuters', '');
      expect(h1, h2);
    });

    test('strips trailing ellipsis', () {
      final h1 = contentHash('Breaking news...', 'Reuters', '');
      final h2 = contentHash('Breaking news', 'Reuters', '');
      expect(h1, h2);
    });

    test('strips URLs from title', () {
      // URL-only title should hash same as empty title (URL fully removed)
      final urlOnly = contentHash('https://example.com/article', 'Reuters', '');
      final empty = contentHash('', 'Reuters', '');
      expect(urlOnly, empty);
    });

    test('different titles produce different hashes', () {
      final h1 = contentHash('Missile launch', 'Reuters', '');
      final h2 = contentHash('Drone attack', 'Reuters', '');
      expect(h1, isNot(h2));
    });

    test('different sources produce different hashes', () {
      final h1 = contentHash('Same title', 'Reuters', '');
      final h2 = contentHash('Same title', 'BBC', '');
      expect(h1, isNot(h2));
    });

    test('returns 16-character hex string', () {
      final hash = contentHash('test', 'src', '');
      expect(hash.length, 16);
      expect(RegExp(r'^[0-9a-f]{16}$').hasMatch(hash), isTrue);
    });
  });

  // ── liveHeadlineToEvent ───────────────────────────────────────

  group('liveHeadlineToEvent', () {
    test('converts headline with drone keyword to drone type', () {
      final event = liveHeadlineToEvent({
        'title': 'Drone attack on military base near Dubai',
        'source': 'Reuters',
        'pubDate': '2026-03-08T12:00:00Z',
        'link': 'https://reuters.com/article/123',
      });
      expect(event, isNotNull);
      expect(event!.type, AttackType.drone);
      expect(event.target, 'UAE'); // Dubai -> UAE
      expect(event.source, 'Reuters');
    });

    test('detects missile/ballistic type', () {
      final event = liveHeadlineToEvent({
        'title': 'Ballistic missile intercepted over Israel',
        'source': 'AP',
        'pubDate': '2026-03-08T12:00:00Z',
        'link': '',
      });
      expect(event, isNotNull);
      expect(event!.type, AttackType.ballistic);
      expect(event.status, EventStatus.intercepted);
    });

    test('detects cyber attack type', () {
      final event = liveHeadlineToEvent({
        'title': 'Cyber attack on Iran infrastructure',
        'source': 'BBC',
        'pubDate': '2026-03-08T12:00:00Z',
        'link': '',
      });
      expect(event, isNotNull);
      expect(event!.type, AttackType.cyber);
    });

    test('detects intercepted status', () {
      final event = liveHeadlineToEvent({
        'title': 'THAAD system shot down incoming missile',
        'source': 'CENTCOM',
        'pubDate': '2026-03-08T12:00:00Z',
        'link': '',
      });
      expect(event, isNotNull);
      expect(event!.status, EventStatus.intercepted);
    });

    test('detects impact status', () {
      final event = liveHeadlineToEvent({
        'title': 'Missile hit military compound, 3 killed',
        'source': 'Al Jazeera',
        'pubDate': '2026-03-08T12:00:00Z',
        'link': '',
      });
      expect(event, isNotNull);
      expect(event!.status, EventStatus.impact);
    });

    test('returns null for pre-mission-start dates', () {
      final event = liveHeadlineToEvent({
        'title': 'Old event about drone',
        'source': 'Reuters',
        'pubDate': '2025-01-01T12:00:00Z',
        'link': '',
      });
      expect(event, isNull);
    });

    test('uses source URL mapping for known sources', () {
      final event = liveHeadlineToEvent({
        'title': 'CENTCOM confirms strike operation in Iran',
        'source': 'CENTCOM',
        'pubDate': '2026-03-08T12:00:00Z',
        'link': '',
      });
      expect(event, isNotNull);
      expect(event!.source, 'CENTCOM');
    });

    test('preserves link when provided', () {
      final event = liveHeadlineToEvent({
        'title': 'Drone strike on Tehran',
        'source': 'Reuters',
        'pubDate': '2026-03-08T12:00:00Z',
        'link': 'https://specific-article.com/123',
      });
      expect(event, isNotNull);
      expect(event!.sourceUrl, 'https://specific-article.com/123');
    });
  });

  // ── liveuamapToEvent ──────────────────────────────────────────

  group('liveuamapToEvent', () {
    test('converts UAMap event with region', () {
      final event = liveuamapToEvent({
        'name': 'Missile impact reported',
        'source': 'LiveUAMap',
        'url': 'https://liveuamap.com/event/123',
        'time': 1709200000,
        'region': 'Tehran',
      });
      expect(event.source, 'LiveUAMap');
      expect(event.details, 'Missile impact reported');
      expect(event.target, 'Tehran');
      expect(event.type, AttackType.ballistic);
    });

    test('defaults region to Middle East', () {
      final event = liveuamapToEvent({
        'name': 'Explosion reported',
        'source': 'LiveUAMap',
        'url': '',
        'time': 0,
      });
      expect(event.target, 'Middle East');
    });

    test('converts time from seconds to milliseconds', () {
      final event = liveuamapToEvent({
        'name': 'Drone spotted',
        'time': 1709200000,
      });
      expect(event.timestamp, 1709200000 * 1000);
    });
  });

  // ── socmintGovToEvent ─────────────────────────────────────────

  group('socmintGovToEvent', () {
    test('returns null for non-x/instagram platform', () {
      final event = socmintGovToEvent({
        'platform': 'facebook',
        'source': '@modgovae',
        'content': 'drone strike',
        'timestamp': missionStartMs + 1000,
      });
      expect(event, isNull);
    });

    test('returns null for non-GOV handle', () {
      final event = socmintGovToEvent({
        'platform': 'x',
        'source': '@random_user',
        'content': 'missile strike near UAE',
        'timestamp': missionStartMs + 1000,
      });
      expect(event, isNull);
    });

    test('returns null for pre-mission timestamps', () {
      final event = socmintGovToEvent({
        'platform': 'x',
        'source': '@modgovae',
        'content': 'old post about drone',
        'timestamp': missionStartMs - 100000,
      });
      expect(event, isNull);
    });

    test('priority source bypasses keyword filter', () {
      // @modgovae is a priority source, so even non-conflict content passes
      final event = socmintGovToEvent({
        'platform': 'x',
        'source': '@modgovae',
        'content': 'Routine press conference today',
        'timestamp': missionStartMs + 1000,
      });
      expect(event, isNotNull);
    });

    test('non-priority GOV source requires conflict keyword', () {
      // @ABORON_uae is not in prioritySources but is in officialGovHandles
      final noConflict = socmintGovToEvent({
        'platform': 'x',
        'source': '@ABORON_uae',
        'content': 'Routine community event',
        'timestamp': missionStartMs + 1000,
      });
      expect(noConflict, isNull);

      final withConflict = socmintGovToEvent({
        'platform': 'x',
        'source': '@ABORON_uae',
        'content': 'Emergency alert missile incoming',
        'timestamp': missionStartMs + 1000,
      });
      expect(withConflict, isNotNull);
    });

    test('detects attack type from content', () {
      final event = socmintGovToEvent({
        'platform': 'x',
        'source': '@modgovae',
        'content': 'Drone intercepted over Abu Dhabi airspace',
        'timestamp': missionStartMs + 1000,
      });
      expect(event, isNotNull);
      expect(event!.type, AttackType.drone);
      expect(event.status, EventStatus.intercepted);
      expect(event.target, 'UAE');
    });
  });
}
