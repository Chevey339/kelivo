import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/api/builtin_tools.dart';
import 'package:Kelivo/core/services/api/chat_api_service.dart';

ProviderConfig _openRouterConfig({
  required String modelId,
  bool searchEnabled = true,
  bool useResponseApi = false,
  List<String>? builtInTools,
  bool claudePromptCachingEnabled = false,
  String? claudePromptCachingTtl,
}) {
  return ProviderConfig(
    id: 'OpenRouter',
    enabled: true,
    name: 'OpenRouter',
    apiKey: 'test-key',
    baseUrl: 'http://openrouter.ai/api/v1',
    providerType: ProviderKind.openai,
    useResponseApi: useResponseApi,
    claudePromptCachingEnabled: claudePromptCachingEnabled,
    claudePromptCachingTtl: claudePromptCachingTtl,
    modelOverrides: <String, dynamic>{
      if (searchEnabled || builtInTools != null)
        modelId: <String, dynamic>{
          'builtInTools':
              builtInTools ?? const <String>[BuiltInToolNames.search],
          'webSearch': const <String, dynamic>{'include_sources': true},
        },
    },
  );
}

class _ProxyHttpOverrides extends HttpOverrides {
  _ProxyHttpOverrides(this.port);

  final int port;

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final client = super.createHttpClient(context);
    client.findProxy = (_) => 'PROXY 127.0.0.1:$port';
    return client;
  }
}

void main() {
  group('OpenRouter built-in tools', () {
    test(
      'support matrix enables Responses web search for OpenRouter models',
      () {
        final cfg = _openRouterConfig(
          modelId: 'deepseek/deepseek-chat',
          useResponseApi: true,
        );

        expect(
          BuiltInToolsHelper.supportsBuiltInSearchForModel(
            cfg: cfg,
            modelId: 'deepseek/deepseek-chat',
          ),
          isTrue,
        );
      },
    );

    test(
      'support matrix enables OpenRouter web search on Chat Completions',
      () {
        final cfg = _openRouterConfig(modelId: 'deepseek/deepseek-chat');

        expect(
          BuiltInToolsHelper.supportsBuiltInSearchForModel(
            cfg: cfg,
            modelId: 'deepseek/deepseek-chat',
          ),
          isTrue,
        );
      },
    );

    test(
      'Chat Completions request injects supported server tools without plugin',
      () async {
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        addTearDown(() async {
          await server.close(force: true);
        });

        Map<String, dynamic>? receivedBody;
        server.listen((request) async {
          receivedBody = jsonDecode(
            await utf8.decoder.bind(request).join(),
          ) as Map<String, dynamic>;
          request.response.statusCode = HttpStatus.ok;
          request.response.headers.contentType = ContentType.json;
          request.response.write(
            jsonEncode({
              'choices': [
                {
                  'message': {'role': 'assistant', 'content': 'ok'},
                  'finish_reason': 'stop',
                },
              ],
              'usage': {
                'prompt_tokens': 1,
                'completion_tokens': 1,
                'total_tokens': 2,
              },
            }),
          );
          await request.response.close();
        });

        await HttpOverrides.runZoned(
          () async {
            final chunks = await ChatApiService.sendMessageStream(
              config: _openRouterConfig(
                modelId: 'deepseek/deepseek-chat',
                builtInTools: const <String>[
                  BuiltInToolNames.search,
                  BuiltInToolNames.webFetch,
                  BuiltInToolNames.imageGeneration,
                  BuiltInToolNames.shell,
                ],
              ),
              modelId: 'deepseek/deepseek-chat',
              messages: const <Map<String, dynamic>>[
                {'role': 'user', 'content': 'latest AI news'},
              ],
              stream: false,
            ).toList();

            expect(chunks.last.isDone, isTrue);
          },
          createHttpClient: (context) {
            return _ProxyHttpOverrides(server.port).createHttpClient(context);
          },
        );

        expect(receivedBody, isNotNull);
        expect(receivedBody!['model'], 'deepseek/deepseek-chat');
        expect(receivedBody!.containsKey('plugins'), isFalse);
        final tools = (receivedBody!['tools'] as List).cast<Map>();
        expect(tools.map((tool) => tool['type']).toSet(), <String>{
          'openrouter:web_search',
          'openrouter:web_fetch',
          'openrouter:image_generation',
        });
        expect(
          tools.any((tool) => tool['type'] == 'openrouter:shell'),
          isFalse,
        );
      },
    );

    test('Responses request injects OpenRouter server tools', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() async {
        await server.close(force: true);
      });

      Map<String, dynamic>? receivedBody;
      server.listen((request) async {
        receivedBody = jsonDecode(
          await utf8.decoder.bind(request).join(),
        ) as Map<String, dynamic>;
        request.response.statusCode = HttpStatus.ok;
        request.response.headers.contentType = ContentType.json;
        request.response.write(
          jsonEncode({
            'id': 'resp_test',
            'output_text': 'ok',
            'output': const <dynamic>[],
            'usage': {'input_tokens': 1, 'output_tokens': 1, 'total_tokens': 2},
          }),
        );
        await request.response.close();
      });

      await HttpOverrides.runZoned(
        () async {
          final chunks = await ChatApiService.sendMessageStream(
            config: _openRouterConfig(
              modelId: 'anthropic/claude-sonnet-4.5',
              useResponseApi: true,
              builtInTools: const <String>[
                BuiltInToolNames.search,
                BuiltInToolNames.webFetch,
                BuiltInToolNames.imageGeneration,
                BuiltInToolNames.shell,
              ],
            ),
            modelId: 'anthropic/claude-sonnet-4.5',
            messages: const <Map<String, dynamic>>[
              {'role': 'user', 'content': 'use the enabled tools'},
            ],
            stream: false,
          ).toList();

          expect(chunks.last.isDone, isTrue);
        },
        createHttpClient: (context) {
          return _ProxyHttpOverrides(server.port).createHttpClient(context);
        },
      );

      expect(receivedBody, isNotNull);
      expect(receivedBody!.containsKey('include'), isFalse);
      final tools = (receivedBody!['tools'] as List).cast<Map>();
      expect(
        tools.map((tool) => tool['type']).toSet(),
        containsAll(<String>{
          'openrouter:web_search',
          'openrouter:web_fetch',
          'openrouter:image_generation',
          'openrouter:shell',
        }),
      );
      final shell = tools.singleWhere(
        (tool) => tool['type'] == 'openrouter:shell',
      );
      expect(shell['parameters'], <String, dynamic>{'engine': 'openrouter'});
    });

    test('non-OpenRouter Responses tools keep native OpenAI types', () {
      final cfg = ProviderConfig(
        id: 'OpenAI',
        enabled: true,
        name: 'OpenAI',
        apiKey: 'test-key',
        baseUrl: 'https://api.openai.com/v1',
        providerType: ProviderKind.openai,
        useResponseApi: true,
        modelOverrides: <String, dynamic>{
          'gpt-5': <String, dynamic>{
            'builtInTools': const <String>[
              BuiltInToolNames.search,
              BuiltInToolNames.codeInterpreter,
              BuiltInToolNames.imageGeneration,
            ],
          },
        },
      );

      final tools = BuiltInToolsHelper.buildResponsesTools(
        cfg: cfg,
        modelId: 'gpt-5',
        upstreamModelId: 'gpt-5',
      ).tools;
      expect(
        tools.map((tool) => tool['type']),
        containsAll(<String>{
          'web_search',
          'code_interpreter',
          'image_generation',
        }),
      );
      expect(
        tools.any((tool) => (tool['type'] as String).startsWith('openrouter:')),
        isFalse,
      );
    });

    test('model settings remove Responses-only shell in Chat mode', () {
      final cfg = _openRouterConfig(modelId: 'test/model');
      expect(BuiltInToolsHelper.modelSettingsToolNames(cfg), <String>{
        BuiltInToolNames.webFetch,
        BuiltInToolNames.imageGeneration,
      });
      final updated = BuiltInToolsHelper.replaceModelSettingsTools(
        cfg: cfg,
        current: const <String>{
          BuiltInToolNames.search,
          BuiltInToolNames.codeInterpreter,
        },
        selected: const <String>{
          BuiltInToolNames.webFetch,
          BuiltInToolNames.imageGeneration,
          BuiltInToolNames.shell,
        },
      );

      expect(updated, <String>{
        BuiltInToolNames.search,
        BuiltInToolNames.webFetch,
        BuiltInToolNames.imageGeneration,
      });
      expect(updated, isNot(contains(BuiltInToolNames.codeInterpreter)));
      expect(updated, isNot(contains(BuiltInToolNames.shell)));
    });

    test('model settings expose shell in Responses mode', () {
      final cfg = _openRouterConfig(
        modelId: 'test/model',
        useResponseApi: true,
      );

      expect(BuiltInToolsHelper.modelSettingsToolNames(cfg), <String>{
        BuiltInToolNames.webFetch,
        BuiltInToolNames.imageGeneration,
        BuiltInToolNames.shell,
      });
    });

    test(
      'Chat Completions request leaves plugins absent when disabled',
      () async {
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        addTearDown(() async {
          await server.close(force: true);
        });

        Map<String, dynamic>? receivedBody;
        server.listen((request) async {
          receivedBody = jsonDecode(
            await utf8.decoder.bind(request).join(),
          ) as Map<String, dynamic>;
          request.response.statusCode = HttpStatus.ok;
          request.response.headers.contentType = ContentType.json;
          request.response.write(
            jsonEncode({
              'choices': [
                {
                  'message': {'role': 'assistant', 'content': 'ok'},
                  'finish_reason': 'stop',
                },
              ],
              'usage': {
                'prompt_tokens': 1,
                'completion_tokens': 1,
                'total_tokens': 2,
              },
            }),
          );
          await request.response.close();
        });

        await HttpOverrides.runZoned(
          () async {
            final chunks = await ChatApiService.sendMessageStream(
              config: _openRouterConfig(
                modelId: 'deepseek/deepseek-chat',
                searchEnabled: false,
              ),
              modelId: 'deepseek/deepseek-chat',
              messages: const <Map<String, dynamic>>[
                {'role': 'user', 'content': 'latest AI news'},
              ],
              stream: false,
            ).toList();

            expect(chunks.last.isDone, isTrue);
          },
          createHttpClient: (context) {
            return _ProxyHttpOverrides(server.port).createHttpClient(context);
          },
        );

        expect(receivedBody, isNotNull);
        expect(receivedBody!.containsKey('plugins'), isFalse);
        expect(receivedBody!.containsKey('tools'), isFalse);
      },
    );

    test(
      'Claude prompt caching adds OpenRouter top-level cache control',
      () async {
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        addTearDown(() async {
          await server.close(force: true);
        });

        Map<String, dynamic>? receivedBody;
        server.listen((request) async {
          receivedBody = jsonDecode(
            await utf8.decoder.bind(request).join(),
          ) as Map<String, dynamic>;
          request.response.statusCode = HttpStatus.ok;
          request.response.headers.contentType = ContentType.json;
          request.response.write(
            jsonEncode({
              'choices': [
                {
                  'message': {'role': 'assistant', 'content': 'ok'},
                  'finish_reason': 'stop',
                },
              ],
              'usage': {
                'prompt_tokens': 1,
                'completion_tokens': 1,
                'total_tokens': 2,
              },
            }),
          );
          await request.response.close();
        });

        await HttpOverrides.runZoned(
          () async {
            final chunks = await ChatApiService.sendMessageStream(
              config: _openRouterConfig(
                modelId: 'anthropic/claude-sonnet-4.5',
                searchEnabled: false,
                claudePromptCachingEnabled: true,
              ),
              modelId: 'anthropic/claude-sonnet-4.5',
              messages: const <Map<String, dynamic>>[
                {
                  'role': 'system',
                  'content': 'Stable persona and long context.',
                },
                {'role': 'user', 'content': 'hello'},
              ],
              stream: false,
            ).toList();

            expect(chunks.last.isDone, isTrue);
          },
          createHttpClient: (context) {
            return _ProxyHttpOverrides(server.port).createHttpClient(context);
          },
        );

        expect(receivedBody, isNotNull);
        final messages = (receivedBody!['messages'] as List).cast<Map>();
        expect(messages.first['role'], 'system');
        expect(messages.first['content'], 'Stable persona and long context.');
        expect(receivedBody!['cache_control'], {'type': 'ephemeral'});
      },
    );

    test('Claude prompt caching adds OpenRouter one hour cache ttl', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() async {
        await server.close(force: true);
      });

      Map<String, dynamic>? receivedBody;
      server.listen((request) async {
        receivedBody = jsonDecode(
          await utf8.decoder.bind(request).join(),
        ) as Map<String, dynamic>;
        request.response.statusCode = HttpStatus.ok;
        request.response.headers.contentType = ContentType.json;
        request.response.write(
          jsonEncode({
            'choices': [
              {
                'message': {'role': 'assistant', 'content': 'ok'},
                'finish_reason': 'stop',
              },
            ],
          }),
        );
        await request.response.close();
      });

      await HttpOverrides.runZoned(
        () async {
          await ChatApiService.sendMessageStream(
            config: _openRouterConfig(
              modelId: 'anthropic/claude-sonnet-4.5',
              searchEnabled: false,
              claudePromptCachingEnabled: true,
              claudePromptCachingTtl: '1h',
            ),
            modelId: 'anthropic/claude-sonnet-4.5',
            messages: const <Map<String, dynamic>>[
              {'role': 'system', 'content': 'Stable persona and long context.'},
              {'role': 'user', 'content': 'hello'},
            ],
            stream: false,
          ).toList();
        },
        createHttpClient: (context) {
          return _ProxyHttpOverrides(server.port).createHttpClient(context);
        },
      );

      expect(receivedBody, isNotNull);
      expect(receivedBody!['cache_control'], {
        'type': 'ephemeral',
        'ttl': '1h',
      });
    });

    test('Claude prompt caching skips non-Claude OpenRouter models', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() async {
        await server.close(force: true);
      });

      Map<String, dynamic>? receivedBody;
      server.listen((request) async {
        receivedBody = jsonDecode(
          await utf8.decoder.bind(request).join(),
        ) as Map<String, dynamic>;
        request.response.statusCode = HttpStatus.ok;
        request.response.headers.contentType = ContentType.json;
        request.response.write(
          jsonEncode({
            'choices': [
              {
                'message': {'role': 'assistant', 'content': 'ok'},
                'finish_reason': 'stop',
              },
            ],
            'usage': {
              'prompt_tokens': 1,
              'completion_tokens': 1,
              'total_tokens': 2,
            },
          }),
        );
        await request.response.close();
      });

      await HttpOverrides.runZoned(
        () async {
          final chunks = await ChatApiService.sendMessageStream(
            config: _openRouterConfig(
              modelId: 'deepseek/deepseek-chat',
              searchEnabled: false,
              claudePromptCachingEnabled: true,
            ),
            modelId: 'deepseek/deepseek-chat',
            messages: const <Map<String, dynamic>>[
              {'role': 'system', 'content': 'Stable persona and long context.'},
              {'role': 'user', 'content': 'hello'},
            ],
            stream: false,
          ).toList();

          expect(chunks.last.isDone, isTrue);
        },
        createHttpClient: (context) {
          return _ProxyHttpOverrides(server.port).createHttpClient(context);
        },
      );

      expect(receivedBody, isNotNull);
      final messages = (receivedBody!['messages'] as List).cast<Map>();
      expect(messages.first['role'], 'system');
      expect(messages.first['content'], 'Stable persona and long context.');
      expect(receivedBody!.containsKey('cache_control'), isFalse);
    });
  });
}
