// =============================================================================
// BRE4CH - Alert Sound Service
// Plays customizable alert sounds per severity level.
// Sound preferences stored via NotificationPreferencesProvider.
// =============================================================================

import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/emergency_alert.dart';

class AlertSoundService {
  AlertSoundService._();
  static final AlertSoundService instance = AlertSoundService._();

  final AudioPlayer _player = AudioPlayer();
  Timer? _stopTimer;
  bool _enabled = true;

  bool get enabled => _enabled;
  set enabled(bool value) => _enabled = value;

  /// Get the configured sound key for a given severity level.
  Future<String> _soundForLevel(AlertLevel level) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      switch (level) {
        case AlertLevel.extreme:
          return prefs.getString('notif_pref_sound_extreme') ?? 'siren';
        case AlertLevel.severe:
          return prefs.getString('notif_pref_sound_severe') ?? 'radar';
        case AlertLevel.moderate:
          return prefs.getString('notif_pref_sound_moderate') ?? 'silent';
      }
    } catch (_) {
      switch (level) {
        case AlertLevel.extreme: return 'siren';
        case AlertLevel.severe: return 'radar';
        case AlertLevel.moderate: return 'silent';
      }
    }
  }

  /// Map sound key to asset filename
  String? _soundAsset(String key) {
    switch (key) {
      case 'siren': return 'sounds/siren.wav';
      case 'radar': return 'sounds/radar.wav';
      case 'default': return null;
      case 'silent': return null;
      default: return null;
    }
  }

  /// Play the appropriate sound for the given alert level.
  /// Uses user-configured sounds from preferences.
  Future<void> playForLevel(AlertLevel level) async {
    if (!_enabled || kIsWeb) return;

    try {
      await stop();

      final soundKey = await _soundForLevel(level);
      if (soundKey == 'silent') return;

      final asset = _soundAsset(soundKey);
      if (asset == null) return;

      await _player.setSource(AssetSource(asset));

      // Siren loops for 5 seconds, everything else plays once
      if (soundKey == 'siren') {
        await _player.setReleaseMode(ReleaseMode.loop);
        await _player.resume();
        _stopTimer = Timer(const Duration(seconds: 5), () => stop());
      } else {
        await _player.setReleaseMode(ReleaseMode.release);
        await _player.resume();
      }
    } catch (e) {
      debugPrint('[SOUND] Playback error: $e');
    }
  }

  /// Preview a sound by key (for the settings picker)
  Future<void> previewSound(String soundKey) async {
    if (kIsWeb) return;
    try {
      await stop();
      if (soundKey == 'silent' || soundKey == 'default') return;

      final asset = _soundAsset(soundKey);
      if (asset == null) return;

      await _player.setSource(AssetSource(asset));
      await _player.setReleaseMode(ReleaseMode.release);
      await _player.resume();
    } catch (e) {
      debugPrint('[SOUND] Preview error: $e');
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
