import "../../../support/business_test_harness.dart";
import 'package:flutter_test/flutter_test.dart';
import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/chat/chat_service.dart';
import 'package:Kelivo/features/home/controllers/stream_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues(const {});

  StreamController buildController({
    SettingsProvider? settings,
    String? currentConversationId,
    void Function()? onStreamTick,
  }) {
    final settingsProvider =
        settings ?? SettingsProvider(createBusinessTestPreferences());
    return StreamController(
      chatService: ChatService(),
      onStateChanged: () {},
      getSettingsProvider: () => settingsProvider,
      getCurrentConversationId: () => currentConversationId,
      onStreamTick: onStreamTick,
    );
  }

  StreamingState buildStreamingState(SettingsProvider settings) {
    final message = ChatMessage(
      id: 'assistant-message',
      role: 'assistant',
      content: '',
      conversationId: 'conversation-1',
      isStreaming: true,
    );
    return StreamingState(
      GenerationContext(
        assistantMessage: message,
        apiMessages: const [],
        userImagePaths: const [],
        allowImagesApiRouting: false,
        providerKey: 'test',
        modelId: 'test-model',
        assistant: null,
        settings: settings,
        config: ProviderConfig(
          id: 'test',
          enabled: true,
          name: 'Test',
          apiKey: '',
          baseUrl: '',
        ),
        toolDefs: const [],
        supportsReasoning: true,
        enableReasoning: true,
        streamOutput: true,
      ),
    );
  }

  testWidgets(
    'reasoning chunks coalesce into one notifier update per 50ms tick',
    (tester) async {
      final settings = SettingsProvider(createBusinessTestPreferences());
      var tickCount = 0;
      final controller = buildController(
        settings: settings,
        currentConversationId: 'conversation-1',
        onStreamTick: () => tickCount++,
      );
      final state = buildStreamingState(settings);
      controller.markStreamingStarted(state.messageId);
      final notifier = controller.streamingContentNotifier.getNotifier(
        state.messageId,
      );
      var notifyCount = 0;
      notifier.addListener(() => notifyCount++);

      for (var i = 0; i < 5; i++) {
        await controller.handleReasoningChunk('${i + 1}', state);
      }

      expect(notifyCount, 0);
      expect(notifier.value.reasoningText, isNull);
      expect(tickCount, 0);

      await tester.pump(const Duration(milliseconds: 50));

      expect(notifyCount, 1);
      expect(notifier.value.reasoningText, '12345');
      expect(tickCount, 1);
      controller.dispose();
    },
  );
}
