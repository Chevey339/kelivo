import '../../../models/token_usage.dart';
import '../chat_api_helpers.dart';
import '../stream/stream_chunk.dart';
import '../stream/stream_chunk_emit.dart';

final class ExecutedClientTool {
  const ExecutedClientTool({required this.call, required this.content});

  final EmitToolCall call;
  final String content;
}

/// Execute [calls] and yield [ToolCallResult]s (and optionally [ToolCall*]).
Stream<StreamChunk> executeClientTools({
  required List<EmitToolCall> calls,
  required ToolCallHandler onToolCall,
  bool emitCalls = false,
  TokenUsage? usage,
  int totalTokens = 0,
}) async* {
  if (calls.isEmpty) return;
  if (emitCalls) {
    yield* emitToolCalls(calls, usage: usage, totalTokens: totalTokens);
  }
  final results = <EmitToolResult>[];
  for (final call in calls) {
    final content = await onToolCall(
      call.name,
      call.arguments,
      toolCallId: call.id,
    );
    results.add(
      emitToolResult(
        id: call.id,
        name: call.name,
        arguments: call.arguments,
        content: content,
        metadata: call.metadata,
      ),
    );
  }
  yield* emitToolResults(results, usage: usage, totalTokens: totalTokens);
}

/// After-round client-tool loop: execute → append → send follow-up → repeat.
///
/// The host owns protocol-specific HTTP and transcript shape. This runner
/// owns execute + [ToolCallResult] emit + the loop.
///
/// Two entries stay on purpose. [runProviderToolRounds] owns the first HTTP
/// round via [sendRound] (Claude / Gemini). OpenAI's first round is consumed
/// by the caller (`await for` SSE or one-shot JSON); only later rounds enter
/// [runClientToolFollowUps]. Unifying stream/non-stream return types does not
/// change who drives the first request, so these cannot merge.
Stream<StreamChunk> runClientToolFollowUps({
  required List<EmitToolCall> initialCalls,
  required ToolCallHandler onToolCall,
  required void Function(List<ExecutedClientTool> executed) append,
  required Stream<StreamChunk> Function() sendFollowUp,
  required List<EmitToolCall> Function() takeCallsAfterRound,
  required Stream<StreamChunk> Function() finish,
  bool emitCalls = false,
  TokenUsage? Function()? usageOf,
}) async* {
  var calls = List<EmitToolCall>.from(initialCalls);
  while (calls.isNotEmpty) {
    final usage = usageOf?.call();
    final totalTokens = usage?.totalTokens ?? 0;
    final executed = <ExecutedClientTool>[];
    // Do not clear [emitCalls] after the first round. OpenAI non-stream
    // follow-ups have no decoder emitting ToolCall*, so later rounds would
    // otherwise land as ToolCallResult-only cards with empty name/args.
    if (emitCalls) {
      yield* emitToolCalls(calls, usage: usage, totalTokens: totalTokens);
    }
    for (final call in calls) {
      executed.add(
        ExecutedClientTool(
          call: call,
          content: await onToolCall(
            call.name,
            call.arguments,
            toolCallId: call.id,
          ),
        ),
      );
    }
    yield* emitToolResults(
      [
        for (final item in executed)
          emitToolResult(
            id: item.call.id,
            name: item.call.name,
            arguments: item.call.arguments,
            content: item.content,
            metadata: item.call.metadata,
          ),
      ],
      usage: usage,
      totalTokens: totalTokens,
    );
    append(executed);
    yield* sendFollowUp();
    calls = takeCallsAfterRound();
  }
  yield* finish();
}

/// In-round loop used by Claude / Gemini: send (and maybe execute mid-stream),
/// then append and repeat until [takeCalls] and [continueWithoutCalls] are both
/// empty/false.
Stream<StreamChunk> runProviderToolRounds({
  required Stream<StreamChunk> Function() sendRound,
  required List<EmitToolCall> Function() takeCalls,
  required void Function(List<ExecutedClientTool> executed) append,
  required bool Function() continueWithoutCalls,
  required Stream<StreamChunk> Function() finish,
  ToolCallHandler? onToolCall,
  bool emitCalls = false,
  bool executeAfterRound = true,
  TokenUsage? Function()? usageOf,
}) async* {
  while (true) {
    yield* sendRound();
    final calls = takeCalls();
    if (calls.isEmpty && !continueWithoutCalls()) {
      yield* finish();
      return;
    }
    final executed = <ExecutedClientTool>[];
    if (executeAfterRound && calls.isNotEmpty && onToolCall != null) {
      final usage = usageOf?.call();
      final totalTokens = usage?.totalTokens ?? 0;
      if (emitCalls) {
        yield* emitToolCalls(calls, usage: usage, totalTokens: totalTokens);
      }
      for (final call in calls) {
        executed.add(
          ExecutedClientTool(
            call: call,
            content: await onToolCall(
              call.name,
              call.arguments,
              toolCallId: call.id,
            ),
          ),
        );
      }
      yield* emitToolResults(
        [
          for (final item in executed)
            emitToolResult(
              id: item.call.id,
              name: item.call.name,
              arguments: item.call.arguments,
              content: item.content,
              metadata: item.call.metadata,
            ),
        ],
        usage: usage,
        totalTokens: totalTokens,
      );
    }
    append(executed);
  }
}
