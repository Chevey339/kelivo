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

  testWidgets('stream UI output is buffered until the smooth ticker fires', (
    tester,
  ) async {
    final settings = SettingsProvider();
    final updates = <String>[];
    var listUpdateCount = 0;
    var tickCount = 0;
    final smoothController = StreamController(
      chatService: ChatService(),
      onStateChanged: () {},
      getSettingsProvider: () => settings,
      getCurrentConversationId: () => 'conversation-1',
      onStreamTick: () => tickCount++,
    );

    smoothController.markStreamingStarted('assistant-message');
    smoothController.streamingContentNotifier
        .getNotifier('assistant-message')
        .addListener(() {
          updates.add(
            smoothController.streamingContentNotifier
                .getNotifier('assistant-message')
                .value
                .content,
          );
        });

    smoothController.scheduleThrottledUpdate(
      'assistant-message',
      'conversation-1',
      'abcdefghijklmnopqrstuvwxyz',
      totalTokens: 26,
      updateMessageInList: (_, __, ___) => listUpdateCount++,
    );

    expect(updates, isEmpty);
    expect(listUpdateCount, 0);

    await tester.pump(const Duration(milliseconds: 50));

    expect(updates, hasLength(1));
    expect(updates.single, isNot('abcdefghijklmnopqrstuvwxyz'));
    expect(updates.single.length, greaterThanOrEqualTo(2));
    expect(listUpdateCount, 1);
    expect(tickCount, 1);
    smoothController.dispose();
  });

  testWidgets('stream UI output adapts pick count to large backlog', (
    tester,
  ) async {
    final settings = SettingsProvider();
    final smoothController = StreamController(
      chatService: ChatService(),
      onStateChanged: () {},
      getSettingsProvider: () => settings,
      getCurrentConversationId: () => 'conversation-1',
    );

    final contents = <String>[];
    smoothController.markStreamingStarted('assistant-message');
    smoothController.streamingContentNotifier
        .getNotifier('assistant-message')
        .addListener(() {
          contents.add(
            smoothController.streamingContentNotifier
                .getNotifier('assistant-message')
                .value
                .content,
          );
        });

    smoothController.scheduleThrottledUpdate(
      'assistant-message',
      'conversation-1',
      'a' * 320,
      totalTokens: 320,
      updateMessageInList: (_, __, ___) {},
    );

    await tester.pump(const Duration(milliseconds: 50));

    expect(contents, hasLength(1));
    expect(contents.single.length, greaterThan(40));
    expect(contents.single.length, lessThan(320));
    smoothController.dispose();
  });

  testWidgets('stream UI output does not repeat an unchanged full frame', (
    tester,
  ) async {
    final settings = SettingsProvider();
    final smoothController = StreamController(
      chatService: ChatService(),
      onStateChanged: () {},
      getSettingsProvider: () => settings,
      getCurrentConversationId: () => 'conversation-1',
    );

    final contents = <String>[];
    smoothController.markStreamingStarted('assistant-message');
    smoothController.streamingContentNotifier
        .getNotifier('assistant-message')
        .addListener(() {
          contents.add(
            smoothController.streamingContentNotifier
                .getNotifier('assistant-message')
                .value
                .content,
          );
        });

    smoothController.scheduleThrottledUpdate(
      'assistant-message',
      'conversation-1',
      'ok',
      totalTokens: 2,
      updateMessageInList: (_, __, ___) {},
    );

    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 50));

    expect(contents, const ['ok']);
    smoothController.dispose();
  });

  testWidgets('cleanup flushes final stream content immediately', (
    tester,
  ) async {
    final settings = SettingsProvider();
    final smoothController = StreamController(
      chatService: ChatService(),
      onStateChanged: () {},
      getSettingsProvider: () => settings,
      getCurrentConversationId: () => 'conversation-1',
    );

    String? latestContent;
    int latestTokens = 0;
    var listUpdateCount = 0;

    smoothController.markStreamingStarted('assistant-message');
    smoothController.streamingContentNotifier
        .getNotifier('assistant-message')
        .addListener(() {
          final data = smoothController.streamingContentNotifier
              .getNotifier('assistant-message')
              .value;
          latestContent = data.content;
          latestTokens = data.totalTokens;
        });

    smoothController.scheduleThrottledUpdate(
      'assistant-message',
      'conversation-1',
      'final answer',
      totalTokens: 11,
      updateMessageInList: (_, __, ___) => listUpdateCount++,
    );

    smoothController.cleanupTimers('assistant-message');
    await tester.pump(const Duration(milliseconds: 200));

    expect(latestContent, 'final answer');
    expect(latestTokens, 11);
    expect(listUpdateCount, 1);
    smoothController.dispose();
  });

  testWidgets('cleanup flushes pending content into the list callback', (
    tester,
  ) async {
    final settings = SettingsProvider();
    final smoothController = StreamController(
      chatService: ChatService(),
      onStateChanged: () {},
      getSettingsProvider: () => settings,
      getCurrentConversationId: () => 'conversation-1',
    );

    String listContent = '';
    smoothController.markStreamingStarted('assistant-message');
    smoothController.scheduleThrottledUpdate(
      'assistant-message',
      'conversation-1',
      'visible after cancel',
      totalTokens: 18,
      updateMessageInList: (_, content, ___) => listContent = content,
    );

    smoothController.cleanupTimers('assistant-message');
    await tester.pump(const Duration(milliseconds: 200));

    expect(listContent, 'visible after cancel');
    smoothController.dispose();
  });
}
