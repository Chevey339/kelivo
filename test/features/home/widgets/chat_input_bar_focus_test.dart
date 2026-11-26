import 'dart:io';

import 'package:flutter/gestures.dart';
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
import 'package:Kelivo/shared/widgets/app_text_selection_toolbar.dart';
import 'package:Kelivo/shared/widgets/long_message_editor.dart';
import 'package:Kelivo/theme/design_tokens.dart';

import '../../../support/business_test_harness.dart';

void main() {
  const desktopPlatforms = TargetPlatformVariant({
    TargetPlatform.windows,
    TargetPlatform.macOS,
    TargetPlatform.linux,
  });

  TestWidgetsFlutterBinding.ensureInitialized();
  const pathProvider = MethodChannel('plugins.flutter.io/path_provider');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late Directory appData;

  setUpAll(() async {
    appData = await Directory.systemTemp.createTemp('chat_input_bar_focus_');
    messenger.setMockMethodCallHandler(pathProvider, (_) async => appData.path);
  });

  tearDownAll(() async {
    messenger.setMockMethodCallHandler(pathProvider, null);
    await appData.delete(recursive: true);
  });

  Future<SettingsProvider> pumpBar(
    WidgetTester tester,
    TextEditingController controller,
    FocusNode focusNode, {
    FocusNode? otherFocusNode,
  }) async {
    final settings = (await tester.runAsync(() async {
      final provider = SettingsProvider(createBusinessTestPreferences());
      await provider.loaded;
      return provider;
    }))!;

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
            body: Column(
              children: [
                if (otherFocusNode != null)
                  TextField(focusNode: otherFocusNode),
                Expanded(
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: ChatInputBar(
                      controller: controller,
                      focusNode: focusNode,
                      onSend: (_) async => ChatInputSubmissionResult.rejected,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return settings;
  }

  Future<void> switchAwayAndBack(
    WidgetTester tester, {
    required bool minimized,
  }) async {
    final states = [
      AppLifecycleState.inactive,
      if (minimized) ...[AppLifecycleState.hidden, AppLifecycleState.inactive],
      AppLifecycleState.resumed,
    ];
    for (final state in states) {
      tester.binding.handleAppLifecycleStateChanged(state);
      await tester.pump();
    }
    await tester.pump(const Duration(milliseconds: 350));
  }

  for (final longDraft in [false, true]) {
    for (final minimized in [false, true]) {
      testWidgets('desktop restores focus and selection after '
          '${minimized ? 'minimizing' : 'Alt+Tab'} '
          '(${longDraft ? 'long' : 'short'} draft)', (tester) async {
        final source = longDraft ? 'draft text\n' * 500 : 'draft text';
        final controller = TextEditingController(text: source);
        final focusNode = FocusNode();
        addTearDown(controller.dispose);
        addTearDown(focusNode.dispose);
        await pumpBar(tester, controller, focusNode);

        focusNode.requestFocus();
        await tester.pumpAndSettle();
        const selection = TextSelection(baseOffset: 1, extentOffset: 4);
        controller.selection = selection;
        await tester.pump();
        expect(focusNode.hasPrimaryFocus, isTrue);

        // Repeat to catch restoration that only works on the first switch.
        for (var i = 0; i < 2; i++) {
          await switchAwayAndBack(tester, minimized: minimized);
          expect(focusNode.hasPrimaryFocus, isTrue);
          expect(controller.text, source);
          expect(controller.selection, selection);
        }

        // A real key event must edit the existing selection without a tap
        // or WidgetTester.enterText (which would focus the editor for us).
        await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
        await tester.pump();
        expect(controller.text, source.replaceRange(1, 4, ''));
        expect(controller.selection, const TextSelection.collapsed(offset: 1));
        await tester.pumpWidget(const SizedBox.shrink());
      }, variant: desktopPlatforms);
    }

    testWidgets('desktop padding focuses the ${longDraft ? 'long' : 'short'} '
        'draft editor', (tester) async {
      final controller = TextEditingController(
        text: longDraft ? 'draft text\n' * 500 : 'draft text',
      );
      final focusNode = FocusNode();
      final otherFocusNode = FocusNode();
      addTearDown(controller.dispose);
      addTearDown(focusNode.dispose);
      addTearDown(otherFocusNode.dispose);
      await pumpBar(
        tester,
        controller,
        focusNode,
        otherFocusNode: otherFocusNode,
      );

      final editor = find.byType(LongMessageEditor);
      final area = find
          .ancestor(of: editor, matching: find.byType(Stack))
          .first;
      final editorBounds = tester.getRect(editor);
      final areaBounds = tester.getRect(area);
      final paddingPoints = [
        Offset(editorBounds.left - 6, editorBounds.center.dy),
        Offset(editorBounds.center.dx, editorBounds.top - 2),
        Offset(editorBounds.center.dx, editorBounds.bottom + 2),
        if (longDraft) Offset(editorBounds.center.dx, editorBounds.top + 1),
      ];
      final otherField = find.byWidgetPredicate(
        (widget) => widget is TextField && widget.focusNode == otherFocusNode,
      );

      for (final point in paddingPoints) {
        expect(areaBounds.contains(point), isTrue);
        await tester.tap(otherField, kind: PointerDeviceKind.mouse);
        await tester.pumpAndSettle();
        expect(otherFocusNode.hasPrimaryFocus, isTrue);

        await tester.tapAt(point, kind: PointerDeviceKind.mouse);
        await tester.pumpAndSettle();
        expect(focusNode.hasPrimaryFocus, isTrue, reason: 'Tapped $point');
        expect(tester.testTextInput.hasAnyClients, isTrue);

        if (longDraft && point == paddingPoints.first) {
          final codeEditor = tester.widget<CodeEditor>(find.byType(CodeEditor));
          final scroll = codeEditor.scrollController!.verticalScroller;
          expect(controller.selection.extentOffset, controller.text.length);
          expect(scroll.offset, closeTo(scroll.position.maxScrollExtent, 1));
        }
      }

      expect(editorBounds.top - areaBounds.top, AppSpacing.xs);
      expect(areaBounds.bottom - editorBounds.bottom, AppSpacing.sm);

      const selection = TextSelection.collapsed(offset: 0);
      controller.selection = selection;
      await tester.pumpAndSettle();
      await tester.tapAt(paddingPoints.first, kind: PointerDeviceKind.mouse);
      await tester.pumpAndSettle();
      expect(controller.selection, selection);

      await tester.tapAt(editorBounds.center, kind: PointerDeviceKind.mouse);
      await tester.pumpAndSettle();
      expect(controller.selection, isNot(selection));

      await tester.tapAt(
        editorBounds.center,
        kind: PointerDeviceKind.mouse,
        buttons: kSecondaryMouseButton,
      );
      await tester.pumpAndSettle();
      final toolbar = find.byType(AppTextSelectionToolbar);
      expect(toolbar, findsOneWidget);
      final selectionWithToolbar = controller.selection;
      await tester.tapAt(paddingPoints.first, kind: PointerDeviceKind.mouse);
      await tester.pumpAndSettle();
      expect(toolbar, findsNothing);
      expect(focusNode.hasPrimaryFocus, isTrue);
      expect(controller.selection, selectionWithToolbar);
      await tester.pumpWidget(const SizedBox.shrink());
    }, variant: desktopPlatforms);
  }

  testWidgets('desktop draft font follows the chat font size in both editors', (
    tester,
  ) async {
    final controller = TextEditingController(text: 'draft text');
    final focusNode = FocusNode();
    addTearDown(controller.dispose);
    addTearDown(focusNode.dispose);
    final settings = await pumpBar(tester, controller, focusNode);
    final editable = find.byType(EditableText);
    expect(tester.widget<EditableText>(editable).style.fontSize, 14);

    await tester.runAsync(() => settings.setChatFontScale(1.25));
    await tester.pumpAndSettle();
    expect(tester.widget<EditableText>(editable).style.fontSize, 17.5);

    controller.text = 'draft text\n' * 500;
    await tester.pumpAndSettle();
    final lineEditor = tester.widget<CodeEditor>(find.byType(CodeEditor));
    expect(lineEditor.style?.fontSize, 17.5);
    await tester.pumpWidget(const SizedBox.shrink());
  }, variant: desktopPlatforms);

  testWidgets('desktop resume keeps focus on the other field', (tester) async {
    final controller = TextEditingController(text: 'draft');
    final focusNode = FocusNode();
    final otherFocusNode = FocusNode();
    addTearDown(controller.dispose);
    addTearDown(focusNode.dispose);
    addTearDown(otherFocusNode.dispose);
    await pumpBar(
      tester,
      controller,
      focusNode,
      otherFocusNode: otherFocusNode,
    );
    otherFocusNode.requestFocus();
    await tester.pumpAndSettle();

    await switchAwayAndBack(tester, minimized: false);

    expect(otherFocusNode.hasPrimaryFocus, isTrue);
    expect(focusNode.hasFocus, isFalse);
    tester.testTextInput.enterText('search');
    await tester.pump();
    expect(find.text('search'), findsOneWidget);
    expect(controller.text, 'draft');
    await tester.pumpWidget(const SizedBox.shrink());
  }, variant: desktopPlatforms);

  testWidgets('iOS still dismisses input focus during lifecycle transitions', (
    tester,
  ) async {
    final controller = TextEditingController(text: 'draft');
    final focusNode = FocusNode();
    addTearDown(controller.dispose);
    addTearDown(focusNode.dispose);
    await pumpBar(tester, controller, focusNode);

    for (final state in [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]) {
      if (state != AppLifecycleState.hidden) {
        focusNode.requestFocus();
        await tester.pump();
        expect(focusNode.hasFocus, isTrue);
      }
      tester.binding.handleAppLifecycleStateChanged(state);
      await tester.pump(const Duration(milliseconds: 350));
      expect(focusNode.hasFocus, isFalse, reason: state.name);
      expect(controller.text, 'draft');
    }
    await tester.pumpWidget(const SizedBox.shrink());
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
}
