import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:Kelivo/shared/widgets/long_message_editor.dart';
import 'controlled_native_message_input.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:re_editor/re_editor.dart';
import 'mirror_harness.dart';

void main() {
  testWidgets(
    'cut to empty retains the native session for immediately following input',
    (tester) async {
      final h = MirrorHarness(tester);
      await h.mount('original text\n' * 400, 100);
      final session = h.bridge.session;
      await h.replace(0, h.native.text.length, '');
      await tester.pump(Duration.zero);
      expect(find.byType(CodeEditor), findsOneWidget);
      expect(h.bridge.session, session);
      expect(h.bridge.client, isNotNull);
      await h.replace(0, 0, 'ni', composing: const TextRange(start: 0, end: 2));
      await tester.pump(Duration.zero);
      await h.replace(0, 2, '你');
      await tester.pump(Duration.zero);
      expect(h.text.text, '你');
      expect(h.text.selection, const TextSelection.collapsed(offset: 1));
      expect(h.bridge.failures, isEmpty);
      await h.dispose();
    },
  );
  testWidgets(
    'short to long focus transfer shows after the default connection hide',
    (tester) async {
      final bridge = MirrorInputControl();
      final text = TextEditingController(text: 'short');
      final calls = <String>[];
      final messenger = tester.binding.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(SystemChannels.textInput, (
        call,
      ) async {
        calls.add(call.method);
        return null;
      });
      messenger.setMockMethodCallHandler(bridge.channel, (call) async {
        calls.add('mirror.${call.method}');
        return null;
      });
      addTearDown(() {
        messenger.setMockMethodCallHandler(bridge.channel, null);
        tester.testTextInput.register();
        text.dispose();
      });
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LongMessageEditor(
              controller: text,
              autofocus: true,
              inputConnectionFactory: bridge.openConnection,
              onInputModeExit: () async {
                await bridge.close();
                bridge.bindDocument(text);
              },
              decoration: const InputDecoration(),
            ),
          ),
        ),
      );
      await tester.pump(Duration.zero);
      expect(calls, contains('TextInput.show'));
      calls.clear();
      text.value = TextEditingValue(
        text: 'long text\n' * 400,
        selection: const TextSelection.collapsed(offset: 100),
      );
      await tester.pump(Duration.zero);
      await tester.pump(Duration.zero);
      expect(find.byType(CodeEditor), findsOneWidget);
      expect(calls, contains('mirror.open'));
      expect(calls, contains('TextInput.hide'));
      final visibility = calls
          .where((c) => c.endsWith('show') || c.endsWith('hide'))
          .toList();
      expect(visibility.last, 'mirror.show', reason: calls.toString());
      await tester.pumpWidget(const SizedBox());
    },
  );
}
