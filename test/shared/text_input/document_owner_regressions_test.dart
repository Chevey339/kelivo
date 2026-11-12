import 'dart:async';

import 'package:Kelivo/core/models/chat_input_data.dart';
import 'package:Kelivo/core/providers/assistant_provider.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/features/home/widgets/chat_input_bar.dart';
import 'package:Kelivo/icons/lucide_adapter.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/text_input/message_editing_controller.dart';
import 'package:Kelivo/shared/widgets/long_message_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../../support/business_test_harness.dart';
import '../../support/native_message_input_harness.dart';

const _longText = 'alpha beta\n';

Widget _editor(
  MessageEditingController document, {
  required Key key,
  bool accessible = false,
}) => MaterialApp(
  home: MediaQuery(
    data: MediaQueryData(accessibleNavigation: accessible),
    child: Scaffold(
      body: LongMessageEditor(
        key: key,
        controller: document,
        autofocus: true,
        decoration: const InputDecoration(),
        textInputAction: TextInputAction.send,
      ),
    ),
  ),
);

Widget _bar(
  MessageEditingController document,
  FocusNode focus,
  Future<ChatInputSubmissionResult> Function(ChatInputData) onSend,
) => MultiProvider(
  providers: [
    ChangeNotifierProvider(
      create: (_) => SettingsProvider(createBusinessTestPreferences()),
    ),
    ChangeNotifierProvider(
      create: (_) =>
          AssistantProvider(preferences: createBusinessTestPreferences()),
    ),
  ],
  child: MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: ChatInputBar(
        conversationId: 'draft-a',
        controller: document,
        focusNode: focus,
        onSend: onSend,
      ),
    ),
  ),
);

void main() {
  testWidgets('mode handoff cannot release a consumer retirement', (
    tester,
  ) async {
    final native = NativeMessageInputHarness(tester);
    final document = MessageEditingController(nativeInputEnabled: true)
      ..value = TextEditingValue(
        text: _longText * 300,
        selection: const TextSelection.collapsed(offset: 100),
      );
    final editorKey = GlobalKey<LongMessageEditorState>();
    await tester.pumpWidget(_editor(document, key: editorKey));
    await tester.pump();
    expect(document.hasNativeInput, isTrue);

    // Android has accepted Z, but its event is still in transit to Dart.
    native.holdDelivery = true;
    await native.commit('Z');
    await tester.pumpWidget(
      _editor(document, key: editorKey, accessible: true),
    );
    expect(document.isDraining, isTrue);
    final consumerRetirement = document.retireInput();
    await native.release();
    await consumerRetirement;
    await tester.pump();
    await tester.pump();
    final pausedAfterBoth = document.isInputPaused;
    final paragraph = tester.widget<TextField>(find.byType(TextField));
    final readOnlyAfterBoth = paragraph.readOnly;
    final acceptedText = document.text;

    await tester.pumpWidget(const SizedBox());
    await document.disposeAfterInput();
    native.dispose();
    expect(acceptedText, (_longText * 300).replaceRange(100, 100, 'Z'));
    expect(
      pausedAfterBoth,
      isTrue,
      reason: 'Only the consumer that requested retirement may resume it',
    );
    expect(readOnlyAfterBoth, isTrue);
  });

  testWidgets('replacing controller changes native owner and session', (
    tester,
  ) async {
    final native = NativeMessageInputHarness(tester);
    final a = MessageEditingController(nativeInputEnabled: true)
      ..value = TextEditingValue(
        text: 'document A\n' * 300,
        selection: const TextSelection.collapsed(offset: 100),
      );
    final b = MessageEditingController(nativeInputEnabled: true)
      ..value = TextEditingValue(
        text: 'document B\n' * 300,
        selection: const TextSelection.collapsed(offset: 100),
      );
    final delivered = <String>[];
    a.configureOwner(onCommand: (name, value) => delivered.add('A:$name'));
    b.configureOwner(onCommand: (name, value) => delivered.add('B:$name'));
    final editorKey = GlobalKey<LongMessageEditorState>();
    await tester.pumpWidget(_editor(a, key: editorKey));
    await tester.pump();
    final oldSession = native.session;
    await tester.pumpWidget(_editor(b, key: editorKey));
    await tester.pump();
    final newSession = native.session;
    final bOwnsNative = b.hasNativeInput;
    await native.deliver(
      NativeMessageInputHarness.codec.encodeMethodCall(
        MethodCall('action', {'session': native.session, 'action': 4}),
      ),
    );
    await tester.idle();

    await tester.pumpWidget(const SizedBox());
    await a.disposeAfterInput();
    await b.disposeAfterInput();
    native.dispose();
    expect(delivered, [
      'B:submit',
    ], reason: 'The visible replacement document owns native commands');
    expect(newSession, isNot(oldSession));
    expect(bOwnsNative, isTrue);
  });

  testWidgets('sending unfocused short text removes it from undo history', (
    tester,
  ) async {
    final document = MessageEditingController(nativeInputEnabled: true)
      ..value = const TextEditingValue(
        text: 'already submitted',
        selection: TextSelection.collapsed(offset: 17),
      );
    final focus = FocusNode();
    final send = Completer<ChatInputSubmissionResult>();
    final submitted = <String>[];
    await tester.pumpWidget(
      _bar(document, focus, (input) {
        submitted.add(input.text);
        return send.future;
      }),
    );
    expect(focus.hasFocus, isFalse);
    expect(document.hasNativeInput, isFalse);
    await tester.tap(find.byIcon(Lucide.ArrowUp));
    await tester.pump(const Duration(milliseconds: 600));
    expect(submitted, ['already submitted']);
    expect(document.text, isEmpty);
    // Flutter's clear() supplies offset zero, even without field focus.
    expect(document.selection, const TextSelection.collapsed(offset: 0));

    focus.requestFocus();
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'B');
    await tester.pump(const Duration(milliseconds: 600));
    document.history!.undo();
    final afterUndo = document.text;
    send.complete(ChatInputSubmissionResult.sent);
    await tester.pump();
    await tester.pumpWidget(const SizedBox());
    await document.disposeAfterInput();
    focus.dispose();
    expect(
      afterUndo,
      isNot('already submitted'),
      reason: 'Resetting history for a successful Send cannot retain its text',
    );
  });

  testWidgets('local rejected Send survives a pending native retirement', (
    tester,
  ) async {
    final native = NativeMessageInputHarness(tester);
    final source = _longText * 300;
    final document = MessageEditingController(nativeInputEnabled: true)
      ..value = TextEditingValue(
        text: source,
        selection: TextSelection.collapsed(offset: source.length),
      );
    final focus = FocusNode();
    final send = Completer<ChatInputSubmissionResult>();
    final submitted = <String>[];
    final errors = <Object>[];
    await tester.pumpWidget(
      _bar(document, focus, (input) {
        submitted.add(input.text);
        return send.future;
      }),
    );
    focus.requestFocus();
    await tester.pump();
    await tester.pump();
    expect(document.hasNativeInput, isTrue);
    // Catch the unawaited network continuation without suppressing the final
    // no-error assertion; its owner registration itself must finish promptly.
    await runZonedGuarded(
      () => document.performCommand('submit'),
      (error, stack) => errors.add(error),
    );
    await tester.idle();
    expect(submitted, [source.trim()]);
    expect(document.text, isEmpty);

    native.holdDelivery = true;
    await native.commit('X');
    final retirement = document.retireInput();
    expect(document.isDraining, isTrue);
    send.complete(ChatInputSubmissionResult.rejected);
    await tester.idle();
    await native.release();
    await retirement;
    final recovered = document.text;
    await tester.pumpWidget(const SizedBox());
    await document.disposeAfterInput();
    native.dispose();
    focus.dispose();
    expect(
      errors,
      isEmpty,
      reason: 'Rejected Send must wait for drain rather than write into close',
    );
    expect(recovered, '${source}X');
  });
  for (final inHandoff in [false, true]) {
    testWidgets(
      'old accepted event stays with A after controller swap; handoff=$inHandoff',
      (tester) async {
        final native = NativeMessageInputHarness(tester);
        final sourceA = 'document A\n' * 300;
        final sourceB = 'document B\n' * 300;
        final a = MessageEditingController(nativeInputEnabled: true)
          ..value = TextEditingValue(
            text: sourceA,
            selection: const TextSelection.collapsed(offset: 100),
          );
        final b = MessageEditingController(nativeInputEnabled: true)
          ..value = TextEditingValue(
            text: sourceB,
            selection: const TextSelection.collapsed(offset: 100),
          );
        final delivered = <String>[];
        a.configureOwner(onCommand: (name, _) => delivered.add('A:$name'));
        b.configureOwner(onCommand: (name, _) => delivered.add('B:$name'));
        final editorKey = GlobalKey<LongMessageEditorState>();
        await tester.pumpWidget(_editor(a, key: editorKey));
        await tester.pump();
        expect(a.hasNativeInput, isTrue);
        native.holdDelivery = true;
        await native.commit('X');
        if (inHandoff) {
          await tester.pumpWidget(_editor(a, key: editorKey, accessible: true));
          expect(a.isDraining, isTrue);
        }
        await tester.pumpWidget(_editor(b, key: editorKey));
        await tester.pump();
        await native.release();
        await tester.pump();
        await tester.pump();
        expect(b.hasNativeInput, isTrue);
        await native.deliver(
          NativeMessageInputHarness.codec.encodeMethodCall(
            MethodCall('action', {'session': native.session, 'action': 4}),
          ),
        );
        await tester.idle();
        final textA = a.text;
        final textB = b.text;
        final bPaused = b.isInputPaused;
        await tester.pumpWidget(const SizedBox());
        await a.disposeAfterInput();
        await b.disposeAfterInput();
        native.dispose();
        expect(textA, sourceA.replaceRange(100, 100, 'X'));
        expect(textB, sourceB);
        expect(bPaused, isFalse);
        expect(delivered, ['B:submit']);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'network throw during retirement restores draft and preserves original error',
    (tester) async {
      final native = NativeMessageInputHarness(tester);
      final source = _longText * 300;
      final document = MessageEditingController(nativeInputEnabled: true)
        ..value = TextEditingValue(
          text: source,
          selection: TextSelection.collapsed(offset: source.length),
        );
      final focus = FocusNode();
      late Completer<ChatInputSubmissionResult> send;
      final errors = <Object>[];
      final failure = StateError('simulated network failure');
      await tester.pumpWidget(_bar(document, focus, (_) => send.future));
      focus.requestFocus();
      await tester.pump();
      await tester.pump();
      await runZonedGuarded(() {
        // An error future cannot cross Dart error-zone boundaries. Create the
        // controlled network future in the same zone as the Send continuation.
        send = Completer<ChatInputSubmissionResult>();
        return document.performCommand('submit');
      }, (error, stack) => errors.add(error));
      await tester.idle();
      expect(document.text, isEmpty);
      native.holdDelivery = true;
      await native.commit('X');
      final retirement = document.retireInput();
      send.completeError(failure);
      await tester.idle();
      await native.release();
      await retirement;
      await tester.idle();
      final recovered = document.text;
      await tester.pumpWidget(const SizedBox());
      await document.disposeAfterInput();
      native.dispose();
      focus.dispose();
      expect(errors, [same(failure)]);
      expect(recovered == '${source}X', isTrue);
    },
  );
}
