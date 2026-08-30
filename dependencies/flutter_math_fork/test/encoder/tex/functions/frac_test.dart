import 'package:flutter_test/flutter_test.dart';

import '../recode.dart';

void main() {
  group('frac encoding test', () {
    test('base frac encoding', () {
      expect(recodeTex('\\frac{a}{b}'), '\\frac{a}{b}');
      expect(recodeTex('\\cfrac{a}{b}'), '\\cfrac{a}{b}');
      expect(recodeTex('\\genfrac{}{}{1.0pt}{}{a}{b}'),
          '\\genfrac{}{}{1.0pt}{}{a}{b}');
    });

    test('frac optimization', () {
      expect(recodeTex('\\dfrac{a}{b}'), '\\dfrac{a}{b}');
      expect(recodeTex('\\tfrac{a}{b}'), '\\tfrac{a}{b}');
      expect(recodeTex('\\binom{a}{b}'), '\\binom{a}{b}');
      expect(recodeTex('\\genfrac{(}{\\}}{0.0pt}{0}{a}{b}'),
          '\\genfrac{(}{\\}}{0.0pt}{0}{a}{b}');
      expect(recodeTex('\\genfrac{}{}{0.0pt}{0}{a}{b}'),
          '\\genfrac{}{}{0.0pt}{0}{a}{b}');
    });
  });
}
