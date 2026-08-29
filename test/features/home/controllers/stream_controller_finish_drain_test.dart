import "../../../support/business_test_harness.dart";
import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/features/home/controllers/stream_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues(const {});

  const messageId = 'assistant-message';

  StreamController buildController(SettingsProvider settings) {
    return StreamController(
      onStateChanged: () {},
      getSettingsProvider: () => settings,
      getCurrentConversationId: () => 'conversation-1',
    );
  }

  /// Feeds a burst the smoothing buffer cannot show in a single tick.
  void scheduleBurst(StreamController controller, String content) {
    controller.scheduleThrottledUpdate(
      messageId,
      'conversation-1',
      () => content,
      updateMessageInList: (_, _, _) {},
      totalTokens: 10,
    );
  }

  testWidgets('结束时先排空平滑缓冲，避免尾部一次性跳变', (tester) async {
    final settings = SettingsProvider(createBusinessTestPreferences());
    final controller = buildController(settings);
    final notifier = controller.streamingContentNotifier.getNotifier(messageId);
    final published = <int>[];
    notifier.addListener(() => published.add(notifier.value.content.length));

    final content = 'x' * 2000;
    scheduleBurst(controller, content);
    // A few ticks of a burst the smoother is still catching up with.
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 50));
    final backlogBeforeFinish = content.length - notifier.value.content.length;
    expect(
      backlogBeforeFinish,
      greaterThan(200),
      reason: 'the burst must still be buffered for this test to mean anything',
    );

    final drain = controller.drainSmoothStream(messageId);
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    await drain;
    final backlogAfterDrain = content.length - notifier.value.content.length;

    controller.cleanupTimers(messageId);
    final finalJump = content.length - (published..removeLast()).last;

    // Without the drain the whole backlog lands in the frame the reply ends,
    // which a bottom-pinned timeline shows as one large jump.
    expect(backlogAfterDrain, lessThan(backlogBeforeFinish));
    expect(finalJump, lessThan(backlogBeforeFinish));
    controller.dispose();
  });

  testWidgets('排空受时间预算约束，不会拖住结束流程', (tester) async {
    final settings = SettingsProvider(createBusinessTestPreferences());
    final controller = buildController(settings);
    controller.streamingContentNotifier.getNotifier(messageId);

    // Content that keeps outpacing the smoother for far longer than the budget.
    scheduleBurst(controller, 'x' * 400000);

    var completed = false;
    unawaited(
      controller
          .drainSmoothStream(
            messageId,
            budget: const Duration(milliseconds: 100),
          )
          .then((_) => completed = true),
    );
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(completed, isTrue);
    controller.dispose();
  });
}
