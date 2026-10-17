import 'package:flutter_test/flutter_test.dart';
import 'package:markstream/markstream_core.dart';

import 'spec_instrumentation.dart';

void main() {
  test('CommonMark 0.31.2 conformance instrument', () {
    final cases = loadSpec('commonmark-0.31.2.json');
    expect(cases, hasLength(652));
    instrumentSpec(
      'commonmark-0.31.2',
      cases,
      const ParserOptions.commonMark(),
    );
  });
}
