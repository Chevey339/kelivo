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
  String? finishReason,
}) async* {
  yield* emitReasoning(null, details: reasoningDetails);
  yield* emitUsage(_usageOrApprox(usage, totalTokens));
  yield Finish(finishReason: finishReason);
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
  String? finishReason,
}) async* {
  yield* emitReasoning(reasoning, details: reasoningDetails);
  yield* emitText(content);
  yield* emitFinish(
    usage: usage,
    totalTokens: totalTokens,
    finishReason: finishReason,
  );
}

Stream<StreamChunk> emitImages(
  Iterable<({String uri, String mimeType})> images,
) async* {
  final ids = StreamChunkIds('images');
  for (final image in images) {
    if (image.uri.isEmpty) continue;
    final id = ids.next('image');
    yield ImageStart(id: id, mimeType: image.mimeType);
    yield ImageSnapshot(
      id: id,
      data: completeRenderableImageUri(image.uri, mimeType: image.mimeType),
    );
    yield ImageEnd(id);
  }
}

typedef EmitToolCall = ({
  String id,
  String name,
  Map<String, dynamic> arguments,
  Map<String, dynamic>? metadata,
});

typedef EmitToolResult = ({
  String id,
  String name,
  Map<String, dynamic> arguments,
  String content,
  Map<String, dynamic>? metadata,
});

EmitToolCall emitToolCall({
  required String id,
  required String name,
  required Map<String, dynamic> arguments,
  Map<String, dynamic>? metadata,
}) => (id: id, name: name, arguments: arguments, metadata: metadata);

EmitToolResult emitToolResult({
  required String id,
  required String name,
  required Map<String, dynamic> arguments,
  required String content,
  Map<String, dynamic>? metadata,
}) => (
  id: id,
  name: name,
  arguments: arguments,
  content: content,
  metadata: metadata,
);

Stream<StreamChunk> emitToolCalls(
  List<EmitToolCall> calls, {
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

Stream<StreamChunk> emitToolResults(
  List<EmitToolResult> results, {
  TokenUsage? usage,
  int totalTokens = 0,
}) async* {
  yield* emitUsage(_usageOrApprox(usage, totalTokens));
  for (final result in results) {
    yield ToolCallResult(
      id: result.id,
      output: result.content,
      metadata: result.metadata,
    );
  }
}
