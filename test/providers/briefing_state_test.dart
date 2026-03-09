// ── BriefingState Unit Tests ─────────────────────────────────────
// Tests for executiveSummary, cooldown, cooldownText, hasBriefing.
// No mocking needed — all getters are pure computations on state.

import 'package:flutter_test/flutter_test.dart';
import 'package:breach/providers/briefing_provider.dart';

void main() {
  group('BriefingState.executiveSummary', () {
    test('extracts summary section from markdown', () {
      const state = BriefingState(
        content: '''# WATCHDOG-IRAN — Day 8

## EXECUTIVE SUMMARY

The coalition intercepted 12 ballistic missiles overnight.
Iran has escalated drone operations in the Gulf region.

---

## TACTICAL SITUATION

Details here...''',
      );
      final summary = state.executiveSummary;
      expect(summary, isNotNull);
      expect(summary, contains('coalition intercepted'));
      expect(summary, contains('drone operations'));
      // Should NOT include the next section
      expect(summary, isNot(contains('TACTICAL SITUATION')));
    });

    test('extracts summary up to next ## heading', () {
      const state = BriefingState(
        content: '''## EXECUTIVE SUMMARY

Short summary paragraph.

## NEXT SECTION

More content.''',
      );
      final summary = state.executiveSummary;
      expect(summary, isNotNull);
      expect(summary, contains('Short summary'));
      expect(summary, isNot(contains('NEXT SECTION')));
    });

    test('returns null when no EXECUTIVE SUMMARY section', () {
      const state = BriefingState(
        content: '## TACTICAL SITUATION\n\nSome data.',
      );
      expect(state.executiveSummary, isNull);
    });

    test('returns null when content is null', () {
      const state = BriefingState();
      expect(state.executiveSummary, isNull);
    });

    test('case-insensitive header detection', () {
      const state = BriefingState(
        content: '''## Executive Summary

Lower case header content here.

## Next''',
      );
      expect(state.executiveSummary, isNotNull);
      expect(state.executiveSummary, contains('Lower case header'));
    });

    test('returns null for empty summary section', () {
      const state = BriefingState(
        content: '''## EXECUTIVE SUMMARY

## NEXT SECTION''',
      );
      // The summary between the two headers is empty after trim
      expect(state.executiveSummary, isNull);
    });
  });

  group('BriefingState.cooldown', () {
    test('returns remaining duration', () {
      final futureTime = DateTime.now().toUtc().add(const Duration(hours: 3));
      final state = BriefingState(nextBriefingAt: futureTime);
      final cd = state.cooldown;
      expect(cd, isNotNull);
      // Should be approximately 3 hours (within a few seconds tolerance)
      expect(cd!.inMinutes, greaterThanOrEqualTo(179));
      expect(cd.inMinutes, lessThanOrEqualTo(180));
    });

    test('returns Duration.zero when past due', () {
      final pastTime = DateTime.now().toUtc().subtract(const Duration(hours: 1));
      final state = BriefingState(nextBriefingAt: pastTime);
      expect(state.cooldown, Duration.zero);
    });

    test('returns null when nextBriefingAt is null', () {
      const state = BriefingState();
      expect(state.cooldown, isNull);
    });
  });

  group('BriefingState.cooldownText', () {
    test('returns PENDING when no next briefing', () {
      const state = BriefingState();
      expect(state.cooldownText, 'PENDING');
    });

    test('returns GENERATING... when cooldown is zero', () {
      final pastTime = DateTime.now().toUtc().subtract(const Duration(minutes: 5));
      final state = BriefingState(nextBriefingAt: pastTime);
      expect(state.cooldownText, 'GENERATING...');
    });

    test('formats hours and minutes', () {
      final futureTime = DateTime.now().toUtc().add(const Duration(hours: 5, minutes: 32));
      final state = BriefingState(nextBriefingAt: futureTime);
      final text = state.cooldownText;
      expect(text, contains('H'));
      expect(text, contains('M'));
      // Should be approximately "5H xxM" (may lose a minute due to timing)
      expect(text.contains('H '), isTrue);
    });

    test('formats minutes only when under 1 hour', () {
      final futureTime = DateTime.now().toUtc().add(const Duration(minutes: 42));
      final state = BriefingState(nextBriefingAt: futureTime);
      final text = state.cooldownText;
      expect(text, endsWith('M'));
      expect(text, isNot(contains('H')));
    });
  });

  group('BriefingState.hasBriefing', () {
    test('returns true when content is non-empty', () {
      const state = BriefingState(content: 'Some briefing content');
      expect(state.hasBriefing, isTrue);
    });

    test('returns false when content is null', () {
      const state = BriefingState();
      expect(state.hasBriefing, isFalse);
    });

    test('returns false when content is empty string', () {
      const state = BriefingState(content: '');
      expect(state.hasBriefing, isFalse);
    });
  });

  group('BriefingState.copyWith', () {
    test('updates specified fields', () {
      const original = BriefingState(content: 'old', isLoading: false);
      final updated = original.copyWith(content: 'new', isLoading: true);
      expect(updated.content, 'new');
      expect(updated.isLoading, isTrue);
    });

    test('preserves unspecified fields', () {
      final original = BriefingState(
        content: 'test',
        dayN: 8,
        generatedAt: DateTime.utc(2026, 3, 8),
      );
      final updated = original.copyWith(isLoading: true);
      expect(updated.content, 'test');
      expect(updated.dayN, 8);
      expect(updated.generatedAt, DateTime.utc(2026, 3, 8));
    });

    test('error can be set to null (cleared)', () {
      const original = BriefingState(error: 'network error');
      // copyWith with error not specified keeps it — but the actual
      // implementation sets error: error which would be null if not passed
      final updated = original.copyWith(isLoading: false);
      // error is set to null because copyWith doesn't pass it
      expect(updated.error, isNull);
    });
  });
}
