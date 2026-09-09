import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/services/workspace/unified_diff.dart';

void main() {
  test('golden diff for a single changed line', () {
    const oldText = 'line1\nline2\nline3\n';
    const newText = 'line1\nline2 changed\nline3\n';
    final diff = UnifiedDiff.compute(oldText, newText, path: 'sample.txt');
    expect(diff.added, 1);
    expect(diff.removed, 1);
    expect(diff.truncated, isFalse);
    expect(diff.text, '''
--- a/sample.txt
+++ b/sample.txt
@@ -1,3 +1,3 @@
 line1
-line2
+line2 changed
 line3
''');
  });

  test('counts pure additions and deletions', () {
    final added = UnifiedDiff.compute('', 'a\nb\n', path: 'f');
    expect(added.added, 2);
    expect(added.removed, 0);
    expect(added.text, contains('+a'));
    expect(added.text, contains('+b'));

    final removed = UnifiedDiff.compute('a\nb\n', '', path: 'f');
    expect(removed.added, 0);
    expect(removed.removed, 2);
  });

  test('truncates at a hunk boundary', () {
    final oldLines = <String>[
      'AAA',
      for (var i = 0; i < 12; i++) 'keep$i',
      'BBB',
    ];
    final newLines = <String>[
      'aaa',
      for (var i = 0; i < 12; i++) 'keep$i',
      'bbb',
    ];
    final full = UnifiedDiff.compute(
      oldLines.join('\n'),
      newLines.join('\n'),
      path: 'big.txt',
      context: 3,
    );
    expect(full.truncated, isFalse);
    expect(full.text, contains('AAA'));
    expect(full.text, contains('BBB'));
    expect(full.text.split('@@ ').length - 1, 2);

    final firstHunkEnd = full.text.indexOf('@@ -', 10);
    expect(firstHunkEnd, greaterThan(0));
    final budget = firstHunkEnd + 8;
    final truncated = UnifiedDiff.compute(
      oldLines.join('\n'),
      newLines.join('\n'),
      path: 'big.txt',
      context: 3,
      maxChars: budget,
    );
    expect(truncated.truncated, isTrue);
    expect(truncated.text, contains('... ('));
    expect(truncated.text, contains('more lines)'));
    expect(truncated.text, isNot(contains('+bbb')));
    expect(truncated.added, full.added);
    expect(truncated.removed, full.removed);
  });
}
