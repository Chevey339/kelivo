import 'package:Kelivo/shared/widgets/long_message_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:re_editor/re_editor.dart';

void main() {
  // Separate invocations exercise the dependency's platform-specific IME
  // prefix. Its platform constants are initialized once per test isolate.
  const platform = String.fromEnvironment('EDITOR_INPUT_TEST_PLATFORM');
  final target = switch (platform) {
    'ios' => TargetPlatform.iOS,
    'macos' => TargetPlatform.macOS,
    'windows' => TargetPlatform.windows,
    'linux' => TargetPlatform.linux,
    _ => TargetPlatform.android,
  };
  final source = 'abc\n${'long message\n' * 222}abcdefghijk';
  final prefix =
      target == TargetPlatform.android || target == TargetPlatform.iOS ? 1 : 0;

  void testInput(String description, WidgetTesterCallback callback) {
    testWidgets(
      description,
      callback,
      variant: TargetPlatformVariant.only(target),
    );
  }

  Future<CodeLineEditingController> show(
    WidgetTester tester,
    TextEditingController text,
    List<String> changes,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LongMessageEditor(
            controller: text,
            autofocus: true,
            onChanged: changes.add,
            decoration: const InputDecoration(),
          ),
        ),
      ),
    );
    await tester.pump();
    return tester.widget<CodeEditor>(find.byType(CodeEditor)).controller!;
  }

  TextEditingValue remote(WidgetTester tester) => TextEditingValue.fromJSON(
    Map<String, dynamic>.from(
      tester.testTextInput.log
              .lastWhere((call) => call.method == 'TextInput.setEditingState')
              .arguments
          as Map,
    ),
  );

  Future<void> send(
    WidgetTester tester,
    TextEditingValue previous,
    TextEditingValue next, {
    required bool deltas,
    TextRange? replaced,
    String replacement = '',
    List<Map<String, dynamic>> additionalDeltas = const [],
  }) async {
    if (!deltas) {
      tester.testTextInput.updateEditingValue(next);
    } else {
      final id =
          (tester.testTextInput.log
                      .lastWhere((call) => call.method == 'TextInput.setClient')
                      .arguments
                  as List)
              .first;
      await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
        'flutter/textinput',
        const JSONMethodCodec().encodeMethodCall(
          MethodCall('TextInputClient.updateEditingStateWithDeltas', [
            id,
            {
              'deltas': [
                {
                  'oldText': previous.text,
                  'deltaText': replacement,
                  'deltaStart': replaced?.start ?? -1,
                  'deltaEnd': replaced?.end ?? -1,
                  ...next.toJSON(),
                },
                ...additionalDeltas,
              ],
            },
          ]),
        ),
        (_) {},
      );
    }
    await tester.pump();
  }

  for (final deltas in [false, true]) {
    testInput(
      'composition in the second selected line survives native buffer rebasing: deltas=$deltas',
      (tester) async {
        final original = 'HEADER\nabc\ndef\n$source';
        final text = TextEditingController(text: original);
        addTearDown(text.dispose);
        final changes = <String>[];
        final lines = await show(tester, text, changes);
        text.selection = const TextSelection(baseOffset: 8, extentOffset: 13);
        await tester.pump();
        final originalLines = lines.codeLines;
        final before = remote(tester);
        final composing = before.copyWith(
          selection: TextSelection.collapsed(offset: prefix + 6),
          composing: TextRange(start: prefix + 4, end: prefix + 6),
        );
        await send(tester, before, composing, deltas: deltas);
        expect(text.text, original);
        expect(identical(lines.codeLines, originalLines), isTrue);
        expect(text.selection, const TextSelection.collapsed(offset: 13));
        expect(text.value.composing, const TextRange(start: 11, end: 13));
        expect(lines.composing, const TextRange(start: 0, end: 2));
        expect(changes, isEmpty);
        final rebased = remote(tester);
        expect(rebased.text.substring(prefix), 'def');
        expect(rebased.composing, TextRange(start: prefix, end: prefix + 2));
        final committed = rebased
            .replaced(rebased.composing, '你好')
            .copyWith(
              selection: TextSelection.collapsed(offset: prefix + 2),
              composing: TextRange.empty,
            );
        await send(
          tester,
          rebased,
          committed,
          deltas: deltas,
          replaced: rebased.composing,
          replacement: '你好',
        );
        expect(text.text, original.replaceRange(11, 13, '你好'));
        expect(text.value.composing, TextRange.empty);
        expect(changes, [text.text]);
        await tester.pumpWidget(const SizedBox.shrink());
        expect(tester.takeException(), isNull);
      },
    );

    testInput(
      'collapsing at the first-line end and submitting that line are distinct: deltas=$deltas',
      (tester) async {
        final text = TextEditingController(text: source);
        addTearDown(text.dispose);
        final changes = <String>[];
        final lines = await show(tester, text, changes);
        lines.selectAll();
        await tester.pump();
        final selected = remote(tester);
        await send(
          tester,
          selected,
          selected.copyWith(
            selection: TextSelection.collapsed(offset: prefix + 3),
          ),
          deltas: deltas,
        );
        expect(text.text, source);
        expect(text.selection, const TextSelection.collapsed(offset: 3));
        expect(changes, isEmpty);

        lines.selectAll();
        await tester.pump();
        final before = remote(tester);
        final next = before
            .replaced(before.selection, 'abc')
            .copyWith(selection: TextSelection.collapsed(offset: prefix + 3));
        await send(
          tester,
          before,
          next,
          deltas: deltas,
          replaced: before.selection,
          replacement: 'abc',
        );
        expect(text.text, 'abc');
        expect(text.selection, const TextSelection.collapsed(offset: 3));
        expect(changes, ['abc']);
        await tester.pumpWidget(const SizedBox.shrink());
        expect(tester.takeException(), isNull);
      },
    );

    for (final reversed in [false, true]) {
      for (final partial in [false, true]) {
        testInput(
          'base-line text replaces a cross-line selection and can undo: deltas=$deltas reversed=$reversed partial=$partial',
          (tester) async {
            final original = partial
                ? 'HEADER\nabc\ndef\nKEEP\n$source'
                : source;
            final start = partial ? 'HEADER\na'.length : 0;
            final end = partial ? 'HEADER\nabc\nde'.length : original.length;
            final replacement = partial
                ? (reversed ? 'de' : 'bc')
                : (reversed ? 'abcdefghijk' : 'abc');
            final text = TextEditingController(text: original);
            addTearDown(text.dispose);
            final changes = <String>[];
            await show(tester, text, changes);
            await tester.pump(const Duration(milliseconds: 600));
            text.selection = TextSelection(
              baseOffset: reversed ? end : start,
              extentOffset: reversed ? start : end,
            );
            await tester.pump();
            final before = remote(tester);
            expect(
              before.selection.textInside(before.text),
              original.substring(start, end),
            );
            final next = before
                .replaced(before.selection, replacement)
                .copyWith(
                  selection: TextSelection.collapsed(
                    offset: before.selection.start + replacement.length,
                  ),
                );
            await send(
              tester,
              before,
              next,
              deltas: deltas,
              replaced: before.selection,
              replacement: replacement,
            );
            final expected = original.replaceRange(start, end, replacement);
            expect(text.text, expected);
            expect(
              text.selection,
              TextSelection.collapsed(offset: start + replacement.length),
            );
            expect(changes, [expected]);
            await tester.pump(const Duration(milliseconds: 600));
            final state = tester.state<LongMessageEditorState>(
              find.byType(LongMessageEditor),
            );
            state.undo();
            await tester.pump();
            await tester.pump();
            expect(text.text, original);
            state.redo();
            await tester.pump();
            await tester.pump();
            expect(text.text, expected);
            await tester.pumpWidget(const SizedBox.shrink());
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
    if (target == TargetPlatform.android || target == TargetPlatform.iOS) {
      testInput(
        'a real native backspace at the line start still joins lines: deltas=$deltas',
        (tester) async {
          final text = TextEditingController(text: source);
          addTearDown(text.dispose);
          final changes = <String>[];
          final lines = await show(tester, text, changes);
          text.selection = const TextSelection.collapsed(offset: 4);
          await tester.pump();
          final before = remote(tester);
          expect(before.text.length - lines.baseLine.text.length, 1);
          final next = before
              .replaced(const TextRange(start: 0, end: 1), '')
              .copyWith(selection: const TextSelection.collapsed(offset: 0));
          await send(
            tester,
            before,
            next,
            deltas: deltas,
            replaced: const TextRange(start: 0, end: 1),
          );
          expect(text.text, source.replaceRange(3, 4, ''));
          expect(text.selection, const TextSelection.collapsed(offset: 3));
          expect(changes, [text.text]);
          await tester.pumpWidget(const SizedBox.shrink());
          expect(tester.takeException(), isNull);
        },
      );
    }
    for (final reversed in [false, true]) {
      testInput(
        'selection-only collapse preserves 2901 characters: deltas=$deltas reversed=$reversed',
        (tester) async {
          final text = TextEditingController(text: source);
          addTearDown(text.dispose);
          final changes = <String>[];
          final lines = await show(tester, text, changes);
          expect(source.length, 2901);
          text.selection = TextSelection(
            baseOffset: reversed ? source.length : 0,
            extentOffset: reversed ? 0 : source.length,
          );
          await tester.pump();
          final originalLines = lines.codeLines;
          final before = remote(tester);
          expect(before.text.substring(prefix), source);
          final offset = reversed ? source.lastIndexOf('\n') + 2 : 1;
          final collapsed = before.copyWith(
            selection: TextSelection.collapsed(offset: prefix + offset),
          );
          await send(tester, before, collapsed, deltas: deltas);
          expect(text.text, source);
          expect(identical(lines.codeLines, originalLines), isTrue);
          expect(text.selection, TextSelection.collapsed(offset: offset));
          expect(changes, isEmpty);

          // The next real edit must use the new caret, preserving every other line.
          // The framework rebases the acknowledged buffer to the caret line.
          final caretState = remote(tester);
          final next = caretState.replaced(caretState.selection, '!');
          await send(
            tester,
            caretState,
            next,
            deltas: deltas,
            replaced: caretState.selection,
            replacement: '!',
          );
          expect(text.text, source.replaceRange(offset, offset, '!'));
          expect(changes, [text.text]);
          await tester.pumpWidget(const SizedBox.shrink());
          expect(tester.takeException(), isNull);
        },
      );
    }

    testInput(
      'moving to native offset zero cannot delete a line: deltas=$deltas',
      (tester) async {
        final text = TextEditingController(text: source);
        addTearDown(text.dispose);
        final changes = <String>[];
        final lines = await show(tester, text, changes);
        text.selection = const TextSelection.collapsed(offset: 6);
        await tester.pump();
        final before = remote(tester);
        final originalLines = lines.codeLines;
        await send(
          tester,
          before,
          before.copyWith(selection: const TextSelection.collapsed(offset: 0)),
          deltas: deltas,
        );
        expect(text.text, source);
        expect(text.selection, const TextSelection.collapsed(offset: 4));
        expect(identical(lines.codeLines, originalLines), isTrue);
        expect(changes, isEmpty);
        await tester.pumpWidget(const SizedBox.shrink());
        expect(tester.takeException(), isNull);
      },
    );

    testInput(
      'composing-only updates retain text and selection: deltas=$deltas',
      (tester) async {
        final text = TextEditingController(text: source);
        addTearDown(text.dispose);
        final changes = <String>[];
        final lines = await show(tester, text, changes);
        text.selection = const TextSelection.collapsed(offset: 6);
        await tester.pump();
        final originalLines = lines.codeLines;
        final before = remote(tester);
        final composing = before.copyWith(
          composing: TextRange(start: prefix, end: prefix + 2),
        );
        await send(tester, before, composing, deltas: deltas);
        expect(text.value.composing, const TextRange(start: 4, end: 6));
        await send(
          tester,
          composing,
          composing.copyWith(composing: TextRange.empty),
          deltas: deltas,
        );
        expect(text.value.composing, TextRange.empty);
        expect(text.text, source);
        expect(text.selection, const TextSelection.collapsed(offset: 6));
        expect(identical(lines.codeLines, originalLines), isTrue);
        expect(changes, isEmpty);
        await tester.pumpWidget(const SizedBox.shrink());
        expect(tester.takeException(), isNull);
      },
    );

    testInput(
      'an unchanged projected selection retains the whole-document range: deltas=$deltas',
      (tester) async {
        final text = TextEditingController(text: source);
        addTearDown(text.dispose);
        final changes = <String>[];
        final lines = await show(tester, text, changes);
        lines.selectAll();
        await tester.pump();
        final before = remote(tester);
        // An empty composing range with a valid caret is also a non-text update.
        await send(
          tester,
          before,
          before.copyWith(composing: TextRange.collapsed(prefix)),
          deltas: deltas,
        );
        expect(text.text, source);
        expect(
          text.selection,
          TextSelection(baseOffset: 0, extentOffset: source.length),
        );
        expect(changes, isEmpty);
        await tester.pumpWidget(const SizedBox.shrink());
        expect(tester.takeException(), isNull);
      },
    );
  }

  testInput(
    'native buffers stay scoped to the caret or selected lines in a million-character document',
    (tester) async {
      final document = List.generate(
        45000,
        (i) => '行 $i abcdefghijklmnop',
      ).join('\n');
      expect(document.length, greaterThan(1000000));
      final first = document.indexOf('行 20000 ');
      final second = document.indexOf('\n', first) + 1;
      final end = document.indexOf('\n', second);
      final text = TextEditingController(text: document)
        ..selection = TextSelection.collapsed(offset: first + 3);
      addTearDown(text.dispose);
      final changes = <String>[];
      final lines = await show(tester, text, changes);
      final caretState = remote(tester);
      expect(
        caretState.text.substring(prefix),
        document.substring(first, second - 1),
      );
      text.selection = TextSelection(
        baseOffset: first + 3,
        extentOffset: second + 4,
      );
      await tester.pump();
      final selected = remote(tester);
      expect(selected.text.substring(prefix), document.substring(first, end));
      expect(
        selected.selection.textInside(selected.text),
        document.substring(first + 3, second + 4),
      );
      final originalLines = lines.codeLines;
      await send(
        tester,
        selected,
        selected.copyWith(
          selection: TextSelection.collapsed(
            offset: prefix + second - first + 2,
          ),
        ),
        deltas: true,
      );
      expect(text.text, document);
      expect(identical(lines.codeLines, originalLines), isTrue);
      expect(text.selection, TextSelection.collapsed(offset: second + 2));
      expect(
        remote(tester).text.substring(prefix),
        document.substring(second, end),
      );
      lines.selectAll();
      await tester.pump();
      expect(remote(tester).text.substring(prefix), document);
      debugPrint(
        'Native buffer chars: caret=${caretState.text.length}, twoLines=${selected.text.length}, selectAll=${remote(tester).text.length}, document=${document.length}',
      );
      expect(changes, isEmpty);
      await tester.pumpWidget(const SizedBox.shrink());
      expect(tester.takeException(), isNull);
    },
  );

  testInput(
    'an IME commit matching the first line replaces the whole selection',
    (tester) async {
      final text = TextEditingController(text: source);
      addTearDown(text.dispose);
      final changes = <String>[];
      final lines = await show(tester, text, changes);
      lines.selectAll();
      await tester.pump();
      final before = remote(tester);
      final next = before
          .replaced(before.selection, 'abc')
          .copyWith(
            selection: TextSelection.collapsed(
              offset: before.selection.start + 3,
            ),
          );
      await send(
        tester,
        before,
        next,
        deltas: true,
        replaced: before.selection,
        replacement: 'abc',
      );
      expect(text.text, 'abc');
      expect(text.selection, const TextSelection.collapsed(offset: 3));
      expect(changes, ['abc']);
      await tester.pumpWidget(const SizedBox.shrink());
      expect(tester.takeException(), isNull);
    },
  );

  testInput(
    'a batch containing a replacement and a non-text update still edits the document',
    (tester) async {
      final text = TextEditingController(text: source);
      addTearDown(text.dispose);
      final changes = <String>[];
      final lines = await show(tester, text, changes);
      lines.selectAll();
      await tester.pump();
      final before = remote(tester);
      final next = before
          .replaced(before.selection, 'hello')
          .copyWith(selection: TextSelection.collapsed(offset: prefix + 5));
      final afterSelection = next.copyWith(
        selection: TextSelection.collapsed(offset: prefix + 2),
      );
      await send(
        tester,
        before,
        next,
        deltas: true,
        replaced: before.selection,
        replacement: 'hello',
        additionalDeltas: [
          {
            'oldText': next.text,
            'deltaStart': -1,
            'deltaEnd': -1,
            'deltaText': '',
            ...afterSelection.toJSON(),
          },
        ],
      );
      expect(text.text, 'hello');
      expect(text.selection, const TextSelection.collapsed(offset: 2));
      expect(changes, ['hello']);
      await tester.pumpWidget(const SizedBox.shrink());
      expect(tester.takeException(), isNull);
    },
  );
}
