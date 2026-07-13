import 'package:Kelivo/features/home/controllers/scroll_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scrollview_observer/scrollview_observer.dart';

void main() {
  group('ChatScrollController streaming auto-follow', () {
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

      chatScrollController.forceScrollToBottom();
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
    testWidgets('collapsed target index scrolls through the observer', (
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
        _ObservedScrollHarness(
          scrollController: scrollController,
          observerController: chatScrollController.observerController,
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

    testWidgets('上一条消息在没有观察回调时仍以当前可见项为锚点', (tester) async {
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
        _ObservedScrollHarness(
          scrollController: scrollController,
          observerController: chatScrollController.observerController,
          messages: messages,
        ),
      );
      scrollController.jumpTo(900);
      await tester.pump();

      final navigation = chatScrollController.jumpToPreviousQuestion(
        messages: messages,
        indexOfId: (id) => messages.indexWhere((message) => message.id == id),
      );
      await tester.pumpAndSettle();
      final moved = await navigation;

      expect(moved, isTrue);
      expect(chatScrollController.lastJumpUserMessageId, 'message-15');

      chatScrollController.dispose();
      scrollController.dispose();
    });

    testWidgets('下一条消息在没有观察回调时仍以当前可见项为锚点', (tester) async {
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
        _ObservedScrollHarness(
          scrollController: scrollController,
          observerController: chatScrollController.observerController,
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
      expect(chatScrollController.lastJumpUserMessageId, 'message-15');

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

class _ObservedScrollHarness extends StatelessWidget {
  const _ObservedScrollHarness({
    required this.scrollController,
    required this.observerController,
    required this.messages,
  });

  final ScrollController scrollController;
  final ListObserverController observerController;
  final List<_NavMessage> messages;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: SizedBox(
        height: 600,
        child: ListViewObserver(
          controller: observerController,
          child: ListView.builder(
            controller: scrollController,
            itemCount: messages.length,
            itemBuilder: (context, index) {
              final message = messages[index];
              return SizedBox(
                height: 80,
                child: Text('${message.role} ${message.id}'),
              );
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
