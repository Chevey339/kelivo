import 'package:Kelivo/shared/widgets/long_message_editor.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:re_editor/re_editor.dart';

void main() {
  final source = List.generate(
    1200,
    (index) => '$index 中文 English **text**',
  ).join('\n');

  Future<void> show(
    WidgetTester tester,
    TextEditingController controller, {
    bool accessible = false,
    double scale = 1,
    TextInputAction inputAction = TextInputAction.newline,
    ValueChanged<String>? onSubmitted,
    ContentInsertionConfiguration? insertion,
    bool readOnly = false,
    bool autofocus = false,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MediaQuery(
            data: MediaQueryData(
              size: const Size(800, 600),
              accessibleNavigation: accessible,
              textScaler: TextScaler.linear(scale),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: LongMessageEditor(
                controller: controller,
                textInputAction: inputAction,
                onSubmitted: onSubmitted,
                contentInsertionConfiguration: insertion,
                readOnly: readOnly,
                autofocus: autofocus,
                decoration: const InputDecoration(
                  filled: true,
                  border: OutlineInputBorder(),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('large edits preserve the entire document and global selection', (
    tester,
  ) async {
    final text = TextEditingController(text: source);
    addTearDown(text.dispose);
    await show(tester, text);
    final lines = tester
        .widget<CodeEditor>(find.byType(CodeEditor))
        .controller!;
    expect(lines.text, source);
    lines.selection = const CodeLineSelection.collapsed(index: 500, offset: 4);
    final offset = source.indexOf('500 中文') + 4;
    expect(text.selection.baseOffset, offset);
    lines.replaceSelection('🧑‍💻测试\n第二行');
    expect(text.text, source.replaceRange(offset, offset, '🧑‍💻测试\n第二行'));
    expect(text.selection.baseOffset, offset + '🧑‍💻测试\n第二行'.length);
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('initial focus retains the standard end-of-document caret', (
    tester,
  ) async {
    final text = TextEditingController(text: source);
    addTearDown(text.dispose);
    await show(tester, text, autofocus: true);
    await tester.pump(const Duration(milliseconds: 150));
    expect(text.selection, TextSelection.collapsed(offset: source.length));
    final lines = tester
        .widget<CodeEditor>(find.byType(CodeEditor))
        .controller!;
    expect(lines.selection.extentIndex, lines.codeLines.length - 1);
    expect(lines.selection.extentOffset, lines.codeLines.last.length);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 200));
    expect(tester.takeException(), isNull);
  });

  testWidgets('a focused external replacement retains an end caret', (
    tester,
  ) async {
    final text = TextEditingController(text: source);
    addTearDown(text.dispose);
    await show(tester, text, autofocus: true);
    await tester.pump();
    final replacement = '$source\nnew content';
    text.text = replacement;
    await tester.pump();
    expect(text.text, replacement);
    expect(text.selection, TextSelection.collapsed(offset: replacement.length));
    final lines = tester
        .widget<CodeEditor>(find.byType(CodeEditor))
        .controller!;
    expect(lines.selection.extentIndex, 1200);
    expect(lines.selection.extentOffset, 'new content'.length);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 200));
    expect(tester.takeException(), isNull);
  });

  testWidgets('plain messages delete literal characters without code pairing', (
    tester,
  ) async {
    final text = TextEditingController(text: '    {}🧑‍💻line\n$source');
    addTearDown(text.dispose);
    await show(tester, text);
    final lines = tester
        .widget<CodeEditor>(find.byType(CodeEditor))
        .controller!;
    lines.selection = const CodeLineSelection.collapsed(index: 0, offset: 5);
    lines.deleteBackward();
    expect(text.text, '    }🧑‍💻line\n$source');
    text.text = '    {}🧑‍💻line\n$source';
    lines.selection = const CodeLineSelection.collapsed(index: 0, offset: 4);
    lines.deleteBackward();
    expect(text.text, '   {}🧑‍💻line\n$source');
    text.text = '    {}🧑‍💻line\n$source';
    lines.selection = const CodeLineSelection.collapsed(index: 0, offset: 0);
    lines.deleteForward();
    expect(text.text, '   {}🧑‍💻line\n$source');
    text.text = '    {}🧑‍💻line\n$source';
    lines.selection = const CodeLineSelection.collapsed(index: 0, offset: 4);
    lines.applyNewLine();
    expect(text.text, '    \n{}🧑‍💻line\n$source');
    text.text = '    {}🧑‍💻line\n$source';
    lines.selection = CodeLineSelection.collapsed(
      index: 0,
      offset: 6 + '🧑‍💻'.length,
    );
    lines.deleteBackward();
    expect(text.text, '    {}line\n$source');
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('external replacements update lines and reversed selections', (
    tester,
  ) async {
    final text = TextEditingController(text: source);
    addTearDown(text.dispose);
    await show(tester, text);
    final next = 'first\n$source\nlast';
    text.value = TextEditingValue(
      text: next,
      selection: TextSelection(baseOffset: next.length, extentOffset: 3),
    );
    await tester.pump();
    final lines = tester
        .widget<CodeEditor>(find.byType(CodeEditor))
        .controller!;
    expect(lines.text, next);
    expect(lines.selectedText, next.substring(3));
    expect(lines.selection.baseIndex, 1201);
    expect(lines.selection.extentIndex, 0);
    expect(lines.selection.extentOffset, 3);
  });

  testWidgets('select all and copy include offscreen lines', (tester) async {
    String? clipboardText;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.setData') {
            clipboardText = (call.arguments as Map)['text'] as String;
          }
          if (call.method == 'Clipboard.getData') {
            return {'text': clipboardText};
          }
          return null;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null),
    );
    final text = TextEditingController(text: source);
    addTearDown(text.dispose);
    await show(tester, text);
    final lines = tester
        .widget<CodeEditor>(find.byType(CodeEditor))
        .controller!;
    lines.selectAll();
    expect(
      text.selection,
      TextSelection(baseOffset: 0, extentOffset: source.length),
    );
    await tester.runAsync(() async {
      await lines.copy();
      expect(clipboardText, source);
    });
    lines.replaceSelection('短消息');
    await tester.pump();
    expect(text.text, '短消息');
    expect(find.byType(TextField), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('large text is not truncated and text scale reaches line spans', (
    tester,
  ) async {
    final text = TextEditingController(text: source);
    addTearDown(text.dispose);
    await show(tester, text, scale: 1.75);
    final editor = tester.widget<CodeEditor>(find.byType(CodeEditor));
    final span = editor.controller!.buildTextSpan(
      context: tester.element(find.byType(CodeEditor)),
      index: 0,
      textSpan: TextSpan(text: editor.controller!.codeLines[0].text),
      style: const TextStyle(),
    );
    expect(span.style!.fontSize, 28);
    expect(span.style!.letterSpacing, .5);
    expect(editor.style!.fontSize, 28);
    expect(editor.maxLengthSingleLineRendering, greaterThan(source.length));
  });

  for (final suffix in ['\nمرحبا', '\r\nWindows']) {
    testWidgets('preserves paragraph editing for $suffix', (tester) async {
      final text = TextEditingController(text: '$source$suffix');
      addTearDown(text.dispose);
      await show(tester, text);
      expect(find.byType(TextField), findsOneWidget);
      expect(text.text, '$source$suffix');
    });
  }

  testWidgets('accessible editing uses Flutter text semantics', (tester) async {
    final text = TextEditingController(text: source);
    addTearDown(text.dispose);
    await show(tester, text, accessible: true);
    expect(find.byType(EditableText), findsOneWidget);
    expect(find.byType(CodeEditor), findsNothing);
    expect(text.text, source);
  });

  testWidgets('short messages keep the default selection toolbar', (
    tester,
  ) async {
    final text = TextEditingController(text: 'short message');
    addTearDown(text.dispose);
    await show(tester, text);
    await tester.tap(find.byType(TextField));
    text.selection = const TextSelection(baseOffset: 0, extentOffset: 5);
    await tester.pump();
    tester.state<EditableTextState>(find.byType(EditableText)).showToolbar();
    await tester.pump();
    expect(find.text('Copy'), findsOneWidget);
    expect(find.text('Cut'), findsOneWidget);
  });

  testWidgets(
    'inserted bidi text switches back without changing the document',
    (tester) async {
      final text = TextEditingController(text: source);
      addTearDown(text.dispose);
      await show(tester, text);
      final editor = tester.widget<CodeEditor>(find.byType(CodeEditor));
      editor.focusNode!.requestFocus();
      await tester.pump();
      final lines = editor.controller!;
      lines.selection = const CodeLineSelection.collapsed(
        index: 513,
        offset: 4,
      );
      final offset = source.indexOf('513 中文') + 4;
      lines.replaceSelection('مرحبا\n新行');
      await tester.pump();
      await tester.pump();
      expect(text.text, source.replaceRange(offset, offset, 'مرحبا\n新行'));
      expect(find.byType(TextField), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField)).focusNode!.hasFocus,
        true,
      );
      lines.undo();
      await tester.pump();
      await tester.pump();
      expect(text.text, source);
      expect(find.byType(CodeEditor), findsOneWidget);
      expect(
        tester.widget<CodeEditor>(find.byType(CodeEditor)).focusNode!.hasFocus,
        true,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'native send and content insertion preserve message input contracts',
    (tester) async {
      final text = TextEditingController(text: source);
      addTearDown(text.dispose);
      String? sent;
      KeyboardInsertedContent? inserted;
      await show(
        tester,
        text,
        inputAction: TextInputAction.send,
        onSubmitted: (value) => sent = value,
        insertion: ContentInsertionConfiguration(
          allowedMimeTypes: const ['image/png'],
          onContentInserted: (value) => inserted = value,
        ),
      );
      tester
          .widget<CodeEditor>(find.byType(CodeEditor))
          .focusNode!
          .requestFocus();
      await tester.pump();
      final client = tester.testTextInput.log.lastWhere(
        (call) => call.method == 'TextInput.setClient',
      );
      final args = client.arguments as List;
      expect((args[1] as Map)['inputAction'], 'TextInputAction.send');
      expect((args[1] as Map)['contentCommitMimeTypes'], ['image/png']);
      await tester.testTextInput.receiveAction(TextInputAction.send);
      expect(sent, source);
      await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
        'flutter/textinput',
        const JSONMethodCodec().encodeMethodCall(
          MethodCall('TextInputClient.performAction', [
            args.first,
            'TextInputAction.commitContent',
            {
              'mimeType': 'image/png',
              'uri': 'content://test/image',
              'data': [1, 2, 3],
            },
          ]),
        ),
        (_) {},
      );
      expect(inserted!.mimeType, 'image/png');
      expect(inserted!.uri, 'content://test/image');
      expect(text.text, source);
      await show(tester, text, readOnly: true);
      await tester.pump();
      expect(tester.testTextInput.hasAnyClients, false);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('IME deltas preserve Chinese composition and untouched lines', (
    tester,
  ) async {
    final text = TextEditingController(text: source);
    addTearDown(text.dispose);
    await show(tester, text);
    text.selection = const TextSelection.collapsed(offset: 0);
    final editor = tester.widget<CodeEditor>(find.byType(CodeEditor));
    editor.focusNode!.requestFocus();
    await tester.pump();
    final client = tester.testTextInput.log.lastWhere(
      (call) => call.method == 'TextInput.setClient',
    );
    final id = (client.arguments as List).first;
    final state =
        tester.testTextInput.log
                .lastWhere((call) => call.method == 'TextInput.setEditingState')
                .arguments
            as Map;
    final oldText = state['text'] as String;
    final insertion = state['selectionBase'] as int;
    await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
      'flutter/textinput',
      const JSONMethodCodec().encodeMethodCall(
        MethodCall('TextInputClient.updateEditingStateWithDeltas', [
          id,
          {
            'deltas': [
              {
                'oldText': oldText,
                'deltaText': '你好',
                'deltaStart': insertion,
                'deltaEnd': insertion,
                'selectionBase': insertion + 2,
                'selectionExtent': insertion + 2,
                'selectionAffinity': 'TextAffinity.downstream',
                'selectionIsDirectional': false,
                'composingBase': insertion,
                'composingExtent': insertion + 2,
              },
            ],
          },
        ]),
      ),
      (_) {},
    );
    await tester.pump();
    expect(text.text, '你好$source');
    expect(editor.controller!.isComposing, true);
    expect(text.value.composing, const TextRange(start: 0, end: 2));
    final span = editor.controller!.buildTextSpan(
      context: tester.element(find.byType(CodeEditor)),
      index: 0,
      textSpan: TextSpan(text: editor.controller!.codeLines[0].text),
      style: const TextStyle(),
    );
    expect((span.children![1] as TextSpan).text, '你好');
    expect(
      (span.children![1] as TextSpan).style!.decoration,
      TextDecoration.underline,
    );
    tester.testTextInput.updateEditingValue(
      TextEditingValue(
        text: oldText.replaceRange(insertion, insertion, '你好!'),
        selection: TextSelection.collapsed(offset: insertion + 3),
      ),
    );
    await tester.pump();
    expect(text.text, '你好!$source');
    expect(editor.controller!.isComposing, false);
    expect(
      editor.controller!
          .buildTextSpan(
            context: tester.element(find.byType(CodeEditor)),
            index: 0,
            textSpan: TextSpan(text: editor.controller!.codeLines[0].text),
            style: const TextStyle(),
          )
          .children,
      isNull,
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 200));
    expect(tester.takeException(), isNull);
  });

  testWidgets('IME commit and newline in one batch retain committed text', (
    tester,
  ) async {
    final text = TextEditingController(text: source);
    addTearDown(text.dispose);
    await show(tester, text);
    text.selection = const TextSelection.collapsed(offset: 0);
    final editor = tester.widget<CodeEditor>(find.byType(CodeEditor));
    editor.focusNode!.requestFocus();
    await tester.pump();
    final client = tester.testTextInput.log.lastWhere(
      (call) => call.method == 'TextInput.setClient',
    );
    final id = (client.arguments as List).first;
    Map state() =>
        tester.testTextInput.log
                .lastWhere((call) => call.method == 'TextInput.setEditingState')
                .arguments
            as Map;
    final original = state()['text'] as String;
    final insertion = state()['selectionBase'] as int;
    final pinyin = original.replaceRange(insertion, insertion, 'ni');
    tester.testTextInput.updateEditingValue(
      TextEditingValue(
        text: pinyin,
        selection: TextSelection.collapsed(offset: insertion + 2),
        composing: TextRange(start: insertion, end: insertion + 2),
      ),
    );
    await tester.pump();
    final oldText = pinyin;
    final committed = oldText.replaceRange(insertion, insertion + 2, '你好');
    await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
      'flutter/textinput',
      const JSONMethodCodec().encodeMethodCall(
        MethodCall('TextInputClient.updateEditingStateWithDeltas', [
          id,
          {
            'deltas': [
              {
                'oldText': oldText,
                'deltaText': '你好',
                'deltaStart': insertion,
                'deltaEnd': insertion + 2,
                'selectionBase': insertion + 2,
                'selectionExtent': insertion + 2,
                'selectionAffinity': 'TextAffinity.downstream',
                'selectionIsDirectional': false,
                'composingBase': -1,
                'composingExtent': -1,
              },
              {
                'oldText': committed,
                'deltaText': '\n',
                'deltaStart': insertion + 2,
                'deltaEnd': insertion + 2,
                'selectionBase': insertion + 3,
                'selectionExtent': insertion + 3,
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
    await tester.pump();
    expect(text.text, '你好\n$source');
    expect(text.selection, const TextSelection.collapsed(offset: 3));
    expect(editor.controller!.isComposing, false);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 200));
    expect(tester.takeException(), isNull);
  });

  testWidgets('a clipboard completion cannot edit a closed message', (
    tester,
  ) async {
    final clipboard = Completer<Map<String, Object>>();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.getData') return clipboard.future;
          return null;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null),
    );
    final text = TextEditingController(text: source);
    addTearDown(text.dispose);
    await show(tester, text);
    tester.widget<CodeEditor>(find.byType(CodeEditor)).controller!.paste();
    await tester.pump();
    await tester.pumpWidget(const SizedBox.shrink());
    clipboard.complete({'text': 'late paste'});
    await tester.pump(const Duration(milliseconds: 200));
    expect(text.text, source);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'complete input states and submit preserve non-Android contracts',
    (tester) async {
      final text = TextEditingController(text: source);
      addTearDown(text.dispose);
      String? submitted;
      await show(
        tester,
        text,
        inputAction: TextInputAction.send,
        onSubmitted: (value) => submitted = value,
      );
      text.selection = const TextSelection.collapsed(offset: 0);
      final editor = tester.widget<CodeEditor>(find.byType(CodeEditor));
      editor.focusNode!.requestFocus();
      await tester.pump();
      final state =
          tester.testTextInput.log
                  .lastWhere(
                    (call) => call.method == 'TextInput.setEditingState',
                  )
                  .arguments
              as Map;
      final oldText = state['text'] as String;
      final insertion = state['selectionBase'] as int;
      tester.testTextInput.updateEditingValue(
        TextEditingValue(
          text: oldText.replaceRange(insertion, insertion, '跨平台'),
          selection: TextSelection.collapsed(offset: insertion + 3),
        ),
      );
      await tester.pump();
      expect(text.text, '跨平台$source');
      expect(text.selection, const TextSelection.collapsed(offset: 3));
      await tester.testTextInput.receiveAction(TextInputAction.send);
      expect(submitted, text.text);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant({
      TargetPlatform.iOS,
      TargetPlatform.macOS,
      TargetPlatform.windows,
      TargetPlatform.linux,
    }),
  );

  testWidgets('pasting across the size threshold retains keyboard focus', (
    tester,
  ) async {
    final text = TextEditingController(text: 'short');
    addTearDown(text.dispose);
    await show(tester, text);
    await tester.tap(find.byType(TextField));
    await tester.pump();
    text.value = TextEditingValue(
      text: source,
      selection: TextSelection.collapsed(offset: source.length),
    );
    await tester.pump();
    await tester.pump();
    final editor = tester.widget<CodeEditor>(find.byType(CodeEditor));
    expect(editor.focusNode!.hasFocus, true);
    expect(tester.testTextInput.hasAnyClients, true);
    final inputClient = tester.testTextInput.log.lastWhere(
      (call) => call.method == 'TextInput.setClient',
    );
    expect(
      ((inputClient.arguments as List)[1] as Map)['enableDeltaModel'],
      true,
    );
    editor.controller!.applyNewLine();
    expect(text.text, '$source\n');
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 200));
    expect(tester.takeException(), isNull);
  });
}
