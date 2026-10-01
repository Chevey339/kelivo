import 'dart:convert';
import 'dart:io';

import 'package:Kelivo/core/models/api_keys.dart';
import 'package:Kelivo/core/models/message_part.dart';
import 'package:Kelivo/core/providers/model_provider.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/api/builtin_tools.dart';
import 'package:Kelivo/core/services/api/chat_api_service.dart';
import 'package:Kelivo/core/services/api/providers/claude/claude_history.dart';
import 'package:Kelivo/core/services/api/stream/stream_chunk.dart';
import 'package:Kelivo/core/services/api/stream/stream_chunk_handler.dart';
import 'package:Kelivo/core/services/provider_balance_service.dart';
import 'package:Kelivo/core/services/workspace/workspace_tools_service.dart';
import 'package:Kelivo/core/utils/multimodal_input_utils.dart';
import 'package:Kelivo/utils/mcp_structured_image.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'support/claude_test_api.dart' show ProxyHttpOverrides;
import 'support/collect_generation.dart';

ProviderConfig _config({
  String model = 'openai/gpt-4o',
  ProviderKind kind = ProviderKind.openai,
  bool responses = false,
  bool search = true,
  List<Map<String, String>> customBody = const [],
}) => ProviderConfig.defaultsFor('Vercel').copyWith(
  enabled: true,
  apiKey: 'test-key',
  baseUrl: 'http://ai-gateway.vercel.sh/v1',
  providerType: kind,
  useResponseApi: responses,
  customBody: customBody,
  modelOverrides: {
    model: {
      'type': 'chat',
      if (search) 'builtInTools': ['search'],
    },
  },
);

Future<void> _withGateway(
  Map<String, dynamic> Function(HttpRequest, int) reply,
  Future<void> Function(List<Map<String, dynamic>>, List<String>, List<String?>)
  run, {
  bool sse = false,
}) async {
  final bodies = <Map<String, dynamic>>[];
  final paths = <String>[];
  final auth = <String?>[];
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  try {
    server.listen((request) async {
      final body = await utf8.decoder.bind(request).join();
      bodies.add(body.isEmpty ? {} : (jsonDecode(body) as Map).cast());
      paths.add(request.uri.path);
      auth.add(request.headers.value('authorization'));
      final rawTools = bodies.last['tools'];
      if (request.uri.path.endsWith('/chat/completions') && rawTools is List) {
        for (final tool in rawTools.whereType<Map>()) {
          if (tool['type'] != 'vercel:perplexity_search') continue;
          final config = tool['config'];
          final query = config is Map ? config['query'] : null;
          if (query is! String || query.trim().isEmpty) {
            request.response.statusCode = HttpStatus.badRequest;
            request.response.headers.contentType = ContentType.json;
            request.response.write(
              jsonEncode({
                'error': {
                  'message': 'vercel:perplexity_search requires config.query',
                },
              }),
            );
            await request.response.close();
            return;
          }
        }
      }
      final data = reply(request, bodies.length - 1);
      request.response.headers.contentType = sse
          ? ContentType('text', 'event-stream')
          : ContentType.json;
      request.response.write(
        sse
            ? 'data: ${jsonEncode(data)}\n\ndata: [DONE]\n\n'
            : jsonEncode(data),
      );
      await request.response.close();
    });
    await HttpOverrides.runZoned(
      () => run(bodies, paths, auth),
      createHttpClient: (context) =>
          ProxyHttpOverrides(server.port).createHttpClient(context),
    );
  } finally {
    await server.close(force: true);
  }
}

const _chatReply = {
  'choices': [
    {
      'message': {'role': 'assistant', 'content': 'ok'},
      'finish_reason': 'stop',
    },
  ],
  'usage': {'prompt_tokens': 1, 'completion_tokens': 1, 'total_tokens': 2},
};

const _function = {
  'type': 'function',
  'function': {
    'name': 'get_note',
    'parameters': {'type': 'object', 'properties': {}},
  },
};

void main() {
  test('Vercel identity is scoped to the Gateway host', () {
    expect(BuiltInToolsHelper.isVercelProvider(_config()), isTrue);
    expect(
      BuiltInToolsHelper.isVercelProvider(
        _config().copyWith(baseUrl: 'https://ai-gateway.vercel.sh.example/v1'),
      ),
      isFalse,
    );
  });

  test('Gateway search works across model families on Chat Completions', () {
    for (final model in [
      'openai/gpt-4o',
      'anthropic/claude-sonnet-4-20250514',
      'google/gemini-2.5-pro',
      'xai/grok-4',
    ]) {
      final cfg = _config(model: model);
      expect(
        BuiltInToolsHelper.supportsBuiltInSearchForModel(
          cfg: cfg,
          modelId: model,
        ),
        isTrue,
      );
      expect(
        BuiltInToolsHelper.buildChatCompletionsTools(
          cfg: cfg,
          modelId: model,
          upstreamModelId: model,
        ).tools,
        [
          {'type': 'vercel:perplexity_search'},
        ],
      );
    }
    const model = 'openai/gpt-4o';
    expect(
      BuiltInToolsHelper.buildChatCompletionsTools(
        cfg: _config(search: false),
        modelId: model,
        upstreamModelId: model,
      ).tools,
      isEmpty,
    );
  });

  test(
    'native search respects API mode and overridden upstream model id',
    () async {
      for (final kind in [ProviderKind.openai, ProviderKind.claude]) {
        final provider = kind == ProviderKind.openai ? 'openai' : 'anthropic';
        final cfg = _config(model: 'alias', kind: kind, responses: true)
            .copyWith(
              modelOverrides: {
                'alias': {
                  'type': 'chat',
                  'apiModelId': '$provider/test-model',
                  'builtInTools': ['search'],
                },
              },
            );
        expect(
          BuiltInToolsHelper.supportsBuiltInSearchForModel(
            cfg: cfg,
            modelId: 'alias',
          ),
          isTrue,
        );
      }
      for (final model in [
        'anthropic/claude-sonnet-4',
        'google/gemini-2.5-pro',
        'xai/grok-4',
      ]) {
        final cfg = _config(model: model, responses: true);
        expect(
          BuiltInToolsHelper.supportsBuiltInSearchForModel(
            cfg: cfg,
            modelId: model,
          ),
          isFalse,
        );
        await expectLater(
          ChatApiService.sendMessageStream(
            config: cfg,
            modelId: model,
            messages: const [
              {'role': 'user', 'content': 'search'},
            ],
          ).toList(),
          throwsA(isA<UnsupportedError>()),
        );
      }
    },
  );

  test('model fetching and credit balance use the active multi-key', () async {
    final cfg = _config(search: false).copyWith(
      balanceEnabled: true,
      multiKeyEnabled: true,
      apiKeys: const [
        ApiKeyConfig(
          id: 'off',
          key: 'disabled-key',
          isEnabled: false,
          createdAt: 0,
          updatedAt: 0,
        ),
        ApiKeyConfig(id: 'on', key: 'active-key', createdAt: 0, updatedAt: 0),
      ],
    );
    await _withGateway(
      (request, _) => request.uri.path.endsWith('/credits')
          ? {'balance': '95.50', 'total_used': '4.50'}
          : {
              'data': [
                {'id': 'openai/gpt-4o'},
                {'id': 'anthropic/claude-sonnet-4'},
              ],
            },
      (bodies, paths, auth) async {
        final models = await ProviderManager.listModels(cfg);
        expect(models.map((model) => model.id), [
          'openai/gpt-4o',
          'anthropic/claude-sonnet-4',
        ]);
        expect(await ProviderBalanceService.fetchBalance(cfg), '95.50');
        expect(paths, ['/v1/models', '/v1/credits']);
        expect(auth, ['Bearer active-key', 'Bearer active-key']);
        expect(bodies, [{}, {}]);
      },
    );
  });

  for (final stream in [false, true]) {
    test(
      'Gateway search retains functions and source annotations, stream=$stream',
      () async {
        final annotation = {
          'type': 'url_citation',
          'url_citation': {
            'url': 'https://example.com/source',
            'title': 'Source',
          },
        };
        await _withGateway(
          (_, _) => {
            'choices': [
              {
                stream ? 'delta' : 'message': {
                  'content': 'answer',
                  'annotations': [annotation],
                },
                'finish_reason': 'stop',
              },
            ],
          },
          (bodies, paths, auth) async {
            var clientCalls = 0;
            final chunks = await ChatApiService.sendMessageStream(
              config: _config(),
              modelId: 'openai/gpt-4o',
              stream: stream,
              messages: const [
                {'role': 'user', 'content': 'search'},
              ],
              tools: const [_function],
              onToolCall: (name, args, {toolCallId}) async {
                clientCalls++;
                return 'unused';
              },
            ).toList();
            expect(chunks.isGenerationDone, isTrue);
            expect(clientCalls, 0);
            expect(paths, ['/v1/chat/completions']);
            expect(auth, ['Bearer test-key']);
            expect(
              bodies.single['tools'],
              contains(
                equals({
                  'type': 'vercel:perplexity_search',
                  'config': {'query': 'search'},
                }),
              ),
            );
            expect(bodies.single['tools'], contains(equals(_function)));
            expect(bodies.single['tool_choice'], 'auto');
            final sources =
                chunks.whereType<ServerToolEnd>().single.output as Map;
            expect((sources['items'] as List).single, {
              'index': 1,
              'url': 'https://example.com/source',
              'title': 'Source',
            });
          },
          sse: stream,
        );
      },
    );

    test(
      'Gateway search survives client-tool follow-ups, stream=$stream',
      () async {
        await _withGateway(
          (_, round) => {
            'choices': [
              {
                'message': {
                  'role': 'assistant',
                  'content': round == 0 ? null : 'answer',
                  if (round == 0)
                    'tool_calls': [
                      {
                        'id': 'client-1',
                        'type': 'function',
                        'function': {'name': 'get_note', 'arguments': '{}'},
                      },
                    ],
                  'annotations': [
                    {
                      'type': 'url_citation',
                      'url_citation': {
                        'url': 'https://example.com/$round',
                        'title': 'Source $round',
                      },
                    },
                  ],
                },
                'finish_reason': round == 0 ? 'tool_calls' : 'stop',
              },
            ],
          },
          (bodies, paths, _) async {
            var clientCalls = 0;
            final chunks = await ChatApiService.sendMessageStream(
              config: _config(),
              modelId: 'openai/gpt-4o',
              stream: stream,
              messages: const [
                {'role': 'user', 'content': 'search and get note'},
              ],
              tools: const [_function],
              onToolCall: (name, args, {toolCallId}) async {
                clientCalls++;
                expect(name, 'get_note');
                expect(toolCallId, 'client-1');
                return 'note';
              },
            ).toList();
            expect(clientCalls, 1);
            expect(chunks.isGenerationDone, isTrue);
            expect(chunks.joinedContent, 'answer');
            expect(paths, ['/v1/chat/completions', '/v1/chat/completions']);
            for (final body in bodies) {
              expect(
                body['tools'],
                contains(
                  equals({
                    'type': 'vercel:perplexity_search',
                    'config': {'query': 'search and get note'},
                  }),
                ),
              );
              expect(body['tools'], contains(equals(_function)));
            }
            expect((bodies.last['messages'] as List).last, {
              'role': 'tool',
              'tool_call_id': 'client-1',
              'name': 'get_note',
              'content': 'note',
            });
            final urls = chunks.whereType<ServerToolEnd>().expand(
              (chunk) => ((chunk.output as Map)['items'] as List).map(
                (item) => item['url'],
              ),
            );
            expect(urls.toSet(), {
              'https://example.com/0',
              'https://example.com/1',
            });
          },
          sse: stream,
        );
      },
    );

    for (final explicitQuery in <String?>[null, 'Vercel release notes']) {
      test(
        'Gateway search keeps its query across image-tool rounds, stream=$stream, explicitQuery=$explicitQuery',
        () async {
          final dir = await Directory.systemTemp.createTemp('gateway_image_');
          addTearDown(() => dir.delete(recursive: true));
          final file = File('${dir.path}/snapshot.png');
          final png = img.encodePng(img.Image(width: 8, height: 4));
          await file.writeAsBytes(png);
          final result = ClientToolResult(
            'Image (8 x 4).\n![](${file.path})',
            metadata: {
              ...const WorkspaceToolMetadata(
                tool: 'view_image',
                status: 'ok',
              ).toJson(),
              kMcpResultMetadataKey: mcpResultMetadata([file.path]),
            },
          );
          final imageTools = WorkspaceToolsService.definitions()
              .where((d) => (d['function'] as Map)['name'] == 'view_image')
              .toList();
          await _withGateway(
            (_, round) => {
              'choices': [
                {
                  'message': {
                    'role': 'assistant',
                    'content': round < 2 ? null : 'answer',
                    if (round < 2)
                      'tool_calls': [
                        {
                          'id': 'image-$round',
                          'type': 'function',
                          'function': {
                            'name': 'view_image',
                            'arguments': '{"path":"plot.png"}',
                          },
                        },
                      ],
                  },
                  'finish_reason': round < 2 ? 'tool_calls' : 'stop',
                },
              ],
            },
            (bodies, _, _) async {
              var clientCalls = 0;
              const question = 'Compare plot.png with current Vercel docs.';
              final chunks = await ChatApiService.sendMessageStream(
                config: _config(
                  customBody: explicitQuery == null
                      ? const []
                      : [
                          {
                            'key': 'tools',
                            'value': jsonEncode([
                              ...imageTools,
                              {
                                'type': 'vercel:perplexity_search',
                                'config': {
                                  'query': explicitQuery,
                                  'max_results': 3,
                                },
                              },
                            ]),
                          },
                        ],
                ),
                modelId: 'openai/gpt-4o',
                stream: stream,
                messages: const [
                  {'role': 'user', 'content': question},
                ],
                tools: imageTools,
                onToolCall: (name, args, {toolCallId}) async {
                  expect(name, 'view_image');
                  expect(args['path'], 'plot.png');
                  expect(toolCallId, 'image-${clientCalls++}');
                  return result;
                },
              ).toList();
              expect(clientCalls, 2);
              expect(chunks.isGenerationDone, isTrue);
              expect(chunks.joinedContent, 'answer');
              expect(bodies, hasLength(3));
              for (var round = 0; round < bodies.length; round++) {
                expect(
                  bodies[round]['tools'],
                  contains(equals(imageTools.single)),
                );
                expect(
                  bodies[round]['tools'],
                  contains(
                    equals({
                      'type': 'vercel:perplexity_search',
                      'config': {
                        'query': explicitQuery ?? question,
                        if (explicitQuery != null) 'max_results': 3,
                      },
                    }),
                  ),
                );
                if (round == 0) continue;
                expect((bodies[round]['messages'] as List).last, {
                  'role': 'user',
                  'content': [
                    {
                      'type': 'text',
                      'text':
                          'Image returned by view_image (image-${round - 1}):',
                    },
                    {
                      'type': 'image_url',
                      'image_url': {
                        'url': 'data:image/png;base64,${base64Encode(png)}',
                        'detail': 'high',
                      },
                    },
                  ],
                });
              }
            },
            sse: stream,
          );
        },
      );
    }
  }

  for (final explicitQuery in <String?>[null, 'Vercel release notes']) {
    test(
      'custom Gateway options and query are preserved, explicitQuery=$explicitQuery',
      () async {
        await _withGateway((_, _) => _chatReply, (bodies, _, _) async {
          await ChatApiService.sendMessageStream(
            config: _config(
              customBody: [
                {
                  'key': 'tools',
                  'value': jsonEncode([
                    {
                      'type': 'vercel:perplexity_search',
                      'config': {
                        'max_results': 3,
                        if (explicitQuery != null) 'query': explicitQuery,
                      },
                    },
                  ]),
                },
              ],
            ),
            modelId: 'openai/gpt-4o',
            stream: false,
            messages: const [
              {'role': 'user', 'content': 'search'},
            ],
          ).toList();
          expect(bodies.single['tools'], [
            {
              'type': 'vercel:perplexity_search',
              'config': {'max_results': 3, 'query': explicitQuery ?? 'search'},
            },
          ]);
        });
      },
    );
  }

  test('Gateway query comes from the latest user text parts', () async {
    await _withGateway((_, _) => _chatReply, (bodies, _, _) async {
      await ChatApiService.sendMessageStream(
        config: _config(),
        modelId: 'openai/gpt-4o',
        stream: false,
        messages: const [
          {'role': 'user', 'content': 'Old question'},
          {'role': 'assistant', 'content': 'Old answer'},
          {
            'role': 'user',
            'content': [
              {'type': 'text', 'text': 'Current question'},
              {
                'type': 'image_url',
                'image_url': {'url': 'https://example.com/image.png'},
              },
              {'type': 'text', 'text': 'More detail'},
            ],
          },
        ],
      ).toList();
      expect((bodies.single['tools'] as List).single, {
        'type': 'vercel:perplexity_search',
        'config': {'query': 'Current question\nMore detail'},
      });
    });
  });

  test(
    'Gateway search fails before sending a request without a text query',
    () async {
      await _withGateway((_, _) => _chatReply, (bodies, _, _) async {
        await expectLater(
          ChatApiService.sendMessageStream(
            config: _config(),
            modelId: 'openai/gpt-4o',
            stream: false,
            messages: const [
              {
                'role': 'user',
                'content': [
                  {
                    'type': 'image_url',
                    'image_url': {'url': 'https://example.com/image.png'},
                  },
                ],
              },
            ],
          ).toList(),
          throwsA(isA<UnsupportedError>()),
        );
        expect(bodies, isEmpty);
      });
    },
  );

  test(
    'native Responses search retains sources in non-streaming replies',
    () async {
      await _withGateway(
        (_, _) => {
          'output': [
            {
              'type': 'web_search_call',
              'id': 'search-1',
              'status': 'completed',
              'action': {'type': 'search', 'query': 'kelivo'},
            },
            {
              'type': 'message',
              'role': 'assistant',
              'content': [
                {'type': 'output_text', 'text': 'prefix ', 'annotations': {}},
                {
                  'type': 'output_text',
                  'text': 'answer',
                  'annotations': [
                    {
                      'type': 'url_citation',
                      'url': 'https://example.com/source',
                      'title': 'Source',
                    },
                  ],
                },
              ],
            },
          ],
        },
        (bodies, paths, _) async {
          final chunks = await ChatApiService.sendMessageStream(
            config: _config(responses: true),
            modelId: 'openai/gpt-4o',
            stream: false,
            messages: const [
              {'role': 'user', 'content': 'search'},
            ],
          ).toList();
          expect(chunks.isGenerationDone, isTrue);
          expect(chunks.joinedContent, 'prefix answer');
          expect(paths, ['/v1/responses']);
          expect(bodies.single['tools'], [
            {'type': 'web_search'},
          ]);
          expect(
            chunks.whereType<Annotations>().single.annotations.single,
            isA<UrlCitationAnnotation>(),
          );
          expect(chunks.whereType<ServerToolEnd>().single.id, 'search-1');
          final result = StreamChunkHandler.collect(chunks);
          final card = jsonDecode(
            result.parts.whereType<ToolCallPart>().single.payloadJson,
          );
          expect(card['id'], 'search-1');
          expect(card['content']['items'], [
            {'url': 'https://example.com/source', 'title': 'Source'},
          ]);
        },
      );
    },
  );

  test(
    'Responses client-tool follow-ups retain native search sources',
    () async {
      await _withGateway(
        (_, round) => round == 0
            ? {
                'output': [
                  {
                    'type': 'function_call',
                    'id': 'fc-1',
                    'call_id': 'client-1',
                    'name': 'get_note',
                    'arguments': '{}',
                  },
                ],
              }
            : {
                'response': {
                  'output': [
                    {
                      'type': 'web_search_call',
                      'id': 'search-1',
                      'status': 'completed',
                    },
                    {
                      'type': 'message',
                      'role': 'assistant',
                      'content': [
                        {
                          'type': 'output_text',
                          'text': 'answer',
                          'annotations': [
                            {
                              'type': 'url_citation',
                              'url': 'https://example.com/source',
                            },
                          ],
                        },
                      ],
                    },
                  ],
                },
              },
        (bodies, paths, _) async {
          final chunks = await ChatApiService.sendMessageStream(
            config: _config(responses: true),
            modelId: 'openai/gpt-4o',
            stream: false,
            messages: const [
              {'role': 'user', 'content': 'get note and search'},
            ],
            tools: const [_function],
            onToolCall: (name, args, {toolCallId}) async => 'note',
          ).toList();
          expect(chunks.isGenerationDone, isTrue);
          expect(chunks.joinedContent, 'answer');
          expect(paths, ['/v1/responses', '/v1/responses']);
          for (final body in bodies) {
            expect(body['tools'], contains(equals({'type': 'web_search'})));
          }
          expect(
            bodies.last['input'],
            contains(
              equals({
                'type': 'function_call_output',
                'call_id': 'client-1',
                'output': 'note',
              }),
            ),
          );
          final citation =
              chunks.whereType<Annotations>().single.annotations.single
                  as UrlCitationAnnotation;
          expect(citation.url, 'https://example.com/source');
          expect(chunks.whereType<ServerToolEnd>().single.id, 'search-1');
        },
      );
    },
  );

  test(
    'Messages retains native search blocks through continuations and history',
    () async {
      const model = 'anthropic/claude-sonnet-4-20250514';
      const searchCall = {
        'type': 'server_tool_use',
        'id': 'srv-1',
        'name': 'web_search',
        'input': {'query': 'kelivo'},
      };
      const searchResult = {
        'type': 'web_search_tool_result',
        'tool_use_id': 'srv-1',
        'content': [
          {
            'type': 'web_search_result',
            'title': 'Source',
            'url': 'https://example.com/source',
            'encrypted_content': 'opaque-source',
          },
        ],
      };
      await _withGateway(
        (_, round) => {
          'id': 'msg-$round',
          'type': 'message',
          'role': 'assistant',
          'model': model,
          'content': round == 0
              ? [
                  searchCall,
                  searchResult,
                  {
                    'type': 'tool_use',
                    'id': 'client-1',
                    'name': 'get_note',
                    'input': {},
                  },
                ]
              : [
                  {'type': 'text', 'text': 'answer'},
                ],
          'stop_reason': round == 0 ? 'tool_use' : 'end_turn',
          'usage': {'input_tokens': 1, 'output_tokens': 1},
        },
        (bodies, paths, _) async {
          final chunks = await ChatApiService.sendMessageStream(
            config: _config(model: model, kind: ProviderKind.claude),
            modelId: model,
            stream: false,
            messages: const [
              {'role': 'user', 'content': 'search'},
            ],
            tools: const [_function],
            onToolCall: (name, args, {toolCallId}) async => 'note',
          ).toList();
          expect(chunks.isGenerationDone, isTrue);
          expect(paths, ['/v1/messages', '/v1/messages']);
          for (final body in bodies) {
            expect(
              body['tools'],
              contains(
                equals({'type': 'web_search_20250305', 'name': 'web_search'}),
              ),
            );
          }
          final messages = bodies.last['messages'] as List;
          final blocks =
              (messages.firstWhere((m) => m['role'] == 'assistant')['content']
                  as List);
          expect(blocks, contains(equals(searchCall)));
          expect(blocks, contains(equals(searchResult)));
          expect(
            chunks.whereType<ServerToolStart>().any(
              (chunk) => chunk.toolName == 'search_web',
            ),
            isTrue,
          );
          final turn = chunks.whereType<ProviderArtifact>().lastWhere(
            (chunk) => chunk.kind == claudeTurnArtifactKind,
          );
          await ChatApiService.sendMessageStream(
            config: _config(model: model, kind: ProviderKind.claude),
            modelId: model,
            stream: false,
            messages: [
              {'role': 'user', 'content': 'search'},
              {
                'role': 'assistant',
                'content': '',
                multimodalInternalClaudeTurnKey: turn.payload,
                'tool_calls': [
                  {
                    'id': 'srv-1',
                    'type': 'function',
                    'function': {
                      'name': 'search_web',
                      'arguments': '{"query":"kelivo"}',
                    },
                  },
                  {
                    'id': 'client-1',
                    'type': 'function',
                    'function': {'name': 'get_note', 'arguments': '{}'},
                  },
                ],
              },
              {'role': 'tool', 'tool_call_id': 'client-1', 'content': 'note'},
              {'role': 'assistant', 'content': 'answer'},
              {'role': 'user', 'content': 'follow up'},
            ],
          ).toList();
          final replayedMessages = bodies.last['messages'] as List;
          final replayedBlocks = replayedMessages
              .where((message) => message['role'] == 'assistant')
              .expand(
                (message) => message['content'] is List
                    ? message['content'] as List
                    : const [],
              );
          expect(replayedBlocks, contains(equals(searchCall)));
          expect(replayedBlocks, contains(equals(searchResult)));
          expect(
            replayedBlocks.where(
              (block) =>
                  block['type'] == 'tool_use' && block['name'] == 'search_web',
            ),
            isEmpty,
          );
        },
      );
    },
  );
}
