import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/services/workspace/edit_matchers.dart';

void main() {
  group('exact', () {
    test('replaces a unique occurrence', () {
      final result = applyEdit(
        original: 'hello world',
        oldText: 'world',
        newText: 'there',
      );
      expect(result, isA<EditApplied>());
      final applied = result as EditApplied;
      expect(applied.updated, 'hello there');
      expect(applied.replacements, 1);
      expect(applied.strategy, EditStrategy.exact);
    });

    test('replace_all replaces every non-overlapping match', () {
      final result = applyEdit(
        original: 'foo foo foo',
        oldText: 'foo',
        newText: 'bar',
        replaceAll: true,
      );
      final applied = result as EditApplied;
      expect(applied.updated, 'bar bar bar');
      expect(applied.replacements, 3);
      expect(applied.strategy, EditStrategy.exact);
    });

    test('ambiguous without replace_all', () {
      final result = applyEdit(
        original: 'foo foo',
        oldText: 'foo',
        newText: 'bar',
      );
      expect(result, isA<EditFailed>());
      final failed = result as EditFailed;
      expect(failed.failure, isA<EditAmbiguous>());
      final ambiguous = failed.failure as EditAmbiguous;
      expect(ambiguous.count, 2);
      expect(ambiguous.strategy, EditStrategy.exact);
      expect(
        failed.message,
        'old_string matches 2 locations (strategy: exact); '
        'add more surrounding context to make it unique, or set replace_all=true',
      );
    });
  });

  group('lineTrimmed', () {
    test('matches trimmed lines and re-indents newText', () {
      const original = 'void main() {\n    foo();\n    bar();\n}\n';
      const oldText = '  foo();\n  bar();';
      const newText = '  foo();\n  baz();';
      final result = applyEdit(
        original: original,
        oldText: oldText,
        newText: newText,
      );
      final applied = result as EditApplied;
      expect(applied.strategy, EditStrategy.lineTrimmed);
      expect(applied.updated, 'void main() {\n    foo();\n    baz();\n}\n');
      expect(applied.replacements, 1);
    });

    test('is disabled when oldText is only blank lines', () {
      final result = applyEdit(
        original: 'a\n\n\nb\n',
        oldText: '  \n  \n',
        newText: 'x\n',
      );
      expect(result, isA<EditFailed>());
      expect((result as EditFailed).failure, isA<EditNotFound>());
      expect(result.message, kEditNotFoundMessage);
    });

    test('replace_all on indented copies', () {
      const original = '    a\n    b\n    a\n    b\n';
      final result = applyEdit(
        original: original,
        oldText: 'a\nb',
        newText: 'c\nd',
        replaceAll: true,
      );
      final applied = result as EditApplied;
      expect(applied.strategy, EditStrategy.lineTrimmed);
      expect(applied.replacements, 2);
      expect(applied.updated, '    c\n    d\n    c\n    d\n');
    });
  });

  group('blockAnchor', () {
    test('matches first and last lines and ignores the middle', () {
      const original = 'line1\nCHANGED\nline3\n';
      const oldText = 'line1\nold middle\nline3\n';
      final result = applyEdit(
        original: original,
        oldText: oldText,
        newText: 'line1\nNEW\nline3\n',
      );
      final applied = result as EditApplied;
      expect(applied.strategy, EditStrategy.blockAnchor);
      expect(applied.updated, 'line1\nNEW\nline3\n');
    });

    test('requires at least three lines', () {
      final result = applyEdit(
        original: 'a\nb\n',
        oldText: 'a\nX',
        newText: 'a\nY',
      );
      expect(result, isA<EditFailed>());
    });

    test('ambiguous block anchors', () {
      const original = 'start\nm1\nend\nstart\nm2\nend\n';
      final result = applyEdit(
        original: original,
        oldText: 'start\nxxx\nend',
        newText: 'start\nYYY\nend',
      );
      final failed = result as EditFailed;
      expect(failed.failure, isA<EditAmbiguous>());
      expect(
        (failed.failure as EditAmbiguous).strategy,
        EditStrategy.blockAnchor,
      );
      expect(failed.message, contains('strategy: block_anchor'));
      expect(failed.message, contains('replace_all=true'));
    });
  });

  test('not-found message is ready to send to the model', () {
    final result = applyEdit(
      original: 'nothing here',
      oldText: 'missing',
      newText: 'x',
    );
    final failed = result as EditFailed;
    expect(failed.failure, isA<EditNotFound>());
    expect(
      failed.message,
      'old_string was not found, even with whitespace-tolerant matching; '
      'read the file again and copy old_string exactly from its current content',
    );
  });
}
