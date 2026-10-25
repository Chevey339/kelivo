import 'package:Kelivo/shared/widgets/long_message_editor.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:re_editor/re_editor.dart';

void main() {
  // Run each desktop platform in a separate test process so the dependency's
  // platform constants cannot be initialized by another platform's test.
  const platform = String.fromEnvironment('EDITOR_TEST_PLATFORM');
  final target = platform == 'macos'
      ? TargetPlatform.macOS
      : platform == 'linux'
      ? TargetPlatform.linux
      : TargetPlatform.windows;
  final source = List.generate(150, (i) => '$i 中文 long message').join('\n');

  void testDesktop(String description, WidgetTesterCallback callback) {
    testWidgets(
      description,
      callback,
      variant: TargetPlatformVariant.only(target),
    );
  }

  Future<void> show(WidgetTester tester, TextEditingController text) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: LongMessageEditor(
              controller: text,
              autofocus: true,
              decoration: const InputDecoration(border: OutlineInputBorder()),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
  }

  Future<void> shortcut(
    WidgetTester tester,
    LogicalKeyboardKey key, {
    bool shift = false,
  }) async {
    final modifier = target == TargetPlatform.macOS
        ? LogicalKeyboardKey.metaLeft
        : LogicalKeyboardKey.controlLeft;
    await tester.sendKeyDownEvent(modifier);
    if (shift) await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(key);
    if (shift) await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyUpEvent(modifier);
    await tester.pump();
    await tester.pump();
  }

  for (final initial in ['abc\ndef', 'abc\ndef\n$source']) {
    testDesktop(
      'collapsed cut/copy preserve text and clipboard (${initial.length} characters)',
      (tester) async {
        String? clipboard = 'previous clipboard';
        var writes = 0;
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          (call) async {
            if (call.method == 'Clipboard.setData') {
              clipboard = (call.arguments as Map)['text'] as String;
              writes++;
            }
            return null;
          },
        );
        addTearDown(
          () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            SystemChannels.platform,
            null,
          ),
        );
        final text = TextEditingController(text: initial);
        addTearDown(text.dispose);
        await show(tester, text);
        text.selection = const TextSelection.collapsed(offset: 1);
        await tester.pump();
        for (final key in [LogicalKeyboardKey.keyX, LogicalKeyboardKey.keyC]) {
          await shortcut(tester, key);
          expect(text.text, initial);
          expect(text.selection, const TextSelection.collapsed(offset: 1));
          expect(clipboard, 'previous clipboard');
          expect(writes, 0);
        }
        text.selection = const TextSelection(baseOffset: 1, extentOffset: 5);
        await tester.pump();
        await shortcut(tester, LogicalKeyboardKey.keyX);
        expect(text.text, initial.replaceRange(1, 5, ''));
        expect(clipboard, 'bc\nd');
        expect(writes, 1);
        await tester.pump(const Duration(milliseconds: 600));
        await shortcut(tester, LogicalKeyboardKey.keyZ);
        expect(text.text, initial);
        await tester.pumpWidget(const SizedBox.shrink());
        expect(tester.takeException(), isNull);
      },
    );
  }

  testDesktop('desktop secondary click opens a working selection menu', (
    tester,
  ) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    final text = TextEditingController(text: source);
    addTearDown(text.dispose);
    await show(tester, text);
    await shortcut(tester, LogicalKeyboardKey.keyA);
    final gesture = await tester.startGesture(
      tester.getTopLeft(find.byType(CodeEditor)) + const Offset(40, 12),
      kind: PointerDeviceKind.mouse,
      buttons: kSecondaryMouseButton,
    );
    await gesture.up();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Copy'), findsOneWidget);
    await tester.tap(find.text('Copy'));
    await tester.pump();
    expect(copied, source);
    expect(find.text('Copy'), findsNothing);
    final again = await tester.startGesture(
      tester.getTopLeft(find.byType(CodeEditor)) + const Offset(40, 12),
      kind: PointerDeviceKind.mouse,
      buttons: kSecondaryMouseButton,
    );
    await again.up();
    await tester.pumpAndSettle();
    expect(find.text('Copy'), findsOneWidget);
    text.text = 'short';
    await tester.pump();
    expect(find.text('Copy'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testDesktop('delete across the threshold can undo and redo by keyboard', (
    tester,
  ) async {
    final text = TextEditingController(text: source);
    addTearDown(text.dispose);
    await show(tester, text);
    await shortcut(tester, LogicalKeyboardKey.keyA);
    await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
    await tester.pump();
    await tester.pump();
    expect(text.text, isEmpty);
    expect(find.byType(TextField), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 600));
    await shortcut(tester, LogicalKeyboardKey.keyZ);
    expect(text.text, source);
    expect(find.byType(CodeEditor), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 600));
    await shortcut(tester, LogicalKeyboardKey.keyZ, shift: true);
    expect(text.text, isEmpty);
    expect(find.byType(TextField), findsOneWidget);
  });

  testDesktop('paragraph layouts stay bounded while editing and scrolling', (
    tester,
  ) async {
    final text = TextEditingController(text: source);
    addTearDown(text.dispose);
    await show(tester, text);
    final editor = tester.widget<CodeEditor>(find.byType(CodeEditor));
    final lines = editor.controller!;
    lines.selection = const CodeLineSelection.collapsed(index: 0, offset: 0);
    editor.scrollController!.verticalScroller.jumpTo(0);
    await tester.pump();

    Map<String, int> cacheCounts() {
      final field = find.descendant(
        of: find.byType(CodeEditor),
        matching: find.byWidgetPredicate(
          (widget) => widget.runtimeType.toString() == '_CodeField',
        ),
      );
      final properties = tester
          .renderObject(field)
          .toDiagnosticsNode()
          .getProperties();
      return {
        for (final property in properties)
          if (property.name == 'cachedParagraphs' ||
              property.name == 'visibleParagraphs')
            property.name!: property.value as int,
      };
    }

    final before = cacheCounts();
    expect(before['cachedParagraphs'], greaterThan(0));
    for (var i = 0; i < 200; i++) {
      lines.replaceSelection('x');
      await tester.pump();
    }
    final after = cacheCounts();
    debugPrint('Paragraph cache: before=$before after200=$after');
    expect(
      after['cachedParagraphs'],
      lessThanOrEqualTo(after['visibleParagraphs']! + 2),
    );
    expect(text.text, '${'x' * 200}$source');
    await tester.drag(find.byType(CodeEditor), const Offset(0, -450));
    await tester.pumpAndSettle();
    final scrolled = cacheCounts();
    expect(
      scrolled['cachedParagraphs'],
      lessThanOrEqualTo(scrolled['visibleParagraphs']! + 2),
    );
    editor.scrollController!.verticalScroller.jumpTo(0);
    await tester.pump();
    expect(text.text, '${'x' * 200}$source');
    expect(tester.takeException(), isNull);
  });

  testDesktop('paste across the threshold preserves earlier undo history', (
    tester,
  ) async {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async =>
          call.method == 'Clipboard.getData' ? {'text': source} : null,
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    final text = TextEditingController(text: 'short');
    addTearDown(text.dispose);
    await show(tester, text);
    tester.testTextInput.updateEditingValue(
      const TextEditingValue(
        text: 'short edit',
        selection: TextSelection.collapsed(offset: 10),
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));
    await shortcut(tester, LogicalKeyboardKey.keyA);
    await shortcut(tester, LogicalKeyboardKey.keyV);
    expect(text.text, source);
    expect(find.byType(CodeEditor), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 600));
    await shortcut(tester, LogicalKeyboardKey.keyZ);
    expect(text.text, 'short edit');
    await shortcut(tester, LogicalKeyboardKey.keyZ);
    expect(text.text, 'short');
    await shortcut(tester, LogicalKeyboardKey.keyZ, shift: true);
    expect(text.text, 'short edit');
    await shortcut(tester, LogicalKeyboardKey.keyZ, shift: true);
    expect(text.text, source);
  });

  for (final reversed in [false, true]) {
    for (final deltas in [false, true]) {
      testDesktop('cross-line IME newline reversed=$reversed deltas=$deltas', (
        tester,
      ) async {
        final original = 'abc\ndef\nghi\n$source';
        final text = TextEditingController(text: original);
        addTearDown(text.dispose);
        await show(tester, text);
        text.selection = TextSelection(
          baseOffset: reversed ? 6 : 1,
          extentOffset: reversed ? 1 : 6,
        );
        await tester.pump();
        final state = TextEditingValue.fromJSON(
          tester.testTextInput.log
                  .lastWhere(
                    (call) => call.method == 'TextInput.setEditingState',
                  )
                  .arguments
              as Map<String, dynamic>,
        );
        final next = state
            .replaced(state.selection, '你\n好')
            .copyWith(
              selection: TextSelection.collapsed(
                offset: state.selection.start + 3,
              ),
            );
        if (deltas) {
          final client =
              (tester.testTextInput.log
                          .lastWhere(
                            (call) => call.method == 'TextInput.setClient',
                          )
                          .arguments
                      as List)
                  .first;
          await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
            'flutter/textinput',
            const JSONMethodCodec().encodeMethodCall(
              MethodCall('TextInputClient.updateEditingStateWithDeltas', [
                client,
                {
                  'deltas': [
                    {
                      'oldText': state.text,
                      'deltaText': '你\n好',
                      'deltaStart': state.selection.start,
                      'deltaEnd': state.selection.end,
                      'selectionBase': next.selection.baseOffset,
                      'selectionExtent': next.selection.extentOffset,
                      'selectionAffinity': 'TextAffinity.downstream',
                      'selectionIsDirectional': false,
                      'composingBase': -1,
                      'composingExtent': -1,
                    },
                  ],
                },
              ]),
            ),
            (_) {},
          );
        } else {
          tester.testTextInput.updateEditingValue(next);
        }
        await tester.pump();
        expect(text.text, original.replaceRange(1, 6, '你\n好'));
        expect(text.selection, const TextSelection.collapsed(offset: 4));
        expect(tester.takeException(), isNull);
      });
    }
  }
}
