// =============================================================================
// BRE4CH - Alert Sound Service
// Uses system default notification sounds only.
// Custom sounds removed — iOS system sounds are used instead.
// =============================================================================

import 'package:flutter/foundation.dart';
import '../models/emergency_alert.dart';

class AlertSoundService {
  AlertSoundService._();
  static final AlertSoundService instance = AlertSoundService._();

  bool enabled = true;

  /// Play is now handled by iOS notification system (default sound).
  /// This method is kept for API compatibility but is a no-op.
  Future<void> playForLevel(AlertLevel level) async {
    // Sound is now handled by iOS notification system (UNNotificationSound.default)
    // No custom in-app audio playback needed.
  }

  /// Preview is a no-op — system default sound cannot be previewed in-app.
  Future<void> previewSound(String soundKey) async {
    if (kIsWeb) return;
    // System default sound — no preview available
    debugPrint('[SOUND] System default sound selected');
  }

  /// Stop — no-op since no custom audio is played.
  Future<void> stop() async {}

  void dispose() {}
}
