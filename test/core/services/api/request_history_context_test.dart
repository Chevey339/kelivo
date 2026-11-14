import 'package:Kelivo/core/models/image_context.dart';
import 'dart:convert';
import 'package:Kelivo/core/models/native_compaction.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/api/request_history_context.dart';
import 'package:Kelivo/core/services/api/request_image_context.dart';
import 'package:Kelivo/core/services/api/providers/openai/openai_provider.dart';
import 'package:Kelivo/core/services/api/providers/claude_official.dart';
import 'package:Kelivo/core/services/api/providers/google_gemini.dart';
import 'package:Kelivo/core/services/api/providers/google_vertex.dart';
import 'package:Kelivo/core/services/api/stream/stream_chunk.dart';
import 'package:Kelivo/core/services/chat/chat_context_reader.dart';

Map<String, dynamic> response(String protocol, bool tool) {
  if (protocol == 'claude' || protocol == 'vertex') {
    return {
      'id': 'msg',
      'type': 'message',
      'role': 'assistant',
      'content': [
        if (tool)
          {
            'type': 'tool_use',
            'id': 'call-1',
            'name': 'write',
            'input': {'value': 'once'},
          }
        else
          {'type': 'text', 'text': 'done'},
      ],
      'stop_reason': tool ? 'tool_use' : 'end_turn',
    };
  }
  if (protocol == 'google') {
    return {
      'candidates': [
        {
          'content': {
            'role': 'model',
            'parts': [
              if (tool)
                {
                  'functionCall': {
                    'name': 'write',
                    'args': {'value': 'once'},
                    'id': 'call-1',
                  },
                }
              else
                {'text': 'done'},
            ],
          },
          'finishReason': 'STOP',
        },
      ],
    };
  }
  if (protocol == 'responses') {
    return {
      'id': 'resp',
      'status': 'completed',
      'output': [
        if (tool)
          {
            'id': 'fc',
            'type': 'function_call',
            'call_id': 'call-1',
            'name': 'write',
            'arguments': '{"value":"once"}',
          }
        else
          {
            'id': 'text',
            'type': 'message',
            'role': 'assistant',
            'content': [
              {'type': 'output_text', 'text': 'done'},
            ],
          },
      ],
    };
  }
  return {
    'choices': [
      {
        'index': 0,
        'message': {
          'role': 'assistant',
          'content': tool ? '' : 'done',
          if (tool)
            'tool_calls': [
              {
                'id': 'call-1',
                'type': 'function',
                'function': {'name': 'write', 'arguments': '{"value":"once"}'},
              },
            ],
        },
        'finish_reason': tool ? 'tool_calls' : 'stop',
      },
    ],
  };
}

String wireResponse(
  String protocol,
  bool tool,
  bool stream, {
  String? finishReason,
}) {
  final value = response(protocol, tool);
  if (finishReason != null) {
    switch (protocol) {
      case 'claude' || 'vertex':
        value['stop_reason'] = finishReason;
      case 'google':
        (value['candidates'] as List).first['finishReason'] = finishReason;
      case 'responses':
        value['status'] = 'incomplete';
        value['incomplete_details'] = {'reason': finishReason};
      default:
        (value['choices'] as List).first['finish_reason'] = finishReason;
    }
  }
  if (!stream) return jsonEncode(value);
  final events = <Map<String, dynamic>>[];
  if (protocol == 'claude' || protocol == 'vertex') {
    events.add({
      'type': 'message_start',
      'message': {
        'id': 'm',
        'type': 'message',
        'role': 'assistant',
        'content': [],
      },
    });
    events.add({
      'type': 'content_block_start',
      'index': 0,
      'content_block': tool
          ? {'type': 'tool_use', 'id': 'call-1', 'name': 'write', 'input': {}}
          : {'type': 'text', 'text': ''},
    });
    events.add({
      'type': 'content_block_delta',
      'index': 0,
      'delta': tool
          ? {'type': 'input_json_delta', 'partial_json': '{"value":"once"}'}
          : {'type': 'text_delta', 'text': 'done'},
    });
    events.add({'type': 'content_block_stop', 'index': 0});
    events.add({
      'type': 'message_delta',
      'delta': {'stop_reason': value['stop_reason']},
    });
    events.add({'type': 'message_stop'});
  } else if (protocol == 'responses') {
    final item = (value['output'] as List).single as Map<String, dynamic>;
    events.add({
      'type': 'response.output_item.added',
      'output_index': 0,
      'item': {...item, if (tool) 'arguments': ''},
    });
    if (tool) {
      events.add({
        'type': 'response.function_call_arguments.delta',
        'item_id': 'fc',
        'output_index': 0,
        'delta': '{"value":"once"}',
      });
    }
    if (!tool) {
      events.add({
        'type': 'response.output_text.delta',
        'item_id': 'text',
        'output_index': 0,
        'content_index': 0,
        'delta': 'done',
      });
    }
    events.add({
      'type': 'response.output_item.done',
      'output_index': 0,
      'item': item,
    });
    events.add({'type': 'response.${value['status']}', 'response': value});
  } else if (protocol == 'google') {
    events.add(value);
  } else {
    final choice = (value['choices'] as List).single as Map;
    events.add({
      'choices': [
        {
          'index': 0,
          'delta': choice['message'],
          'finish_reason': choice['finish_reason'],
        },
      ],
    });
  }
  return '${events.map((e) => '${e['type'] == null ? '' : 'event: ${e['type']}\n'}data: ${jsonEncode(e)}\n\n').join()}${protocol == 'chat' ? 'data: [DONE]\n\n' : ''}';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'nested summary detaches history and image scopes, then restores the caller',
    () async {
      final history = RequestHistoryContext(
        currentUserId: 'u',
        targetMessageId: 'a',
        beforeRequest: (_, _, _) async => null,
        isCancelled: () => false,
      );
      final images = RequestImageContext(
        settings: const ImageContextSettings(),
        images: const [],
      );
      Stream<void> summary() async* {
        expect(RequestHistoryContext.current, isNull);
        expect(RequestImageContext.current, isNull);
        yield null;
      }

      Stream<void> parent() async* {
        await for (final _ in RequestHistoryContext.without(
          () => RequestImageContext.without(summary),
        )) {
          expect(RequestHistoryContext.current, same(history));
          expect(RequestImageContext.current, same(images));
        }
        yield null;
      }

      await history.run(() => images.run(parent)).drain<void>();
    },
  );

  for (final streaming in [false, true]) {
    test(
      'native automatic replacement preserves a live tool round: stream=$streaming',
      () async {
        final payload = NativeCompactionPayload(
          protocol: NativeCompactionProtocol.compact,
          scope: 'test',
          modelId: 'test',
          output: [
            {
              'type': 'compaction',
              'id': 'c',
              'encrypted_content': 'NATIVE_STATE',
            },
            {'type': 'future_item', 'keep': true},
          ],
        );
        final requests = <Map<String, dynamic>>[];
        var toolsRun = 0;
        final client = MockClient((request) async {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          requests.add(body);
          final tool = requests.length == 1;
          return http.Response(wireResponse('responses', tool, streaming), 200);
        });
        final history = RequestHistoryContext(
          currentUserId: 'current',
          targetMessageId: 'reply',
          nativeCompression: true,
          isCancelled: () => false,
          beforeRequest: (body, project, overflow) async {
            if (toolsRun == 0) return null;
            return [
              {
                'role': 'user',
                'content': '',
                imageContextOwnerKey: 'context-summary:native',
                nativeCompactionMessageKey: payload.toJson(),
              },
              {
                'role': 'user',
                'content': 'CURRENT',
                imageContextOwnerKey: 'current',
              },
            ];
          },
        );
        final config = ProviderConfig(
          id: 'custom',
          name: 'custom',
          enabled: true,
          apiKey: 'test',
          baseUrl: 'https://custom.example/v1',
          useResponseApi: true,
        );
        await history
            .run(
              () => sendOpenAIStream(
                client,
                config,
                'unknown-model',
                [
                  {'role': 'user', 'content': 'OLD', historySourceKey: 'old'},
                  {
                    'role': 'user',
                    'content': 'CURRENT',
                    historySourceKey: 'current',
                  },
                ],
                stream: streaming,
                onToolCall: (name, args, {toolCallId}) async {
                  toolsRun++;
                  return 'ALREADY_EXECUTED';
                },
              ),
            )
            .drain<void>();
        expect(toolsRun, 1);
        expect(requests, hasLength(2));
        final input = requests.last['input'] as List;
        expect(input.take(2).toList(), payload.output);
        expect(jsonEncode(input), contains('CURRENT'));
        expect(jsonEncode(input), contains('ALREADY_EXECUTED'));
        expect(jsonEncode(input), isNot(contains('OLD')));
        expect(jsonEncode(input), isNot(contains('_kelivo')));
      },
    );
  }

  for (final protocol in ['chat', 'responses', 'claude', 'google', 'vertex']) {
    for (final streaming in [false, true]) {
      test(
        '$protocol preserves output-limit finish reason stream=$streaming',
        () async {
          final reason = switch (protocol) {
            'claude' || 'vertex' => 'max_tokens',
            'google' => 'MAX_TOKENS',
            'responses' => 'max_output_tokens',
            _ => 'length',
          };
          final client = MockClient(
            (_) async => http.Response(
              wireResponse(protocol, false, streaming, finishReason: reason),
              200,
              headers: {
                'content-type': streaming
                    ? 'text/event-stream'
                    : 'application/json',
              },
            ),
          );
          addTearDown(client.close);
          final config = ProviderConfig(
            id: 'test',
            enabled: true,
            name: 'test',
            apiKey: 'unused',
            baseUrl: 'https://example.test/v1',
            providerType: protocol == 'claude'
                ? ProviderKind.claude
                : ['google', 'vertex'].contains(protocol)
                ? ProviderKind.google
                : ProviderKind.openai,
            useResponseApi: protocol == 'responses',
          );
          final messages = <Map<String, dynamic>>[
            {'role': 'user', 'content': 'summarize'},
          ];
          final chunksFuture = switch (protocol) {
            'claude' => sendClaudeStream(
              client,
              config,
              'claude-sonnet-4',
              messages,
              stream: streaming,
            ),
            'vertex' => sendGoogleVertexClaudeStream(
              client: client,
              config: config,
              modelId: 'claude-sonnet-4',
              messages: messages,
              stream: streaming,
            ),
            'google' => sendGoogleGeminiStream(
              client,
              config,
              'gemini-2.5-pro',
              messages,
              stream: streaming,
            ),
            _ => sendOpenAIStream(
              client,
              config,
              'deepseek-v4-flash',
              messages,
              stream: streaming,
            ),
          }.toList();
          // Both Responses transports expose partial output/usage and then
          // fail the turn, so a truncated response never becomes a success.
          if (protocol == 'responses') {
            await expectLater(
              chunksFuture,
              throwsA(
                predicate(
                  (error) => error.toString().contains('max_output_tokens'),
                ),
              ),
            );
          } else {
            final chunks = await chunksFuture;
            expect(chunks.whereType<Finish>().last.finishReason, reason);
          }
        },
      );
    }
    for (final (beforeFirst, streaming) in [
      (false, false),
      (true, false),
      (false, true),
    ]) {
      test(
        '$protocol replaces source prefix ${beforeFirst ? 'before send' : 'inside tool loop'} without repeating tools stream=$streaming',
        () async {
          final requests = <Map<String, dynamic>>[];
          final client = MockClient((request) async {
            requests.add(jsonDecode(request.body) as Map<String, dynamic>);
            return http.Response(
              wireResponse(protocol, requests.length == 1, streaming),
              200,
              headers: {
                'content-type': streaming
                    ? 'text/event-stream'
                    : 'application/json',
              },
            );
          });
          addTearDown(client.close);
          final config = ProviderConfig(
            id: 'test',
            enabled: true,
            name: 'test',
            apiKey: 'unused',
            baseUrl: 'https://example.test/v1',
            providerType: protocol == 'claude'
                ? ProviderKind.claude
                : ['google', 'vertex'].contains(protocol)
                ? ProviderKind.google
                : ProviderKind.openai,
            useResponseApi: protocol == 'responses',
          );
          final messages = RequestHistoryContext.identify([
            {'role': 'system', 'content': 'OLD_RULES'},
            {
              'role': 'user',
              'content': 'OLD_FACTS',
              imageContextOwnerKey: 'old-user',
            },
            {
              'role': 'assistant',
              'content': 'OLD_ANSWER',
              imageContextOwnerKey: 'old-assistant',
            },
            {
              'role': 'user',
              'content': 'CURRENT_QUESTION',
              imageContextOwnerKey: 'current',
            },
          ]);
          final replacement = <Map<String, dynamic>>[
            {'role': 'system', 'content': 'CURRENT_RULES'},
            {
              'role': 'user',
              'content': 'HISTORY_SUMMARY',
              imageContextOwnerKey: 'context-summary:summary',
            },
            {
              'role': 'user',
              'content': 'CURRENT_QUESTION',
              imageContextOwnerKey: 'current',
            },
          ];
          var projected = false;
          final history = RequestHistoryContext(
            currentUserId: 'current',
            targetMessageId: 'answer',
            isCancelled: () => false,
            beforeRequest: (body, project, overflow) async {
              if (!projected && (beforeFirst || requests.isNotEmpty)) {
                final candidate = project(replacement);
                expect(jsonEncode(candidate), isNot(contains('OLD_FACTS')));
                projected = true;
                return replacement;
              }
              return null;
            },
          );
          var toolsRun = 0;
          Future<Object?> onTool(
            String name,
            Map<String, dynamic> args, {
            String? toolCallId,
          }) async {
            toolsRun++;
            return 'SIDE_EFFECT_ALREADY_DONE';
          }

          final tools = [
            {
              'type': 'function',
              'function': {
                'name': 'write',
                'parameters': {
                  'type': 'object',
                  'properties': {
                    'value': {'type': 'string'},
                  },
                },
              },
            },
          ];
          Stream<StreamChunk> send() => switch (protocol) {
            'claude' => sendClaudeStream(
              client,
              config,
              'claude-sonnet-4',
              messages,
              tools: tools,
              onToolCall: onTool,
              stream: streaming,
            ),
            'vertex' => sendGoogleVertexClaudeStream(
              client: client,
              config: config,
              modelId: 'claude-sonnet-4',
              messages: messages,
              tools: tools,
              onToolCall: onTool,
              stream: streaming,
            ),
            'google' => sendGoogleGeminiStream(
              client,
              config,
              'gemini-2.5-pro',
              messages,
              tools: tools,
              onToolCall: onTool,
              stream: streaming,
            ),
            _ => sendOpenAIStream(
              client,
              config,
              'deepseek-v4-flash',
              messages,
              tools: tools,
              onToolCall: onTool,
              stream: streaming,
            ),
          };
          await history.run(send).drain<void>();
          expect(requests, hasLength(2));
          expect(toolsRun, 1);
          final last = jsonEncode(requests.last);
          expect(last, contains('HISTORY_SUMMARY'));
          expect(last, contains('CURRENT_QUESTION'));
          expect(last, contains('CURRENT_RULES'));
          expect(last, contains('SIDE_EFFECT_ALREADY_DONE'));
          expect(last, isNot(contains('OLD_FACTS')));
          expect(last, isNot(contains('OLD_ANSWER')));
          expect(last, isNot(contains('OLD_RULES')));
          expect(last, isNot(contains(historySourceKey)));
          expect(last, isNot(contains(toolSourceKey)));
        },
      );
    }
  }

  test(
    'reference projection is opt-in, keeps unread results, and gates reader',
    () async {
      final original = <String, dynamic>{
        'messages': [
          {'role': 'tool', 'tool_call_id': 'old', 'content': 'OLD_RESULT'},
          {'role': 'tool', 'tool_call_id': 'new', 'content': 'LATEST_RESULT'},
        ],
        'tools': [readChatContextDefinition],
      };
      final none = RequestHistoryContext.projectToolResults(original, {});
      expect(none.containsKey('tools'), isFalse);
      expect(jsonEncode(none), contains('OLD_RESULT'));
      final next = RequestHistoryContext.projectToolResults(original, {
        'old': 'ctx_ref',
      });
      expect(next['tools'], hasLength(1));
      expect(jsonEncode(next), contains('LATEST_RESULT'));
      expect(jsonEncode(next), isNot(contains('OLD_RESULT')));
      expect(jsonEncode(original), contains('OLD_RESULT'));
    },
  );

  test(
    'overflow recovery never retries the same rejected round twice',
    () async {
      var sends = 0;
      var recoveries = 0;
      final history = RequestHistoryContext(
        currentUserId: 'u',
        targetMessageId: 'a',
        isCancelled: () => false,
        beforeRequest: (_, _, overflow) async {
          if (overflow) recoveries++;
          return null;
        },
      )..format = HistoryWireFormat.chatCompletions;
      await history.prepare({
        'messages': [
          {'role': 'user', 'content': 'question', historySourceKey: 'u'},
        ],
      });
      Stream<int> failing() async* {
        sends++;
        throw StateError('context_length_exceeded');
      }

      await expectLater(
        history
            .recoverOverflow(() => history.recoverOverflow(failing))
            .drain<void>(),
        throwsStateError,
      );
      expect(sends, 1);
      expect(recoveries, 1);
    },
  );
}
