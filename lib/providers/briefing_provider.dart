// =============================================================================
// BRE4CH — WATCHDOG-IRAN Briefing Provider
// Fetches AI-generated intelligence briefings from backend (07:00 & 19:00 UTC).
// Read-only: no chat, no user input. Cooldown timer until next briefing.
// =============================================================================

import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api.dart';

// ── State ────────────────────────────────────────────────────────

class BriefingState {
  final String? content;
  final DateTime? generatedAt;
  final DateTime? nextBriefingAt;
  final int? dayN;
  final int? groundingSources;
  final bool isLoading;
  final String? error;

  const BriefingState({
    this.content,
    this.generatedAt,
    this.nextBriefingAt,
    this.dayN,
    this.groundingSources,
    this.isLoading = false,
    this.error,
  });

  BriefingState copyWith({
    String? content,
    DateTime? generatedAt,
    DateTime? nextBriefingAt,
    int? dayN,
    int? groundingSources,
    bool? isLoading,
    String? error,
  }) {
    return BriefingState(
      content: content ?? this.content,
      generatedAt: generatedAt ?? this.generatedAt,
      nextBriefingAt: nextBriefingAt ?? this.nextBriefingAt,
      dayN: dayN ?? this.dayN,
      groundingSources: groundingSources ?? this.groundingSources,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }

  /// Extract EXECUTIVE SUMMARY section from briefing markdown
  String? get executiveSummary {
    if (content == null) return null;
    final upper = content!.toUpperCase();
    final start = upper.indexOf('EXECUTIVE SUMMARY');
    if (start == -1) return null;
    // Find next newline after header
    final lineEnd = content!.indexOf('\n', start);
    if (lineEnd == -1) return null;
    // Find next section separator (--- or ##)
    final nextSep = content!.indexOf('\n---', lineEnd);
    final nextH2 = content!.indexOf('\n## ', lineEnd + 1);
    int end = content!.length;
    if (nextSep != -1 && nextSep < end) end = nextSep;
    if (nextH2 != -1 && nextH2 < end) end = nextH2;
    final summary = content!.substring(lineEnd, end).trim();
    return summary.isEmpty ? null : summary;
  }

  /// Remaining time until next briefing
  Duration? get cooldown {
    if (nextBriefingAt == null) return null;
    final remaining = nextBriefingAt!.difference(DateTime.now().toUtc());
    return remaining.isNegative ? Duration.zero : remaining;
  }

  /// Formatted cooldown text: "5H 32M" / "32M" / "GENERATING..."
  String get cooldownText {
    final cd = cooldown;
    if (cd == null) return 'PENDING';
    if (cd == Duration.zero) return 'GENERATING...';
    final h = cd.inHours;
    final m = cd.inMinutes.remainder(60);
    if (h > 0) return '${h}H ${m.toString().padLeft(2, '0')}M';
    return '${m}M';
  }

  bool get hasBriefing => content != null && content!.isNotEmpty;
}

// ── Notifier ─────────────────────────────────────────────────────

class BriefingNotifier extends StateNotifier<BriefingState> {
  BriefingNotifier() : super(const BriefingState()) {
    _init();
  }

  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 30),
  ));
  Timer? _pollTimer;

  static const String _cacheKey = 'watchdog_briefing_v1';

  void _init() async {
    await _loadCache();
    await _fetchLatest();
    _pollTimer = Timer.periodic(PollIntervals.briefing, (_) => _fetchLatest());
  }

  Future<void> _loadCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString(_cacheKey);
      if (json != null) {
        final data = jsonDecode(json) as Map<String, dynamic>;
        state = BriefingState(
          content: data['content'] as String?,
          generatedAt: data['generatedAt'] != null
              ? DateTime.tryParse(data['generatedAt'] as String)
              : null,
          nextBriefingAt: data['nextBriefingAt'] != null
              ? DateTime.tryParse(data['nextBriefingAt'] as String)
              : null,
          dayN: data['dayN'] as int?,
          groundingSources: data['groundingSources'] as int?,
        );
      }
    } catch (_) {
      // Cache read failure is non-critical
    }
  }

  Future<void> _saveCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cacheKey, jsonEncode({
        'content': state.content,
        'generatedAt': state.generatedAt?.toIso8601String(),
        'nextBriefingAt': state.nextBriefingAt?.toIso8601String(),
        'dayN': state.dayN,
        'groundingSources': state.groundingSources,
      }));
    } catch (_) {
      // Cache write failure is non-critical
    }
  }

  Future<void> _fetchLatest() async {
    if (!mounted) return;
    state = state.copyWith(isLoading: true);

    try {
      final res = await _dio.get(Api.briefingLatest);
      if (res.statusCode == 200 && res.data != null) {
        final data = res.data as Map<String, dynamic>;
        final briefing = data['briefing'] as Map<String, dynamic>?;
        if (briefing != null) {
          state = BriefingState(
            content: briefing['content'] as String?,
            generatedAt: briefing['generatedAt'] != null
                ? DateTime.tryParse(briefing['generatedAt'] as String)
                : null,
            nextBriefingAt: data['nextBriefingAt'] != null
                ? DateTime.tryParse(data['nextBriefingAt'] as String)
                : null,
            dayN: briefing['dayN'] as int?,
            groundingSources: briefing['groundingSources'] as int?,
          );
          _saveCache();
          return;
        }
      }
      // 404 — no briefing yet
      if (state.content == null) {
        state = state.copyWith(isLoading: false, error: null);
      } else {
        state = state.copyWith(isLoading: false);
      }
    } on DioException catch (e) {
      // Keep cached content, just note error
      state = state.copyWith(
        isLoading: false,
        error: e.message,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> refresh() async {
    await _fetchLatest();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _dio.close();
    super.dispose();
  }
}

// ── Provider ─────────────────────────────────────────────────────

final briefingProvider =
    StateNotifierProvider<BriefingNotifier, BriefingState>((ref) {
  return BriefingNotifier();
});
