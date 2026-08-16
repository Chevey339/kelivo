import 'package:Kelivo/core/services/api/chat_api_service.dart';
import 'package:Kelivo/core/services/api/stream/stream_chunk.dart';
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
        finish: () => emitFinish(),
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
        finish: () => emitFinish(),
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
        finish: () => emitFinish(),
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
      finish: () => emitFinish(),
    ).toList();

    expect(sends, 2);
    expect(chunks.whereType<TextDelta>(), hasLength(2));
    expect(chunks.whereType<Finish>(), hasLength(1));
  });
}
