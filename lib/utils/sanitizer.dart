// ── Content Sanitizer ────────────────────────────────────────────
// MED-03: Validate API response shapes.
// MED-05: Strip HTML/scripts from RSS content before display.

/// Strip all HTML tags and decode common entities.
String stripHtml(String input) {
  return input
      .replaceAll(RegExp(r'<script[^>]*>[\s\S]*?</script>', caseSensitive: false), '')
      .replaceAll(RegExp(r'<style[^>]*>[\s\S]*?</style>', caseSensitive: false), '')
      .replaceAll(RegExp(r'<[^>]+>'), '')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll('&nbsp;', ' ')
      .trim();
}

/// Sanitize a headline map from RSS: strip tags, validate fields.
Map<String, dynamic> sanitizeHeadline(Map<String, dynamic> raw) {
  return {
    'title': stripHtml(raw['title']?.toString() ?? ''),
    'source': stripHtml(raw['source']?.toString() ?? ''),
    'pubDate': raw['pubDate']?.toString() ?? '',
    'link': _sanitizeUrl(raw['link']?.toString() ?? ''),
  };
}

/// Only allow http/https URLs.
String _sanitizeUrl(String url) {
  if (url.isEmpty) return '';
  final uri = Uri.tryParse(url);
  if (uri == null) return '';
  if (uri.scheme != 'http' && uri.scheme != 'https') return '';
  return url;
}

/// Validate that a JSON response is a Map with expected keys.
bool validateResponseShape(dynamic data, List<String> requiredKeys) {
  if (data is! Map<String, dynamic>) return false;
  return requiredKeys.every((k) => data.containsKey(k));
}
