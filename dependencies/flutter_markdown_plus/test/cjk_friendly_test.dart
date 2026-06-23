import 'package:flutter_test/flutter_test.dart';
import 'package:markdown/markdown.dart' as md;

// Copied inline to avoid depending on the app package.
class CjkFriendlyBoldSyntax extends md.InlineSyntax {
  CjkFriendlyBoldSyntax()
    : super(
        r'(?<!\*)\*\*(?!\*)(.+?)(?<!\*)\*\*(?!\*)',
        startCharacter: 0x2A,
      );

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    parser.addNode(md.Element('strong', [md.Text(match[1]!)]));
    return true;
  }
}

class CjkFriendlyItalicSyntax extends md.InlineSyntax {
  CjkFriendlyItalicSyntax()
    : super(
        r'(?<!\*)\*(?!\*)(.+?)(?<!\*)\*(?!\*)',
        startCharacter: 0x2A,
      );

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    parser.addNode(md.Element('em', [md.Text(match[1]!)]));
    return true;
  }
}

void main() {
  group('CJK-friendly bold (fullwidth punctuation)', () {
    late md.Document doc;

    setUp(() {
      doc = md.Document(
        blockSyntaxes: md.ExtensionSet.gitHubFlavored.blockSyntaxes,
        inlineSyntaxes: [
          CjkFriendlyBoldSyntax(),
          CjkFriendlyItalicSyntax(),
          ...md.ExtensionSet.gitHubFlavored.inlineSyntaxes,
        ],
      );
    });

    test('bold with fullwidth right parenthesis', () {
      // This is the known-bug case from gpt_markdown:
      // **苹果（Apple）** should produce <strong>苹果（Apple）</strong>
      final nodes = doc.parseLines(['**苹果（Apple）**是一家公司']);
      final strong = _findTag(nodes, 'strong');
      expect(strong, isNotNull);
      expect(strong!.textContent, '苹果（Apple）');
    });

    test('bold with fullwidth left parenthesis', () {
      final nodes = doc.parseLines(['**（重要）**通知']);
      final strong = _findTag(nodes, 'strong');
      expect(strong, isNotNull);
      expect(strong!.textContent, '（重要）');
    });

    test('bold with Chinese only', () {
      final nodes = doc.parseLines(['**你好世界**']);
      final strong = _findTag(nodes, 'strong');
      expect(strong, isNotNull);
      expect(strong!.textContent, '你好世界');
    });

    test('italic with fullwidth punctuation', () {
      final nodes = doc.parseLines(['*苹果（Apple）*']);
      final em = _findTag(nodes, 'em');
      expect(em, isNotNull);
      expect(em!.textContent, '苹果（Apple）');
    });

    test('bold with English text still works', () {
      final nodes = doc.parseLines(['**bold text**']);
      final strong = _findTag(nodes, 'strong');
      expect(strong, isNotNull);
      expect(strong!.textContent, 'bold text');
    });

    test('italic with English text still works', () {
      final nodes = doc.parseLines(['*italic text*']);
      final em = _findTag(nodes, 'em');
      expect(em, isNotNull);
      expect(em!.textContent, 'italic text');
    });

    test('bold inside paragraph works', () {
      final nodes = doc.parseLines(['Before **bold（粗体）** after.']);
      final p = _findTag(nodes, 'p');
      expect(p, isNotNull);
      final strong = _findTag([p!], 'strong');
      expect(strong, isNotNull);
      expect(strong!.textContent, 'bold（粗体）');
    });

    test('multiple bold segments', () {
      final nodes = doc.parseLines(['**第一段** 和 **第二段**']);
      final strongs = _findAllTags(nodes, 'strong');
      expect(strongs.length, 2);
      expect(strongs[0].textContent, '第一段');
      expect(strongs[1].textContent, '第二段');
    });
  });
}

md.Element? _findTag(List<md.Node> nodes, String tag) {
  final all = _findAllTags(nodes, tag);
  return all.isNotEmpty ? all.first : null;
}

List<md.Element> _findAllTags(List<md.Node> nodes, String tag) {
  final result = <md.Element>[];
  for (final node in nodes) {
    if (node is md.Element) {
      if (node.tag == tag) result.add(node);
      if (node.children != null) {
        result.addAll(_findAllTags(node.children!, tag));
      }
    }
  }
  return result;
}
