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
}) {
  return ProviderConfig(
    id: 'OpenRouter',
    enabled: true,
    name: 'OpenRouter',
    apiKey: 'test-key',
    baseUrl: 'http://openrouter.ai/api/v1',
    providerType: ProviderKind.openai,
    useResponseApi: useResponseApi,
    modelOverrides: <String, dynamic>{
      if (searchEnabled)
        modelId: <String, dynamic>{
          'builtInTools': const <String>[BuiltInToolNames.search],
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
  group('OpenRouter built-in search', () {
    test('support matrix enables web search for OpenRouter models', () {
      final cfg = _openRouterConfig(modelId: 'deepseek/deepseek-chat');

      expect(
        BuiltInToolsHelper.supportsBuiltInSearchForModel(
          cfg: cfg,
          modelId: 'deepseek/deepseek-chat',
        ),
        isTrue,
      );
    });

    test('support matrix keeps OpenRouter Responses path unsupported', () {
      final cfg = _openRouterConfig(
        modelId: 'deepseek/deepseek-chat',
        useResponseApi: true,
      );

      expect(
        BuiltInToolsHelper.supportsBuiltInSearchForModel(
          cfg: cfg,
          modelId: 'deepseek/deepseek-chat',
        ),
        isFalse,
      );
    });

    test('Chat Completions request injects default web plugin', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() async {
        await server.close(force: true);
      });

      Map<String, dynamic>? receivedBody;
      server.listen((request) async {
        receivedBody =
            jsonDecode(await utf8.decoder.bind(request).join())
                as Map<String, dynamic>;
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
            config: _openRouterConfig(modelId: 'deepseek/deepseek-chat'),
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
      expect(
        receivedBody!['plugins'],
        contains(
          predicate<Map<String, dynamic>>((plugin) => plugin['id'] == 'web'),
        ),
      );
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
          receivedBody =
              jsonDecode(await utf8.decoder.bind(request).join())
                  as Map<String, dynamic>;
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
      },
    );
  });
}
