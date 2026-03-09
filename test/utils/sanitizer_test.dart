// ── Sanitizer Unit Tests ─────────────────────────────────────────
// Tests for stripHtml, sanitizeHeadline, validateResponseShape.

import 'package:flutter_test/flutter_test.dart';
import 'package:breach/utils/sanitizer.dart';

void main() {
  group('stripHtml', () {
    test('removes simple HTML tags', () {
      expect(stripHtml('<b>bold</b> text'), 'bold text');
      expect(stripHtml('<p>paragraph</p>'), 'paragraph');
      expect(stripHtml('<a href="x">link</a>'), 'link');
    });

    test('removes script tags with content', () {
      expect(stripHtml('<script>alert("xss")</script>hello'), 'hello');
      expect(stripHtml('before<script type="text/javascript">var x=1;</script>after'), 'beforeafter');
    });

    test('removes style tags with content', () {
      expect(stripHtml('<style>.foo{color:red}</style>text'), 'text');
    });

    test('removes iframe, object, embed, form tags', () {
      expect(stripHtml('<iframe src="evil.com"></iframe>safe'), 'safe');
      expect(stripHtml('<object data="x"></object>ok'), 'ok');
      expect(stripHtml('<embed src="x"></embed>ok'), 'ok');
      expect(stripHtml('<form action="x"><input></form>ok'), 'ok');
    });

    test('strips event handler attributes', () {
      expect(stripHtml('<div onclick="alert(1)">content</div>'), 'content');
      expect(stripHtml('<img onload="steal()" src="x">'), '');
    });

    test('handles nested/malformed tags via loop stripping', () {
      // '<<b>nested</b>>' → replaceAll removes <<b> and </b> in one pass → 'nested>'
      expect(stripHtml('<<b>nested</b>>'), 'nested>');
      expect(stripHtml('<div><span>deep</span></div>'), 'deep');
    });

    test('decodes &amp; &lt; &gt; &quot;', () {
      expect(stripHtml('&amp;'), '&');
      expect(stripHtml('&lt;'), '<');
      expect(stripHtml('&gt;'), '>');
      expect(stripHtml('&quot;'), '"');
    });

    test('decodes &#39; and &#x27; (apostrophes)', () {
      expect(stripHtml("it&#39;s"), "it's");
      expect(stripHtml("it&#x27;s"), "it's");
    });

    test('decodes &nbsp;', () {
      expect(stripHtml('hello&nbsp;world'), 'hello world');
    });

    test('decodes numeric HTML entities (&#NNN;)', () {
      expect(stripHtml('&#65;'), 'A'); // ASCII 65 = 'A'
      expect(stripHtml('&#233;'), '\u00e9'); // e-acute
    });

    test('handles edge case numeric entities', () {
      // Very large code points beyond Unicode range should produce empty
      expect(stripHtml('&#1114112;'), ''); // 0x110000 = out of range
    });

    test('trims whitespace', () {
      expect(stripHtml('  hello  '), 'hello');
      expect(stripHtml('\n\ttabs\n'), 'tabs');
    });

    test('passes through plain text unchanged', () {
      expect(stripHtml('no tags here'), 'no tags here');
      expect(stripHtml(''), '');
    });

    test('handles real-world RSS titles', () {
      expect(
        stripHtml('Iran launches &quot;massive&quot; drone &amp; missile attack'),
        'Iran launches "massive" drone & missile attack',
      );
    });
  });

  group('sanitizeHeadline', () {
    test('strips HTML from title and source', () {
      final result = sanitizeHeadline({
        'title': '<b>Breaking</b>: missile strike',
        'source': '<i>Reuters</i>',
        'pubDate': '2026-03-08',
        'link': 'https://reuters.com/article/123',
      });
      expect(result['title'], 'Breaking: missile strike');
      expect(result['source'], 'Reuters');
      expect(result['pubDate'], '2026-03-08');
      expect(result['link'], 'https://reuters.com/article/123');
    });

    test('rejects javascript: URLs', () {
      final result = sanitizeHeadline({
        'title': 'Test',
        'source': 'Test',
        'pubDate': '',
        'link': 'javascript:alert(1)',
      });
      expect(result['link'], isEmpty);
    });

    test('rejects data: URLs', () {
      final result = sanitizeHeadline({
        'title': 'Test',
        'source': 'Test',
        'pubDate': '',
        'link': 'data:text/html,<script>alert(1)</script>',
      });
      expect(result['link'], isEmpty);
    });

    test('allows http and https URLs', () {
      final http = sanitizeHeadline({
        'title': 'T', 'source': 'S', 'pubDate': '', 'link': 'http://example.com',
      });
      expect(http['link'], 'http://example.com');

      final https = sanitizeHeadline({
        'title': 'T', 'source': 'S', 'pubDate': '', 'link': 'https://example.com',
      });
      expect(https['link'], 'https://example.com');
    });

    test('handles null fields gracefully', () {
      final result = sanitizeHeadline({});
      expect(result['title'], isEmpty);
      expect(result['source'], isEmpty);
      expect(result['pubDate'], isEmpty);
      expect(result['link'], isEmpty);
    });
  });

  group('validateResponseShape', () {
    test('returns true when all keys present', () {
      expect(
        validateResponseShape({'a': 1, 'b': 2, 'c': 3}, ['a', 'b']),
        isTrue,
      );
    });

    test('returns false when a key is missing', () {
      expect(
        validateResponseShape({'a': 1}, ['a', 'b']),
        isFalse,
      );
    });

    test('returns false for non-Map data', () {
      expect(validateResponseShape([1, 2, 3], ['a']), isFalse);
      expect(validateResponseShape('string', ['a']), isFalse);
      expect(validateResponseShape(42, ['a']), isFalse);
      expect(validateResponseShape(null, ['a']), isFalse);
    });

    test('returns true with empty required keys', () {
      expect(validateResponseShape({'a': 1}, []), isTrue);
    });
  });
}
