import 'package:flutter_test/flutter_test.dart';
import 'package:html2md/html2md.dart' as html2md;

void main() {
  group('fetch_markdown script/style ignore', () {
    test('plain text without HTML tags passes through unchanged', () {
      final md = html2md.convert('Hello world', ignore: ['script', 'style']);
      expect(md, contains('Hello world'));
    });

    test('script element content is stripped from markdown output', () {
      const html = '<p>Hello</p><script>alert("xss")</script><p>World</p>';
      final md = html2md.convert(html, ignore: ['script', 'style']);
      expect(md, contains('Hello'));
      expect(md, contains('World'));
      expect(md, isNot(contains('alert')));
      expect(md, isNot(contains('xss')));
    });

    test('style element content is stripped from markdown output', () {
      const html = '<p>Content</p><style>body{color:red}</style>';
      final md = html2md.convert(html, ignore: ['style']);
      expect(md, contains('Content'));
      expect(md, isNot(contains('color:red')));
      expect(md, isNot(contains('body{')));
    });

    test('both script and style elements are stripped simultaneously', () {
      const html = '<script>js</script><p>Hello</p><style>css</style>';
      final md = html2md.convert(html, ignore: ['script', 'style']);
      expect(md, contains('Hello'));
      expect(md, isNot(contains('js')));
      expect(md, isNot(contains('css')));
    });

    test('nested script inside body is stripped', () {
      const html =
          '<html><body><p>Visible</p><script>nested</script></body></html>';
      final md = html2md.convert(html, ignore: ['script', 'style']);
      expect(md, contains('Visible'));
      expect(md, isNot(contains('nested')));
    });
  });
}
