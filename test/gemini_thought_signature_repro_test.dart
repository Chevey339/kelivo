import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/api/chat_api_service.dart';

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

Map<String, dynamic> _streamChunk(
  List<Map<String, dynamic>> parts, {
  String? finishReason,
}) {
  return {
    'candidates': [
      {
        'content': {'parts': parts},
        if (finishReason != null) 'finishReason': finishReason,
      },
    ],
    'usageMetadata': {
      'promptTokenCount': 1,
      'candidatesTokenCount': 1,
      'totalTokenCount': 2,
    },
  };
}

Map<String, dynamic> _functionCallPart({
  required String name,
  required Map<String, dynamic> args,
  String? thoughtSignature,
}) {
  return {
    'functionCall': {'name': name, 'args': args},
    if (thoughtSignature != null) 'thoughtSignature': thoughtSignature,
  };
}

Map<String, dynamic> _toolCallPart({
  required String toolType,
  required Map<String, dynamic> args,
  required String id,
  String? thoughtSignature,
}) {
  return {
    'toolCall': {'toolType': toolType, 'args': args, 'id': id},
    if (thoughtSignature != null) 'thoughtSignature': thoughtSignature,
  };
}

Map<String, dynamic> _textPart({
  required String text,
  String? thoughtSignature,
}) {
  return {
    'text': text,
    if (thoughtSignature != null) 'thoughtSignature': thoughtSignature,
  };
}

bool _hasThoughtSignature(Map<dynamic, dynamic> part) {
  return part.containsKey('thoughtSignature') ||
      part.containsKey('thought_signature');
}

String? _thoughtSignatureOf(Map<dynamic, dynamic> part) {
  return (part['thoughtSignature'] ?? part['thought_signature'])?.toString();
}

void main() {
  group('Gemini mixed tool thought signature repro', () {
    test('does not move a detached signature onto an unsigned functionCall', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() async {
        await server.close(force: true);
      });

      var requestCount = 0;
      server.listen((request) async {
        requestCount++;
        final bodyText = await utf8.decoder.bind(request).join();

        if (requestCount == 1) {
          request.response.statusCode = HttpStatus.ok;
          request.response.headers.contentType = ContentType(
            'text',
            'event-stream',
          );
          request.response.headers.set('Transfer-Encoding', 'chunked');
          request.response.write(
            'data: ${jsonEncode(_streamChunk([
              _functionCallPart(name: 'google_search', args: {'query': 'Kelivo fetch'}),
            ]))}\n\n',
          );
          request.response.write(
            'data: ${jsonEncode(_streamChunk([_textPart(text: '', thoughtSignature: 'sig-google-search')], finishReason: 'STOP'))}\n\n',
          );
          request.response.write('data: [DONE]');
          await request.response.close();
          return;
        }

        if (requestCount == 2) {
          final body = jsonDecode(bodyText) as Map<String, dynamic>;
          final contents = (body['contents'] as List).cast<Map>();
          final modelParts = (contents[1]['parts'] as List).cast<Map>();
          final firstCall = modelParts.firstWhere(
            (p) => p.containsKey('functionCall'),
          );
          final detachedSignature = modelParts.firstWhere(
            (p) =>
                p['text'] == '' &&
                _thoughtSignatureOf(p) == 'sig-google-search',
          );

          expect(_hasThoughtSignature(firstCall), isFalse);
          expect(_thoughtSignatureOf(detachedSignature), 'sig-google-search');

          request.response.statusCode = HttpStatus.badRequest;
          request.response.headers.contentType = ContentType.json;
          request.response.write(
            jsonEncode({
              'error': {
                'code': 400,
                'message':
                    'Function call is missing a thought_signature in functionCall parts. Additional data, function call `google:search`, position 6.',
                'status': 'INVALID_ARGUMENT',
              },
            }),
          );
          await request.response.close();
          return;
        }

        fail('Unexpected request count: $requestCount');
      });

      await expectLater(
        ChatApiService.sendMessageStream(
          config: _geminiConfig(
            'http://${server.address.address}:${server.port}/v1beta',
          ),
          modelId: 'gemini-3.1-pro-preview',
          messages: const [
            {
              'role': 'user',
              'content':
                  'Search the web for the Kelivo fetch server docs, then summarize them.',
            },
          ],
          tools: const [
            {'google_search': {}},
            {
              'function_declarations': [
                {
                  'name': 'fetch_markdown',
                  'description': 'Fetch a page as markdown',
                  'parameters': {
                    'type': 'object',
                    'properties': {
                      'url': {'type': 'string'},
                    },
                    'required': ['url'],
                  },
                },
              ],
            },
          ],
        ).toList(),
        throwsA(isA<HttpException>()),
      );

      expect(requestCount, 2);
    });

    test(
      'succeeds when the signature is attached to the functionCall chunk',
      () async {
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        addTearDown(() async {
          await server.close(force: true);
        });

        var requestCount = 0;
        server.listen((request) async {
          requestCount++;
          await utf8.decoder.bind(request).join();

          if (requestCount == 1) {
            request.response.statusCode = HttpStatus.ok;
            request.response.headers.contentType = ContentType(
              'text',
              'event-stream',
            );
            request.response.headers.set('Transfer-Encoding', 'chunked');
            request.response.write(
              'data: ${jsonEncode(_streamChunk([
                _functionCallPart(name: 'google_search', args: {'query': 'Kelivo fetch'}, thoughtSignature: 'sig-google-search'),
              ]))}\n\n',
            );
            request.response.write('data: [DONE]');
            await request.response.close();
            return;
          }

          if (requestCount == 2) {
            request.response.statusCode = HttpStatus.ok;
            request.response.headers.contentType = ContentType(
              'text',
              'event-stream',
            );
            request.response.headers.set('Transfer-Encoding', 'chunked');
            request.response.write(
              'data: ${jsonEncode(_streamChunk([_textPart(text: 'ok')], finishReason: 'STOP'))}\n\n',
            );
            request.response.write('data: [DONE]');
            await request.response.close();
            return;
          }

          fail('Unexpected request count: $requestCount');
        });

        final chunks = await ChatApiService.sendMessageStream(
          config: _geminiConfig(
            'http://${server.address.address}:${server.port}/v1beta',
          ),
          modelId: 'gemini-3.1-pro-preview',
          messages: const [
            {
              'role': 'user',
              'content':
                  'Search the web for the Kelivo fetch server docs, then summarize them.',
            },
          ],
          tools: const [
            {'google_search': {}},
            {
              'function_declarations': [
                {
                  'name': 'fetch_markdown',
                  'description': 'Fetch a page as markdown',
                  'parameters': {
                    'type': 'object',
                    'properties': {
                      'url': {'type': 'string'},
                    },
                    'required': ['url'],
                  },
                },
              ],
            },
          ],
        ).toList();

        expect(chunks.last.isDone, isTrue);
      },
    );

    test('preserves parallel function calls without inventing signatures', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() async {
        await server.close(force: true);
      });

      var requestCount = 0;
      server.listen((request) async {
        requestCount++;
        final bodyText = await utf8.decoder.bind(request).join();

        if (requestCount == 1) {
          request.response.statusCode = HttpStatus.ok;
          request.response.headers.contentType = ContentType(
            'text',
            'event-stream',
          );
          request.response.headers.set('Transfer-Encoding', 'chunked');
          request.response.write(
            'data: ${jsonEncode(_streamChunk([
              _functionCallPart(name: 'search_docs', args: {'query': 'Kelivo fetch'}, thoughtSignature: 'sig-search-docs'),
              _functionCallPart(name: 'fetch_markdown', args: {'url': 'https://example.com'}),
            ], finishReason: 'STOP'))}\n\n',
          );
          request.response.write('data: [DONE]');
          await request.response.close();
          return;
        }

        if (requestCount == 2) {
          final body = jsonDecode(bodyText) as Map<String, dynamic>;
          final contents = (body['contents'] as List).cast<Map>();
          final modelParts = (contents[1]['parts'] as List).cast<Map>();
          final functionCalls = modelParts
              .where((p) => p.containsKey('functionCall'))
              .toList();

          expect(functionCalls, hasLength(2));
          expect(_thoughtSignatureOf(functionCalls[0]), 'sig-search-docs');
          expect(_hasThoughtSignature(functionCalls[1]), isFalse);

          request.response.statusCode = HttpStatus.ok;
          request.response.headers.contentType = ContentType(
            'text',
            'event-stream',
          );
          request.response.headers.set('Transfer-Encoding', 'chunked');
          request.response.write(
            'data: ${jsonEncode(_streamChunk([_textPart(text: 'ok')], finishReason: 'STOP'))}\n\n',
          );
          request.response.write('data: [DONE]');
          await request.response.close();
          return;
        }

        fail('Unexpected request count: $requestCount');
      });

      final chunks = await ChatApiService.sendMessageStream(
        config: _geminiConfig(
          'http://${server.address.address}:${server.port}/v1beta',
        ),
        modelId: 'gemini-3.1-pro-preview',
        messages: const [
          {
            'role': 'user',
            'content': 'Look up the docs first, then fetch the page content.',
          },
        ],
        tools: const [
          {
            'function_declarations': [
              {
                'name': 'search_docs',
                'description': 'Search for matching docs',
                'parameters': {
                  'type': 'object',
                  'properties': {
                    'query': {'type': 'string'},
                  },
                  'required': ['query'],
                },
              },
              {
                'name': 'fetch_markdown',
                'description': 'Fetch a page as markdown',
                'parameters': {
                  'type': 'object',
                  'properties': {
                    'url': {'type': 'string'},
                  },
                  'required': ['url'],
                },
              },
            ],
          },
        ],
      ).toList();

      expect(requestCount, 2);
      expect(chunks.last.isDone, isTrue);
    });

    test('keeps a detached signature part instead of moving it', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() async {
        await server.close(force: true);
      });

      var requestCount = 0;
      server.listen((request) async {
        requestCount++;
        final bodyText = await utf8.decoder.bind(request).join();

        if (requestCount == 1) {
          request.response.statusCode = HttpStatus.ok;
          request.response.headers.contentType = ContentType(
            'text',
            'event-stream',
          );
          request.response.headers.set('Transfer-Encoding', 'chunked');
          request.response.write(
            'data: ${jsonEncode(_streamChunk([
              _functionCallPart(name: 'fetch_markdown', args: {'url': 'https://example.com'}, thoughtSignature: 'sig-fetch-markdown'),
            ]))}\n\n',
          );
          request.response.write(
            'data: ${jsonEncode(_streamChunk([_textPart(text: '', thoughtSignature: 'sig-detached')], finishReason: 'STOP'))}\n\n',
          );
          request.response.write('data: [DONE]');
          await request.response.close();
          return;
        }

        if (requestCount == 2) {
          final body = jsonDecode(bodyText) as Map<String, dynamic>;
          final contents = (body['contents'] as List).cast<Map>();
          final modelParts = (contents[1]['parts'] as List).cast<Map>();
          final functionCall = modelParts.firstWhere(
            (p) => p.containsKey('functionCall'),
          );
          final detachedSignature = modelParts.firstWhere(
            (p) => p['text'] == '' && _thoughtSignatureOf(p) == 'sig-detached',
          );

          expect(_thoughtSignatureOf(functionCall), 'sig-fetch-markdown');
          expect(_thoughtSignatureOf(detachedSignature), 'sig-detached');

          request.response.statusCode = HttpStatus.ok;
          request.response.headers.contentType = ContentType(
            'text',
            'event-stream',
          );
          request.response.headers.set('Transfer-Encoding', 'chunked');
          request.response.write(
            'data: ${jsonEncode(_streamChunk([_textPart(text: 'ok')], finishReason: 'STOP'))}\n\n',
          );
          request.response.write('data: [DONE]');
          await request.response.close();
          return;
        }

        fail('Unexpected request count: $requestCount');
      });

      final chunks = await ChatApiService.sendMessageStream(
        config: _geminiConfig(
          'http://${server.address.address}:${server.port}/v1beta',
        ),
        modelId: 'gemini-3.1-pro-preview',
        messages: const [
          {'role': 'user', 'content': 'Fetch the page content.'},
        ],
        tools: const [
          {
            'function_declarations': [
              {
                'name': 'fetch_markdown',
                'description': 'Fetch a page as markdown',
                'parameters': {
                  'type': 'object',
                  'properties': {
                    'url': {'type': 'string'},
                  },
                  'required': ['url'],
                },
              },
            ],
          },
        ],
      ).toList();

      expect(requestCount, 2);
      expect(chunks.last.isDone, isTrue);
    });

    test('preserves unknown non-thought model parts in replay', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() async {
        await server.close(force: true);
      });

      var requestCount = 0;
      server.listen((request) async {
        requestCount++;
        final bodyText = await utf8.decoder.bind(request).join();

        if (requestCount == 1) {
          request.response.statusCode = HttpStatus.ok;
          request.response.headers.contentType = ContentType(
            'text',
            'event-stream',
          );
          request.response.headers.set('Transfer-Encoding', 'chunked');
          request.response.write(
            'data: ${jsonEncode(_streamChunk([
              {
                'futureToolPart': {'id': 'future-tool-1', 'payload': 'preserve me'},
              },
              _functionCallPart(name: 'fetch_markdown', args: {'url': 'https://example.com'}, thoughtSignature: 'sig-fetch-markdown'),
            ], finishReason: 'STOP'))}\n\n',
          );
          request.response.write('data: [DONE]');
          await request.response.close();
          return;
        }

        if (requestCount == 2) {
          final body = jsonDecode(bodyText) as Map<String, dynamic>;
          final contents = (body['contents'] as List).cast<Map>();
          final modelParts = (contents[1]['parts'] as List).cast<Map>();
          final futurePartIndex = modelParts.indexWhere(
            (p) => p.containsKey('futureToolPart'),
          );
          final functionCallIndex = modelParts.indexWhere(
            (p) => p.containsKey('functionCall'),
          );

          expect(futurePartIndex, isNonNegative);
          expect(functionCallIndex, isNonNegative);
          expect(futurePartIndex, lessThan(functionCallIndex));

          request.response.statusCode = HttpStatus.ok;
          request.response.headers.contentType = ContentType(
            'text',
            'event-stream',
          );
          request.response.headers.set('Transfer-Encoding', 'chunked');
          request.response.write(
            'data: ${jsonEncode(_streamChunk([_textPart(text: 'ok')], finishReason: 'STOP'))}\n\n',
          );
          request.response.write('data: [DONE]');
          await request.response.close();
          return;
        }

        fail('Unexpected request count: $requestCount');
      });

      final chunks = await ChatApiService.sendMessageStream(
        config: _geminiConfig(
          'http://${server.address.address}:${server.port}/v1beta',
        ),
        modelId: 'gemini-3.1-pro-preview',
        messages: const [
          {
            'role': 'user',
            'content': 'Fetch the page content after processing the tool part.',
          },
        ],
        tools: const [
          {
            'function_declarations': [
              {
                'name': 'fetch_markdown',
                'description': 'Fetch a page as markdown',
                'parameters': {
                  'type': 'object',
                  'properties': {
                    'url': {'type': 'string'},
                  },
                  'required': ['url'],
                },
              },
            ],
          },
        ],
      ).toList();

      expect(requestCount, 2);
      expect(chunks.last.isDone, isTrue);
    });

    test('preserves signed toolCall and functionCall parts in order', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() async {
        await server.close(force: true);
      });

      var requestCount = 0;
      server.listen((request) async {
        requestCount++;
        final bodyText = await utf8.decoder.bind(request).join();

        if (requestCount == 1) {
          request.response.statusCode = HttpStatus.ok;
          request.response.headers.contentType = ContentType(
            'text',
            'event-stream',
          );
          request.response.headers.set('Transfer-Encoding', 'chunked');
          request.response.write(
            'data: ${jsonEncode(_streamChunk([
              _toolCallPart(toolType: 'GOOGLE_SEARCH_WEB', args: {
                'queries': ['"Vagal blood volume receptors"'],
              }, id: 'wne1uqtz', thoughtSignature: 'sig-google-search'),
              _functionCallPart(name: 'fetch_markdown', args: {'url': 'https://example.com'}, thoughtSignature: 'sig-fetch-markdown'),
            ]))}\n\n',
          );
          request.response.write('data: [DONE]');
          await request.response.close();
          return;
        }

        if (requestCount == 2) {
          final body = jsonDecode(bodyText) as Map<String, dynamic>;
          final contents = (body['contents'] as List).cast<Map>();
          final modelParts = (contents[1]['parts'] as List).cast<Map>();
          final toolCallIndex = modelParts.indexWhere(
            (p) => p.containsKey('toolCall'),
          );
          final functionCallIndex = modelParts.indexWhere(
            (p) => p.containsKey('functionCall'),
          );

          expect(toolCallIndex, isNonNegative);
          expect(functionCallIndex, isNonNegative);
          expect(toolCallIndex, lessThan(functionCallIndex));
          expect(_hasThoughtSignature(modelParts[toolCallIndex]), isTrue);
          expect(_hasThoughtSignature(modelParts[functionCallIndex]), isTrue);

          request.response.statusCode = HttpStatus.ok;
          request.response.headers.contentType = ContentType(
            'text',
            'event-stream',
          );
          request.response.headers.set('Transfer-Encoding', 'chunked');
          request.response.write(
            'data: ${jsonEncode(_streamChunk([_textPart(text: 'ok')], finishReason: 'STOP'))}\n\n',
          );
          request.response.write('data: [DONE]');
          await request.response.close();
          return;
        }

        fail('Unexpected request count: $requestCount');
      });

      final chunks = await ChatApiService.sendMessageStream(
        config: _geminiConfig(
          'http://${server.address.address}:${server.port}/v1beta',
        ),
        modelId: 'gemini-3.1-pro-preview',
        messages: const [
          {
            'role': 'user',
            'content':
                'Search the web for the latest paper, then fetch it and summarize it.',
          },
        ],
        tools: const [
          {'google_search': {}},
          {
            'function_declarations': [
              {
                'name': 'fetch_markdown',
                'description': 'Fetch a page as markdown',
                'parameters': {
                  'type': 'object',
                  'properties': {
                    'url': {'type': 'string'},
                  },
                  'required': ['url'],
                },
              },
            ],
          },
        ],
      ).toList();

      expect(requestCount, 2);
      expect(chunks.last.isDone, isTrue);
    });
  });
}
