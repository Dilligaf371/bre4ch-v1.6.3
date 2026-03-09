// =============================================================================
// BRE4CH - Source Overlay Provider
// WebSocket-first with HTTP polling fallback.
// WS: listens on 'source_overlay' channel for instant pushes when
//     sources.json changes on the server.
// HTTP: polls /api/source-overlay when WS is disconnected.
// Falls back to hardcoded data when offline (overlay stays empty).
//
// Consumers call applyToAirDefense() / applyToMissileSites() to merge
// overlay data onto hardcoded lists.
// =============================================================================

import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/api.dart';
import '../models/air_defense_system.dart';
import '../models/missile_site.dart';
import '../services/api_service.dart';
import '../services/breach_socket_service.dart';

// ── Overlay entry (parsed from JSON) ─────────────────────────────────

class SourceOverlayEntry {
  final String? description;
  final String? sourceLabel;
  final String? sourceUrl;
  final DateTime? sourceDate;

  const SourceOverlayEntry({
    this.description,
    this.sourceLabel,
    this.sourceUrl,
    this.sourceDate,
  });

  factory SourceOverlayEntry.fromJson(Map<String, dynamic> json) {
    DateTime? date;
    final raw = json['sourceDate'];
    if (raw is String && raw.isNotEmpty) {
      date = DateTime.tryParse(raw);
    }
    return SourceOverlayEntry(
      description: json['description'] as String?,
      sourceLabel: json['sourceLabel'] as String?,
      sourceUrl: json['sourceUrl'] as String?,
      sourceDate: date,
    );
  }
}

// ── State ────────────────────────────────────────────────────────────

class SourceOverlayState {
  final Map<String, SourceOverlayEntry> entries;
  final bool loaded;

  const SourceOverlayState({
    this.entries = const {},
    this.loaded = false,
  });

  SourceOverlayState copyWith({
    Map<String, SourceOverlayEntry>? entries,
    bool? loaded,
  }) {
    return SourceOverlayState(
      entries: entries ?? this.entries,
      loaded: loaded ?? this.loaded,
    );
  }

  /// Apply overlay to air defense systems (after stats merge).
  List<AirDefenseSystem> applyToAirDefense(List<AirDefenseSystem> systems) {
    if (entries.isEmpty) return systems;
    return systems.map((system) {
      final overlay = entries[system.id];
      if (overlay == null) return system;
      return system.copyWith(
        description: overlay.description,
        sourceLabel: overlay.sourceLabel,
        sourceUrl: overlay.sourceUrl,
        sourceDate: overlay.sourceDate,
      );
    }).toList();
  }

  /// Apply overlay to missile sites.
  List<MissileSite> applyToMissileSites(List<MissileSite> sites) {
    if (entries.isEmpty) return sites;
    return sites.map((site) {
      final overlay = entries[site.id];
      if (overlay == null) return site;
      return site.copyWith(
        description: overlay.description,
        sourceLabel: overlay.sourceLabel,
        sourceUrl: overlay.sourceUrl,
        sourceDate: overlay.sourceDate,
      );
    }).toList();
  }
}

// ── Notifier ─────────────────────────────────────────────────────────

class SourceOverlayNotifier extends StateNotifier<SourceOverlayState> {
  SourceOverlayNotifier() : super(const SourceOverlayState()) {
    _init();
  }

  Timer? _pollTimer;
  StreamSubscription? _wsSub;
  StreamSubscription? _wsConnSub;

  void _init() {
    // Initial HTTP fetch
    _fetchOverlay();

    // Subscribe to WS source_overlay channel for instant pushes
    final ws = BreachSocketService.instance;
    _wsSub = ws.channel(WsMessageType.sourceOverlay).listen((data) {
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

    // If WS is not connected, start HTTP polling
    if (!ws.connected) {
      _startHttpPolling();
    }
  }

  void _startHttpPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(
      PollIntervals.sourceOverlay,
      (_) => _fetchOverlay(),
    );
  }

  /// Parse overlay payload from either WS or HTTP.
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

      final sources = data['sources'] as Map<String, dynamic>?;
      if (sources == null) return;

      final map = <String, SourceOverlayEntry>{};
      for (final entry in sources.entries) {
        if (entry.value is Map<String, dynamic>) {
          map[entry.key] = SourceOverlayEntry.fromJson(
            entry.value as Map<String, dynamic>,
          );
        }
      }

      if (mounted) {
        state = state.copyWith(entries: map, loaded: true);
      }
    } catch (_) {
      // Silently fail — hardcoded data remains in effect
    }
  }

  Future<void> _fetchOverlay() async {
    try {
      final response = await ApiService.instance.get<dynamic>(
        Api.sourceOverlay,
      );
      if (response.data != null && mounted) {
        _handlePayload(response.data);
      }
    } catch (_) {
      // Silently fail — hardcoded data remains in effect
    }
  }

  /// Manual refresh trigger.
  Future<void> refresh() async => _fetchOverlay();

  @override
  void dispose() {
    _pollTimer?.cancel();
    _wsSub?.cancel();
    _wsConnSub?.cancel();
    super.dispose();
  }
}

// ── Provider ─────────────────────────────────────────────────────────

final sourceOverlayProvider =
    StateNotifierProvider<SourceOverlayNotifier, SourceOverlayState>((ref) {
  return SourceOverlayNotifier();
});
