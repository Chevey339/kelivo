import 'package:Kelivo/core/models/token_usage.dart';
import 'package:Kelivo/core/services/api/chat_api_service.dart';
import 'package:Kelivo/core/services/api/stream/stream_chunk.dart';
import 'package:Kelivo/core/services/api/stream/stream_chunk_handler.dart';
import 'package:Kelivo/core/services/api/stream/stream_chunk_ids.dart';
import 'package:Kelivo/utils/mcp_structured_image.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('executeClientTools emits ToolCall* then ToolCallResult', () async {
    final chunks = await executeClientTools(
      calls: [
        emitToolCall(
          id: 'call_1',
          name: 'lookup',
          arguments: const <String, dynamic>{'q': 'kelivo'},
        ),
      ],
      onToolCall: (name, args, {toolCallId}) async => '{"ok":true}',
      emitCalls: true,
    ).toList();

    expect(chunks.whereType<ToolCallStart>().single.id, 'call_1');
    expect(chunks.whereType<ToolCallEnd>().single.id, 'call_1');
    expect(chunks.whereType<ToolCallResult>().single.output, '{"ok":true}');
    expect(chunks.whereType<ServerToolEnd>(), isEmpty);
  });

  test(
    'runClientToolFollowUps executes, appends, and stops when no more calls',
    () async {
      final appended = <String>[];
      var rounds = 0;
      final chunks = await runClientToolFollowUps(
        initialCalls: [
          emitToolCall(
            id: 'call_1',
            name: 'lookup',
            arguments: const <String, dynamic>{'q': '1'},
          ),
        ],
        onToolCall: (name, args, {toolCallId}) async => 'res-$toolCallId',
        append: (executed) {
          appended.addAll(executed.map((item) => item.content));
        },
        sendFollowUp: () async* {
          rounds += 1;
          yield const TextDelta(id: 't', text: 'done');
        },
        takeCallsAfterRound: () => const <EmitToolCall>[],
        finish: () => emitFinish(ids: StreamChunkIds('finish')),
      ).toList();

      expect(appended, ['res-call_1']);
      expect(rounds, 1);
      expect(chunks.whereType<ToolCallResult>().single.output, 'res-call_1');
      expect(chunks.whereType<TextDelta>().single.text, 'done');
      expect(chunks.whereType<Finish>(), hasLength(1));
    },
  );

  test(
    'runProviderToolRounds sends, executes after the round, then finishes',
    () async {
      var sends = 0;
      final appended = <int>[];
      final chunks = await runProviderToolRounds(
        sendRound: () async* {
          sends += 1;
          yield TextDelta(id: 't', text: 'round-$sends');
        },
        takeCalls: () => sends == 1
            ? [
                emitToolCall(
                  id: 'call_1',
                  name: 'lookup',
                  arguments: const <String, dynamic>{'q': '1'},
                ),
              ]
            : const <EmitToolCall>[],
        continueWithoutCalls: () => false,
        executeAfterRound: true,
        emitCalls: true,
        onToolCall: (name, args, {toolCallId}) async => 'res-$toolCallId',
        append: (executed) => appended.add(executed.length),
        finish: () => emitFinish(ids: StreamChunkIds('finish')),
      ).toList();

      expect(sends, 2);
      expect(appended, [1]);
      expect(chunks.whereType<ToolCallStart>(), hasLength(1));
      expect(chunks.whereType<ToolCallResult>().single.output, 'res-call_1');
      expect(chunks.whereType<Finish>(), hasLength(1));
    },
  );

  test(
    'runClientToolFollowUps still emits ToolCall* on later rounds',
    () async {
      var rounds = 0;
      final chunks = await runClientToolFollowUps(
        initialCalls: [
          emitToolCall(
            id: 'call_1',
            name: 'lookup',
            arguments: const <String, dynamic>{'q': '1'},
          ),
        ],
        onToolCall: (name, args, {toolCallId}) async => 'res-$toolCallId',
        append: (_) {},
        sendFollowUp: () async* {
          rounds += 1;
          yield TextDelta(id: 't-$rounds', text: 'round-$rounds');
        },
        takeCallsAfterRound: () => rounds == 1
            ? [
                emitToolCall(
                  id: 'call_2',
                  name: 'lookup',
                  arguments: const <String, dynamic>{'q': '2'},
                ),
              ]
            : const <EmitToolCall>[],
        finish: () => emitFinish(ids: StreamChunkIds('finish')),
        emitCalls: true,
      ).toList();

      expect(chunks.whereType<ToolCallStart>().map((chunk) => chunk.id), [
        'call_1',
        'call_2',
      ]);
      expect(chunks.whereType<ToolCallStart>().map((chunk) => chunk.toolName), [
        'lookup',
        'lookup',
      ]);
      expect(chunks.whereType<ToolCallResult>().map((chunk) => chunk.id), [
        'call_1',
        'call_2',
      ]);
    },
  );

  test('runProviderToolRounds continues without calls when asked', () async {
    var sends = 0;
    final chunks = await runProviderToolRounds(
      sendRound: () async* {
        sends += 1;
        yield TextDelta(id: 't', text: 'pause-$sends');
      },
      takeCalls: () => const <EmitToolCall>[],
      continueWithoutCalls: () => sends < 2,
      executeAfterRound: false,
      append: (_) {},
      finish: () => emitFinish(ids: StreamChunkIds('finish')),
    ).toList();

    expect(sends, 2);
    expect(chunks.whereType<TextDelta>(), hasLength(2));
    expect(chunks.whereType<Finish>(), hasLength(1));
  });

  test(
    'three tool-call rounds keep summed usage and do not double-count repeats',
    () async {
      const snapshots = [
        TokenUsage(promptTokens: 100, completionTokens: 20, totalTokens: 120),
        TokenUsage(promptTokens: 400, completionTokens: 60, totalTokens: 460),
        TokenUsage(promptTokens: 900, completionTokens: 70, totalTokens: 970),
      ];
      var sends = 0;
      TokenUsage? usage;
      final chunks = await runProviderToolRounds(
        sendRound: () async* {
          usage = snapshots[sends];
          sends += 1;
          yield Usage(usage!);
          yield TextDelta(id: 't-$sends', text: 'round-$sends');
        },
        takeCalls: () => sends < 3
            ? [
                emitToolCall(
                  id: 'call_$sends',
                  name: 'lookup',
                  arguments: <String, dynamic>{'q': '$sends'},
                ),
              ]
            : const <EmitToolCall>[],
        continueWithoutCalls: () => false,
        executeAfterRound: true,
        emitCalls: true,
        onToolCall: (name, args, {toolCallId}) async => 'res',
        append: (_) {},
        finish: () => emitFinish(ids: StreamChunkIds('finish'), usage: usage),
        usageOf: () => usage,
      ).toList();

      final result = StreamChunkHandler.collect(chunks);
      expect(result.usage!.promptTokens, 900);
      expect(result.usage!.completionTokens, 70);
      expect(result.usage!.totalTokens, 970);
      expect(chunks.whereType<Usage>().length, greaterThan(3));
    },
  );

  test('a silent round neither zeros nor double-counts prior usage', () async {
    const first = TokenUsage(
      promptTokens: 100,
      completionTokens: 20,
      totalTokens: 120,
    );
    const afterThird = TokenUsage(
      promptTokens: 600,
      completionTokens: 30,
      totalTokens: 630,
    );
    var sends = 0;
    TokenUsage? usage;
    final chunks = await runProviderToolRounds(
      sendRound: () async* {
        sends += 1;
        if (sends == 1) {
          usage = first;
          yield const Usage(first);
        } else if (sends == 3) {
          usage = afterThird;
          yield const Usage(afterThird);
        }
        yield TextDelta(id: 't-$sends', text: 'round-$sends');
      },
      takeCalls: () => sends < 3
          ? [
              emitToolCall(
                id: 'call_$sends',
                name: 'lookup',
                arguments: <String, dynamic>{'q': '$sends'},
              ),
            ]
          : const <EmitToolCall>[],
      continueWithoutCalls: () => false,
      executeAfterRound: true,
      emitCalls: true,
      onToolCall: (name, args, {toolCallId}) async => 'res',
      append: (_) {},
      finish: () => emitFinish(ids: StreamChunkIds('finish'), usage: usage),
      usageOf: () => usage,
    ).toList();

    final result = StreamChunkHandler.collect(chunks);
    expect(result.usage!.promptTokens, 600);
    expect(result.usage!.completionTokens, 30);
    expect(result.usage!.totalTokens, 630);
  });

  test(
    'streaming and non-streaming send Markdown to the model with mcpResult',
    () async {
      const markdown =
          'caption A\n![](https://cdn.example.com/a.png)\n'
          'caption B\n![](https://cdn.example.com/b.png)';
      final typed = const McpToolResult(
        markdown: markdown,
        imageUris: [
          'https://cdn.example.com/a.png',
          'https://cdn.example.com/b.png',
        ],
      );

      Future<Object?> onToolCall(
        String name,
        Map<String, dynamic> args, {
        String? toolCallId,
      }) async => typed;

      final streamed = await executeClientTools(
        calls: [
          emitToolCall(
            id: 'call_s',
            name: 'shot',
            arguments: const <String, dynamic>{},
            metadata: const {'anthropic': 'keep'},
          ),
        ],
        onToolCall: onToolCall,
      ).toList();

      ExecutedClientTool? appended;
      await runProviderToolRounds(
        sendRound: () async* {
          yield const TextDelta(id: 't', text: 'round');
        },
        takeCalls: () => appended == null
            ? [
                emitToolCall(
                  id: 'call_n',
                  name: 'shot',
                  arguments: const <String, dynamic>{},
                ),
              ]
            : const <EmitToolCall>[],
        continueWithoutCalls: () => false,
        executeAfterRound: true,
        onToolCall: onToolCall,
        append: (executed) {
          if (executed.isNotEmpty) appended = executed.single;
        },
        finish: () => emitFinish(ids: StreamChunkIds('finish')),
      ).toList();

      final streamResult = streamed.whereType<ToolCallResult>().single;
      expect(streamResult.output, markdown);
      expect(streamResult.output, isNot(contains('"kelivo"')));
      expect(mcpResultImageUris(readMcpResultMetadata(streamResult.metadata)), [
        'https://cdn.example.com/a.png',
        'https://cdn.example.com/b.png',
      ]);
      expect(streamResult.metadata!['anthropic'], 'keep');

      expect(appended, isNotNull);
      expect(appended!.content, markdown);
      expect(mcpResultImageUris(readMcpResultMetadata(appended!.metadata)), [
        'https://cdn.example.com/a.png',
        'https://cdn.example.com/b.png',
      ]);
    },
  );
}
