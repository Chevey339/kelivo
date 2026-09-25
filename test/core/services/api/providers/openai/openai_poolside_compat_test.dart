import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/api/chat_api_service.dart';
import '../../../../../support/collect_generation.dart';
import '../../../../../support/legacy_reasoning.dart';

ProviderConfig _poolsideConfig(String baseUrl, {bool useResponseApi = false}) {
  return ProviderConfig(
    id: 'Poolside',
    enabled: true,
    name: 'Poolside',
    apiKey: 'test-key',
    baseUrl: baseUrl,
    providerType: ProviderKind.openai,
    useResponseApi: useResponseApi,
  );
}

Future<Map<String, dynamic>> _captureBody({
  required String modelId,
  required int? thinkingBudget,
  bool useResponseApi = false,
  Map<String, dynamic>? extraBody,
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
              'delta': {'content': 'ok'},
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
    config: _poolsideConfig(
      'http://${server.address.address}:${server.port}/v1',
      useResponseApi: useResponseApi,
    ),
    modelId: modelId,
    messages: const [
      {'role': 'user', 'content': 'hello'},
    ],
    reasoning: legacyBudget(thinkingBudget),
    extraBody: extraBody,
  ).toList();
  expect(chunks.isGenerationDone, isTrue);
  return requestBody;
}

void main() {
  group('Poolside Laguna thinking knobs', () {
    test('Laguna chat completions map budget to enable_thinking', () async {
      final enabled = await _captureBody(
        modelId: 'poolside/laguna-s-2.1',
        thinkingBudget: 128000,
      );
      final disabled = await _captureBody(
        modelId: 'laguna-xs-2.1',
        thinkingBudget: 0,
      );
      final auto = await _captureBody(
        modelId: 'poolside/laguna-s-2.1',
        thinkingBudget: -1,
      );

      expect(enabled['chat_template_kwargs'], {'enable_thinking': true});
      expect(enabled.containsKey('reasoning_effort'), isFalse);
      expect(disabled['chat_template_kwargs'], {'enable_thinking': false});
      expect(auto.containsKey('chat_template_kwargs'), isFalse);
    });

    test('custom body merges into the dialect object', () async {
      final body = await _captureBody(
        modelId: 'poolside/laguna-s-2.1',
        thinkingBudget: 128000,
        extraBody: const {
          'chat_template_kwargs': {'foo': 'bar'},
        },
      );
      expect(body['chat_template_kwargs'], {
        'foo': 'bar',
        'enable_thinking': true,
      });
    });

    test(
      'Responses path uses chat_template_kwargs instead of reasoning',
      () async {
        final body = await _captureBody(
          modelId: 'poolside/laguna-s-2.1',
          thinkingBudget: 128000,
          useResponseApi: true,
        );
        expect(body['chat_template_kwargs'], {'enable_thinking': true});
        expect(body.containsKey('reasoning'), isFalse);
      },
    );
  });
}
