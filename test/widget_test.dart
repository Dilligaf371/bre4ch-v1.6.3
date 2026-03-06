// Smoke test — verifies imports compile and key classes exist.
// Full widget tests require mocking Dio/FCM/WebSocket services.

import 'package:flutter_test/flutter_test.dart';
import 'package:breach/config/api.dart';
import 'package:breach/config/constants.dart';
import 'package:breach/utils/sanitizer.dart';
import 'package:breach/services/secure_storage_service.dart';

void main() {
  test('API configuration is valid', () {
    expect(Api.base, isNotEmpty);
    expect(Api.ws, startsWith('ws'));
    expect(Api.headlines, contains('/api/'));
  });

  test('Google Maps API key is not hardcoded', () {
    // CRIT-03: Key should come from --dart-define, not a hardcoded string
    // In test env, it will be empty (no --dart-define passed)
    expect(googleMapsApiKey, isEmpty,
        reason: 'API key must be injected via --dart-define, not hardcoded');
  });

  test('Sanitizer strips HTML tags', () {
    expect(stripHtml('<script>alert("xss")</script>hello'), equals('hello'));
    expect(stripHtml('<b>bold</b> text'), equals('bold text'));
    expect(stripHtml('&amp; &lt;'), equals('& <'));
  });

  test('Sanitizer validates URLs', () {
    final result = sanitizeHeadline({
      'title': '<b>Test</b>',
      'source': 'Reuters',
      'pubDate': '2026-03-06',
      'link': 'javascript:alert(1)',
    });
    expect(result['title'], equals('Test'));
    expect(result['link'], isEmpty, reason: 'javascript: URLs must be rejected');
  });

  test('SecureStorageService is a singleton', () {
    expect(SecureStorageService.instance, same(SecureStorageService.instance));
  });

  test('CacheTtl values are reasonable', () {
    expect(CacheTtl.headlines.inMinutes, lessThanOrEqualTo(5));
    expect(CacheTtl.forces.inMinutes, lessThanOrEqualTo(15));
    expect(CacheTtl.defaultTtl.inMinutes, lessThanOrEqualTo(5));
  });
}
