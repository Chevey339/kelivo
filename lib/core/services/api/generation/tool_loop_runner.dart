part of '../chat_api_service.dart';

final class ExecutedClientTool {
  const ExecutedClientTool({required this.call, required this.content});

  final EmitToolCall call;
  final String content;
}

List<EmitToolCall> clientToolCallsFromChatAcc(Map<dynamic, dynamic> toolAcc) {
  final calls = <EmitToolCall>[];
  final keys = toolAcc.keys.toList()
    ..sort((a, b) {
      final ai = a is int ? a : int.tryParse(a.toString()) ?? 0;
      final bi = b is int ? b : int.tryParse(b.toString()) ?? 0;
      return ai.compareTo(bi);
    });
  for (final key in keys) {
    final raw = toolAcc[key];
    if (raw is! Map) continue;
    final id = _effectiveToolCallId(raw['id'], 'call', key);
    final name = (raw['name'] ?? '').toString();
    Map<String, dynamic> arguments;
    try {
      arguments = (jsonDecode((raw['args'] ?? '{}').toString()) as Map)
          .cast<String, dynamic>();
    } catch (_) {
      arguments = <String, dynamic>{};
    }
    calls.add(emitToolCall(id: id, name: name, arguments: arguments));
  }
  return calls;
}

List<Map<String, dynamic>> openaiToolCallMaps(List<EmitToolCall> calls) {
  return [
    for (final call in calls)
      <String, dynamic>{
        'id': call.id,
        'type': 'function',
        'function': <String, dynamic>{
          'name': call.name,
          'arguments': jsonEncode(call.arguments),
        },
      },
  ];
}

List<Map<String, dynamic>> openaiToolResultMessages(
  List<ExecutedClientTool> executed,
) {
  return [
    for (final item in executed)
      <String, dynamic>{
        'role': 'tool',
        'tool_call_id': item.call.id,
        'name': item.call.name,
        'content': item.content,
      },
  ];
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
  var shouldEmitCalls = emitCalls;
  while (calls.isNotEmpty) {
    final usage = usageOf?.call();
    final totalTokens = usage?.totalTokens ?? 0;
    final executed = <ExecutedClientTool>[];
    if (shouldEmitCalls) {
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
    shouldEmitCalls = false;
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
