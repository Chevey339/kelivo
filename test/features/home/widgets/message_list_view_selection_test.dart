import 'package:Kelivo/features/chat/controllers/conversation_find_controller.dart';
import 'package:Kelivo/features/chat/services/conversation_find_service.dart';
import 'package:Kelivo/features/chat/widgets/conversation_find_highlights.dart';
import 'package:markstream/markstream_core.dart' show SourceSpan;
import '../../../support/business_test_harness.dart';
import '../../../support/markdown_render_helpers.dart';

import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/core/providers/assistant_provider.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/providers/tts_provider.dart';
import 'package:Kelivo/core/providers/user_provider.dart';
import 'package:Kelivo/features/home/services/ask_user_interaction_service.dart';
import 'package:Kelivo/features/home/services/tool_approval_service.dart';
import 'package:Kelivo/features/home/widgets/message_list_view.dart';
import 'package:Kelivo/features/home/controllers/scroll_controller.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/widgets/app_selection_area.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:super_sliver_list/super_sliver_list.dart';

const _messageText = 'alpha bravo charlie';
const _wordSelection = TextSelection(baseOffset: 6, extentOffset: 11);
const _overlayHeaderHeight = 160.0;
const _scrollPointerKinds = [
  PointerDeviceKind.touch,
  PointerDeviceKind.stylus,
  PointerDeviceKind.invertedStylus,
];

void main() {
  testWidgets(
    'cycling conversation find highlights the words without animating the whole row',
    (tester) async {
      final matches = [
        for (final start in [0, 6])
          (
            messageId: 'message-1',
            part: FindPart.body,
            block: 0,
            segment: null,
            range: SourceSpan(start, start + 5),
            surfaceKey: null,
          ),
      ];
      final controller = ConversationFindController(
        search: (_, _, _) async => {'message-1': matches},
        onReveal: (_, _) {},
      );
      addTearDown(controller.dispose);
      await _pumpTimeline(
        tester,
        conversationFind: controller,
        content: 'alpha alpha',
      );
      controller.open(selection: 'alpha');
      await tester.pump();
      controller.move(1);
      await tester.pump();
      final highlights = tester.widget<ConversationFindHighlights>(
        find.byType(ConversationFindHighlights),
      );
      expect(highlights.current, matches.last);
      expect(highlights.ranges(FindPart.body, 0), matches.map((h) => h.range));
      final paint = find.byWidgetPredicate(
        (w) =>
            w is DecoratedBox &&
            w.decoration is BoxDecoration &&
            ((w.decoration as BoxDecoration).color
                    ?.withValues(alpha: 1)
                    .toARGB32() ==
                0xffffa726),
      );
      expect(
        find.descendant(of: find.byType(MessageListView), matching: paint),
        findsNothing,
      );
      controller.close();
      await tester.pump();
      expect(
        tester
            .widget<ConversationFindHighlights>(
              find.byType(ConversationFindHighlights),
            )
            .hits,
        isEmpty,
      );
    },
  );

  testWidgets(
    'selecting a minimap hit expands a collapsed user message with find closed',
    (tester) async {
      final content = 'Long user message.\n\n' * 40 + 'keyword';
      final hit = (
        messageId: 'message-1',
        part: FindPart.body,
        block: 0,
        segment: null,
        range: SourceSpan(content.length - 'keyword'.length, content.length),
        surfaceKey: null,
      );
      final reveals = <ConversationFindHit>[];
      final barHit = (
        messageId: hit.messageId,
        part: FindPart.body,
        block: 0,
        segment: null,
        range: const SourceSpan(0, 4),
        surfaceKey: null,
      );
      late bool Function() isCurrent;
      final controller = ConversationFindController(
        search: (_, _, _) async => {
          hit.messageId: [barHit],
        },
        onReveal: (hit, current) {
          reveals.add(hit);
          isCurrent = current;
        },
      );
      addTearDown(controller.dispose);
      await _pumpTimeline(
        tester,
        conversationFind: controller,
        role: 'user',
        content: content,
        collapseLongUserText: true,
      );
      final clip = find.byKey(const ValueKey('collapsible-user-text-clip'));
      expect(clip, findsOneWidget);

      controller.revealPreview(hit);
      await tester.pumpAndSettle();
      expect(reveals, [hit]);
      expect(isCurrent(), isTrue);
      expect(controller.opened, isFalse);
      expect(clip, findsNothing);
      expect(
        tester
            .widget<ConversationFindHighlights>(
              find.byType(ConversationFindHighlights),
            )
            .current,
        hit,
      );
      controller.open(selection: 'Long');
      await tester.pumpAndSettle();
      controller.revealPreview(hit);
      await tester.pumpAndSettle();
      final highlights = tester.widget<ConversationFindHighlights>(
        find.byType(ConversationFindHighlights),
      );
      expect(controller.current, barHit);
      expect(highlights.current, hit);
      expect(highlights.ranges(FindPart.body, 0), [barHit.range, hit.range]);
      controller.setConversation('another-chat');
      await tester.pump();
      expect(isCurrent(), isFalse);
      expect(controller.activeHit, isNull);
    },
  );

  testWidgets(
    'selection edge scroll expresses user intent before auto-follow can pin the page',
    (tester) async {
      tester.view.physicalSize = const Size(400, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final scroll = ChatAutoFollowScrollController();
      var autoFollow = true;
      var scrollIntents = 0;
      scroll.shouldAutoFollow = () => autoFollow;
      await _pumpTimeline(
        tester,
        controller: scroll,
        content: List.generate(
          100,
          (i) => 'anchor$i selectable words on this line.',
        ).join('\n\n'),
        onUserScrollIntent: () {
          autoFollow = false;
          scrollIntents++;
        },
      );
      final bounds = tester.getRect(find.byType(MessageListView));
      final paragraph = renderParagraphs(find.byType(MessageListView))
          .firstWhere((p) {
            final top = p.localToGlobal(Offset.zero).dy;
            return p.text.toPlainText().startsWith('anchor') &&
                top > bounds.top + 100 &&
                top < bounds.bottom - 100;
          });
      final glyph = paragraph
          .getBoxesForSelection(
            const TextSelection(baseOffset: 0, extentOffset: 1),
          )
          .first
          .toRect();
      await tester.longPressAt(paragraph.localToGlobal(glyph.center));
      await tester.pumpAndSettle();
      final region = tester.state<SelectableRegionState>(
        find.bySubtype<SelectableRegion>().first,
      );
      final regionBox = region.context.findRenderObject()! as RenderBox;
      final start =
          regionBox.localToGlobal(region.selectionEndpoints.first.point) +
          const Offset(0, 8);
      autoFollow = true;
      scrollIntents = 0;
      final before = scroll.offset;
      final gesture = await tester.startGesture(start);
      final target = Offset(start.dx, bounds.top + 4);
      for (var i = 1; i <= 12; i++) {
        await gesture.moveTo(Offset.lerp(start, target, i / 12)!);
        await tester.pump(const Duration(milliseconds: 16));
      }
      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(scrollIntents, greaterThan(0));
      expect(scroll.offset, lessThan(before - 60));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets(
    'touch scrolling preserves a released reply selection',
    (tester) async {
      tester.view.physicalSize = const Size(400, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final scroll = ChatAutoFollowScrollController();
      final ios = defaultTargetPlatform == TargetPlatform.iOS;
      final inputFocus = await _pumpTimeline(
        tester,
        controller: scroll,
        headerHeight: ios ? _overlayHeaderHeight : 0,
        content: List.generate(
          100,
          (i) => 'anchor$i selectable words on this line.',
        ).join('\n\n'),
      );
      scroll.jumpTo(scroll.position.maxScrollExtent / 2);
      await tester.pumpAndSettle();

      final timeline = find.byType(MessageListView);
      final bounds = tester.getRect(timeline);
      final paragraph = renderParagraphs(timeline).firstWhere((paragraph) {
        final top = paragraph.localToGlobal(Offset.zero).dy;
        return paragraph.text.toPlainText().startsWith('anchor') &&
            top > bounds.top + 230 &&
            top < bounds.top + 350;
      });
      final word = paragraph
          .getBoxesForSelection(
            const TextSelection(baseOffset: 0, extentOffset: 1),
          )
          .first
          .toRect();
      Offset selectionPoint() => paragraph.localToGlobal(word.center);

      await tester.longPressAt(selectionPoint());
      await tester.pumpAndSettle();
      final selected = paragraph.text.toPlainText().split(' ').first;
      expect(AppSelectionArea.focusedSelection, selected);
      final selection = paragraph.selections.toList();
      expect(selection, isNotEmpty);

      final before = scroll.offset;
      await tester.dragFrom(
        selectionPoint() + const Offset(0, 150),
        const Offset(0, -150),
      );
      await tester.pumpAndSettle();
      expect(scroll.offset, greaterThan(before + 80));
      expect(bounds.contains(selectionPoint()), isTrue);
      expect(AppSelectionArea.focusedSelection, selected);
      expect(paragraph.selections, selection);

      final after = scroll.offset;
      for (final kind in _scrollPointerKinds) {
        scroll.jumpTo(after);
        await tester.pumpAndSettle();
        final swipe = await tester.startGesture(
          selectionPoint() + const Offset(0, 150),
          kind: kind,
        );
        await tester.pump(kPressTimeout + const Duration(milliseconds: 10));
        await swipe.moveBy(const Offset(0, 50));
        await swipe.moveBy(const Offset(0, 70));
        await swipe.up();
        await tester.pumpAndSettle();
        expect(scroll.offset, lessThan(after - 60), reason: '$kind swipe');
        expect(
          AppSelectionArea.focusedSelection,
          selected,
          reason: '$kind swipe',
        );
        expect(paragraph.selections, selection);
      }

      if (ios) {
        final handles = find.descendant(
          of: find.byWidgetPredicate(
            (widget) =>
                widget is CompositedTransformFollower &&
                !widget.showWhenUnlinked &&
                widget.child is FadeTransition,
          ),
          matching: find.byType(RawGestureDetector),
        );
        expect(handles.hitTestable(), findsNWidgets(2));
        final visibleOffset = scroll.offset;
        await tester.dragFrom(
          selectionPoint() + const Offset(100, 150),
          const Offset(0, -110),
        );
        await tester.pumpAndSettle();
        expect(scroll.offset, greaterThan(visibleOffset + 60));
        expect(bounds.contains(selectionPoint()), isTrue);
        expect(selectionPoint().dy, lessThan(_overlayHeaderHeight));
        expect(handles.hitTestable(), findsNothing);
        expect(AppSelectionArea.focusedSelection, selected);
        scroll.jumpTo(visibleOffset);
        await tester.pumpAndSettle();
        expect(handles.hitTestable(), findsNWidgets(2));
      }

      String? copied;
      final messenger = tester.binding.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String;
        }
        return null;
      });
      addTearDown(
        () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
      );
      Actions.invoke(
        FocusManager.instance.primaryFocus!.context!,
        CopySelectionTextIntent.copy,
      );
      await tester.pump();
      expect(copied, selected);

      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();
      expect(inputFocus.hasFocus, isTrue);
      expect(paragraph.selections, isEmpty);
    },
    variant: const TargetPlatformVariant({
      TargetPlatform.android,
      TargetPlatform.iOS,
    }),
  );

  testWidgets(
    'scrolling another reply keeps the selection after the selected row leaves the viewport',
    (tester) async {
      tester.view.physicalSize = const Size(400, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final scroll = ChatAutoFollowScrollController();
      final ios = defaultTargetPlatform == TargetPlatform.iOS;
      await _pumpTimeline(
        tester,
        controller: scroll,
        iosNativeSelectionMenuEnabled: false,
        headerHeight: ios ? _overlayHeaderHeight : 0,
        followingReply: List.generate(
          100,
          (i) => 'line$i selectable words on this line.',
        ).join('\n\n'),
      );

      final timeline = find.byType(MessageListView);
      final bounds = tester.getRect(timeline);
      final paragraphs = renderParagraphs(timeline);
      final selected = paragraphs.singleWhere(
        (paragraph) => paragraph.text.toPlainText() == _messageText,
      );
      final following = paragraphs.firstWhere((paragraph) {
        final top = paragraph.localToGlobal(Offset.zero).dy;
        return paragraph.text.toPlainText().startsWith('line') &&
            top > bounds.center.dy &&
            top < bounds.bottom - 90;
      });
      Offset firstWord(RenderParagraph paragraph) => paragraph.localToGlobal(
        paragraph
            .getBoxesForSelection(
              const TextSelection(baseOffset: 0, extentOffset: 1),
            )
            .first
            .toRect()
            .center,
      );

      await tester.longPressAt(firstWord(selected));
      await tester.pumpAndSettle();
      expect(AppSelectionArea.focusedSelection, 'alpha');
      final copyMenu = find.byType(AdaptiveTextSelectionToolbar);
      if (ios) expect(copyMenu, findsOneWidget);

      for (final kind in _scrollPointerKinds) {
        scroll.jumpTo(0);
        await tester.pumpAndSettle();
        final swipe = await tester.startGesture(
          firstWord(following),
          kind: kind,
        );
        await tester.pump(kPressTimeout + const Duration(milliseconds: 10));
        expect(
          AppSelectionArea.focusedSelection,
          'alpha',
          reason: '$kind down',
        );
        await swipe.moveBy(const Offset(0, -50));
        await swipe.moveBy(const Offset(0, -70));
        await swipe.up();
        await tester.pumpAndSettle();
        expect(scroll.offset, greaterThan(60), reason: '$kind swipe');
        expect(
          AppSelectionArea.focusedSelection,
          'alpha',
          reason: '$kind swipe',
        );
        expect(copyMenu, findsNothing);
      }

      await tester.flingFrom(bounds.center, const Offset(0, -300), 7000);
      await tester.pumpAndSettle();
      expect(scroll.offset, greaterThan(bounds.height + 600));
      expect(AppSelectionArea.focusedSelection, 'alpha');

      scroll.jumpTo(0);
      await tester.pumpAndSettle();
      expect(selected.selections, isNotEmpty);
      if (ios) {
        await tester.tapAt(firstWord(selected));
        await tester.pumpAndSettle();
        expect(copyMenu, findsOneWidget);
      }

      await tester.longPressAt(firstWord(following));
      await tester.pumpAndSettle();
      expect(
        AppSelectionArea.focusedSelection,
        following.text.toPlainText().split(' ').first,
      );
      expect(selected.selections, isEmpty);
    },
    variant: const TargetPlatformVariant({
      TargetPlatform.android,
      TargetPlatform.iOS,
    }),
  );

  for (final role in ['user', 'assistant']) {
    testWidgets(
      '$role message supports keyboard copy after double-click and drag selection',
      (tester) async {
        final copied = <String>[];
        final messenger = tester.binding.defaultBinaryMessenger;
        messenger.setMockMethodCallHandler(SystemChannels.platform, (
          call,
        ) async {
          if (call.method == 'Clipboard.setData') {
            copied.add((call.arguments as Map)['text'] as String);
          }
          return null;
        });
        addTearDown(
          () =>
              messenger.setMockMethodCallHandler(SystemChannels.platform, null),
        );

        await _pumpTimeline(tester, role: role);
        final paragraph = renderParagraphs(find.byType(MessageListView))
            .singleWhere(
              (paragraph) => paragraph.text.toPlainText() == _messageText,
            );

        await _selectWord(tester, paragraph, doubleClick: true);
        expect(paragraph.selections, contains(_wordSelection));
        await _copySelection(tester);
        expect(copied, ['bravo']);

        // Start a separate gesture after the double-click tracking expires.
        await tester.pump(kDoubleTapTimeout);
        await _selectWord(tester, paragraph, doubleClick: false);
        expect(paragraph.selections, contains(_wordSelection));
        await _copySelection(tester);
        expect(copied, ['bravo', 'bravo']);
      },
      variant: TargetPlatformVariant.desktop(),
    );
  }

  testWidgets(
    'clicking the list background still enables keyboard scroll intent',
    (tester) async {
      var scrollIntents = 0;
      final inputFocus = await _pumpTimeline(
        tester,
        onUserScrollIntent: () => scrollIntents++,
      );
      expect(inputFocus.hasFocus, isTrue);

      // The list's top padding is outside the message selection region.
      await tester.tapAt(
        tester.getTopLeft(find.byType(MessageListView)) + const Offset(4, 4),
        kind: PointerDeviceKind.mouse,
      );
      await tester.pump();
      expect(inputFocus.hasFocus, isFalse);

      await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);
      expect(scrollIntents, 1);
    },
    variant: TargetPlatformVariant.desktop(),
  );
}

Future<void> _copySelection(WidgetTester tester) async {
  final modifier = defaultTargetPlatform == TargetPlatform.macOS
      ? LogicalKeyboardKey.metaLeft
      : LogicalKeyboardKey.controlLeft;
  await tester.sendKeyDownEvent(modifier);
  await tester.sendKeyEvent(LogicalKeyboardKey.keyC);
  await tester.sendKeyUpEvent(modifier);
  await tester.pump();
}

Future<void> _selectWord(
  WidgetTester tester,
  RenderParagraph paragraph, {
  required bool doubleClick,
}) async {
  final word = paragraph.getBoxesForSelection(_wordSelection).first.toRect();
  final start = paragraph.localToGlobal(
    doubleClick ? word.center : Offset(word.left + 1, word.center.dy),
  );
  final mouse = await tester.startGesture(start, kind: PointerDeviceKind.mouse);
  await tester.pump(const Duration(milliseconds: 16));
  if (doubleClick) {
    await mouse.up();
    await tester.pump(const Duration(milliseconds: 50));
    await mouse.down(start);
  } else {
    await mouse.moveTo(
      paragraph.localToGlobal(Offset(word.right - 1, word.center.dy)),
    );
  }
  await tester.pump(const Duration(milliseconds: 16));
  await mouse.up();
  await tester.pump(const Duration(milliseconds: 16));
  await mouse.removePointer();
}

Future<FocusNode> _pumpTimeline(
  WidgetTester tester, {
  String role = 'assistant',
  String content = _messageText,
  String? followingReply,
  double headerHeight = 0,
  bool iosNativeSelectionMenuEnabled = true,
  ScrollController? controller,
  VoidCallback? onUserScrollIntent,
  ConversationFindController? conversationFind,
  bool collapseLongUserText = false,
}) async {
  final scrollController = controller ?? ScrollController();
  final listController = ListController();
  final processingFilesMessageId = ValueNotifier<String?>(null);
  final inputFocus = FocusNode();
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    scrollController.dispose();
    listController.dispose();
    processingFilesMessageId.dispose();
    inputFocus.dispose();
  });
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  final settings = SettingsProvider(createBusinessTestPreferences());
  if (collapseLongUserText) await settings.setCollapseLongUserMessages(true);
  if (!iosNativeSelectionMenuEnabled) {
    await settings.setIosNativeSelectionMenuEnabled(false);
  }

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => settings),
        ChangeNotifierProvider(
          create: (_) =>
              AssistantProvider(preferences: createBusinessTestPreferences()),
        ),
        ChangeNotifierProvider(
          create: (_) =>
              TtsProvider(preferences: createBusinessTestPreferences()),
        ),
        ChangeNotifierProvider(
          create: (_) =>
              UserProvider(preferences: createBusinessTestPreferences()),
        ),
        ChangeNotifierProvider(create: (_) => AskUserInteractionService()),
        ChangeNotifierProvider(create: (_) => ToolApprovalService()),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          extendBodyBehindAppBar: headerHeight > 0,
          appBar: headerHeight == 0
              ? null
              : AppBar(toolbarHeight: headerHeight),
          body: Column(
            children: [
              Expanded(
                child: MessageListView(
                  conversationFind: conversationFind,
                  scrollController: scrollController,
                  listController: listController,
                  messages: [
                    ChatMessage(
                      id: 'message-1',
                      role: role,
                      content: content,
                      conversationId: 'conversation-1',
                    ),
                    if (followingReply != null)
                      ChatMessage(
                        id: 'message-2',
                        role: 'assistant',
                        content: followingReply,
                        conversationId: 'conversation-1',
                      ),
                  ],
                  byGroup: const {},
                  versionSelections: const {},
                  reasoning: const {},
                  reasoningSegments: const {},
                  contentSplits: const {},
                  toolParts: const {},
                  translations: const {},
                  selecting: false,
                  selectedItems: const {},
                  dividerPadding: EdgeInsets.zero,
                  topContentPadding: headerHeight + 8,
                  processingFilesMessageId: processingFilesMessageId,
                  showModelIcon: false,
                  showUserAvatar: false,
                  onUserScrollIntent: onUserScrollIntent,
                ),
              ),
              TextField(focusNode: inputFocus, autofocus: true),
            ],
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return inputFocus;
}
