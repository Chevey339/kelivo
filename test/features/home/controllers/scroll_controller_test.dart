import 'package:Kelivo/features/home/controllers/scroll_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ChatScrollController streaming auto-follow', () {
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
