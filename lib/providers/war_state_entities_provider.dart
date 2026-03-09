// =============================================================================
// BRE4CH - War State Entities Provider
// WebSocket-first with HTTP polling fallback.
// WS: listens on 'war_state' channel for instant pushes when
//     war-state.json changes on the server.
// HTTP: polls /api/war-state when WS is disconnected.
// Falls back to hardcoded data when offline (entity stats stay unchanged).
//
// Consumers call applyToEntities() to merge overlay stat values onto
// hardcoded _VerifiedStat lists in war_state_screen.dart.
// =============================================================================

import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/api.dart';
import '../services/api_service.dart';
import '../services/breach_socket_service.dart';

// ── Single entity overlay (parsed from JSON) ────────────────────────

class WarStateEntityOverlay {
  /// Stat label → new value (e.g. "KIA" → "12")
  final Map<String, String> stats;
  final String? sourceLabel;
  final String? sourceUrl;

  const WarStateEntityOverlay({
    this.stats = const {},
    this.sourceLabel,
    this.sourceUrl,
  });

  factory WarStateEntityOverlay.fromJson(Map<String, dynamic> json) {
    final rawStats = json['stats'];
    final statsMap = <String, String>{};
    if (rawStats is Map<String, dynamic>) {
      for (final entry in rawStats.entries) {
        statsMap[entry.key] = entry.value.toString();
      }
    }
    return WarStateEntityOverlay(
      stats: statsMap,
      sourceLabel: json['sourceLabel'] as String?,
      sourceUrl: json['sourceUrl'] as String?,
    );
  }
}

// ── State ────────────────────────────────────────────────────────────

class WarStateEntitiesState {
  /// Entity code (e.g. "US", "IR", "HZ") → overlay data
  final Map<String, WarStateEntityOverlay> entities;
  final bool loaded;

  const WarStateEntitiesState({
    this.entities = const {},
    this.loaded = false,
  });

  WarStateEntitiesState copyWith({
    Map<String, WarStateEntityOverlay>? entities,
    bool? loaded,
  }) {
    return WarStateEntitiesState(
      entities: entities ?? this.entities,
      loaded: loaded ?? this.loaded,
    );
  }

  /// Look up stat value override for an entity + label.
  /// Returns null if no override exists.
  String? getStatValue(String entityCode, String statLabel) {
    final overlay = entities[entityCode];
    if (overlay == null) return null;
    return overlay.stats[statLabel];
  }

  /// Look up source label override for an entity.
  String? getSourceLabel(String entityCode) {
    return entities[entityCode]?.sourceLabel;
  }

  /// Look up source URL override for an entity.
  String? getSourceUrl(String entityCode) {
    return entities[entityCode]?.sourceUrl;
  }
}

// ── Notifier ─────────────────────────────────────────────────────────

class WarStateEntitiesNotifier extends StateNotifier<WarStateEntitiesState> {
  WarStateEntitiesNotifier() : super(const WarStateEntitiesState()) {
    _init();
  }

  Timer? _pollTimer;
  StreamSubscription? _wsSub;
  StreamSubscription? _wsConnSub;

  void _init() {
    // Initial HTTP fetch
    _fetchWarState();

    // Subscribe to WS war_state channel for instant pushes
    final ws = BreachSocketService.instance;
    _wsSub = ws.channel(WsMessageType.warState).listen((data) {
      _handlePayload(data);
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

    // If WS is not connected right now, start HTTP polling
    if (!ws.connected) {
      _startHttpPolling();
    }
  }

  void _startHttpPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(
      PollIntervals.warState,
      (_) => _fetchWarState(),
    );
  }

  /// Parse war-state payload from either WS or HTTP.
  void _handlePayload(dynamic raw) {
    try {
      final Map<String, dynamic> data;
      if (raw is String) {
        data = jsonDecode(raw) as Map<String, dynamic>;
      } else if (raw is Map<String, dynamic>) {
        data = raw;
      } else {
        return;
      }

      final entities = data['entities'] as Map<String, dynamic>?;
      if (entities == null) return;

      final map = <String, WarStateEntityOverlay>{};
      for (final entry in entities.entries) {
        if (entry.value is Map<String, dynamic>) {
          map[entry.key] = WarStateEntityOverlay.fromJson(
            entry.value as Map<String, dynamic>,
          );
        }
      }

      if (mounted) {
        state = state.copyWith(entities: map, loaded: true);
      }
    } catch (_) {
      // Silently fail — hardcoded data remains in effect
    }
  }

  Future<void> _fetchWarState() async {
    try {
      final response = await ApiService.instance.get<dynamic>(
        Api.warState,
      );
      if (response.data != null && mounted) {
        _handlePayload(response.data);
      }
    } catch (_) {
      // Silently fail — hardcoded data remains in effect
    }
  }

  /// Manual refresh trigger.
  Future<void> refresh() async => _fetchWarState();

  @override
  void dispose() {
    _pollTimer?.cancel();
    _wsSub?.cancel();
    _wsConnSub?.cancel();
    super.dispose();
  }
}

// ── Provider ─────────────────────────────────────────────────────────

final warStateEntitiesProvider =
    StateNotifierProvider<WarStateEntitiesNotifier, WarStateEntitiesState>((ref) {
  return WarStateEntitiesNotifier();
});
