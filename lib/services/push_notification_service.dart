// =============================================================================
// BRE4CH - Push Notification Service
// FCM initialization, token management, topic subscriptions
// HIGH-04 FIX: Token rotation every 24h + secure storage.
// =============================================================================

import 'dart:async';
import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';
import '../config/api.dart';
import 'secure_storage_service.dart';

// Top-level background handler (must be top-level, not a class method)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint('[FCM] Background message: ${message.messageId}');
}

class PushNotificationService {
  PushNotificationService._();
  static final PushNotificationService instance = PushNotificationService._();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final Dio _dio = Dio(BaseOptions(connectTimeout: const Duration(seconds: 10)));
  final _secureStorage = SecureStorageService.instance;
  bool _initialized = false;
  String? _fcmToken;
  Timer? _rotationTimer;

  String? get fcmToken => _fcmToken;
  bool get isInitialized => _initialized;

  Future<void> initialize() async {
    if (kIsWeb) {
      _initialized = true;
      return;
    }

    // Set background handler (only once)
    if (!_initialized) {
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    }

    // Request iOS notification permissions (criticalAlert for siren sounds)
    final settings = await _messaging.requestPermission(
      alert: true,
      announcement: true,
      badge: true,
      carPlay: false,
      criticalAlert: true,
      provisional: false,
      sound: true,
    );

    debugPrint('[FCM] Permission: ${settings.authorizationStatus}');

    // Show notifications when app is in foreground (banner + sound + badge)
    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional) {

      // Get APNs token first (iOS only) — retry if null
      if (Platform.isIOS) {
        for (int i = 0; i < 3; i++) {
          try {
            final apnsToken = await _messaging.getAPNSToken()
                .timeout(const Duration(seconds: 8), onTimeout: () => null);
            debugPrint('[FCM] APNs token attempt ${i + 1}: ${apnsToken != null ? "obtained" : "null"}');
            if (apnsToken != null) break;
            if (i < 2) await Future.delayed(const Duration(seconds: 2));
          } catch (e) {
            debugPrint('[FCM] APNs token error: $e');
          }
        }
      }

      // HIGH-04: Check if token needs rotation
      await _getOrRotateToken();

      // Register with backend
      if (_fcmToken != null) {
        _registerTokenWithBackend(_fcmToken!);
      } else {
        debugPrint('[FCM] WARNING: No FCM token after 3 attempts');
      }

      // Token refresh listener (only once)
      if (!_initialized) {
        _messaging.onTokenRefresh.listen((newToken) {
          _fcmToken = newToken;
          _secureStorage.setFcmToken(newToken);
          debugPrint('[FCM] Token refreshed');
          _registerTokenWithBackend(newToken);
        });

        // HIGH-04: Periodic token rotation check (every 6 hours)
        _rotationTimer = Timer.periodic(const Duration(hours: 6), (_) {
          _getOrRotateToken();
        });
      }

      // Restore saved topic subscriptions
      await _restoreSubscriptions();
    }

    _initialized = true;
  }

  // ── HIGH-04: Token rotation ────────────────────────────────────────

  Future<void> _getOrRotateToken() async {
    final expired = await _secureStorage.isFcmTokenExpired();

    if (expired) {
      debugPrint('[FCM] Token expired or missing, requesting new token...');
      // Delete old token to force rotation
      await _messaging.deleteToken();
      _fcmToken = null;
    }

    if (_fcmToken == null) {
      for (int i = 0; i < 3; i++) {
        try {
          _fcmToken = await _messaging.getToken()
              .timeout(const Duration(seconds: 10), onTimeout: () => null);
          debugPrint('[FCM] Token attempt ${i + 1}: ${_fcmToken != null ? "obtained (${_fcmToken!.substring(0, 20)}...)" : "null"}');
          if (_fcmToken != null) {
            await _secureStorage.setFcmToken(_fcmToken!);
            break;
          }
          if (i < 2) await Future.delayed(const Duration(seconds: 2));
        } catch (e) {
          debugPrint('[FCM] Token error: $e');
        }
      }
    }
  }

  /// Revoke current FCM token (call on device wipe).
  Future<void> revokeToken() async {
    try {
      await _messaging.deleteToken();
      _fcmToken = null;
      await _secureStorage.delete('breach_fcm_token');
      await _secureStorage.delete('breach_fcm_token_ts');
      debugPrint('[FCM] Token revoked');
    } catch (e) {
      debugPrint('[FCM] Revoke failed: $e');
    }
  }

  // ── Topic Management ──────────────────────────────────────────────

  Future<void> subscribeToTopic(String topic) async {
    final fullTopic = 'breach_$topic';
    await _messaging.subscribeToTopic(fullTopic);
    await _saveSubscription(fullTopic, true);
    debugPrint('[FCM] Subscribed: $fullTopic');
  }

  Future<void> unsubscribeFromTopic(String topic) async {
    final fullTopic = 'breach_$topic';
    await _messaging.unsubscribeFromTopic(fullTopic);
    await _saveSubscription(fullTopic, false);
    debugPrint('[FCM] Unsubscribed: $fullTopic');
  }

  Future<void> subscribeToCountry(String code) =>
      subscribeToTopic('country_${code.toLowerCase()}');

  Future<void> unsubscribeFromCountry(String code) =>
      unsubscribeFromTopic('country_${code.toLowerCase()}');

  Future<void> subscribeToCity(String slug) =>
      subscribeToTopic('city_${slug.toLowerCase().replaceAll(' ', '_')}');

  Future<void> unsubscribeFromCity(String slug) =>
      unsubscribeFromTopic('city_${slug.toLowerCase().replaceAll(' ', '_')}');

  Future<void> subscribeToType(String type) =>
      subscribeToTopic('type_${type.toLowerCase()}');

  Future<void> unsubscribeFromType(String type) =>
      unsubscribeFromTopic('type_${type.toLowerCase()}');

  Future<void> subscribeToSeverity(String level) =>
      subscribeToTopic('severity_${level.toLowerCase()}');

  Future<void> unsubscribeFromSeverity(String level) =>
      unsubscribeFromTopic('severity_${level.toLowerCase()}');

  // ── Persistence ───────────────────────────────────────────────────

  Future<void> _saveSubscription(String topic, bool subscribed) async {
    final prefs = await SharedPreferences.getInstance();
    final subs = prefs.getStringList('fcm_subscriptions') ?? [];
    if (subscribed) {
      if (!subs.contains(topic)) subs.add(topic);
    } else {
      subs.remove(topic);
    }
    await prefs.setStringList('fcm_subscriptions', subs);
  }

  Future<Set<String>> getActiveSubscriptions() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList('fcm_subscriptions') ?? []).toSet();
  }

  Future<void> _restoreSubscriptions() async {
    final subs = await getActiveSubscriptions();
    for (final topic in subs) {
      await _messaging.subscribeToTopic(topic);
    }
    debugPrint('[FCM] Restored ${subs.length} subscriptions');
  }

  // ── Backend Registration ──────────────────────────────────────────

  Future<void> _registerTokenWithBackend(String token) async {
    try {
      await _dio.post(
        '${Api.base}/api/notifications/register',
        data: {
          'token': token,
          'platform': Platform.isIOS ? 'ios' : 'android',
        },
      );
    } catch (e) {
      debugPrint('[FCM] Token registration failed: $e');
    }
  }

  // ── Message Streams ───────────────────────────────────────────────

  Stream<RemoteMessage> get onForegroundMessage =>
      FirebaseMessaging.onMessage;

  Stream<RemoteMessage> get onNotificationTap =>
      FirebaseMessaging.onMessageOpenedApp;

  Future<RemoteMessage?> getInitialMessage() =>
      _messaging.getInitialMessage();

  void dispose() {
    _rotationTimer?.cancel();
  }
}
