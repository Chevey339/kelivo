import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/api/chat_api_service.dart';

const _conversationHeaderName = 'X-Conversation-Id';
const _conversationId = 'conversation-123';

ProviderConfig _openAiConfig(String baseUrl) {
  return ProviderConfig(
    id: 'OpenAITest',
    enabled: true,
    name: 'OpenAITest',
    apiKey: 'test-key',
    baseUrl: baseUrl,
    providerType: ProviderKind.openai,
  );
}

ProviderConfig _claudeConfig(String baseUrl) {
  return ProviderConfig(
    id: 'ClaudeTest',
    enabled: true,
    name: 'ClaudeTest',
    apiKey: 'test-key',
    baseUrl: baseUrl,
    providerType: ProviderKind.claude,
  );
}

ProviderConfig _geminiConfig(String baseUrl) {
  return ProviderConfig(
    id: 'GeminiTest',
    enabled: true,
    name: 'GeminiTest',
    apiKey: 'test-key',
    baseUrl: baseUrl,
    providerType: ProviderKind.google,
  );
}

void main() {
  group('ChatApiService extra headers', () {
    test('OpenAI-compatible requests forward conversation id header', () async {
      String? receivedConversationId;
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() async {
        await server.close(force: true);
      });

      server.listen((request) async {
        receivedConversationId = request.headers.value(_conversationHeaderName);
        await utf8.decoder.bind(request).join();
        request.response.statusCode = HttpStatus.ok;
        request.response.headers.contentType = ContentType.json;
        request.response.write(
          jsonEncode({
            'id': 'chatcmpl-1',
            'object': 'chat.completion',
            'choices': [
              {
                'index': 0,
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

      final chunks = await ChatApiService.sendMessageStream(
        config: _openAiConfig(
          'http://${server.address.address}:${server.port}/v1',
        ),
        modelId: 'gpt-4.1',
        messages: const [
          {'role': 'user', 'content': 'hello'},
        ],
        extraHeaders: const {_conversationHeaderName: _conversationId},
        stream: false,
      ).toList();

      expect(receivedConversationId, _conversationId);
      expect(chunks.last.isDone, isTrue);
    });

    test('Claude requests forward conversation id header', () async {
      String? receivedConversationId;
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() async {
        await server.close(force: true);
      });

      server.listen((request) async {
        receivedConversationId = request.headers.value(_conversationHeaderName);
        await utf8.decoder.bind(request).join();
        request.response.statusCode = HttpStatus.ok;
        request.response.headers.contentType = ContentType.json;
        request.response.write(
          jsonEncode({
            'id': 'msg_1',
            'content': [
              {'type': 'text', 'text': 'ok'},
            ],
            'usage': {'input_tokens': 1, 'output_tokens': 1},
          }),
        );
        await request.response.close();
      });

      final chunks = await ChatApiService.sendMessageStream(
        config: _claudeConfig(
          'http://${server.address.address}:${server.port}',
        ),
        modelId: 'claude-sonnet-4-5',
        messages: const [
          {'role': 'user', 'content': 'hello'},
        ],
        extraHeaders: const {_conversationHeaderName: _conversationId},
        stream: false,
      ).toList();

      expect(receivedConversationId, _conversationId);
      expect(chunks.last.isDone, isTrue);
    });

    test('Gemini requests forward conversation id header', () async {
      String? receivedConversationId;
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() async {
        await server.close(force: true);
      });

      server.listen((request) async {
        receivedConversationId = request.headers.value(_conversationHeaderName);
        await utf8.decoder.bind(request).join();
        request.response.statusCode = HttpStatus.ok;
        request.response.headers.contentType = ContentType.json;
        request.response.write(
          jsonEncode({
            'candidates': [
              {
                'content': {
                  'parts': [
                    {'text': 'ok'},
                  ],
                },
              },
            ],
            'usageMetadata': {
              'promptTokenCount': 1,
              'candidatesTokenCount': 1,
              'totalTokenCount': 2,
            },
          }),
        );
        await request.response.close();
      });

      final chunks = await ChatApiService.sendMessageStream(
        config: _geminiConfig(
          'http://${server.address.address}:${server.port}/v1beta',
        ),
        modelId: 'gemini-2.5-pro',
        messages: const [
          {'role': 'user', 'content': 'hello'},
        ],
        extraHeaders: const {_conversationHeaderName: _conversationId},
        stream: false,
      ).toList();

      expect(receivedConversationId, _conversationId);
      expect(chunks.last.isDone, isTrue);
    });
  });
}
