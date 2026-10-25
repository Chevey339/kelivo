import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/api/providers/claude_official.dart';
import 'package:Kelivo/core/services/api/providers/google_common.dart';
import 'package:Kelivo/core/services/api/providers/openai/openai_provider.dart';
import 'package:Kelivo/core/services/api/stream/stream_chunk_handler.dart';

Map<String, dynamic> _response(String transport, bool first, bool missing) {
  final prompt = first ? 100 : 200;
  final output = first ? 20 : 30;
  if (transport == 'gemini') {
    return {
      'candidates': [
        {
          'content': {
            'role': 'model',
            'parts': [
              if (first)
                {
                  'functionCall': {'name': 'lookup', 'args': {}},
                }
              else
                {'text': 'done'},
            ],
          },
          'finishReason': 'STOP',
        },
      ],
      if (!missing)
        'usageMetadata': {
          'promptTokenCount': prompt,
          'candidatesTokenCount': output - (first ? 5 : 0),
          'thoughtsTokenCount': first ? 5 : 0,
          'cachedContentTokenCount': first ? 10 : 60,
          'totalTokenCount': prompt + output,
        },
    };
  }
  if (transport == 'claude' || transport == 'vertex') {
    return {
      'id': first ? 'msg-1' : 'msg-2',
      'type': 'message',
      'role': 'assistant',
      'content': [
        if (first)
          {'type': 'tool_use', 'id': 'call-1', 'name': 'lookup', 'input': {}}
        else
          {'type': 'text', 'text': 'done'},
      ],
      'stop_reason': first ? 'tool_use' : 'end_turn',
      if (!missing)
        'usage': {
          'input_tokens': first ? 60 : 140,
          'output_tokens': output,
          'cache_read_input_tokens': first ? 10 : 60,
          'cache_creation_input_tokens': first ? 30 : 0,
        },
    };
  }
  final usage = {
    'prompt_tokens': prompt,
    'completion_tokens': output,
    'prompt_tokens_details': {'cached_tokens': first ? 10 : 60},
    'completion_tokens_details': {'reasoning_tokens': first ? 5 : 0},
    'total_tokens': prompt + output,
  };
  if (transport == 'responses') {
    return {
      'id': first ? 'resp-1' : 'resp-2',
      'output': [
        if (first)
          {
            'id': 'fc-1',
            'type': 'function_call',
            'call_id': 'call-1',
            'name': 'lookup',
            'arguments': '{}',
          }
        else
          {
            'id': 'm-2',
            'type': 'message',
            'role': 'assistant',
            'content': [
              {'type': 'output_text', 'text': 'done'},
            ],
          },
      ],
      if (!missing) 'usage': usage,
    };
  }
  return {
    'choices': [
      {
        'index': 0,
        'message': {
          'role': 'assistant',
          'content': first ? '' : 'done',
          if (first)
            'tool_calls': [
              {
                'index': 0,
                'id': 'call-1',
                'type': 'function',
                'function': {'name': 'lookup', 'arguments': '{}'},
              },
            ],
        },
        'finish_reason': first ? 'tool_calls' : 'stop',
      },
    ],
    if (!missing) 'usage': usage,
  };
}

String _sse(String transport, Map<String, dynamic> body) {
  final events = <Map<String, dynamic>>[];
  if (transport == 'gemini') {
    events.add(body);
  } else if (transport == 'claude' || transport == 'vertex') {
    final usage = body['usage'] as Map?;
    events.add({
      'type': 'message_start',
      'message': {
        'id': body['id'],
        'type': 'message',
        'role': 'assistant',
        if (usage != null) 'usage': {...usage, 'output_tokens': 0},
      },
    });
    final content = (body['content'] as List).single as Map;
    events.add({
      'type': 'content_block_start',
      'index': 0,
      'content_block': content,
    });
    events.add({'type': 'content_block_stop', 'index': 0});
    events.add({
      'type': 'message_delta',
      'delta': {'stop_reason': body['stop_reason']},
      if (usage != null) 'usage': {'output_tokens': usage['output_tokens']},
    });
    events.add({'type': 'message_stop'});
  } else if (transport == 'responses') {
    for (final item in body['output'] as List) {
      events.add({
        'type': 'response.output_item.added',
        'output_index': 0,
        'item': item,
      });
      if (item['type'] == 'message') {
        events.add({
          'type': 'response.output_text.delta',
          'output_index': 0,
          'item_id': item['id'],
          'delta': 'done',
        });
      }
      events.add({
        'type': 'response.output_item.done',
        'output_index': 0,
        'item': item,
      });
    }
    events.add({'type': 'response.completed', 'response': body});
  } else {
    final choice = (body['choices'] as List).single as Map;
    events.add({
      'choices': [
        {'index': 0, 'delta': choice['message']},
      ],
    });
    events.add({
      'choices': [
        {'index': 0, 'delta': {}, 'finish_reason': choice['finish_reason']},
      ],
    });
    if (body['usage'] != null) {
      // Repeated snapshots of one request must count only once.
      events.add({'choices': [], 'usage': body['usage']});
      events.add({'choices': [], 'usage': body['usage']});
    }
  }
  return events.map((event) => 'data: ${jsonEncode(event)}\n\n').join();
}

void main() {
  for (final transport in ['chat', 'responses', 'claude', 'vertex', 'gemini']) {
    for (final stream in [false, true]) {
      for (final missingFinalUsage in [false, true]) {
        test(
          '$transport stream=$stream missingFinal=$missingFinalUsage',
          () async {
            var requests = 0;
            final client = MockClient((request) async {
              final first = requests++ == 0;
              final body = _response(
                transport,
                first,
                !first && missingFinalUsage,
              );
              return http.Response(
                stream ? _sse(transport, body) : jsonEncode(body),
                200,
                headers: {
                  'content-type': stream
                      ? 'text/event-stream'
                      : 'application/json',
                },
              );
            });
            addTearDown(client.close);
            final openai = transport == 'chat' || transport == 'responses';
            final config = ProviderConfig(
              id: 'Test',
              enabled: true,
              name: 'Test',
              apiKey: 'k',
              providerType: openai
                  ? ProviderKind.openai
                  : transport == 'claude'
                  ? ProviderKind.claude
                  : ProviderKind.google,
              baseUrl: transport == 'vertex'
                  ? 'https://aiplatform.googleapis.com'
                  : 'https://example.test',
              vertexAI: transport == 'vertex',
              projectId: 'test-project',
              location: 'global',
              useResponseApi: transport == 'responses',
            );
            final send = openai
                ? sendOpenAIStream
                : transport == 'claude'
                ? sendClaudeStream
                : sendGoogleStream;
            final chunks = await send(
              client,
              config,
              openai
                  ? 'gpt-4o'
                  : transport == 'gemini'
                  ? 'gemini-2.5-flash'
                  : 'claude-sonnet-4-5',
              const [
                {'role': 'user', 'content': 'look up'},
              ],
              stream: stream,
              tools: const [
                {
                  'type': 'function',
                  'function': {
                    'name': 'lookup',
                    'parameters': {
                      'type': 'object',
                      'properties': <String, dynamic>{},
                    },
                  },
                },
              ],
              onToolCall: (name, arguments, {toolCallId}) async => 'ok',
            ).toList();
            final result = StreamChunkHandler.collect(chunks);
            expect(requests, 2);
            expect(result.usage!.totalTokens, missingFinalUsage ? 0 : 230);
            expect(
              result.totalUsage!.promptTokens,
              missingFinalUsage ? 100 : 300,
            );
            expect(
              result.totalUsage!.completionTokens,
              missingFinalUsage ? 20 : 50,
            );
            expect(
              result.totalUsage!.cachedTokens,
              missingFinalUsage ? 10 : 70,
            );
            expect(
              result.totalUsage!.totalTokens,
              missingFinalUsage ? 120 : 350,
            );
            final claude = transport == 'claude' || transport == 'vertex';
            expect(result.totalUsage!.cacheWriteTokens, claude ? 30 : 0);
            expect(result.totalUsage!.reasoningTokens, claude ? 0 : 5);
          },
        );
      }
    }
  }
}
