import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:Kelivo/core/services/asr/asr_service_options.dart';
import 'package:Kelivo/core/services/asr/cloud_asr_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  for (final kind in [AsrServiceKind.groq, AsrServiceKind.mistral]) {
    group(kind.name, () {
      test(
        'uploads authenticated multipart WAV and reads UTF-8 text',
        () async {
          final options = AudioTranscriptionAsrOptions(
            kind: kind,
            apiKey: ' test-key ',
            language: ' zh ',
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
          final pcm = Uint8List(320)..setAll(0, [0, 128, 255, 127]);
          await session.addPcm16(pcm);
          final finish = session.finish();
          expect(session.finish(), same(finish));
          expect(await finish, '你好，世界');
          expect(await partials, ['你好，世界']);
          expect(captured.method, 'POST');
          expect(
            captured.url.toString(),
            '${options.baseUrl}/audio/transcriptions',
          );
          expect(captured.headers['authorization'], 'Bearer test-key');
          expect(
            captured.headers['content-type'],
            startsWith('multipart/form-data; boundary='),
          );
          final body = latin1.decode(captured.bodyBytes);
          expect(body, contains('name="model"\r\n\r\n${options.model}\r\n'));
          expect(body, contains('name="language"\r\n\r\nzh\r\n'));
          expect(body, contains('name="file"; filename="recording.wav"'));
          expect(body, contains('content-type: audio/wav'));
          expect(
            body.contains('name="response_format"'),
            kind == AsrServiceKind.groq,
          );
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
        },
      );

      for (final language in ['', ' auto ', 'AUTO']) {
        test(
          'omits automatic language "$language" and keeps custom endpoint/model',
          () async {
            final client = MockClient((request) async {
              expect(
                request.url.toString(),
                'https://proxy.test/prefix/audio/transcriptions?project=one',
              );
              final body = latin1.decode(request.bodyBytes);
              expect(body, contains('name="model"\r\n\r\ncustom-model\r\n'));
              expect(body, isNot(contains('name="language"')));
              return http.Response('{"text":"ok"}', 200);
            });
            final session = await CloudAsrService(httpClient: client).startSession(
              AudioTranscriptionAsrOptions(
                kind: kind,
                apiKey: 'key',
                baseUrl:
                    'https://proxy.test/prefix/audio/transcriptions/?project=one',
                model: 'custom-model',
                language: language,
              ),
            );
            await session.addPcm16(Uint8List(2));
            expect(await session.finish(), 'ok');
          },
        );
      }

      test(
        'splits oversized chunks and joins ordered transcript updates',
        () async {
          var requests = 0;
          final audio = <int>[];
          final client = MockClient((request) async {
            requests++;
            final start = latin1.decode(request.bodyBytes).indexOf('RIFF');
            final wav = ByteData.sublistView(request.bodyBytes, start);
            final length = wav.getUint32(40, Endian.little);
            expect(length, lessThanOrEqualTo(4));
            audio.addAll(
              request.bodyBytes.sublist(start + 44, start + 44 + length),
            );
            return http.Response(jsonEncode({'text': 'part-$requests'}), 200);
          });
          final session = await CloudAsrService(httpClient: client)
              .startSession(
                AudioTranscriptionAsrOptions(
                  kind: kind,
                  apiKey: 'key',
                  sampleRate: 2,
                  segmentDurationSec: 1,
                ),
              );
          final partials = session.partialTranscripts.toList();
          await session.addPcm16(Uint8List.fromList([1]));
          await session.addPcm16(
            Uint8List.fromList([2, 3, 4, 5, 6, 7, 8, 9, 10]),
          );
          expect(requests, 2);
          expect(await session.finish(), 'part-1 part-2 part-3');
          expect(await partials, [
            'part-1',
            'part-1 part-2',
            'part-1 part-2 part-3',
          ]);
          expect(audio, List.generate(10, (index) => index + 1));
        },
      );

      test('empty recording does not send a request', () async {
        final session = await CloudAsrService(
          httpClient: MockClient((_) async {
            fail('An empty recording must not be uploaded');
          }),
        ).startSession(AudioTranscriptionAsrOptions(kind: kind, apiKey: 'key'));
        expect(await session.finish(), '');
      });

      test('HTTP failure redacts the key and terminates the session', () async {
        const secret = 'private-api-key';
        final session =
            await CloudAsrService(
              httpClient: MockClient((_) async {
                return http.Response(
                  jsonEncode({
                    'error': {'message': 'invalid $secret'},
                  }),
                  401,
                );
              }),
            ).startSession(
              AudioTranscriptionAsrOptions(kind: kind, apiKey: secret),
            );
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
              (error) => error.message,
              'message',
              allOf(contains('HTTP 401'), isNot(contains(secret))),
            ),
          ),
        );
        expect(errors, hasLength(1));
        await expectLater(
          session.addPcm16(Uint8List(2)),
          throwsA(same(errors.single)),
        );
        await subscription.cancel();
      });

      for (final body in ['invalid', '{}', '{"text":123}']) {
        test('rejects malformed response $body', () async {
          final session =
              await CloudAsrService(
                httpClient: MockClient((_) async => http.Response(body, 200)),
              ).startSession(
                AudioTranscriptionAsrOptions(kind: kind, apiKey: 'key'),
              );
          await session.addPcm16(Uint8List(2));
          await expectLater(session.finish(), throwsA(isA<AsrException>()));
        });
      }

      test('accepts an empty transcript without inventing text', () async {
        final session = await CloudAsrService(
          httpClient: MockClient(
            (_) async => http.Response('{"text":""}', 200),
          ),
        ).startSession(AudioTranscriptionAsrOptions(kind: kind, apiKey: 'key'));
        await session.addPcm16(Uint8List(2));
        expect(await session.finish(), '');
      });

      test('rejects an incomplete PCM sample before uploading', () async {
        final session = await CloudAsrService(
          httpClient: MockClient((_) async {
            fail('Invalid PCM must not be uploaded');
          }),
        ).startSession(AudioTranscriptionAsrOptions(kind: kind, apiKey: 'key'));
        await session.addPcm16(Uint8List(1));
        await expectLater(
          session.finish(),
          throwsA(
            isA<AsrException>().having(
              (error) => error.message,
              'message',
              contains('incomplete PCM16'),
            ),
          ),
        );
      });

      test(
        'cancel aborts an in-flight request and ignores its late result',
        () async {
          final sent = Completer<http.BaseRequest>();
          final response = Completer<http.StreamedResponse>();
          final client = _ControlledClient((request) {
            sent.complete(request);
            return response.future;
          });
          final session = await CloudAsrService(httpClient: client)
              .startSession(
                AudioTranscriptionAsrOptions(kind: kind, apiKey: 'key'),
              );
          final partials = session.partialTranscripts.toList();
          await session.addPcm16(Uint8List(2));
          final finish = session.finish();
          final rejected = expectLater(
            finish,
            throwsA(
              isA<AsrException>().having(
                (error) => error.message,
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
              Stream.value(utf8.encode('{"text":"stale"}')),
              200,
            ),
          );
          expect(await partials, isEmpty);
          expect(client.closed, isFalse);
          await expectLater(
            session.addPcm16(Uint8List(2)),
            throwsA(isA<AsrException>()),
          );
        },
      );

      test(
        'timeout includes response body reading and aborts transport',
        () async {
          final body = StreamController<List<int>>();
          addTearDown(body.close);
          late http.Abortable request;
          final client = _ControlledClient((value) async {
            request = value as http.Abortable;
            return http.StreamedResponse(body.stream, 200);
          });
          final session =
              await CloudAsrService(
                httpClient: client,
                completionTimeout: const Duration(milliseconds: 20),
              ).startSession(
                AudioTranscriptionAsrOptions(kind: kind, apiKey: 'key'),
              );
          await session.addPcm16(Uint8List(2));
          await expectLater(
            session.finish(),
            throwsA(
              isA<AsrException>().having(
                (error) => error.message,
                'message',
                contains('timed out'),
              ),
            ),
          );
          await request.abortTrigger;
          expect(client.closed, isFalse);
        },
      );
    });
  }

  for (final (sampleRate, expectedBytes) in [(16000, 320), (22050, 442)]) {
    test('Groq pads a short tail to at least 10ms at $sampleRate Hz', () async {
      final pcm = Uint8List(128)..fillRange(0, 128, 3);
      final client = MockClient((request) async {
        final start = latin1.decode(request.bodyBytes).indexOf('RIFF');
        final header = ByteData.sublistView(request.bodyBytes, start);
        expect(header.getUint32(24, Endian.little), sampleRate);
        expect(header.getUint32(40, Endian.little), expectedBytes);
        final audio = request.bodyBytes.sublist(
          start + 44,
          start + 44 + expectedBytes,
        );
        expect(audio.take(pcm.length), pcm);
        expect(audio.skip(pcm.length), everyElement(0));
        return http.Response('{"text":"tail"}', 200);
      });
      final session = await CloudAsrService(httpClient: client).startSession(
        AudioTranscriptionAsrOptions(
          kind: AsrServiceKind.groq,
          apiKey: 'key',
          sampleRate: sampleRate,
        ),
      );
      await session.addPcm16(pcm);
      expect(await session.finish(), 'tail');
    });
  }

  test(
    'rejects non-HTTP transcription endpoints before starting a session',
    () async {
      await expectLater(
        CloudAsrService().startSession(
          AudioTranscriptionAsrOptions(
            kind: AsrServiceKind.groq,
            apiKey: 'key',
            baseUrl: 'wss://example.test/realtime',
          ),
        ),
        throwsA(isA<AsrException>()),
      );
    },
  );
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
