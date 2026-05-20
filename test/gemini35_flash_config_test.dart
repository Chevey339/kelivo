import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/providers/model_provider.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/api/chat_api_service.dart';

ProviderConfig _geminiConfig(String baseUrl) {
  return ProviderConfig(
    id: 'Gemini35Test',
    enabled: true,
    name: 'Gemini35Test',
    apiKey: 'test-key',
    baseUrl: baseUrl,
    providerType: ProviderKind.google,
  );
}

Map<String, dynamic>? _generationConfig(Map<String, dynamic> body) {
  final generationConfig = body['generationConfig'];
  if (generationConfig is! Map) return null;
  return generationConfig.cast<String, dynamic>();
}

Map<String, dynamic>? _thinkingConfig(Map<String, dynamic> body) {
  final generationConfig = _generationConfig(body);
  final thinkingConfig = generationConfig?['thinkingConfig'];
  if (thinkingConfig is! Map) return null;
  return thinkingConfig.cast<String, dynamic>();
}

Future<HttpServer> _startJsonGeminiServer(
  void Function(Map<String, dynamic> body) onBody,
) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  server.listen((request) async {
    final bodyText = await utf8.decoder.bind(request).join();
    onBody(jsonDecode(bodyText) as Map<String, dynamic>);

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
  return server;
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

void main() {
  group('Gemini 3.5 Flash model metadata', () {
    test('infers Google-supported model abilities', () {
      final info = ModelRegistry.infer(
        ModelInfo(id: 'gemini-3.5-flash', displayName: 'Gemini 3.5 Flash'),
      );

      expect(info.input, contains(Modality.image));
      expect(info.output, [Modality.text]);
      expect(
        info.abilities,
        containsAll([ModelAbility.tool, ModelAbility.reasoning]),
      );
    });

    test('Google default provider exposes Gemini 3.5 Flash', () {
      final config = ProviderConfig.defaultsFor('Gemini');

      expect(config.models, contains('gemini-3.5-flash'));
      final override = config.modelOverrides['gemini-3.5-flash'] as Map;
      expect(override['input'], ['text', 'image']);
      expect(override['output'], ['text']);
      expect(override['abilities'], containsAll(['tool', 'reasoning']));
    });
  });

  group('Gemini 3.5 Flash generation config', () {
    test(
      'defaults to medium thinking level and strips sampling params',
      () async {
        late Map<String, dynamic> capturedBody;
        final server = await _startJsonGeminiServer((body) {
          capturedBody = body;
        });
        addTearDown(() async {
          await server.close(force: true);
        });

        final chunks = await ChatApiService.sendMessageStream(
          config: _geminiConfig(
            'http://${server.address.address}:${server.port}/v1beta',
          ),
          modelId: 'gemini-3.5-flash',
          messages: const [
            {'role': 'user', 'content': 'hello'},
          ],
          temperature: 0.7,
          topP: 0.8,
          stream: false,
        ).toList();

        expect(chunks.last.isDone, isTrue);
        expect(capturedBody.containsKey('temperature'), isFalse);
        expect(capturedBody.containsKey('topP'), isFalse);
        expect(
          _generationConfig(capturedBody)!.containsKey('temperature'),
          isFalse,
        );
        expect(_generationConfig(capturedBody)!.containsKey('topP'), isFalse);
        expect(_generationConfig(capturedBody)!['maxOutputTokens'], 65536);
        expect(_thinkingConfig(capturedBody), {
          'includeThoughts': true,
          'thinkingLevel': 'medium',
        });
        expect(
          _thinkingConfig(capturedBody)!.containsKey('thinkingBudget'),
          isFalse,
        );
      },
    );

    test('maps legacy budget choices to Gemini 3.5 thinking levels', () async {
      final capturedBodies = <Map<String, dynamic>>[];
      final server = await _startJsonGeminiServer(capturedBodies.add);
      addTearDown(() async {
        await server.close(force: true);
      });

      final baseUrl = 'http://${server.address.address}:${server.port}/v1beta';
      for (final budget in const [0, 1024, 16000, 32000]) {
        await ChatApiService.sendMessageStream(
          config: _geminiConfig(baseUrl),
          modelId: 'gemini-3.5-flash',
          messages: const [
            {'role': 'user', 'content': 'hello'},
          ],
          thinkingBudget: budget,
          stream: false,
        ).toList();
      }

      expect(capturedBodies.map(_thinkingConfig).toList(), [
        {'includeThoughts': true, 'thinkingLevel': 'minimal'},
        {'includeThoughts': true, 'thinkingLevel': 'low'},
        {'includeThoughts': true, 'thinkingLevel': 'medium'},
        {'includeThoughts': true, 'thinkingLevel': 'high'},
      ]);
      for (final body in capturedBodies) {
        expect(_thinkingConfig(body)!.containsKey('thinkingBudget'), isFalse);
      }
    });

    test(
      'Gemini 2.5 keeps numeric budget and sampling compatibility',
      () async {
        late Map<String, dynamic> capturedBody;
        final server = await _startJsonGeminiServer((body) {
          capturedBody = body;
        });
        addTearDown(() async {
          await server.close(force: true);
        });

        await ChatApiService.sendMessageStream(
          config: _geminiConfig(
            'http://${server.address.address}:${server.port}/v1beta',
          ),
          modelId: 'gemini-2.5-pro',
          messages: const [
            {'role': 'user', 'content': 'hello'},
          ],
          thinkingBudget: 16000,
          temperature: 0.7,
          topP: 0.8,
          stream: false,
        ).toList();

        expect(capturedBody['temperature'], 0.7);
        expect(capturedBody['topP'], 0.8);
        expect(_thinkingConfig(capturedBody), {
          'includeThoughts': true,
          'thinkingBudget': 16000,
        });
      },
    );
  });

  group('Gemini 3.5 Flash function response ids', () {
    test(
      'streaming tool continuation nests the API call id in functionResponse',
      () async {
        final requestBodies = <Map<String, dynamic>>[];
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        addTearDown(() async {
          await server.close(force: true);
        });

        var requestCount = 0;
        server.listen((request) async {
          requestCount++;
          requestBodies.add(
            jsonDecode(await utf8.decoder.bind(request).join())
                as Map<String, dynamic>,
          );
          request.response.statusCode = HttpStatus.ok;
          request.response.headers.contentType = ContentType(
            'text',
            'event-stream',
          );
          request.response.headers.set('Transfer-Encoding', 'chunked');

          if (requestCount == 1) {
            request.response.write(
              'data: ${jsonEncode(_streamChunk([
                {
                  'id': 'call_abc',
                  'functionCall': {
                    'name': 'lookup',
                    'args': {'query': 'Kelivo'},
                  },
                  'thoughtSignature': 'sig-call',
                },
              ], finishReason: 'STOP'))}\n\n',
            );
          } else {
            request.response.write(
              'data: ${jsonEncode(_streamChunk([
                {'text': 'done'},
              ], finishReason: 'STOP'))}\n\n',
            );
          }
          request.response.write('data: [DONE]');
          await request.response.close();
        });

        final chunks = await ChatApiService.sendMessageStream(
          config: _geminiConfig(
            'http://${server.address.address}:${server.port}/v1beta',
          ),
          modelId: 'gemini-3.5-flash',
          messages: const [
            {'role': 'user', 'content': 'hello'},
          ],
          onToolCall: (name, args, {toolCallId}) async => '{"result":"ok"}',
        ).toList();

        expect(chunks.last.isDone, isTrue);
        expect(requestBodies, hasLength(2));
        final contents = (requestBodies[1]['contents'] as List).cast<Map>();
        final responsePart = ((contents[2]['parts'] as List).single as Map)
            .cast<String, dynamic>();
        expect(responsePart.containsKey('id'), isFalse);
        expect(responsePart['functionResponse']['id'], 'call_abc');
        expect(responsePart['functionResponse']['name'], 'lookup');
      },
    );

    test(
      'non-stream tool continuation nests the API call id in functionResponse',
      () async {
        final requestBodies = <Map<String, dynamic>>[];
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        addTearDown(() async {
          await server.close(force: true);
        });

        var requestCount = 0;
        server.listen((request) async {
          requestCount++;
          requestBodies.add(
            jsonDecode(await utf8.decoder.bind(request).join())
                as Map<String, dynamic>,
          );
          request.response.statusCode = HttpStatus.ok;
          request.response.headers.contentType = ContentType.json;

          if (requestCount == 1) {
            request.response.write(
              jsonEncode({
                'candidates': [
                  {
                    'content': {
                      'parts': [
                        {
                          'id': 'call_xyz',
                          'functionCall': {
                            'name': 'lookup',
                            'args': {'query': 'Kelivo'},
                          },
                          'thoughtSignature': 'sig-call',
                        },
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
          } else {
            request.response.write(
              jsonEncode({
                'candidates': [
                  {
                    'content': {
                      'parts': [
                        {'text': 'done'},
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
          }
          await request.response.close();
        });

        final chunks = await ChatApiService.sendMessageStream(
          config: _geminiConfig(
            'http://${server.address.address}:${server.port}/v1beta',
          ),
          modelId: 'gemini-3.5-flash',
          messages: const [
            {'role': 'user', 'content': 'hello'},
          ],
          onToolCall: (name, args, {toolCallId}) async => '{"result":"ok"}',
          stream: false,
        ).toList();

        expect(chunks.last.isDone, isTrue);
        expect(requestBodies, hasLength(2));
        final contents = (requestBodies[1]['contents'] as List).cast<Map>();
        final responsePart = ((contents[2]['parts'] as List).single as Map)
            .cast<String, dynamic>();
        expect(responsePart.containsKey('id'), isFalse);
        expect(responsePart['functionResponse']['id'], 'call_xyz');
        expect(responsePart['functionResponse']['name'], 'lookup');
      },
    );
  });
}
