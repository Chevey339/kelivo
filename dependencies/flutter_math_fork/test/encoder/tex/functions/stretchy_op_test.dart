import 'package:flutter_math_fork/ast.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_math_fork/src/encoder/tex/encoder.dart';

void main() {
  group('StretchyOp encoding test', () {
    test('general encoding', () {
      final node1 = StretchyOpNode(
        symbol: '\u2192',
        above: EquationRowNode(children: []),
        below: EquationRowNode(children: []),
      );
      expect(node1.encodeTeX(), '\\xrightarrow{}');

      final node2 = StretchyOpNode(
        symbol: '\u2192',
        above: EquationRowNode(children: [SymbolNode(symbol: 'a')]),
        below: EquationRowNode(children: []),
      );
      expect(node2.encodeTeX(), '\\xrightarrow[a]{}');
    });
  });
}
