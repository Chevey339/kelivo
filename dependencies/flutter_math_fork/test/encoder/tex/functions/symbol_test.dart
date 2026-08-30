import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_math_fork/src/ast/nodes/symbol.dart';
import 'package:flutter_math_fork/src/ast/syntax_tree.dart';
import 'package:flutter_math_fork/src/ast/types.dart';
import 'package:flutter_math_fork/src/encoder/tex/encoder.dart';
import 'package:flutter_math_fork/src/parser/tex/parser.dart';
import 'package:flutter_math_fork/src/parser/tex/settings.dart';

String recodeTexSymbol(String tex, [Mode mode = Mode.math]) {
  if (mode == Mode.text) {
    tex = '\\text{$tex}';
  }
  var node = TexParser(tex, const TexParserSettings()).parse().children.first;
  while (node is ParentableNode) {
    node = node.children.first!;
  }
  assert(node is SymbolNode);
  return node.encodeTeX(
    conf: mode == Mode.math ? TexEncodeConf.mathConf : TexEncodeConf.textConf,
  );
}

void main() {
  group('symbol encoding test', () {
    test('base math symbols', () {
      expect(recodeTexSymbol('a'), 'a');
      expect(recodeTexSymbol('0'), '0');
      expect(recodeTexSymbol('\\pm'), '\\pm');
    });

    test('base text symbols', () {
      expect(recodeTexSymbol('a', Mode.text), 'a');
      expect(recodeTexSymbol('0', Mode.text), '0');
      expect(recodeTexSymbol('\\dag', Mode.text), '\\dag');
    });

    test('escaped math symbols', () {
      expect(recodeTexSymbol('\\{'), '\\{');
      expect(recodeTexSymbol('\\}'), '\\}');
      expect(recodeTexSymbol('\\&'), '\\&');
      expect(recodeTexSymbol('\\#'), '\\#');
      expect(recodeTexSymbol('\\_'), '\\_');
    });
  });
}
