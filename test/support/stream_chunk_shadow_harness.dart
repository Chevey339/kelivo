import 'dart:io';

import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/api/chat_api_service.dart';
import 'package:Kelivo/core/services/api/stream/legacy_chunk_adapter.dart';
import 'package:Kelivo/core/services/api/stream/stream_chunk.dart';
import 'package:Kelivo/core/services/api/stream/stream_chunk_decoder.dart';
import 'package:Kelivo/core/services/api/stream/stream_chunk_handler.dart';
import 'package:Kelivo/core/services/api/stream/stream_chunk_shadow.dart';
import 'package:Kelivo/core/services/api/stream/stream_trace.dart';
import 'package:Kelivo/core/services/chat/chat_service.dart';
import 'package:Kelivo/features/home/controllers/legacy_content_bookkeeping.dart';
import 'package:Kelivo/features/home/controllers/stream_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import 'business_test_harness.dart';

List<StreamChunk> replayTraceChunks(String path, StreamChunkDecoder decoder) {
  final events = loadSseEventsJsonl(
    File('test/fixtures/stream-traces/$path/events.jsonl').readAsStringSync(),
  );
  final chunks = <StreamChunk>[];
  for (final event in events) {
    chunks.addAll(decoder.accept(event).chunks);
  }
  chunks.addAll(decoder.onClosed());
  return chunks;
}

void expectShadowMatched(
  StreamChunkShadowDiff diff, {
  required String because,
}) {
  expect(
    diff.matched,
    isTrue,
    reason:
        '$because\n'
        'handlerKinds=${diff.handlerKinds} legacyKinds=${diff.legacyKinds}\n'
        'textMatch=${diff.textMatch} toolsMatch=${diff.toolsMatch} '
        'reasoningMatch=${diff.reasoningMatch} imagesMatch=${diff.imagesMatch}\n'
        'handlerTools=${diff.handlerToolIds} legacyTools=${diff.legacyToolIds}\n'
        'handlerImages=${diff.handlerImages} legacyImages=${diff.legacyImages}',
  );
}

Future<StreamChunkShadowDiff> compareChatFromChunks(
  List<StreamChunk> chunks, {
  bool streamOutput = true,
  bool responsesImageDuplicates = false,
}) async {
  final settings = SettingsProvider(createBusinessTestPreferences());
  await settings.loaded;
  const conversationId = 'conversation-1';
  const messageId = 'assistant-message';
  final controller = StreamController(
    chatService: ChatService(),
    onStateChanged: () {},
    getSettingsProvider: () => settings,
    getCurrentConversationId: () => conversationId,
  );
  addTearDown(() => controller.cleanupTimers(messageId));

  final state = StreamingState(
    GenerationContext(
      assistantMessage: ChatMessage(
        id: messageId,
        role: 'assistant',
        content: '',
        conversationId: conversationId,
        isStreaming: true,
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
      streamOutput: streamOutput,
    ),
  );

  final handler = StreamChunkHandler();
  final adapter = LegacyChunkAdapter();
  for (final chunk in chunks) {
    handler.handle(chunk);
    for (final bag in adapter.handle(chunk)) {
      await _dispatchLegacyBag(controller, state, bag);
    }
  }

  final tools = controller.getToolParts(messageId) ?? const [];
  final segments = controller.reasoningSegments[messageId] ?? const [];
  return StreamChunkShadow.compareChat(
    parts: handler.parts,
    fullContentRaw: state.fullContentRaw,
    offsets: state.contentSplitOffsets,
    reasoningCounts: state.reasoningCountAtSplit,
    toolCounts: state.toolCountAtSplit,
    toolIds: [for (final tool in tools) tool.id],
    reasoningSegments: [
      for (final segment in segments)
        (
          hasText: segment.text.isNotEmpty,
          toolStartIndex: segment.toolStartIndex,
        ),
    ],
    reasoningFallbackText:
        controller.reasoning[messageId]?.text ?? state.bufferedReasoning,
    responsesImageDuplicates: responsesImageDuplicates,
  );
}

StreamChunkShadowDiff compareLegacyFromChunks(
  List<StreamChunk> chunks, {
  bool responsesImageDuplicates = false,
}) {
  final handler = StreamChunkHandler();
  final adapter = LegacyChunkAdapter();
  final bags = <ShadowBag>[];
  for (final chunk in chunks) {
    handler.handle(chunk);
    for (final bag in adapter.handle(chunk)) {
      bags.add(
        ShadowBag(
          content: bag.content,
          reasoning: bag.reasoning ?? '',
          toolCallIds: [
            for (final call in bag.toolCalls ?? const <ToolCallInfo>[]) call.id,
          ],
          toolResultIds: [
            for (final result in bag.toolResults ?? const <ToolResultInfo>[])
              result.id,
          ],
        ),
      );
    }
  }
  final coalesced = coalesceChatStreamChunks([
    for (final bag in bags)
      ChatStreamChunk(
        content: bag.content,
        reasoning: bag.reasoning.isEmpty ? null : bag.reasoning,
        isDone: false,
        totalTokens: 0,
        toolCalls: [
          for (final id in bag.toolCallIds)
            ToolCallInfo(
              id: id,
              name: '',
              arguments: const <String, dynamic>{},
            ),
        ],
        toolResults: [
          for (final id in bag.toolResultIds)
            ToolResultInfo(
              id: id,
              name: '',
              arguments: const <String, dynamic>{},
              content: '',
            ),
        ],
      ),
  ]);
  return StreamChunkShadow.compareLegacy(
    parts: handler.parts,
    content: coalesced.content,
    reasoning: coalesced.reasoning ?? '',
    toolIds: {
      for (final call in coalesced.toolCalls ?? const <ToolCallInfo>[]) call.id,
      for (final result in coalesced.toolResults ?? const <ToolResultInfo>[])
        result.id,
    },
    bags: bags,
    responsesImageDuplicates: responsesImageDuplicates,
  );
}

Future<void> _dispatchLegacyBag(
  StreamController controller,
  StreamingState state,
  ChatStreamChunk chunk,
) async {
  if ((chunk.reasoning ?? '').isNotEmpty) {
    await controller.handleReasoningChunk(chunk, state);
  }
  if ((chunk.toolCalls ?? const []).isNotEmpty) {
    await controller.handleToolCallsChunk(
      chunk,
      state,
      updateReasoningSegmentsInDb: (_, _) async {},
      setToolEventsInDb: (_, _) async {},
      getToolEventsFromDb: (_) => const <Map<String, dynamic>>[],
    );
  }
  if ((chunk.toolResults ?? const []).isNotEmpty) {
    await controller.handleToolResultsChunk(
      chunk,
      state,
      upsertToolEventInDb:
          (
            _, {
            required id,
            required name,
            required arguments,
            content,
            metadata,
          }) async {},
    );
  }

  final content = chunk.content;
  if (content.isEmpty && !chunk.isDone) return;
  if (state.ctx.streamOutput && content.isNotEmpty) {
    await controller.finishReasoningOnContent(
      state,
      updateReasoningInDb:
          (
            _, {
            reasoningText,
            reasoningFinishedAt,
            reasoningSegmentsJson,
          }) async {},
    );
  }
  final bookkeeping = LegacyContentBookkeeping(
    hadThinkingBlock: state.hadThinkingBlock,
    fullContentRaw: state.fullContentRaw,
    offsets: state.contentSplitOffsets,
    reasoningCounts: state.reasoningCountAtSplit,
    toolCounts: state.toolCountAtSplit,
  );
  final recorded = bookkeeping.addContent(
    content,
    reasoningCount: controller.getReasoningSegmentCount(state.messageId),
    toolCount: controller.getToolPartsCount(state.messageId),
  );
  state
    ..hadThinkingBlock = bookkeeping.hadThinkingBlock
    ..fullContentRaw = bookkeeping.fullContentRaw;
  if (!recorded) return;
  controller.setContentSplitData(
    state.messageId,
    ContentSplitData(
      offsets: List<int>.of(state.contentSplitOffsets),
      reasoningCounts: List<int>.of(state.reasoningCountAtSplit),
      toolCounts: List<int>.of(state.toolCountAtSplit),
    ),
  );
}
