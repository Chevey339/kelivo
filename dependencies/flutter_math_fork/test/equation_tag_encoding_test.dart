import 'package:flutter_math_fork/ast.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:flutter_math_fork/src/encoder/tex/encoder.dart';
import 'package:flutter_math_fork/src/parser/tex/parser.dart';
import 'package:flutter_math_fork/src/widgets/controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';

EquationRowNode _parse(String source) => TexParser(
      source,
      const TexParserSettings(displayMode: true),
    ).parse();

Iterable<GreenNode> _descendants(GreenNode node) sync* {
  yield node;
  for (final child in node.children) {
    if (child != null) yield* _descendants(child);
  }
}

String _symbols(GreenNode node) => _descendants(node)
    .whereType<SymbolNode>()
    .map((symbol) => symbol.symbol)
    .join();

Object? _nodeSemantics(GreenNode node) {
  if (node is SymbolNode) {
    return {
      'type': node.runtimeType,
      'symbol': node.symbol,
      'mode': node.mode,
      'atomType': node.overrideAtomType,
      'font': node.overrideFont,
    };
  }
  if (node is StyleNode) {
    final diff = node.optionsDiff;
    return {
      'type': node.runtimeType,
      'style': diff.style,
      'size': diff.size,
      'color': diff.color,
      'textFont': diff.textFontOptions,
      'mathFont': diff.mathFontOptions,
      'children': node.children.map(_nodeSemantics).toList(),
    };
  }
  return {
    'type': node.runtimeType,
    'children':
        node.children.whereType<GreenNode>().map(_nodeSemantics).toList(),
  };
}

List<Object?> _arraySemantics(GreenNode root) => _descendants(root)
    .whereType<EquationArrayNode>()
    .map<Object?>((array) => {
          'environment': array.environment,
          'alignmentColumns': array.alignmentColumns,
          'displayLayout': array.displayLayout,
          'body': array.body.map(_symbols).toList(),
          'tags': array.tags.map((tag) {
            if (tag == null) return null;
            expect(tag, isA<EquationTagNode>());
            final semanticTag = tag as EquationTagNode;
            return {
              'literal': semanticTag.literal,
              'body': _nodeSemantics(semanticTag.body),
              'display': _nodeSemantics(semanticTag),
            };
          }).toList(),
        })
    .toList();

String _encode(GreenNode node) =>
    node.encodeTeX(conf: TexEncodeConf.mathParamConf);

void main() {
  test('encodes tags and their equation environments exactly', () {
    const sources = [
      r'x\tag{A}',
      r'x\tag*{A}',
      r'\begin{equation}x+y\tag{1}\end{equation}',
      r'\begin{equation}\begin{aligned}a&=b\\c&=d\end{aligned}'
          r'\tag{A}\end{equation}',
      r'\begin{align}a&=b\tag{A}\\c&=d\tag*{B}\end{align}',
      r'\begin{gather}a=b\\c=d\tag*{B}\end{gather}',
      r'\begin{alignat}{1}a&=b\tag{A}\\c&=d\end{alignat}',
    ];

    for (final source in sources) {
      expect(_encode(_parse(source)), source, reason: source);
    }
  });

  test('encoded tags parse back to equivalent semantic arrays', () {
    const sources = [
      r'x\tag{A}',
      r'x\tag*{A}',
      r'\begin{equation}\begin{aligned}a&=b\\c&=d\end{aligned}'
          r'\tag{A}\end{equation}',
      r'\begin{align}a&=b\tag{A}\\c&=d\tag*{B}\end{align}',
      r'\begin{gather}a=b\\c=d\tag*{B}\end{gather}',
      r'x\tag{\textbf{A} $n+1$}',
      r'x\tag{\textbf{$n+1$}}',
      r'x\tag{\textit{a $n+1$ b}}',
      r'x\tag{\textcolor{red}{$n$}}',
    ];

    for (final source in sources) {
      final parsed = _parse(source);
      final encoded = _encode(parsed);
      final reparsed = _parse(encoded);
      expect(
        _arraySemantics(reparsed),
        _arraySemantics(parsed),
        reason: '$source -> $encoded',
      );
    }
  });

  test('recursively restores nested text and math mode boundaries', () {
    const cases = {
      r'x\tag{\textbf{$n+1$}}': r'x\tag{\textbf{\(n+1\)}}',
      r'x\tag{\textit{a $n+1$ b}}': r'x\tag{\textit{a \(n+1\) b}}',
      r'x\tag{\textcolor{red}{$n$}}': r'x\tag{\textcolor{#ff0000}{\(n\)}}',
    };

    for (final entry in cases.entries) {
      expect(_encode(_parse(entry.key)), entry.value, reason: entry.key);
    }
  });

  test('select-all copy retains tag commands and alignment semantics', () {
    const source = r'\begin{align}a&=b\tag{A}\\c&=d\tag*{B}\end{align}';
    final root = _parse(source);
    final controller = MathController(
      ast: SyntaxTree(greenRoot: root),
      selection: TextSelection(
        baseOffset: 0,
        extentOffset: root.capturedCursor - 1,
      ),
    );
    addTearDown(controller.dispose);

    final copied = controller.selectedNodes.encodeTex();
    expect(copied, source);
    expect(
      _arraySemantics(_parse(copied)),
      _arraySemantics(root),
    );
  });

  test('structural tag updates change the encoded semantic body', () {
    final root = _parse(r'x\tag{A}');
    final array = _descendants(root).whereType<EquationArrayNode>().single;
    final tag = array.tags.single! as EquationTagNode;
    final outerStyle = tag.children.single as StyleNode;
    final updatedStyle = outerStyle.copyWith(
      children: outerStyle.children
          .map(
            (child) => child is SymbolNode && child.symbol == 'A'
                ? SymbolNode(symbol: 'B', mode: Mode.text)
                : child,
          )
          .toList(growable: false),
    );
    final updatedTag = tag.updateChildren([updatedStyle]);
    final updatedArray = array.updateChildren([
      array.body.single,
      updatedTag,
    ]);

    expect(_symbols(updatedTag.body), 'B');
    expect(updatedTag.toJson()['body'], updatedTag.body.toJson());
    expect(_encode(updatedArray), r'x\tag{B}');

    final copiedTag = tag.copyWith(children: [updatedStyle]);
    expect(copiedTag, isA<EquationTagNode>());
    expect(copiedTag.literal, isFalse);
    expect(_encode(copiedTag), r'\tag{B}');

    final manuallyUpdatedTag = updatedTag.updateChildren([
      SymbolNode(symbol: 'C', mode: Mode.text),
    ]);
    final manuallyUpdatedArray = array.updateChildren([
      array.body.single,
      manuallyUpdatedTag,
    ]);
    expect(_symbols(manuallyUpdatedTag.body), 'C');
    expect(_encode(manuallyUpdatedArray), r'x\tag{C}');

    final customStyle = StyleNode(
      optionsDiff: const OptionsDiff(
        textFontOptions: PartialFontOptions(fontWeight: FontWeight.bold),
      ),
      children: [SymbolNode(symbol: 'D', mode: Mode.text)],
    );
    final styledLiteralTag = EquationTagNode(
      literal: true,
      displayBody: EquationRowNode(children: [customStyle]),
    );
    expect(styledLiteralTag.body.children, [customStyle]);
    expect(_encode(styledLiteralTag), r'\tag*{\textbf{D}}');
  });
}
