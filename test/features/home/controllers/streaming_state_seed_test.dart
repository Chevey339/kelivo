import "../../../support/business_test_harness.dart";
import 'dart:convert';
import 'dart:async' as async;

import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/core/models/message_part.dart';
import 'package:Kelivo/core/models/token_usage.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/api/generation/text_generation_result.dart';
import 'package:Kelivo/core/services/api/stream/stream_chunk.dart';
import 'package:Kelivo/features/home/controllers/stream_controller.dart';
import 'package:Kelivo/features/home/controllers/chat_actions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues(const {});

  StreamingState buildState(
    List<MessagePart> parts, {
    int? durationMs,
    int? firstTokenMs,
  }) {
    final settings = SettingsProvider(createBusinessTestPreferences());
    return StreamingState(
      GenerationContext(
        assistantMessage: ChatMessage(
          id: 'assistant-message',
          role: 'assistant',
          parts: parts,
          conversationId: 'conversation-1',
          isStreaming: true,
          durationMs: durationMs,
          firstTokenMs: firstTokenMs,
        ),
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

  test('reasoning is the first output; metadata and empty deltas are not', () {
    final state = buildState(const [])
      ..requestStartedAt = DateTime.now().subtract(const Duration(seconds: 2));
    for (final chunk in <StreamChunk>[
      const Usage(TokenUsage(promptTokens: 100)),
      const TextStart('text'),
      const ReasoningStart(id: 'reasoning'),
      const TextDelta(id: 'text', text: ''),
      const ReasoningDelta(id: 'reasoning', text: '', details: []),
      const RetryAttemptStart(),
    ]) {
      state.recordFirstOutput(chunk);
    }
    expect(state.firstTokenMs, isNull);

    state.recordFirstOutput(
      const ReasoningDelta(id: 'reasoning', text: 'think'),
    );
    final firstTokenMs = state.firstTokenMs;
    expect(firstTokenMs, inInclusiveRange(2000, 3000));
    state.requestStartedAt = state.requestStartedAt!.subtract(
      const Duration(seconds: 30),
    );
    state.recordFirstOutput(const TextDelta(id: 'text', text: 'answer'));
    expect(state.firstTokenMs, firstTokenMs);
    state.finishRequestTiming();
    expect(state.durationMs, inInclusiveRange(32000, 33000));
    final finishedAt = state.requestFinishedAt;
    state.finishRequestTiming();
    expect(state.requestFinishedAt, finishedAt);
  });

  for (final firstOutput in <StreamChunk>[
    const TextDelta(id: 'text', text: 'answer'),
    const ReasoningDelta(id: 'reasoning', text: 'thinking'),
  ]) {
    test(
      'first ${firstOutput.runtimeType} excludes a queued database wait',
      () async {
        final state = buildState(const [])..requestStartedAt = DateTime.now();
        final source = async.StreamController<StreamChunk>(sync: true);
        final databaseWrite = async.Completer<void>();
        final done = async.Completer<void>();
        final processed = <StreamChunk>[];
        final subscription = ChatActions.listenSequentiallyToStream<StreamChunk>(
          stream: source.stream,
          onReceived: state.recordFirstOutput,
          onData: (chunk) async {
            // Model the database transition that holds TextStart/Usage in the
            // production handler. Later model output still arrives meanwhile.
            processed.add(chunk);
            if (chunk is TextStart) await databaseWrite.future;
          },
          onError: (error, stackTrace) async =>
              done.completeError(error, stackTrace),
          onDone: () async => done.complete(),
        );
        source.add(const TextStart('text'));
        source.add(const Usage(TokenUsage(promptTokens: 100)));
        await Future<void>.delayed(const Duration(milliseconds: 10));
        final receivedMs = DateTime.now()
            .difference(state.requestStartedAt!)
            .inMilliseconds;
        source.add(firstOutput);
        final recordedWhileBlocked = state.firstTokenMs;
        expect(processed, hasLength(1));
        await Future<void>.delayed(const Duration(milliseconds: 250));
        databaseWrite.complete();
        await source.close();
        await done.future;
        await subscription.cancel();

        expect(processed, hasLength(3));
        expect(
          state.firstTokenMs,
          inInclusiveRange(receivedMs, receivedMs + 20),
        );
        expect(recordedWhileBlocked, state.firstTokenMs);
      },
    );
  }

  test('tool input can be the first output without counting a bare start', () {
    final state = buildState(const [])
      ..requestStartedAt = DateTime.now().subtract(const Duration(seconds: 1));
    state.recordFirstOutput(const ToolCallStart(id: 'tool'));
    expect(state.firstTokenMs, isNull);
    state.recordFirstOutput(
      const ToolCallDelta(id: 'tool', inputDelta: '{"query":'),
    );
    expect(state.firstTokenMs, inInclusiveRange(1000, 2000));
  });

  test(
    'resumed generation keeps original latency and accumulates duration',
    () {
      final state = buildState(
        const [TextPart('before')],
        durationMs: 30000,
        firstTokenMs: 1500,
      )..requestStartedAt = DateTime(2026, 9, 27);
      state.requestFinishedAt = state.requestStartedAt!.add(
        const Duration(seconds: 5),
      );
      state.recordFirstOutput(const TextDelta(id: 'text', text: 'after'));
      expect(state.durationMs, 35000);
      expect(state.firstTokenMs, 1500);
    },
  );

  test('unknown original latency remains unknown on continuation', () {
    final state = buildState(const [TextPart('before')], durationMs: 30000)
      ..requestStartedAt = DateTime.now();
    state.recordFirstOutput(const TextDelta(id: 'text', text: 'after'));
    expect(state.firstTokenMs, isNull);
  });

  test('late output after cancellation cannot change the frozen timing', () {
    final state = buildState(const [])
      ..requestStartedAt = DateTime.now().subtract(const Duration(seconds: 1));
    state.finishRequestTiming();
    final duration = state.durationMs;
    state.recordFirstOutput(const TextDelta(id: 'text', text: 'late'));
    expect(state.firstTokenMs, isNull);
    expect(state.durationMs, duration);
  });

  test('unknown starts and clock rollback do not create negative timing', () {
    final state = buildState(const []);
    state.recordFirstOutput(const TextDelta(id: 'text', text: 'answer'));
    expect(state.durationMs, isNull);
    expect(state.firstTokenMs, isNull);
    state.requestStartedAt = DateTime.now().add(const Duration(days: 1));
    state.finishRequestTiming();
    state.recordFirstOutput(const TextDelta(id: 'text', text: 'answer'));
    expect(state.durationMs, isNull);
    expect(state.firstTokenMs, isNull);
  });

  test('StreamingState seeds partsHandler from the assistant message', () {
    final state = buildState(const [
      TextPart('before'),
      ReasoningPart('plan'),
      ToolCallPart('{"id":"call_1","name":"lookup"}'),
    ]);

    expect(state.fullContentRaw, 'before');
    expect(state.partsHandler.parts.map((part) => part.kind).toList(), [
      'text',
      'reasoning',
      'tool_call',
    ]);
    expect((state.partsHandler.parts[0] as TextPart).text, 'before');
  });

  test('non-stream handleResult keeps seeded parts and joins all text', () {
    final state = buildState(const [TextPart('before'), ReasoningPart('plan')]);
    state.partsHandler.handleResult(
      const TextGenerationResult(parts: [TextPart('after')]),
    );
    state.fullContentRaw = [
      for (final part in state.partsHandler.parts)
        if (part is TextPart) part.text,
    ].join();

    expect(state.fullContentRaw, 'beforeafter');
    expect(
      state.partsHandler.parts.whereType<TextPart>().map((part) => part.text),
      ['before', 'after'],
    );
    expect(
      state.partsHandler.parts.whereType<ReasoningPart>().single.text,
      'plan',
    );
  });

  test('continuation text after a tool answer does not drop prior cards', () {
    final state = buildState([
      const TextPart('before'),
      ToolCallPart(
        jsonEncode(<String, dynamic>{
          'id': 'call_1',
          'name': 'lookup',
          'arguments': <String, dynamic>{'q': 'kelivo'},
        }),
      ),
    ]);
    state.partsHandler.handle(
      const TextDelta(id: 'round-1:text-1', text: 'after'),
    );

    expect(state.partsHandler.parts.map((part) => part.kind).toList(), [
      'text',
      'tool_call',
      'text',
    ]);
    expect((state.partsHandler.parts.first as TextPart).text, 'before');
    expect((state.partsHandler.parts.last as TextPart).text, 'after');
  });

  test('StreamingState keeps retryStatus independently of the notifier', () {
    final state = buildState(const [TextPart('hello')]);
    final status = RetryStatus(
      attempt: 1,
      maxRetries: 3,
      retryAt: DateTime(2026, 8, 30, 21, 1),
    );
    state.retryStatus = status;
    expect(state.retryStatus, status);
    expect(state.retryStatus!.attempt, 1);
  });
}
