import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/api/chat_api_service.dart';
import 'support/collect_generation.dart';
import 'support/legacy_reasoning.dart';

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

Future<HttpServer> _startGeminiServer(
  void Function(Map<String, dynamic> body) onBody,
) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  server.listen((request) async {
    final bodyText = await utf8.decoder.bind(request).join();
    onBody(jsonDecode(bodyText) as Map<String, dynamic>);

    request.response.statusCode = HttpStatus.ok;
    if (request.uri.path.endsWith(':streamGenerateContent')) {
      request.response.headers.contentType = ContentType(
        'text',
        'event-stream',
      );
      request.response.write(
        'data: ${jsonEncode({
          'candidates': [
            {
              'content': {
                'parts': [
                  {'text': 'ok'},
                ],
              },
              'finishReason': 'STOP',
            },
          ],
          'usageMetadata': {'promptTokenCount': 1, 'candidatesTokenCount': 1, 'totalTokenCount': 2},
        })}\n\n',
      );
      request.response.write('data: [DONE]');
    } else {
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
    }
    await request.response.close();
  });
  return server;
}

Map<String, dynamic>? _thinkingConfig(Map<String, dynamic> body) {
  final generationConfig = body['generationConfig'];
  if (generationConfig is! Map) return null;
  final thinkingConfig = generationConfig['thinkingConfig'];
  if (thinkingConfig is! Map) return null;
  return thinkingConfig.cast<String, dynamic>();
}

Future<Map<String, dynamic>> _capture({
  required String modelId,
  int? thinkingBudget,
  bool stream = false,
}) async {
  late Map<String, dynamic> body;
  final server = await _startGeminiServer((b) => body = b);
  addTearDown(() async {
    await server.close(force: true);
  });

  final chunks = await ChatApiService.sendMessageStream(
    config: _geminiConfig(
      'http://${server.address.address}:${server.port}/v1beta',
    ),
    modelId: modelId,
    messages: const [
      {'role': 'user', 'content': 'hello'},
    ],
    reasoning: legacyBudget(thinkingBudget),
    stream: stream,
  ).toList();

  expect(chunks.isGenerationDone, isTrue, reason: modelId);
  return body;
}

void main() {
  group('Gemini / Gemma request thinking via send path', () {
    for (final c in _cases) {
      test(c.name, () async {
        final body = await _capture(
          modelId: c.modelId,
          thinkingBudget: c.thinkingBudget,
          stream: c.stream,
        );
        c.verify(body);
      });
    }
  });
}

class _GeminiCase {
  const _GeminiCase({
    required this.name,
    required this.modelId,
    this.thinkingBudget,
    this.stream = false,
    required this.verify,
  });

  final String name;
  final String modelId;
  final int? thinkingBudget;
  final bool stream;
  final void Function(Map<String, dynamic> body) verify;
}

final _cases = <_GeminiCase>[
  _GeminiCase(
    name: 'Gemma 4 medium budget clamps to high',
    modelId: 'google/gemma-4-E4B-it',
    thinkingBudget: 16000,
    verify: (body) {
      expect(_thinkingConfig(body), {
        'includeThoughts': true,
        'thinkingLevel': 'HIGH',
      });
      expect(_thinkingConfig(body)!.containsKey('thinkingBudget'), isFalse);
    },
  ),
  _GeminiCase(
    name: 'Gemma 4 low budget clamps to minimal',
    modelId: 'google/gemma-4-31B-it',
    thinkingBudget: 1024,
    stream: true,
    verify: (body) {
      expect(_thinkingConfig(body), {
        'includeThoughts': true,
        'thinkingLevel': 'MINIMAL',
      });
    },
  ),
  _GeminiCase(
    name: 'Gemma 4 off hides thoughts at the lowest level',
    modelId: 'gemma-4-E2B-it',
    thinkingBudget: 0,
    stream: true,
    verify: (body) {
      expect(_thinkingConfig(body), {
        'includeThoughts': false,
        'thinkingLevel': 'MINIMAL',
      });
    },
  ),
  _GeminiCase(
    name: 'Gemini 3.6 Flash auto only writes includeThoughts and 64K output',
    modelId: 'gemini-3.6-flash',
    verify: (body) {
      expect(_thinkingConfig(body), {'includeThoughts': true});
      expect((body['generationConfig'] as Map)['maxOutputTokens'], 65536);
    },
  ),
  _GeminiCase(
    name: 'Gemini 3.7 Flash auto keeps 64K output',
    modelId: 'gemini-3.7-flash',
    verify: (body) {
      expect(_thinkingConfig(body), {'includeThoughts': true});
      expect((body['generationConfig'] as Map)['maxOutputTokens'], 65536);
    },
  ),
  _GeminiCase(
    name: 'Gemini 3.5 Flash-Lite auto only writes includeThoughts',
    modelId: 'gemini-3.5-flash-lite',
    verify: (body) {
      expect(_thinkingConfig(body), {'includeThoughts': true});
      expect((body['generationConfig'] as Map)['maxOutputTokens'], 65536);
    },
  ),
  _GeminiCase(
    name: 'Gemini 3.1 Pro maps a medium budget to MEDIUM',
    modelId: 'gemini-3.1-pro-preview',
    thinkingBudget: 16000,
    verify: (body) {
      expect(_thinkingConfig(body), {
        'includeThoughts': true,
        'thinkingLevel': 'MEDIUM',
      });
    },
  ),
  _GeminiCase(
    name: 'Gemini 3.8 Flash off floors at LOW',
    modelId: 'gemini-3.8-flash',
    thinkingBudget: 0,
    verify: (body) {
      expect(_thinkingConfig(body), {
        'includeThoughts': false,
        'thinkingLevel': 'LOW',
      });
    },
  ),
  _GeminiCase(
    name: 'Gemini 3.7 Flash off floors at LOW',
    modelId: 'gemini-3.7-flash',
    thinkingBudget: 0,
    verify: (body) {
      expect(_thinkingConfig(body), {
        'includeThoughts': false,
        'thinkingLevel': 'LOW',
      });
    },
  ),
  _GeminiCase(
    name: 'Gemini 3.6 Flash off floors at MINIMAL',
    modelId: 'gemini-3.6-flash',
    thinkingBudget: 0,
    verify: (body) {
      expect(_thinkingConfig(body), {
        'includeThoughts': false,
        'thinkingLevel': 'MINIMAL',
      });
    },
  ),
  _GeminiCase(
    name: 'Flash Image high budget maps to HIGH',
    modelId: 'gemini-3.1-flash-image',
    thinkingBudget: 16000,
    verify: (body) {
      expect(_thinkingConfig(body), {
        'includeThoughts': true,
        'thinkingLevel': 'HIGH',
      });
    },
  ),
  _GeminiCase(
    name: 'Flash-Lite Image low budget maps to MINIMAL',
    modelId: 'gemini-3.1-flash-lite-image',
    thinkingBudget: 1024,
    verify: (body) {
      expect(_thinkingConfig(body), {
        'includeThoughts': true,
        'thinkingLevel': 'MINIMAL',
      });
    },
  ),
  _GeminiCase(
    name: 'Flash Image auto only writes includeThoughts',
    modelId: 'gemini-3.1-flash-image-preview',
    verify: (body) {
      expect(_thinkingConfig(body), {'includeThoughts': true});
      expect(
        (body['generationConfig'] as Map).containsKey('maxOutputTokens'),
        isFalse,
      );
    },
  ),
  _GeminiCase(
    name: 'Flash Image off hides thoughts at MINIMAL',
    modelId: 'gemini-3.1-flash-image',
    thinkingBudget: 0,
    verify: (body) {
      expect(_thinkingConfig(body), {
        'includeThoughts': false,
        'thinkingLevel': 'MINIMAL',
      });
    },
  ),
  _GeminiCase(
    name: 'Gemini 3 Pro Image has no reasoning dialect',
    modelId: 'gemini-3-pro-image-preview',
    thinkingBudget: 16000,
    verify: (body) {
      expect(_thinkingConfig(body), isNull);
    },
  ),
  _GeminiCase(
    name: 'TTS ids have no thinkingConfig',
    modelId: 'gemini-3.1-flash-tts-preview',
    thinkingBudget: 16000,
    verify: (body) {
      expect(_thinkingConfig(body), isNull);
      expect(
        (body['generationConfig'] as Map?)?.containsKey('maxOutputTokens'),
        isNot(isTrue),
      );
    },
  ),
  _GeminiCase(
    name: 'Gemini 2.5 Flash auto only writes includeThoughts',
    modelId: 'gemini-2.5-flash',
    verify: (body) {
      expect(_thinkingConfig(body), {'includeThoughts': true});
    },
  ),
  _GeminiCase(
    name: 'Gemini 2.5 Flash writes the budget verbatim',
    modelId: 'gemini-2.5-flash',
    thinkingBudget: 16000,
    verify: (body) {
      expect(_thinkingConfig(body), {
        'includeThoughts': true,
        'thinkingBudget': 16000,
      });
    },
  ),
  _GeminiCase(
    name: 'Gemini 2.5 Pro cannot disable thinking',
    modelId: 'gemini-2.5-pro',
    thinkingBudget: 0,
    verify: (body) {
      expect(_thinkingConfig(body)!['includeThoughts'], isFalse);
      expect(_thinkingConfig(body)!.containsKey('thinkingLevel'), isFalse);
    },
  ),
];
