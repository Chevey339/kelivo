import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/core/models/message_part.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/chat/chat_service.dart';
import 'package:Kelivo/features/home/services/message_builder_service.dart';
import 'package:Kelivo/features/home/services/assistant_tool_history.dart';
import 'package:Kelivo/core/services/api/providers/openai/openai_provider.dart';
import 'package:Kelivo/core/services/api/request_image_context.dart';
import 'package:Kelivo/core/services/api/request_history_context.dart';
import 'package:Kelivo/core/services/api/providers/google_gemini.dart';
import 'package:Kelivo/core/services/api/providers/google_vertex.dart';
import 'package:Kelivo/core/services/api/providers/claude_official.dart';
import 'package:Kelivo/core/services/api/providers/claude/claude_history.dart';
import 'package:Kelivo/core/services/api/stream/stream_chunk.dart';
import 'package:Kelivo/core/services/api/stream/stream_chunk_handler.dart';
import 'package:Kelivo/core/utils/multimodal_input_utils.dart';
import 'package:Kelivo/utils/mcp_structured_image.dart';

import 'support/claude_test_api.dart' show sseRound;

class _Context extends Fake implements BuildContext {}

class _Chat extends ChatService {
  @override
  List<Map<String, dynamic>> getToolEvents(String assistantMessageId) =>
      const [];
}

const _tools = <Map<String, dynamic>>[
  {
    'type': 'function',
    'function': {
      'name': 'lookup',
      'parameters': {'type': 'object', 'properties': <String, dynamic>{}},
    },
  },
];
const _user = <Map<String, dynamic>>[
  {'role': 'user', 'content': 'Question'},
];

ProviderConfig _openai({bool router = false, bool responses = false}) =>
    ProviderConfig(
      id: router ? 'OpenRouter' : 'OpenAI',
      enabled: true,
      name: 'probe',
      apiKey: 'mock-only',
      baseUrl: router
          ? 'https://openrouter.ai/api/v1'
          : 'https://api.openai.com/v1',
      providerType: ProviderKind.openai,
      useResponseApi: responses,
      claudePromptCachingEnabled: true,
    );

http.Response _chatReply(bool call, bool stream, {String callId = 'call_1'}) {
  final message = <String, dynamic>{
    'role': 'assistant',
    'content': call ? '' : 'Done',
    if (call)
      'tool_calls': [
        {
          if (stream) 'index': 0,
          'id': callId,
          'type': 'function',
          'function': {'name': 'lookup', 'arguments': '{}'},
        },
      ],
  };
  final body = {
    'choices': [
      {
        'index': 0,
        stream ? 'delta' : 'message': message,
        'finish_reason': call ? 'tool_calls' : 'stop',
      },
    ],
  };
  return http.Response(
    stream ? 'data: ${jsonEncode(body)}\n\ndata: [DONE]\n\n' : jsonEncode(body),
    200,
  );
}

http.Response _responsesReply(
  bool call,
  bool stream, {
  String callId = 'call_1',
}) {
  final item = call
      ? <String, dynamic>{
          'type': 'function_call',
          'id': 'fc_$callId',
          'call_id': callId,
          'name': 'lookup',
          'arguments': '{}',
        }
      : <String, dynamic>{
          'type': 'message',
          'role': 'assistant',
          'content': [
            {'type': 'output_text', 'text': 'Done', 'annotations': <Object>[]},
          ],
        };
  final body = {
    'status': 'completed',
    'output': [item],
  };
  final events = [
    {'type': 'response.output_item.done', 'output_index': 0, 'item': item},
    {'type': 'response.completed', 'response': body},
  ];
  return http.Response(
    stream
        ? events.map((event) => 'data: ${jsonEncode(event)}\n\n').join()
        : jsonEncode(body),
    200,
  );
}

http.Response _claudeReply(
  List<Map<String, dynamic>> blocks,
  bool stream,
  String stop,
) {
  if (!stream) {
    return http.Response(
      jsonEncode({
        'content': blocks,
        'stop_reason': stop,
        'usage': {'input_tokens': 1, 'output_tokens': 1},
      }),
      200,
    );
  }
  return http.Response(
    sseRound('mock-message', [
      for (var i = 0; i < blocks.length; i++) ...[
        {'type': 'content_block_start', 'index': i, 'content_block': blocks[i]},
        if (blocks[i]['type'] == 'text')
          {
            'type': 'content_block_delta',
            'index': i,
            'delta': {'type': 'text_delta', 'text': blocks[i]['text']},
          },
        if (blocks[i]['type'] == 'thinking') ...[
          {
            'type': 'content_block_delta',
            'index': i,
            'delta': {
              'type': 'thinking_delta',
              'thinking': blocks[i]['thinking'],
            },
          },
          {
            'type': 'content_block_delta',
            'index': i,
            'delta': {
              'type': 'signature_delta',
              'signature': blocks[i]['signature'],
            },
          },
        ],
        if (blocks[i]['type'] == 'redacted_thinking')
          {
            'type': 'content_block_delta',
            'index': i,
            'delta': {
              'type': 'redacted_thinking_delta',
              'data': blocks[i]['data'],
            },
          },
        {'type': 'content_block_stop', 'index': i},
      ],
      {
        'type': 'message_delta',
        'delta': {'stop_reason': stop},
      },
      {'type': 'message_stop'},
    ]),
    200,
  );
}

void main() {
  for (final vertex in [false, true]) {
    test(
      'Claude assistant images skip injected user lore: vertex=$vertex',
      () async {
        late Map body;
        final client = MockClient((request) async {
          body = jsonDecode(request.body);
          return _claudeReply(
            [
              {'type': 'text', 'text': 'Done'},
            ],
            false,
            'end_turn',
          );
        });
        addTearDown(client.close);
        final config = ProviderConfig(
          id: vertex ? 'Vertex' : 'Claude',
          name: 'test',
          enabled: true,
          baseUrl: 'https://example.test',
          apiKey: 'mock-only',
          vertexAI: vertex,
          projectId: 'test',
          location: 'global',
          providerType: vertex ? ProviderKind.google : ProviderKind.claude,
        );
        final messages = <Map<String, dynamic>>[
          {
            'role': 'assistant',
            'content': 'A drawing',
            imageContextOwnerKey: 'assistant-id',
            multimodalInternalMediaPathsKey: [
              'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jFioAAAAASUVORK5CYII=',
            ],
          },
          {'role': 'user', 'content': 'Injected lore'},
          {
            'role': 'user',
            'content': 'Describe it',
            imageContextOwnerKey: 'user-id',
          },
        ];
        await (vertex
                ? sendGoogleVertexClaudeStream(
                    client: client,
                    config: config,
                    modelId: 'claude-sonnet-4-6',
                    messages: messages,
                    stream: false,
                  )
                : sendClaudeStream(
                    client,
                    config,
                    'claude-sonnet-4-6',
                    messages,
                    stream: false,
                  ))
            .toList();
        final counts = [
          for (final message in body['messages'] as List)
            (message['content'] is List ? message['content'] as List : const [])
                .where((part) => part['type'] == 'image')
                .length,
        ];
        expect(counts, [0, 0, 1]);
      },
    );
  }

  for (final protocol in ['chat', 'responses', 'gemini', 'claude', 'vertex']) {
    test(
      'attachments belong to the real user before tail lore: $protocol',
      () async {
        const image =
            'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jFioAAAAASUVORK5CYII=';
        final bodies = <Map<String, dynamic>>[];
        final client = MockClient((request) async {
          bodies.add(jsonDecode(request.body));
          return switch (protocol) {
            'chat' => _chatReply(bodies.length == 1, false),
            'responses' => _responsesReply(false, false),
            'gemini' => http.Response(
              jsonEncode({
                'candidates': [
                  {
                    'content': {
                      'parts': [
                        {'text': 'Done'},
                      ],
                    },
                    'finishReason': 'STOP',
                  },
                ],
              }),
              200,
            ),
            _ => _claudeReply(
              [
                {'type': 'text', 'text': 'Done'},
              ],
              false,
              'end_turn',
            ),
          };
        });
        addTearDown(client.close);
        final messages = <Map<String, dynamic>>[
          {
            'role': 'user',
            'content': 'Real question',
            imageContextOwnerKey: 'real-user-revision',
            multimodalInternalMediaPathsKey: [image],
          },
          {'role': 'user', 'content': '<system>Lore</system>'},
        ];
        if (protocol == 'chat' || protocol == 'responses') {
          await sendOpenAIStream(
            client,
            _openai(responses: protocol == 'responses'),
            'gpt-4o',
            messages,
            userImagePaths: [image],
            stream: false,
            tools: _tools,
            onToolCall: (_, _, {toolCallId}) async => 'result',
          ).toList();
        } else {
          final config = ProviderConfig(
            id: protocol,
            name: protocol,
            enabled: true,
            apiKey: 'mock-only',
            baseUrl: 'https://example.test',
            vertexAI: protocol == 'vertex',
            projectId: 'test',
            location: 'global',
            providerType: protocol == 'claude'
                ? ProviderKind.claude
                : ProviderKind.google,
          );
          if (protocol == 'claude') {
            await sendClaudeStream(
              client,
              config,
              'claude-sonnet-4-6',
              messages,
              userImagePaths: [image],
              stream: false,
            ).toList();
          } else if (protocol == 'vertex') {
            await sendGoogleVertexClaudeStream(
              client: client,
              config: config,
              modelId: 'claude-sonnet-4-6',
              messages: messages,
              userImagePaths: [image],
              stream: false,
            ).toList();
          } else {
            await sendGoogleGeminiStream(
              client,
              config,
              'gemini-3.8-flash',
              messages,
              userImagePaths: [image],
              stream: false,
            ).toList();
          }
        }
        for (final body in bodies) {
          final wire =
              (body['messages'] ?? body['input'] ?? body['contents']) as List;
          final counts = [
            for (final message in wire.take(2))
              ((message['parts'] ??
                          (message['content'] is List
                              ? message['content']
                              : const []))
                      as List)
                  .where(
                    (part) =>
                        [
                          'image_url',
                          'input_image',
                          'image',
                        ].contains(part['type']) ||
                        part['inlineData'] != null,
                  )
                  .length,
          ];
          expect(counts, [1, 0]);
          expect(jsonEncode(body), isNot(contains('_kelivo_')));
        }
      },
    );
  }

  for (final responses in [false, true]) {
    for (final stream in [false, true]) {
      for (final custom in [false, true]) {
        test(
          'cache continuity responses=$responses stream=$stream custom=$custom',
          () async {
            final bodies = <Map<String, dynamic>>[];
            var round = 0;
            final client = MockClient((request) async {
              bodies.add(jsonDecode(request.body));
              expect(bodies.length, lessThanOrEqualTo(4));
              // A failed continuation must retain the same options when retried.
              if (bodies.length == 2) return http.Response('retry', 500);
              round++;
              return responses
                  ? _responsesReply(round <= 2, stream, callId: 'call_$round')
                  : _chatReply(round <= 2, stream, callId: 'call_$round');
            });
            addTearDown(client.close);
            await sendOpenAIStream(
              client,
              _openai(router: true, responses: responses),
              'anthropic/claude-sonnet-4.6',
              _user,
              tools: _tools,
              onToolCall: (_, _, {toolCallId}) async => '{"x":1}',
              extraBody: custom
                  ? {
                      'cache_control': {'type': 'ephemeral', 'ttl': '1h'},
                    }
                  : null,
              retryRound: (sendRound) async* {
                try {
                  await for (final chunk in sendRound()) {
                    yield chunk;
                  }
                } on HttpException {
                  yield* sendRound();
                }
              },
              stream: stream,
            ).toList();
            expect(bodies, hasLength(4));
            for (final body in bodies) {
              expect(body['cache_control'], {
                'type': 'ephemeral',
                if (custom) 'ttl': '1h',
              });
            }
          },
        );
      }
    }
  }

  for (final scenario in [
    (_openai(), 'o3', 'max_completion_tokens', null),
    (_openai(), 'gpt-5.4', 'max_completion_tokens', null),
    (_openai(), 'gpt-4o', 'max_tokens', null),
    (_openai(router: true), 'openai/o3', 'max_tokens', null),
    (
      _openai().copyWith(baseUrl: 'https://relay.example/v1'),
      'o3',
      'max_tokens',
      null,
    ),
    (_openai(responses: true), 'o3', 'max_output_tokens', null),
    (
      _openai().copyWith(
        modelOverrides: {
          'local-alias': {'apiModelId': 'o3'},
        },
      ),
      'local-alias',
      'max_completion_tokens',
      null,
    ),
    (_openai(), 'o3', 'max_tokens', <String, dynamic>{'max_tokens': 1024}),
  ]) {
    for (final stream in [false, true]) {
      test(
        'output limit ${scenario.$1.baseUrl} ${scenario.$2} ${scenario.$3} custom=${scenario.$4 != null} stream=$stream',
        () async {
          final bodies = <Map<String, dynamic>>[];
          final responses = scenario.$1.useResponseApi == true;
          final client = MockClient((request) async {
            bodies.add(jsonDecode(request.body));
            return responses
                ? _responsesReply(bodies.length == 1, stream)
                : _chatReply(bodies.length == 1, stream);
          });
          addTearDown(client.close);
          await sendOpenAIStream(
            client,
            scenario.$1,
            scenario.$2,
            _user,
            tools: _tools,
            onToolCall: (_, _, {toolCallId}) async => 'result',
            maxTokens: 8192,
            stream: stream,
            extraBody: scenario.$4,
          ).toList();
          expect(bodies, hasLength(2));
          for (final body in bodies) {
            expect(body[scenario.$3], scenario.$4 == null ? 8192 : 1024);
            expect(
              body.keys.where(
                (key) => [
                  'max_tokens',
                  'max_completion_tokens',
                  'max_output_tokens',
                ].contains(key),
              ),
              [scenario.$3],
            );
          }
        },
      );
    }
  }

  for (final stream in [false, true]) {
    test(
      'Gemini parallel text, JSON and image results replay identically stream=$stream',
      () async {
        const callPart = <String, dynamic>{
          'functionCall': {
            'id': 'call_1',
            'name': 'view_image',
            'args': <String, dynamic>{},
          },
          'thoughtSignature': 'mock-signature',
        };
        const secondCall = <String, dynamic>{
          'functionCall': {
            'id': 'call_2',
            'name': 'lookup',
            'args': <String, dynamic>{},
          },
        };
        final directory = await Directory.systemTemp.createTemp(
          'gemini_results_',
        );
        addTearDown(() => directory.delete(recursive: true));
        final image = File('${directory.path}/result.png');
        await image.writeAsBytes(
          base64Decode(
            'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jFioAAAAASUVORK5CYII=',
          ),
        );
        final bodies = <Map<String, dynamic>>[];
        final client = MockClient((request) async {
          bodies.add(jsonDecode(request.body));
          final reply = {
            'candidates': [
              {
                'content': {
                  'role': 'model',
                  'parts': [
                    if (bodies.length == 1) ...[
                      callPart,
                      secondCall,
                    ] else
                      {'text': 'Done'},
                  ],
                },
                'finishReason': 'STOP',
              },
            ],
          };
          return http.Response(
            stream ? 'data: ${jsonEncode(reply)}\n\n' : jsonEncode(reply),
            200,
          );
        });
        addTearDown(client.close);
        final config = ProviderConfig(
          id: 'Gemini',
          enabled: true,
          name: 'Gemini',
          apiKey: 'mock-only',
          baseUrl: 'https://example.test/v1beta',
          providerType: ProviderKind.google,
        );
        final chunks = await sendGoogleGeminiStream(
          client,
          config,
          'gemini-3.8-flash',
          _user,
          tools: [
            ..._tools,
            {
              'type': 'function',
              'function': {
                'name': 'view_image',
                'parameters': {'type': 'object', 'properties': {}},
              },
            },
          ],
          stream: stream,
          onToolCall: (name, _, {toolCallId}) async => name == 'lookup'
              ? 'plain text'
              : ClientToolResult(
                  '{"x":1}',
                  metadata: {
                    'workspace': {'tool': 'view_image', 'status': 'ok'},
                    kMcpResultMetadataKey: mcpResultMetadata([image.path]),
                  },
                ),
        ).toList();
        expect(bodies, hasLength(2));
        final restoredParts = [
          for (final part in StreamChunkHandler.collect(chunks).parts)
            MessagePart.fromRow(part.kind, part.encodePayload()),
        ];
        final history = buildAssistantToolHistory(restoredParts);
        await sendGoogleGeminiStream(client, config, 'gemini-3.8-flash', [
          ..._user,
          ...history.messages,
          {'role': 'assistant', 'content': history.content},
          {'role': 'user', 'content': 'Next question'},
        ], stream: stream).toList();
        Map functionResponse(Map body) =>
            (body['contents'] as List)
                    .expand((content) => content['parts'] as List)
                    .cast<Map>()
                    .firstWhere(
                      (part) => part.containsKey('functionResponse'),
                    )['functionResponse']
                as Map;
        final continuation = functionResponse(bodies[1]);
        final replay = functionResponse(bodies[2]);
        expect(continuation['response'], {'x': 1});
        expect(replay['response'], {'x': 1});
        expect(continuation['id'], replay['id']);
        List responseParts(Map body) =>
            (body['contents'] as List).firstWhere(
                  (content) => (content['parts'] as List).any(
                    (part) => part['functionResponse'] != null,
                  ),
                )['parts']
                as List;
        final parts = responseParts(bodies[1]);
        expect(parts, responseParts(bodies[2]));
        expect(parts, hasLength(3));
        expect(parts[1]['inlineData']['mimeType'], 'image/png');
        expect(parts[2]['functionResponse'], {
          'name': 'lookup',
          'id': 'call_2',
          'response': {'result': 'plain text'},
        });
      },
    );
  }

  for (final vertex in [false, true]) {
    for (final stream in [false, true]) {
      test(
        'Claude signed blocks storage and history vertex=$vertex stream=$stream',
        () async {
          const signed = <String, dynamic>{
            'type': 'thinking',
            'thinking': 'Private reasoning',
            'signature': 'mock-signature',
          };
          const redacted = <String, dynamic>{
            'type': 'redacted_thinking',
            'data': 'mock-opaque',
          };
          const toolBlock = <String, dynamic>{
            'type': 'tool_use',
            'id': 'toolu_1',
            'name': 'lookup',
            'input': <String, dynamic>{},
          };
          const doneBlock = <String, dynamic>{'type': 'text', 'text': 'Done'};
          const preface = <String, dynamic>{
            'type': 'text',
            'text': 'Checking. ',
          };
          final bodies = <Map<String, dynamic>>[];
          final client = MockClient((request) async {
            bodies.add(jsonDecode(request.body));
            final call = bodies.length == 1;
            return _claudeReply(
              call ? [signed, preface, redacted, toolBlock] : [doneBlock],
              stream,
              call ? 'tool_use' : 'end_turn',
            );
          });
          addTearDown(client.close);
          final config = ProviderConfig(
            id: vertex ? 'Vertex' : 'Claude',
            enabled: true,
            name: 'probe',
            apiKey: 'mock-only',
            baseUrl: vertex
                ? 'https://aiplatform.googleapis.com'
                : 'https://api.anthropic.com',
            providerType: vertex ? ProviderKind.google : ProviderKind.claude,
            vertexAI: vertex,
            location: 'global',
            projectId: 'mock-project',
          );
          final model = vertex
              ? 'claude-sonnet-4@20250514'
              : 'claude-sonnet-4-20250514';
          final chunks =
              await (vertex
                      ? sendGoogleVertexClaudeStream(
                          client: client,
                          config: config,
                          modelId: model,
                          messages: _user,
                          tools: _tools,
                          stream: stream,
                          onToolCall: (_, _, {toolCallId}) async => '{"x":1}',
                        )
                      : sendClaudeStream(
                          client,
                          config,
                          model,
                          _user,
                          tools: _tools,
                          stream: stream,
                          onToolCall: (_, _, {toolCallId}) async => '{"x":1}',
                        ))
                  .toList();
          expect(bodies, hasLength(2));
          expect(jsonEncode(bodies[1]['messages']), contains('mock-signature'));
          final artifacts = chunks
              .whereType<ProviderArtifact>()
              .where((a) => a.kind == claudeTurnArtifactKind)
              .toList();
          expect(artifacts, hasLength(2));
          expect(decodeClaudeTurn(artifacts.last.payload), [
            [signed, preface, redacted, toolBlock],
            [doneBlock],
          ]);
          final restored = ChatMessage(
            id: 'assistant-reply',
            role: 'assistant',
            conversationId: 'c',
            providerId: config.id,
            modelId: model,
            parts: [
              for (final part in StreamChunkHandler.collect(chunks).parts)
                MessagePart.fromRow(part.kind, part.encodePayload()),
            ],
          );
          final builder = MessageBuilderService(
            chatService: _Chat(),
            contextProvider: _Context(),
            providerArtifactLookup: (_, kind) =>
                kind == claudeTurnArtifactKind ? artifacts.last.payload : null,
          );
          expect(restored.content, 'Checking. Done');
          for (final scope in [
            (providerId: config.id, modelId: model),
            (providerId: 'other-provider', modelId: model),
            (providerId: config.id, modelId: 'claude-opus-4-6'),
          ]) {
            final history = builder.buildApiMessages(
              messages: [
                ChatMessage(
                  role: 'user',
                  content: 'Question',
                  conversationId: 'c',
                ),
                restored,
                ChatMessage(
                  id: 'current-user',
                  role: 'user',
                  content: 'Next question',
                  conversationId: 'c',
                ),
              ],
              versionSelections: {},
              currentConversation: null,
              includeToolMessages: true,
              claudeSource: scope,
            );
            final projection = RequestHistoryContext(
              currentUserId: 'current-user',
              targetMessageId: 'next-reply',
              isCancelled: () => false,
              beforeRequest: (_, project, _) async {
                // Even a projection retaining the existing history must preserve
                // all responses and tool results under the assistant's identity.
                final candidate = project(history);
                expect(jsonEncode(candidate), contains('tool_use'));
                return history;
              },
            );
            final identified = RequestHistoryContext.identify(history);
            await projection
                .run(
                  () => vertex
                      ? sendGoogleVertexClaudeStream(
                          client: client,
                          config: config,
                          modelId: model,
                          messages: identified,
                          stream: stream,
                        )
                      : sendClaudeStream(
                          client,
                          config,
                          model,
                          identified,
                          stream: stream,
                        ),
                )
                .toList();
            expect(
              jsonEncode(bodies.last['messages']).contains('mock-signature'),
              scope.providerId == config.id && scope.modelId == model,
            );
            if (scope.providerId == config.id && scope.modelId == model) {
              expect((bodies.last['messages'] as List)[1]['content'], [
                signed,
                preface,
                redacted,
                toolBlock,
              ]);
              expect((bodies.last['messages'] as List)[3]['content'], [
                doneBlock,
              ]);
            }
            expect(
              jsonEncode(bodies.last['messages']),
              contains('tool_result'),
            );
          }
        },
      );
    }
  }
}
