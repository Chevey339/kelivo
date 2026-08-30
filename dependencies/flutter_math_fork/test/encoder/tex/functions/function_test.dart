import 'package:flutter_test/flutter_test.dart';

import '../recode.dart';

void main() {
  group('FunctionNode encoding', () {
    test('general encoding', () {
      const testStrings = [
        '\\operatorname{abc}{def}',
      ];
      for (final testString in testStrings) {
        expect(recodeTex(testString), testString);
      }
    });

    test('optimization', () {
      const testStrings = [
        '\\sin{a}',
        '\\sin{abc}',
        '\\sin_1^2{abc}',
        '\\sin\\limits_1^2{abc}',
        '\\sin\\limits^2{abc}',
        '\\sin\\limits_1{abc}',
        '\\lim_1{abc}',
        '\\lim\\nolimits_1{abc}',
      ];
      for (final testString in testStrings) {
        expect(recodeTex(testString), testString);
      }
    });
  });
}
