import 'package:flutter_math_fork/ast.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_math_fork/src/encoder/tex/encoder.dart';

void main() {
  group('accent encoding test', () {
    test('general encoding math', () {
      final bar = AccentNode(
        base: EquationRowNode.empty(),
        label: '\u00AF',
        isStretchy: false,
        isShifty: true,
      );
      expect(bar.encodeTeX(), '\\bar{}');

      final widehat = AccentNode(
        base: EquationRowNode.empty(),
        label: '\u005e',
        isStretchy: true,
        isShifty: true,
      );
      expect(widehat.encodeTeX(), '\\widehat{}');

      final overline = AccentNode(
        base: EquationRowNode.empty(),
        label: '\u00AF',
        isStretchy: true,
        isShifty: false,
      );
      expect(overline.encodeTeX(), '\\overline{}');
    });

    test('general encoding text', () {
      final bar = AccentNode(
        base: EquationRowNode.empty(),
        label: '\u00AF',
        isStretchy: false,
        isShifty: true,
      );
      expect(bar.encodeTeX(conf: TexEncodeConf.textConf), '\\={}');
    });
  });
}
