import 'package:Kelivo/shared/widgets/streaming_code_fence.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('keeps body, language and closing state across token boundaries', () {
    for (final marker in ['```', '````', '~~~']) {
      final parser = StreamingCodeFenceParser();
      var source = '$marker dart\n';
      final code = 'const value = "中文";\n// `inline` remains code\n';
      for (final unit in code.split('')) {
        source += unit;
        final fence = parser.update(source, sourceStart: 0, appendOnly: true)!;
        expect(fence.language, 'dart');
        expect(fence.closed, false);
        expect(fence.code, source.substring('$marker dart\n'.length));
      }
      for (var i = 0; i < marker.length; i++) {
        source += marker[i];
        final fence = parser.update(source, sourceStart: 0, appendOnly: true)!;
        expect(fence.closed, i == marker.length - 1);
        if (fence.closed) expect(fence.code, code);
      }
      source += '\n';
      expect(
        parser.update(source, sourceStart: 0, appendOnly: true)!.code,
        code,
      );
      source += 'Following prose';
      expect(parser.update(source, sourceStart: 0, appendOnly: true), isNull);
    }
  });

  test('leaves preprocessing-sensitive syntax to the complete parser', () {
    for (final source in [
      '  ```dart\nbody\n```',
      '```dart\r\nbody\r\n```',
      '```text\n- ```other\nbody',
      '~~~text\n```nested\nbody',
      '```text\nbody\n``` following',
      '```text\n- \n```',
      '```<details>\nbody\n```',
    ]) {
      expect(StreamingCodeFenceParser().update(source), isNull, reason: source);
    }
  });

  test(
    'same-offset edits and a new source block discard the previous scan',
    () {
      final parser = StreamingCodeFenceParser();
      parser.update('```dart\noriginal', sourceStart: 0);
      expect(
        parser.update('```text\nreplacement\n```', sourceStart: 0)!.code,
        'replacement\n',
      );
      final next = parser.update(
        '~~~python\nnext',
        sourceStart: 200,
        appendOnly: true,
      )!;
      expect(next.language, 'python');
      expect(next.code, 'next');
      expect(next.closed, false);
    },
  );
}
