import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'mirror_harness.dart';

void main() {
  final source = 'original text\n' * 400;
  testWidgets('app paste is committed before the next native input', (
    tester,
  ) async {
    final h = MirrorHarness(tester);
    await h.mount(source, 100);
    h.text.value = h.text.value.replaced(h.text.selection, 'APP');
    await tester.pump();
    expect(h.native.text, h.text.text);
    expect(h.native.selection.extentOffset, 103);
    await h.replace(103, 103, 'x');
    await tester.pump();
    expect(
      h.text.text,
      '${source.substring(0, 100)}APPx${source.substring(100)}',
    );
    expect(h.bridge.failures, isEmpty);
    await h.dispose();
  });

  testWidgets('stale app paste rebases over input accepted by native first', (
    tester,
  ) async {
    final h = MirrorHarness(tester);
    await h.mount(source, 100);
    h.holdAppCommands = true;
    h.text.value = h.text.value.replaced(h.text.selection, 'APP');
    await tester.pump();
    await h.replace(100, 100, 'x');
    await tester.pump();
    final expected = '${source.substring(0, 100)}xAPP${source.substring(100)}';
    expect(h.text.text, expected);
    await h.releaseAllAppCommands();
    expect(h.native.text, expected);
    expect(h.native.selection.extentOffset, 104);
    expect(h.bridge.failures, isEmpty);
    await h.dispose();
  });

  testWidgets(
    'undo before paste acknowledgement keeps concurrent native text',
    (tester) async {
      final h = MirrorHarness(tester);
      await h.mount(source, 100);
      h.holdAppCommands = true;
      final before = h.text.value;
      h.text.value = before.replaced(before.selection, 'APP');
      await tester.pump();
      h.text.value =
          before; // Same public controller mutation used by app undo.
      await tester.pump();
      await h.replace(0, 0, 'X');
      await tester.pump();
      expect(h.text.text, 'X$source');
      await h.releaseAllAppCommands();
      expect(h.native.text, 'X$source');
      final caret = h.native.selection.start;
      await h.replace(caret, caret, 'Y');
      await tester.pump();
      expect(h.text.text, ('X$source').replaceRange(caret, caret, 'Y'));
      expect(h.text.text.contains('APP'), isFalse);
      expect(h.bridge.failures, isEmpty);
      await h.dispose();
    },
  );

  testWidgets('two distant app edits preserve native insertion between them', (
    tester,
  ) async {
    final h = MirrorHarness(tester);
    await h.mount(source, 100);
    h.holdAppCommands = true;
    h.text.value = h.text.value.replaced(h.text.selection, 'APP1');
    await tester.pump();
    h.text.value = h.text.value.replaced(
      const TextRange.collapsed(400),
      'APP2',
    );
    await tester.pump();
    final expected = h.text.text.replaceRange(254, 254, 'N');
    await h.replace(250, 250, 'N');
    await tester.pump();
    expect(h.text.text, expected);
    await h.releaseAllAppCommands();
    expect(h.native.text, expected);
    expect(h.bridge.failures, isEmpty);
    await h.dispose();
  });
}
