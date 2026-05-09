import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/features/home/controllers/chat_scroll_position.dart';
import 'package:Kelivo/features/home/controllers/scroll_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

const _harnessHeight = 600.0;

void main() {
  group('ChatScrollController indexed navigation', () {
    testWidgets('超远距离跳到底部不会动画构建中间消息', (tester) async {
      var itemCount = 5000;
      final scrollControllers = ChatIndexedScrollControllers();
      final builtIndexes = <int>{};
      final chatScrollController = ChatScrollController(
        indexedControllers: scrollControllers,
        onStateChanged: () {},
        getShouldAutoStickToBottom: () => true,
        getAutoScrollEnabled: () => true,
        getAutoScrollIdleSeconds: () => 8,
        getItemCount: () => itemCount,
        getBottomAnchorAlignment: () => 1,
      );

      await tester.pumpWidget(
        _IndexedScrollHarness(
          scrollControllers: scrollControllers,
          itemCount: itemCount,
          itemBuilder: (context, index) {
            builtIndexes.add(index);
            return SizedBox(height: 56, child: Text('Message $index'));
          },
        ),
      );
      await tester.pump();

      builtIndexes.clear();
      await chatScrollController.scrollToMessageId(
        targetId: 'message-4999',
        targetIndex: itemCount - 1,
      );
      await tester.pump();

      expect(builtIndexes, isNotEmpty);
      expect(
        builtIndexes.any((index) => index >= 4980 && index < itemCount),
        isTrue,
      );
      expect(builtIndexes.any((index) => index > 200 && index < 4800), isFalse);
      expect(builtIndexes.length, lessThan(120));

      chatScrollController.dispose();
    });

    testWidgets('迷你地图跳到远处消息后显示消息导航按钮', (tester) async {
      const itemCount = 5000;
      final scrollControllers = ChatIndexedScrollControllers();
      final chatScrollController = ChatScrollController(
        indexedControllers: scrollControllers,
        onStateChanged: () {},
        getShouldAutoStickToBottom: () => true,
        getAutoScrollEnabled: () => true,
        getAutoScrollIdleSeconds: () => 8,
        getItemCount: () => itemCount,
        getBottomAnchorAlignment: () => 1,
      );

      await tester.pumpWidget(
        _IndexedScrollHarness(
          scrollControllers: scrollControllers,
          itemCount: itemCount,
          itemBuilder: (context, index) {
            return SizedBox(height: 56, child: Text('Message $index'));
          },
        ),
      );
      await tester.pump();

      expect(chatScrollController.showNavButtons, isFalse);

      await chatScrollController.scrollToMessageId(
        targetId: 'message-4500',
        targetIndex: 4500,
      );
      await tester.pump();

      expect(chatScrollController.showNavButtons, isTrue);

      chatScrollController.dispose();
    });

    testWidgets('上一条和下一条用户消息按可见位置跳转', (tester) async {
      const itemCount = 120;
      final messages = List<ChatMessage>.generate(
        itemCount,
        (index) => ChatMessage(
          id: 'message-$index',
          role: index.isEven ? 'user' : 'assistant',
          content: 'Message $index',
          conversationId: 'conversation-1',
        ),
      );
      final scrollControllers = ChatIndexedScrollControllers();
      final chatScrollController = ChatScrollController(
        indexedControllers: scrollControllers,
        onStateChanged: () {},
        getShouldAutoStickToBottom: () => true,
        getAutoScrollEnabled: () => true,
        getAutoScrollIdleSeconds: () => 8,
        getItemCount: () => messages.length,
        getBottomAnchorAlignment: () => 1,
      );

      await tester.pumpWidget(
        _IndexedScrollHarness(
          scrollControllers: scrollControllers,
          itemCount: messages.length,
          initialScrollIndex: 40,
          itemBuilder: (context, index) {
            return SizedBox(height: 56, child: Text(messages[index].id));
          },
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(chatScrollController.hasClients, isTrue);
      final previousAnchor = chatScrollController.visibleRange.firstIndex;
      expect(previousAnchor, greaterThan(0));
      final expectedPrevious = _previousUserIndex(messages, previousAnchor);
      expect(expectedPrevious, greaterThanOrEqualTo(0));

      final previousFuture = chatScrollController.jumpToPreviousQuestion(
        messages: messages,
        indexOfId: (id) => messages.indexWhere((message) => message.id == id),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 240));
      await previousFuture;
      await tester.pump();

      expect(
        scrollControllers.itemPositionsListener.itemPositions.value.any(
          (position) => position.index == expectedPrevious,
        ),
        isTrue,
      );
      expect(
        chatScrollController.lastJumpUserMessageId,
        messages[expectedPrevious].id,
      );

      final expectedNext = _nextUserIndex(messages, expectedPrevious);
      expect(expectedNext, greaterThanOrEqualTo(0));

      final nextFuture = chatScrollController.jumpToNextQuestion(
        messages: messages,
        indexOfId: (id) => messages.indexWhere((message) => message.id == id),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 240));
      await nextFuture;
      await tester.pump();

      expect(
        scrollControllers.itemPositionsListener.itemPositions.value.any(
          (position) => position.index == expectedNext,
        ),
        isTrue,
      );
      expect(
        chatScrollController.lastJumpUserMessageId,
        messages[expectedNext].id,
      );

      chatScrollController.dispose();
    });

    testWidgets('手动滚动中按钮状态不变时不重复通知页面', (tester) async {
      const itemCount = 3000;
      var stateChangeCount = 0;
      final scrollControllers = ChatIndexedScrollControllers();
      final chatScrollController = ChatScrollController(
        indexedControllers: scrollControllers,
        onStateChanged: () {
          stateChangeCount++;
        },
        getShouldAutoStickToBottom: () => true,
        getAutoScrollEnabled: () => true,
        getAutoScrollIdleSeconds: () => 8,
        getItemCount: () => itemCount,
        getBottomAnchorAlignment: () => 1,
      );

      await tester.pumpWidget(
        _IndexedScrollHarness(
          scrollControllers: scrollControllers,
          itemCount: itemCount,
          initialScrollIndex: 1200,
          itemBuilder: (context, index) {
            return SizedBox(height: 56, child: Text('Message $index'));
          },
        ),
      );
      await tester.pump();
      await tester.pump();
      stateChangeCount = 0;

      await tester.drag(
        find.byType(ScrollablePositionedList),
        const Offset(0, -360),
      );
      await tester.pump();
      await tester.pump();

      expect(chatScrollController.showNavButtons, isTrue);
      expect(stateChangeCount, 1);

      chatScrollController.dispose();
    });

    testWidgets('滚到底部时底部锚点完整可见', (tester) async {
      const messageCount = 40;
      const bottomAnchorHeight = 120.0;
      final scrollControllers = ChatIndexedScrollControllers();
      final chatScrollController = ChatScrollController(
        indexedControllers: scrollControllers,
        onStateChanged: () {},
        getShouldAutoStickToBottom: () => true,
        getAutoScrollEnabled: () => true,
        getAutoScrollIdleSeconds: () => 8,
        getItemCount: () => messageCount,
        getBottomAnchorAlignment: () => 1 - bottomAnchorHeight / _harnessHeight,
      );

      await tester.pumpWidget(
        _IndexedScrollHarness(
          scrollControllers: scrollControllers,
          itemCount: messageCount + 1,
          itemBuilder: (context, index) {
            if (index == messageCount) {
              return const SizedBox(height: bottomAnchorHeight);
            }
            return SizedBox(height: 56, child: Text('Message $index'));
          },
        ),
      );
      await tester.pump();

      chatScrollController.scrollToBottom(animate: false);
      await tester.pump();
      await tester.pump();
      await tester.pump();

      final anchor = scrollControllers.itemPositionsListener.itemPositions.value
          .firstWhere((position) => position.index == messageCount);
      expect(anchor.itemLeadingEdge, greaterThanOrEqualTo(0));
      expect(anchor.itemTrailingEdge, closeTo(1, 0.02));
      expect(chatScrollController.isNearBottom(), isTrue);

      chatScrollController.dispose();
    });

    testWidgets('空会话插入第一条消息后保持正向列表顶部位置', (tester) async {
      var messageCount = 0;
      const bottomAnchorHeight = 120.0;
      final bottomAnchorAlignment = 1 - bottomAnchorHeight / _harnessHeight;
      final scrollControllers = ChatIndexedScrollControllers();
      final chatScrollController = ChatScrollController(
        indexedControllers: scrollControllers,
        onStateChanged: () {},
        getShouldAutoStickToBottom: () => true,
        getAutoScrollEnabled: () => true,
        getAutoScrollIdleSeconds: () => 8,
        getItemCount: () => messageCount,
        getBottomAnchorAlignment: () => bottomAnchorAlignment,
      );

      await tester.pumpWidget(
        _IndexedScrollHarness(
          scrollControllers: scrollControllers,
          itemCount: messageCount + 1,
          initialAlignment: bottomAnchorAlignment,
          itemBuilder: (context, index) {
            if (index == messageCount) {
              return const SizedBox(height: bottomAnchorHeight);
            }
            return SizedBox(height: 56, child: Text('Message $index'));
          },
        ),
      );
      await tester.pump();

      messageCount = 1;
      chatScrollController.followBottomAfterContentChange();
      await tester.pumpWidget(
        _IndexedScrollHarness(
          scrollControllers: scrollControllers,
          itemCount: messageCount + 1,
          itemBuilder: (context, index) {
            if (index == messageCount) {
              return const SizedBox(height: bottomAnchorHeight);
            }
            return SizedBox(height: 56, child: Text('Message $index'));
          },
        ),
      );
      await tester.pump();
      await tester.pump();

      final firstMessage = scrollControllers
          .itemPositionsListener
          .itemPositions
          .value
          .firstWhere((position) => position.index == 0);
      expect(firstMessage.itemLeadingEdge, 0);

      chatScrollController.dispose();
    });

    testWidgets('内容不满一屏时滚到底部不会把第一条消息推到底部', (tester) async {
      const messageCount = 1;
      const bottomAnchorHeight = 120.0;
      final scrollControllers = ChatIndexedScrollControllers();
      final chatScrollController = ChatScrollController(
        indexedControllers: scrollControllers,
        onStateChanged: () {},
        getShouldAutoStickToBottom: () => true,
        getAutoScrollEnabled: () => true,
        getAutoScrollIdleSeconds: () => 8,
        getItemCount: () => messageCount,
        getBottomAnchorAlignment: () => 1 - bottomAnchorHeight / _harnessHeight,
      );

      await tester.pumpWidget(
        _IndexedScrollHarness(
          scrollControllers: scrollControllers,
          itemCount: messageCount + 1,
          itemBuilder: (context, index) {
            if (index == messageCount) {
              return const SizedBox(height: bottomAnchorHeight);
            }
            return SizedBox(height: 56, child: Text('Message $index'));
          },
        ),
      );
      await tester.pump();

      chatScrollController.scrollToBottom(animate: false);
      await tester.pump();
      await tester.pump();

      final firstMessage = scrollControllers
          .itemPositionsListener
          .itemPositions
          .value
          .firstWhere((position) => position.index == 0);
      expect(firstMessage.itemLeadingEdge, 0);

      chatScrollController.dispose();
    });
  });
}

int _previousUserIndex(List<ChatMessage> messages, int anchor) {
  for (var i = anchor - 1; i >= 0; i--) {
    if (messages[i].role == 'user') return i;
  }
  return -1;
}

int _nextUserIndex(List<ChatMessage> messages, int anchor) {
  for (var i = anchor + 1; i < messages.length; i++) {
    if (messages[i].role == 'user') return i;
  }
  return -1;
}

class _IndexedScrollHarness extends StatelessWidget {
  const _IndexedScrollHarness({
    required this.scrollControllers,
    required this.itemCount,
    required this.itemBuilder,
    this.initialScrollIndex = 0,
    this.initialAlignment = 0,
  });

  final ChatIndexedScrollControllers scrollControllers;
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final int initialScrollIndex;
  final double initialAlignment;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: SizedBox(
        height: _harnessHeight,
        child: ScrollablePositionedList.builder(
          itemScrollController: scrollControllers.itemScrollController,
          itemPositionsListener: scrollControllers.itemPositionsListener,
          scrollOffsetListener: scrollControllers.scrollOffsetListener,
          initialScrollIndex: initialScrollIndex,
          initialAlignment: initialAlignment,
          itemCount: itemCount,
          minCacheExtent: 0,
          addAutomaticKeepAlives: false,
          itemBuilder: itemBuilder,
        ),
      ),
    );
  }
}
