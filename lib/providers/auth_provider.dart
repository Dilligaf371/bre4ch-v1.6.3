// ── Auth Provider ────────────────────────────────────────────────
// CRIT-01 FIX: Removed hardcoded admin/admin credentials.
// Auth is now API-key based (injected via --dart-define at build time).
// No login screen — app opens directly to the dashboard.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/secure_storage_service.dart';

class AuthState {
  final bool isAuthenticated;

  const AuthState({this.isAuthenticated = true});
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(const AuthState(isAuthenticated: true)) {
    _initApiKey();
  }

  /// The API key used for backend requests (from env or secure storage).
  static const _envApiKey = String.fromEnvironment('BREACH_API_KEY', defaultValue: '');
  String _apiKey = _envApiKey;

  String get apiKey => _apiKey;

  Future<void> _initApiKey() async {
    // If env key is set at build time, persist it securely
    if (_envApiKey.isNotEmpty) {
      await SecureStorageService.instance.setApiKey(_envApiKey);
      _apiKey = _envApiKey;
    } else {
      // Try reading from secure storage (previously persisted)
      final stored = await SecureStorageService.instance.getApiKey();
      if (stored != null && stored.isNotEmpty) {
        _apiKey = stored;
      }
    }
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier();
});
