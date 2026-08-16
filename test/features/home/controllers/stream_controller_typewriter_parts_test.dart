import "../../../support/business_test_harness.dart";
import 'package:Kelivo/core/models/message_part.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/chat/chat_service.dart';
import 'package:Kelivo/features/home/controllers/chat_actions.dart';
import 'package:Kelivo/features/home/controllers/stream_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues(const {});

  const messageId = 'assistant-message';
  const fullText = 'Hello world, this is a long enough burst for smoothing.';

  StreamController buildController(SettingsProvider settings) {
    return StreamController(
      chatService: ChatService(),
      onStateChanged: () {},
      getSettingsProvider: () => settings,
      getCurrentConversationId: () => 'conversation-1',
    );
  }

  testWidgets('throttled parts follow the visible slice, then flush complete', (
    tester,
  ) async {
    final settings = SettingsProvider(createBusinessTestPreferences());
    final controller = buildController(settings);
    final notifier = controller.streamingContentNotifier.getNotifier(messageId);
    final fullParts = <MessagePart>[
      const TextPart(fullText),
      const ReasoningPart('plan'),
    ];

    controller.scheduleThrottledUpdate(
      messageId,
      'conversation-1',
      () => fullText,
      partsBuilder: (visibleText) => ChatActions.assistantPartsForVisibleText(
        parts: fullParts,
        visibleText: visibleText,
      ),
      updateMessageInList: (_, _, _) {},
      totalTokens: 10,
    );

    await tester.pump(const Duration(milliseconds: 50));
    final mid = notifier.value;
    expect(mid.content.length, lessThan(fullText.length));
    expect(mid.parts, isNotNull);
    expect((mid.parts!.first as TextPart).text, mid.content);
    expect(mid.parts!.whereType<ReasoningPart>().single.text, 'plan');

    final drain = controller.drainSmoothStream(messageId);
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    await drain;
    controller.cleanupTimers(messageId);
    final end = notifier.value;
    expect(end.content, fullText);
    expect((end.parts!.first as TextPart).text, fullText);
    expect(end.parts!.whereType<ReasoningPart>().single.text, 'plan');
    controller.dispose();
  });
}
