import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:re_editor/re_editor.dart';

import 'package:Kelivo/core/models/chat_input_data.dart';
import 'package:Kelivo/core/providers/assistant_provider.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/features/home/widgets/chat_input_bar.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/widgets/long_message_editor.dart';

import '../../../support/business_test_harness.dart';

void main() {
  const desktopPlatforms = TargetPlatformVariant({
    TargetPlatform.macOS,
    TargetPlatform.windows,
    TargetPlatform.linux,
  });

  Future<void> pumpBar(
    WidgetTester tester,
    TextEditingController controller,
    List<ChatInputData> submissions, {
    DesktopSendShortcut shortcut = DesktopSendShortcut.enter,
    bool hasQueuedInput = false,
    ChatInputBarController? mediaController,
  }) async {
    final settings = SettingsProvider(createBusinessTestPreferences());
    await settings.loaded;
    await settings.setDesktopSendShortcut(shortcut);
    await settings.setEnterToSendOnMobile(false);
    final focus = FocusNode();
    addTearDown(focus.dispose);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: settings),
          ChangeNotifierProvider.value(
            value: AssistantProvider(
              preferences: createBusinessTestPreferences(),
            ),
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Align(
              alignment: Alignment.bottomCenter,
              child: ChatInputBar(
                controller: controller,
                focusNode: focus,
                hasQueuedInput: hasQueuedInput,
                mediaController: mediaController,
                onSend: (input) async {
                  submissions.add(input);
                  // Retain the draft to detect accidental newlines or a
                  // second submission from the same key press.
                  return ChatInputSubmissionResult.rejected;
                },
              ),
            ),
          ),
        ),
      ),
    );
    focus.requestFocus();
    await tester.pumpAndSettle();
  }

  Future<void> pressEnter(
    WidgetTester tester, {
    LogicalKeyboardKey key = LogicalKeyboardKey.enter,
    LogicalKeyboardKey? modifier,
  }) async {
    // Flutter's Windows raw-key simulator has no numpad Enter mapping. Use
    // Linux event encoding for that chord while keeping the Windows target.
    final platform =
        defaultTargetPlatform == TargetPlatform.windows &&
            key == LogicalKeyboardKey.numpadEnter
        ? 'linux'
        : null;
    if (modifier != null) {
      await tester.sendKeyDownEvent(modifier, platform: platform);
    }
    await tester.sendKeyEvent(key, platform: platform);
    if (modifier != null) {
      await tester.sendKeyUpEvent(modifier, platform: platform);
    }
    await tester.pumpAndSettle();
  }

  for (final longDraft in [false, true]) {
    final draftLabel = longDraft ? 'long' : 'short';
    final source = longDraft ? 'draft text\n' * 500 : 'draft text';

    for (final shortcut in DesktopSendShortcut.values) {
      testWidgets(
        'desktop ${shortcut.name} shortcut survives resizing ($draftLabel draft)',
        (tester) async {
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = const Size(1200, 800);
          addTearDown(tester.view.reset);
          final controller = TextEditingController(text: source);
          addTearDown(controller.dispose);
          final submissions = <ChatInputData>[];
          await pumpBar(tester, controller, submissions, shortcut: shortcut);
          expect(
            find.byType(CodeEditor),
            longDraft ? findsOneWidget : findsNothing,
          );
          final modifier = defaultTargetPlatform == TargetPlatform.macOS
              ? LogicalKeyboardKey.metaLeft
              : LogicalKeyboardKey.controlLeft;
          final modifiedSend = shortcut == DesktopSendShortcut.ctrlEnter;

          // Cross the tablet breakpoint in both directions without replacing
          // the composer, just as dragging a desktop window edge would.
          for (final width in [1200.0, 600.0, 899.0, 900.0, 1200.0]) {
            tester.view.physicalSize = Size(width, 800);
            await tester.pumpAndSettle();
            for (final key in [
              LogicalKeyboardKey.enter,
              LogicalKeyboardKey.numpadEnter,
            ]) {
              controller.value = TextEditingValue(
                text: source,
                selection: TextSelection.collapsed(offset: source.length),
              );
              await tester.pump();
              submissions.clear();
              await pressEnter(
                tester,
                key: key,
                modifier: modifiedSend ? modifier : null,
              );
              expect(submissions, hasLength(1), reason: 'width=$width');
              expect(submissions.single.text, source.trim());
              expect(controller.text, source);

              // The alternate Enter chord must still insert exactly one
              // newline at the caret, without sending the message.
              controller.selection = const TextSelection.collapsed(offset: 5);
              await tester.pump();
              submissions.clear();
              await pressEnter(
                tester,
                key: key,
                modifier: modifiedSend ? null : modifier,
              );
              expect(submissions, isEmpty);
              expect(controller.text, source.replaceRange(5, 5, '\n'));

              controller.value = TextEditingValue(
                text: source,
                selection: const TextSelection(baseOffset: 0, extentOffset: 5),
              );
              await tester.pump();
              await pressEnter(
                tester,
                key: key,
                modifier: LogicalKeyboardKey.shiftLeft,
              );
              expect(submissions, isEmpty);
              expect(controller.text, source.replaceRange(0, 5, '\n'));
            }
          }
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
        },
        variant: desktopPlatforms,
      );
    }

    for (final restoring in [false, true]) {
      for (final shortcut in DesktopSendShortcut.values) {
        testWidgets(
          'desktop ${shortcut.name} keeps ${restoring ? 'restoring' : 'queued'} '
          'draft read-only ($draftLabel draft)',
          (tester) async {
            tester.view.devicePixelRatio = 1;
            tester.view.physicalSize = const Size(600, 800);
            addTearDown(tester.view.reset);
            final value = TextEditingValue(
              text: source,
              selection: const TextSelection(baseOffset: 0, extentOffset: 5),
            );
            final controller = TextEditingController.fromValue(value);
            addTearDown(controller.dispose);
            final submissions = <ChatInputData>[];
            await pumpBar(
              tester,
              controller,
              submissions,
              shortcut: shortcut,
              hasQueuedInput: !restoring,
              mediaController: ChatInputBarController()
                ..restoringDraft = restoring,
            );
            expect(
              tester
                  .widget<LongMessageEditor>(find.byType(LongMessageEditor))
                  .readOnly,
              isTrue,
            );
            for (final width in [600.0, 1200.0]) {
              tester.view.physicalSize = Size(width, 800);
              await tester.pumpAndSettle();
              for (final key in [
                LogicalKeyboardKey.enter,
                LogicalKeyboardKey.numpadEnter,
              ]) {
                for (final modifier in [
                  null,
                  LogicalKeyboardKey.shiftLeft,
                  LogicalKeyboardKey.controlLeft,
                  LogicalKeyboardKey.metaLeft,
                ]) {
                  await pressEnter(tester, key: key, modifier: modifier);
                  expect(controller.text, value.text);
                  expect(controller.selection, value.selection);
                  expect(submissions, isEmpty);
                }
              }
            }
            await tester.pumpWidget(const SizedBox.shrink());
          },
          variant: desktopPlatforms,
        );
      }
    }

    testWidgets(
      'narrow desktop leaves composing Enter to the IME ($draftLabel draft)',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(600, 800);
        addTearDown(tester.view.reset);
        final controller = TextEditingController(text: source);
        addTearDown(controller.dispose);
        final submissions = <ChatInputData>[];
        await pumpBar(tester, controller, submissions);
        final composing = TextEditingValue(
          text: 'ni$source',
          selection: const TextSelection.collapsed(offset: 2),
          composing: const TextRange(start: 0, end: 2),
        );
        // The line editor exposes only a local text window to the IME. Set
        // the document value so both renderers start with the same composing
        // range, regardless of the current native window.
        controller.value = composing;
        await tester.pump();
        for (final key in [
          LogicalKeyboardKey.enter,
          LogicalKeyboardKey.numpadEnter,
        ]) {
          await pressEnter(tester, key: key);
          expect(submissions, isEmpty);
          expect(controller.text, composing.text);
          expect(controller.selection, composing.selection);
          expect(controller.value.composing, composing.composing);
        }

        // Once the IME commits the candidate, Enter can send again.
        controller.value = TextEditingValue(
          text: '你$source',
          selection: const TextSelection.collapsed(offset: 1),
        );
        await tester.pump();
        await pressEnter(tester);
        expect(submissions, hasLength(1));
        expect(submissions.single.text, '你$source'.trim());
        await tester.pumpWidget(const SizedBox.shrink());
      },
      variant: desktopPlatforms,
    );
  }

  testWidgets(
    'mobile Enter remains a newline when mobile send is disabled',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(400, 800);
      addTearDown(tester.view.reset);
      final controller = TextEditingController(text: 'draft');
      addTearDown(controller.dispose);
      final submissions = <ChatInputData>[];
      await pumpBar(tester, controller, submissions);
      controller.selection = const TextSelection.collapsed(offset: 5);
      await tester.pump();
      expect(await tester.sendKeyEvent(LogicalKeyboardKey.enter), isFalse);
      expect(
        tester.widget<TextField>(find.byType(TextField)).textInputAction,
        TextInputAction.newline,
      );
      // The unhandled Enter is forwarded to the native text input, which
      // returns the edit; widget tests have no native keyboard to do that.
      tester.testTextInput.updateEditingValue(
        const TextEditingValue(
          text: 'draft\n',
          selection: TextSelection.collapsed(offset: 6),
        ),
      );
      await tester.pump();
      expect(submissions, isEmpty);
      expect(controller.text, 'draft\n');
      await tester.pumpWidget(const SizedBox.shrink());
    },
    variant: const TargetPlatformVariant({
      TargetPlatform.android,
      TargetPlatform.iOS,
    }),
  );
}
