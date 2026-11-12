import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:Kelivo/shared/text_input/compact_edit.dart';

void main() {
  test(
    'coalescing preserves mixed sequential replacements and untouched text',
    () {
      final random = Random(1238);
      for (var sample = 0; sample < 2000; sample++) {
        final original = '中文 abcdefghijklmnopqrstuvwxyz\n' * 4;
        var edited = original;
        final patches = <List<Object>>[];
        for (var i = 0; i < 12; i++) {
          final start = random.nextInt(edited.length + 1);
          final end = start + random.nextInt(edited.length - start + 1);
          final insertion = ['中', '', 'hi\nthere', 'x' * 20][random.nextInt(4)];
          patches.add([start, end, insertion]);
          edited = edited.replaceRange(start, end, insertion);
        }
        final combined = CompactEdit.coalesce(original, patches)!;
        expect(
          original.replaceRange(combined.start, combined.end, combined.text),
          edited,
          reason: 'sample $sample: $patches',
        );
      }
    },
  );

  test('selected paste and emoji replacements keep exact UTF-16 offsets', () {
    const original = 'start😀中文end';
    final combined = CompactEdit.coalesce(original, [
      [5, 7, ''],
      [5, 5, '👨‍👩‍👧‍👦\n'],
    ])!;
    expect(combined.start, 5);
    expect(combined.end, 7);
    expect(
      original.replaceRange(combined.start, combined.end, combined.text),
      'start👨‍👩‍👧‍👦\n中文end',
    );
  });
}
