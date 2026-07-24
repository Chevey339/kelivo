import 'package:Kelivo/features/home/controllers/scroll_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_sliver_list/super_sliver_list.dart';

void main() {
  group('ChatScrollController streaming auto-follow', () {
    testWidgets('conversation open reaches bottom in its first layout', (
      tester,
    ) async {
      var itemCount = 8;
      final scrollController = ChatAutoFollowScrollController();
      final chatScrollController = ChatScrollController(
        scrollController: scrollController,
        onStateChanged: () {},
        getAutoScrollEnabled: () => false,
        getAutoScrollIdleSeconds: () => 8,
      );
      await tester.pumpWidget(
        _ScrollHarness(
          scrollController: scrollController,
          itemCount: itemCount,
        ),
      );
      expect(scrollController.position.maxScrollExtent, 0);

      itemCount = 40;
      chatScrollController.positionAtBottomOnNextLayout();
      await tester.pumpWidget(
        _ScrollHarness(
          scrollController: scrollController,
          itemCount: itemCount,
        ),
      );

      expect(
        scrollController.offset,
        scrollController.position.maxScrollExtent,
      );

      chatScrollController.dispose();
      scrollController.dispose();
    });

    testWidgets('short conversation starts with fresh scroll state', (
      tester,
    ) async {
      final previousController = ChatAutoFollowScrollController();
      await tester.pumpWidget(
        KeyedSubtree(
          key: const ValueKey('previous-conversation'),
          child: _ScrollHarness(
            scrollController: previousController,
            itemCount: 40,
          ),
        ),
      );
      previousController.jumpTo(1200);
      expect(previousController.offset, greaterThan(0));

      final nextController = ChatAutoFollowScrollController();
      final nextChatController = ChatScrollController(
        scrollController: nextController,
        onStateChanged: () {},
        getAutoScrollEnabled: () => false,
        getAutoScrollIdleSeconds: () => 8,
      );
      nextChatController.positionAtBottomOnNextLayout();
      await tester.pumpWidget(
        KeyedSubtree(
          key: const ValueKey('next-conversation'),
          child: _SuperScrollHarness(
            scrollController: nextController,
            listController: nextChatController.messageListController,
            itemCount: 8,
            topPadding: 108,
            bottomPadding: 144,
          ),
        ),
      );
      final settle = nextChatController.settleAtBottomBeforeReveal();
      await tester.pumpAndSettle();
      await settle;

      expect(nextController.offset, nextController.position.maxScrollExtent);
      expect(nextController.position.isScrollingNotifier.value, isFalse);
      final firstPaintOffset = nextController.offset;
      final firstPaintTop = tester.getTopLeft(find.text('Message 0')).dy;
      for (var frame = 0; frame < 4; frame++) {
        await tester.pump(const Duration(milliseconds: 16));
        expect(nextController.offset, moreOrLessEquals(firstPaintOffset));
        expect(
          tester.getTopLeft(find.text('Message 0')).dy,
          moreOrLessEquals(firstPaintTop),
        );
      }

      nextChatController.dispose();
      previousController.dispose();
      nextController.dispose();
    });

    testWidgets('conversation reveal resolves the real indexed tail', (
      tester,
    ) async {
      final messages = <_NavMessage>[
        for (var i = 0; i < 2000; i++)
          _NavMessage(id: 'large-message-$i', role: 'assistant'),
      ];
      final scrollController = ChatAutoFollowScrollController();
      final chatScrollController = ChatScrollController(
        scrollController: scrollController,
        onStateChanged: () {},
        getAutoScrollEnabled: () => false,
        getAutoScrollIdleSeconds: () => 8,
      );
      chatScrollController.positionAtBottomOnNextLayout();
      await tester.pumpWidget(
        _VariableExtentIndexedScrollHarness(
          scrollController: scrollController,
          listController: chatScrollController.messageListController,
          messages: messages,
          builtIndices: <int>{},
          topPadding: 108,
          bottomPadding: 144,
        ),
      );

      final settle = chatScrollController.settleAtBottomBeforeReveal();
      await tester.pumpAndSettle();
      await settle;

      expect(find.byKey(const ValueKey('large-message-1999')), findsOneWidget);
      expect(
        scrollController.offset,
        moreOrLessEquals(scrollController.position.maxScrollExtent, epsilon: 1),
      );

      chatScrollController.dispose();
      scrollController.dispose();
    });

    testWidgets('viewport shrink pins only a timeline already at bottom', (
      tester,
    ) async {
      final height = ValueNotifier<double>(600);
      final scrollController = ChatAutoFollowScrollController();
      final chatScrollController = ChatScrollController(
        scrollController: scrollController,
        onStateChanged: () {},
        getAutoScrollEnabled: () => false,
        getAutoScrollIdleSeconds: () => 8,
      );
      await tester.pumpWidget(
        _ResizableScrollHarness(
          scrollController: scrollController,
          height: height,
        ),
      );

      scrollController.jumpTo(scrollController.position.maxScrollExtent);
      await tester.pump();
      expect(
        chatScrollController.pinBottomDuringViewportResizeIfNeeded(),
        isTrue,
      );
      height.value = 360;
      await tester.pump();
      expect(
        scrollController.position.maxScrollExtent - scrollController.offset,
        lessThanOrEqualTo(1),
      );

      scrollController.jumpTo(scrollController.position.maxScrollExtent - 300);
      await tester.pump();
      final readingOffset = scrollController.offset;
      expect(
        chatScrollController.pinBottomDuringViewportResizeIfNeeded(),
        isFalse,
      );
      height.value = 280;
      await tester.pump();
      expect(
        scrollController.offset,
        moreOrLessEquals(readingOffset, epsilon: 1),
      );

      chatScrollController.dispose();
      scrollController.dispose();
      height.dispose();
    });

    testWidgets('conversation switch cancels the previous driven scroll', (
      tester,
    ) async {
      var itemCount = 40;
      final scrollController = ChatAutoFollowScrollController();
      final chatScrollController = ChatScrollController(
        scrollController: scrollController,
        onStateChanged: () {},
        getAutoScrollEnabled: () => false,
        getAutoScrollIdleSeconds: () => 8,
      );
      await tester.pumpWidget(
        _ScrollHarness(
          scrollController: scrollController,
          itemCount: itemCount,
        ),
      );

      chatScrollController.scrollToBottom();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(chatScrollController.explicitBottomAnimationInProgress, isTrue);

      itemCount = 12;
      chatScrollController.positionAtBottomOnNextLayout();
      await tester.pumpWidget(
        _ScrollHarness(
          scrollController: scrollController,
          itemCount: itemCount,
        ),
      );

      expect(
        scrollController.offset,
        scrollController.position.maxScrollExtent,
      );
      expect(scrollController.position.isScrollingNotifier.value, isFalse);
      expect(chatScrollController.explicitBottomAnimationInProgress, isFalse);
      await tester.pump(const Duration(milliseconds: 300));
      expect(
        scrollController.offset,
        scrollController.position.maxScrollExtent,
      );

      chatScrollController.dispose();
      scrollController.dispose();
    });

    testWidgets('conversation switch cancels deferred bottom callbacks', (
      tester,
    ) async {
      var itemCount = 40;
      final scrollController = ChatAutoFollowScrollController();
      final chatScrollController = ChatScrollController(
        scrollController: scrollController,
        onStateChanged: () {},
        getAutoScrollEnabled: () => false,
        getAutoScrollIdleSeconds: () => 8,
      );
      await tester.pumpWidget(
        _ScrollHarness(
          scrollController: scrollController,
          itemCount: itemCount,
        ),
      );

      chatScrollController.forceScrollToBottomSoon(
        postSwitchDelay: const Duration(milliseconds: 220),
      );
      itemCount = 12;
      chatScrollController.positionAtBottomOnNextLayout();
      await tester.pumpWidget(
        _ScrollHarness(
          scrollController: scrollController,
          itemCount: itemCount,
        ),
      );
      scrollController.jumpTo(0);

      await tester.pump(const Duration(milliseconds: 250));
      await tester.pumpAndSettle();
      expect(scrollController.offset, 0);

      chatScrollController.dispose();
      scrollController.dispose();
    });

    testWidgets('streaming bottom command jumps once and layout owns follow', (
      tester,
    ) async {
      var itemCount = 30;
      final scrollController = ChatAutoFollowScrollController();
      final chatScrollController = ChatScrollController(
        scrollController: scrollController,
        onStateChanged: () {},
        getAutoScrollEnabled: () => true,
        getAutoScrollIdleSeconds: () => 8,
        isGenerating: () => true,
      );
      await tester.pumpWidget(
        _ScrollHarness(
          scrollController: scrollController,
          itemCount: itemCount,
        ),
      );
      scrollController.jumpTo(0);

      chatScrollController.scrollToBottom();
      await tester.pump();
      expect(
        scrollController.offset,
        scrollController.position.maxScrollExtent,
      );
      expect(chatScrollController.explicitBottomAnimationInProgress, isFalse);

      final oldOffset = scrollController.offset;
      itemCount++;
      await tester.pumpWidget(
        _ScrollHarness(
          scrollController: scrollController,
          itemCount: itemCount,
        ),
      );
      expect(scrollController.offset, greaterThanOrEqualTo(oldOffset));
      expect(
        scrollController.offset,
        scrollController.position.maxScrollExtent,
      );

      chatScrollController.dispose();
      scrollController.dispose();
    });

    testWidgets('indexed bottom command uses a continuous scroll animation', (
      tester,
    ) async {
      final messages = <_NavMessage>[
        for (var i = 0; i < 40; i++)
          _NavMessage(id: 'message-$i', role: 'assistant'),
      ];
      final scrollController = ChatAutoFollowScrollController();
      final chatScrollController = ChatScrollController(
        scrollController: scrollController,
        onStateChanged: () {},
        getAutoScrollEnabled: () => true,
        getAutoScrollIdleSeconds: () => 8,
        isGenerating: () => true,
      );
      await tester.pumpWidget(
        _IndexedScrollHarness(
          scrollController: scrollController,
          listController: chatScrollController.messageListController,
          messages: messages,
        ),
      );
      scrollController.jumpTo(0);
      chatScrollController.handleUserScrollIntent();

      chatScrollController.forceScrollToBottom();
      await tester.pump();
      expect(chatScrollController.explicitBottomAnimationInProgress, isTrue);
      expect(
        scrollController.offset,
        lessThan(scrollController.position.maxScrollExtent),
      );

      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 16));
      expect(scrollController.offset, greaterThan(0));
      expect(
        scrollController.offset,
        lessThan(scrollController.position.maxScrollExtent),
      );

      await tester.pumpAndSettle();
      expect(
        scrollController.offset,
        moreOrLessEquals(scrollController.position.maxScrollExtent, epsilon: 1),
      );
      expect(chatScrollController.explicitBottomAnimationInProgress, isFalse);

      chatScrollController.dispose();
      scrollController.dispose();
    });

    testWidgets('programmatic animation does not become user scroll intent', (
      tester,
    ) async {
      final scrollController = ChatAutoFollowScrollController();
      final chatScrollController = ChatScrollController(
        scrollController: scrollController,
        onStateChanged: () {},
        getAutoScrollEnabled: () => false,
        getAutoScrollIdleSeconds: () => 8,
      );
      await tester.pumpWidget(
        _ScrollHarness(scrollController: scrollController, itemCount: 30),
      );

      chatScrollController.scrollToBottom();
      await tester.pumpAndSettle();
      chatScrollController.handleUserScrollIntent();
      expect(chatScrollController.isUserScrolling, isTrue);
      expect(chatScrollController.autoStickToBottom, isFalse);

      chatScrollController.dispose();
      scrollController.dispose();
    });

    testWidgets('does not follow new content when auto-scroll is disabled', (
      tester,
    ) async {
      var autoScrollEnabled = false;
      var itemCount = 20;
      final scrollController = ChatAutoFollowScrollController();
      final chatScrollController = ChatScrollController(
        scrollController: scrollController,
        onStateChanged: () {},
        getAutoScrollEnabled: () => autoScrollEnabled,
        getAutoScrollIdleSeconds: () => 8,
        isGenerating: () => true,
      );

      await tester.pumpWidget(
        _ScrollHarness(
          scrollController: scrollController,
          itemCount: itemCount,
        ),
      );
      scrollController.jumpTo(scrollController.position.maxScrollExtent);
      final oldMax = scrollController.position.maxScrollExtent;

      itemCount += 1;
      await tester.pumpWidget(
        _ScrollHarness(
          scrollController: scrollController,
          itemCount: itemCount,
        ),
      );

      expect(scrollController.offset, oldMax);
      expect(
        scrollController.offset,
        lessThan(scrollController.position.maxScrollExtent),
      );

      chatScrollController.dispose();
      scrollController.dispose();
    });

    testWidgets('follows new content when auto-scroll is enabled', (
      tester,
    ) async {
      var autoScrollEnabled = true;
      var itemCount = 20;
      final scrollController = ChatAutoFollowScrollController();
      final chatScrollController = ChatScrollController(
        scrollController: scrollController,
        onStateChanged: () {},
        getAutoScrollEnabled: () => autoScrollEnabled,
        getAutoScrollIdleSeconds: () => 8,
        isGenerating: () => true,
      );

      await tester.pumpWidget(
        _ScrollHarness(
          scrollController: scrollController,
          itemCount: itemCount,
        ),
      );
      scrollController.jumpTo(scrollController.position.maxScrollExtent);

      itemCount += 1;
      await tester.pumpWidget(
        _ScrollHarness(
          scrollController: scrollController,
          itemCount: itemCount,
        ),
      );

      expect(
        scrollController.offset,
        scrollController.position.maxScrollExtent,
      );

      chatScrollController.dispose();
      scrollController.dispose();
    });

    testWidgets('terminal content growth does not auto-follow', (tester) async {
      var itemCount = 20;
      final scrollController = ChatAutoFollowScrollController();
      final chatScrollController = ChatScrollController(
        scrollController: scrollController,
        onStateChanged: () {},
        getAutoScrollEnabled: () => true,
        getAutoScrollIdleSeconds: () => 8,
        isGenerating: () => false,
      );
      await tester.pumpWidget(
        _ScrollHarness(
          scrollController: scrollController,
          itemCount: itemCount,
        ),
      );
      scrollController.jumpTo(scrollController.position.maxScrollExtent);
      final terminalOffset = scrollController.offset;

      itemCount++;
      await tester.pumpWidget(
        _ScrollHarness(
          scrollController: scrollController,
          itemCount: itemCount,
        ),
      );

      expect(scrollController.offset, terminalOffset);
      expect(
        scrollController.offset,
        lessThan(scrollController.position.maxScrollExtent),
      );
      chatScrollController.dispose();
      scrollController.dispose();
    });

    testWidgets('user scroll detaches and bottom button restores follow', (
      tester,
    ) async {
      var itemCount = 24;
      final scrollController = ChatAutoFollowScrollController();
      final chatScrollController = ChatScrollController(
        scrollController: scrollController,
        onStateChanged: () {},
        getAutoScrollEnabled: () => true,
        getAutoScrollIdleSeconds: () => 8,
        isGenerating: () => true,
      );
      await tester.pumpWidget(
        _ScrollHarness(
          scrollController: scrollController,
          itemCount: itemCount,
        ),
      );
      scrollController.jumpTo(0);
      chatScrollController.handleUserScrollIntent();
      final detachedOffset = scrollController.offset;

      itemCount++;
      await tester.pumpWidget(
        _ScrollHarness(
          scrollController: scrollController,
          itemCount: itemCount,
        ),
      );
      expect(scrollController.offset, detachedOffset);
      expect(chatScrollController.autoStickToBottom, isFalse);

      chatScrollController.forceScrollToBottom();
      await tester.pump();
      expect(chatScrollController.explicitBottomAnimationInProgress, isTrue);
      await tester.pumpAndSettle();
      expect(
        scrollController.offset,
        scrollController.position.maxScrollExtent,
      );
      expect(chatScrollController.autoStickToBottom, isTrue);

      final restoredOffset = scrollController.offset;
      itemCount++;
      await tester.pumpWidget(
        _ScrollHarness(
          scrollController: scrollController,
          itemCount: itemCount,
        ),
      );
      expect(scrollController.offset, greaterThan(restoredOffset));
      expect(
        scrollController.offset,
        scrollController.position.maxScrollExtent,
      );
      chatScrollController.dispose();
      scrollController.dispose();
    });

    testWidgets('streaming tail growth is monotonic without rebound', (
      tester,
    ) async {
      var itemCount = 20;
      final scrollController = ChatAutoFollowScrollController();
      final chatScrollController = ChatScrollController(
        scrollController: scrollController,
        onStateChanged: () {},
        getAutoScrollEnabled: () => true,
        getAutoScrollIdleSeconds: () => 8,
        isGenerating: () => true,
      );
      await tester.pumpWidget(
        _ScrollHarness(
          scrollController: scrollController,
          itemCount: itemCount,
        ),
      );
      chatScrollController.scrollToBottom(animate: false);
      await tester.pump();
      var previous = scrollController.offset;

      for (var frame = 0; frame < 6; frame++) {
        itemCount++;
        await tester.pumpWidget(
          _ScrollHarness(
            scrollController: scrollController,
            itemCount: itemCount,
          ),
        );
        expect(scrollController.offset, greaterThanOrEqualTo(previous));
        expect(
          scrollController.offset,
          scrollController.position.maxScrollExtent,
        );
        previous = scrollController.offset;
      }
      chatScrollController.dispose();
      scrollController.dispose();
    });
  });

  group('ChatScrollController message navigation', () {
    testWidgets('collapsed target index scrolls through the indexed list', (
      tester,
    ) async {
      final messages = <_NavMessage>[
        for (var i = 0; i < 40; i++)
          _NavMessage(id: 'message-$i', role: i.isEven ? 'user' : 'assistant'),
      ];
      final scrollController = ChatAutoFollowScrollController();
      final chatScrollController = ChatScrollController(
        scrollController: scrollController,
        onStateChanged: () {},
        getAutoScrollEnabled: () => false,
        getAutoScrollIdleSeconds: () => 8,
      );
      await tester.pumpWidget(
        _IndexedScrollHarness(
          scrollController: scrollController,
          listController: chatScrollController.messageListController,
          messages: messages,
        ),
      );

      final jump = chatScrollController.scrollToMessageId(
        targetId: 'message-25',
        targetIndex: 25,
      );
      await tester.pumpAndSettle();
      await jump;

      expect(chatScrollController.lastJumpUserMessageId, 'message-25');
      expect(scrollController.offset, greaterThan(0));
      chatScrollController.dispose();
      scrollController.dispose();
    });

    testWidgets('streaming previous navigation disables bottom follow first', (
      tester,
    ) async {
      final messages = <_NavMessage>[
        for (var i = 0; i < 40; i++)
          _NavMessage(id: 'message-$i', role: i.isEven ? 'user' : 'assistant'),
      ];
      final scrollController = ChatAutoFollowScrollController();
      final chatScrollController = ChatScrollController(
        scrollController: scrollController,
        onStateChanged: () {},
        getAutoScrollEnabled: () => true,
        getAutoScrollIdleSeconds: () => 8,
        isGenerating: () => true,
      );
      await tester.pumpWidget(
        _IndexedScrollHarness(
          scrollController: scrollController,
          listController: chatScrollController.messageListController,
          messages: messages,
        ),
      );
      scrollController.jumpTo(scrollController.position.maxScrollExtent);
      expect(chatScrollController.autoStickToBottom, isTrue);

      final navigation = chatScrollController.jumpToPreviousQuestion(
        messages: messages,
        indexOfId: (id) => messages.indexWhere((message) => message.id == id),
      );
      expect(chatScrollController.autoStickToBottom, isFalse);
      await tester.pump(const Duration(milliseconds: 16));

      messages.add(const _NavMessage(id: 'message-40', role: 'assistant'));
      await tester.pumpWidget(
        _IndexedScrollHarness(
          scrollController: scrollController,
          listController: chatScrollController.messageListController,
          messages: messages,
        ),
      );
      expect(
        scrollController.offset,
        lessThan(scrollController.position.maxScrollExtent),
      );

      await tester.pumpAndSettle();
      await navigation;
      chatScrollController.dispose();
      scrollController.dispose();
    });

    testWidgets('顶部覆盖层下的连续消息跳转保持精确落点', (tester) async {
      final messages = <_NavMessage>[
        for (var i = 0; i < 40; i++)
          _NavMessage(id: 'message-$i', role: i.isEven ? 'user' : 'assistant'),
      ];
      final scrollController = ChatAutoFollowScrollController();
      final chatScrollController = ChatScrollController(
        scrollController: scrollController,
        onStateChanged: () {},
        getAutoScrollEnabled: () => false,
        getAutoScrollIdleSeconds: () => 8,
        getTopRevealInset: () => 100,
      );
      await tester.pumpWidget(
        _IndexedScrollHarness(
          scrollController: scrollController,
          listController: chatScrollController.messageListController,
          messages: messages,
          topPadding: 108,
        ),
      );

      final initial = chatScrollController.scrollToMessageId(
        targetId: 'message-20',
        targetIndex: 20,
      );
      await tester.pumpAndSettle();
      await initial;
      expect(
        tester.getTopLeft(find.byKey(const ValueKey('message-20'))).dy,
        moreOrLessEquals(100, epsilon: 1),
      );

      final previous = chatScrollController.jumpToPreviousQuestion(
        messages: messages,
        indexOfId: (id) => messages.indexWhere((message) => message.id == id),
      );
      final previousFrameTops = <double>[];
      for (var frame = 0; frame < 15; frame++) {
        await tester.pump(const Duration(milliseconds: 16));
        previousFrameTops.add(
          tester.getTopLeft(find.byKey(const ValueKey('message-19'))).dy,
        );
      }
      await tester.pumpAndSettle();
      expect(await previous, isTrue);
      for (var index = 1; index < previousFrameTops.length; index++) {
        expect(
          previousFrameTops[index],
          greaterThanOrEqualTo(previousFrameTops[index - 1] - 0.5),
        );
      }
      expect(
        tester.getTopLeft(find.byKey(const ValueKey('message-19'))).dy,
        moreOrLessEquals(100, epsilon: 1),
      );
      await tester.pump(const Duration(milliseconds: 32));
      expect(
        tester.getTopLeft(find.byKey(const ValueKey('message-19'))).dy,
        moreOrLessEquals(100, epsilon: 1),
      );

      final next = chatScrollController.jumpToNextQuestion(
        messages: messages,
        indexOfId: (id) => messages.indexWhere((message) => message.id == id),
      );
      final nextFrameTops = <double>[];
      for (var frame = 0; frame < 15; frame++) {
        await tester.pump(const Duration(milliseconds: 16));
        nextFrameTops.add(
          tester.getTopLeft(find.byKey(const ValueKey('message-20'))).dy,
        );
      }
      await tester.pumpAndSettle();
      expect(await next, isTrue);
      for (var index = 1; index < nextFrameTops.length; index++) {
        expect(
          nextFrameTops[index],
          lessThanOrEqualTo(nextFrameTops[index - 1] + 0.5),
        );
      }
      expect(
        tester.getTopLeft(find.byKey(const ValueKey('message-20'))).dy,
        moreOrLessEquals(100, epsilon: 1),
      );
      await tester.pump(const Duration(milliseconds: 32));
      expect(
        tester.getTopLeft(find.byKey(const ValueKey('message-20'))).dy,
        moreOrLessEquals(100, epsilon: 1),
      );

      chatScrollController.dispose();
      scrollController.dispose();
    });

    testWidgets('相邻跳转平滑穿过大消息的真实高度修正', (tester) async {
      final messages = <_NavMessage>[
        for (var i = 0; i < 2000; i++)
          _NavMessage(id: 'large-message-$i', role: 'assistant'),
      ];
      final scrollController = ChatAutoFollowScrollController();
      final chatScrollController = ChatScrollController(
        scrollController: scrollController,
        onStateChanged: () {},
        getAutoScrollEnabled: () => false,
        getAutoScrollIdleSeconds: () => 8,
        getTopRevealInset: () => 100,
      );
      await tester.pumpWidget(
        _VariableExtentIndexedScrollHarness(
          scrollController: scrollController,
          listController: chatScrollController.messageListController,
          messages: messages,
          builtIndices: <int>{},
          topPadding: 108,
        ),
      );

      final initial = chatScrollController.scrollToMessageId(
        targetId: 'large-message-1002',
        targetIndex: 1002,
      );
      await tester.pumpAndSettle();
      await initial;

      final navigation = chatScrollController.jumpToPreviousQuestion(
        messages: messages,
        indexOfId: (id) => messages.indexWhere((message) => message.id == id),
      );
      final frameTops = <double>[];
      for (var frame = 0; frame < 20; frame++) {
        await tester.pump(const Duration(milliseconds: 16));
        final target = find.byKey(const ValueKey('large-message-1001'));
        if (target.evaluate().isNotEmpty) {
          frameTops.add(tester.getTopLeft(target).dy);
        }
      }
      await tester.pumpAndSettle();
      expect(await navigation, isTrue);

      final frameDeltas = <double>[];
      for (var index = 1; index < frameTops.length; index++) {
        frameDeltas.add(frameTops[index] - frameTops[index - 1]);
        expect(
          frameTops[index],
          greaterThanOrEqualTo(frameTops[index - 1] - 0.5),
        );
      }
      for (var index = 1; index < frameDeltas.length; index++) {
        expect(
          frameDeltas[index],
          lessThanOrEqualTo(frameDeltas[index - 1] + 1),
        );
      }
      expect(
        tester.getTopLeft(find.byKey(const ValueKey('large-message-1001'))).dy,
        moreOrLessEquals(100, epsilon: 1),
      );
      await tester.pump(const Duration(milliseconds: 32));
      expect(
        tester.getTopLeft(find.byKey(const ValueKey('large-message-1001'))).dy,
        moreOrLessEquals(100, epsilon: 1),
      );

      chatScrollController.dispose();
      scrollController.dispose();
    });

    testWidgets('上一条消息以索引列表的当前可见项为锚点', (tester) async {
      final messages = <_NavMessage>[
        for (var i = 0; i < 40; i++)
          _NavMessage(
            id: 'message-$i',
            role: i % 5 == 0 ? 'user' : 'assistant',
          ),
      ];
      final scrollController = ChatAutoFollowScrollController();
      final chatScrollController = ChatScrollController(
        scrollController: scrollController,
        onStateChanged: () {},
        getAutoScrollEnabled: () => false,
        getAutoScrollIdleSeconds: () => 8,
      );

      await tester.pumpWidget(
        _IndexedScrollHarness(
          scrollController: scrollController,
          listController: chatScrollController.messageListController,
          messages: messages,
        ),
      );
      scrollController.jumpTo(900);
      await tester.pump();

      final navigation = chatScrollController.jumpToPreviousQuestion(
        messages: messages,
        indexOfId: (id) => messages.indexWhere((message) => message.id == id),
      );
      await tester.pump();
      expect(scrollController.position.isScrollingNotifier.value, isTrue);
      await tester.pumpAndSettle();
      final moved = await navigation;

      expect(moved, isTrue);
      expect(chatScrollController.lastJumpUserMessageId, 'message-10');

      chatScrollController.dispose();
      scrollController.dispose();
    });

    testWidgets('下一条消息以索引列表的当前可见项为锚点', (tester) async {
      final messages = <_NavMessage>[
        for (var i = 0; i < 40; i++)
          _NavMessage(
            id: 'message-$i',
            role: i % 5 == 0 ? 'user' : 'assistant',
          ),
      ];
      final scrollController = ChatAutoFollowScrollController();
      final chatScrollController = ChatScrollController(
        scrollController: scrollController,
        onStateChanged: () {},
        getAutoScrollEnabled: () => false,
        getAutoScrollIdleSeconds: () => 8,
      );

      await tester.pumpWidget(
        _IndexedScrollHarness(
          scrollController: scrollController,
          listController: chatScrollController.messageListController,
          messages: messages,
        ),
      );
      scrollController.jumpTo(900);
      await tester.pump();

      final navigation = chatScrollController.jumpToNextQuestion(
        messages: messages,
        indexOfId: (id) => messages.indexWhere((message) => message.id == id),
      );
      await tester.pumpAndSettle();
      final moved = await navigation;

      expect(moved, isTrue);
      expect(chatScrollController.lastJumpUserMessageId, 'message-12');

      chatScrollController.dispose();
      scrollController.dispose();
    });

    testWidgets('rapid previous taps advance the indexed navigation cursor', (
      tester,
    ) async {
      final messages = <_NavMessage>[
        for (var i = 0; i < 40; i++)
          _NavMessage(
            id: 'message-$i',
            role: i % 5 == 0 ? 'user' : 'assistant',
          ),
      ];
      final scrollController = ChatAutoFollowScrollController();
      final chatScrollController = ChatScrollController(
        scrollController: scrollController,
        onStateChanged: () {},
        getAutoScrollEnabled: () => false,
        getAutoScrollIdleSeconds: () => 8,
      );
      await tester.pumpWidget(
        _IndexedScrollHarness(
          scrollController: scrollController,
          listController: chatScrollController.messageListController,
          messages: messages,
        ),
      );
      scrollController.jumpTo(900);
      await tester.pump();

      final first = chatScrollController.jumpToPreviousQuestion(
        messages: messages,
        indexOfId: (id) => messages.indexWhere((message) => message.id == id),
      );
      await tester.pump(const Duration(milliseconds: 40));
      final second = chatScrollController.jumpToPreviousQuestion(
        messages: messages,
        indexOfId: (id) => messages.indexWhere((message) => message.id == id),
      );
      await tester.pumpAndSettle();
      await Future.wait([first, second]);

      expect(chatScrollController.lastJumpUserMessageId, 'message-9');
      expect(find.byKey(const ValueKey('message-9')), findsOneWidget);

      chatScrollController.dispose();
      scrollController.dispose();
    });

    testWidgets('rapid next taps advance the indexed navigation cursor', (
      tester,
    ) async {
      final messages = <_NavMessage>[
        for (var i = 0; i < 40; i++)
          _NavMessage(
            id: 'message-$i',
            role: i % 5 == 0 ? 'user' : 'assistant',
          ),
      ];
      final scrollController = ChatAutoFollowScrollController();
      final chatScrollController = ChatScrollController(
        scrollController: scrollController,
        onStateChanged: () {},
        getAutoScrollEnabled: () => false,
        getAutoScrollIdleSeconds: () => 8,
      );
      await tester.pumpWidget(
        _IndexedScrollHarness(
          scrollController: scrollController,
          listController: chatScrollController.messageListController,
          messages: messages,
        ),
      );
      scrollController.jumpTo(900);
      await tester.pump();

      final first = chatScrollController.jumpToNextQuestion(
        messages: messages,
        indexOfId: (id) => messages.indexWhere((message) => message.id == id),
      );
      await tester.pump(const Duration(milliseconds: 40));
      final second = chatScrollController.jumpToNextQuestion(
        messages: messages,
        indexOfId: (id) => messages.indexWhere((message) => message.id == id),
      );
      await tester.pumpAndSettle();
      await Future.wait([first, second]);

      expect(chatScrollController.lastJumpUserMessageId, 'message-13');
      expect(find.byKey(const ValueKey('message-13')), findsOneWidget);

      chatScrollController.dispose();
      scrollController.dispose();
    });

    testWidgets(
      'far jump across thousands of large variable items is lazy and exact',
      (tester) async {
        final messages = <_NavMessage>[
          for (var i = 0; i < 2000; i++)
            _NavMessage(id: 'large-message-$i', role: 'assistant'),
        ];
        final builtIndices = <int>{};
        final scrollController = ChatAutoFollowScrollController();
        final chatScrollController = ChatScrollController(
          scrollController: scrollController,
          onStateChanged: () {},
          getAutoScrollEnabled: () => false,
          getAutoScrollIdleSeconds: () => 8,
          getTopRevealInset: () => 100,
        );
        await tester.pumpWidget(
          _VariableExtentIndexedScrollHarness(
            scrollController: scrollController,
            listController: chatScrollController.messageListController,
            messages: messages,
            builtIndices: builtIndices,
            topPadding: 108,
          ),
        );

        const targetIndex = 1804;
        final navigation = chatScrollController.scrollToMessageId(
          targetId: 'large-message-$targetIndex',
          targetIndex: targetIndex,
        );
        await tester.pumpAndSettle();
        await navigation;

        final target = find.byKey(const ValueKey('large-message-1804'));
        expect(target, findsOneWidget);
        final targetRect = tester.getRect(target);
        expect(targetRect.height, 1400);
        expect(targetRect.top, moreOrLessEquals(100, epsilon: 1));
        expect(builtIndices.length, lessThan(100));

        chatScrollController.dispose();
        scrollController.dispose();
      },
    );

    testWidgets(
      'repeated bottom actions reach the indexed tail after extent refinement',
      (tester) async {
        final messages = <_NavMessage>[
          for (var i = 0; i < 2000; i++)
            _NavMessage(id: 'large-message-$i', role: 'assistant'),
        ];
        final scrollController = ChatAutoFollowScrollController();
        final chatScrollController = ChatScrollController(
          scrollController: scrollController,
          onStateChanged: () {},
          getAutoScrollEnabled: () => false,
          getAutoScrollIdleSeconds: () => 8,
        );
        await tester.pumpWidget(
          _VariableExtentIndexedScrollHarness(
            scrollController: scrollController,
            listController: chatScrollController.messageListController,
            messages: messages,
            builtIndices: <int>{},
            bottomPadding: 120,
          ),
        );

        chatScrollController.forceScrollToBottom();
        chatScrollController.forceScrollToBottom();
        chatScrollController.forceScrollToBottom();
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey('large-message-1999')),
          findsOneWidget,
        );
        expect(
          scrollController.offset,
          moreOrLessEquals(
            scrollController.position.maxScrollExtent,
            epsilon: 1,
          ),
        );

        chatScrollController.dispose();
        scrollController.dispose();
      },
    );

    testWidgets('leaving the timeline during an indexed animation is safe', (
      tester,
    ) async {
      final messages = <_NavMessage>[
        for (var i = 0; i < 40; i++)
          _NavMessage(
            id: 'message-$i',
            role: i % 5 == 0 ? 'user' : 'assistant',
          ),
      ];
      final scrollController = ChatAutoFollowScrollController();
      final chatScrollController = ChatScrollController(
        scrollController: scrollController,
        onStateChanged: () {},
        getAutoScrollEnabled: () => false,
        getAutoScrollIdleSeconds: () => 8,
      );
      await tester.pumpWidget(
        _IndexedScrollHarness(
          scrollController: scrollController,
          listController: chatScrollController.messageListController,
          messages: messages,
        ),
      );
      scrollController.jumpTo(900);
      await tester.pump();

      final navigation = chatScrollController.jumpToPreviousQuestion(
        messages: messages,
        indexOfId: (id) => messages.indexWhere((message) => message.id == id),
      );
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await navigation;

      expect(tester.takeException(), isNull);
      chatScrollController.dispose();
      scrollController.dispose();
    });
  });
}

class _ScrollHarness extends StatelessWidget {
  const _ScrollHarness({
    required this.scrollController,
    required this.itemCount,
  });

  final ScrollController scrollController;
  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: SizedBox(
        height: 600,
        child: ListView.builder(
          controller: scrollController,
          itemCount: itemCount,
          itemBuilder: (context, index) {
            return SizedBox(height: 60, child: Text('Message $index'));
          },
        ),
      ),
    );
  }
}

class _ResizableScrollHarness extends StatelessWidget {
  const _ResizableScrollHarness({
    required this.scrollController,
    required this.height,
  });

  final ScrollController scrollController;
  final ValueNotifier<double> height;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Align(
        alignment: Alignment.topCenter,
        child: ValueListenableBuilder<double>(
          valueListenable: height,
          builder: (context, value, child) => SizedBox(
            height: value,
            child: ListView.builder(
              controller: scrollController,
              itemCount: 100,
              itemBuilder: (context, index) => const SizedBox(height: 60),
            ),
          ),
        ),
      ),
    );
  }
}

class _IndexedScrollHarness extends StatelessWidget {
  const _IndexedScrollHarness({
    required this.scrollController,
    required this.listController,
    required this.messages,
    this.topPadding = 0,
  });

  final ScrollController scrollController;
  final ListController listController;
  final List<_NavMessage> messages;
  final double topPadding;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: SizedBox(
        height: 600,
        child: SuperListView.builder(
          controller: scrollController,
          listController: listController,
          padding: EdgeInsets.only(top: topPadding),
          itemCount: messages.length,
          itemBuilder: (context, index) {
            final message = messages[index];
            return SizedBox(
              key: ValueKey(message.id),
              height: 80,
              child: Text('${message.role} ${message.id}'),
            );
          },
          findChildIndexCallback: (key) {
            if (key is! ValueKey<String>) return null;
            final index = messages.indexWhere(
              (message) => message.id == key.value,
            );
            return index < 0 ? null : index;
          },
        ),
      ),
    );
  }
}

class _SuperScrollHarness extends StatelessWidget {
  const _SuperScrollHarness({
    required this.scrollController,
    required this.listController,
    required this.itemCount,
    this.topPadding = 0,
    this.bottomPadding = 0,
  });

  final ScrollController scrollController;
  final ListController listController;
  final int itemCount;
  final double topPadding;
  final double bottomPadding;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: SizedBox(
        height: 600,
        child: SuperListView.builder(
          controller: scrollController,
          listController: listController,
          cacheExtent: 600,
          delayPopulatingCacheArea: false,
          padding: EdgeInsets.only(top: topPadding, bottom: bottomPadding),
          itemCount: itemCount,
          itemBuilder: (context, index) {
            return SizedBox(height: 60, child: Text('Message $index'));
          },
        ),
      ),
    );
  }
}

class _VariableExtentIndexedScrollHarness extends StatelessWidget {
  const _VariableExtentIndexedScrollHarness({
    required this.scrollController,
    required this.listController,
    required this.messages,
    required this.builtIndices,
    this.topPadding = 0,
    this.bottomPadding = 0,
  });

  final ScrollController scrollController;
  final ListController listController;
  final List<_NavMessage> messages;
  final Set<int> builtIndices;
  final double topPadding;
  final double bottomPadding;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          height: 600,
          child: SuperListView.builder(
            controller: scrollController,
            listController: listController,
            delayPopulatingCacheArea: true,
            padding: EdgeInsets.only(top: topPadding, bottom: bottomPadding),
            itemCount: messages.length,
            itemBuilder: (context, index) {
              builtIndices.add(index);
              final message = messages[index];
              return SizedBox(
                key: ValueKey(message.id),
                height: index % 11 == 0 ? 1400 : 60 + (index % 5) * 35,
                child: Text(message.id),
              );
            },
            findChildIndexCallback: (key) {
              if (key is! ValueKey<String>) return null;
              final value = key.value;
              if (!value.startsWith('large-message-')) return null;
              return int.tryParse(value.substring('large-message-'.length));
            },
          ),
        ),
      ),
    );
  }
}

class _NavMessage {
  const _NavMessage({required this.id, required this.role});

  final String id;
  final String role;
}
