import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/api/chat_api_service.dart';

/// Regression tests for https://github.com/Chevey339/kelivo/issues/764
///
/// Claude models served through OpenAI-compatible proxies rebuild Anthropic
/// thinking blocks from the echoed reasoning fields. An unsigned
/// `reasoning_content` echo fails validation with
/// "thinking.signature: Field required", so it must be dropped unless the
/// signature-carrying `reasoning_details` are present.
ProviderConfig _openAIConfig(String baseUrl) {
  return ProviderConfig(
    id: 'ClaudeProxyTest',
    enabled: true,
    name: 'ClaudeProxyTest',
    apiKey: 'test-key',
    baseUrl: baseUrl,
    providerType: ProviderKind.openai,
  );
}

void main() {
  group('Claude via OpenAI-compatible proxy thinking signature', () {
    test('stream emits captured reasoning_details for persistence', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() async {
        await server.close(force: true);
      });

      server.listen((request) async {
        await utf8.decoder.bind(request).join();
        request.response.statusCode = HttpStatus.ok;
        request.response.headers.contentType = ContentType(
          'text',
          'event-stream',
        );
        request.response.write(
          'data: {"choices":[{"delta":{"reasoning_content":"thinking..."},"finish_reason":null}]}\n\n',
        );
        request.response.write(
          'data: {"choices":[{"delta":{"reasoning_details":[{"type":"reasoning.text","text":"thinking...","signature":"sig-proxy-1"}],"content":"done"},"finish_reason":"stop"}]}\n\n',
        );
        request.response.write('data: [DONE]\n\n');
        await request.response.close();
      });

      final chunks = await ChatApiService.sendMessageStream(
        config: _openAIConfig(
          'http://${server.address.address}:${server.port}/v1',
        ),
        modelId: 'claude-sonnet-4-6',
        messages: const [
          {'role': 'user', 'content': 'hello'},
        ],
      ).toList();

      final done = chunks.last;
      expect(done.isDone, isTrue);
      expect(done.reasoningDetails, isA<List>());
      expect(
        (done.reasoningDetails as List).first['signature'],
        'sig-proxy-1',
      );
    });

    test(
      'unsigned reasoning_content is stripped from Claude history replay',
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
          request.response.headers.contentType = ContentType(
            'text',
            'event-stream',
          );
          request.response.write(
            'data: {"choices":[{"delta":{"content":"ok"},"finish_reason":"stop"}]}\n\n',
          );
          request.response.write('data: [DONE]\n\n');
          await request.response.close();
        });

        final chunks = await ChatApiService.sendMessageStream(
          config: _openAIConfig(
            'http://${server.address.address}:${server.port}/v1',
          ),
          modelId: 'claude-sonnet-4-6',
          messages: const [
            {'role': 'user', 'content': 'hello'},
            {
              'role': 'assistant',
              'content': 'hi there',
              'reasoning_content': 'unsigned thinking text',
            },
            {'role': 'user', 'content': 'follow up'},
          ],
        ).toList();

        expect(chunks.last.isDone, isTrue);
        final messages = (requestBody['messages'] as List).cast<Map>();
        final assistant = messages[1];
        expect(assistant.containsKey('reasoning_content'), isFalse);
        expect(assistant.containsKey('reasoning'), isFalse);
        expect(assistant['content'], 'hi there');
      },
    );

    test(
      'signed reasoning_details are echoed back on Claude history replay',
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
          request.response.headers.contentType = ContentType(
            'text',
            'event-stream',
          );
          request.response.write(
            'data: {"choices":[{"delta":{"content":"ok"},"finish_reason":"stop"}]}\n\n',
          );
          request.response.write('data: [DONE]\n\n');
          await request.response.close();
        });

        const details = [
          {
            'type': 'reasoning.text',
            'text': 'signed thinking text',
            'signature': 'sig-proxy-1',
          },
        ];
        final chunks = await ChatApiService.sendMessageStream(
          config: _openAIConfig(
            'http://${server.address.address}:${server.port}/v1',
          ),
          modelId: 'claude-sonnet-4-6',
          messages: const [
            {'role': 'user', 'content': 'hello'},
            {
              'role': 'assistant',
              'content': 'hi there',
              'reasoning_content': 'signed thinking text',
              'reasoning_details': details,
            },
            {'role': 'user', 'content': 'follow up'},
          ],
        ).toList();

        expect(chunks.last.isDone, isTrue);
        final messages = (requestBody['messages'] as List).cast<Map>();
        final assistant = messages[1];
        expect(assistant['reasoning_content'], 'signed thinking text');
        expect(
          (assistant['reasoning_details'] as List).first['signature'],
          'sig-proxy-1',
        );
      },
    );

    test('streamed reasoning_details deltas are accumulated in order', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() async {
        await server.close(force: true);
      });

      server.listen((request) async {
        await utf8.decoder.bind(request).join();
        request.response.statusCode = HttpStatus.ok;
        request.response.headers.contentType = ContentType(
          'text',
          'event-stream',
        );
        // OpenRouter-style: the array arrives as ordered deltas across chunks.
        request.response.write(
          'data: {"choices":[{"delta":{"reasoning_details":[{"type":"reasoning.text","text":"part A","signature":"sig-a"}]},"finish_reason":null}]}\n\n',
        );
        request.response.write(
          'data: {"choices":[{"delta":{"reasoning_details":[{"type":"reasoning.text","text":"part B","signature":"sig-b"}],"content":"done"},"finish_reason":"stop"}]}\n\n',
        );
        request.response.write('data: [DONE]\n\n');
        await request.response.close();
      });

      final chunks = await ChatApiService.sendMessageStream(
        config: _openAIConfig(
          'http://${server.address.address}:${server.port}/v1',
        ),
        modelId: 'claude-sonnet-4-6',
        messages: const [
          {'role': 'user', 'content': 'hello'},
        ],
      ).toList();

      final details = chunks.last.reasoningDetails as List;
      expect(details, hasLength(2));
      expect(details[0]['signature'], 'sig-a');
      expect(details[1]['signature'], 'sig-b');
    });

    test('identical consecutive reasoning_details deltas are both kept',
        () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() async {
        await server.close(force: true);
      });

      server.listen((request) async {
        await utf8.decoder.bind(request).join();
        request.response.statusCode = HttpStatus.ok;
        request.response.headers.contentType = ContentType(
          'text',
          'event-stream',
        );
        // Two byte-identical deltas: per OpenRouter docs the full sequence is
        // the ordered concatenation of all chunks, so both must be kept.
        const delta =
            'data: {"choices":[{"delta":{"reasoning_details":[{"type":"reasoning.text","text":"same","signature":"sig-x"}]},"finish_reason":null}]}\n\n';
        request.response.write(delta);
        request.response.write(delta);
        request.response.write(
          'data: {"choices":[{"delta":{"content":"done"},"finish_reason":"stop"}]}\n\n',
        );
        request.response.write('data: [DONE]\n\n');
        await request.response.close();
      });

      final chunks = await ChatApiService.sendMessageStream(
        config: _openAIConfig(
          'http://${server.address.address}:${server.port}/v1',
        ),
        modelId: 'claude-sonnet-4-6',
        messages: const [
          {'role': 'user', 'content': 'hello'},
        ],
      ).toList();

      final details = chunks.last.reasoningDetails as List;
      expect(details, hasLength(2));
      expect(details[0]['signature'], 'sig-x');
      expect(details[1]['signature'], 'sig-x');
    });

    test(
        'OpenRouter deltas are always concatenated, even with repeated prefix',
        () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() async {
        await server.close(force: true);
      });

      server.listen((request) async {
        await utf8.decoder.bind(request).join();
        request.response.statusCode = HttpStatus.ok;
        request.response.headers.contentType = ContentType(
          'text',
          'event-stream',
        );
        // Two delta chunks where the second carries two new entries; per
        // OpenRouter docs the full sequence is the ordered concatenation of
        // all chunks, so the result must be [X, X, Y], not [X, Y].
        request.response.write(
          'data: {"choices":[{"delta":{"reasoning_details":[{"type":"reasoning.text","text":"entry","signature":"sig-x"}]},"finish_reason":null}]}\n\n',
        );
        request.response.write(
          'data: {"choices":[{"delta":{"reasoning_details":[{"type":"reasoning.text","text":"entry","signature":"sig-x"},{"type":"reasoning.text","text":"other","signature":"sig-y"}],"content":"done"},"finish_reason":"stop"}]}\n\n',
        );
        request.response.write('data: [DONE]\n\n');
        await request.response.close();
      });

      final chunks = await ChatApiService.sendMessageStream(
        config: ProviderConfig(
          id: 'OpenRouter',
          enabled: true,
          name: 'OpenRouter',
          apiKey: 'test-key',
          baseUrl: 'http://${server.address.address}:${server.port}/v1',
          providerType: ProviderKind.openai,
        ),
        modelId: 'claude-sonnet-4-6',
        messages: const [
          {'role': 'user', 'content': 'hello'},
        ],
      ).toList();

      final details = chunks.last.reasoningDetails as List;
      expect(details, hasLength(3));
      expect(details[0]['signature'], 'sig-x');
      expect(details[1]['signature'], 'sig-x');
      expect(details[2]['signature'], 'sig-y');
    });

    test('cumulative reasoning_details snapshots replace, not duplicate',
        () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() async {
        await server.close(force: true);
      });

      server.listen((request) async {
        await utf8.decoder.bind(request).join();
        request.response.statusCode = HttpStatus.ok;
        request.response.headers.contentType = ContentType(
          'text',
          'event-stream',
        );
        // Some providers resend the full array-so-far with each chunk.
        request.response.write(
          'data: {"choices":[{"delta":{"reasoning_details":[{"type":"reasoning.text","text":"part A","signature":"sig-a"}]},"finish_reason":null}]}\n\n',
        );
        request.response.write(
          'data: {"choices":[{"delta":{"reasoning_details":[{"type":"reasoning.text","text":"part A","signature":"sig-a"},{"type":"reasoning.text","text":"part B","signature":"sig-b"}],"content":"done"},"finish_reason":"stop"}]}\n\n',
        );
        // Final chunk repeats the same full array; it must not be appended.
        request.response.write(
          'data: {"choices":[{"delta":{"reasoning_details":[{"type":"reasoning.text","text":"part A","signature":"sig-a"},{"type":"reasoning.text","text":"part B","signature":"sig-b"}]},"finish_reason":"stop"}]}\n\n',
        );
        request.response.write('data: [DONE]\n\n');
        await request.response.close();
      });

      final chunks = await ChatApiService.sendMessageStream(
        config: _openAIConfig(
          'http://${server.address.address}:${server.port}/v1',
        ),
        modelId: 'claude-sonnet-4-6',
        messages: const [
          {'role': 'user', 'content': 'hello'},
        ],
      ).toList();

      final details = chunks.last.reasoningDetails as List;
      expect(details, hasLength(2));
      expect(details[0]['signature'], 'sig-a');
      expect(details[1]['signature'], 'sig-b');
    });

    test(
      'non-Claude models keep unsigned reasoning_content in history',
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
          request.response.headers.contentType = ContentType(
            'text',
            'event-stream',
          );
          request.response.write(
            'data: {"choices":[{"delta":{"content":"ok"},"finish_reason":"stop"}]}\n\n',
          );
          request.response.write('data: [DONE]\n\n');
          await request.response.close();
        });

        final chunks = await ChatApiService.sendMessageStream(
          config: _openAIConfig(
            'http://${server.address.address}:${server.port}/v1',
          ),
          modelId: 'kimi-k2-thinking',
          messages: const [
            {'role': 'user', 'content': 'hello'},
            {
              'role': 'assistant',
              'content': 'hi there',
              'reasoning_content': 'kimi thinking text',
            },
            {'role': 'user', 'content': 'follow up'},
          ],
        ).toList();

        expect(chunks.last.isDone, isTrue);
        final messages = (requestBody['messages'] as List).cast<Map>();
        expect(messages[1]['reasoning_content'], 'kimi thinking text');
      },
    );
  });
}
