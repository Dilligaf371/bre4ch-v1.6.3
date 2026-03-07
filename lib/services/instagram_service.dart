// =============================================================================
// BRE4CH - Instagram SOCMINT Service
// HTTP fallback for real Instagram feed when backend scraper is available.
// =============================================================================

import '../config/api.dart';
import 'api_service.dart';

class InstagramService {
  InstagramService._();
  static final InstagramService instance = InstagramService._();

  final _api = ApiService.instance;

  /// Fetch latest Instagram SOCMINT items from the backend.
  /// Returns empty list when backend endpoint is not yet available.
  Future<List<Map<String, dynamic>>> fetchInstagramFeed() async {
    try {
      final response = await _api.get<dynamic>(Api.instagramFeed);
      final data = response.data;
      if (data is Map<String, dynamic>) {
        final items = data['items'];
        if (items is List) {
          return items
              .whereType<Map<String, dynamic>>()
              .toList();
        }
      }
      return [];
    } catch (_) {
      return [];
    }
  }
}
