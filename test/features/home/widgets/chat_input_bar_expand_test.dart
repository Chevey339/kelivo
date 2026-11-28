import 'dart:async';

import '../../../support/business_test_harness.dart';
import '../../../support/android_selection_menu_mock.dart';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:re_editor/re_editor.dart';
import 'package:provider/provider.dart';

import 'package:Kelivo/core/models/chat_input_data.dart';
import 'package:Kelivo/core/models/composer_draft.dart';
import 'package:Kelivo/core/providers/assistant_provider.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/features/home/widgets/chat_input_bar.dart';
import 'package:Kelivo/icons/lucide_adapter.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/widgets/android_text_selection_toolbar.dart';

void main() {
  const barKey = Key('bar');
  const bodyHeight = 600.0;
  const nativeMenuChannel = MethodChannel('app.ios_selection_menu');
  late AndroidSelectionMenuMock androidMenu;

  setUp(() {
    androidMenu = AndroidSelectionMenuMock();
    // These assertions exercise the existing Flutter toolbar on older iOS.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(nativeMenuChannel, (_) async => false);
  });
  tearDown(() {
    androidMenu.dispose();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(nativeMenuChannel, null);
  });

  Future<List<bool>> pumpBar(
    WidgetTester tester,
    TextEditingController controller, {
    ChatInputSubmissionResult sendResult = ChatInputSubmissionResult.rejected,
    bool showBar = true,
    List<ChatInputData>? submissions,
    ChatInputBarController? mediaController,
    Future<ChatInputSubmissionResult> Function(ChatInputData data)? onSend,
  }) async {
    final settings = SettingsProvider(createBusinessTestPreferences());
    await settings.loaded;
    final expandedEvents = <bool>[];
    final focusNode = FocusNode();
    addTearDown(focusNode.dispose);
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
              child: SizedBox(
                width: 400,
                height: bodyHeight,
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: showBar
                      ? ChatInputBar(
                          key: barKey,
                          controller: controller,
                          focusNode: focusNode,
                          mediaController: mediaController,
                          onExpandedChanged: expandedEvents.add,
                          onSend: (data) async {
                            submissions?.add(data);
                            if (onSend != null) return onSend(data);
                            return sendResult;
                          },
                        )
                      : const SizedBox.shrink(),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    return expandedEvents;
  }

  double barHeight(WidgetTester tester) =>
      tester.getSize(find.byKey(barKey)).height;

  for (final draft in ['short', 'scrolling', 'long']) {
    testWidgets(
      'Android Select all keeps the $draft draft menu available for Copy',
      (tester) async {
        final source = switch (draft) {
          'short' => 'alpha beta gamma',
          'scrolling' => 'alpha beta gamma\n' * 25,
          _ => 'alpha beta gamma\n' * 500,
        };
        final controller = TextEditingController(text: source);
        addTearDown(controller.dispose);
        String? clipboard;
        final messenger =
            TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
        messenger.setMockMethodCallHandler(SystemChannels.platform, (
          call,
        ) async {
          if (call.method == 'Clipboard.setData') {
            clipboard = (call.arguments as Map)['text'] as String;
          } else if (call.method == 'Clipboard.getData') {
            return {'text': clipboard};
          } else if (call.method == 'Clipboard.hasStrings') {
            return {'value': clipboard?.isNotEmpty ?? false};
          }
          return null;
        });
        addTearDown(
          () =>
              messenger.setMockMethodCallHandler(SystemChannels.platform, null),
        );
        await pumpBar(tester, controller);

        // Repeat after Copy as well as directly from the initial selection.
        for (var cycle = 0; cycle < 2; cycle++) {
          clipboard = null;
          if (draft == 'long') {
            final editor = tester.widget<CodeEditor>(find.byType(CodeEditor));
            editor.focusNode!.requestFocus();
            editor.controller!.selection = const CodeLineSelection.collapsed(
              index: 0,
              offset: 0,
            );
            editor.scrollController!.verticalScroller.jumpTo(0);
            await tester.pumpAndSettle();
            await tester.longPressAt(
              tester.getTopLeft(find.byType(CodeEditor)) + const Offset(20, 12),
            );
          } else {
            final editable = tester.state<EditableTextState>(
              find.byType(EditableText),
            );
            editable.widget.focusNode.requestFocus();
            await tester.pumpAndSettle();
            editable.userUpdateTextEditingValue(
              controller.value.copyWith(
                selection: const TextSelection(baseOffset: 0, extentOffset: 5),
              ),
              SelectionChangedCause.longPress,
            );
            editable.showToolbar();
          }
          await tester.pumpAndSettle();
          expect(controller.selection.isCollapsed, isFalse);
          expect(controller.selection.end, lessThan(source.length));
          expect(androidMenu.isShown, isTrue);

          await androidMenu.press('Select all');
          // Also allow Copy before the next frame refreshes the editor menu.
          if (cycle == 0) await tester.pumpAndSettle();
          expect(
            controller.selection,
            TextSelection(baseOffset: 0, extentOffset: source.length),
          );
          expect(find.byType(AndroidTextSelectionToolbar), findsOneWidget);
          expect(androidMenu.isShown, isTrue);

          await androidMenu.press('Copy');
          await tester.pumpAndSettle();
          expect(clipboard, source);
          expect(controller.text, source);
          expect(androidMenu.isShown, isFalse);
          expect(find.byType(AndroidTextSelectionToolbar), findsNothing);
        }
        await tester.pumpWidget(const SizedBox.shrink());
      },
      variant: TargetPlatformVariant.only(TargetPlatform.android),
    );
  }

  for (final kind in [
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.stylus,
  ]) {
    testWidgets('toggling keeps focus and the input connection ($kind)', (
      tester,
    ) async {
      final controller = TextEditingController(text: 'line\n' * 6);
      addTearDown(controller.dispose);
      await pumpBar(tester, controller);
      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();
      final focus = tester
          .widget<EditableText>(find.byType(EditableText))
          .focusNode;
      expect(focus.hasFocus, isTrue);

      for (final tooltip in ['Expand', 'Collapse']) {
        tester.testTextInput.log.clear();
        await tester.tap(find.byTooltip(tooltip), kind: kind);
        await tester.pump();
        expect(focus.hasFocus, isTrue, reason: tooltip);
        await tester.pumpAndSettle();
        expect(focus.hasFocus, isTrue, reason: tooltip);
        final methods = tester.testTextInput.log.map((c) => c.method);
        expect(methods, isNot(contains('TextInput.clearClient')));
        expect(methods, isNot(contains('TextInput.hide')));
      }
    }, variant: TargetPlatformVariant.all());
  }

  for (final kind in [
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.stylus,
  ]) {
    testWidgets(
      'toggling long drafts keeps focus and the input connection ($kind)',
      (tester) async {
        final source = 'line\n' * 500;
        final controller = TextEditingController(text: source);
        addTearDown(controller.dispose);
        await pumpBar(tester, controller);
        final focus = tester
            .widget<CodeEditor>(find.byType(CodeEditor))
            .focusNode!;
        focus.requestFocus();
        await tester.pumpAndSettle();

        for (final tooltip in ['Expand', 'Collapse']) {
          tester.testTextInput.log.clear();
          await tester.tap(find.byTooltip(tooltip), kind: kind);
          await tester.pump();
          expect(focus.hasFocus, isTrue, reason: tooltip);
          await tester.pumpAndSettle();
          expect(focus.hasFocus, isTrue, reason: tooltip);
          expect(controller.text, source);
          final methods = tester.testTextInput.log.map((c) => c.method);
          expect(methods, isNot(contains('TextInput.clearClient')));
          expect(methods, isNot(contains('TextInput.hide')));
        }
      },
      variant: TargetPlatformVariant.all(),
    );
  }

  testWidgets(
    'expanding long drafts closes the mobile selection toolbar',
    (tester) async {
      final source = 'line\n' * 500;
      final controller = TextEditingController(text: source);
      addTearDown(controller.dispose);
      await pumpBar(tester, controller);
      final editor = tester.widget<CodeEditor>(find.byType(CodeEditor));
      editor.focusNode!.requestFocus();
      editor.controller!.selection = const CodeLineSelection.collapsed(
        index: 0,
        offset: 0,
      );
      editor.scrollController!.verticalScroller.jumpTo(0);
      await tester.pumpAndSettle();
      for (final tooltip in ['Expand', 'Collapse']) {
        await tester.longPressAt(
          tester.getTopLeft(find.byType(CodeEditor)) + const Offset(20, 12),
        );
        await tester.pumpAndSettle();
        final android =
            Theme.of(tester.element(find.byType(CodeEditor))).platform ==
            TargetPlatform.android;
        if (android) {
          expect(androidMenu.labels, contains('Copy'));
        } else {
          expect(find.text('Copy'), findsOneWidget);
        }
        final nativeHides = androidMenu.calls
            .where((call) => call.method == 'hide')
            .length;

        await tester.tap(find.byTooltip(tooltip));
        await tester.pumpAndSettle();
        expect(editor.focusNode!.hasFocus, isTrue);
        expect(find.text('Copy'), findsNothing);
        if (android) {
          expect(
            androidMenu.calls.where((call) => call.method == 'hide').length,
            greaterThan(nativeHides),
          );
        }
        expect(controller.text, source);
      }
    },
    variant: TargetPlatformVariant({
      TargetPlatform.android,
      TargetPlatform.iOS,
    }),
  );

  testWidgets('offers expansion only once the text wraps past two lines', (
    tester,
  ) async {
    final controller = TextEditingController(text: 'short');
    addTearDown(controller.dispose);
    await pumpBar(tester, controller);
    expect(find.byTooltip('Expand'), findsNothing);

    // A single long paragraph with no line breaks still counts.
    await tester.enterText(find.byType(TextField), 'word ' * 80);
    await tester.pump();
    await tester.pump();
    expect(find.byTooltip('Expand'), findsOneWidget);
  });

  testWidgets('expand button never flickers as the text reflows around it', (
    tester,
  ) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await pumpBar(tester, controller);

    // A long unbreakable word can wrap onto fewer lines when the field is
    // narrower, which once made the button toggle itself every frame.
    for (var n = 1; n <= 60; n++) {
      await tester.enterText(find.byType(TextField), 'This is a ${'x' * n}');
      await tester.pump();
      await tester.pump();
      final visible = find.byTooltip('Expand').evaluate().isNotEmpty;
      for (var frame = 0; frame < 3; frame++) {
        await tester.pump();
        expect(
          find.byTooltip('Expand').evaluate().isNotEmpty,
          visible,
          reason: 'n=$n',
        );
      }
    }
  });

  testWidgets('expands to the full host height and back', (tester) async {
    final controller = TextEditingController(text: 'line\n' * 6);
    addTearDown(controller.dispose);
    final events = await pumpBar(tester, controller);
    final collapsedHeight = barHeight(tester);
    expect(collapsedHeight, lessThan(bodyHeight / 2));

    await tester.tap(find.byTooltip('Expand'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
    final midway = barHeight(tester);
    expect(midway, greaterThan(collapsedHeight));
    expect(midway, lessThan(bodyHeight));

    await tester.pumpAndSettle();
    expect(barHeight(tester), bodyHeight);
    expect(events, [true]);

    await tester.tap(find.byTooltip('Collapse'));
    await tester.pumpAndSettle();
    expect(barHeight(tester), collapsedHeight);
    expect(events, [true, false]);
  });

  testWidgets('long drafts keep expansion and app send shortcuts', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final source = '中文 mixed content **Markdown** 1234567890\n' * 1200;
    final controller = TextEditingController(text: source);
    addTearDown(controller.dispose);
    final submissions = <ChatInputData>[];
    final events = await pumpBar(tester, controller, submissions: submissions);
    expect(find.byType(CodeEditor), findsOneWidget);
    expect(find.byTooltip('Expand'), findsOneWidget);
    final collapsed = barHeight(tester);
    final editor = tester.widget<CodeEditor>(find.byType(CodeEditor));
    editor.focusNode!.requestFocus();
    await tester.pump();
    // At the tablet-sized MediaQuery, Enter belongs to the app's send policy.
    // A rejected send must not also insert a newline in the line editor.
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(controller.text, source);
    expect(submissions, hasLength(1));
    expect(submissions.single.text, source.trim());
    await tester.tap(find.byTooltip('Expand'));
    await tester.pumpAndSettle();
    expect(barHeight(tester), greaterThan(bodyHeight * .9));
    expect(events, [true]);
    await tester.tap(find.byTooltip('Collapse'));
    await tester.pumpAndSettle();
    expect(barHeight(tester), closeTo(collapsed, 1));
    expect(events, [true, false]);
    expect(controller.text, source);
    expect(tester.takeException(), isNull);
  });

  testWidgets('collapse lands on the height of text edited while expanded', (
    tester,
  ) async {
    final controller = TextEditingController(text: 'line\n' * 2 + 'line');
    addTearDown(controller.dispose);
    await pumpBar(tester, controller);

    await tester.tap(find.byTooltip('Expand'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'line\n' * 12);
    await tester.pump();

    await tester.tap(find.byTooltip('Collapse'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 318));
    final lastAnimatedFrame = barHeight(tester);
    await tester.pumpAndSettle();
    expect((lastAnimatedFrame - barHeight(tester)).abs(), lessThan(1));
  });

  testWidgets('survives a long press and rapid toggling mid-animation', (
    tester,
  ) async {
    final controller = TextEditingController(text: 'line\n' * 6);
    addTearDown(controller.dispose);
    await pumpBar(tester, controller);

    await tester.longPress(find.byTooltip('Expand'));
    await tester.pumpAndSettle();
    for (var i = 0; i < 4; i++) {
      final expand = find.byTooltip('Expand');
      await tester.tap(
        expand.evaluate().isNotEmpty ? expand : find.byTooltip('Collapse'),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 90));
    }
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('a rejected send keeps the restored draft expanded', (
    tester,
  ) async {
    final controller = TextEditingController(text: 'line\n' * 6);
    addTearDown(controller.dispose);
    await pumpBar(tester, controller);
    await tester.tap(find.byTooltip('Expand'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Lucide.ArrowUp));
    await tester.pumpAndSettle();
    expect(barHeight(tester), bodyHeight);
    expect(controller.text, 'line\n' * 6);
  });

  testWidgets('an accepted send collapses the editor', (tester) async {
    final controller = TextEditingController(text: 'line\n' * 6);
    addTearDown(controller.dispose);
    final events = await pumpBar(
      tester,
      controller,
      sendResult: ChatInputSubmissionResult.sent,
    );
    await tester.tap(find.byTooltip('Expand'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Lucide.ArrowUp));
    await tester.pumpAndSettle();
    expect(barHeight(tester), lessThan(bodyHeight / 2));
    expect(events, [true, false]);
  });

  testWidgets(
    'an accepted edit-send collapses when the host restores the previous draft',
    (tester) async {
      final controller = TextEditingController(text: 'line\n' * 6);
      addTearDown(controller.dispose);
      const edit = DraftSubmission(
        id: 'send',
        conversationId: 'chat',
        editMessageId: 'message',
      );
      final media = ChatInputBarController()
        ..onBeginSubmission = (_) async => edit;
      final events = await pumpBar(
        tester,
        controller,
        mediaController: media,
        onSend: (data) async {
          // Exiting edit mode restores the pre-edit draft before the accepted
          // send future resolves.
          controller.value = const TextEditingValue(text: 'previous draft');
          media.restoreDraft(
            const ComposerDraftInput(text: 'previous draft'),
            completedEdit: data.draftSubmission,
          );
          return ChatInputSubmissionResult.sent;
        },
      );
      await tester.tap(find.byTooltip('Expand'));
      await tester.pumpAndSettle();
      expect(barHeight(tester), bodyHeight);

      await tester.tap(find.byIcon(Lucide.ArrowUp));
      await tester.pumpAndSettle();

      expect(controller.text, 'previous draft');
      expect(barHeight(tester), lessThan(bodyHeight / 2));
      expect(events, [true, false]);
    },
  );

  testWidgets('a late send leaves a newer message edit expanded', (
    tester,
  ) async {
    final controller = TextEditingController(text: 'ordinary send');
    addTearDown(controller.dispose);
    final media = ChatInputBarController();
    final accepted = Completer<ChatInputSubmissionResult>();
    final events = await pumpBar(
      tester,
      controller,
      mediaController: media,
      onSend: (_) => accepted.future,
    );
    await tester.tap(find.byIcon(Lucide.ArrowUp));
    await tester.pump();
    expect(controller.text, isEmpty);

    final otherMessage = 'other message\n' * 6;
    controller.text = otherMessage;
    media.restoreDraft(ComposerDraftInput(text: otherMessage));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Expand'));
    await tester.pumpAndSettle();
    accepted.complete(ChatInputSubmissionResult.sent);
    await tester.idle();
    await tester.enterText(find.byType(TextField), '${otherMessage}continued');
    await tester.pumpAndSettle();

    expect(controller.text, '${otherMessage}continued');
    expect(barHeight(tester), bodyHeight);
    expect(events, [true]);
  });

  testWidgets('a manually reopened editor survives its earlier send', (
    tester,
  ) async {
    final controller = TextEditingController(text: 'line\n' * 6);
    addTearDown(controller.dispose);
    final accepted = Completer<ChatInputSubmissionResult>();
    final events = await pumpBar(
      tester,
      controller,
      onSend: (_) => accepted.future,
    );
    await tester.tap(find.byTooltip('Expand'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Lucide.ArrowUp));
    await tester.pump();
    await tester.tap(find.byTooltip('Collapse'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'new line\n' * 6);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Expand'));
    await tester.pumpAndSettle();
    accepted.complete(ChatInputSubmissionResult.sent);
    await tester.pumpAndSettle();
    expect(barHeight(tester), bodyHeight);
    expect(events, [true, false, true]);
  });

  testWidgets('replacing a draft before the collapse frame keeps it expanded', (
    tester,
  ) async {
    final controller = TextEditingController(text: 'line\n' * 6);
    addTearDown(controller.dispose);
    final media = ChatInputBarController();
    final accepted = Completer<ChatInputSubmissionResult>();
    final events = await pumpBar(
      tester,
      controller,
      mediaController: media,
      onSend: (_) => accepted.future,
    );
    await tester.tap(find.byTooltip('Expand'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Lucide.ArrowUp));
    await tester.pump();
    accepted.complete(ChatInputSubmissionResult.sent);
    await tester.idle();

    controller.text = 'next draft';
    media.restoreDraft(const ComposerDraftInput(text: 'next draft'));
    await tester.pumpAndSettle();
    expect(controller.text, 'next draft');
    expect(barHeight(tester), bodyHeight);
    expect(events, [true]);
  });

  testWidgets('removing an expanded bar reports that expansion ended', (
    tester,
  ) async {
    final controller = TextEditingController(text: 'line\n' * 6);
    addTearDown(controller.dispose);
    final events = await pumpBar(tester, controller);
    await tester.tap(find.byTooltip('Expand'));
    await tester.pumpAndSettle();
    expect(events, [true]);

    await pumpBar(tester, controller, showBar: false);
    expect(events, [true, false]);
  });

  testWidgets('system back collapses instead of leaving the page', (
    tester,
  ) async {
    final controller = TextEditingController(text: 'line\n' * 6);
    addTearDown(controller.dispose);
    await pumpBar(tester, controller);
    final collapsedHeight = barHeight(tester);

    await tester.tap(find.byTooltip('Expand'));
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(barHeight(tester), collapsedHeight);
    expect(find.byKey(barKey), findsOneWidget);
  });
}
