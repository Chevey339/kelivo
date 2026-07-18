import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/api/chat_api_service.dart';

ProviderConfig _openAIConfig(String baseUrl) {
  return ProviderConfig(
    id: 'EncodingCompatTest',
    enabled: true,
    name: 'EncodingCompatTest',
    apiKey: 'test-key',
    baseUrl: baseUrl,
    providerType: ProviderKind.openai,
  );
}

ProviderConfig _openAIReasoningConfig({
  required String id,
  required String baseUrl,
  required String modelId,
}) {
  return ProviderConfig(
    id: id,
    enabled: true,
    name: id,
    apiKey: 'test-key',
    baseUrl: baseUrl,
    providerType: ProviderKind.openai,
    models: [modelId],
    modelOverrides: {
      modelId: {
        'type': 'chat',
        'input': ['text'],
        'output': ['text'],
        'abilities': ['reasoning'],
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

Future<Map<String, dynamic>> _captureGenerateTextBody({
  required String providerId,
  required String modelId,
  required int thinkingBudget,
  String? configBaseUrl,
}) async {
  late Map<String, dynamic> requestBody;
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  addTearDown(() async {
    await server.close(force: true);
  });

  server.listen((request) async {
    requestBody = (jsonDecode(await utf8.decoder.bind(request).join()) as Map)
        .cast<String, dynamic>();

    request.response.statusCode = HttpStatus.ok;
    request.response.headers.contentType = ContentType.json;
    request.response.write(
      jsonEncode({
        'choices': [
          {
            'message': {'content': '标题'},
          },
        ],
      }),
    );
    await request.response.close();
  });

  final localBaseUrl = 'http://${server.address.address}:${server.port}/v1';
  final effectiveBaseUrl = configBaseUrl ?? localBaseUrl;
  Future<String> generate() {
    return ChatApiService.generateText(
      config: _openAIReasoningConfig(
        id: providerId,
        baseUrl: effectiveBaseUrl,
        modelId: modelId,
      ),
      modelId: modelId,
      prompt: 'summarize',
      thinkingBudget: thinkingBudget,
    );
  }

  final title = configBaseUrl == null
      ? await generate()
      : await HttpOverrides.runZoned(
          generate,
          createHttpClient: (context) {
            return _ProxyHttpOverrides(server.port).createHttpClient(context);
          },
        );

  expect(title, '标题');
  return requestBody;
}

void main() {
  group('ChatApiService.generateText encoding compatibility', () {
    test(
      'decodes OpenAI compatible JSON as UTF-8 when content type lacks charset',
      () async {
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        addTearDown(() async {
          await server.close(force: true);
        });

        server.listen((request) async {
          await utf8.decoder.bind(request).join();

          request.response.statusCode = HttpStatus.ok;
          request.response.headers.set(
            HttpHeaders.contentTypeHeader,
            'text/plain',
          );
          request.response.add(
            utf8.encode('{"choices":[{"message":{"content":"问候交流"}}]}'),
          );
          await request.response.close();
        });

        final baseUrl = 'http://${server.address.address}:${server.port}/v1';
        final title = await ChatApiService.generateText(
          config: _openAIConfig(baseUrl),
          modelId: 'title-model',
          prompt: 'summarize',
        );

        expect(title, '问候交流');
      },
    );

    test(
      'omits fixed Kimi K2.7 Code params from OpenAI compatible JSON',
      () async {
        late Map<String, dynamic> requestBody;
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        addTearDown(() async {
          await server.close(force: true);
        });

        server.listen((request) async {
          requestBody =
              (jsonDecode(await utf8.decoder.bind(request).join()) as Map)
                  .cast<String, dynamic>();

          request.response.statusCode = HttpStatus.ok;
          request.response.headers.contentType = ContentType.json;
          request.response.write(
            jsonEncode({
              'choices': [
                {
                  'message': {'content': '标题'},
                },
              ],
            }),
          );
          await request.response.close();
        });

        final baseUrl = 'http://${server.address.address}:${server.port}/v1';
        final title = await ChatApiService.generateText(
          config: _openAIConfig(baseUrl),
          modelId: 'kimi-k2.7-code',
          prompt: 'summarize',
          thinkingBudget: 0,
        );

        expect(title, '标题');
        expect(requestBody['model'], 'kimi-k2.7-code');
        expect(requestBody.containsKey('thinking'), isFalse);
        expect(requestBody.containsKey('reasoning_effort'), isFalse);
        expect(requestBody.containsKey('temperature'), isFalse);
        expect(requestBody.containsKey('top_p'), isFalse);
        expect(requestBody.containsKey('n'), isFalse);
        expect(requestBody.containsKey('presence_penalty'), isFalse);
        expect(requestBody.containsKey('frequency_penalty'), isFalse);
      },
    );

    test(
      'maps DeepSeek reasoning knobs for non-streaming text generation',
      () async {
        final enabledBody = await _captureGenerateTextBody(
          providerId: 'DeepSeekCompatTest',
          modelId: 'deepseek-v4-pro',
          thinkingBudget: 64000,
        );
        final disabledBody = await _captureGenerateTextBody(
          providerId: 'DeepSeekCompatTest',
          modelId: 'deepseek-v4-pro',
          thinkingBudget: 0,
        );

        expect(enabledBody['thinking'], {'type': 'enabled'});
        expect(enabledBody['reasoning_effort'], 'xhigh');
        expect(disabledBody['thinking'], {'type': 'disabled'});
        expect(disabledBody.containsKey('reasoning_effort'), isFalse);
      },
    );

    test('maps GPT-5.6 maximum reasoning to max effort', () async {
      final maximumBody = await _captureGenerateTextBody(
        providerId: 'OpenAICompatTest',
        modelId: 'gpt-5.6-sol',
        thinkingBudget: 128000,
      );
      final xhighBody = await _captureGenerateTextBody(
        providerId: 'OpenAICompatTest',
        modelId: 'gpt-5.6-terra',
        thinkingBudget: 64000,
      );

      expect(maximumBody['reasoning_effort'], 'max');
      expect(xhighBody['reasoning_effort'], 'xhigh');
    });

    test(
      'maps DashScope reasoning knobs for non-streaming text generation',
      () async {
        final enabledBody = await _captureGenerateTextBody(
          providerId: 'DashScopeCompatTest',
          modelId: 'qwen3-plus',
          thinkingBudget: 2048,
          configBaseUrl: 'http://dashscope.aliyuncs.com/compatible-mode/v1',
        );
        final disabledBody = await _captureGenerateTextBody(
          providerId: 'DashScopeCompatTest',
          modelId: 'qwen3-plus',
          thinkingBudget: 0,
          configBaseUrl: 'http://dashscope.aliyuncs.com/compatible-mode/v1',
        );

        expect(enabledBody['enable_thinking'], isTrue);
        expect(enabledBody['thinking_budget'], 2048);
        expect(enabledBody.containsKey('reasoning_effort'), isFalse);
        expect(disabledBody['enable_thinking'], isFalse);
        expect(disabledBody.containsKey('thinking_budget'), isFalse);
        expect(disabledBody.containsKey('reasoning_effort'), isFalse);
      },
    );

    test(
      'maps SiliconFlow reasoning knobs for non-streaming text generation',
      () async {
        final enabledBody = await _captureGenerateTextBody(
          providerId: 'SiliconFlow',
          modelId: 'Qwen/Qwen3-8B',
          thinkingBudget: 1024,
        );
        final disabledBody = await _captureGenerateTextBody(
          providerId: 'SiliconFlow',
          modelId: 'Qwen/Qwen3-8B',
          thinkingBudget: 0,
        );

        expect(enabledBody['thinking_budget'], 1024);
        expect(enabledBody.containsKey('enable_thinking'), isFalse);
        expect(enabledBody.containsKey('reasoning_effort'), isFalse);
        expect(disabledBody['enable_thinking'], isFalse);
        expect(disabledBody.containsKey('thinking_budget'), isFalse);
        expect(disabledBody.containsKey('reasoning_effort'), isFalse);
      },
    );
  });
}
