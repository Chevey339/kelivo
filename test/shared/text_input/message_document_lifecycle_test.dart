import 'dart:async';

import 'package:Kelivo/shared/text_input/message_editing_controller.dart';
import 'package:Kelivo/shared/widgets/long_message_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'mirror_harness.dart';

void main() {
  testWidgets('unavailable clipboard leaves the default editor usable', (
    tester,
  ) async {
    final document = MessageEditingController(nativeInputEnabled: true);
    final h = MirrorHarness(tester);
    await h.mount('alpha beta\n' * 300, 100, document: document);
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.getData') {
          throw PlatformException(code: 'clipboard_unavailable');
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
    await document.performCommand('paste');
    await h.replace(100, 100, 'X');
    expect(
      (await document.flushInput()).text,
      ('alpha beta\n' * 300).replaceRange(100, 100, 'X'),
    );
    await h.dispose();
  });

  testWidgets('finished owner callbacks can later await the input barrier', (
    tester,
  ) async {
    final document = MessageEditingController(nativeInputEnabled: true);
    final h = MirrorHarness(tester);
    final network = Completer<void>();
    late Future<TextEditingValue> later;
    document.configureOwner(
      onCommand: (_, _) {
        later = network.future.then((_) => document.flushInput());
      },
    );
    await h.mount('alpha beta\n' * 300, 100, document: document);
    await document.performCommand('submit');
    network.complete();
    expect((await later).text, document.text);
    await h.dispose();
  });

  testWidgets(
    'retiring a focused document does not reopen it on the next frame',
    (tester) async {
      final document = MessageEditingController(nativeInputEnabled: true);
      final h = MirrorHarness(tester);
      await h.mount('alpha beta\n' * 300, 100, document: document);
      final opens = h.commands.where((c) => c.method == 'open').length;
      await document.retireInput();
      await tester.pump();
      await tester.pump();
      final after = h.commands.where((c) => c.method == 'open').length;
      await h.dispose();
      expect(after, opens);
    },
  );

  testWidgets('closing saves accepted native edits after renderer removal', (
    tester,
  ) async {
    final document = MessageEditingController(nativeInputEnabled: true);
    final h = MirrorHarness(tester);
    final source = 'alpha beta\n' * 300;
    await h.mount(source, 100, document: document);
    final message = h.prepare(
      document.value.replaced(document.selection, 'X'),
      [
        [100, 100, 'X'],
      ],
    );
    var closed = false;
    final closing = document.retireInput().then((_) => closed = true);
    await tester.pumpWidget(const SizedBox());
    await tester.idle();
    expect(closed, isFalse);
    await h.dispatch(message);
    await closing;
    expect(document.text, source.replaceRange(100, 100, 'X'));
    await h.dispose();
  });

  testWidgets(
    'document undo survives a removed renderer and later native typing',
    (tester) async {
      final document = MessageEditingController(nativeInputEnabled: true);
      final h = MirrorHarness(tester);
      final source = 'alpha beta\n' * 300;
      await h.mount(source, 100, document: document);
      await tester.pump(const Duration(milliseconds: 600));
      await h.replace(100, 100, 'A');
      await tester.pump(const Duration(milliseconds: 600));
      expect(document.history!.canUndo, isTrue);
      await tester.pumpWidget(const SizedBox());
      await h.dispatch(
        MirrorHarness.codec.encodeMethodCall(
          MethodCall('command', {'session': h.session, 'command': 'undo'}),
        ),
      );
      await tester.idle();
      expect(document.text, source);
      await h.replace(100, 100, 'B');
      expect(
        (await document.flushInput()).text,
        source.replaceRange(100, 100, 'B'),
      );
      await h.dispose();
    },
  );

  testWidgets(
    'history survives paragraph fallback and return to native editor',
    (tester) async {
      final document = MessageEditingController(nativeInputEnabled: true);
      final h = MirrorHarness(tester);
      final source = 'alpha beta\n' * 300;
      await h.mount(source, 100, document: document);
      await tester.pump(const Duration(milliseconds: 600));
      await h.replace(0, source.length, 'مرحبا');
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.byType(TextField), findsOneWidget);
      await document.performCommand('undo');
      await tester.pump();
      await tester.pump();
      expect(document.text, source);
      expect(
        tester
            .state<LongMessageEditorState>(find.byType(LongMessageEditor))
            .usesLineEditor,
        isTrue,
      );
      await document.performCommand('redo');
      await tester.pump();
      await tester.pump();
      expect(document.text, 'مرحبا');
      await h.dispose();
    },
  );

  testWidgets('short-editor paste drains before replacing the draft', (
    tester,
  ) async {
    final document = MessageEditingController(
      text: 'A',
      nativeInputEnabled: true,
    );
    document.selection = const TextSelection.collapsed(offset: 1);
    final clipboard = Completer<String>();
    document.configureOwner(
      onCommand: (_, _) async {
        final text = await clipboard.future;
        document.value = document.value.replaced(document.selection, text);
      },
    );
    final paste = document.performCommand('paste');
    expect(document.needsInputDrain, isTrue);
    var retired = false;
    final closing = document.retireInput().then((_) => retired = true);
    await tester.idle();
    expect(retired, isFalse);
    expect(document.isDraining, isTrue);
    clipboard.complete('PASTE');
    await paste;
    await closing;
    expect(document.text, 'APASTE');
    document.text = 'new draft';
    document.dispose();
  });

  testWidgets(
    'disposal retains asynchronous content registration without a renderer',
    (tester) async {
      final document = MessageEditingController(nativeInputEnabled: true);
      final saved = Completer<void>();
      var registered = false;
      document.configureOwner(
        onContent: (_) async {
          await saved.future;
          registered = true;
        },
      );
      final content = document.insertContent(
        KeyboardInsertedContent(
          mimeType: 'image/png',
          uri: 'content://test/image',
        ),
      );
      var disposed = false;
      final closing = document.disposeAfterInput().then((_) => disposed = true);
      await tester.idle();
      expect(disposed, isFalse);
      saved.complete();
      await content;
      await closing;
      expect(registered, isTrue);
    },
  );
}
