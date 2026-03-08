// ── Headlines Service ────────────────────────────────────────────
// MED-05 FIX: RSS content sanitized before return.
import 'package:flutter/foundation.dart';
import '../config/api.dart';
import '../utils/sanitizer.dart';
import 'api_service.dart';

class HeadlinesService {
  HeadlinesService._();
  static final HeadlinesService instance = HeadlinesService._();

  final _api = ApiService.instance;

  /// Fetch headlines from the backend RSS aggregator.
  /// Returns a list of {title, source, pubDate, link}.
  Future<List<Map<String, dynamic>>> fetchHeadlines() async {
    try {
      final response = await _api.get<dynamic>(Api.headlines);
      final data = response.data;
      if (data is Map<String, dynamic>) {
        final items = data['items'];
        if (items is List) {
          return items.map<Map<String, dynamic>>((e) {
            final m = e as Map<String, dynamic>;
            // MED-05: Sanitize all RSS fields
            return sanitizeHeadline(m);
          }).toList();
        }
      }
      return [];
    } catch (e) {
      debugPrint('[Headlines] Fetch error: $e');
      return [];
    }
  }
}
