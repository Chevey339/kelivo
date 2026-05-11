import 'package:flutter_test/flutter_test.dart';
import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/api/chat_api_service.dart';
import 'package:Kelivo/core/services/chat/chat_service.dart';
import 'package:Kelivo/features/home/controllers/stream_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _waitForSettingsLoad() async {
  for (var i = 0; i < 25; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues(const {});

  StreamController buildController({SettingsProvider? settings}) {
    final settingsProvider = settings ?? SettingsProvider();
    return StreamController(
      chatService: ChatService(),
      onStateChanged: () {},
      getSettingsProvider: () => settingsProvider,
      getCurrentConversationId: () => null,
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

  StreamingState buildStreamingStateWithContent(
    SettingsProvider settings,
    String content,
  ) {
    final message = ChatMessage(
      id: 'assistant-message',
      role: 'assistant',
      content: content,
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

  test('v2 reasoning payload preserves content split metadata', () {
    final controller = buildController();
    final segment = ReasoningSegmentData()
      ..text = 'thinking'
      ..expanded = false
      ..toolStartIndex = 0;

    final json = controller.serializeReasoningSegmentsWithSplits(
      [segment],
      contentSplitOffsets: const [12],
      reasoningCountAtSplit: const [1],
      toolCountAtSplit: const [2],
    );

    final restoredSegments = controller.deserializeReasoningSegments(json);
    final restoredSplits = controller.deserializeContentSplits(json);

    expect(restoredSegments, hasLength(1));
    expect(restoredSegments.single.text, 'thinking');
    expect(restoredSplits, isNotNull);
    expect(restoredSplits!.offsets, const [12]);
    expect(restoredSplits.reasoningCounts, const [1]);
    expect(restoredSplits.toolCounts, const [2]);
  });

  test('v1 reasoning payload remains compatible without content splits', () {
    final controller = buildController();
    final segment = ReasoningSegmentData()
      ..text = 'legacy'
      ..expanded = true
      ..toolStartIndex = 0;

    final json = controller.serializeReasoningSegments([segment]);

    expect(controller.deserializeReasoningSegments(json), hasLength(1));
    expect(controller.deserializeContentSplits(json), isNull);
  });

  test('StreamingState resumes from existing assistant content', () {
    final settings = SettingsProvider();
    final state = buildStreamingStateWithContent(settings, '先确认一下。');

    expect(state.fullContentRaw, '先确认一下。');
  });

  test(
    'finishReasoningAndPersist writes v2 payload for tool-only splits',
    () async {
      final controller = buildController();
      const messageId = 'assistant-message';
      controller.setContentSplitData(
        messageId,
        const ContentSplitData(
          offsets: [8],
          reasoningCounts: [0],
          toolCounts: [1],
        ),
      );

      String? persistedJson;
      await controller.finishReasoningAndPersist(
        messageId,
        updateReasoningInDb:
            (
              messageId, {
              String? reasoningText,
              DateTime? reasoningFinishedAt,
              String? reasoningSegmentsJson,
            }) async {
              expect(messageId, 'assistant-message');
              persistedJson = reasoningSegmentsJson ?? persistedJson;
            },
      );

      expect(persistedJson, isNotNull);
      expect(controller.deserializeReasoningSegments(persistedJson), isEmpty);
      final restoredSplits = controller.deserializeContentSplits(persistedJson);
      expect(restoredSplits, isNotNull);
      expect(restoredSplits!.toolCounts, const [1]);
    },
  );

  test('streaming reasoning honors disabled auto-collapse setting', () async {
    SharedPreferences.setMockInitialValues({
      'display_auto_collapse_thinking_v1': false,
    });
    final settings = SettingsProvider();
    await _waitForSettingsLoad();
    final controller = buildController(settings: settings);
    final state = buildStreamingState(settings);

    await controller.handleReasoningChunk(
      ChatStreamChunk(
        content: '',
        reasoning: 'thinking',
        isDone: false,
        totalTokens: 0,
      ),
      state,
      updateReasoningInDb:
          (
            messageId, {
            String? reasoningText,
            DateTime? reasoningStartAt,
            String? reasoningSegmentsJson,
          }) async {},
    );

    expect(
      controller.reasoningSegments[state.messageId]!.single.expanded,
      isTrue,
    );

    await controller.finishReasoningAndPersist(
      state.messageId,
      updateReasoningInDb:
          (
            messageId, {
            String? reasoningText,
            DateTime? reasoningFinishedAt,
            String? reasoningSegmentsJson,
          }) async {},
    );

    expect(
      controller.reasoningSegments[state.messageId]!.single.expanded,
      isTrue,
    );
  });

  test(
    'restoreMessageUiState restores tool parts and empty v2 split metadata',
    () {
      final controller = buildController();
      final message = ChatMessage(
        id: 'assistant-1',
        role: 'assistant',
        content: '让我帮你搜索一下',
        conversationId: 'conversation-1',
        reasoningSegmentsJson: controller.serializeReasoningSegmentsWithSplits(
          const [],
          contentSplitOffsets: const [],
          reasoningCountAtSplit: const [],
          toolCountAtSplit: const [],
        ),
      );

      controller.restoreMessageUiState(
        message,
        getToolEventsFromDb: (_) => const [
          {
            'id': 'tool-1',
            'name': 'search_web',
            'arguments': {'query': 'Kelivo'},
            'content': null,
          },
        ],
        getGeminiThoughtSigFromDb: (_) => null,
      );

      expect(controller.contentSplits[message.id], isNotNull);
      expect(controller.contentSplits[message.id]!.offsets, isEmpty);
      expect(controller.toolParts[message.id], hasLength(1));
      expect(controller.toolParts[message.id]!.single.loading, isTrue);
    },
  );

  test('stream throttle consumes each pending content once', () async {
    const conversationId = 'conversation-1';
    final controller = StreamController(
      chatService: ChatService(),
      onStateChanged: () {},
      getSettingsProvider: () => SettingsProvider(),
      getCurrentConversationId: () => conversationId,
    );
    addTearDown(controller.dispose);

    final valueListenable = controller.streamingContentNotifier.getNotifier(
      'assistant-1',
    );
    var notifyCount = 0;
    valueListenable.addListener(() {
      notifyCount++;
    });
    final applied = <String>[];

    controller.scheduleThrottledUpdate(
      'assistant-1',
      conversationId,
      'first chunk',
      updateMessageInList: (messageId, content, totalTokens) {
        applied.add(content);
      },
      totalTokens: 1,
    );

    await Future<void>.delayed(const Duration(milliseconds: 75));
    expect(notifyCount, 1);
    expect(applied, const <String>['first chunk']);
    expect(valueListenable.value.content, 'first chunk');

    await Future<void>.delayed(const Duration(milliseconds: 150));
    expect(notifyCount, 1);
    expect(applied, const <String>['first chunk']);

    controller.scheduleThrottledUpdate(
      'assistant-1',
      conversationId,
      'second chunk',
      updateMessageInList: (messageId, content, totalTokens) {
        applied.add(content);
      },
      totalTokens: 2,
    );

    await Future<void>.delayed(const Duration(milliseconds: 75));
    expect(notifyCount, 2);
    expect(applied, const <String>['first chunk', 'second chunk']);
    expect(valueListenable.value.content, 'second chunk');
    expect(valueListenable.value.totalTokens, 2);
  });
}
