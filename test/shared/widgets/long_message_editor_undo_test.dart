import 'package:Kelivo/shared/widgets/long_message_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:re_editor/re_editor.dart';

void main() {
  final source = List.generate(150, (i) => '$i long message 中文').join('\n');

  Future<void> show(
    WidgetTester tester,
    TextEditingController text, {
    bool readOnly = false,
    ValueChanged<String>? onChanged,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LongMessageEditor(
            controller: text,
            autofocus: true,
            readOnly: readOnly,
            onChanged: onChanged,
            decoration: const InputDecoration(),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
  }

  Future<void> nativeUndo(WidgetTester tester, String direction) async {
    await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
      'flutter/undomanager',
      const JSONMethodCodec().encodeMethodCall(
        MethodCall('UndoManagerClient.handleUndo', [direction]),
      ),
      (_) {},
    );
    await tester.pump();
    await tester.pump();
  }

  for (final replacement in ['', 'مرحبا']) {
    testWidgets('iOS native undo survives renderer change to "$replacement"', (
      tester,
    ) async {
      final text = TextEditingController(text: source);
      addTearDown(text.dispose);
      final changes = <String>[];
      await show(tester, text, onChanged: changes.add);
      final lines = tester
          .widget<CodeEditor>(find.byType(CodeEditor))
          .controller!;
      if (replacement.isEmpty) lines.selectAll();
      lines.replaceSelection(replacement);
      final changed = text.text;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.byType(TextField), findsOneWidget);
      await nativeUndo(tester, 'undo');
      expect(text.text, source);
      expect(find.byType(CodeEditor), findsOneWidget);
      await nativeUndo(tester, 'redo');
      expect(text.text, changed);
      expect(find.byType(TextField), findsOneWidget);
      expect(changes, [changed, source, changed]);
      await tester.pumpWidget(const SizedBox.shrink());
      expect(tester.takeException(), isNull);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
  }

  testWidgets('iOS paste undo and redo keep the complete short draft', (
    tester,
  ) async {
    final text = TextEditingController(text: 'short');
    addTearDown(text.dispose);
    await show(tester, text);
    tester.testTextInput.updateEditingValue(
      TextEditingValue(
        text: source,
        selection: TextSelection.collapsed(offset: source.length),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byType(CodeEditor), findsOneWidget);
    await nativeUndo(tester, 'undo');
    expect(text.text, 'short');
    await nativeUndo(tester, 'redo');
    expect(text.text, source);
    await tester.pumpWidget(const SizedBox.shrink());
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets(
    'read-only blocks shared undo and retains history when unlocked',
    (tester) async {
      final text = TextEditingController(text: source);
      addTearDown(text.dispose);
      await show(tester, text);
      tester
          .widget<CodeEditor>(find.byType(CodeEditor))
          .controller!
          .replaceSelection('edit');
      final edited = text.text;
      await tester.pump(const Duration(milliseconds: 600));
      await show(tester, text, readOnly: true);
      await nativeUndo(tester, 'undo');
      expect(text.text, edited);
      await show(tester, text);
      await nativeUndo(tester, 'undo');
      expect(text.text, source);
      await tester.pumpWidget(const SizedBox.shrink());
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets('replacing the document controller resets shared undo history', (
    tester,
  ) async {
    final first = TextEditingController(text: source);
    final second = TextEditingController(text: 'new document');
    addTearDown(first.dispose);
    addTearDown(second.dispose);
    await show(tester, first);
    tester
        .widget<CodeEditor>(find.byType(CodeEditor))
        .controller!
        .replaceSelection('edit');
    await tester.pump(const Duration(milliseconds: 600));
    await show(tester, second);
    await nativeUndo(tester, 'undo');
    expect(second.text, 'new document');
    expect(first.text, '${source}edit');
    await tester.pumpWidget(const SizedBox.shrink());
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
}
