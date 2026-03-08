// ── Content Sanitizer ────────────────────────────────────────────
// MED-03: Validate API response shapes.
// MED-05: Strip HTML/scripts from RSS content before display.

/// Strip all HTML tags and decode common entities.
/// M-01 FIX: Loop stripping to handle nested/malformed tags.
String stripHtml(String input) {
  var cleaned = input;

  // Remove dangerous tags first (script, style, iframe, object, embed)
  for (final tag in ['script', 'style', 'iframe', 'object', 'embed', 'form']) {
    cleaned = cleaned.replaceAll(
      RegExp('<$tag[^>]*>[\\s\\S]*?</$tag>', caseSensitive: false), '');
  }

  // Strip event handler attributes before removing tags
  cleaned = cleaned.replaceAll(
    RegExp(r'\s+on\w+\s*=\s*["\u0027][^"]*["\u0027]', caseSensitive: false), '');

  // Loop-strip remaining tags (handles nested cases)
  final tagPattern = RegExp(r'<[^>]+>');
  while (tagPattern.hasMatch(cleaned)) {
    cleaned = cleaned.replaceAll(tagPattern, '');
  }

  // Decode HTML entities
  return cleaned
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll('&#x27;', "'")
      .replaceAll('&nbsp;', ' ')
      .replaceAllMapped(RegExp(r'&#(\d+);'), (m) {
        final code = int.tryParse(m.group(1) ?? '');
        return (code != null && code > 0 && code < 0x110000)
            ? String.fromCharCode(code)
            : '';
      })
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
