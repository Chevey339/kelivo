import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:Kelivo/core/services/asr/asr_service_options.dart';
import 'package:Kelivo/core/services/asr/cloud_asr_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

QwenAudioAsrOptions _options() => QwenAudioAsrOptions(
  apiKey: 'token-plan-key',
  workspaceId: 'token-plan',
  region: 'ap-southeast-1',
  mode: QwenAudioAsrMode.transcription,
);

http.Response _response(String text) => http.Response.bytes(
  utf8.encode(
    jsonEncode({
      'output': {'text': text},
    }),
  ),
  200,
);

Uint8List _uploadedWav(http.Request request) {
  final body = jsonDecode(request.body) as Map<String, dynamic>;
  final audio =
      body['input']['messages'][0]['content'][0]['input_audio']['data']
          as String;
  expect(audio, startsWith('data:audio/wav;base64,'));
  return base64Decode(audio.split(',').last);
}

void main() {
  test('posts Token Plan audio using the documented HTTP contract', () async {
    late http.Request captured;
    final session = await CloudAsrService(
      websocketConnector: (_, _) async =>
          throw StateError('Unexpected WebSocket'),
      httpClient: MockClient((request) async {
        captured = request;
        return http.Response.bytes(
          utf8.encode(
            jsonEncode({
              'output': {
                'text': '你好。完整识别结果。',
                'sentence': {'text': '完整识别结果。'},
              },
            }),
          ),
          200,
        );
      }),
    ).startSession(_options().copyWith(language: 'zh'));
    final pcm = Uint8List.fromList([0, 1, 2, 3, 4, 5]);
    await session.addPcm16(pcm);
    expect(await session.finish(), '你好。完整识别结果。');
    expect(
      captured.url.toString(),
      'https://token-plan.ap-southeast-1.maas.aliyuncs.com/api/v1/services/aigc/multimodal-generation/generation',
    );
    expect(captured.method, 'POST');
    expect(captured.headers['authorization'], 'Bearer token-plan-key');
    expect(captured.headers['X-DashScope-WorkSpace'], 'token-plan');
    expect(captured.headers['X-DashScope-SSE'], 'disable');
    final body = jsonDecode(captured.body) as Map<String, dynamic>;
    expect(body['model'], 'qwen-audio-3.0-asr-flash');
    expect(body['input']['messages'][0]['role'], 'user');
    expect(body['input']['messages'][0]['content'][0]['type'], 'input_audio');
    expect(body['parameters'], {
      'format': 'wav',
      'sample_rate': '16000',
      'language_hints': ['zh'],
    });
    final wav = _uploadedWav(captured);
    final header = ByteData.sublistView(wav);
    expect(ascii.decode(wav.sublist(0, 4)), 'RIFF');
    expect(header.getUint16(22, Endian.little), 1);
    expect(header.getUint32(24, Endian.little), 16000);
    expect(header.getUint16(34, Endian.little), 16);
    expect(header.getUint32(40, Endian.little), pcm.length);
    expect(wav.sublist(44), pcm);
  });

  for (final language in ['', ' auto ', 'AUTO']) {
    test(
      'keeps a custom full path and omits automatic language "$language"',
      () async {
        final session =
            await CloudAsrService(
              httpClient: MockClient((request) async {
                expect(
                  request.url.toString(),
                  'https://proxy.test/custom/asr/?project=one',
                );
                final body = jsonDecode(request.body) as Map;
                expect(body['model'], 'custom-model');
                expect(body['parameters'], isNot(contains('language_hints')));
                return _response('ok');
              }),
            ).startSession(
              _options().copyWith(
                endpoint: 'https://proxy.test/custom/asr/?project=one',
                model: 'custom-model',
                language: language,
              ),
            );
        await session.addPcm16(Uint8List(2));
        expect(await session.finish(), 'ok');
      },
    );
  }

  test('segments oversized chunks in order without dropping samples', () async {
    final audio = <int>[];
    var calls = 0;
    final session = await CloudAsrService(
      httpClient: MockClient((request) async {
        final pcm = _uploadedWav(request).sublist(44);
        expect(pcm.length, lessThanOrEqualTo(4));
        audio.addAll(pcm);
        return _response(['你好。', '今天', '晴天。'][calls++]);
      }),
    ).startSession(_options().copyWith(sampleRate: 2, segmentDurationSec: 1));
    final partials = session.partialTranscripts.toList();
    await session.addPcm16(Uint8List.fromList([1]));
    await session.addPcm16(Uint8List.fromList([2, 3, 4, 5, 6, 7, 8, 9, 10]));
    expect(await session.finish(), '你好。今天晴天。');
    expect(await partials, ['你好。', '你好。今天', '你好。今天晴天。']);
    expect(audio, List.generate(10, (i) => i + 1));
    expect(calls, 3);
  });

  test(
    'caps uploads at five minutes even with segmentation disabled',
    () async {
      final lengths = <int>[];
      final session = await CloudAsrService(
        httpClient: MockClient((request) async {
          lengths.add(_uploadedWav(request).length - 44);
          return _response('');
        }),
      ).startSession(_options().copyWith(sampleRate: 2, segmentDurationSec: 0));
      await session.addPcm16(Uint8List(1202));
      expect(await session.finish(), '');
      expect(lengths, [1200, 2]);
    },
  );

  for (final (first, next, expected) in [
    ('Привет', 'мир', 'Привет мир'),
    ('Привет!', 'Мир', 'Привет! Мир'),
    ('café', 'été', 'café été'),
    ('See (', 'details)', 'See (details)'),
    ('well-', 'known', 'well-known'),
    ('snake_', 'case', 'snake_case'),
    ('user@', 'example.com', 'user@example.com'),
    ('path/', 'name', 'path/name'),
    ('مرحبا،', 'بالعالم', 'مرحبا، بالعالم'),
    ('안녕하세요', '세계', '안녕하세요 세계'),
    ('नमस्ते', 'दुनिया', 'नमस्ते दुनिया'),
    ('你好。', '世界', '你好。世界'),
    ('こんにちは', '世界', 'こんにちは世界'),
    ('สวัสดี', 'โลก', 'สวัสดีโลก'),
  ]) {
    test('preserves transcript word boundaries in "$expected"', () async {
      var calls = 0;
      final session = await CloudAsrService(
        httpClient: MockClient(
          (_) async => _response(calls++ == 0 ? first : next),
        ),
      ).startSession(_options().copyWith(sampleRate: 2, segmentDurationSec: 1));
      await session.addPcm16(Uint8List(8));
      expect(await session.finish(), expected);
    });
  }

  test('empty recording makes no request', () async {
    final session = await CloudAsrService(
      httpClient: MockClient((_) async {
        fail('Empty audio must not be uploaded');
      }),
    ).startSession(_options());
    expect(await session.finish(), '');
  });

  test('rejects an incomplete PCM sample before upload', () async {
    final session = await CloudAsrService(
      httpClient: MockClient((_) async {
        fail('Incomplete sample must not be uploaded');
      }),
    ).startSession(_options());
    await session.addPcm16(Uint8List(1));
    await expectLater(session.finish(), throwsA(isA<AsrException>()));
  });

  for (final body in [
    'invalid',
    '{}',
    '{"output":{"text":123}}',
    '{"output":{"sentence":{"text":"last sentence only"}}}',
  ]) {
    test('rejects malformed or incomplete result $body', () async {
      final session = await CloudAsrService(
        httpClient: MockClient((_) async => http.Response(body, 200)),
      ).startSession(_options());
      await session.addPcm16(Uint8List(2));
      await expectLater(session.finish(), throwsA(isA<AsrException>()));
    });
  }

  test(
    'reports an API failure without leaking the key and stops the session',
    () async {
      final session = await CloudAsrService(
        httpClient: MockClient(
          (_) async => http.Response(
            '{"code":"InvalidApiKey","message":"invalid token-plan-key"}',
            401,
          ),
        ),
      ).startSession(_options());
      final errors = <Object>[];
      final subscription = session.partialTranscripts.listen(
        (_) {},
        onError: errors.add,
      );
      await session.addPcm16(Uint8List(2));
      await expectLater(
        session.finish(),
        throwsA(
          isA<AsrException>().having(
            (e) => e.message,
            'message',
            allOf(contains('HTTP 401'), isNot(contains('token-plan-key'))),
          ),
        ),
      );
      expect(errors, hasLength(1));
      await expectLater(
        session.addPcm16(Uint8List(2)),
        throwsA(same(errors.single)),
      );
      await subscription.cancel();
    },
  );

  test('cancel aborts an upload and ignores the late response', () async {
    final sent = Completer<http.BaseRequest>();
    final response = Completer<http.StreamedResponse>();
    final client = _ControlledClient((request) {
      sent.complete(request);
      return response.future;
    });
    final session = await CloudAsrService(
      httpClient: client,
    ).startSession(_options());
    final partials = session.partialTranscripts.toList();
    await session.addPcm16(Uint8List(2));
    final finish = session.finish();
    final rejected = expectLater(
      finish,
      throwsA(
        isA<AsrException>().having(
          (e) => e.message,
          'message',
          contains('cancelled'),
        ),
      ),
    );
    final request = await sent.future as http.Abortable;
    await session.cancel();
    await request.abortTrigger;
    await rejected;
    response.complete(
      http.StreamedResponse(
        Stream.value(utf8.encode('{"output":{"text":"late result"}}')),
        200,
      ),
    );
    expect(await partials, isEmpty);
    expect(client.closed, isFalse);
  });

  test('timeout includes the response body and aborts transport', () async {
    final body = StreamController<List<int>>();
    addTearDown(body.close);
    late http.Abortable request;
    final client = _ControlledClient((value) async {
      request = value as http.Abortable;
      return http.StreamedResponse(body.stream, 200);
    });
    final session = await CloudAsrService(
      httpClient: client,
      completionTimeout: const Duration(milliseconds: 20),
    ).startSession(_options());
    await session.addPcm16(Uint8List(2));
    await expectLater(
      session.finish(),
      throwsA(
        isA<AsrException>().having(
          (e) => e.message,
          'message',
          contains('timed out'),
        ),
      ),
    );
    await request.abortTrigger;
    expect(client.closed, isFalse);
  });
}

class _ControlledClient extends http.BaseClient {
  _ControlledClient(this.handler);
  final Future<http.StreamedResponse> Function(http.BaseRequest) handler;
  bool closed = false;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      handler(request);

  @override
  void close() => closed = true;
}
