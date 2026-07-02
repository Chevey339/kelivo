import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:Cuplivo/core/providers/settings_provider.dart';
import 'package:Cuplivo/core/services/api/builtin_tools.dart';
import 'package:Cuplivo/core/services/api/chat_api_service.dart';

ProviderConfig _dashScopeConfig({
  required bool useResponseApi,
  required String modelId,
}) {
  return ProviderConfig(
    id: 'DashScopeTest',
    enabled: true,
    name: 'DashScopeTest',
    apiKey: 'test-key',
    baseUrl: 'http://dashscope.aliyuncs.com/compatible-mode/v1',
    providerType: ProviderKind.openai,
    useResponseApi: useResponseApi,
    modelOverrides: <String, dynamic>{
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
  group('DashScope Qwen3.6 built-in search', () {
    test('Responses API support matrix only enables qwen3.6 models there', () {
      final responsesPlus = _dashScopeConfig(
        useResponseApi: true,
        modelId: 'qwen3.6-plus',
      );
      final responsesFlash = _dashScopeConfig(
        useResponseApi: true,
        modelId: 'qwen3.6-flash',
      );
      final chatPlus = _dashScopeConfig(
        useResponseApi: false,
        modelId: 'qwen3.6-plus',
      );

      expect(
        BuiltInToolsHelper.supportsBuiltInSearchForModel(
          cfg: responsesPlus,
          modelId: 'qwen3.6-plus',
        ),
        isTrue,
      );
      expect(
        BuiltInToolsHelper.supportsBuiltInSearchForModel(
          cfg: responsesFlash,
          modelId: 'qwen3.6-flash',
        ),
        isTrue,
      );
      expect(
        BuiltInToolsHelper.supportsBuiltInSearchForModel(
          cfg: chatPlus,
          modelId: 'qwen3.6-plus',
        ),
        isFalse,
      );
    });

    test('Responses request injects web_search for qwen3.6-plus', () async {
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
            'output_text': 'ok',
            'usage': {'input_tokens': 1, 'output_tokens': 1, 'total_tokens': 2},
          }),
        );
        await request.response.close();
      });

      await HttpOverrides.runZoned(
        () async {
          final chunks = await ChatApiService.sendMessageStream(
            config: _dashScopeConfig(
              useResponseApi: true,
              modelId: 'qwen3.6-plus',
            ),
            modelId: 'qwen3.6-plus',
            messages: const <Map<String, dynamic>>[
              {'role': 'user', 'content': '杭州天气'},
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
      expect(receivedBody!['model'], 'qwen3.6-plus');
      expect(
        receivedBody!['tools'],
        contains(
          predicate<Map<String, dynamic>>(
            (tool) => tool['type'] == 'web_search',
          ),
        ),
      );
    });

    test('Responses request injects web_search for qwen3.6-flash', () async {
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
            'output_text': 'ok',
            'usage': {'input_tokens': 1, 'output_tokens': 1, 'total_tokens': 2},
          }),
        );
        await request.response.close();
      });

      await HttpOverrides.runZoned(
        () async {
          final chunks = await ChatApiService.sendMessageStream(
            config: _dashScopeConfig(
              useResponseApi: true,
              modelId: 'qwen3.6-flash',
            ),
            modelId: 'qwen3.6-flash',
            messages: const <Map<String, dynamic>>[
              {'role': 'user', 'content': '杭州天气'},
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
      expect(receivedBody!['model'], 'qwen3.6-flash');
      expect(
        receivedBody!['tools'],
        contains(
          predicate<Map<String, dynamic>>(
            (tool) => tool['type'] == 'web_search',
          ),
        ),
      );
    });
  });
}
