// =============================================================================
// BRE4CH - Notification Preferences Provider
// Manages user push notification preferences with persistence
// =============================================================================

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/push_notification_service.dart';

// ── Preference State ────────────────────────────────────────────────

class NotificationPreferences {
  final bool enabled;
  final bool soundEnabled;
  final Set<String> countries;
  final Set<String> cities;
  final Set<String> types;
  final Set<String> severities;
  // Custom sound per severity level
  final String extremeSound;
  final String severeSound;
  final String moderateSound;

  const NotificationPreferences({
    this.enabled = false,
    this.soundEnabled = true,
    this.countries = const {},
    this.cities = const {},
    this.types = const {'danger'},
    this.severities = const {'extreme', 'severe'},
    this.extremeSound = 'default',
    this.severeSound = 'default',
    this.moderateSound = 'silent',
  });

  NotificationPreferences copyWith({
    bool? enabled,
    bool? soundEnabled,
    Set<String>? countries,
    Set<String>? cities,
    Set<String>? types,
    Set<String>? severities,
    String? extremeSound,
    String? severeSound,
    String? moderateSound,
  }) {
    return NotificationPreferences(
      enabled: enabled ?? this.enabled,
      soundEnabled: soundEnabled ?? this.soundEnabled,
      countries: countries ?? this.countries,
      cities: cities ?? this.cities,
      types: types ?? this.types,
      severities: severities ?? this.severities,
      extremeSound: extremeSound ?? this.extremeSound,
      severeSound: severeSound ?? this.severeSound,
      moderateSound: moderateSound ?? this.moderateSound,
    );
  }
}

/// Available alert sounds (key → display label)
const Map<String, String> availableAlertSounds = {
  'default': '🔔  System Default',
  'silent': '🔇  Silent',
};

// ── Available Options ───────────────────────────────────────────────

const Map<String, String> availableCountries = {
  'uae': '🇦🇪  UAE',
  'israel': '🇮🇱  Israel',
  'iran': '🇮🇷  Iran',
  'ksa': '🇸🇦  Saudi Arabia',
  'kuwait': '🇰🇼  Kuwait',
  'bahrain': '🇧🇭  Bahrain',
  'qatar': '🇶🇦  Qatar',
  'oman': '🇴🇲  Oman',
  'jordan': '🇯🇴  Jordan',
  'lebanon': '🇱🇧  Lebanon',
};

const Map<String, Map<String, String>> citiesByCountry = {
  'uae': {
    'dubai': 'Dubai',
    'abu_dhabi': 'Abu Dhabi',
    'sharjah': 'Sharjah',
    'ajman': 'Ajman',
    'rak': 'Ras Al Khaimah',
    'fujairah': 'Fujairah',
  },
  'israel': {
    'tel_aviv': 'Tel Aviv',
    'jerusalem': 'Jerusalem',
    'haifa': 'Haifa',
    'beer_sheva': "Be'er Sheva",
    'netanya': 'Netanya',
  },
  'ksa': {
    'riyadh': 'Riyadh',
    'jeddah': 'Jeddah',
    'dammam': 'Dammam',
  },
  'qatar': {'doha': 'Doha'},
  'bahrain': {'manama': 'Manama'},
  'kuwait': {'kuwait_city': 'Kuwait City'},
  'oman': {'muscat': 'Muscat'},
  'jordan': {'amman': 'Amman'},
  'lebanon': {'beirut': 'Beirut'},
  'iran': {'tehran': 'Tehran', 'isfahan': 'Isfahan'},
};

const Map<String, String> availableTypes = {
  'danger': '⚠️  Immediate Danger',
  'shelter': '🛡️  Shelters',
  'embassy': '🏛️  Embassies',
  'airport': '✈️  Airports',
};

const Map<String, String> availableSeverities = {
  'extreme': '🔴  EXTREME',
  'severe': '🟠  SEVERE',
  'moderate': '🟡  MODERATE',
};

// ── Notifier ────────────────────────────────────────────────────────

class NotificationPreferencesNotifier
    extends StateNotifier<NotificationPreferences> {
  NotificationPreferencesNotifier() : super(const NotificationPreferences()) {
    _load();
  }

  final _push = PushNotificationService.instance;

  static const _prefsPrefix = 'notif_pref_';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool('${_prefsPrefix}enabled') ?? false;
    final soundEnabled = prefs.getBool('${_prefsPrefix}sound_enabled') ?? true;
    final countries =
        (prefs.getStringList('${_prefsPrefix}countries') ?? []).toSet();
    final cities =
        (prefs.getStringList('${_prefsPrefix}cities') ?? []).toSet();
    final types =
        (prefs.getStringList('${_prefsPrefix}types') ?? ['danger']).toSet();
    final severities =
        (prefs.getStringList('${_prefsPrefix}severities') ?? ['extreme', 'severe'])
            .toSet();
    final extremeSound = prefs.getString('${_prefsPrefix}sound_extreme') ?? 'default';
    final severeSound = prefs.getString('${_prefsPrefix}sound_severe') ?? 'default';
    final moderateSound = prefs.getString('${_prefsPrefix}sound_moderate') ?? 'silent';

    state = NotificationPreferences(
      enabled: enabled,
      soundEnabled: soundEnabled,
      countries: countries,
      cities: cities,
      types: types,
      severities: severities,
      extremeSound: extremeSound,
      severeSound: severeSound,
      moderateSound: moderateSound,
    );
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('${_prefsPrefix}enabled', state.enabled);
    await prefs.setBool('${_prefsPrefix}sound_enabled', state.soundEnabled);
    await prefs.setStringList(
        '${_prefsPrefix}countries', state.countries.toList());
    await prefs.setStringList('${_prefsPrefix}cities', state.cities.toList());
    await prefs.setStringList('${_prefsPrefix}types', state.types.toList());
    await prefs.setStringList(
        '${_prefsPrefix}severities', state.severities.toList());
    await prefs.setString('${_prefsPrefix}sound_extreme', state.extremeSound);
    await prefs.setString('${_prefsPrefix}sound_severe', state.severeSound);
    await prefs.setString('${_prefsPrefix}sound_moderate', state.moderateSound);
  }

  Future<void> toggleEnabled(bool value) async {
    state = state.copyWith(enabled: value);
    await _save();
    // FCM sync in background — don't block UI
    if (value) {
      _push.initialize().then((_) => _syncAllSubscriptions()).catchError((e) {
        debugPrint('[NOTIF] Enable sync error: $e');
      });
    } else {
      _nuclearUnsubscribe().catchError((e) {
        debugPrint('[NOTIF] Disable sync error: $e');
      });
    }
  }

  Future<void> toggleSound(bool value) async {
    state = state.copyWith(soundEnabled: value);
    await _save();
  }

  Future<void> setExtremeSound(String sound) async {
    state = state.copyWith(extremeSound: sound);
    await _save();
  }

  Future<void> setSevereSound(String sound) async {
    state = state.copyWith(severeSound: sound);
    await _save();
  }

  Future<void> setModerateSound(String sound) async {
    state = state.copyWith(moderateSound: sound);
    await _save();
  }

  Future<void> toggleCountry(String code, bool subscribe) async {
    final updated = Set<String>.from(state.countries);
    if (subscribe) {
      updated.add(code);
    } else {
      updated.remove(code);
      // Also remove cities of this country
      final countryCities = citiesByCountry[code]?.keys ?? [];
      final updatedCities = Set<String>.from(state.cities)
        ..removeAll(countryCities);
      state = state.copyWith(cities: updatedCities);
    }
    state = state.copyWith(countries: updated);
    await _save();
    // FCM sync in background — manage breach_all vs country-specific
    _syncFcm(() async {
      if (subscribe) {
        await _push.subscribeToCountry(code);
        // First country added → leave breach_all so we only get this country
        if (updated.length == 1) {
          await _push.unsubscribeFromTopic('all');
        }
      } else {
        await _push.unsubscribeFromCountry(code);
        for (final city in citiesByCountry[code]?.keys ?? <String>[]) {
          await _push.unsubscribeFromCity(city);
        }
        // Last country removed → go back to breach_all (global)
        if (updated.isEmpty) {
          await _push.subscribeToTopic('all');
        }
      }
    });
  }

  Future<void> toggleCity(String slug, bool subscribe) async {
    final updated = Set<String>.from(state.cities);
    if (subscribe) {
      updated.add(slug);
    } else {
      updated.remove(slug);
    }
    state = state.copyWith(cities: updated);
    await _save();
    _syncFcm(() => subscribe
        ? _push.subscribeToCity(slug)
        : _push.unsubscribeFromCity(slug));
  }

  Future<void> toggleType(String type, bool subscribe) async {
    final updated = Set<String>.from(state.types);
    if (subscribe) {
      updated.add(type);
    } else {
      updated.remove(type);
    }
    state = state.copyWith(types: updated);
    await _save();
    // Type filtering is client-side only (no FCM topic).
    // FCM topics for type caused cross-contamination with country filters.
  }

  Future<void> toggleSeverity(String level, bool subscribe) async {
    final updated = Set<String>.from(state.severities);
    if (subscribe) {
      updated.add(level);
    } else {
      updated.remove(level);
    }
    state = state.copyWith(severities: updated);
    await _save();
    // Severity filtering is client-side only (no FCM topic).
    // FCM topics for severity caused cross-contamination with country filters.
  }

  /// Fire-and-forget FCM sync — never blocks UI
  void _syncFcm(Future<void> Function() action) {
    if (!state.enabled) return;
    action().catchError((e) {
      debugPrint('[NOTIF] FCM sync error: $e');
    });
  }

  Future<void> _syncAllSubscriptions() async {
    // ── v1.8.2 fix: only use breach_all + country topics ──
    // Severity/type topics caused cross-contamination (e.g. subscribing to
    // UAE still received ALL "extreme" alerts worldwide).

    // 1. Clean up legacy severity/type FCM topics
    for (final s in availableSeverities.keys) {
      try { await _push.unsubscribeFromSeverity(s); } catch (_) {}
    }
    for (final t in availableTypes.keys) {
      try { await _push.unsubscribeFromType(t); } catch (_) {}
    }

    // 2. Subscribe to correct topics
    if (state.countries.isEmpty) {
      // No country filter → subscribe to breach_all (global)
      try { await _push.subscribeToTopic('all'); } catch (_) {}
    } else {
      // Country filter active → specific country topics only
      try { await _push.unsubscribeFromTopic('all'); } catch (_) {}
      for (final c in state.countries) {
        try { await _push.subscribeToCountry(c); } catch (_) {}
      }
      for (final c in state.cities) {
        try { await _push.subscribeToCity(c); } catch (_) {}
      }
    }
    debugPrint('[NOTIF] Synced subscriptions (countries: ${state.countries}, breach_all: ${state.countries.isEmpty})');
  }

  /// Nuclear unsubscribe — clears ALL known FCM topics regardless of state.
  /// Called when user disables notifications entirely.
  Future<void> _nuclearUnsubscribe() async {
    // breach_all
    try { await _push.unsubscribeFromTopic('all'); } catch (_) {}
    // ALL known countries (not just state.countries — catches stale subs)
    for (final c in availableCountries.keys) {
      try { await _push.unsubscribeFromCountry(c); } catch (_) {}
    }
    // ALL known cities
    for (final country in citiesByCountry.entries) {
      for (final city in country.value.keys) {
        try { await _push.unsubscribeFromCity(city); } catch (_) {}
      }
    }
    // Legacy severity/type topics (clean up old subscriptions)
    for (final s in availableSeverities.keys) {
      try { await _push.unsubscribeFromSeverity(s); } catch (_) {}
    }
    for (final t in availableTypes.keys) {
      try { await _push.unsubscribeFromType(t); } catch (_) {}
    }
    // Clear persisted subscription list
    await _push.clearAllSubscriptions();
    debugPrint('[NOTIF] Nuclear unsubscribe complete');
  }
}

// ── Provider ────────────────────────────────────────────────────────

final notificationPreferencesProvider = StateNotifierProvider<
    NotificationPreferencesNotifier, NotificationPreferences>((ref) {
  return NotificationPreferencesNotifier();
});
