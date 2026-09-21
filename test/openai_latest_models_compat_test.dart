import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/api/chat_api_service.dart';
import 'package:Kelivo/core/utils/openai_model_compat.dart';
import 'support/collect_generation.dart';

ProviderConfig _openAIConfig(
  String baseUrl, {
  bool useResponseApi = false,
  String providerId = 'LatestModelCompatTest',
}) {
  return ProviderConfig(
    id: providerId,
    enabled: true,
    name: providerId,
    apiKey: 'test-key',
    baseUrl: baseUrl,
    providerType: ProviderKind.openai,
    useResponseApi: useResponseApi,
  );
}

Future<Map<String, dynamic>> _captureChatBody({
  required String modelId,
  required int thinkingBudget,
  double? temperature,
  double? topP,
  List<Map<String, dynamic>>? tools,
  String providerId = 'LatestModelCompatTest',
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
    request.response.headers.contentType = ContentType(
      'text',
      'event-stream',
      charset: 'utf-8',
    );
    request.response.write(
      'data: ${jsonEncode({
        'choices': [
          {
            'index': 0,
            'delta': {'role': 'assistant', 'content': 'ok'},
            'finish_reason': 'stop',
          },
        ],
      })}\n\n',
    );
    request.response.write('data: [DONE]\n\n');
    await request.response.close();
  });

  final chunks = await ChatApiService.sendMessageStream(
    config: _openAIConfig(
      'http://${server.address.address}:${server.port}/v1',
      providerId: providerId,
    ),
    modelId: modelId,
    messages: const [
      {'role': 'user', 'content': 'hello'},
    ],
    thinkingBudget: thinkingBudget,
    temperature: temperature,
    topP: topP,
    tools: tools,
  ).toList();

  expect(chunks.isGenerationDone, isTrue);
  return requestBody;
}

void main() {
  group('latest OpenAI-compatible model compatibility', () {
    test('normalizes only officially supported reasoning efforts', () {
      for (final modelId in const [
        'gpt-5.6-sol',
        'gpt-5.6-terra',
        'gpt-5.6-luna',
        'openai/gpt-5.6-sol',
      ]) {
        expect(openAINormalizeReasoningEffort('off', modelId), 'none');
        expect(openAINormalizeReasoningEffort('xhigh', modelId), 'xhigh');
        expect(openAINormalizeReasoningEffort('max', modelId), 'max');
      }

      expect(openAINormalizeReasoningEffort('off', 'kimi-k3'), 'low');
      expect(openAINormalizeReasoningEffort('medium', 'kimi-k3'), 'high');
      expect(openAINormalizeReasoningEffort('max', 'kimi-k3'), 'max');
      expect(
        openAINormalizeReasoningEffort('off', 'moonshotai/kimi-k3'),
        'low',
      );
      expect(openAISupportsMaxReasoning('moonshotai/kimi-k3'), isTrue);
      expect(openAINormalizeReasoningEffort('off', 'grok-4.5'), 'low');
      expect(openAINormalizeReasoningEffort('max', 'grok-4.5'), 'high');
      expect(openAINormalizeReasoningEffort('off', 'x-ai/grok-4.5'), 'low');
      expect(openAINormalizeReasoningEffort('off', 'grok-4.6'), 'low');
      expect(openAINormalizeReasoningEffort('xhigh', 'grok-4.6'), 'xhigh');
      expect(openAINormalizeReasoningEffort('max', 'x-ai/grok-4.6'), 'xhigh');
      expect(openAINormalizeReasoningEffort('off', 'deepseek-v4-pro'), 'off');
      expect(
        openAINormalizeReasoningEffort('medium', 'deepseek-v4-flash'),
        'high',
      );
      expect(
        openAINormalizeReasoningEffort('xhigh', 'deepseek-v4-pro'),
        'high',
      );
      expect(
        openAINormalizeReasoningEffort('max', 'deepseek-v4-flash-vision-exp'),
        'max',
      );
      expect(
        openAINormalizeReasoningEffort('medium', 'deepseek-flash'),
        'high',
      );
      expect(openAINormalizeReasoningEffort('max', 'deepseek-flash'), 'max');
      expect(
        openAINormalizeReasoningEffort('off', 'deepseek/deepseek-flash'),
        'off',
      );
      expect(openAINormalizeReasoningEffort('off', 'gpt-5-codex'), 'low');
      expect(openAINormalizeReasoningEffort('off', 'gpt-5.1-codex'), 'low');
      expect(
        openAINormalizeReasoningEffort('off', 'openai/gpt-5.1-codex-max'),
        'low',
      );
      expect(openAINormalizeReasoningEffort('xhigh', 'gpt-5.1-codex'), 'high');
      expect(
        openAINormalizeReasoningEffort('xhigh', 'gpt-5.1-codex-max'),
        'xhigh',
      );
      expect(openAINormalizeReasoningEffort('off', 'gpt-5.2-codex'), 'low');
      expect(openAINormalizeReasoningEffort('off', 'gpt-5.3-codex'), 'low');
      expect(
        openAINormalizeReasoningEffort('off', 'openai/gpt-5.3-codex'),
        'low',
      );
      expect(openAINormalizeReasoningEffort('off', 'gpt-5-pro'), 'high');
      expect(openAINormalizeReasoningEffort('off', 'gpt-5.2-pro'), 'medium');
      expect(openAINormalizeReasoningEffort('off', 'gpt-5.4-pro'), 'medium');
      expect(openAINormalizeReasoningEffort('off', 'gpt-5.5-pro'), 'medium');
      expect(openAISupportsNoneReasoning('gpt-5.3-codex'), isFalse);
      expect(openAISupportsXhighReasoning('gpt-5.3-codex'), isTrue);
      expect(openAINormalizeReasoningEffort('off', 'gpt-6-astra'), 'low');
      expect(
        openAINormalizeReasoningEffort('none', 'openai/gpt-6-astra'),
        'low',
      );
      expect(openAINormalizeReasoningEffort('max', 'gpt-6-astra'), 'max');
      expect(openAISupportsNoneReasoning('gpt-6-astra'), isFalse);
      expect(openAISupportsMaxReasoning('gpt-6-astra'), isTrue);
      expect(
        openAINormalizeReasoningEffort('high', 'meta/muse-spark-1.1'),
        'high',
      );
      expect(openAINormalizeReasoningEffort('off', 'muse-spark-1.3'), 'low');
      expect(openAISupportsMaxReasoning('muse-spark-1.3'), isTrue);
      expect(openAISupportsMaxReasoning('muse-spark-1.3-contributor'), isFalse);
      expect(openAINormalizeReasoningEffort('medium', 'glm-5.3'), 'high');
      expect(openAINormalizeReasoningEffort('off', 'glm-5.3-flash'), 'low');
      expect(openAISupportsMaxReasoning('z-ai/glm-5.3'), isTrue);
      expect(openAINormalizeReasoningEffort('off', 'glm-5.2'), 'off');
      expect(openAINormalizeReasoningEffort('low', 'glm-5.2'), 'low');
      expect(openAINormalizeReasoningEffort('xhigh', 'z-ai/glm-5.2'), 'xhigh');
      expect(openAISupportsMaxReasoning('glm-5.2'), isTrue);
    });

    test(
      'OpenRouter keeps mandatory reasoning enabled for namespaced models',
      () async {
        final kimiOff = await _captureChatBody(
          modelId: 'moonshotai/kimi-k3',
          thinkingBudget: 0,
          providerId: 'OpenRouter',
        );
        final kimiMax = await _captureChatBody(
          modelId: 'moonshotai/kimi-k3',
          thinkingBudget: 128000,
          providerId: 'OpenRouter',
        );
        final grokOff = await _captureChatBody(
          modelId: 'x-ai/grok-4.5',
          thinkingBudget: 0,
          providerId: 'OpenRouter',
        );

        expect(kimiOff['reasoning'], {'effort': 'low'});
        expect(kimiMax['reasoning'], {'effort': 'max'});
        expect(grokOff['reasoning'], {'effort': 'low'});
        for (final body in [kimiOff, kimiMax, grokOff]) {
          expect(body.containsKey('reasoning_effort'), isFalse);
          expect(body['reasoning'], isNot({'enabled': false}));
        }
      },
    );

    test('GPT-5.6 Chat tools force none in the provider format', () async {
      const tools = [
        {
          'type': 'function',
          'function': {
            'name': 'lookup',
            'description': 'Look something up',
            'parameters': {'type': 'object', 'properties': <String, dynamic>{}},
          },
        },
      ];
      final body = await _captureChatBody(
        modelId: 'openai/gpt-5.6-sol',
        thinkingBudget: 128000,
        temperature: 0.7,
        topP: 0.8,
        tools: tools,
      );
      final openRouterBody = await _captureChatBody(
        modelId: 'openai/gpt-5.6-sol',
        thinkingBudget: 128000,
        temperature: 0.7,
        topP: 0.8,
        tools: tools,
        providerId: 'OpenRouter',
      );

      expect(body['reasoning_effort'], 'none');
      expect(body['temperature'], 0.7);
      expect(body['top_p'], 0.8);
      expect(openRouterBody['reasoning'], {'effort': 'none'});
      expect(openRouterBody.containsKey('reasoning_effort'), isFalse);
      expect(openRouterBody['temperature'], 0.7);
      expect(openRouterBody['top_p'], 0.8);
    });

    test('GPT-5.6 auto effort omits incompatible sampling params', () async {
      final body = await _captureChatBody(
        modelId: 'openai/gpt-5.6-terra',
        thinkingBudget: -1,
        temperature: 0.7,
        topP: 0.8,
      );

      expect(body.containsKey('reasoning_effort'), isFalse);
      expect(body.containsKey('temperature'), isFalse);
      expect(body.containsKey('top_p'), isFalse);
    });

    test('Codex and Pro models clamp off to the lowest legal effort', () async {
      final codexOff = await _captureChatBody(
        modelId: 'gpt-5.3-codex',
        thinkingBudget: 0,
      );
      final namespacedCodexOff = await _captureChatBody(
        modelId: 'openai/gpt-5.2-codex',
        thinkingBudget: 0,
      );
      final proOff = await _captureChatBody(
        modelId: 'gpt-5.2-pro',
        thinkingBudget: 0,
      );
      final openRouterCodexOff = await _captureChatBody(
        modelId: 'openai/gpt-5.3-codex',
        thinkingBudget: 0,
        providerId: 'OpenRouter',
      );

      expect(codexOff['reasoning_effort'], 'low');
      expect(namespacedCodexOff['reasoning_effort'], 'low');
      expect(proOff['reasoning_effort'], 'medium');
      expect(openRouterCodexOff['reasoning'], {'effort': 'low'});
      expect(openRouterCodexOff.containsKey('reasoning_effort'), isFalse);
      expect(openRouterCodexOff['reasoning'], isNot({'enabled': false}));
    });

    test('Muse Spark 1.3 sends documented effort including max', () async {
      final body = await _captureChatBody(
        modelId: 'meta/muse-spark-1.3',
        thinkingBudget: 128000,
      );
      final offBody = await _captureChatBody(
        modelId: 'muse-spark-1.1',
        thinkingBudget: 0,
      );

      expect(body['reasoning_effort'], 'max');
      expect(offBody['reasoning_effort'], 'low');
    });

    test('GPT-6 Astra omits sampling and never sends none', () async {
      const tools = [
        {
          'type': 'function',
          'function': {
            'name': 'lookup',
            'description': 'Look something up',
            'parameters': {'type': 'object', 'properties': <String, dynamic>{}},
          },
        },
      ];
      final offBody = await _captureChatBody(
        modelId: 'gpt-6-astra',
        thinkingBudget: 0,
        temperature: 0.7,
        topP: 0.8,
        tools: tools,
      );
      final maxBody = await _captureChatBody(
        modelId: 'openai/gpt-6-astra',
        thinkingBudget: 128000,
        temperature: 0.7,
        topP: 0.8,
      );

      expect(offBody['reasoning_effort'], 'low');
      expect(offBody.containsKey('temperature'), isFalse);
      expect(offBody.containsKey('top_p'), isFalse);
      expect(maxBody['reasoning_effort'], 'max');
      expect(maxBody.containsKey('temperature'), isFalse);
    });

    test('Grok 4.6 Responses keeps xhigh and clamps off to low', () async {
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
        request.response.headers.contentType = ContentType(
          'text',
          'event-stream',
          charset: 'utf-8',
        );
        request.response.write(
          'data: ${jsonEncode({'type': 'response.output_text.delta', 'delta': 'answer'})}\n\n',
        );
        request.response.write(
          'data: ${jsonEncode({
            'type': 'response.completed',
            'response': {
              'output': const [],
              'usage': {'input_tokens': 1, 'output_tokens': 2},
            },
          })}\n\n',
        );
        request.response.write('data: [DONE]\n\n');
        await request.response.close();
      });

      final offChunks = await ChatApiService.sendMessageStream(
        config: _openAIConfig(
          'http://${server.address.address}:${server.port}/v1',
          useResponseApi: true,
        ),
        modelId: 'grok-4.6',
        messages: const [
          {'role': 'user', 'content': 'hello'},
        ],
        thinkingBudget: 0,
      ).toList();
      expect(offChunks.isGenerationDone, isTrue);
      expect((requestBody['reasoning'] as Map)['effort'], 'low');

      final xhighChunks = await ChatApiService.sendMessageStream(
        config: _openAIConfig(
          'http://${server.address.address}:${server.port}/v1',
          useResponseApi: true,
        ),
        modelId: 'grok-4.6',
        messages: const [
          {'role': 'user', 'content': 'hello'},
        ],
        thinkingBudget: 64000,
      ).toList();
      expect(xhighChunks.isGenerationDone, isTrue);
      expect((requestBody['reasoning'] as Map)['effort'], 'xhigh');
    });

    test('Grok Responses streams reasoning text and clamps off to low', () async {
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
        request.response.headers.contentType = ContentType(
          'text',
          'event-stream',
          charset: 'utf-8',
        );
        request.response.write(
          'data: ${jsonEncode({'type': 'response.reasoning_text.delta', 'delta': 'reasoning summary'})}\n\n',
        );
        request.response.write(
          'data: ${jsonEncode({'type': 'response.output_text.delta', 'delta': 'answer'})}\n\n',
        );
        request.response.write(
          'data: ${jsonEncode({
            'type': 'response.completed',
            'response': {
              'output': const [],
              'usage': {'input_tokens': 1, 'output_tokens': 2},
            },
          })}\n\n',
        );
        request.response.write('data: [DONE]\n\n');
        await request.response.close();
      });

      final chunks = await ChatApiService.sendMessageStream(
        config: _openAIConfig(
          'http://${server.address.address}:${server.port}/v1',
          useResponseApi: true,
        ),
        modelId: 'grok-4.5',
        messages: const [
          {'role': 'user', 'content': 'hello'},
        ],
        thinkingBudget: 0,
      ).toList();

      expect((requestBody['reasoning'] as Map)['effort'], 'low');
      expect(chunks.joinedReasoning, contains('reasoning summary'));
      expect(chunks.joinedContent, contains('answer'));
    });
  });
}
