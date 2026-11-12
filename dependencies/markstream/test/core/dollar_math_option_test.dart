import 'package:flutter_test/flutter_test.dart';
import 'package:markstream/markstream_core.dart';

void main() {
  test('single-dollar toggle retains parenthesized and display formulas', () {
    final parser = MarkdownParser(
      options: const ParserOptions(dollarInlineMath: false),
    );
    final document = parser.parse(
      r'$price$ and \(x\)'
      '\n\n'
      r'$$y$$',
    );
    expect(toPlainText(document.children.first), r'$price$ and \(x\)');
    expect(
      document.children.first.children.whereType<MathInlineNode>().single.tex,
      'x',
    );
    expect(document.children.last, isA<MathBlockNode>());
    expect(
      const ParserOptions().copyWith(dollarInlineMath: false).dollarInlineMath,
      isFalse,
    );
  });
  test('table tokenization follows the single-dollar toggle', () {
    const source = '| a | b | c |\n| - | - | - |\n| \$a | b\$ | c |';
    final document = MarkdownParser(
      options: const ParserOptions(dollarInlineMath: false),
    ).parse(source);
    final row = (document.children.single as TableNode).children.last;
    expect(row.children.map(toPlainText), [r'$a', r'b$', 'c']);
  });
}
