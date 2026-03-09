// ── DefenseStatsState Unit Tests ─────────────────────────────────
// Tests for mergedSystems, totalInterceptions, fallback behavior.
// Uses real coalitionAirDefense data (no mocking needed).

import 'package:flutter_test/flutter_test.dart';
import 'package:breach/providers/defense_stats_provider.dart';
import 'package:breach/models/air_defense_system.dart';
import 'package:breach/data/air_defense_systems.dart';

void main() {
  group('DefenseStatsState.mergedSystems', () {
    test('returns hardcoded data when no dynamic stats', () {
      const state = DefenseStatsState();
      expect(state.mergedSystems, coalitionAirDefense);
      expect(state.mergedSystems.length, coalitionAirDefense.length);
    });

    test('merges dynamic stats for matching system IDs', () {
      final dynamicStats = {
        coalitionAirDefense.first.id: const InterceptionStats(
          ballisticIntercepted: 999,
          cruiseIntercepted: 888,
          droneIntercepted: 777,
          totalIntercepted: 2664,
          lastUpdated: '2026-03-08T14:00:00Z',
        ),
      };
      final state = DefenseStatsState(dynamicStats: dynamicStats);
      final merged = state.mergedSystems;

      // First system should have updated stats
      expect(merged.first.stats.ballisticIntercepted, 999);
      expect(merged.first.stats.totalIntercepted, 2664);

      // Other systems should keep hardcoded stats
      if (coalitionAirDefense.length > 1) {
        expect(
          merged[1].stats.totalIntercepted,
          coalitionAirDefense[1].stats.totalIntercepted,
        );
      }
    });

    test('ignores dynamic stats for unknown system IDs', () {
      final dynamicStats = {
        'nonexistent-system-id': const InterceptionStats(
          ballisticIntercepted: 100,
          cruiseIntercepted: 50,
          droneIntercepted: 200,
          totalIntercepted: 350,
          lastUpdated: '',
        ),
      };
      final state = DefenseStatsState(dynamicStats: dynamicStats);
      // Should return same length — no extra systems added
      expect(state.mergedSystems.length, coalitionAirDefense.length);
    });
  });

  group('DefenseStatsState aggregate totals', () {
    test('totalInterceptions sums all systems', () {
      const state = DefenseStatsState();
      final manual = coalitionAirDefense.fold<int>(
        0, (sum, s) => sum + s.stats.totalIntercepted,
      );
      expect(state.totalInterceptions, manual);
    });

    test('totalBallisticInterceptions sums correctly', () {
      const state = DefenseStatsState();
      final manual = coalitionAirDefense.fold<int>(
        0, (sum, s) => sum + s.stats.ballisticIntercepted,
      );
      expect(state.totalBallisticInterceptions, manual);
    });

    test('totalDroneInterceptions sums correctly', () {
      const state = DefenseStatsState();
      final manual = coalitionAirDefense.fold<int>(
        0, (sum, s) => sum + s.stats.droneIntercepted,
      );
      expect(state.totalDroneInterceptions, manual);
    });

    test('totals update with dynamic stats', () {
      const original = DefenseStatsState();
      final originalTotal = original.totalInterceptions;

      final dynamicStats = {
        coalitionAirDefense.first.id: InterceptionStats(
          ballisticIntercepted: coalitionAirDefense.first.stats.ballisticIntercepted + 100,
          cruiseIntercepted: coalitionAirDefense.first.stats.cruiseIntercepted,
          droneIntercepted: coalitionAirDefense.first.stats.droneIntercepted,
          totalIntercepted: coalitionAirDefense.first.stats.totalIntercepted + 100,
          lastUpdated: '2026-03-08T14:00:00Z',
        ),
      };
      final updated = DefenseStatsState(dynamicStats: dynamicStats);

      expect(updated.totalInterceptions, originalTotal + 100);
    });
  });

  group('DefenseStatsState.copyWith', () {
    test('updates loaded flag', () {
      const state = DefenseStatsState();
      expect(state.loaded, isFalse);
      final updated = state.copyWith(loaded: true);
      expect(updated.loaded, isTrue);
    });

    test('preserves dynamicStats when not specified', () {
      final state = DefenseStatsState(
        dynamicStats: {
          'test': const InterceptionStats(
            ballisticIntercepted: 1,
            cruiseIntercepted: 2,
            droneIntercepted: 3,
            totalIntercepted: 6,
            lastUpdated: '',
          ),
        },
      );
      final updated = state.copyWith(loaded: true);
      expect(updated.dynamicStats.containsKey('test'), isTrue);
    });
  });

  group('InterceptionStats.fromJson', () {
    test('parses all fields', () {
      final stats = InterceptionStats.fromJson({
        'ballisticIntercepted': 170,
        'cruiseIntercepted': 2,
        'droneIntercepted': 560,
        'totalIntercepted': 732,
        'lastUpdated': '2026-03-08T14:00:00Z',
      });
      expect(stats.ballisticIntercepted, 170);
      expect(stats.cruiseIntercepted, 2);
      expect(stats.droneIntercepted, 560);
      expect(stats.totalIntercepted, 732);
      expect(stats.lastUpdated, '2026-03-08T14:00:00Z');
    });

    test('defaults missing fields to zero', () {
      final stats = InterceptionStats.fromJson({});
      expect(stats.ballisticIntercepted, 0);
      expect(stats.cruiseIntercepted, 0);
      expect(stats.droneIntercepted, 0);
      expect(stats.totalIntercepted, 0);
      expect(stats.lastUpdated, '');
    });

    test('calculates totalIntercepted if not provided', () {
      final stats = InterceptionStats.fromJson({
        'ballisticIntercepted': 10,
        'cruiseIntercepted': 20,
        'droneIntercepted': 30,
      });
      // totalIntercepted defaults to sum of components
      expect(stats.totalIntercepted, 60);
    });
  });
}
