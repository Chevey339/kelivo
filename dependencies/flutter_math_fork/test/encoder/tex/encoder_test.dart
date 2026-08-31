import 'package:flutter_math_fork/ast.dart';
import 'package:flutter_math_fork/src/encoder/encoder.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_math_fork/src/encoder/tex/encoder.dart';

import 'recode.dart';

void main() {
  group('EquationRowEncoderResult', () {
    test('empty row', () {
      final result = EquationRowTexEncodeResult(<dynamic>[]);
      expect(result.stringify(TexEncodeConf.mathConf), '{}');
      expect(result.stringify(TexEncodeConf.mathParamConf), '');
    });

    test('normal row', () {
      final result = EquationRowTexEncodeResult(<dynamic>[
        'a',
        StaticEncodeResult('b'),
        SymbolNode(symbol: 'c'),
        EquationRowNode.empty(),
      ]);
      expect(result.stringify(TexEncodeConf.mathConf), '{abc{}}');
      expect(result.stringify(TexEncodeConf.mathParamConf), 'abc{}');
    });

    test('symbol contanetation', () {
      const testStrings = [
        'i\\pi x',
        'i\\pi\\xi',
      ];
      for (final testString in testStrings) {
        expect(recodeTex(testString), testString);
      }
    });
  });
  group('TexCommandEncoderResult', () {
    test('basic spec lookup', () {
      final result =
          TexCommandEncodeResult(command: '\\frac', args: <dynamic>[]);
      expect(result.numArgs, 2);
      expect(result.numOptionalArgs, 0);
      expect(result.argModes, [null, null]);
    });

    test('empty math param', () {
      final result = TexCommandEncodeResult(
          command: '\\frac',
          args: <dynamic>[EquationRowNode.empty(), EquationRowNode.empty()]);
      expect(result.stringify(TexEncodeConf.mathConf), '\\frac{}{}');
    });

    test('single char math param', () {
      final result =
          TexCommandEncodeResult(command: '\\frac', args: <dynamic>['1', '2']);
      expect(result.stringify(TexEncodeConf.mathConf), '\\frac{1}{2}');
    });
  });
}
