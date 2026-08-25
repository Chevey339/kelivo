import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:Kelivo/core/services/asr/asr_service_options.dart';
import 'package:Kelivo/core/services/asr/cloud_asr_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('OpenAI Realtime ASR', () {
    test('configures the official session and commits PCM audio', () async {
      final socket = _FakeWebSocket();
      late Uri connectedUri;
      late Map<String, String> connectedHeaders;
      final service = CloudAsrService(
        websocketConnector: (uri, headers) async {
          connectedUri = uri;
          connectedHeaders = headers;
          return socket;
        },
      );
      final session = await service.startSession(
        OpenAiRealtimeAsrOptions(
          apiKey: 'openai-secret',
          websocketUrl: 'wss://api.example.test/realtime',
          language: 'zh-cn',
          prompt: 'Kelivo',
          vadThreshold: 0,
        ),
      );

      expect(connectedUri.queryParameters['intent'], 'transcription');
      expect(connectedHeaders['Authorization'], 'Bearer openai-secret');
      final setup = socket.sentJson.single;
      expect(setup['type'], 'session.update');
      final input =
          (((setup['session'] as Map)['audio'] as Map)['input'] as Map);
      expect(input['format'], {'type': 'audio/pcm', 'rate': 24000});
      expect(input['turn_detection'], isNull);
      expect(input['transcription'], {
        'model': 'gpt-live-transcribe',
        'languages': ['zh-cn'],
        'prompt': 'Kelivo',
      });

      final partials = <String>[];
      final subscription = session.partialTranscripts.listen(partials.add);
      await session.addPcm16(Uint8List.fromList([1, 2, 3, 4]));
      expect(socket.sentJson.last, {
        'type': 'input_audio_buffer.append',
        'audio': 'AQIDBA==',
      });

      socket.serverJson({
        'type': 'conversation.item.input_audio_transcription.delta',
        'item_id': 'item-1',
        'delta': '你好',
      });
      expect(partials, ['你好']);

      final resultFuture = session.finish();
      expect(socket.sentJson.last, {'type': 'input_audio_buffer.commit'});
      socket.serverJson({
        'type': 'conversation.item.input_audio_transcription.completed',
        'item_id': 'item-1',
        'transcript': '你好。',
      });

      expect(await resultFuture, '你好。');
      expect(partials, ['你好', '你好。']);
      expect(socket.closeCode, 1000);
      await subscription.cancel();
    });

    test('redacts API keys from connection errors', () async {
      const secret = 'must-not-leak';
      final service = CloudAsrService(
        websocketConnector: (_, _) async {
          throw Exception('connector rejected $secret');
        },
      );

      await expectLater(
        service.startSession(OpenAiRealtimeAsrOptions(apiKey: secret)),
        throwsA(
          isA<AsrException>().having(
            (error) => error.toString(),
            'message',
            allOf(contains('connection failed'), isNot(contains(secret))),
          ),
        ),
      );
    });

    test('surfaces transcription.failed without waiting for timeout', () async {
      final socket = _FakeWebSocket();
      final session = await CloudAsrService(
        websocketConnector: (_, _) async => socket,
        completionTimeout: const Duration(milliseconds: 100),
      ).startSession(OpenAiRealtimeAsrOptions(apiKey: 'openai-secret'));
      await session.addPcm16(Uint8List.fromList([1, 2]));

      final resultFuture = session.finish();
      socket.serverJson({
        'type': 'conversation.item.input_audio_transcription.failed',
        'item_id': 'item-1',
        'error': {
          'code': 'audio_unintelligible',
          'message': 'Audio could not be transcribed',
        },
      });

      await expectLater(
        resultFuture,
        throwsA(
          isA<AsrException>().having(
            (error) => error.message,
            'message',
            allOf(
              contains('transcription failed'),
              contains('Audio could not be transcribed'),
              isNot(contains('timed out')),
            ),
          ),
        ),
      );
    });
  });

  group('DashScope ASR', () {
    test('uses the official Qwen ASR realtime lifecycle', () async {
      final socket = _FakeWebSocket();
      late Uri connectedUri;
      late Map<String, String> connectedHeaders;
      final session =
          await CloudAsrService(
            websocketConnector: (uri, headers) async {
              connectedUri = uri;
              connectedHeaders = headers;
              return socket;
            },
          ).startSession(
            DashScopeAsrOptions(
              apiKey: 'dash-secret',
              websocketUrl: 'wss://dash.example.test/realtime?workspace=kelivo',
              language: 'zh',
            ),
          );

      expect(
        connectedUri.queryParameters,
        containsPair('model', 'qwen3-asr-flash-realtime'),
      );
      expect(connectedUri.queryParameters, containsPair('workspace', 'kelivo'));
      expect(connectedHeaders, {'Authorization': 'Bearer dash-secret'});
      final setup = socket.sentJson.single;
      expect(setup['type'], 'session.update');
      final setupSession = setup['session'] as Map;
      expect(setupSession['input_audio_format'], 'pcm');
      expect(setupSession['sample_rate'], 16000);
      expect(setupSession['input_audio_transcription'], {'language': 'zh'});
      expect(setupSession['turn_detection'], isNull);

      final partialFuture = session.partialTranscripts.first;
      await session.addPcm16(Uint8List.fromList([5, 6]));
      expect(socket.sentJson.last['type'], 'input_audio_buffer.append');
      expect(socket.sentJson.last['event_id'], 'kelivo_asr_1');

      socket.serverJson({
        'type': 'conversation.item.input_audio_transcription.text',
        'item_id': 'dash-item',
        'text': '阿里',
      });
      expect(await partialFuture, '阿里');

      final resultFuture = session.finish();
      expect(
        socket.sentJson[socket.sentJson.length - 2]['type'],
        'input_audio_buffer.commit',
      );
      expect(
        socket.sentJson[socket.sentJson.length - 2]['event_id'],
        'kelivo_asr_2',
      );
      expect(socket.sentJson.last['type'], 'session.finish');
      expect(socket.sentJson.last['event_id'], 'kelivo_asr_3');
      socket.serverJson({
        'type': 'conversation.item.input_audio_transcription.completed',
        'item_id': 'dash-item',
        'transcript': '阿里云',
      });
      await Future<void>.delayed(Duration.zero);
      expect(socket.closeCode, isNull);
      socket.serverJson({'type': 'session.finished'});
      expect(await resultFuture, '阿里云');
      expect(socket.closeCode, 1000);
    });

    test('cancel closes the socket and rejects later audio', () async {
      final socket = _FakeWebSocket();
      final session = await CloudAsrService(
        websocketConnector: (_, _) async => socket,
      ).startSession(DashScopeAsrOptions(apiKey: 'dash-secret'));

      await session.cancel();

      expect(socket.closeCode, 1000);
      await expectLater(
        session.addPcm16(Uint8List.fromList([1, 2])),
        throwsA(isA<AsrException>()),
      );
    });

    test('finishes a no-speech session through session.finished', () async {
      final socket = _FakeWebSocket();
      final session = await CloudAsrService(
        websocketConnector: (_, _) async => socket,
      ).startSession(DashScopeAsrOptions(apiKey: 'dash-secret'));

      final resultFuture = session.finish();
      expect(socket.sentJson.last['type'], 'session.finish');
      expect(
        socket.sentJson.where(
          (event) => event['type'] == 'input_audio_buffer.commit',
        ),
        isEmpty,
      );
      socket.serverJson({'type': 'session.finished'});

      expect(await resultFuture, isEmpty);
      expect(socket.closeCode, 1000);
    });
  });

  group('Volcengine ASR', () {
    test('uses the RikkaHub binary WebSocket protocol', () async {
      final socket = _FakeWebSocket();
      late Uri connectedUri;
      late Map<String, String> connectedHeaders;
      final session =
          await CloudAsrService(
            websocketConnector: (uri, headers) async {
              connectedUri = uri;
              connectedHeaders = headers;
              return socket;
            },
          ).startSession(
            VolcengineAsrOptions(apiKey: 'volc-secret', language: 'zh-CN'),
          );

      expect(
        connectedUri.toString(),
        'wss://openspeech.bytedance.com/api/v3/sauc/bigmodel',
      );
      expect(connectedHeaders['X-Api-Key'], 'volc-secret');
      expect(
        connectedHeaders['X-Api-Resource-Id'],
        'volc.seedasr.sauc.duration',
      );
      expect(connectedHeaders['X-Api-Sequence'], '-1');
      expect(connectedHeaders['X-Api-Request-Id'], isNotEmpty);

      final configFrame = socket.sentBinary.single;
      expect(_volcMessageType(configFrame), 0x01);
      expect(_volcFlags(configFrame), 0);
      expect(_volcSerialization(configFrame), 0x01);
      expect(_volcCompression(configFrame), 0x01);
      final config =
          jsonDecode(utf8.decode(_volcPayload(configFrame)))
              as Map<String, dynamic>;
      expect(config['user'], {'uid': 'kelivo'});
      expect(config['audio'], {
        'format': 'pcm',
        'rate': 16000,
        'bits': 16,
        'channel': 1,
        'language': 'zh-CN',
      });
      expect(config['request'], {
        'model_name': 'bigmodel',
        'enable_itn': true,
        'enable_punc': true,
        'show_utterances': true,
        'result_type': 'full',
      });

      final partialFuture = session.partialTranscripts.first;
      await session.addPcm16(Uint8List.fromList([1, 2, 3, 4]));
      final audioFrame = socket.sentBinary.last;
      expect(_volcMessageType(audioFrame), 0x02);
      expect(_volcFlags(audioFrame), 0);
      expect(_volcCompression(audioFrame), 0);
      expect(_volcPayload(audioFrame), [1, 2, 3, 4]);

      socket.serverBinary(_volcTranscriptFrame('火山', isFinal: false));
      expect(await partialFuture, '火山');

      final resultFuture = session.finish();
      final finalAudioFrame = socket.sentBinary.last;
      expect(_volcMessageType(finalAudioFrame), 0x02);
      expect(_volcFlags(finalAudioFrame), 0x02);
      expect(_volcPayload(finalAudioFrame), isEmpty);

      socket.serverBinary(_volcTranscriptFrame('火山引擎', isFinal: true));
      expect(await resultFuture, '火山引擎');
      expect(socket.closeCode, 1000);
    });

    test('redacts API keys from binary server errors', () async {
      const secret = 'volc-private-key';
      final socket = _FakeWebSocket();
      final session = await CloudAsrService(
        websocketConnector: (_, _) async => socket,
      ).startSession(VolcengineAsrOptions(apiKey: secret));
      final streamError = expectLater(
        session.partialTranscripts,
        emitsError(
          isA<AsrException>().having(
            (error) => error.message,
            'message',
            allOf(contains('server error 45000001'), isNot(contains(secret))),
          ),
        ),
      );
      final resultFuture = session.finish();

      socket.serverBinary(_volcErrorFrame(45000001, 'invalid key: $secret'));

      await expectLater(
        resultFuture,
        throwsA(
          isA<AsrException>().having(
            (error) => error.message,
            'message',
            allOf(contains('server error 45000001'), isNot(contains(secret))),
          ),
        ),
      );
      await streamError;
    });
  });

  group('MiMo ASR', () {
    test('posts a PCM-wrapped WAV data URL to chat completions', () async {
      late http.Request captured;
      late Map<String, dynamic> body;
      final client = MockClient((request) async {
        captured = request;
        body = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response.bytes(
          utf8.encode(
            jsonEncode({
              'choices': [
                {
                  'message': {'content': '今天天气很好'},
                },
              ],
            }),
          ),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });
      final session = await CloudAsrService(httpClient: client).startSession(
        MimoAsrOptions(
          apiKey: 'mimo-secret',
          baseUrl: 'https://mimo.example.test/v1/',
          language: 'zh',
        ),
      );
      final partialFuture = session.partialTranscripts.first;
      await session.addPcm16(Uint8List.fromList([1, 2, 3, 4]));

      expect(await session.finish(), '今天天气很好');
      expect(await partialFuture, '今天天气很好');
      expect(captured.url.path, '/v1/chat/completions');
      expect(captured.headers['api-key'], 'mimo-secret');
      expect(body['model'], 'mimo-v2.5-asr');
      expect(body['asr_options'], {'language': 'zh'});

      final messages = body['messages'] as List;
      final content = (messages.single as Map)['content'] as List;
      final inputAudio = (content.single as Map)['input_audio'] as Map;
      final dataUrl = inputAudio['data'] as String;
      expect(dataUrl, startsWith('data:audio/wav;base64,'));
      final wav = base64Decode(dataUrl.split(',').last);
      expect(utf8.decode(wav.sublist(0, 4)), 'RIFF');
      expect(utf8.decode(wav.sublist(8, 12)), 'WAVE');
      expect(wav.sublist(44), [1, 2, 3, 4]);
    });

    test(
      'flushes timed segments as complete transcript-so-far updates',
      () async {
        var requestCount = 0;
        final client = MockClient((_) async {
          requestCount += 1;
          return http.Response(
            jsonEncode({
              'choices': [
                {
                  'message': {'content': 'segment-$requestCount'},
                },
              ],
            }),
            200,
          );
        });
        final session = await CloudAsrService(httpClient: client).startSession(
          MimoAsrOptions(
            apiKey: 'mimo-secret',
            sampleRate: 1,
            segmentDurationSec: 1,
          ),
        );
        final partialsFuture = session.partialTranscripts.take(2).toList();

        await session.addPcm16(Uint8List.fromList([1, 2]));
        await session.addPcm16(Uint8List.fromList([3, 4]));

        expect(await session.finish(), 'segment-1 segment-2');
        expect(await partialsFuture, ['segment-1', 'segment-1 segment-2']);
        expect(requestCount, 2);
      },
    );

    test('throws explicit HTTP errors without exposing the API key', () async {
      const secret = 'mimo-private-key';
      final client = MockClient(
        (_) async => http.Response(
          jsonEncode({
            'error': {'message': 'invalid key: $secret'},
          }),
          401,
        ),
      );
      final session = await CloudAsrService(
        httpClient: client,
      ).startSession(MimoAsrOptions(apiKey: secret));
      await session.addPcm16(Uint8List.fromList([1, 2]));

      await expectLater(
        session.finish(),
        throwsA(
          isA<AsrException>().having(
            (error) => error.toString(),
            'message',
            allOf(contains('HTTP 401'), isNot(contains(secret))),
          ),
        ),
      );
    });
  });

  group('Qwen Audio ASR', () {
    test(
      'combineQwenAudioTranscript inserts space after Latin punctuation',
      () {
        expect(combineQwenAudioTranscript('Hello.', 'World'), 'Hello. World');
        expect(combineQwenAudioTranscript('Hello!', 'World'), 'Hello! World');
        expect(combineQwenAudioTranscript('Hello', 'World'), 'Hello World');
        expect(combineQwenAudioTranscript('Hello. ', 'World'), 'Hello. World');
        // CJK joins stay unspaced.
        expect(combineQwenAudioTranscript('你好。', '今天'), '你好。今天');
        expect(combineQwenAudioTranscript('你好', '世界'), '你好世界');
      },
    );

    test('accumulates finalized sentences with the current partial', () async {
      final socket = _FakeWebSocket();
      late Uri connectedUri;
      late Map<String, String> connectedHeaders;
      final session =
          await CloudAsrService(
            websocketConnector: (uri, headers) async {
              connectedUri = uri;
              connectedHeaders = headers;
              return socket;
            },
          ).startSession(
            QwenAudioAsrOptions(
              apiKey: 'qwen-audio-secret',
              model: 'qwen-audio-3.0-asr-flash-streaming',
            ),
          );

      expect(
        connectedUri.toString(),
        'wss://dashscope.aliyuncs.com/api-ws/v1/inference',
      );
      expect(connectedHeaders['Authorization'], 'Bearer qwen-audio-secret');
      expect(socket.sentJson.single['header']['action'], 'run-task');

      final partials = <String>[];
      final subscription = session.partialTranscripts.listen(partials.add);

      socket.serverJson({
        'header': {'event': 'task-started', 'task_id': 't1'},
        'payload': const <String, dynamic>{},
      });
      await session.addPcm16(Uint8List.fromList([1, 2, 3, 4]));
      expect(socket.sentBinary, isNotEmpty);

      socket.serverJson({
        'header': {'event': 'result-generated'},
        'payload': {
          'output': {
            'sentence': {'text': '你好', 'sentence_end': false},
          },
        },
      });
      expect(partials, ['你好']);

      socket.serverJson({
        'header': {'event': 'result-generated'},
        'payload': {
          'output': {
            'sentence': {'text': '你好世界', 'sentence_end': true},
          },
        },
      });
      expect(partials.last, '你好世界');

      socket.serverJson({
        'header': {'event': 'result-generated'},
        'payload': {
          'output': {
            'sentence': {'text': '今天', 'sentence_end': false},
          },
        },
      });
      expect(partials.last, '你好世界今天');

      socket.serverJson({
        'header': {'event': 'result-generated'},
        'payload': {
          'output': {
            'sentence': {'text': '今天天气不错', 'sentence_end': true},
          },
        },
      });
      expect(partials.last, '你好世界今天天气不错');

      final resultFuture = session.finish();
      expect(socket.sentJson.last['header']['action'], 'finish-task');
      socket.serverJson({
        'header': {'event': 'task-finished'},
        'payload': const <String, dynamic>{},
      });

      expect(await resultFuture, '你好世界今天天气不错');
      expect(socket.closeCode, 1000);
      await subscription.cancel();
    });

    test(
      'inserts a space between English sentences ending with punctuation',
      () async {
        final socket = _FakeWebSocket();
        final session =
            await CloudAsrService(
              websocketConnector: (uri, headers) async => socket,
            ).startSession(
              QwenAudioAsrOptions(
                apiKey: 'qwen-audio-secret',
                model: 'qwen-audio-3.0-asr-flash-streaming',
              ),
            );

        final partials = <String>[];
        final subscription = session.partialTranscripts.listen(partials.add);

        socket.serverJson({
          'header': {'event': 'task-started', 'task_id': 't1'},
          'payload': const <String, dynamic>{},
        });

        socket.serverJson({
          'header': {'event': 'result-generated'},
          'payload': {
            'output': {
              'sentence': {'text': 'Hello.', 'sentence_end': true},
            },
          },
        });
        expect(partials.last, 'Hello.');

        socket.serverJson({
          'header': {'event': 'result-generated'},
          'payload': {
            'output': {
              'sentence': {'text': 'World', 'sentence_end': false},
            },
          },
        });
        expect(partials.last, 'Hello. World');

        socket.serverJson({
          'header': {'event': 'result-generated'},
          'payload': {
            'output': {
              'sentence': {'text': 'World', 'sentence_end': true},
            },
          },
        });
        expect(partials.last, 'Hello. World');

        final resultFuture = session.finish();
        socket.serverJson({
          'header': {'event': 'task-finished'},
          'payload': const <String, dynamic>{},
        });
        expect(await resultFuture, 'Hello. World');
        await subscription.cancel();
      },
    );
  });

  group('Step ASR', () {
    test('posts PCM JSON and parses the official SSE events', () async {
      late http.Request captured;
      late Map<String, dynamic> body;
      final client = MockClient((request) async {
        captured = request;
        body = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response.bytes(
          utf8.encode(
            [
              'data: ${jsonEncode({'type': 'transcript.text.delta', 'delta': '阶跃'})}',
              '',
              'data: ${jsonEncode({'type': 'transcript.text.done', 'text': '阶跃星辰'})}',
              '',
              'data: [DONE]',
              '',
            ].join('\n'),
          ),
          200,
          headers: {'content-type': 'text/event-stream'},
        );
      });
      final session = await CloudAsrService(httpClient: client).startSession(
        StepAsrOptions(
          apiKey: 'step-secret',
          baseUrl: 'https://step.example.test/',
          model: 'stepaudio-2-asr-pro',
          language: 'zh',
          sampleRate: 16000,
          enableItn: false,
          enableTimestamp: true,
          hotwords: const ['Kelivo', '阶跃星辰'],
        ),
      );
      final partialFuture = session.partialTranscripts.first;
      await session.addPcm16(Uint8List(3200));

      expect(await session.finish(), '阶跃星辰');
      expect(await partialFuture, '阶跃星辰');
      expect(
        captured.url.toString(),
        'https://step.example.test/v1/audio/asr/sse',
      );
      expect(captured.headers['authorization'], 'Bearer step-secret');
      expect(captured.headers['accept'], 'text/event-stream');
      expect(captured.headers['content-type'], 'application/json');

      final audio = body['audio'] as Map;
      expect(base64Decode(audio['data'] as String), hasLength(3200));
      final input = audio['input'] as Map;
      expect(input['transcription'], {
        'model': 'stepaudio-2-asr-pro',
        'enable_itn': false,
        'enable_timestamp': true,
        'language': 'zh',
        'hotwords': ['Kelivo', '阶跃星辰'],
      });
      expect(input['format'], {
        'type': 'pcm',
        'codec': 'pcm_s16le',
        'rate': 16000,
        'bits': 16,
        'channel': 1,
      });
    });

    test('flushes timed segments in recording order', () async {
      var requestCount = 0;
      final client = MockClient((_) async {
        requestCount += 1;
        return http.Response(
          'data: ${jsonEncode({'type': 'transcript.text.done', 'text': 'segment-$requestCount'})}\n\n',
          200,
        );
      });
      final session = await CloudAsrService(httpClient: client).startSession(
        StepAsrOptions(
          apiKey: 'step-secret',
          sampleRate: 1600,
          segmentDurationSec: 1,
        ),
      );
      final partialsFuture = session.partialTranscripts.take(2).toList();

      await session.addPcm16(Uint8List(3200));
      await session.addPcm16(Uint8List(3200));

      expect(await session.finish(), 'segment-1 segment-2');
      expect(await partialsFuture, ['segment-1', 'segment-1 segment-2']);
      expect(requestCount, 2);
    });

    test('cancel invalidates an in-flight segment request', () async {
      final requestStarted = Completer<void>();
      final response = Completer<http.Response>();
      var requestCount = 0;
      final client = MockClient((_) {
        requestCount += 1;
        if (!requestStarted.isCompleted) requestStarted.complete();
        return response.future;
      });
      final session = await CloudAsrService(httpClient: client).startSession(
        StepAsrOptions(
          apiKey: 'step-secret',
          sampleRate: 1600,
          segmentDurationSec: 1,
        ),
      );

      final addFuture = session.addPcm16(Uint8List(3200));
      await requestStarted.future;
      await session.cancel();
      response.complete(
        http.Response(
          'data: ${jsonEncode({'type': 'transcript.text.done', 'text': 'late'})}\n\n',
          200,
        ),
      );

      await expectLater(
        addFuture,
        throwsA(
          isA<AsrException>().having(
            (error) => error.message,
            'message',
            contains('cancelled'),
          ),
        ),
      );
      await expectLater(session.finish(), throwsA(isA<AsrException>()));
      expect(requestCount, 1);
    });

    test('retries and redacts API keys from HTTP errors', () async {
      const secret = 'step-private-key';
      var requestCount = 0;
      final client = MockClient((_) async {
        requestCount += 1;
        return http.Response(
          jsonEncode({
            'error': {'message': 'invalid key: $secret'},
          }),
          401,
        );
      });
      final session = await CloudAsrService(
        httpClient: client,
      ).startSession(StepAsrOptions(apiKey: secret));
      await session.addPcm16(Uint8List(3200));

      await expectLater(
        session.finish(),
        throwsA(
          isA<AsrException>().having(
            (error) => error.message,
            'message',
            allOf(contains('HTTP 401'), isNot(contains(secret))),
          ),
        ),
      );
      expect(requestCount, 3);
    });
  });

  test('rejects non-cloud options explicitly', () async {
    await expectLater(
      CloudAsrService().startSession(SystemAsrOptions()),
      throwsA(
        isA<AsrException>().having(
          (error) => error.message,
          'message',
          contains('not a cloud ASR service'),
        ),
      ),
    );
  });
}

class _FakeWebSocket implements AsrWebSocketConnection {
  final StreamController<Object?> _controller =
      StreamController<Object?>.broadcast(sync: true);
  final List<String> sent = [];
  final List<Uint8List> sentBinary = [];
  int? closeCode;
  String? closeReason;

  List<Map<String, dynamic>> get sentJson => sent
      .map((message) => jsonDecode(message) as Map<String, dynamic>)
      .toList();

  @override
  Stream<Object?> get messages => _controller.stream;

  @override
  void send(String message) => sent.add(message);

  @override
  void sendBinary(Uint8List message) {
    sentBinary.add(Uint8List.fromList(message));
  }

  void serverJson(Map<String, dynamic> event) {
    _controller.add(jsonEncode(event));
  }

  void serverBinary(Uint8List frame) {
    _controller.add(frame);
  }

  @override
  Future<void> close([int? code, String? reason]) async {
    closeCode = code;
    closeReason = reason;
    await _controller.close();
  }
}

int _volcMessageType(Uint8List frame) => (frame[1] >> 4) & 0x0f;

int _volcFlags(Uint8List frame) => frame[1] & 0x0f;

int _volcSerialization(Uint8List frame) => (frame[2] >> 4) & 0x0f;

int _volcCompression(Uint8List frame) => frame[2] & 0x0f;

Uint8List _volcPayload(Uint8List frame) {
  final headerSize = (frame[0] & 0x0f) * 4;
  var offset = headerSize;
  if ((_volcFlags(frame) & 0x01) != 0) offset += 4;
  final size = ByteData.sublistView(
    frame,
    offset,
    offset + 4,
  ).getUint32(0, Endian.big);
  offset += 4;
  final payload = frame.sublist(offset, offset + size);
  return _volcCompression(frame) == 0x01
      ? Uint8List.fromList(GZipCodec().decode(payload))
      : Uint8List.fromList(payload);
}

Uint8List _volcTranscriptFrame(String text, {required bool isFinal}) {
  final payload = Uint8List.fromList(
    GZipCodec().encode(
      utf8.encode(
        jsonEncode({
          'result': {'text': text},
        }),
      ),
    ),
  );
  final frame = ByteData(12 + payload.length);
  frame.setUint8(0, 0x11);
  frame.setUint8(1, 0x90 | (isFinal ? 0x03 : 0x01));
  frame.setUint8(2, 0x11);
  frame.setUint8(3, 0);
  frame.setInt32(4, isFinal ? -1 : 1, Endian.big);
  frame.setUint32(8, payload.length, Endian.big);
  frame.buffer.asUint8List(12).setAll(0, payload);
  return frame.buffer.asUint8List();
}

Uint8List _volcErrorFrame(int code, String message) {
  final payload = Uint8List.fromList(utf8.encode(message));
  final frame = ByteData(12 + payload.length);
  frame.setUint8(0, 0x11);
  frame.setUint8(1, 0xf0);
  frame.setUint8(2, 0);
  frame.setUint8(3, 0);
  frame.setUint32(4, code, Endian.big);
  frame.setUint32(8, payload.length, Endian.big);
  frame.buffer.asUint8List(12).setAll(0, payload);
  return frame.buffer.asUint8List();
}
