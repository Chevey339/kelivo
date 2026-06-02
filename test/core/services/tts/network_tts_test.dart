import 'dart:convert';
import 'dart:io';

import 'package:Kelivo/core/services/tts/network_tts.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TtsServiceOptions', () {
    test('deserializes RikkaHub-aligned provider defaults', () {
      final qwen = TtsServiceOptions.fromJson({
        'kind': 'qwen',
        'enabled': true,
      });
      final groq = TtsServiceOptions.fromJson({
        'kind': 'groq',
        'enabled': true,
      });
      final xai = TtsServiceOptions.fromJson({'kind': 'xai', 'enabled': true});
      final minimax = TtsServiceOptions.fromJson({
        'kind': 'minimax',
        'enabled': true,
      });

      expect(qwen, isA<QwenTtsOptions>());
      expect(
        (qwen as QwenTtsOptions).baseUrl,
        'https://dashscope.aliyuncs.com/api/v1',
      );
      expect(qwen.model, 'qwen3-tts-flash');
      expect(qwen.voice, 'Cherry');
      expect(qwen.languageType, 'Auto');

      expect(groq, isA<GroqTtsOptions>());
      expect(
        (groq as GroqTtsOptions).baseUrl,
        'https://api.groq.com/openai/v1',
      );
      expect(groq.model, 'canopylabs/orpheus-v1-english');
      expect(groq.voice, 'austin');

      expect(xai, isA<XaiTtsOptions>());
      expect((xai as XaiTtsOptions).baseUrl, 'https://api.x.ai/v1');
      expect(xai.voiceId, 'eve');
      expect(xai.language, 'auto');

      expect(minimax, isA<MiniMaxTtsOptions>());
      expect((minimax as MiniMaxTtsOptions).model, 'speech-2.6-turbo');
    });
  });

  group('NetworkTtsService', () {
    test('synthesizes Qwen SSE PCM response as wav', () async {
      late HttpRequest captured;
      late Map<String, dynamic> requestBody;
      final pcm = <int>[1, 2, 3, 4];
      final audio = base64Encode(pcm);
      final server = await _bindServer((request) async {
        captured = request;
        requestBody =
            jsonDecode(await utf8.decoder.bind(request).join())
                as Map<String, dynamic>;
        request.response.statusCode = HttpStatus.ok;
        request.response.headers.contentType = ContentType(
          'text',
          'event-stream',
        );
        request.response.write(
          'data: ${jsonEncode({
            'output': {
              'audio': {'data': audio},
              'finish_reason': 'stop',
            },
          })}\n\n',
        );
        await request.response.close();
      });

      addTearDown(() async => server.close(force: true));

      final result = await NetworkTtsService.synthesize(
        options: QwenTtsOptions(
          enabled: true,
          name: 'Qwen',
          apiKey: 'qwen-key',
          baseUrl: _baseUrl(server),
          model: 'qwen3-tts-flash',
          voice: 'Cherry',
          languageType: 'Chinese',
        ),
        text: '你好',
      );

      expect(
        captured.uri.path,
        '/api/v1/services/aigc/multimodal-generation/generation',
      );
      expect(
        captured.headers.value(HttpHeaders.authorizationHeader),
        'Bearer qwen-key',
      );
      expect(captured.headers.value('X-DashScope-SSE'), 'enable');
      expect(requestBody['model'], 'qwen3-tts-flash');
      expect(requestBody['input'], {
        'text': '你好',
        'voice': 'Cherry',
        'language_type': 'Chinese',
      });
      expect(result.mime, 'audio/wav');
      expect(result.sampleRate, 24000);
      expect(utf8.decode(result.bytes.take(4).toList()), 'RIFF');
    });

    test('synthesizes Groq audio speech response as wav', () async {
      late HttpRequest captured;
      late Map<String, dynamic> requestBody;
      final audioBytes = <int>[9, 8, 7];
      final server = await _bindServer((request) async {
        captured = request;
        requestBody =
            jsonDecode(await utf8.decoder.bind(request).join())
                as Map<String, dynamic>;
        request.response.statusCode = HttpStatus.ok;
        request.response.add(audioBytes);
        await request.response.close();
      });

      addTearDown(() async => server.close(force: true));

      final result = await NetworkTtsService.synthesize(
        options: GroqTtsOptions(
          enabled: true,
          name: 'Groq',
          apiKey: 'groq-key',
          baseUrl: _baseUrl(server),
          model: 'canopylabs/orpheus-v1-english',
          voice: 'austin',
        ),
        text: 'hello',
      );

      expect(captured.uri.path, '/api/v1/audio/speech');
      expect(
        captured.headers.value(HttpHeaders.authorizationHeader),
        'Bearer groq-key',
      );
      expect(requestBody['model'], 'canopylabs/orpheus-v1-english');
      expect(requestBody['input'], 'hello');
      expect(requestBody['voice'], 'austin');
      expect(requestBody['response_format'], 'wav');
      expect(result.bytes, audioBytes);
      expect(result.mime, 'audio/wav');
    });

    test('synthesizes xAI tts response as mp3', () async {
      late HttpRequest captured;
      late Map<String, dynamic> requestBody;
      final audioBytes = <int>[6, 5, 4];
      final server = await _bindServer((request) async {
        captured = request;
        requestBody =
            jsonDecode(await utf8.decoder.bind(request).join())
                as Map<String, dynamic>;
        request.response.statusCode = HttpStatus.ok;
        request.response.add(audioBytes);
        await request.response.close();
      });

      addTearDown(() async => server.close(force: true));

      final result = await NetworkTtsService.synthesize(
        options: XaiTtsOptions(
          enabled: true,
          name: 'xAI',
          apiKey: 'xai-key',
          baseUrl: _baseUrl(server),
          voiceId: 'eve',
          language: 'zh',
        ),
        text: 'hello',
      );

      expect(captured.uri.path, '/api/v1/tts');
      expect(
        captured.headers.value(HttpHeaders.authorizationHeader),
        'Bearer xai-key',
      );
      expect(requestBody, {
        'text': 'hello',
        'voice_id': 'eve',
        'language': 'zh',
      });
      expect(result.bytes, audioBytes);
      expect(result.mime, 'audio/mpeg');
    });

    test('synthesizes ElevenLabs response with host-only base url', () async {
      late HttpRequest captured;
      late Map<String, dynamic> requestBody;
      final audioBytes = <int>[1, 3, 5];
      final server = await _bindServer((request) async {
        captured = request;
        requestBody =
            jsonDecode(await utf8.decoder.bind(request).join())
                as Map<String, dynamic>;
        request.response.statusCode = HttpStatus.ok;
        request.response.add(audioBytes);
        await request.response.close();
      });

      addTearDown(() async => server.close(force: true));

      final result = await NetworkTtsService.synthesize(
        options: ElevenLabsTtsOptions(
          enabled: true,
          name: 'ElevenLabs',
          apiKey: 'eleven-key',
          baseUrl: _hostOnlyBaseUrl(server),
          modelId: 'eleven_multilingual_v2',
          voiceId: 'pNInz6obpgDQGcFmaJgB',
        ),
        text: 'hello',
      );

      expect(captured.uri.path, '/v1/text-to-speech/pNInz6obpgDQGcFmaJgB');
      expect(captured.uri.queryParameters['output_format'], 'mp3_44100_128');
      expect(captured.headers.value('xi-api-key'), 'eleven-key');
      expect(requestBody, {
        'text': 'hello',
        'model_id': 'eleven_multilingual_v2',
      });
      expect(result.bytes, audioBytes);
      expect(result.mime, 'audio/mpeg');
    });

    test('synthesizes ElevenLabs response with v1 base url', () async {
      late HttpRequest captured;
      final audioBytes = <int>[2, 4, 6];
      final server = await _bindServer((request) async {
        captured = request;
        await utf8.decoder.bind(request).join();
        request.response.statusCode = HttpStatus.ok;
        request.response.add(audioBytes);
        await request.response.close();
      });

      addTearDown(() async => server.close(force: true));

      final result = await NetworkTtsService.synthesize(
        options: ElevenLabsTtsOptions(
          enabled: true,
          name: 'ElevenLabs',
          apiKey: 'eleven-key',
          baseUrl: _baseUrl(server),
          modelId: 'eleven_multilingual_v2',
          voiceId: 'pNInz6obpgDQGcFmaJgB',
        ),
        text: 'hello',
      );

      expect(captured.uri.path, '/api/v1/text-to-speech/pNInz6obpgDQGcFmaJgB');
      expect(captured.uri.queryParameters['output_format'], 'mp3_44100_128');
      expect(result.bytes, audioBytes);
      expect(result.mime, 'audio/mpeg');
    });

    test(
      'synthesizes MiMo streaming PCM response as wav with api-key auth',
      () async {
        late HttpRequest captured;
        late Map<String, dynamic> requestBody;
        final audio = base64Encode(<int>[3, 2, 1]);
        final server = await _bindServer((request) async {
          captured = request;
          requestBody =
              jsonDecode(await utf8.decoder.bind(request).join())
                  as Map<String, dynamic>;
          request.response.statusCode = HttpStatus.ok;
          request.response.headers.contentType = ContentType(
            'text',
            'event-stream',
          );
          request.response.write(
            'data: ${jsonEncode({
              'choices': [
                {
                  'delta': {
                    'audio': {'data': audio},
                  },
                },
              ],
            })}\n\n',
          );
          request.response.write('data: [DONE]\n\n');
          await request.response.close();
        });

        addTearDown(() async => server.close(force: true));

        final result = await NetworkTtsService.synthesize(
          options: MimoTtsOptions(
            enabled: true,
            name: 'MiMo',
            apiKey: 'mimo-key',
            baseUrl: _baseUrl(server),
            model: 'mimo-v2-tts',
            voice: 'mimo_default',
          ),
          text: 'hello',
        );

        expect(captured.uri.path, '/api/v1/chat/completions');
        expect(captured.headers.value('api-key'), 'mimo-key');
        expect(captured.headers.value(HttpHeaders.authorizationHeader), isNull);
        expect(requestBody['stream'], isTrue);
        expect(requestBody['audio'], {
          'format': 'pcm16',
          'voice': 'mimo_default',
        });
        expect(result.mime, 'audio/wav');
        expect(result.sampleRate, 24000);
        expect(utf8.decode(result.bytes.take(4).toList()), 'RIFF');
      },
    );

    test(
      'throws when MiMo streaming response contains no audio chunks',
      () async {
        final server = await _bindServer((request) async {
          await utf8.decoder.bind(request).join();
          request.response.statusCode = HttpStatus.ok;
          request.response.headers.contentType = ContentType(
            'text',
            'event-stream',
          );
          request.response.write('data: [DONE]\n\n');
          await request.response.close();
        });

        addTearDown(() async => server.close(force: true));

        expect(
          () => NetworkTtsService.synthesize(
            options: MimoTtsOptions(
              enabled: true,
              name: 'MiMo',
              apiKey: 'mimo-key',
              baseUrl: _baseUrl(server),
              model: 'mimo-v2-tts',
              voice: 'mimo_default',
            ),
            text: 'hello',
          ),
          throwsA(isA<Exception>()),
        );
      },
    );
  });
}

Future<HttpServer> _bindServer(
  Future<void> Function(HttpRequest request) handler,
) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  server.listen(handler);
  return server;
}

String _baseUrl(HttpServer server) {
  return 'http://${server.address.address}:${server.port}/api/v1';
}

String _hostOnlyBaseUrl(HttpServer server) {
  return 'http://${server.address.address}:${server.port}';
}
