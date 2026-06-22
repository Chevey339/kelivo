import 'package:flutter_test/flutter_test.dart';
import 'package:markdown/markdown.dart' as md;

void main() {
  late md.Document doc;

  setUp(() {
    doc = md.Document(extensionSet: md.ExtensionSet.gitHubFlavored);
  });

  group('CJK emphasis parsing', () {
    test('bold with Chinese text only', () {
      final nodes = doc.parseLines(['**你好世界**']);
      final strong = _findStrong(nodes);
      expect(strong, isNotNull);
      expect(strong!.textContent, '你好世界');
    });

    test('bold with Chinese and fullwidth parenthesis (KNOWN BUG)', () {
      final nodes = doc.parseLines(['**苹果（Apple）**是一家公司']);
      final strong = _findStrong(nodes);
      print('AST: ${nodes.toString()}');
      expect(strong, isNull);
    });

    test('bold with ZWNJ workaround between ) and **', () {
      final fixed = '**苹果（Apple）\u200C**是一家公司';
      final nodes = doc.parseLines([fixed]);
      final strong = _findStrong(nodes);
      print('ZWNJ AST: ${nodes.toString()}');
      expect(strong, isNotNull);
    });
  });

  group('HTML inline tags', () {
    test('<br> is parsed as element with InlineHtmlSyntax', () {
      final doc2 = md.Document(
        inlineSyntaxes: [md.InlineHtmlSyntax()],
        extensionSet: md.ExtensionSet.gitHubFlavored,
      );
      final nodes = doc2.parseLines(['line1<br>line2']);
      print('BR AST: ${nodes.toString()}');
    });

    test('<br> without InlineHtmlSyntax falls through to text', () {
      final nodes = doc.parseLines(['line1<br>line2']);
      print('BR (no html syntax) AST: ${nodes.toString()}');
    });
  });

  group('Dollar math in markdown parser', () {
    test(r'$$...$$ is parsed as plain text by default', () {
      final nodes = doc.parseLines([
        r'$$c = \pm\sqrt{a^2 + b^2}$$',
      ]);
      print('AST: ${nodes.toString()}');
    });
  });
}

md.Element? _findStrong(List<md.Node> nodes) {
  for (final node in nodes) {
    if (node is md.Element) {
      if (node.tag == 'strong') return node;
      if (node.children != null) {
        final found = _findStrong(node.children!);
        if (found != null) return found;
      }
    }
  }
  return null;
}
