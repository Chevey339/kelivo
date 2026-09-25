import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/api/chat_api_service.dart';
import 'support/collect_generation.dart';
import 'support/legacy_reasoning.dart';

ProviderConfig _openAIConfig(
  String baseUrl, {
  bool useResponseApi = false,
  String providerId = 'LatestModelCompatTest',
  Map<String, dynamic> modelOverrides = const {},
}) {
  return ProviderConfig(
    id: providerId,
    enabled: true,
    name: providerId,
    apiKey: 'test-key',
    baseUrl: baseUrl,
    providerType: ProviderKind.openai,
    useResponseApi: useResponseApi,
    modelOverrides: modelOverrides,
  );
}

Future<Map<String, dynamic>> _captureChatBody({
  required String modelId,
  int? thinkingBudget,
  double? temperature,
  double? topP,
  List<Map<String, dynamic>>? tools,
  Map<String, dynamic>? extraBody,
  String providerId = 'LatestModelCompatTest',
  bool useResponseApi = false,
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
    if (useResponseApi) {
      request.response.headers.contentType = ContentType(
        'text',
        'event-stream',
        charset: 'utf-8',
      );
      request.response.write(
        'data: ${jsonEncode({'type': 'response.output_text.delta', 'delta': 'ok'})}\n\n',
      );
      request.response.write(
        'data: ${jsonEncode({
          'type': 'response.completed',
          'response': {
            'output': const [],
            'usage': {'input_tokens': 1, 'output_tokens': 1},
          },
        })}\n\n',
      );
      request.response.write('data: [DONE]\n\n');
    } else {
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
    }
    await request.response.close();
  });

  final chunks = await ChatApiService.sendMessageStream(
    config: _openAIConfig(
      'http://${server.address.address}:${server.port}/v1',
      providerId: providerId,
      useResponseApi: useResponseApi,
    ),
    modelId: modelId,
    messages: const [
      {'role': 'user', 'content': 'hello'},
    ],
    reasoning: legacyBudget(thinkingBudget),
    temperature: temperature,
    topP: topP,
    tools: tools,
    extraBody: extraBody,
  ).toList();

  expect(chunks.isGenerationDone, isTrue);
  return requestBody;
}

void main() {
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

  group('latest OpenAI-compatible request bodies', () {
    test('auto writes no effort and leaves unrelated extraBody keys', () async {
      final body = await _captureChatBody(
        modelId: 'gpt-5.2',
        thinkingBudget: -1,
        extraBody: const {'foo': 'bar', 'reasoning_effort': 'high'},
      );
      expect(body.containsKey('reasoning_effort'), isTrue);
      expect(body['reasoning_effort'], 'high');
      expect(body['foo'], 'bar');
    });

    test('off on always-on models clamps to the lowest legal effort', () async {
      final cases = <(String, String)>[
        ('gpt-5.3-codex', 'low'),
        ('openai/gpt-5.2-codex', 'low'),
        ('gpt-5.2-pro', 'medium'),
        ('gpt-5-pro', 'high'),
        ('muse-spark-1.1', 'low'),
        ('grok-4.5', 'low'),
        ('grok-4.6', 'low'),
        ('grok-4.7', 'low'),
        ('x-ai/grok-4.7', 'low'),
      ];
      for (final (modelId, effort) in cases) {
        final body = await _captureChatBody(
          modelId: modelId,
          thinkingBudget: 0,
        );
        expect(body['reasoning_effort'], effort, reason: modelId);
      }
    });

    test(
      'OpenRouter off on always-on models writes effort not enabled:false',
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
        final codexOff = await _captureChatBody(
          modelId: 'openai/gpt-5.3-codex',
          thinkingBudget: 0,
          providerId: 'OpenRouter',
        );

        expect(kimiOff['reasoning'], {'effort': 'low'});
        expect(kimiMax['reasoning'], {'effort': 'max'});
        expect(grokOff['reasoning'], {'effort': 'low'});
        expect(codexOff['reasoning'], {'effort': 'low'});
        for (final body in [kimiOff, kimiMax, grokOff, codexOff]) {
          expect(body.containsKey('reasoning_effort'), isFalse);
          expect(body['reasoning'], isNot({'enabled': false}));
        }
      },
    );

    test('GPT-5.6 tools no longer force none; sampling follows spec', () async {
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

      expect(body['reasoning_effort'], 'max');
      expect(body.containsKey('temperature'), isFalse);
      expect(body.containsKey('top_p'), isFalse);
      expect(openRouterBody['reasoning'], {'effort': 'max'});
      expect(openRouterBody.containsKey('reasoning_effort'), isFalse);
      expect(openRouterBody.containsKey('temperature'), isFalse);
      expect(openRouterBody.containsKey('top_p'), isFalse);
    });

    test('GPT-5.6 auto omits effort and strips sampling', () async {
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

    test('nearest-level clamping replaces per-vendor normalization', () async {
      final body = await _captureChatBody(
        modelId: 'meta/muse-spark-1.3',
        thinkingBudget: 128000,
      );
      final kimiMedium = await _captureChatBody(
        modelId: 'kimi-k3',
        thinkingBudget: 16000,
      );
      final deepseekMedium = await _captureChatBody(
        modelId: 'deepseek-v4-flash',
        thinkingBudget: 16000,
      );

      expect(body['reasoning_effort'], 'max');
      expect(kimiMedium['reasoning_effort'], 'low');
      expect(deepseekMedium['thinking'], {'type': 'enabled'});
      expect(deepseekMedium['reasoning_effort'], 'low');
    });

    test('GPT-6 Astra omits sampling and never sends none', () async {
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

    test(
      'Grok Responses auto writes summary only; off clamps to low',
      () async {
        final offBody = await _captureChatBody(
          modelId: 'grok-4.6',
          thinkingBudget: 0,
          useResponseApi: true,
        );
        final xhighBody = await _captureChatBody(
          modelId: 'grok-4.6',
          thinkingBudget: 64000,
          useResponseApi: true,
        );
        final autoBody = await _captureChatBody(
          modelId: 'grok-4.5',
          thinkingBudget: -1,
          useResponseApi: true,
        );

        expect((offBody['reasoning'] as Map)['effort'], 'low');
        expect((xhighBody['reasoning'] as Map)['effort'], 'xhigh');
        expect(autoBody['reasoning'], {'summary': 'auto'});
        expect((autoBody['reasoning'] as Map).containsKey('effort'), isFalse);
      },
    );
  });
}
