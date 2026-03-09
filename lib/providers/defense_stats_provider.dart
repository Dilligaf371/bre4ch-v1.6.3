// =============================================================================
// BRE4CH - Defense Stats Provider
// WebSocket-first with HTTP polling fallback.
// WS: listens on 'stats' channel for real-time pushes from backend scraper.
// HTTP: polls /api/defense/stats when WS is disconnected.
// Falls back to hardcoded data in air_defense_systems.dart when offline.
//
// API/WS payload format:
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
import '../services/breach_socket_service.dart';

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
  StreamSubscription? _wsSub;
  StreamSubscription? _wsConnSub;

  void _init() {
    // Initial HTTP fetch
    _fetchStats();

    // Subscribe to WS stats channel for real-time pushes
    final ws = BreachSocketService.instance;
    _wsSub = ws.channel(WsMessageType.stats).listen((data) {
      _handleStatsPayload(data);
    });

    // Toggle HTTP polling based on WS connection state
    _wsConnSub = ws.connectionStream.listen((connected) {
      if (connected) {
        // WS connected — stop polling
        _pollTimer?.cancel();
        _pollTimer = null;
      } else {
        // WS disconnected — start HTTP polling fallback
        _startHttpPolling();
      }
    });

    // If WS is not connected, start HTTP polling
    if (!ws.connected) {
      _startHttpPolling();
    }
  }

  void _startHttpPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(
      PollIntervals.defenseStats,
      (_) => _fetchStats(),
    );
  }

  /// Parse stats payload from either WS or HTTP.
  void _handleStatsPayload(dynamic raw) {
    try {
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

  Future<void> _fetchStats() async {
    try {
      final response = await ApiService.instance.get<dynamic>(
        Api.defenseStats,
      );
      if (response.data != null && mounted) {
        _handleStatsPayload(response.data);
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
    _wsSub?.cancel();
    _wsConnSub?.cancel();
    super.dispose();
  }
}

// ── Provider ─────────────────────────────────────────────────────────

final defenseStatsProvider =
    StateNotifierProvider<DefenseStatsNotifier, DefenseStatsState>((ref) {
  return DefenseStatsNotifier();
});
