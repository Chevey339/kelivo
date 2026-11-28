import 'package:flutter_test/flutter_test.dart';
import 'package:markstream/markstream_core.dart';

const _url = 'https://api-docs.deepseek.com/zh-cn/guides/document_parsing';
const _suffix = '只告诉我这一页列出的上传用途（purpose）有哪些。';

void main() {
  test('the issue 1555 link and adjacent prose retain their source spans', () {
    const prefix = '请读取 ';
    const source = '$prefix$_url$_suffix';
    final stream = IncrementalDocument();
    for (var end = prefix.length + _url.length; end <= source.length; end++) {
      final partial = source.substring(0, end);
      final doc = stream.update(partial, streaming: true);
      final nodes = doc.children.single.children;
      final link = nodes.whereType<LinkNode>().single;
      expect(link.destination, _url, reason: partial);
      expect(link.span.slice(partial), _url);
      expect(toPlainText(link), _url);
      expect(toPlainText(doc), partial);
      expect(doc.toJson(), const MarkdownParser().parse(partial).toJson());
    }
    final tail =
        stream.update(source).children.single.children.last as TextNode;
    expect(tail.text, _suffix);
    expect(tail.span.slice(source), _suffix);
  });

  test(
    'prose and punctuation delimit bare URLs without consuming the next link',
    () {
      const cases = {
        '看https://a.test/path日本語': ['https://a.test/path'],
        'www.example.com안내': ['http://www.example.com'],
        'https://a.test/a(b)𠀀文': ['https://a.test/a(b)'],
        'https://a.test/path😀说明': ['https://a.test/path'],
        'https://a.test/path🇨🇳说明': ['https://a.test/path'],
        '(www.example.com/path.)说明': ['http://www.example.com/path'],
        '(https://a.test/我，机器人.pdf)': ['https://a.test/我，机器人.pdf'],
        'Download https://a.test/我，机器人.pdf.': ['https://a.test/我，机器人.pdf'],
        'https://a.test。下一句': ['https://a.test'],
        'https://a.test/doc～请点这里': ['https://a.test/doc'],
        'https://a.test/doc只告诉我API/SDK的区别。': ['https://a.test/doc'],
        'https://a.test/doc请看第2.1节。': ['https://a.test/doc'],
        'https://a.test:8080见A/B说明。': ['https://a.test:8080'],
        'https://a.test:8080查看/详情': ['https://a.test:8080'],
        'http://localhost:3000。查看/说明': ['http://localhost:3000'],
        'http://localhost:3000.查看详情': ['http://localhost:3000'],
        'http://[::1]。查看/说明': ['http://[::1]'],
        'http://[::ffff:192.0.2.1]查看/说明': ['http://[::ffff:192.0.2.1]'],
        'http://[::1]联系user@example.com': [
          'http://[::1]',
          'mailto:user@example.com',
        ],
        'https://a.test/path只看这个（demo）.': ['https://a.test/path'],
        'https://a.test和www.b.test': ['https://a.test', 'http://www.b.test'],
        'https://a.test/中文，联系first.last@example.com': [
          'https://a.test/中文',
          'mailto:first.last@example.com',
        ],
        'https://a.test/中文，联系first.last.team+chat@example.com': [
          'https://a.test/中文',
          'mailto:first.last.team+chat@example.com',
        ],
        'https://a.test/中文，另见www.b.test': [
          'https://a.test/中文',
          'http://www.b.test',
        ],
        'https://a.test/中文或https://b.test/文档': [
          'https://a.test/中文或',
          'https://b.test/文档',
        ],
        'https://a.test/中文（另见https://b.test/）': [
          'https://a.test/中文',
          'https://b.test/',
        ],
        '（https://a.test），【https://b.test】、https://c.test。': [
          'https://a.test',
          'https://b.test',
          'https://c.test',
        ],
        'https://a.test/a看https://b.test/b': [
          'https://a.test/a',
          'https://b.test/b',
        ],
        'www.，https://。': <String>[],
        'https://a.test/path另见www.b.test/b': [
          'https://a.test/path',
          'http://www.b.test/b',
        ],
        'https://a.test/path联系a@example.com': [
          'https://a.test/path',
          'mailto:a@example.com',
        ],
        '用户user@example.com后文': ['mailto:user@example.com'],
      };
      for (final entry in cases.entries) {
        final nodes = const InlineParser().parse(entry.key);
        expect(
          nodes.whereType<LinkNode>().map((n) => n.destination),
          entry.value,
          reason: entry.key,
        );
      }
    },
  );

  test(
    'international hosts, paths, query values and fragments remain linkable',
    () {
      for (final url in [
        'https://例子.测试/文档',
        'https://café.example/résumé',
        'https://www.abc中文网.com/导航',
        'https://zh.wikipedia.org/wiki/中文',
        'https://example.com/版本2说明',
        'https://example.com/Flutter教程.md',
        'https://example.com/Flutter教程/目录',
        'https://example.com/API教程/',
        'https://example.com/材料（译本）.pdf',
        'https://example.com/文件《初稿》.pdf',
        'https://example.com/我，机器人.pdf',
        'https://example.com/?file=我，机器人.pdf&lang=zh',
        'https://example.com/《入门》.pdf',
        'https://example.com/API教程（入门）.pdf',
        'https://example.com/AIニュース.pdf',
        'https://zh.wikipedia.org/wiki/水星（行星）',
        'https://例子。测试/资料',
        'https://例子．测试/资料',
        'https://例子｡测试/资料',
        'https://example．com',
        'https://例子。测试。公司',
        'https://www.abc中bar.com/导航',
        'https://user:80中文@example.com:8080/文档',
        'https://example.com/search?q=苹果，香蕉&lang=zh',
        'https://example.com/search?q=苹果，香蕉，梨&lang=zh',
        'https://example.com/search?q=苹果，香蕉&语言=中文',
        'https://example.com/search?q=苹果，香蕉&next=/中文',
        'https://example.com/search?q=苹果，香蕉&next=#章节',
        'https://example.com/search?q=苹果，香蕉#章节',
        'https://example.com/search?q=中文&lang=zh#章节',
        'https://example.com/search?q=Flutter教程&lang=zh',
        'https://example.com/%E4%B8%AD#章节',
        'http://[::1]:8080/路径',
      ]) {
        final link = const InlineParser().parse(url).single as LinkNode;
        expect(link.destination, url, reason: url);
        expect(link.span.slice(url), url);
      }
      const mixed = 'https://example.com/Flutter教程';
      for (final marked in ['<$mixed>附注', '[文章]($mixed)附注']) {
        final nodes = const InlineParser().parse(marked);
        expect(nodes.whereType<LinkNode>().single.destination, mixed);
        expect((nodes.last as TextNode).text, '附注');
      }
      final strict = const InlineParser(options: ParserOptions.gfm());
      expect((strict.parse(mixed).single as LinkNode).destination, mixed);
    },
  );
}
