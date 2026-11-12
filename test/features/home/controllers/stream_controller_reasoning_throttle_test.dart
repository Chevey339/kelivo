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

  StreamingState buildStreamingState(
    SettingsProvider settings, {
    ChatMessage? seed,
  }) {
    final message =
        seed ??
        ChatMessage(
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

  for (final withHistory in [false, true]) {
    for (final initialSummary in ['', 'first']) {
      testWidgets('returning to background reasoning preserves live overlays '
          '(history=$withHistory, summary=$initialSummary)', (tester) async {
        final settings = SettingsProvider(createBusinessTestPreferences());
        var current = 'other';
        final controller = StreamController(
          onStateChanged: () {},
          getSettingsProvider: () => settings,
          getCurrentConversationId: () => current,
        );
        addTearDown(controller.dispose);
        addTearDown(settings.dispose);
        final oldStart = DateTime(2026, 11, 2);
        final oldEnd = oldStart.add(const Duration(seconds: 1));
        final seed = ChatMessage(
          id: 'assistant-message',
          role: 'assistant',
          conversationId: 'conversation-1',
          isStreaming: true,
          parts: withHistory
              ? const [
                  ReasoningPart(''),
                  ReasoningPart('older'),
                  TextPart('answer'),
                ]
              : const [],
          reasoningText: withHistory ? 'older' : null,
          reasoningStartAt: withHistory ? oldStart : null,
          reasoningFinishedAt: withHistory ? oldEnd : null,
          reasoningSegmentsJson: withHistory
              ? controller.serializeReasoningSegments([
                  for (final text in ['', 'older'])
                    ReasoningSegmentData()
                      ..text = text
                      ..startAt = oldStart
                      ..finishedAt = oldEnd,
                ])
              : null,
        );
        // Generation initializes its complete seed before any stream event,
        // including when no UI has rendered this background message yet.
        controller.restoreMessageUiState(seed, getToolEventsFromDb: (_) => []);
        final state = buildStreamingState(settings, seed: seed);
        controller.markStreamingStarted(state.messageId);
        state.partsHandler.handle(const ReasoningStart(id: 'live'));
        controller.handleReasoningStart('live', state);
        state.partsHandler.handle(
          ReasoningDelta(id: 'live', text: initialSummary),
        );
        await controller.handleReasoningChunk(
          initialSummary,
          state,
          id: 'live',
        );
        final live = controller.getReasoningSegments(state.messageId)!;
        final startedAt = live.last.startAt;
        final checkpoint = seed.copyWith(
          parts: state.partsHandler.parts,
          reasoningText: controller.getReasoningData(state.messageId)!.text,
          reasoningStartAt: startedAt,
          reasoningSegmentsJson: controller.serializeReasoningSegments(live),
        );

        controller.clearAllState(keepMessageIds: {state.messageId});
        current = state.conversationId;
        controller.restoreMessageUiState(
          checkpoint,
          getToolEventsFromDb: (_) => [],
        );
        controller.refreshPresentation();
        expect(controller.getReasoningSegments(state.messageId), same(live));
        expect(live, hasLength(withHistory ? 3 : 1));
        expect(live.last.finishedAt, isNull);
        expect(
          state.partsHandler.parts.whereType<ReasoningPart>(),
          hasLength(live.length),
        );

        await controller.handleReasoningChunk(' later', state, id: 'live');
        await tester.pump(const Duration(milliseconds: 50));
        expect(live.last.text, '$initialSummary later');
        expect(live.last.startAt, startedAt);
        expect(live.last.finishedAt, isNull);
        expect(
          controller.getReasoningData(state.messageId)!.text,
          '${withHistory ? 'older' : ''}$initialSummary later',
        );
        controller.handleReasoningEnd('live', state);
        await tester.pump(const Duration(milliseconds: 50));
        expect(live.last.finishedAt, isNotNull);
        expect(
          controller
              .deserializeReasoningSegments(
                controller.serializeReasoningSegments(live),
              )
              .last
              .text,
          '$initialSummary later',
        );
        controller.cleanupTimers(state.messageId);
      });
    }
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
        await controller.handleReasoningChunk('${i + 1}', state, id: 'r');
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
    await controller.handleReasoningChunk('before switching', state, id: 'r');
    final startAt = controller.getReasoningData(state.messageId)!.startAt;
    controller.clearAllState(keepMessageIds: {state.messageId});
    await controller.handleReasoningChunk(' and after', state, id: 'r');
    await tester.pump(const Duration(milliseconds: 50));

    expect(notifier.value.reasoningText, 'before switching and after');
    expect(notifier.value.reasoningStartAt, startAt);
    expect(notifier.value.reasoningFinishedAt, isNull);
    controller.dispose();
  });
}
