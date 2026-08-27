import 'dart:convert';

import "../../../support/business_test_harness.dart";
import 'package:flutter_test/flutter_test.dart';
import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/api/stream/stream_chunk.dart';
import 'package:Kelivo/core/services/chat/chat_service.dart';
import 'package:Kelivo/features/chat/widgets/chat_message_widget.dart'
    show ToolUIPart;
import 'package:Kelivo/features/home/controllers/stream_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues(const {});

  StreamController buildController({
    SettingsProvider? settings,
    String? currentConversationId,
  }) {
    final settingsProvider =
        settings ?? SettingsProvider(createBusinessTestPreferences());
    return StreamController(
      chatService: ChatService(),
      onStateChanged: () {},
      getSettingsProvider: () => settingsProvider,
      getCurrentConversationId: () => currentConversationId,
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

  test('segments plus reasoningDetails omit empty contentSplits', () {
    final controller = buildController();
    final segment = ReasoningSegmentData()
      ..text = 'openrouter thinking'
      ..expanded = true
      ..toolStartIndex = 0;

    final json = controller.serializeReasoningSegmentsWithSplits(
      [segment],
      reasoningDetails: const [
        {
          'id': 'rd_1',
          'type': 'reasoning.encrypted',
          'data': 'sig',
          'format': 'anthropic-claude-v1',
        },
      ],
    );

    final decoded = jsonDecode(json) as Map<String, dynamic>;
    expect(decoded.containsKey('contentSplits'), isFalse);
    expect(decoded['v'], 2);
    expect(decoded['reasoningDetails'], isNotEmpty);
    expect(controller.deserializeContentSplits(json), isNull);
    expect(
      controller.deserializeReasoningSegments(json).single.text,
      'openrouter thinking',
    );
    expect(controller.deserializeReasoningDetails(json), isNotEmpty);
  });

  test('empty split arrays are not persisted', () {
    final controller = buildController();
    final json = controller.serializeReasoningSegmentsWithSplits(
      const [],
      contentSplitOffsets: const [],
      reasoningCountAtSplit: const [],
      toolCountAtSplit: const [],
      reasoningDetails: const [
        {'type': 'reasoning.encrypted', 'data': 'sig'},
      ],
    );

    final decoded = jsonDecode(json) as Map<String, dynamic>;
    expect(decoded.containsKey('contentSplits'), isFalse);
    expect(controller.deserializeContentSplits(json), isNull);
  });

  test('deserializes empty v2 contentSplits as absent', () {
    final controller = buildController();
    const json =
        '{"v":2,"segments":[],"contentSplits":{"offsets":[],"reasoningCounts":[],"toolCounts":[]},"reasoningDetails":[{"type":"reasoning.encrypted","data":"sig"}]}';

    expect(controller.deserializeContentSplits(json), isNull);
    expect(controller.deserializeReasoningSegments(json), isEmpty);
    expect(controller.deserializeReasoningDetails(json), [
      {'type': 'reasoning.encrypted', 'data': 'sig'},
    ]);
  });

  test('invalid contentSplits do not drop segments or reasoningDetails', () {
    final controller = buildController();
    const mismatched =
        '{"v":2,"segments":[{"text":"keep","expanded":true,"toolStartIndex":0}],"contentSplits":{"offsets":[1],"reasoningCounts":[1,2],"toolCounts":[0]},"reasoningDetails":[{"type":"reasoning.encrypted","data":"sig"}]}';
    const negative =
        '{"v":2,"segments":[{"text":"keep","expanded":true,"toolStartIndex":0}],"contentSplits":{"offsets":[-1],"reasoningCounts":[1],"toolCounts":[0]},"reasoningDetails":[{"type":"reasoning.encrypted","data":"sig"}]}';
    const regression =
        '{"v":2,"segments":[{"text":"keep","expanded":true,"toolStartIndex":0}],"contentSplits":{"offsets":[0,3],"reasoningCounts":[2,1],"toolCounts":[0,0]},"reasoningDetails":[{"type":"reasoning.encrypted","data":"sig"}]}';

    for (final json in [mismatched, negative, regression]) {
      expect(controller.deserializeContentSplits(json), isNull);
      expect(controller.deserializeReasoningSegments(json).single.text, 'keep');
      expect(controller.deserializeReasoningDetails(json), [
        {'type': 'reasoning.encrypted', 'data': 'sig'},
      ]);
    }
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
    final settings = SettingsProvider(createBusinessTestPreferences());
    final state = buildStreamingStateWithContent(settings, '先确认一下。');

    expect(state.fullContentRaw, '先确认一下。');
  });

  test('finishReasoningAndPersist no longer writes content splits', () async {
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
    expect(controller.deserializeContentSplits(persistedJson), isNull);
  });

  test('streaming reasoning honors disabled auto-collapse setting', () async {
    final harness = await createBusinessTestHarness(
      initial: {'display_auto_collapse_thinking_v1': false},
    );
    final settings = SettingsProvider(harness.preferences);
    await settings.loaded;
    final controller = buildController(settings: settings);
    final state = buildStreamingState(settings);
    addTearDown(() => controller.cleanupTimers(state.messageId));

    await controller.handleReasoningChunk('thinking', state);

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

  test('treats empty v2 contentSplits as absent', () {
    final controller = buildController();
    final message = ChatMessage(
      id: 'assistant-1',
      role: 'assistant',
      content: '让我帮你搜索一下',
      conversationId: 'conversation-1',
      reasoningSegmentsJson:
          '{"v":2,"segments":[],"contentSplits":{"offsets":[],"reasoningCounts":[],"toolCounts":[]}}',
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
    );

    expect(controller.getContentSplitData(message.id), isNull);
    expect(controller.toolParts[message.id], hasLength(1));
    expect(controller.toolParts[message.id]!.single.loading, isTrue);
  });

  test(
    'OpenRouter Claude persist-reload keeps reasoningDetails and drops empty splits',
    () {
      final writer = buildController();
      final segment = ReasoningSegmentData()
        ..text = 'openrouter thinking'
        ..expanded = true
        ..toolStartIndex = 0;
      final persisted = writer.serializeReasoningSegmentsWithSplits(
        [segment],
        reasoningDetails: const [
          {
            'id': 'rd_1',
            'type': 'reasoning.encrypted',
            'data': 'sig',
            'format': 'anthropic-claude-v1',
          },
        ],
      );
      expect(
        (jsonDecode(persisted) as Map<String, dynamic>).containsKey(
          'contentSplits',
        ),
        isFalse,
      );

      final reader = buildController();
      final message = ChatMessage(
        id: 'or-claude',
        role: 'assistant',
        content: 'openrouter answer',
        conversationId: 'conversation-1',
        reasoningSegmentsJson: persisted,
      );
      reader.restoreMessageUiState(
        message,
        getToolEventsFromDb: (_) => const [],
      );

      expect(reader.getContentSplitData(message.id), isNull);
      expect(
        reader.getReasoningSegments(message.id)!.single.text,
        'openrouter thinking',
      );
      expect(reader.reasoningDetails[message.id], isNotNull);
    },
  );

  test(
    'dedupeToolPartsList keeps completed no-id tool results with different content',
    () {
      final controller = buildController();

      final parts = controller.dedupeToolPartsList(const [
        ToolUIPart(
          id: '',
          toolName: 'builtin_search',
          arguments: {},
          content: '{"items":[{"title":"First"}]}',
        ),
        ToolUIPart(
          id: '',
          toolName: 'builtin_search',
          arguments: {},
          content: '{"items":[{"title":"Second"}]}',
        ),
      ]);

      expect(parts, hasLength(2));
      expect(parts.map((part) => part.content), [
        '{"items":[{"title":"First"}]}',
        '{"items":[{"title":"Second"}]}',
      ]);
    },
  );

  test(
    'dedupeToolEvents keeps completed no-id tool results with different content',
    () {
      final controller = buildController();

      final events = controller.dedupeToolEvents(const [
        {
          'id': '',
          'name': 'builtin_search',
          'arguments': <String, dynamic>{},
          'content': '{"items":[{"title":"First"}]}',
        },
        {
          'id': '',
          'name': 'builtin_search',
          'arguments': <String, dynamic>{},
          'content': '{"items":[{"title":"Second"}]}',
        },
      ]);

      expect(events, hasLength(2));
      expect(events.map((event) => event['content']), [
        '{"items":[{"title":"First"}]}',
        '{"items":[{"title":"Second"}]}',
      ]);
    },
  );

  test(
    'dedupeToolPartsList keeps latest completed result for the same non-empty id',
    () {
      final controller = buildController();

      final parts = controller.dedupeToolPartsList(const [
        ToolUIPart(
          id: 'builtin_search',
          toolName: 'builtin_search',
          arguments: {},
          content: '{"items":[{"title":"First"}]}',
        ),
        ToolUIPart(
          id: 'builtin_search',
          toolName: 'builtin_search',
          arguments: {},
          content: '{"items":[{"title":"First"},{"title":"Second"}]}',
        ),
      ]);

      expect(parts, hasLength(1));
      expect(
        parts.single.content,
        '{"items":[{"title":"First"},{"title":"Second"}]}',
      );
    },
  );

  test(
    'dedupeToolEvents keeps latest completed result for the same non-empty id',
    () {
      final controller = buildController();

      final events = controller.dedupeToolEvents(const [
        {
          'id': 'builtin_search',
          'name': 'builtin_search',
          'arguments': <String, dynamic>{},
          'content': '{"items":[{"title":"First"}]}',
        },
        {
          'id': 'builtin_search',
          'name': 'builtin_search',
          'arguments': <String, dynamic>{},
          'content': '{"items":[{"title":"First"},{"title":"Second"}]}',
        },
      ]);

      expect(events, hasLength(1));
      expect(
        events.single['content'],
        '{"items":[{"title":"First"},{"title":"Second"}]}',
      );
    },
  );

  test(
    'handleToolResultsChunk keeps latest completed result for the same non-empty id',
    () async {
      final settings = SettingsProvider(createBusinessTestPreferences());
      final controller = buildController(
        settings: settings,
        currentConversationId: 'conversation-1',
      );
      final state = buildStreamingState(settings);

      Future<void> upsertToolEventInDb(
        String messageId, {
        required String id,
        required String name,
        required Map<String, dynamic> arguments,
        String? content,
        Map<String, dynamic>? metadata,
      }) async {}

      await controller.handleToolResultsChunk(
        const ToolCallResult(
          id: 'builtin_search',
          output: '{"items":[{"title":"First"}]}',
        ),
        state,
        upsertToolEventInDb: upsertToolEventInDb,
      );

      await controller.handleToolResultsChunk(
        const ToolCallResult(
          id: 'builtin_search',
          output: '{"items":[{"title":"First"},{"title":"Second"}]}',
        ),
        state,
        upsertToolEventInDb: upsertToolEventInDb,
      );

      final parts = controller.toolParts[state.messageId]!;
      expect(parts, hasLength(1));
      expect(
        parts.single.content,
        '{"items":[{"title":"First"},{"title":"Second"}]}',
      );
    },
  );

  test(
    'handleToolResultsChunk keeps accumulated Annotations for the same search id',
    () async {
      final settings = SettingsProvider(createBusinessTestPreferences());
      final controller = buildController(
        settings: settings,
        currentConversationId: 'conversation-1',
      );
      final state = buildStreamingState(settings);
      final upserted = <Map<String, dynamic>>[];

      Future<void> upsertToolEventInDb(
        String messageId, {
        required String id,
        required String name,
        required Map<String, dynamic> arguments,
        String? content,
        Map<String, dynamic>? metadata,
      }) async {
        upserted.add({'id': id, 'name': name, 'content': content});
      }

      const first = Annotations([
        UrlCitationAnnotation(url: 'https://a.example', title: 'A'),
      ], id: 'round-0:search-1');
      const second = Annotations([
        UrlCitationAnnotation(url: 'https://b.example', title: 'B'),
      ], id: 'round-0:search-1');

      state.partsHandler.handle(first);
      await controller.handleToolResultsChunk(
        first,
        state,
        upsertToolEventInDb: upsertToolEventInDb,
      );
      state.partsHandler.handle(second);
      await controller.handleToolResultsChunk(
        second,
        state,
        upsertToolEventInDb: upsertToolEventInDb,
      );

      expect(upserted, hasLength(2));
      final items = jsonDecode(upserted.last['content'] as String)['items'];
      expect(items, [
        {'url': 'https://a.example', 'title': 'A'},
        {'url': 'https://b.example', 'title': 'B'},
      ]);
    },
  );

  test(
    'handleToolResultsChunk does not add annotation search when a server tool exists',
    () async {
      final settings = SettingsProvider(createBusinessTestPreferences());
      final controller = buildController(
        settings: settings,
        currentConversationId: 'conversation-1',
      );
      final state = buildStreamingState(settings);

      Future<void> upsertToolEventInDb(
        String messageId, {
        required String id,
        required String name,
        required Map<String, dynamic> arguments,
        String? content,
        Map<String, dynamic>? metadata,
      }) async {}

      state.pendingToolNames['st_1'] = 'search_web';
      await controller.handleToolResultsChunk(
        const ServerToolEnd(id: 'st_1', output: '{"query":"kotlin"}'),
        state,
        upsertToolEventInDb: upsertToolEventInDb,
      );
      await controller.handleToolResultsChunk(
        const Annotations([UrlCitationAnnotation(url: 'https://example.com')]),
        state,
        upsertToolEventInDb: upsertToolEventInDb,
      );

      final parts = controller.toolParts[state.messageId]!;
      expect(parts, hasLength(1));
      expect(parts.single.id, 'st_1');
    },
  );

  test(
    'dedupeToolPartsList drops stale no-id placeholders when a completed result exists',
    () {
      final controller = buildController();

      final parts = controller.dedupeToolPartsList(const [
        ToolUIPart(
          id: '',
          toolName: 'builtin_search',
          arguments: {},
          loading: true,
        ),
        ToolUIPart(
          id: '',
          toolName: 'builtin_search',
          arguments: {},
          content: '{"items":[{"title":"Finished"}]}',
        ),
      ]);

      expect(parts, hasLength(1));
      expect(parts.single.loading, isFalse);
      expect(parts.single.content, '{"items":[{"title":"Finished"}]}');
    },
  );

  test(
    'dedupeToolEvents drops stale no-id placeholders when a completed result exists',
    () {
      final controller = buildController();

      final events = controller.dedupeToolEvents(const [
        {
          'id': '',
          'name': 'builtin_search',
          'arguments': <String, dynamic>{},
          'content': null,
        },
        {
          'id': '',
          'name': 'builtin_search',
          'arguments': <String, dynamic>{},
          'content': '{"items":[{"title":"Finished"}]}',
        },
      ]);

      expect(events, hasLength(1));
      expect(events.single['content'], '{"items":[{"title":"Finished"}]}');
    },
  );

  testWidgets('stream UI output is buffered until the smooth ticker fires', (
    tester,
  ) async {
    final settings = SettingsProvider(createBusinessTestPreferences());
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
      () => 'abcdefghijklmnopqrstuvwxyz',
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
    final settings = SettingsProvider(createBusinessTestPreferences());
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
      () => 'a' * 320,
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
    final settings = SettingsProvider(createBusinessTestPreferences());
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
      () => 'ok',
      totalTokens: 2,
      updateMessageInList: (_, __, ___) {},
    );

    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 50));

    expect(contents, const ['ok']);
    smoothController.dispose();
  });

  testWidgets('stream UI output handles a one-character final backlog', (
    tester,
  ) async {
    final settings = SettingsProvider(createBusinessTestPreferences());
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
      () => 'abc',
      totalTokens: 3,
      updateMessageInList: (_, __, ___) {},
    );

    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 50));

    expect(tester.takeException(), isNull);
    expect(contents, const ['ab', 'abc']);
    smoothController.dispose();
  });

  testWidgets('cleanup flushes final stream content immediately', (
    tester,
  ) async {
    final settings = SettingsProvider(createBusinessTestPreferences());
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
      () => 'final answer',
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
    final settings = SettingsProvider(createBusinessTestPreferences());
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
      () => 'visible after cancel',
      totalTokens: 18,
      updateMessageInList: (_, content, ___) => listContent = content,
    );

    smoothController.cleanupTimers('assistant-message');
    await tester.pump(const Duration(milliseconds: 200));

    expect(listContent, 'visible after cancel');
    smoothController.dispose();
  });

  test('handleToolCallsChunk keeps OpenAI server-tool action input', () async {
    final settings = SettingsProvider(createBusinessTestPreferences());
    final controller = buildController(
      settings: settings,
      currentConversationId: 'conversation-1',
    );
    final state = buildStreamingState(settings);
    final stored = <Map<String, dynamic>>[];
    const chunk = ServerToolStart(
      id: 'st_1',
      toolName: 'web_search_preview',
      input: {
        'action': {'query': 'kotlin coroutines'},
      },
    );

    state.partsHandler.handle(chunk);
    await controller.handleToolCallsChunk(
      chunk,
      state,
      updateReasoningSegmentsInDb: (_, __) async {},
      setToolEventsInDb: (_, events) async {
        stored
          ..clear()
          ..addAll(events);
      },
      getToolEventsFromDb: (_) => const [],
    );

    expect(stored.single['arguments'], {
      'action': {'query': 'kotlin coroutines'},
    });
    expect(controller.toolParts[state.messageId]!.single.arguments, {
      'action': {'query': 'kotlin coroutines'},
    });
  });

  test(
    'handleToolCallsChunk keeps Gemini code after an empty ServerToolStart',
    () async {
      final settings = SettingsProvider(createBusinessTestPreferences());
      final controller = buildController(
        settings: settings,
        currentConversationId: 'conversation-1',
      );
      final state = buildStreamingState(settings);
      final stored = <Map<String, dynamic>>[];
      const start = ToolCallStart(id: 'code_1', toolName: 'code_execution');
      const delta = ToolCallDelta(
        id: 'code_1',
        inputDelta: '{"language":"python","code":"print(1)"}',
      );
      const end = ToolCallEnd('code_1');
      const serverStart = ServerToolStart(
        id: 'code_1',
        toolName: 'code_execution',
      );

      for (final chunk in [start, delta, end]) {
        state.partsHandler.handle(chunk);
      }
      await controller.handleToolCallsChunk(
        end,
        state,
        updateReasoningSegmentsInDb: (_, __) async {},
        setToolEventsInDb: (_, events) async {
          stored
            ..clear()
            ..addAll(events);
        },
        getToolEventsFromDb: (_) => const [],
      );

      state.partsHandler.handle(serverStart);
      await controller.handleToolCallsChunk(
        serverStart,
        state,
        updateReasoningSegmentsInDb: (_, __) async {},
        setToolEventsInDb: (_, events) async {
          stored
            ..clear()
            ..addAll(events);
        },
        getToolEventsFromDb: (_) => List<Map<String, dynamic>>.from(stored),
      );

      expect(stored.last['arguments'], {
        'language': 'python',
        'code': 'print(1)',
      });
    },
  );

  test(
    'handleToolResultsChunk keeps handler content when ServerToolEnd has no output',
    () async {
      final settings = SettingsProvider(createBusinessTestPreferences());
      final controller = buildController(
        settings: settings,
        currentConversationId: 'conversation-1',
      );
      final state = buildStreamingState(settings);
      Map<String, dynamic>? upserted;
      const start = ServerToolStart(
        id: 'st_1',
        toolName: 'web_search_preview',
        input: {
          'action': {'query': 'kelivo'},
        },
      );
      const end = ServerToolEnd(id: 'st_1');

      state.partsHandler.handle(start);
      state.partsHandler.handle(end);
      await controller.handleToolResultsChunk(
        end,
        state,
        upsertToolEventInDb:
            (
              _, {
              required id,
              required name,
              required arguments,
              content,
              metadata,
            }) async {
              upserted = {'id': id, 'arguments': arguments, 'content': content};
            },
      );

      expect(upserted!['arguments'], {
        'action': {'query': 'kelivo'},
      });
      expect(upserted!['content'], isNotEmpty);
    },
  );
}
