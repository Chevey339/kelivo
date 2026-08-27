import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/api/chat_api_service.dart';
import 'package:Kelivo/core/services/api/providers/google_gemini.dart';
import 'package:Kelivo/core/services/api/stream/stream_chunk.dart';
import 'support/collect_generation.dart';

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

String _streamChunk(List<Map<String, dynamic>> parts) {
  return 'data: ${jsonEncode({
    'candidates': [
      {
        'content': {'parts': parts},
        'finishReason': 'STOP',
      },
    ],
    'usageMetadata': {'promptTokenCount': 1, 'candidatesTokenCount': 1, 'totalTokenCount': 2},
  })}\n\n';
}

const _legacyComment =
    '\n<!-- gemini_thought_signatures:{"text":{"k":"thoughtSignature","v":"sig-legacy"}} -->';

void main() {
  group('Gemini thought signature payload', () {
    test('encodes as bare JSON', () {
      final payload = encodeGeminiThoughtSignature(
        textKey: 'thoughtSignature',
        textValue: 'sig-text',
        imageSigs: const [
          {'k': 'thoughtSignature', 'v': 'sig-img'},
        ],
      );
      expect(jsonDecode(payload), {
        'text': {'k': 'thoughtSignature', 'v': 'sig-text'},
        'images': [
          {'k': 'thoughtSignature', 'v': 'sig-img'},
        ],
      });
      expect(encodeGeminiThoughtSignature(), '');
    });

    test('a legacy comment re-encodes as bare JSON', () {
      final legacy = extractGeminiThoughtMeta('Answer.$_legacyComment');
      final migrated = encodeGeminiThoughtSignature(
        textKey: legacy.textKey,
        textValue: legacy.textValue,
        imageSigs: legacy.images,
      );
      expect(legacy.cleanedText, 'Answer.');
      expect(migrated, startsWith('{'));
      expect(decodeGeminiThoughtSignature(migrated)?.textValue, 'sig-legacy');
    });

    test('collects the signature from a trailing empty part', () {
      final payload = collectGeminiThoughtSignatureFromParts([
        {
          'text': 'Thinking',
          'thought': true,
          'thoughtSignature': 'sig-thought',
        },
        {'text': 'Answer.'},
        {'text': '', 'thoughtSignature': 'sig-trailing'},
      ]);
      expect(jsonDecode(payload), {
        'text': {'k': 'thoughtSignature', 'v': 'sig-trailing'},
      });
    });

    test('decodes bare JSON and the legacy comment alike', () {
      final fresh = decodeGeminiThoughtSignature(
        '{"text":{"k":"thoughtSignature","v":"sig-new"}}',
      );
      expect(fresh?.textValue, 'sig-new');

      final legacy = decodeGeminiThoughtSignature(_legacyComment);
      expect(legacy?.textKey, 'thoughtSignature');
      expect(legacy?.textValue, 'sig-legacy');

      expect(decodeGeminiThoughtSignature(''), isNull);
      expect(decodeGeminiThoughtSignature('not a signature'), isNull);
      expect(decodeGeminiThoughtSignature('{}'), isNull);
    });
  });

  group('Gemini thought signature artifact', () {
    late HttpServer server;
    late List<Map<String, dynamic>> requestBodies;
    late List<Map<String, dynamic>> responseParts;

    setUp(() async {
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      requestBodies = [];
      responseParts = [
        {'text': 'Answer.', 'thoughtSignature': 'sig-answer'},
      ];
      server.listen((request) async {
        final body = await utf8.decoder.bind(request).join();
        requestBodies.add(jsonDecode(body) as Map<String, dynamic>);
        request.response.statusCode = HttpStatus.ok;
        request.response.headers.contentType = ContentType(
          'text',
          'event-stream',
        );
        request.response.write(_streamChunk(responseParts));
        request.response.write('data: [DONE]');
        await request.response.close();
      });
    });

    tearDown(() => server.close(force: true));

    Future<List<StreamChunk>> send(List<Map<String, dynamic>> messages) {
      return ChatApiService.sendMessageStream(
        config: _geminiConfig(
          'http://${server.address.address}:${server.port}/v1beta',
        ),
        modelId: 'gemini-3.1-pro-preview',
        messages: messages,
      ).toList();
    }

    List<Map> modelParts(Map<String, dynamic> body) {
      final contents = (body['contents'] as List).cast<Map>();
      return (contents[1]['parts'] as List).cast<Map>();
    }

    test('leaves the stream as a ProviderArtifact, not as text', () async {
      final chunks = await send(const [
        {'role': 'user', 'content': 'Hello'},
      ]);

      expect(chunks.isGenerationDone, isTrue);
      expect(chunks.joinedContent, 'Answer.');
      final artifact = chunks.whereType<ProviderArtifact>().single;
      expect(artifact.kind, geminiThoughtSignatureArtifactKind);
      expect(jsonDecode(artifact.payload), {
        'text': {'k': 'thoughtSignature', 'v': 'sig-answer'},
      });
    });

    test(
      'keeps the signature Gemini 3 hangs on a trailing empty part',
      () async {
        responseParts = [
          {
            'text': 'Thinking',
            'thought': true,
            'thoughtSignature': 'sig-thought',
          },
          {'text': 'Answer.'},
          {'text': '', 'thoughtSignature': 'sig-trailing'},
        ];

        final chunks = await send(const [
          {'role': 'user', 'content': 'Hello'},
        ]);

        expect(chunks.joinedContent, 'Answer.');
        final artifact = chunks.whereType<ProviderArtifact>().single;
        expect(jsonDecode(artifact.payload), {
          'text': {'k': 'thoughtSignature', 'v': 'sig-trailing'},
        });
      },
    );

    test('replays a stored signature from the internal key', () async {
      await send([
        {'role': 'user', 'content': 'Hello'},
        {
          'role': 'assistant',
          'content': 'Earlier answer.',
          multimodalInternalGeminiThoughtSignatureKey:
              encodeGeminiThoughtSignature(
                textKey: 'thoughtSignature',
                textValue: 'sig-stored',
              ),
        },
        {'role': 'user', 'content': 'Go on'},
      ]);

      final body = requestBodies.single;
      final model = modelParts(body).single;
      expect(model['text'], 'Earlier answer.');
      expect(model['thoughtSignature'], 'sig-stored');
      expect(
        jsonEncode(body),
        isNot(contains(multimodalInternalGeminiThoughtSignatureKey)),
      );
    });

    test('still reads a legacy comment left in the message text', () async {
      await send(const [
        {'role': 'user', 'content': 'Hello'},
        {'role': 'assistant', 'content': 'Earlier answer.$_legacyComment'},
        {'role': 'user', 'content': 'Go on'},
      ]);

      final model = modelParts(requestBodies.single).single;
      expect(model['text'], 'Earlier answer.');
      expect(model['thoughtSignature'], 'sig-legacy');
    });
  });
}
