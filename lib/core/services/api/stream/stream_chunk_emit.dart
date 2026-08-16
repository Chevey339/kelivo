part of '../chat_api_service.dart';

const _emitTextId = 'legacy:text';
const _emitReasoningId = 'legacy:reasoning';

TokenUsage? _usageOrApprox(TokenUsage? usage, int totalTokens) {
  if (usage != null) return usage;
  if (totalTokens > 0) return TokenUsage(totalTokens: totalTokens);
  return null;
}

Future<StreamChunk> _sanitizeStreamChunk(
  StreamChunk chunk,
  Future<String> Function(String input) sanitize,
) async {
  if (chunk is TextDelta) {
    final sanitized = await sanitize(chunk.text);
    if (sanitized != chunk.text) {
      return TextDelta(id: chunk.id, text: sanitized);
    }
  }
  return chunk;
}

Stream<StreamChunk> emitText(String content) async* {
  if (content.isNotEmpty) {
    yield TextDelta(id: _emitTextId, text: content);
  }
}

Stream<StreamChunk> emitReasoning(String? reasoning, {dynamic details}) async* {
  if ((reasoning == null || reasoning.isEmpty) && details == null) return;
  yield ReasoningDelta(
    id: _emitReasoningId,
    text: reasoning ?? '',
    details: details,
  );
}

Stream<StreamChunk> emitUsage(TokenUsage? usage) async* {
  if (usage != null) yield Usage(usage);
}

Stream<StreamChunk> emitFinish({
  TokenUsage? usage,
  int totalTokens = 0,
  dynamic reasoningDetails,
}) async* {
  yield* emitReasoning(null, details: reasoningDetails);
  yield* emitUsage(_usageOrApprox(usage, totalTokens));
  yield const Finish();
}

Stream<StreamChunk> emitDelta({
  String content = '',
  String? reasoning,
  dynamic reasoningDetails,
  TokenUsage? usage,
  int totalTokens = 0,
}) async* {
  yield* emitUsage(_usageOrApprox(usage, totalTokens));
  yield* emitReasoning(reasoning, details: reasoningDetails);
  yield* emitText(content);
}

Stream<StreamChunk> emitDone({
  String content = '',
  String? reasoning,
  dynamic reasoningDetails,
  TokenUsage? usage,
  int totalTokens = 0,
}) async* {
  yield* emitReasoning(reasoning, details: reasoningDetails);
  yield* emitText(content);
  yield* emitFinish(usage: usage, totalTokens: totalTokens);
}

Stream<StreamChunk> emitToolCalls(
  List<ToolCallInfo> calls, {
  TokenUsage? usage,
  int totalTokens = 0,
}) async* {
  yield* emitUsage(_usageOrApprox(usage, totalTokens));
  for (final call in calls) {
    yield ToolCallStart(
      id: call.id,
      toolName: call.name,
      metadata: call.metadata,
    );
    if (call.arguments.isNotEmpty) {
      yield ToolCallDelta(id: call.id, inputDelta: jsonEncode(call.arguments));
    }
    yield ToolCallEnd(call.id);
  }
}

// Local Kelivo-executed results reuse ServerTool until P5 lifts the tool
// loop. Handler payload `server` is therefore true for these too.
Stream<StreamChunk> emitToolResults(
  List<ToolResultInfo> results, {
  TokenUsage? usage,
  int totalTokens = 0,
}) async* {
  yield* emitUsage(_usageOrApprox(usage, totalTokens));
  for (final result in results) {
    yield ServerToolStart(
      id: result.id,
      toolName: result.name,
      metadata: result.metadata,
    );
    yield ServerToolEnd(
      id: result.id,
      input: result.arguments,
      output: result.content,
      metadata: result.metadata,
    );
  }
}
