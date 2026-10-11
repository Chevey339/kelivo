import "../../../support/business_test_harness.dart";
import 'package:flutter_test/flutter_test.dart';
import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/core/models/message_part.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/api/stream/stream_chunk.dart';
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
    'caught-up and hidden streams do no presentation work until woken',
    (tester) async {
      final settings = SettingsProvider(createBusinessTestPreferences());
      var current = 'conversation-1';
      final controller = StreamController(
        onStateChanged: () {},
        getSettingsProvider: () => settings,
        getCurrentConversationId: () => current,
      );
      addTearDown(controller.dispose);
      var calls = 0;
      var content = 'a';
      void publish() => controller.scheduleThrottledUpdate(
        'message',
        'conversation-1',
        () {
          calls++;
          return content;
        },
        updateMessageInList: (_, _, _) {},
        totalTokens: 0,
      );
      publish();
      await tester.pump(const Duration(milliseconds: 50));
      expect(calls, 1);
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(calls, 1);
      controller.setPresentationEnabled(false);
      content = 'b';
      publish();
      await tester.pump(const Duration(seconds: 1));
      expect(calls, 1);
      controller.setPresentationEnabled(true);
      await tester.pump(const Duration(milliseconds: 50));
      expect(calls, 2);
      expect(
        controller.streamingContentNotifier
            .getNotifier('message')
            .value
            .content,
        'b',
      );
      current = 'other';
      controller.refreshPresentation();
      content = 'c';
      publish();
      await tester.pump(const Duration(seconds: 1));
      expect(calls, 2);
      current = 'conversation-1';
      controller.refreshPresentation();
      await tester.pump(const Duration(milliseconds: 50));
      expect(calls, 3);
      expect(
        controller.streamingContentNotifier
            .getNotifier('message')
            .value
            .content,
        'c',
      );
    },
  );

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

  test('interleaved reasoning and text preserve segment identity', () async {
    final settings = SettingsProvider(createBusinessTestPreferences());
    await settings.loaded;
    final controller = buildController(
      settings: settings,
      currentConversationId: 'conversation-1',
    );
    addTearDown(controller.dispose);
    final state = buildStreamingState(settings);

    const first = ReasoningDelta(id: 'reasoning-1', text: 'initial reasoning');
    state.partsHandler.handle(first);
    await controller.handleReasoningChunk(first.text, state, segmentId: first.id);
    final original = controller.getReasoningSegments(state.messageId)!.single;

    state.partsHandler.handle(
      const TextDelta(id: 'text-1', text: 'partial answer'),
    );
    controller.finishReasoningIfNeeded(state.messageId);
    final finishedAt = original.finishedAt;
    expect(finishedAt, isNotNull);
    original.expanded = true;

    const second = ReasoningDelta(id: 'reasoning-1', text: ' continued');
    state.partsHandler.handle(second);
    await controller.handleReasoningChunk(
      second.text,
      state,
      segmentId: second.id,
    );

    final segments = controller.getReasoningSegments(state.messageId)!;
    final parts = state.partsHandler.parts.whereType<ReasoningPart>().toList();
    expect(segments, hasLength(1));
    expect(parts, hasLength(1));
    expect(segments.single, same(original));
    expect(segments.single.text, 'initial reasoning continued');
    expect(segments.single.text, parts.single.text);
    expect(segments.single.finishedAt, finishedAt);
    expect(segments.single.expanded, isTrue);
  });

  test('structured reasoning summaries keep item boundaries', () async {
    final settings = SettingsProvider(createBusinessTestPreferences());
    await settings.loaded;
    await settings.setAutoCollapseThinking(true);
    final controller = buildController(
      settings: settings,
      currentConversationId: 'conversation-1',
    );
    addTearDown(controller.dispose);
    final state = buildStreamingState(settings);

    await controller.handleReasoningChunk(
      '**First**',
      state,
      segmentId: 'summary-1',
      reasoningType: ReasoningType.summaryText,
    );
    controller.getReasoningSegments(state.messageId)!.single.expanded = true;
    await controller.handleReasoningChunk(
      ' explanation',
      state,
      segmentId: 'summary-1',
      reasoningType: ReasoningType.summaryText,
    );
    await controller.handleReasoningChunk(
      '**Second**',
      state,
      segmentId: 'summary-2',
      reasoningType: ReasoningType.summaryText,
    );

    final segments = controller.getReasoningSegments(state.messageId)!;
    expect(segments, hasLength(2));
    expect(segments[0].id, 'summary-1');
    expect(segments[0].text, '**First** explanation');
    expect(segments[0].reasoningType, ReasoningType.summaryText);
    expect(segments[0].finishedAt, isNotNull);
    expect(segments[0].expanded, isFalse);
    expect(segments[1].id, 'summary-2');
    expect(segments[1].text, '**Second**');
    expect(segments[1].finishedAt, isNull);
  });

  for (final autoCollapse in [true, false]) {
    test('summary completion honors auto-collapse: $autoCollapse', () async {
      final settings = SettingsProvider(createBusinessTestPreferences());
      await settings.loaded;
      await settings.setAutoCollapseThinking(autoCollapse);
      final controller = buildController(
        settings: settings,
        currentConversationId: 'conversation-1',
      );
      addTearDown(controller.dispose);
      final state = buildStreamingState(settings);
      await controller.handleReasoningChunk(
        'summary',
        state,
        segmentId: 'summary-1',
        reasoningType: ReasoningType.summaryText,
      );
      final segment = controller.getReasoningSegments(state.messageId)!.single;
      segment.expanded = true;

      controller.finishReasoningSegment(state.messageId, 'summary-1');

      final finishedAt = segment.finishedAt;
      expect(finishedAt, isNotNull);
      expect(segment.expanded, !autoCollapse);

      segment.expanded = true;
      controller.finishReasoningSegment(state.messageId, 'summary-1');
      controller.finishReasoningIfNeeded(state.messageId);

      expect(segment.finishedAt, finishedAt);
      expect(segment.expanded, isTrue);
      await controller.handleReasoningChunk('subsequent reasoning', state);
      expect(segment.expanded, isTrue);
    });
  }

  test('switching to reasoning closes and collapses a summary', () async {
    final settings = SettingsProvider(createBusinessTestPreferences());
    await settings.loaded;
    await settings.setAutoCollapseThinking(true);
    final controller = buildController(settings: settings);
    addTearDown(controller.dispose);
    final state = buildStreamingState(settings);
    await controller.handleReasoningChunk(
      'summary',
      state,
      segmentId: 'summary-1',
      reasoningType: ReasoningType.summaryText,
    );
    final summary = controller.getReasoningSegments(state.messageId)!.single;
    summary.expanded = true;

    await controller.handleReasoningChunk('subsequent reasoning', state);

    final segments = controller.getReasoningSegments(state.messageId)!;
    expect(segments, hasLength(2));
    expect(summary.finishedAt, isNotNull);
    expect(summary.expanded, isFalse);
    expect(segments.last.text, 'subsequent reasoning');
    expect(segments.last.finishedAt, isNull);
  });

  test('deltas after summary completion create a new segment', () async {
    final settings = SettingsProvider(createBusinessTestPreferences());
    await settings.loaded;
    final controller = buildController(
      settings: settings,
      currentConversationId: 'conversation-1',
    );
    addTearDown(controller.dispose);
    final state = buildStreamingState(settings);

    const first = ReasoningDelta(
      id: 'summary-1',
      text: 'item one',
      reasoningType: ReasoningType.summaryText,
    );
    state.partsHandler.handle(first);
    await controller.handleReasoningChunk(
      first.text,
      state,
      segmentId: first.id,
      reasoningType: first.reasoningType,
    );
    state.partsHandler.handle(const ReasoningEnd(id: 'summary-1'));
    controller.finishReasoningSegment(state.messageId, 'summary-1');

    const second = ReasoningDelta(
      id: 'summary-1',
      text: 'item two',
      reasoningType: ReasoningType.summaryText,
    );
    state.partsHandler.handle(second);
    await controller.handleReasoningChunk(
      second.text,
      state,
      segmentId: second.id,
      reasoningType: second.reasoningType,
    );

    final segments = controller.getReasoningSegments(state.messageId)!;
    final parts = state.partsHandler.parts.whereType<ReasoningPart>().toList();
    expect(segments, hasLength(2));
    expect(parts, hasLength(2));
    expect(segments.map((segment) => segment.text), ['item one', 'item two']);
    expect(parts.map((part) => part.text), ['item one', 'item two']);
    expect(segments.first.finishedAt, isNotNull);
    expect(segments.last.finishedAt, isNull);
  });

  testWidgets('clearing completed messages preserves pending reasoning ticks', (
    tester,
  ) async {
    final settings = SettingsProvider(createBusinessTestPreferences());
    final controller = buildController(
      settings: settings,
      currentConversationId: 'conversation-1',
    );
    final state = buildStreamingState(settings);
    controller.markStreamingStarted(state.messageId);
    final notifier = controller.streamingContentNotifier.getNotifier(
      state.messageId,
    );
    await controller.handleReasoningChunk('before switching', state);
    final startAt = controller.getReasoningData(state.messageId)!.startAt;
    controller.clearAllState(keepMessageIds: {state.messageId});
    await controller.handleReasoningChunk(' and after', state);
    await tester.pump(const Duration(milliseconds: 50));

    expect(notifier.value.reasoningText, 'before switching and after');
    expect(notifier.value.reasoningStartAt, startAt);
    expect(notifier.value.reasoningFinishedAt, isNull);
    controller.dispose();
  });
}
