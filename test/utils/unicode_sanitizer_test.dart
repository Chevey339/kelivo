import 'package:Kelivo/utils/unicode_sanitizer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('valid Unicode keeps the original string instance', () {
    final text = ['中文', '😀', 'e\u0301', '\r\n', 'text'].join();
    expect(identical(UnicodeSanitizer.sanitize(text), text), isTrue);
  });

  test(
    'isolated high and low surrogates are replaced, valid pairs survive',
    () {
      const source = 'a\uD800b\uDC00c😀\uDFFF';
      expect(UnicodeSanitizer.sanitize(source), 'a�b�c😀�');
      expect(UnicodeSanitizer.sanitize(''), '');
    },
  );
}
