import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:re_editor/re_editor.dart';
import 'mirror_harness.dart';

void main() {
  final source = List.generate(400, (i) => 'line $i 中文 abcdefghijk').join('\n');
  void scenario(String name, Future<void> Function(MirrorHarness) body) {
    testWidgets(name, (tester) async {
      final h = MirrorHarness(tester);
      await h.mount(source, 100);
      try {
        await body(h);
      } finally {
        await h.dispose();
      }
    });
  }

  scenario('long editor bypasses the default full-text platform channel', (
    h,
  ) async {
    expect(h.native.text, source);
    expect(
      h.tester.testTextInput.log.where(
        (c) => c.method == 'TextInput.setEditingState',
      ),
      isEmpty,
    );
    final lines = h.tester
        .widget<CodeEditor>(find.byType(CodeEditor))
        .controller!;
    final first = lines.codeLines.first, last = lines.codeLines.last;
    await h.replace(100, 100, '中');
    await h.tester.pump();
    expect(h.text.text, source.replaceRange(100, 100, '中'));
    expect(identical(lines.codeLines.first, first), isTrue);
    expect(identical(lines.codeLines.last, last), isTrue);
    expect(h.bridge.failures, isEmpty);
  });
  scenario('full selection and immediate cut converge after paused delivery', (
    h,
  ) async {
    h.bridge.paused = true;
    await h.send(
      h.native.copyWith(
        selection: TextSelection(baseOffset: 0, extentOffset: source.length),
      ),
      [],
    );
    final copied = h.native.selection.textInside(h.native.text);
    await h.replace(0, source.length, '');
    expect(h.text.text, source);
    expect(copied, source);
    h.bridge.resume();
    await h.tester.pump();
    expect(h.text.text, '');
    expect(h.text.selection, const TextSelection.collapsed(offset: 0));
    expect(h.bridge.failures, isEmpty);
  });
  scenario('uncommitted composing remains marked across full selection', (
    h,
  ) async {
    await h.replace(
      100,
      100,
      'ni',
      composing: const TextRange(start: 100, end: 102),
    );
    await h.send(
      h.native.copyWith(
        selection: TextSelection(
          baseOffset: 0,
          extentOffset: h.native.text.length,
        ),
      ),
      [],
    );
    await h.tester.pump();
    expect(
      h.text.selection,
      TextSelection(baseOffset: 0, extentOffset: source.length + 2),
    );
    expect(
      h.bridge.nativeValue!.composing,
      const TextRange(start: 100, end: 102),
    );
    await h.replace(100, 102, '你');
    await h.tester.pump();
    expect(h.text.text, source.replaceRange(100, 100, '你'));
    expect(h.bridge.failures, isEmpty);
  });
  scenario('queued cross-paragraph insert and delete retain global offsets', (
    h,
  ) async {
    h.bridge.paused = true;
    await h.replace(100, 100, '\n');
    await h.replace(101, 101, '中文');
    await h.replace(102, 103, '');
    h.bridge.resume();
    await h.tester.pump();
    expect(h.text.text, source.replaceRange(100, 100, '\n中'));
    expect(h.text.selection, const TextSelection.collapsed(offset: 102));
    expect(h.bridge.failures, isEmpty);
  });
  scenario('native expanded selection and deletion cross many paragraphs', (
    h,
  ) async {
    await h.send(
      h.native.copyWith(
        selection: const TextSelection(baseOffset: 4000, extentOffset: 20),
      ),
      [],
    );
    await h.tester.pump();
    expect(
      h.text.selection,
      const TextSelection(baseOffset: 4000, extentOffset: 20),
    );
    await h.replace(20, 4000, '');
    await h.tester.pump();
    expect(h.text.text, source.replaceRange(20, 4000, ''));
    expect(h.bridge.failures, isEmpty);
  });
  scenario('metadata-only selection has bounded payload and preserves lines', (
    h,
  ) async {
    final lines = h.tester
        .widget<CodeEditor>(find.byType(CodeEditor))
        .controller!;
    final before = lines.codeLines;
    final message = h.prepare(
      h.native.copyWith(
        selection: TextSelection(baseOffset: 0, extentOffset: source.length),
      ),
      [],
    );
    expect(message.lengthInBytes, lessThan(256));
    await h.dispatch(message);
    await h.tester.pump();
    expect(identical(lines.codeLines, before), isTrue);
    expect(h.changes, 0);
  });
  scenario('duplicate event does not apply text twice', (h) async {
    final message = h.prepare(h.native.replaced(h.native.selection, 'x'), [
      [100, 100, 'x'],
    ]);
    await h.dispatch(message);
    await h.dispatch(message);
    await h.tester.pump();
    expect(h.text.text, source.replaceRange(100, 100, 'x'));
    expect(h.changes, 1);
  });
  scenario('revision gap is detected before mutating text', (h) async {
    h.nativeRevision = 3;
    await h.replace(100, 100, 'x');
    await h.tester.pump();
    expect(h.text.text, source);
    expect(h.bridge.failures.single, contains('Non-contiguous'));
  });
}
