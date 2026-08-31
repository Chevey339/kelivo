import 'package:flutter_test/flutter_test.dart';

import '../recode.dart';

void main() {
  group('MultiscriptsNode encoding', () {
    test('general encoding', () {
      const testStrings = [
        'a_b^c',
        'a_b',
        'a^c',
        '{ab}_{12}^{cd}',
        '1_{12}^{cd}',
      ];
      for (final testString in testStrings) {
        expect(recodeTex(testString), testString);
      }
    });
  });
}
