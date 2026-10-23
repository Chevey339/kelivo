import '../../../support/business_test_harness.dart';
import '../../../support/native_message_input_harness.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:re_editor/re_editor.dart';
import 'package:Kelivo/core/models/chat_input_data.dart';
import 'package:Kelivo/core/models/composer_draft.dart';
import 'package:Kelivo/core/providers/assistant_provider.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/features/home/widgets/chat_input_bar.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/icons/lucide_adapter.dart';
import 'package:Kelivo/shared/text_input/message_editing_controller.dart';
import 'package:Kelivo/shared/widgets/long_message_editor.dart';

class _Composer {
  _Composer({bool native = false})
    : text = MessageEditingController(nativeInputEnabled: native);
  final MessageEditingController text;
  final media = ChatInputBarController();
  final submissions = <ChatInputData>[];
  late String recipientId;
  late AssistantProvider assistants;
  ComposerDraftInput get draft => media.snapshotDraft(text.text);

  Future<void> mount(WidgetTester tester, double width) async {
    if (text.nativeInputEnabled) {
      final native = NativeMessageInputHarness(tester);
      addTearDown(native.dispose);
    }
    tester.view.physicalSize = Size(width, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final settings = SettingsProvider(createBusinessTestPreferences());
    assistants = AssistantProvider(
      preferences: createBusinessTestPreferences(),
    );
    await settings.loaded;
    await assistants.loaded;
    recipientId = await assistants.addAssistant(name: 'Reviewer');
    addTearDown(text.dispose);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: settings),
          ChangeNotifierProvider.value(value: assistants),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Align(
              alignment: Alignment.bottomCenter,
              child: ChatInputBar(
                controller: text,
                mediaController: media,
                onSend: (input) async {
                  submissions.add(input);
                  return ChatInputSubmissionResult.sent;
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> choose(WidgetTester tester) async {
    await tester.enterText(find.byType(TextField), '@Rev');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reviewer'));
    await tester.pumpAndSettle();
  }
}

void main() {
  for (final native in [false, true]) {
    testWidgets('same-name selection is an undo checkpoint native=$native', (
      tester,
    ) async {
      final composer = _Composer(native: native);
      await composer.mount(tester, 1000);
      await composer.choose(tester);
      await tester.pump(const Duration(milliseconds: 600));
      final second = await composer.assistants.addAssistant(name: 'Reviewer');
      await tester.enterText(find.byType(TextField), '@Rev');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.text('Reviewer').at(1));
      await tester.pump(const Duration(milliseconds: 600));
      expect(composer.draft.recipientAssistantId, second);
      await tester.enterText(find.byType(TextField), '@Reviewer next');
      await tester.pump(const Duration(milliseconds: 600));
      final editor = tester.state<LongMessageEditorState>(
        find.byType(LongMessageEditor),
      );
      editor.undo();
      await tester.pump();
      expect(composer.text.text, '@Reviewer ');
      expect(composer.draft.recipientAssistantId, second);
      editor.undo();
      await tester.pump();
      expect(composer.text.text, '@Rev');
      expect(composer.draft.recipientAssistantId, isNull);
      editor.undo();
      await tester.pump();
      expect(composer.text.text, '@Reviewer ');
      expect(composer.draft.recipientAssistantId, composer.recipientId);
      editor.redo();
      await tester.pump();
      expect(composer.draft.recipientAssistantId, isNull);
      editor.redo();
      await tester.pump();
      expect(composer.draft.recipientAssistantId, second);
      editor.redo();
      await tester.pump();
      expect(composer.text.text, '@Reviewer next');
      expect(composer.draft.recipientAssistantId, second);
      await tester.pump(const Duration(milliseconds: 600));
    });
    testWidgets(
      'selection expansion collapse and arrow keys preserve recipient through send native=$native',
      (tester) async {
        final composer = _Composer(native: native);
        await composer.mount(tester, 1000);
        await composer.choose(tester);
        await tester.pump(const Duration(milliseconds: 600));
        await tester.enterText(find.byType(TextField), '@Reviewer hello');
        for (final selection in [
          const TextSelection(baseOffset: 0, extentOffset: 4),
          const TextSelection(baseOffset: 0, extentOffset: 9),
          const TextSelection.collapsed(offset: 9),
        ]) {
          tester.testTextInput.updateEditingValue(
            TextEditingValue(text: '@Reviewer hello', selection: selection),
          );
          await tester.pump();
          expect(composer.draft.recipientAssistantId, composer.recipientId);
        }
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.pump();
        expect(
          composer.text.selection,
          const TextSelection.collapsed(offset: 10),
        );
        expect(composer.draft.recipientAssistantId, composer.recipientId);
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
        await tester.pump();
        expect(
          composer.text.selection,
          const TextSelection.collapsed(offset: 9),
        );
        expect(composer.text.text, '@Reviewer hello');
        expect(composer.draft.recipientAssistantId, composer.recipientId);
        await tester.tap(find.byIcon(Lucide.ArrowUp));
        await tester.pumpAndSettle();
        expect(composer.submissions.single.text, '@Reviewer hello');
        expect(
          composer.submissions.single.recipientAssistantId,
          composer.recipientId,
        );
        await tester.pump(const Duration(milliseconds: 600));
      },
    );
    testWidgets(
      'cut and paste identical mention text stays plain across undo and redo native=$native',
      (tester) async {
        final composer = _Composer(native: native);
        await composer.mount(tester, 1000);
        await composer.choose(tester);
        await tester.pump(const Duration(milliseconds: 600));
        final editor = tester.state<LongMessageEditorState>(
          find.byType(LongMessageEditor),
        );
        composer.text.selection = const TextSelection(
          baseOffset: 0,
          extentOffset: 10,
        );
        final cut = composer.text.selection.textInside(composer.text.text);
        composer.text.value = composer.text.value.replaced(
          composer.text.selection,
          '',
        );
        await tester.pump(const Duration(milliseconds: 600));
        expect(composer.draft.recipientAssistantId, isNull);
        composer.text.value = composer.text.value.replaced(
          composer.text.selection,
          cut,
        );
        await tester.pump(const Duration(milliseconds: 600));
        expect(composer.text.text, '@Reviewer ');
        expect(composer.draft.recipientAssistantId, isNull);
        editor.undo();
        await tester.pump();
        expect(composer.draft.recipientAssistantId, isNull);
        editor.undo();
        await tester.pump();
        expect(composer.draft.recipientAssistantId, composer.recipientId);
        editor.redo();
        await tester.pump();
        editor.redo();
        await tester.pump();
        expect(composer.text.text, '@Reviewer ');
        expect(composer.draft.recipientAssistantId, isNull);
        await tester.pump(const Duration(milliseconds: 600));
      },
    );
    testWidgets(
      'selected ranges keep anchors through Chinese composing and renderer switches native=$native',
      (tester) async {
        final composer = _Composer(native: native);
        await composer.mount(tester, 1000);
        await composer.choose(tester);
        composer.text.selection = const TextSelection.collapsed(offset: 0);
        composer.text.value = composer.text.value
            .replaced(composer.text.selection, '请 ')
            .copyWith(composing: const TextRange(start: 0, end: 1));
        await tester.pump();
        expect(composer.draft.mention?.start, 2);
        expect(composer.draft.recipientAssistantId, composer.recipientId);
        composer.text.value = composer.text.value.copyWith(
          composing: TextRange.empty,
        );
        composer.text.selection = TextSelection.collapsed(
          offset: composer.text.text.length,
        );
        final short = composer.text.text;
        composer.text.value = composer.text.value.replaced(
          composer.text.selection,
          '\n${'more line\n' * 250}',
        );
        await tester.pumpAndSettle();
        expect(find.byType(CodeEditor), findsOneWidget);
        expect(composer.draft.recipientAssistantId, composer.recipientId);
        composer.text.selection = TextSelection(
          baseOffset: short.length,
          extentOffset: composer.text.text.length,
        );
        composer.text.value = composer.text.value.replaced(
          composer.text.selection,
          '',
        );
        await tester.pumpAndSettle();
        // Native input intentionally keeps the line editor until focus exits.
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pumpAndSettle();
        expect(find.byType(TextField), findsOneWidget);
        expect(composer.draft.recipientAssistantId, composer.recipientId);
        composer.text.selection = const TextSelection.collapsed(offset: 5);
        composer.text.value = composer.text.value.replaced(
          composer.text.selection,
          'x',
        );
        expect(composer.draft.recipientAssistantId, isNull);
        await tester.pump(const Duration(milliseconds: 600));
      },
    );
    testWidgets(
      'ambiguous programmatic removal never adopts a duplicate native=$native',
      (tester) async {
        final composer = _Composer(native: native);
        await composer.mount(tester, 1000);
        await composer.choose(tester);
        await tester.enterText(
          find.byType(TextField),
          '@Reviewer foo @Reviewer ',
        );
        composer.text.value = const TextEditingValue(text: '@Reviewer ');
        expect(composer.draft.recipientAssistantId, isNull);
        await tester.pump(const Duration(milliseconds: 600));
      },
    );
    testWidgets(
      'deleting selected mention cannot bind a plain duplicate native=$native',
      (tester) async {
        final composer = _Composer(native: native);
        await composer.mount(tester, 1000);
        await composer.choose(tester);
        await tester.enterText(
          find.byType(TextField),
          '@Reviewer foo @Reviewer ',
        );
        composer.text.selection = const TextSelection(
          baseOffset: 0,
          extentOffset: 14,
        );
        composer.text.value = composer.text.value.replaced(
          composer.text.selection,
          '',
        );
        await tester.pump();
        expect(composer.text.text, '@Reviewer ');
        expect(composer.draft.recipientAssistantId, isNull);
        await tester.pump(const Duration(milliseconds: 600));
      },
    );
  }
  for (final width in [390.0, 1000.0]) {
    testWidgets(
      'inline mention preserves ID through persisted draft and send at $width',
      (tester) async {
        final composer = _Composer();
        await composer.mount(tester, width);
        await composer.choose(tester);
        expect(composer.text.text, '@Reviewer ');
        expect(find.byType(InputChip), findsNothing);
        await tester.enterText(
          find.byType(TextField),
          '@Reviewer Please review',
        );
        composer.text.value = composer.text.value.copyWith(
          text: '  ${composer.text.text}',
          selection: TextSelection.collapsed(
            offset: composer.text.text.length + 2,
          ),
        );
        final saved = ComposerDraftInput.fromJson(composer.draft.toJson());
        expect(saved.recipientAssistantId, composer.recipientId);
        expect(saved.mention?.start, 2);
        expect(saved.copyWith(text: 'No mention').recipientAssistantId, isNull);
        composer.text.clear();
        composer.text.text = saved.text;
        composer.media.restoreDraft(saved);
        await tester.pumpAndSettle();
        await tester.tap(find.byIcon(Lucide.ArrowUp));
        await tester.pumpAndSettle();
        expect(
          composer.submissions.single.recipientAssistantId,
          composer.recipientId,
        );
        expect(composer.submissions.single.mention?.start, 0);
        expect(composer.submissions.single.text, '@Reviewer Please review');
        expect(composer.draft.recipientAssistantId, isNull);
      },
    );

    testWidgets(
      'token deletion cancels routing, undo restores, redo removes; pasted text stays plain at $width',
      (tester) async {
        final composer = _Composer();
        await composer.mount(tester, width);
        await composer.choose(tester);
        await tester.enterText(
          find.byType(TextField),
          '@Reviewer Please review',
        );
        await tester.pump(const Duration(milliseconds: 600));
        await tester.enterText(find.byType(TextField), 'Please review');
        await tester.pump(const Duration(milliseconds: 600));
        expect(composer.draft.recipientAssistantId, isNull);
        final editor = tester.state<LongMessageEditorState>(
          find.byType(LongMessageEditor),
        );
        editor.undo();
        await tester.pump();
        expect(composer.text.text, '@Reviewer Please review');
        expect(composer.draft.recipientAssistantId, composer.recipientId);
        editor.redo();
        await tester.pump();
        expect(composer.draft.recipientAssistantId, isNull);
        await tester.enterText(
          find.byType(TextField),
          '@Reviewer Please review',
        );
        expect(composer.draft.recipientAssistantId, isNull);
        await tester.pump(const Duration(milliseconds: 600));
        editor.undo();
        await tester.pump();
        expect(composer.draft.recipientAssistantId, isNull);
        editor.undo();
        await tester.pump();
        expect(composer.text.text, '@Reviewer Please review');
        expect(composer.draft.recipientAssistantId, composer.recipientId);
      },
    );

    testWidgets(
      'inserts at caret, tracks surrounding edits, preserves Chinese composing and long editor at $width',
      (tester) async {
        final composer = _Composer();
        await composer.mount(tester, width);
        await tester.enterText(find.byType(TextField), '请 @Rev 检查');
        composer.text.selection = const TextSelection.collapsed(offset: 6);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Reviewer'));
        await tester.pumpAndSettle();
        expect(composer.text.text, '请 @Reviewer  检查');
        expect(composer.draft.mention?.start, 2);
        composer.text.value = const TextEditingValue(
          text: '现在请 @Reviewer  检查',
          selection: TextSelection.collapsed(offset: 2),
          composing: TextRange(start: 0, end: 2),
        );
        await tester.pump();
        expect(composer.draft.mention?.start, 4);
        expect(
          composer.text.value.composing,
          const TextRange(start: 0, end: 2),
        );
        final short = composer.text.text;
        composer.text.value = TextEditingValue(
          text: '$short\n${'additional line\n' * 200}',
          selection: const TextSelection.collapsed(offset: 4),
        );
        await tester.pumpAndSettle();
        expect(find.byType(CodeEditor), findsOneWidget);
        expect(composer.draft.recipientAssistantId, composer.recipientId);
        composer.text.value = TextEditingValue(
          text: short,
          selection: TextSelection.collapsed(offset: short.length),
        );
        await tester.pumpAndSettle();
        expect(find.byType(TextField), findsOneWidget);
        expect(composer.draft.recipientAssistantId, composer.recipientId);
        await tester.enterText(find.byType(TextField), '现在请 @Review  检查');
        expect(composer.draft.recipientAssistantId, isNull);
      },
    );
  }

  testWidgets(
    'candidate popup supports keyboard selection and Escape without sending',
    (tester) async {
      final composer = _Composer();
      await composer.mount(tester, 1000);
      await tester.enterText(find.byType(TextField), '@Rev');
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.text('Reviewer'), findsNothing);
      await tester.enterText(find.byType(TextField), '@Re');
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(composer.text.text, '@Reviewer ');
      expect(composer.draft.recipientAssistantId, composer.recipientId);
      expect(composer.submissions, isEmpty);
    },
  );
}
