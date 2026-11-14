import 'dart:convert';
import 'dart:typed_data';

import 'package:Kelivo/core/services/asr/asr_service_options.dart';
import 'package:Kelivo/core/services/asr/cloud_asr_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('DeepSeekAsrOptions', () {
    test('applies defaults and round-trips through JSON', () {
      final options = AsrServiceOptions.fromJson({
        'kind': 'deepseek',
        'name': 'DeepSeek',
        'apiKey': 'ds-key',
      });

      expect(options, isA<DeepSeekAsrOptions>());
      final deepSeek = options as DeepSeekAsrOptions;
      expect(deepSeek.baseUrl, 'https://api.deepseek.com/v1');
      expect(deepSeek.sampleRate, 16000);
      expect(deepSeek.segmentDurationSec, 30);
      expect(deepSeek.isConfigured, isTrue);

      final restored = AsrServiceOptions.fromJson(deepSeek.toJson());
      expect(restored, isA<DeepSeekAsrOptions>());
      expect((restored as DeepSeekAsrOptions).id, deepSeek.id);
      expect(restored.apiKey, 'ds-key');

      expect(
        AsrServiceOptions.fromJson({
          'kind': 'deepseek',
          'apiKey': '',
        }).isConfigured,
        isFalse,
      );
    });
  });

  group('DeepSeek ASR session', () {
    test('uploads an authenticated multipart WAV and reads text', () async {
      final options = DeepSeekAsrOptions(
        apiKey: ' test-key ',
        baseUrl: 'http://proxy.test/v1',
      );
      late http.Request captured;
      final client = MockClient((request) async {
        captured = request;
        return http.Response.bytes(utf8.encode('{"text":" 你好，世界 "}'), 200);
      });

      final session = await CloudAsrService(
        httpClient: client,
      ).startSession(options);
      final partials = session.partialTranscripts.toList();
      final pcm = Uint8List(3200)..setAll(0, [0, 128, 255, 127]);

      await session.addPcm16(pcm);
      final finish = session.finish();
      expect(session.finish(), same(finish));
      expect(await finish, '你好，世界');
      expect(await partials, ['你好，世界']);

      expect(captured.method, 'POST');
      expect(captured.url.toString(), 'http://proxy.test/v1/tools/asr');
      expect(captured.headers['authorization'], 'Bearer test-key');
      expect(
        captured.headers['content-type'],
        startsWith('multipart/form-data; boundary='),
      );

      final body = latin1.decode(captured.bodyBytes);
      // DeepSeek takes only the audio; it rejects nothing extra but has no model
      // or language parameter, so neither is sent.
      expect(body, isNot(contains('name="model"')));
      expect(body, isNot(contains('name="language"')));
      expect(body, contains('name="file"; filename="recording.wav"'));
      expect(body, contains('content-type: audio/wav'));

      final start = body.indexOf('RIFF');
      expect(start, greaterThan(0));
      final wav = Uint8List.sublistView(
        captured.bodyBytes,
        start,
        start + 44 + pcm.length,
      );
      final header = ByteData.sublistView(wav);
      expect(latin1.decode(wav.sublist(8, 12)), 'WAVE');
      expect(header.getUint32(4, Endian.little), 36 + pcm.length);
      expect(header.getUint16(22, Endian.little), 1);
      expect(header.getUint32(24, Endian.little), 16000);
      expect(header.getUint16(34, Endian.little), 16);
      expect(header.getUint32(40, Endian.little), pcm.length);
      expect(wav.sublist(44), pcm);
    });

    test('keeps a custom base URL with a trailing slash', () async {
      final options = DeepSeekAsrOptions(
        apiKey: 'ds-key',
        baseUrl: 'https://api.deepseek.com/v1/',
      );
      final client = MockClient((request) async {
        expect(request.url.toString(), 'https://api.deepseek.com/v1/tools/asr');
        return http.Response('{"text":"ok","duration_ms":1200}', 200);
      });

      final session = await CloudAsrService(
        httpClient: client,
      ).startSession(options);
      await session.addPcm16(Uint8List(320));
      expect(await session.finish(), 'ok');
    });

    test('surfaces service errors without leaking the API key', () async {
      const secret = 'sk-deepseek-secret';
      final options = DeepSeekAsrOptions(apiKey: secret);
      final client = MockClient(
        (request) async => http.Response(
          '{"error":{"message":"Unsupported audio format"}}',
          400,
        ),
      );

      final session = await CloudAsrService(
        httpClient: client,
      ).startSession(options);
      await session.addPcm16(Uint8List(320));

      await expectLater(
        session.finish(),
        throwsA(
          isA<AsrException>()
              .having((error) => error.message, 'message', contains('HTTP 400'))
              .having(
                (error) => error.message,
                'message',
                contains('Unsupported audio format'),
              )
              .having(
                (error) => error.message,
                'message',
                isNot(contains(secret)),
              ),
        ),
      );
    });

    test('rejects a request when the key is missing', () async {
      await expectLater(
        CloudAsrService().startSession(DeepSeekAsrOptions()),
        throwsA(isA<AsrException>()),
      );
    });
  });
}
