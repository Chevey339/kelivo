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

    testWidgets('导航按钮隐藏后继续拖动会重新显示', (tester) async {
      const itemCount = 3000;
      final scrollControllers = ChatIndexedScrollControllers();
      final chatScrollController = ChatScrollController(
        indexedControllers: scrollControllers,
        onStateChanged: () {},
        getShouldAutoStickToBottom: () => true,
        getAutoScrollEnabled: () => true,
        getItemCount: () => itemCount,
        getBottomAnchorAlignment: () => 1,
      );

      await tester.pumpWidget(
        _IndexedScrollHarness(
          scrollControllers: scrollControllers,
          itemCount: itemCount,
          initialScrollIndex: 1200,
          itemBuilder: (context, index) {
            return SizedBox(height: 160, child: Text('Message $index'));
          },
        ),
      );
      await tester.pump();
      await tester.pump();

      await tester.drag(
        find.byType(ScrollablePositionedList),
        const Offset(0, -120),
      );
      await tester.pump();
      expect(chatScrollController.showNavButtons, isTrue);

      await tester.pump(const Duration(milliseconds: 2100));
      expect(chatScrollController.showNavButtons, isFalse);

      await tester.drag(
        find.byType(ScrollablePositionedList),
        const Offset(0, -24),
      );
      await tester.pump();

      expect(chatScrollController.showNavButtons, isTrue);

      chatScrollController.dispose();
    });

    testWidgets('从底部开始手动上滑会立即停止流式自动贴底', (tester) async {
      const messageCount = 120;
      const bottomAnchorHeight = 120.0;
      final bottomAnchorAlignment = 1 - bottomAnchorHeight / _harnessHeight;
      final scrollControllers = ChatIndexedScrollControllers();
      final chatScrollController = ChatScrollController(
        indexedControllers: scrollControllers,
        onStateChanged: () {},
        getShouldAutoStickToBottom: () => true,
        getAutoScrollEnabled: () => true,
        getItemCount: () => messageCount,
        getBottomAnchorAlignment: () => bottomAnchorAlignment,
      );

      await tester.pumpWidget(
        _IndexedScrollHarness(
          scrollControllers: scrollControllers,
          itemCount: messageCount + 1,
          initialScrollIndex: messageCount,
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
      expect(chatScrollController.isNearBottom(), isTrue);
      expect(chatScrollController.autoStickToBottom, isTrue);

      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(ScrollablePositionedList)),
      );
      await gesture.moveBy(const Offset(0, 48));
      await tester.pump();

      expect(chatScrollController.autoStickToBottom, isFalse);

      chatScrollController.autoScrollToBottomIfNeeded();
      await tester.pump();

      expect(chatScrollController.autoStickToBottom, isFalse);

      await gesture.up();
      chatScrollController.dispose();
    });

    testWidgets('用户从底部向上阅读时即使底部锚点仍可见也不恢复贴底', (tester) async {
      const messageCount = 120;
      const bottomAnchorHeight = 120.0;
      final bottomAnchorAlignment = 1 - bottomAnchorHeight / _harnessHeight;
      final scrollControllers = ChatIndexedScrollControllers();
      final chatScrollController = ChatScrollController(
        indexedControllers: scrollControllers,
        onStateChanged: () {},
        getShouldAutoStickToBottom: () => true,
        getAutoScrollEnabled: () => true,
        getItemCount: () => messageCount,
        getBottomAnchorAlignment: () => bottomAnchorAlignment,
      );

      await tester.pumpWidget(
        _IndexedScrollHarness(
          scrollControllers: scrollControllers,
          itemCount: messageCount + 1,
          initialScrollIndex: messageCount,
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
      expect(chatScrollController.isNearBottom(), isTrue);

      await tester.drag(
        find.byType(ScrollablePositionedList),
        const Offset(0, 12),
      );
      await tester.pump(const Duration(milliseconds: 240));

      expect(chatScrollController.isNearBottom(), isTrue);
      expect(chatScrollController.autoStickToBottom, isFalse);

      await tester.pump(const Duration(milliseconds: 1200));

      expect(chatScrollController.isNearBottom(), isTrue);
      expect(chatScrollController.autoStickToBottom, isFalse);

      chatScrollController.autoScrollToBottomIfNeeded();
      await tester.pump();

      expect(chatScrollController.autoStickToBottom, isFalse);

      chatScrollController.dispose();
    });

    testWidgets('用户上滑离开底部后空闲状态会结束以允许阅读锚点维护', (tester) async {
      const messageCount = 120;
      const bottomAnchorHeight = 120.0;
      final bottomAnchorAlignment = 1 - bottomAnchorHeight / _harnessHeight;
      final scrollControllers = ChatIndexedScrollControllers();
      late final ChatScrollController chatScrollController;
      chatScrollController = ChatScrollController(
        indexedControllers: scrollControllers,
        onStateChanged: () {},
        getShouldAutoStickToBottom: () {
          if (chatScrollController.isUserScrolling) return false;
          return chatScrollController.isNearBottom(48);
        },
        getAutoScrollEnabled: () => true,
        getItemCount: () => messageCount,
        getBottomAnchorAlignment: () => bottomAnchorAlignment,
      );

      await tester.pumpWidget(
        _IndexedScrollHarness(
          scrollControllers: scrollControllers,
          itemCount: messageCount + 1,
          initialScrollIndex: messageCount,
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

      await tester.drag(
        find.byType(ScrollablePositionedList),
        const Offset(0, 360),
      );
      await tester.pump();
      expect(chatScrollController.isUserScrolling, isTrue);

      await tester.pump(const Duration(milliseconds: 240));

      expect(chatScrollController.autoStickToBottom, isFalse);
      expect(chatScrollController.isNearBottom(), isFalse);
      expect(chatScrollController.isUserScrolling, isFalse);

      chatScrollController.dispose();
    });

    testWidgets('用户展开消息内容后内容变化不会重新强行贴底', (tester) async {
      const messageCount = 80;
      const bottomAnchorHeight = 120.0;
      final bottomAnchorAlignment = 1 - bottomAnchorHeight / _harnessHeight;
      final scrollControllers = ChatIndexedScrollControllers();
      final chatScrollController = ChatScrollController(
        indexedControllers: scrollControllers,
        onStateChanged: () {},
        getShouldAutoStickToBottom: () => true,
        getAutoScrollEnabled: () => true,
        getItemCount: () => messageCount,
        getBottomAnchorAlignment: () => bottomAnchorAlignment,
      );

      await tester.pumpWidget(
        _IndexedScrollHarness(
          scrollControllers: scrollControllers,
          itemCount: messageCount + 1,
          initialScrollIndex: messageCount,
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

      expect(chatScrollController.autoStickToBottom, isTrue);

      chatScrollController.suspendAutoStickForUserInteraction();
      chatScrollController.followBottomAfterContentChange();
      await tester.pump();

      expect(chatScrollController.autoStickToBottom, isFalse);

      chatScrollController.dispose();
    });

    testWidgets('用户暂停贴底后空闲计时不会隐式恢复流式贴底', (tester) async {
      const messageCount = 80;
      const bottomAnchorHeight = 120.0;
      final bottomAnchorAlignment = 1 - bottomAnchorHeight / _harnessHeight;
      final scrollControllers = ChatIndexedScrollControllers();
      final chatScrollController = ChatScrollController(
        indexedControllers: scrollControllers,
        onStateChanged: () {},
        getShouldAutoStickToBottom: () => true,
        getAutoScrollEnabled: () => true,
        getItemCount: () => messageCount,
        getBottomAnchorAlignment: () => bottomAnchorAlignment,
      );

      await tester.pumpWidget(
        _IndexedScrollHarness(
          scrollControllers: scrollControllers,
          itemCount: messageCount + 1,
          initialScrollIndex: messageCount,
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

      expect(chatScrollController.isNearBottom(), isTrue);
      expect(chatScrollController.autoStickToBottom, isTrue);

      chatScrollController.suspendAutoStickForUserInteraction();
      await tester.pump(const Duration(milliseconds: 1200));

      expect(chatScrollController.isNearBottom(), isTrue);
      expect(chatScrollController.autoStickToBottom, isFalse);

      chatScrollController.autoScrollToBottomIfNeeded();
      chatScrollController.followBottomAfterContentChange();
      await tester.pump();

      expect(chatScrollController.autoStickToBottom, isFalse);

      chatScrollController.dispose();
    });

    testWidgets('展开可见消息前会重锚点让内容向下展开', (tester) async {
      const messageCount = 2;
      const bottomAnchorHeight = 120.0;
      final bottomAnchorAlignment = 1 - bottomAnchorHeight / _harnessHeight;
      var assistantHeight = 420.0;
      final scrollControllers = ChatIndexedScrollControllers();
      final chatScrollController = ChatScrollController(
        indexedControllers: scrollControllers,
        onStateChanged: () {},
        getShouldAutoStickToBottom: () => true,
        getAutoScrollEnabled: () => true,
        getItemCount: () => messageCount,
        getBottomAnchorAlignment: () => bottomAnchorAlignment,
      );

      Widget buildHarness() {
        return _IndexedScrollHarness(
          scrollControllers: scrollControllers,
          itemCount: messageCount + 1,
          initialScrollIndex: messageCount,
          initialAlignment: bottomAnchorAlignment,
          itemBuilder: (context, index) {
            if (index == 0) {
              return const SizedBox(height: 80, child: Text('User'));
            }
            if (index == 1) {
              return SizedBox(
                height: assistantHeight,
                child: const Text('Assistant'),
              );
            }
            return const SizedBox(height: bottomAnchorHeight);
          },
        );
      }

      await tester.pumpWidget(buildHarness());
      await tester.pump();

      final before = _positionFor(scrollControllers, 1).itemLeadingEdge;
      chatScrollController.suspendAutoStickForUserInteraction(anchorIndex: 1);
      assistantHeight = 820.0;
      await tester.pumpWidget(buildHarness());
      await tester.pump();

      final after = _positionFor(scrollControllers, 1).itemLeadingEdge;
      expect(after, closeTo(before, 0.03));

      chatScrollController.dispose();
    });

    testWidgets('展开顶部在屏幕外的长消息不会跳回消息顶部', (tester) async {
      const messageCount = 2;
      const bottomAnchorHeight = 120.0;
      final scrollControllers = ChatIndexedScrollControllers();
      final chatScrollController = ChatScrollController(
        indexedControllers: scrollControllers,
        onStateChanged: () {},
        getShouldAutoStickToBottom: () => true,
        getAutoScrollEnabled: () => true,
        getItemCount: () => messageCount,
        getBottomAnchorAlignment: () => 1,
      );

      await tester.pumpWidget(
        _IndexedScrollHarness(
          scrollControllers: scrollControllers,
          itemCount: messageCount + 1,
          initialScrollIndex: 1,
          itemBuilder: (context, index) {
            if (index == 0) {
              return const SizedBox(height: 80, child: Text('User'));
            }
            if (index == 1) {
              return const SizedBox(
                height: 1800,
                child: Text('Long assistant'),
              );
            }
            return const SizedBox(height: bottomAnchorHeight);
          },
        ),
      );
      await tester.pump();

      await tester.drag(
        find.byType(ScrollablePositionedList),
        const Offset(0, -360),
      );
      await tester.pump();
      final before = _positionFor(scrollControllers, 1).itemLeadingEdge;
      expect(before, lessThan(0));

      chatScrollController.suspendAutoStickForUserInteraction(anchorIndex: 1);
      await tester.pump();

      final after = _positionFor(scrollControllers, 1).itemLeadingEdge;
      expect(after, closeTo(before, 0.03));

      chatScrollController.dispose();
    });

    testWidgets('长助手消息重试收缩后用户消息保持在顶部', (tester) async {
      const messageCount = 2;
      const bottomAnchorHeight = 120.0;
      final bottomAnchorAlignment = 1 - bottomAnchorHeight / _harnessHeight;
      var assistantHeight = 1800.0;
      final scrollControllers = ChatIndexedScrollControllers();
      final chatScrollController = ChatScrollController(
        indexedControllers: scrollControllers,
        onStateChanged: () {},
        getShouldAutoStickToBottom: () => true,
        getAutoScrollEnabled: () => true,
        getItemCount: () => messageCount,
        getBottomAnchorAlignment: () => bottomAnchorAlignment,
      );

      Widget buildHarness() {
        return _IndexedScrollHarness(
          scrollControllers: scrollControllers,
          itemCount: messageCount + 1,
          initialScrollIndex: messageCount,
          initialAlignment: bottomAnchorAlignment,
          itemBuilder: (context, index) {
            if (index == 0) {
              return const SizedBox(height: 80, child: Text('User'));
            }
            if (index == 1) {
              return SizedBox(
                height: assistantHeight,
                child: const Text('Assistant'),
              );
            }
            return const SizedBox(height: bottomAnchorHeight);
          },
        );
      }

      await tester.pumpWidget(buildHarness());
      await tester.pump();

      chatScrollController.suspendAutoStickForUserInteraction(
        anchorIndex: 0,
        anchorAlignment: 0,
      );
      assistantHeight = 80.0;
      chatScrollController.followBottomAfterContentChange();
      await tester.pumpWidget(buildHarness());
      await tester.pump();

      final userPosition = _positionFor(scrollControllers, 0);
      expect(userPosition.itemLeadingEdge, closeTo(0, 0.03));

      chatScrollController.dispose();
    });

    testWidgets('用户滚动意图会取消待执行的普通延迟滚底', (tester) async {
      const messageCount = 120;
      const bottomAnchorHeight = 120.0;
      final bottomAnchorAlignment = 1 - bottomAnchorHeight / _harnessHeight;
      final scrollControllers = ChatIndexedScrollControllers();
      final chatScrollController = ChatScrollController(
        indexedControllers: scrollControllers,
        onStateChanged: () {},
        getShouldAutoStickToBottom: () => true,
        getAutoScrollEnabled: () => true,
        getItemCount: () => messageCount,
        getBottomAnchorAlignment: () => bottomAnchorAlignment,
      );

      await tester.pumpWidget(
        _IndexedScrollHarness(
          scrollControllers: scrollControllers,
          itemCount: messageCount + 1,
          initialScrollIndex: 40,
          itemBuilder: (context, index) {
            if (index == messageCount) {
              return const SizedBox(height: bottomAnchorHeight);
            }
            return SizedBox(height: 56, child: Text('Message $index'));
          },
        ),
      );
      await tester.pump();

      chatScrollController.scrollToBottomSoon(animate: false);
      chatScrollController.handleUserScrollIntent();
      await tester.pump(const Duration(milliseconds: 130));

      expect(chatScrollController.autoStickToBottom, isFalse);

      chatScrollController.dispose();
    });

    testWidgets('用户重新滚到底部后恢复流式自动贴底', (tester) async {
      const messageCount = 120;
      const bottomAnchorHeight = 120.0;
      final bottomAnchorAlignment = 1 - bottomAnchorHeight / _harnessHeight;
      final scrollControllers = ChatIndexedScrollControllers();
      final chatScrollController = ChatScrollController(
        indexedControllers: scrollControllers,
        onStateChanged: () {},
        getShouldAutoStickToBottom: () => true,
        getAutoScrollEnabled: () => true,
        getItemCount: () => messageCount,
        getBottomAnchorAlignment: () => bottomAnchorAlignment,
      );

      await tester.pumpWidget(
        _IndexedScrollHarness(
          scrollControllers: scrollControllers,
          itemCount: messageCount + 1,
          initialScrollIndex: messageCount,
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

      await tester.drag(
        find.byType(ScrollablePositionedList),
        const Offset(0, 360),
      );
      await tester.pump(const Duration(milliseconds: 240));
      expect(chatScrollController.autoStickToBottom, isFalse);

      chatScrollController.handleUserScrollIntent(
        ChatUserScrollIntentDirection.towardBottom,
      );
      await tester.drag(
        find.byType(ScrollablePositionedList),
        const Offset(0, -360),
      );
      await tester.pump(const Duration(milliseconds: 240));
      chatScrollController.handleUserScrollIntent(
        ChatUserScrollIntentDirection.towardBottom,
      );
      await tester.drag(
        find.byType(ScrollablePositionedList),
        const Offset(0, -360),
      );
      await tester.pump(const Duration(milliseconds: 240));

      expect(chatScrollController.isNearBottom(), isTrue);
      expect(chatScrollController.autoStickToBottom, isTrue);

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

    testWidgets('用户在短内容顶部拖动时顶部重对齐不会重新打开贴底', (tester) async {
      const messageCount = 1;
      const bottomAnchorHeight = 120.0;
      final scrollControllers = ChatIndexedScrollControllers();
      final chatScrollController = ChatScrollController(
        indexedControllers: scrollControllers,
        onStateChanged: () {},
        getShouldAutoStickToBottom: () => true,
        getAutoScrollEnabled: () => true,
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
            return const SizedBox(height: 56, child: Text('Message 0'));
          },
        ),
      );
      await tester.pump();

      chatScrollController.handleUserScrollIntent(
        ChatUserScrollIntentDirection.towardTop,
      );
      scrollControllers.itemScrollController.jumpTo(index: 0, alignment: 0.1);
      await tester.pump();
      await tester.pump();

      expect(chatScrollController.autoStickToBottom, isFalse);

      chatScrollController.dispose();
    });

    testWidgets('用户停在顶部附近后流式维护不会保留下拉空隙', (tester) async {
      const messageCount = 80;
      const bottomAnchorHeight = 120.0;
      final scrollControllers = ChatIndexedScrollControllers();
      late final ChatScrollController chatScrollController;
      chatScrollController = ChatScrollController(
        indexedControllers: scrollControllers,
        onStateChanged: () {},
        getShouldAutoStickToBottom: () {
          if (chatScrollController.isUserScrolling) return false;
          return chatScrollController.isNearBottom(48);
        },
        getAutoScrollEnabled: () => true,
        getItemCount: () => messageCount,
        getBottomAnchorAlignment: () => 1 - bottomAnchorHeight / _harnessHeight,
      );

      await tester.pumpWidget(
        _IndexedScrollHarness(
          scrollControllers: scrollControllers,
          itemCount: messageCount + 1,
          initialScrollIndex: messageCount,
          itemBuilder: (context, index) {
            if (index == messageCount) {
              return const SizedBox(height: bottomAnchorHeight);
            }
            return SizedBox(height: 72, child: Text('Message $index'));
          },
        ),
      );
      await tester.pump();

      chatScrollController.handleUserScrollIntent(
        ChatUserScrollIntentDirection.towardTop,
      );
      scrollControllers.itemScrollController.jumpTo(index: 0, alignment: 0.12);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 240));

      chatScrollController.autoScrollToBottomIfNeeded();
      await tester.pump();
      await tester.pump();

      final firstMessage = _positionFor(scrollControllers, 0);
      expect(firstMessage.itemLeadingEdge, closeTo(0, 0.02));
      expect(chatScrollController.autoStickToBottom, isFalse);

      chatScrollController.dispose();
    });

    testWidgets('首条消息内容变高先触发内容跟随后仍继续自动贴底', (tester) async {
      const messageCount = 1;
      const bottomAnchorHeight = 120.0;
      final bottomAnchorAlignment = 1 - bottomAnchorHeight / _harnessHeight;
      var messageHeight = 240.0;
      final scrollControllers = ChatIndexedScrollControllers();
      late final ChatScrollController chatScrollController;
      chatScrollController = ChatScrollController(
        indexedControllers: scrollControllers,
        onStateChanged: () {},
        getShouldAutoStickToBottom: () {
          if (chatScrollController.isUserScrolling) return false;
          if (!chatScrollController.hasEnoughContentToScroll(56.0)) {
            return true;
          }
          return chatScrollController.isNearBottom(48);
        },
        getAutoScrollEnabled: () => true,
        getItemCount: () => messageCount,
        getBottomAnchorAlignment: () => bottomAnchorAlignment,
      );

      Widget buildHarness() {
        return _IndexedScrollHarness(
          scrollControllers: scrollControllers,
          itemCount: messageCount + 1,
          initialScrollIndex: messageCount,
          initialAlignment: bottomAnchorAlignment,
          itemBuilder: (context, index) {
            if (index == messageCount) {
              return const SizedBox(height: bottomAnchorHeight);
            }
            return SizedBox(
              height: messageHeight,
              child: const Text('Message'),
            );
          },
        );
      }

      await tester.pumpWidget(buildHarness());
      await tester.pump();
      expect(chatScrollController.isNearBottom(), isTrue);
      expect(chatScrollController.autoStickToBottom, isTrue);

      messageHeight = 900.0;
      await tester.pumpWidget(buildHarness());
      await tester.pump();

      chatScrollController.followBottomAfterContentChange();
      chatScrollController.autoScrollToBottomIfNeeded();
      for (var i = 0; i < 8; i++) {
        await tester.pump();
      }

      final anchor = _positionFor(scrollControllers, messageCount);
      expect(anchor.itemTrailingEdge, closeTo(1, 0.02));
      expect(chatScrollController.autoStickToBottom, isTrue);

      chatScrollController.dispose();
    });

    testWidgets('流式 tick 早于本帧布局时仍会滚到新内容底部', (tester) async {
      const messageCount = 1;
      const bottomAnchorHeight = 120.0;
      final bottomAnchorAlignment = 1 - bottomAnchorHeight / _harnessHeight;
      var messageHeight = 240.0;
      final scrollControllers = ChatIndexedScrollControllers();
      final chatScrollController = ChatScrollController(
        indexedControllers: scrollControllers,
        onStateChanged: () {},
        getShouldAutoStickToBottom: () => true,
        getAutoScrollEnabled: () => true,
        getItemCount: () => messageCount,
        getBottomAnchorAlignment: () => bottomAnchorAlignment,
      );

      Widget buildHarness() {
        return _IndexedScrollHarness(
          scrollControllers: scrollControllers,
          itemCount: messageCount + 1,
          initialScrollIndex: messageCount,
          initialAlignment: bottomAnchorAlignment,
          itemBuilder: (context, index) {
            if (index == messageCount) {
              return const SizedBox(height: bottomAnchorHeight);
            }
            return SizedBox(
              height: messageHeight,
              child: const Text('Message'),
            );
          },
        );
      }

      await tester.pumpWidget(buildHarness());
      await tester.pump();
      expect(chatScrollController.autoStickToBottom, isTrue);

      messageHeight = 900.0;
      chatScrollController.autoScrollToBottomIfNeeded();
      await tester.pumpWidget(buildHarness());
      await tester.pump();
      await tester.pump();
      await tester.pump();

      final anchor = _positionFor(scrollControllers, messageCount);
      expect(anchor.itemTrailingEdge, closeTo(1, 0.02));

      chatScrollController.dispose();
    });

    testWidgets('首条流式从不满一屏跨到超出一屏时继续贴底', (tester) async {
      const messageCount = 1;
      const bottomAnchorHeight = 120.0;
      final bottomAnchorAlignment = 1 - bottomAnchorHeight / _harnessHeight;
      var messageHeight = 240.0;
      final scrollControllers = ChatIndexedScrollControllers();
      final chatScrollController = ChatScrollController(
        indexedControllers: scrollControllers,
        onStateChanged: () {},
        getShouldAutoStickToBottom: () => true,
        getAutoScrollEnabled: () => true,
        getItemCount: () => messageCount,
        getBottomAnchorAlignment: () => bottomAnchorAlignment,
      );

      Widget buildHarness() {
        return _IndexedScrollHarness(
          scrollControllers: scrollControllers,
          itemCount: messageCount + 1,
          initialScrollIndex: messageCount,
          initialAlignment: bottomAnchorAlignment,
          itemBuilder: (context, index) {
            if (index == messageCount) {
              return const SizedBox(height: bottomAnchorHeight);
            }
            return SizedBox(
              height: messageHeight,
              child: const Text('Message'),
            );
          },
        );
      }

      await tester.pumpWidget(buildHarness());
      await tester.pump();
      expect(chatScrollController.autoStickToBottom, isTrue);

      messageHeight = 520.0;
      chatScrollController.autoScrollToBottomIfNeeded();
      await tester.pumpWidget(buildHarness());
      await tester.pump();

      messageHeight = 900.0;
      chatScrollController.autoScrollToBottomIfNeeded();
      await tester.pumpWidget(buildHarness());
      for (var i = 0; i < 8; i++) {
        await tester.pump();
      }

      final anchor = _positionFor(scrollControllers, messageCount);
      expect(anchor.itemTrailingEdge, closeTo(1, 0.02));
      expect(chatScrollController.autoStickToBottom, isTrue);

      chatScrollController.dispose();
    });

    testWidgets('首个用户消息后的短流式回复保持顶部超出一屏后才贴底', (tester) async {
      const messageCount = 2;
      const bottomAnchorHeight = 120.0;
      final bottomAnchorAlignment = 1 - bottomAnchorHeight / _harnessHeight;
      var assistantHeight = 120.0;
      final scrollControllers = ChatIndexedScrollControllers();
      final chatScrollController = ChatScrollController(
        indexedControllers: scrollControllers,
        onStateChanged: () {},
        getShouldAutoStickToBottom: () => true,
        getAutoScrollEnabled: () => true,
        getItemCount: () => messageCount,
        getBottomAnchorAlignment: () => bottomAnchorAlignment,
      );

      Widget buildHarness() {
        return _IndexedScrollHarness(
          scrollControllers: scrollControllers,
          itemCount: messageCount + 1,
          initialScrollIndex: 0,
          itemBuilder: (context, index) {
            if (index == 0) {
              return const SizedBox(height: 96, child: Text('User message'));
            }
            if (index == 1) {
              return SizedBox(
                height: assistantHeight,
                child: const Text('Assistant message'),
              );
            }
            return const SizedBox(height: bottomAnchorHeight);
          },
        );
      }

      await tester.pumpWidget(buildHarness());
      await tester.pump();
      expect(
        _positionFor(scrollControllers, 0).itemLeadingEdge,
        closeTo(0, 0.02),
      );

      chatScrollController.autoScrollToBottomIfNeeded();
      for (var i = 0; i < 4; i++) {
        await tester.pump();
      }

      expect(
        _positionFor(scrollControllers, 0).itemLeadingEdge,
        closeTo(0, 0.02),
      );

      assistantHeight = 900.0;
      chatScrollController.autoScrollToBottomIfNeeded();
      await tester.pumpWidget(buildHarness());
      for (var i = 0; i < 8; i++) {
        await tester.pump();
      }

      final anchor = _positionFor(scrollControllers, messageCount);
      expect(anchor.itemTrailingEdge, closeTo(1, 0.02));
      expect(chatScrollController.autoStickToBottom, isTrue);

      chatScrollController.dispose();
    });

    testWidgets('关闭自动贴底后内容变化不会自动滚到底部', (tester) async {
      var messageCount = 0;
      var messageHeight = 56.0;
      const bottomAnchorHeight = 120.0;
      final bottomAnchorAlignment = 1 - bottomAnchorHeight / _harnessHeight;
      final scrollControllers = ChatIndexedScrollControllers();
      final chatScrollController = ChatScrollController(
        indexedControllers: scrollControllers,
        onStateChanged: () {},
        getShouldAutoStickToBottom: () => true,
        getAutoScrollEnabled: () => false,
        getItemCount: () => messageCount,
        getBottomAnchorAlignment: () => bottomAnchorAlignment,
      );

      Widget buildHarness() {
        return _IndexedScrollHarness(
          scrollControllers: scrollControllers,
          itemCount: messageCount + 1,
          initialAlignment: bottomAnchorAlignment,
          itemBuilder: (context, index) {
            if (index == messageCount) {
              return const SizedBox(height: bottomAnchorHeight);
            }
            return SizedBox(
              height: messageHeight,
              child: const Text('Message'),
            );
          },
        );
      }

      await tester.pumpWidget(buildHarness());
      await tester.pump();

      messageCount = 1;
      messageHeight = 900.0;
      chatScrollController.followBottomAfterContentChange();
      await tester.pumpWidget(buildHarness());
      await tester.pump();
      await tester.pump();

      final message = _positionFor(scrollControllers, 0);
      expect(message.itemLeadingEdge, closeTo(0, 0.02));
      expect(chatScrollController.autoStickToBottom, isFalse);

      chatScrollController.dispose();
    });

    testWidgets('真实拖动到底部后会恢复流式自动贴底', (tester) async {
      const messageCount = 120;
      const bottomAnchorHeight = 120.0;
      final bottomAnchorAlignment = 1 - bottomAnchorHeight / _harnessHeight;
      final scrollControllers = ChatIndexedScrollControllers();
      late final ChatScrollController chatScrollController;
      chatScrollController = ChatScrollController(
        indexedControllers: scrollControllers,
        onStateChanged: () {},
        getShouldAutoStickToBottom: () => true,
        getAutoScrollEnabled: () => true,
        getItemCount: () => messageCount,
        getBottomAnchorAlignment: () => bottomAnchorAlignment,
      );

      await tester.pumpWidget(
        _IndexedScrollHarness(
          scrollControllers: scrollControllers,
          itemCount: messageCount + 1,
          initialScrollIndex: messageCount,
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
      expect(chatScrollController.autoStickToBottom, isTrue);

      await tester.drag(
        find.byType(ScrollablePositionedList),
        const Offset(0, 360),
      );
      await tester.pump(const Duration(milliseconds: 240));
      expect(chatScrollController.autoStickToBottom, isFalse);

      for (var i = 0; i < 3; i++) {
        chatScrollController.handleUserScrollIntent(
          ChatUserScrollIntentDirection.towardBottom,
        );
        await tester.drag(
          find.byType(ScrollablePositionedList),
          const Offset(0, -360),
        );
        await tester.pump(const Duration(milliseconds: 240));
      }

      expect(chatScrollController.isNearBottom(), isTrue);
      expect(chatScrollController.autoStickToBottom, isTrue);

      chatScrollController.dispose();
    });

    testWidgets('点到底部后用户上滑会停止后续流式贴底', (tester) async {
      const messageCount = 12;
      const bottomAnchorHeight = 120.0;
      final bottomAnchorAlignment = 1 - bottomAnchorHeight / _harnessHeight;
      var lastMessageHeight = 120.0;
      final scrollControllers = ChatIndexedScrollControllers();
      final chatScrollController = ChatScrollController(
        indexedControllers: scrollControllers,
        onStateChanged: () {},
        getShouldAutoStickToBottom: () => true,
        getAutoScrollEnabled: () => true,
        getItemCount: () => messageCount,
        getBottomAnchorAlignment: () => bottomAnchorAlignment,
      );

      Widget buildHarness() {
        return _IndexedScrollHarness(
          scrollControllers: scrollControllers,
          itemCount: messageCount + 1,
          initialScrollIndex: 0,
          itemBuilder: (context, index) {
            if (index == messageCount) {
              return const SizedBox(height: bottomAnchorHeight);
            }
            final height = index == messageCount - 1
                ? lastMessageHeight
                : 120.0;
            return SizedBox(height: height, child: Text('Message $index'));
          },
        );
      }

      await tester.pumpWidget(buildHarness());
      await tester.pump();

      chatScrollController.forceScrollToBottom();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 280));
      expect(chatScrollController.isNearBottom(), isTrue);

      chatScrollController.handleUserScrollIntent();
      await tester.drag(
        find.byType(ScrollablePositionedList),
        const Offset(0, 180),
      );
      await tester.pump(const Duration(milliseconds: 240));
      expect(chatScrollController.autoStickToBottom, isFalse);

      lastMessageHeight = 480.0;
      await tester.pumpWidget(buildHarness());
      await tester.pump();
      chatScrollController.autoScrollToBottomIfNeeded();
      chatScrollController.followBottomAfterContentChange();
      await tester.pump();
      await tester.pump();

      expect(chatScrollController.autoStickToBottom, isFalse);
      expect(chatScrollController.isNearBottom(), isFalse);

      chatScrollController.dispose();
    });

    testWidgets('用户上滑阅读流式助手消息时新增内容不会持续推走当前阅读行', (tester) async {
      const messageCount = 2;
      const bottomAnchorHeight = 120.0;
      final bottomAnchorAlignment = 1 - bottomAnchorHeight / _harnessHeight;
      var streamingLineCount = 28;
      final scrollControllers = ChatIndexedScrollControllers();
      late final ChatScrollController chatScrollController;
      chatScrollController = ChatScrollController(
        indexedControllers: scrollControllers,
        onStateChanged: () {},
        getShouldAutoStickToBottom: () {
          if (chatScrollController.isUserScrolling) return false;
          if (!chatScrollController.hasEnoughContentToScroll(56.0)) {
            return true;
          }
          return chatScrollController.isNearBottom(48);
        },
        getAutoScrollEnabled: () => true,
        getItemCount: () => messageCount,
        getBottomAnchorAlignment: () => bottomAnchorAlignment,
      );

      Widget buildHarness() {
        return _IndexedScrollHarness(
          scrollControllers: scrollControllers,
          itemCount: messageCount + 1,
          initialScrollIndex: messageCount,
          initialAlignment: bottomAnchorAlignment,
          itemBuilder: (context, index) {
            if (index == 0) {
              return const SizedBox(height: 96, child: Text('User message'));
            }
            if (index == 1) {
              return Column(
                children: [
                  for (var line = 0; line < streamingLineCount; line++)
                    SizedBox(
                      key: ValueKey('streaming-line-$line'),
                      height: 40,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text('Streaming line $line'),
                      ),
                    ),
                ],
              );
            }
            return const SizedBox(height: bottomAnchorHeight);
          },
        );
      }

      await tester.pumpWidget(buildHarness());
      await tester.pump();
      expect(chatScrollController.isNearBottom(), isTrue);

      await tester.drag(
        find.byType(ScrollablePositionedList),
        const Offset(0, 320),
      );
      await tester.pump(const Duration(milliseconds: 240));
      expect(chatScrollController.autoStickToBottom, isFalse);

      final anchorFinder = find.byKey(const ValueKey('streaming-line-16'));
      expect(anchorFinder, findsOneWidget);
      final beforeTop = tester.getTopLeft(anchorFinder).dy;

      for (var step = 0; step < 4; step++) {
        streamingLineCount += 8;
        await tester.pumpWidget(buildHarness());
        chatScrollController.autoScrollToBottomIfNeeded();
        await tester.pump();
        await tester.pump();
      }

      expect(tester.getTopLeft(anchorFinder).dy, closeTo(beforeTop, 2.0));
      expect(chatScrollController.autoStickToBottom, isFalse);

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

ItemPosition _positionFor(
  ChatIndexedScrollControllers scrollControllers,
  int index,
) {
  return scrollControllers.itemPositionsListener.itemPositions.value.firstWhere(
    (position) => position.index == index,
  );
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
