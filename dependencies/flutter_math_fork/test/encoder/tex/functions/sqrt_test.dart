import 'package:flutter_test/flutter_test.dart';

import '../recode.dart';

void main() {
  group('SqrtNode encoding', () {
    test('general encoding', () {
      const testStrings = [
        '\\sqrt{a}',
        '\\sqrt[a]{b}',
      ];
      for (final testString in testStrings) {
        expect(recodeTex(testString), testString);
      }
    });
  });
}
