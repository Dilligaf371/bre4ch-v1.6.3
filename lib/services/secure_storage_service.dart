// ── Secure Storage Service ───────────────────────────────────────
// HIGH-01: Encrypted storage for sensitive data (JWT, FCM tokens, keys).
// Uses Keychain (iOS) / EncryptedSharedPreferences (Android).

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorageService {
  SecureStorageService._();
  static final SecureStorageService instance = SecureStorageService._();

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  // ── Keys ─────────────────────────────────────────────────────────
  static const _kApiKey = 'breach_api_key';
  static const _kFcmToken = 'breach_fcm_token';
  static const _kFcmTokenTimestamp = 'breach_fcm_token_ts';

  // ── API Key ──────────────────────────────────────────────────────
  Future<String?> getApiKey() => _storage.read(key: _kApiKey);
  Future<void> setApiKey(String key) => _storage.write(key: _kApiKey, value: key);

  // ── FCM Token ────────────────────────────────────────────────────
  Future<String?> getFcmToken() => _storage.read(key: _kFcmToken);
  Future<void> setFcmToken(String token) async {
    await _storage.write(key: _kFcmToken, value: token);
    await _storage.write(
      key: _kFcmTokenTimestamp,
      value: DateTime.now().toIso8601String(),
    );
  }

  Future<bool> isFcmTokenExpired({Duration maxAge = const Duration(hours: 24)}) async {
    final ts = await _storage.read(key: _kFcmTokenTimestamp);
    if (ts == null) return true;
    final stored = DateTime.tryParse(ts);
    if (stored == null) return true;
    return DateTime.now().difference(stored) > maxAge;
  }

  // ── Wipe all ─────────────────────────────────────────────────────
  Future<void> clearAll() => _storage.deleteAll();

  // ── Generic ──────────────────────────────────────────────────────
  Future<String?> read(String key) => _storage.read(key: key);
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);
  Future<void> delete(String key) => _storage.delete(key: key);
}
