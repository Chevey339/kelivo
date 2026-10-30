import "../../../support/business_test_harness.dart";

import 'package:flutter_test/flutter_test.dart';
import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/core/models/message_part.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/api/stream/stream_chunk.dart';
import 'package:Kelivo/features/chat/widgets/timeline_projection.dart';
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
    await controller.handleReasoningChunk(
      first.text,
      state,
      segmentId: first.id,
    );
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
    expect(segments[0].summaryEnded, isTrue);
    expect(segments[0].finishedAt, isNull);
    expect(segments[0].expanded, isFalse);
    expect(segments[1].id, 'summary-2');
    expect(segments[1].text, '**Second**');
    expect(segments[1].finishedAt, isNull);
  });

  test('tool start finishes every unfinished reasoning segment', () async {
    final settings = SettingsProvider(createBusinessTestPreferences());
    await settings.loaded;
    await settings.setAutoCollapseThinking(true);
    final controller = buildController(settings: settings);
    addTearDown(controller.dispose);
    final state = buildStreamingState(settings);

    await controller.handleReasoningChunk('first reasoning', state);
    final segments = controller.getReasoningSegments(state.messageId)!;
    final first = segments.single..expanded = true;
    final second = ReasoningSegmentData()
      ..text = 'second reasoning'
      ..startAt = DateTime.now()
      ..expanded = true;
    segments.add(second);
    final previousEnd = DateTime.now().subtract(const Duration(seconds: 20));
    final completed = ReasoningSegmentData()
      ..text = 'completed reasoning'
      ..startAt = previousEnd.subtract(const Duration(seconds: 4))
      ..finishedAt = previousEnd
      ..expanded = true;
    segments.insert(0, completed);
    String? persisted;

    await controller.handleToolCallsChunk(
      const ToolCallStart(id: 'search-1', toolName: 'search'),
      state,
      updateReasoningSegmentsInDb: (_, json) async {
        persisted = json;
      },
      setToolEventsInDb: (_, _) async {},
      getToolEventsFromDb: (_) => [],
    );

    expect(first.finishedAt, isNotNull);
    expect(second.finishedAt, first.finishedAt);
    expect(first.expanded, isFalse);
    expect(second.expanded, isFalse);
    expect(completed.finishedAt, previousEnd);
    expect(completed.expanded, isTrue);
    final restored = controller.deserializeReasoningSegments(persisted!);
    expect(restored.map((segment) => segment.finishedAt), [
      previousEnd,
      first.finishedAt,
      first.finishedAt,
    ]);
  });

  for (final boundary in ['text', 'tool', 'stream end']) {
    test(
      'post-tool summaries keep timing until $boundary and retain phase ends',
      () async {
        final settings = SettingsProvider(createBusinessTestPreferences());
        await settings.loaded;
        final controller = buildController(settings: settings);
        addTearDown(controller.dispose);
        final state = buildStreamingState(settings);

        Future<void> summary(String id, String text) async {
          final chunk = ReasoningDelta(
            id: id,
            text: text,
            reasoningType: ReasoningType.summaryText,
          );
          state.partsHandler.handle(chunk);
          await controller.handleReasoningChunk(
            text,
            state,
            segmentId: id,
            reasoningType: chunk.reasoningType,
          );
          state.partsHandler.handle(ReasoningEnd(id: id));
          controller.finishReasoningSegment(state.messageId, id);
        }

        Future<void> tool(String id) async {
          final chunk = ToolCallStart(id: id, toolName: 'search');
          state.partsHandler.handle(chunk);
          await controller.handleToolCallsChunk(
            chunk,
            state,
            updateReasoningSegmentsInDb: (_, _) async {},
            setToolEventsInDb: (_, _) async {},
            getToolEventsFromDb: (_) => [],
          );
        }

        await summary('first', 'first-round summary');
        state.partsHandler.handle(
          const TextDelta(id: 'first-text', text: 'first-round answer'),
        );
        controller.finishReasoningIfNeeded(state.messageId);
        final first = controller.getReasoningSegments(state.messageId)!.single;
        expect(first.finishedAt, isNotNull);
        final firstEnd = DateTime.now().subtract(const Duration(seconds: 20));
        first
          ..startAt = firstEnd.subtract(const Duration(seconds: 4))
          ..finishedAt = firstEnd;
        controller.getReasoningData(state.messageId)!.finishedAt = firstEnd;
        await tool('first-tool');

        await summary('second', 'second-round summary one');
        await summary('third', 'second-round summary two');
        final segments = controller.getReasoningSegments(state.messageId)!;
        final secondStart = DateTime.now().subtract(
          const Duration(seconds: 10),
        );
        segments[1].startAt = secondStart;
        segments[2].startAt = secondStart.add(const Duration(seconds: 2));
        expect(segments[1].summaryEnded, isTrue);
        expect(segments[2].summaryEnded, isTrue);
        expect(segments[1].finishedAt, isNull);
        expect(segments[2].finishedAt, isNull);
        segments[1].expanded = true;
        segments[2].expanded = true;

        switch (boundary) {
          case 'text':
            state.partsHandler.handle(
              const TextDelta(id: 'second-text', text: 'second-round answer'),
            );
            await controller.finishReasoningAndPersist(
              state.messageId,
              updateReasoningInDb:
                  (
                    _, {
                    reasoningText,
                    reasoningFinishedAt,
                    reasoningSegmentsJson,
                  }) async {},
            );
          case 'tool':
            await tool('second-tool');
          case 'stream end':
            state.partsHandler.handle(const Finish());
            await controller.finalizeReasoningState(
              state.messageId,
              updateReasoningInDb:
                  (
                    _, {
                    reasoningText,
                    reasoningFinishedAt,
                    reasoningSegmentsJson,
                  }) async {},
            );
        }
        final secondEnd = segments[2].finishedAt;
        expect(secondEnd, isNotNull);
        expect(segments[1].finishedAt, secondEnd);
        expect(segments[1].expanded, isTrue);
        expect(segments[2].expanded, isTrue);
        expect(first.finishedAt, firstEnd);

        for (final restored in [false, true]) {
          final overlay = restored
              ? controller.deserializeReasoningSegments(
                  controller.serializeReasoningSegmentsWithSplits(segments),
                )
              : segments;
          final projected = projectAssistantTimeline(
            parts: state.partsHandler.parts,
            liveTools: const [],
            reasoningSegments: [
              for (final segment in overlay)
                TimelineReasoningRef(
                  text: segment.text,
                  startAt: segment.startAt,
                  finishedAt: segment.finishedAt,
                  loading: timelineReasoningLoading(
                    finishedAt: segment.finishedAt,
                    isStreaming: !restored && boundary != 'stream end',
                  ),
                  toolStartIndex: segment.toolStartIndex,
                ),
            ],
            visualContent: boundary == 'text'
                ? 'first-round answersecond-round answer'
                : 'first-round answer',
            isStreaming: !restored && boundary != 'stream end',
            partsArrivalOrdered: !restored,
            reasoningFinishedAt: controller
                .getReasoningData(state.messageId)!
                .finishedAt,
          );
          final reasoning = projected.blocks
              .expand((block) => block.steps)
              .where((step) => step.isReasoning)
              .last
              .reasoning!;
          expect(reasoning.startAt, secondStart);
          expect(reasoning.finishedAt, secondEnd);
          expect(reasoning.loading, isFalse);
        }
      },
    );
  }

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

      expect(segment.summaryEnded, isTrue);
      expect(segment.finishedAt, isNull);
      expect(segment.expanded, !autoCollapse);

      segment.expanded = true;
      controller.finishReasoningSegment(state.messageId, 'summary-1');
      controller.finishReasoningIfNeeded(state.messageId);

      final finishedAt = segment.finishedAt;
      expect(finishedAt, isNotNull);
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
    expect(summary.summaryEnded, isTrue);
    expect(summary.finishedAt, isNull);
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
    expect(segments.first.summaryEnded, isTrue);
    expect(segments.first.finishedAt, isNull);
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
