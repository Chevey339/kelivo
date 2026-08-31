import 'package:flutter_test/flutter_test.dart';

import '../recode.dart';

void main() {
  group('NaryOperatorNode encoding', () {
    test('general encoding', () {
      const testStrings = [
        '\\sum{a}',
        '\\sum_a^b{c}',
        '\\sum_{a0}^b{cd}',
      ];
      for (final testString in testStrings) {
        expect(recodeTex(testString), testString);
      }
    });
  });
}
