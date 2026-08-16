import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/api/chat_api_service.dart';
import 'package:Kelivo/core/utils/openai_model_compat.dart';
import 'support/collect_generation.dart';

ProviderConfig _mimoConfig(String baseUrl) {
  return ProviderConfig(
    id: 'XiaomiMiMo',
    enabled: true,
    name: 'Xiaomi MiMo',
    apiKey: 'test-key',
    baseUrl: baseUrl,
    providerType: ProviderKind.openai,
    useResponseApi: true,
  );
}

Future<Map<String, dynamic>> _readJsonBody(HttpRequest request) async {
  return jsonDecode(await utf8.decoder.bind(request).join())
      as Map<String, dynamic>;
}

void main() {
  group('Xiaomi MiMo Responses compatibility', () {
    test('normalizes reasoning efforts to the documented values', () {
      expect(openAINormalizeReasoningEffort('off', 'mimo-v2.5-pro'), 'none');
      expect(openAINormalizeReasoningEffort('xhigh', 'mimo-v2.5-pro'), 'high');
      expect(openAINormalizeReasoningEffort('max', 'xiaomi/mimo-v2.5'), 'high');
    });

    test('streams reasoning text and cached token usage', () async {
      late Map<String, dynamic> requestBody;
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() async {
        await server.close(force: true);
      });

      server.listen((request) async {
        requestBody = await _readJsonBody(request);
        request.response.statusCode = HttpStatus.ok;
        request.response.headers.contentType = ContentType(
          'text',
          'event-stream',
          charset: 'utf-8',
        );
        request.response.write(
          'data: ${jsonEncode({'type': 'response.reasoning_text.delta', 'sequence_number': 1, 'output_index': 0, 'content_index': 0, 'item_id': 'reasoning-mimo', 'delta': '先比较两个小数。'})}\n\n',
        );
        request.response.write(
          'data: ${jsonEncode({'type': 'response.output_text.delta', 'sequence_number': 2, 'output_index': 1, 'content_index': 0, 'item_id': 'message-mimo', 'delta': '9.8 更大。'})}\n\n',
        );
        request.response.write(
          'data: ${jsonEncode({
            'type': 'response.completed',
            'sequence_number': 3,
            'response': {
              'status': 'completed',
              'output': const [],
              'usage': {
                'input_tokens': 100,
                'input_tokens_details': {'cached_tokens': 64},
                'output_tokens': 30,
                'output_tokens_details': {'reasoning_tokens': 20},
                'total_tokens': 130,
              },
            },
          })}\n\n',
        );
        await request.response.close();
      });

      final baseUrl = 'http://${server.address.address}:${server.port}/v1';
      final chunks = await ChatApiService.sendMessageStream(
        config: _mimoConfig(baseUrl),
        modelId: 'mimo-v2.5-pro',
        messages: const [
          {'role': 'user', 'content': '9.11 和 9.8 哪个大？'},
        ],
        thinkingBudget: 2000,
      ).toList();

      expect(requestBody['reasoning'], {'effort': 'low'});
      expect(chunks.joinedReasoning, '先比较两个小数。');
      expect(chunks.joinedContent, contains('9.8 更大。'));
      expect(chunks.isGenerationDone, isTrue);
      expect(chunks.lastUsage?.cachedTokens, 64);
      expect(chunks.lastUsage?.totalTokens, 130);
    });

    test(
      'non-stream returns reasoning and uses default thinking mode',
      () async {
        late Map<String, dynamic> requestBody;
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        addTearDown(() async {
          await server.close(force: true);
        });

        server.listen((request) async {
          requestBody = await _readJsonBody(request);
          request.response.statusCode = HttpStatus.ok;
          request.response.headers.contentType = ContentType.json;
          request.response.write(
            jsonEncode({
              'id': 'resp-mimo',
              'object': 'response',
              'status': 'completed',
              'output': [
                {
                  'id': 'reasoning-mimo',
                  'type': 'reasoning',
                  'status': 'completed',
                  'content': [
                    {'type': 'reasoning_text', 'text': '先分析问题。'},
                  ],
                },
                {
                  'id': 'message-mimo',
                  'type': 'message',
                  'status': 'completed',
                  'role': 'assistant',
                  'content': [
                    {'type': 'output_text', 'text': '这是答案。'},
                  ],
                },
              ],
              'output_text': '这是答案。',
              'usage': {
                'input_tokens': 50,
                'input_tokens_details': {'cached_tokens': 32},
                'output_tokens': 10,
                'output_tokens_details': {'reasoning_tokens': 6},
                'total_tokens': 60,
              },
            }),
          );
          await request.response.close();
        });

        final baseUrl = 'http://${server.address.address}:${server.port}/v1';
        final chunks = await ChatApiService.sendMessageStream(
          config: _mimoConfig(baseUrl),
          modelId: 'mimo-v2.5-pro',
          messages: const [
            {'role': 'user', 'content': '请回答问题'},
          ],
          stream: false,
        ).toList();

        expect(requestBody.containsKey('reasoning'), isFalse);
        expect(chunks.joinedContent, '这是答案。');
        expect(chunks.joinedReasoning, '先分析问题。');
        expect(chunks.lastUsage?.cachedTokens, 32);
        expect(chunks.lastUsage?.totalTokens, 60);
      },
    );

    test('off reasoning sends effort none', () async {
      late Map<String, dynamic> requestBody;
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() async {
        await server.close(force: true);
      });

      server.listen((request) async {
        requestBody = await _readJsonBody(request);
        request.response.statusCode = HttpStatus.ok;
        request.response.headers.contentType = ContentType.json;
        request.response.write(
          jsonEncode({
            'id': 'resp-mimo',
            'object': 'response',
            'status': 'completed',
            'output': const [],
            'output_text': 'ok',
            'usage': {
              'input_tokens': 1,
              'input_tokens_details': {'cached_tokens': 0},
              'output_tokens': 1,
              'output_tokens_details': {'reasoning_tokens': 0},
              'total_tokens': 2,
            },
          }),
        );
        await request.response.close();
      });

      final baseUrl = 'http://${server.address.address}:${server.port}/v1';
      final chunks = await ChatApiService.sendMessageStream(
        config: _mimoConfig(baseUrl),
        modelId: 'mimo-v2.5-pro',
        messages: const [
          {'role': 'user', 'content': 'hello'},
        ],
        thinkingBudget: 0,
        stream: false,
      ).toList();

      expect(chunks.isGenerationDone, isTrue);
      expect(requestBody['reasoning'], {'effort': 'none'});
    });
  });
}
