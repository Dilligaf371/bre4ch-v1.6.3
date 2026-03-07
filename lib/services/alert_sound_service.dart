// =============================================================================
// BRE4CH - Alert Sound Service
// Plays radar ping for SEVERE alerts, police siren for EXTREME alerts.
// =============================================================================

import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import '../models/emergency_alert.dart';

class AlertSoundService {
  AlertSoundService._();
  static final AlertSoundService instance = AlertSoundService._();

  final AudioPlayer _player = AudioPlayer();
  Timer? _stopTimer;
  bool _enabled = true;

  bool get enabled => _enabled;
  set enabled(bool value) => _enabled = value;

  /// Play the appropriate sound for the given alert level.
  /// - EXTREME → police siren (5s loop)
  /// - SEVERE → radar ping (single play)
  /// - MODERATE → silent
  Future<void> playForLevel(AlertLevel level) async {
    if (!_enabled || kIsWeb) return;

    try {
      await stop();

      switch (level) {
        case AlertLevel.extreme:
          await _player.setSource(AssetSource('sounds/siren.wav'));
          await _player.setReleaseMode(ReleaseMode.loop);
          await _player.resume();
          // Auto-stop after 5 seconds
          _stopTimer = Timer(const Duration(seconds: 5), () => stop());

        case AlertLevel.severe:
          await _player.setSource(AssetSource('sounds/radar.wav'));
          await _player.setReleaseMode(ReleaseMode.release);
          await _player.resume();

        case AlertLevel.moderate:
          break; // Silent
      }
    } catch (e) {
      debugPrint('[SOUND] Playback error: $e');
    }
  }

  /// Stop any currently playing alert sound.
  Future<void> stop() async {
    _stopTimer?.cancel();
    _stopTimer = null;
    try {
      await _player.stop();
    } catch (_) {}
  }

  void dispose() {
    stop();
    _player.dispose();
  }
}
