// =============================================================================
// BRE4CH - Defense Stats Provider
// Fetches interception statistics dynamically from API.
// Falls back to hardcoded data in air_defense_systems.dart when offline.
//
// API response format (GET /api/defense/stats):
// {
//   "stats": {
//     "ad-uae-dhafra": {
//       "ballisticIntercepted": 170,
//       "cruiseIntercepted": 2,
//       "droneIntercepted": 560,
//       "totalIntercepted": 732,
//       "lastUpdated": "2026-03-08T14:00:00Z"
//     },
//     ...
//   }
// }
// =============================================================================

import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/api.dart';
import '../models/air_defense_system.dart';
import '../data/air_defense_systems.dart';
import '../services/api_service.dart';

// ── State ────────────────────────────────────────────────────────────

class DefenseStatsState {
  /// Dynamic stats keyed by air defense system ID.
  final Map<String, InterceptionStats> dynamicStats;

  /// Whether at least one successful fetch has been made.
  final bool loaded;

  const DefenseStatsState({
    this.dynamicStats = const {},
    this.loaded = false,
  });

  DefenseStatsState copyWith({
    Map<String, InterceptionStats>? dynamicStats,
    bool? loaded,
  }) {
    return DefenseStatsState(
      dynamicStats: dynamicStats ?? this.dynamicStats,
      loaded: loaded ?? this.loaded,
    );
  }

  /// Returns the [AirDefenseSystem] list with dynamic stats merged in.
  /// If no dynamic data available for a given system, its hardcoded stats
  /// are preserved.
  List<AirDefenseSystem> get mergedSystems {
    if (dynamicStats.isEmpty) return coalitionAirDefense;
    return coalitionAirDefense.map((system) {
      final updated = dynamicStats[system.id];
      return updated != null ? system.copyWith(stats: updated) : system;
    }).toList();
  }

  /// Aggregate totals computed from merged data.
  int get totalInterceptions =>
      mergedSystems.fold(0, (sum, s) => sum + s.stats.totalIntercepted);

  int get totalBallisticInterceptions =>
      mergedSystems.fold(0, (sum, s) => sum + s.stats.ballisticIntercepted);

  int get totalDroneInterceptions =>
      mergedSystems.fold(0, (sum, s) => sum + s.stats.droneIntercepted);
}

// ── Notifier ─────────────────────────────────────────────────────────

class DefenseStatsNotifier extends StateNotifier<DefenseStatsState> {
  DefenseStatsNotifier() : super(const DefenseStatsState()) {
    _init();
  }

  Timer? _pollTimer;

  void _init() {
    _fetchStats();
    _pollTimer = Timer.periodic(
      PollIntervals.defenseStats,
      (_) => _fetchStats(),
    );
  }

  Future<void> _fetchStats() async {
    try {
      final response = await ApiService.instance.get<dynamic>(
        Api.defenseStats,
      );

      final raw = response.data;
      if (raw == null || !mounted) return;

      // Handle both String and Map responses
      final Map<String, dynamic> data;
      if (raw is String) {
        data = jsonDecode(raw) as Map<String, dynamic>;
      } else if (raw is Map<String, dynamic>) {
        data = raw;
      } else {
        return;
      }

      final systems = data['stats'] as Map<String, dynamic>?;
      if (systems == null || systems.isEmpty) return;

      final statsMap = <String, InterceptionStats>{};
      for (final entry in systems.entries) {
        try {
          statsMap[entry.key] = InterceptionStats.fromJson(
            entry.value as Map<String, dynamic>,
          );
        } catch (_) {
          // Skip malformed entries
        }
      }

      if (mounted && statsMap.isNotEmpty) {
        state = state.copyWith(dynamicStats: statsMap, loaded: true);
      }
    } catch (_) {
      // Silently fail — hardcoded fallback remains in effect
    }
  }

  /// Manual refresh trigger.
  Future<void> refresh() async => _fetchStats();

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }
}

// ── Provider ─────────────────────────────────────────────────────────

final defenseStatsProvider =
    StateNotifierProvider<DefenseStatsNotifier, DefenseStatsState>((ref) {
  return DefenseStatsNotifier();
});
