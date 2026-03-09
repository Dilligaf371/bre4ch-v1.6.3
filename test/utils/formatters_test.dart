// ── Formatters Unit Tests ────────────────────────────────────────
// Tests for formatTimestamp, formatNumber, formatDuration.

import 'package:flutter_test/flutter_test.dart';
import 'package:breach/utils/formatters.dart';

void main() {
  group('formatNumber', () {
    test('formats small numbers with commas', () {
      expect(formatNumber(0), '0');
      expect(formatNumber(999), '999');
      expect(formatNumber(1000), '1,000');
      expect(formatNumber(1500), '1,500');
      expect(formatNumber(9999), '9,999');
    });

    test('formats thousands with K suffix', () {
      expect(formatNumber(10000), '10.0K');
      expect(formatNumber(12345), '12.3K');
      expect(formatNumber(99999), '100.0K'); // 99.999 < 100 threshold
      expect(formatNumber(100000), '100K');
      expect(formatNumber(999999), '1000K'); // edge: just under 1M
    });

    test('formats millions with M suffix', () {
      expect(formatNumber(1000000), '1.0M');
      expect(formatNumber(1234567), '1.2M');
      expect(formatNumber(100000000), '100M');
    });

    test('handles negative numbers', () {
      expect(formatNumber(-500), '-500');
      expect(formatNumber(-15000), '-15.0K');
      expect(formatNumber(-2000000), '-2.0M');
    });

    test('formats zero', () {
      expect(formatNumber(0), '0');
    });
  });

  group('formatDuration', () {
    test('formats seconds only', () {
      expect(formatDuration(const Duration(seconds: 45)), '00:00:45');
    });

    test('formats hours and minutes', () {
      expect(formatDuration(const Duration(hours: 2, minutes: 30, seconds: 15)),
          '02:30:15');
    });

    test('formats with days', () {
      expect(
        formatDuration(const Duration(days: 3, hours: 5, minutes: 30, seconds: 45)),
        '3d 05:30:45',
      );
    });

    test('zero duration', () {
      expect(formatDuration(Duration.zero), '00:00:00');
    });

    test('pads single-digit values', () {
      expect(formatDuration(const Duration(hours: 1, minutes: 2, seconds: 3)),
          '01:02:03');
    });

    test('large day count', () {
      expect(
        formatDuration(const Duration(days: 100, hours: 12)),
        '100d 12:00:00',
      );
    });
  });

  group('formatTimestamp', () {
    // formatTimestamp uses DateTime.now(), so we test relative boundaries.
    // These tests verify the format strings, not exact values.

    test('returns "just now" for current time', () {
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      expect(formatTimestamp(now), 'just now');
    });

    test('returns minutes ago', () {
      final fiveMinAgo =
          DateTime.now().millisecondsSinceEpoch ~/ 1000 - 300;
      expect(formatTimestamp(fiveMinAgo), '5m ago');
    });

    test('returns hours ago', () {
      final twoHoursAgo =
          DateTime.now().millisecondsSinceEpoch ~/ 1000 - 7200;
      expect(formatTimestamp(twoHoursAgo), '2h ago');
    });

    test('returns days ago', () {
      final threeDaysAgo =
          DateTime.now().millisecondsSinceEpoch ~/ 1000 - 259200;
      expect(formatTimestamp(threeDaysAgo), '3d ago');
    });

    test('returns weeks ago', () {
      final twoWeeksAgo =
          DateTime.now().millisecondsSinceEpoch ~/ 1000 - 1209600;
      expect(formatTimestamp(twoWeeksAgo), '2w ago');
    });
  });
}
