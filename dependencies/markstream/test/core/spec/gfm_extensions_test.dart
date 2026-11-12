import 'package:flutter_test/flutter_test.dart';
import 'package:markstream/markstream_core.dart';

import 'spec_instrumentation.dart';

void main() {
  test('GFM 0.29 extension conformance instrument', () {
    final cases = loadSpec('gfm-0.29-extensions.json');
    expect(cases, hasLength(27));
    expect(cases.map((e) => e['section']).toSet(), {
      'Tables (extension)',
      'Task list items (extension)',
      'Strikethrough (extension)',
      'Autolinks (extension)',
    });
    instrumentSpec('gfm-0.29-extensions', cases, const ParserOptions.gfm());
  });
}
