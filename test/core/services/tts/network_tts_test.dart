import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

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
      expect((minimax as MiniMaxTtsOptions).model, 'speech-2.8-turbo');
      expect(minimax.emotion, isEmpty);

      final gemini = TtsServiceOptions.fromJson({
        'kind': 'gemini',
        'enabled': true,
      });
      expect(
        (gemini as GeminiTtsOptions).model,
        'gemini-3.1-flash-tts-preview',
      );

      final azure = TtsServiceOptions.fromJson({
        'kind': 'azure',
        'enabled': true,
      });
      expect(azure, isA<AzureTtsOptions>());
      expect((azure as AzureTtsOptions).baseUrl, isEmpty);
      expect(azure.language, 'zh-CN');
      expect(azure.voice, 'zh-CN-XiaoxiaoNeural');
      expect(
        isValidAzureTtsEndpoint('https://eastus.tts.speech.microsoft.com'),
        isTrue,
      );
      expect(
        isValidAzureTtsEndpoint('eastus.tts.speech.microsoft.com'),
        isFalse,
      );
      expect(isValidAzureTtsEndpoint('ftp://example.com'), isFalse);

      final mimo = TtsServiceOptions.fromJson({
        'kind': 'mimo',
        'enabled': true,
        'model': 'mimo-v2-tts',
      });
      expect((mimo as MimoTtsOptions).model, 'mimo-v2.5-tts');
      expect(migrateMimoTtsModel('mimo-v2-tts'), 'mimo-v2.5-tts');

      final qwenAudio = TtsServiceOptions.fromJson({
        'kind': 'qwen_audio',
        'enabled': true,
      });
      expect(qwenAudio, isA<QwenAudioTtsOptions>());
      expect((qwenAudio as QwenAudioTtsOptions).voice, 'longanhuan_v3.6');
      expect(qwenAudio.model, 'qwen-audio-3.0-tts-flash');
    });

    test('round-trips advanced fields for new TTS providers', () {
      final miniMax = MiniMaxTtsOptions(
        enabled: true,
        name: 'MiniMax',
        apiKey: 'k',
        baseUrl: 'https://api.minimaxi.com/v1',
        model: 'speech-2.8-turbo',
        voiceId: 'female-shaonv',
        volume: 0.8,
        pitch: 2,
        languageBoost: 'Chinese',
        format: 'flac',
        sampleRate: 24000,
        bitrate: 64000,
        channel: 2,
        subtitleEnable: true,
        pronunciationDictionary: const <String>['Kelivo/ke-li-vo'],
      );
      final miniMaxAgain =
          TtsServiceOptions.fromJson(miniMax.toJson()) as MiniMaxTtsOptions;
      expect(miniMaxAgain.emotion, isEmpty);
      expect(miniMaxAgain.volume, 0.8);
      expect(miniMaxAgain.pitch, 2);
      expect(miniMaxAgain.languageBoost, 'Chinese');
      expect(miniMaxAgain.format, 'flac');
      expect(miniMaxAgain.sampleRate, 24000);
      expect(miniMaxAgain.bitrate, 64000);
      expect(miniMaxAgain.channel, 2);
      expect(miniMaxAgain.subtitleEnable, isTrue);
      expect(miniMaxAgain.pronunciationDictionary, <String>['Kelivo/ke-li-vo']);

      final step = StepTtsOptions(
        enabled: true,
        name: 'Step',
        apiKey: 'k',
        baseUrl: 'https://api.stepfun.com/v1',
        model: 'stepaudio-2.5-tts',
        voice: 'cixingnansheng',
        responseFormat: 'wav',
        speed: 1.25,
        volume: 0.8,
        sampleRate: 16000,
        instruction: 'whisper',
      );
      final stepAgain =
          TtsServiceOptions.fromJson(step.toJson()) as StepTtsOptions;
      expect(stepAgain.responseFormat, 'wav');
      expect(stepAgain.speed, 1.25);
      expect(stepAgain.volume, 0.8);
      expect(stepAgain.sampleRate, 16000);
      expect(stepAgain.instruction, 'whisper');

      final qwenAudio = QwenAudioTtsOptions(
        enabled: true,
        name: 'Qwen Audio',
        apiKey: 'k',
        workspaceId: 'ws',
        region: 'ap-southeast-1',
        model: 'qwen-audio-3.0-tts-flash',
        voice: 'longanhuan_v3.6',
        format: 'wav',
        sampleRate: 24000,
      );
      final qwenAgain =
          TtsServiceOptions.fromJson(qwenAudio.toJson()) as QwenAudioTtsOptions;
      expect(qwenAgain.region, 'ap-southeast-1');
      expect(qwenAgain.format, 'wav');
      expect(qwenAgain.sampleRate, 24000);

      final fish = FishAudioTtsOptions(
        enabled: true,
        name: 'Fish',
        apiKey: 'k',
        baseUrl: 'https://api.fish.audio',
        model: 's2.1-pro',
        referenceId: 'ref',
        format: 'opus',
        temperature: 0.4,
        topP: 0.5,
        speed: 1.1,
        sampleRate: 48000,
        latency: 'balanced',
      );
      final fishAgain =
          TtsServiceOptions.fromJson(fish.toJson()) as FishAudioTtsOptions;
      expect(fishAgain.format, 'opus');
      expect(fishAgain.temperature, 0.4);
      expect(fishAgain.topP, 0.5);
      expect(fishAgain.speed, 1.1);
      expect(fishAgain.sampleRate, 48000);
      expect(fishAgain.latency, 'balanced');

      final mimo = MimoTtsOptions(
        enabled: true,
        name: 'MiMo',
        apiKey: 'k',
        baseUrl: 'https://api.xiaomimimo.com/v1',
        model: 'mimo-v2.5-tts',
        voice: 'mimo_default',
        instruction: 'slow',
        stream: false,
        optimizeTextPreview: true,
      );
      final mimoAgain =
          TtsServiceOptions.fromJson(mimo.toJson()) as MimoTtsOptions;
      expect(mimoAgain.instruction, 'slow');
      expect(mimoAgain.stream, isFalse);
      expect(mimoAgain.optimizeTextPreview, isTrue);
    });

    test('only advertises MiniMax formats safe for chunked playback', () {
      expect(miniMaxAudioFormats, <String>['mp3', 'pcm']);
    });

    test('uses Groq provider-specific 200 character chunks', () {
      final groq = GroqTtsOptions(
        enabled: true,
        name: 'Groq',
        apiKey: 'key',
        baseUrl: 'https://api.groq.com/openai/v1',
        model: 'canopylabs/orpheus-v1-english',
        voice: 'austin',
      );
      final openAi = OpenAiTtsOptions(
        enabled: true,
        name: 'OpenAI',
        apiKey: 'key',
        baseUrl: 'https://api.openai.com/v1',
        model: 'gpt-4o-mini-tts',
        voice: 'alloy',
      );

      expect(networkTtsMaxCharsPerRequest(groq), 200);
      expect(networkTtsMaxCharsPerRequest(openAi), 220);
    });
  });

  group('NetworkTtsService', () {
    test('Azure sends escaped SSML and returns MP3 audio', () async {
      late HttpRequest captured;
      late String requestBody;
      final server = await _bindServer((request) async {
        captured = request;
        requestBody = await utf8.decoder.bind(request).join();
        request.response.statusCode = HttpStatus.ok;
        request.response.add(const <int>[1, 2, 3]);
        await request.response.close();
      });

      addTearDown(() async => server.close(force: true));

      final result = await NetworkTtsService.synthesize(
        options: AzureTtsOptions(
          enabled: true,
          name: 'Azure',
          apiKey: 'azure-key',
          baseUrl: '${_hostOnlyBaseUrl(server)}/cognitiveservices/v1/',
          language: 'zh-CN',
          voice: 'zh-CN-XiaoxiaoNeural',
        ),
        text: '你好 & <Kelivo>',
      );

      expect(captured.uri.path, '/cognitiveservices/v1');
      expect(captured.headers.value('Ocp-Apim-Subscription-Key'), 'azure-key');
      expect(
        captured.headers.value('X-Microsoft-OutputFormat'),
        'audio-24khz-96kbitrate-mono-mp3',
      );
      expect(
        requestBody,
        '<speak version="1.0" xml:lang="zh-CN">'
        '<voice name="zh-CN-XiaoxiaoNeural">'
        '你好 &amp; &lt;Kelivo&gt;</voice></speak>',
      );
      expect(result.mime, 'audio/mpeg');
      expect(result.bytes, <int>[1, 2, 3]);
    });

    test('Azure retries transient responses with bounded backoff', () async {
      var requestCount = 0;
      final stopwatch = Stopwatch()..start();
      final server = await _bindServer((request) async {
        await request.drain<void>();
        requestCount++;
        request.response.statusCode = switch (requestCount) {
          1 => HttpStatus.tooManyRequests,
          2 => HttpStatus.serviceUnavailable,
          _ => HttpStatus.ok,
        };
        if (requestCount == 1) {
          request.response.headers.set(HttpHeaders.retryAfterHeader, '1');
        }
        if (requestCount == 3) {
          request.response.add(const <int>[4, 5, 6]);
        }
        await request.response.close();
      });

      addTearDown(() async => server.close(force: true));

      final result = await NetworkTtsService.synthesize(
        options: AzureTtsOptions(
          enabled: true,
          name: 'Azure',
          apiKey: 'azure-key',
          baseUrl: _hostOnlyBaseUrl(server),
          language: 'zh-CN',
          voice: 'zh-CN-XiaoxiaoNeural',
        ),
        text: '你好',
      );

      expect(requestCount, 3);
      expect(
        stopwatch.elapsed,
        greaterThanOrEqualTo(const Duration(seconds: 1)),
      );
      expect(result.bytes, <int>[4, 5, 6]);
    });

    test('Azure does not retry after cancellation during backoff', () async {
      var requestCount = 0;
      var isCancelled = false;
      final server = await _bindServer((request) async {
        await request.drain<void>();
        requestCount++;
        request.response.statusCode = HttpStatus.serviceUnavailable;
        request.response.headers.set(HttpHeaders.retryAfterHeader, '60');
        await request.response.close();
      });

      addTearDown(() async => server.close(force: true));

      final synthesis = NetworkTtsService.synthesize(
        options: AzureTtsOptions(
          enabled: true,
          name: 'Azure',
          apiKey: 'azure-key',
          baseUrl: _hostOnlyBaseUrl(server),
          language: 'zh-CN',
          voice: 'zh-CN-XiaoxiaoNeural',
        ),
        text: '你好',
        cancelled: () {
          if (!isCancelled) {
            Timer(const Duration(milliseconds: 50), () => isCancelled = true);
          }
          return isCancelled;
        },
      );

      await expectLater(synthesis, throwsA(isA<Exception>()));
      expect(requestCount, 1);
    });

    test(
      'Azure cancellation aborts pending headers and audio streams',
      () async {
        for (final waitForHeaders in <bool>[true, false]) {
          final requestReceived = Completer<void>();
          final bodyStarted = Completer<void>();
          final releaseServer = Completer<void>();
          var isCancelled = false;
          final server = await _bindServer((request) async {
            requestReceived.complete();
            await request.drain<void>();
            try {
              if (waitForHeaders) await releaseServer.future;
              request.response.statusCode = HttpStatus.ok;
              request.response.add(const <int>[1]);
              await request.response.flush();
              if (!bodyStarted.isCompleted) bodyStarted.complete();
              if (!waitForHeaders) await releaseServer.future;
              await request.response.close();
            } catch (_) {}
          });

          final synthesis = NetworkTtsService.synthesize(
            options: AzureTtsOptions(
              enabled: true,
              name: 'Azure',
              apiKey: 'azure-key',
              baseUrl: _hostOnlyBaseUrl(server),
              language: 'zh-CN',
              voice: 'zh-CN-XiaoxiaoNeural',
            ),
            text: '你好',
            cancelled: () => isCancelled,
          );

          await requestReceived.future.timeout(const Duration(seconds: 1));
          if (!waitForHeaders) {
            await bodyStarted.future.timeout(const Duration(seconds: 1));
          }
          isCancelled = true;
          await expectLater(
            synthesis.timeout(const Duration(seconds: 1)),
            throwsA(isA<Exception>()),
          );

          if (!releaseServer.isCompleted) releaseServer.complete();
          await server.close(force: true);
        }
      },
    );

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
      expect(_riffChunkData(result.bytes, 'data'), pcm);
    });

    test('Qwen keeps PCM samples split across SSE events', () async {
      final result = await _synthesizeQwenAudio([
        [0, 1, 2],
        [3, 4, 5],
      ]);
      expect(_riffChunkData(result.bytes, 'data'), [0, 1, 2, 3, 4, 5]);
      expect(result.sampleRate, 24000);
    });

    test('Qwen extracts WAV chunks and preserves the actual format', () async {
      final format = _pcmFormat(16000);
      ByteData.sublistView(format)
        ..setUint16(2, 2, Endian.little)
        ..setUint32(8, 64000, Endian.little)
        ..setUint16(12, 4, Endian.little);
      final samples = <int>[1, 2, 3, 4, ...ascii.encode('RIFF'), 5, 6, 7, 8];
      final upstream = _buildWav([
        ('JUNK', [9, 8, 7]),
        ('fmt ', format),
        ('LIST', [1, 2]),
        ('data', samples.sublist(0, 4)),
        ('data', samples.sublist(4)),
      ]);
      final result = await _synthesizeQwenAudio([upstream]);

      expect(result.mime, 'audio/wav');
      expect(result.sampleRate, 16000);
      expect(_riffChunkData(result.bytes, 'fmt '), format);
      expect(_riffChunkData(result.bytes, 'data'), samples);
      expect(result.bytes.length, 44 + samples.length);
    });

    for (final sizes in <(int?, int?)>[
      (null, null),
      (0x7fffffbf, 0x7fffff9b), // Header reported in issue #1232.
      (0x7fffffff, 0x7fffffff),
      (0xffffffff, 0xffffffff),
      (0x7fffffff, 0x7fffffdb),
      (0xffffffff, 0xffffffdb),
      (0xffffffff, null),
      (null, 0xffffffff),
    ]) {
      test('Qwen normalizes WAV lengths $sizes across SSE events', () async {
        final samples = Uint8List(480);
        final upstream = _buildWav([
          ('fmt ', _pcmFormat(24000)),
          ('data', samples),
        ]);
        final view = ByteData.sublistView(upstream);
        if (sizes.$1 != null) view.setUint32(4, sizes.$1!, Endian.little);
        if (sizes.$2 != null) view.setUint32(40, sizes.$2!, Endian.little);
        final result = await _synthesizeQwenAudio([
          upstream.sublist(0, 2),
          upstream.sublist(2, 9),
          upstream.sublist(9, 39),
          upstream.sublist(39),
        ]);

        expect(result.sampleRate, 24000);
        expect(_riffChunkData(result.bytes, 'data'), samples);
        expect(
          ByteData.sublistView(result.bytes).getUint32(4, Endian.little),
          result.bytes.length - 8,
        );
        final exported = combineWavAudio(List.filled(5, result.bytes));
        expect(_riffChunkData(exported, 'data'), Uint8List(5 * samples.length));
        expect(exported.length, 44 + 5 * samples.length);
      });
    }

    test('Qwen preserves odd-sized 8-bit WAV data with RIFF padding', () async {
      final format = _pcmFormat(8000);
      ByteData.sublistView(format)
        ..setUint32(8, 8000, Endian.little)
        ..setUint16(12, 1, Endian.little)
        ..setUint16(14, 8, Endian.little);
      final result = await _synthesizeQwenAudio([
        _buildWav([
          ('fmt ', format),
          ('data', [128, 129, 127]),
        ]),
      ]);
      expect(_riffChunkData(result.bytes, 'data'), [128, 129, 127]);
      expect(result.bytes.length, 48);
      expect(result.sampleRate, 8000);
    });

    final validQwenWav = _buildWav([
      ('fmt ', _pcmFormat(24000)),
      ('data', [0, 1, 2, 3]),
    ]);
    final invalidQwenAudio = <String, List<int>>{
      'odd PCM byte count': [1, 2, 3],
      'truncated RIFF header': ascii.encode('RIFF'),
      'wrong RIFF form': _replaceWavUint32(validQwenWav, 8, 0),
      'truncated RIFF body': _replaceWavUint32(validQwenWav, 4, 100),
      'bytes outside RIFF': [...validQwenWav, 0, 0],
      'truncated chunk header': _replaceWavUint32(
        Uint8List.fromList([..._buildWav([]), ...ascii.encode('fmt ')]),
        4,
        8,
      ),
      'truncated data chunk': _replaceWavUint32(validQwenWav, 40, 6),
      'unknown fmt length': _replaceWavUint32(validQwenWav, 16, 0xffffffff),
      'missing fmt': _buildWav([
        ('data', [0, 0]),
      ]),
      'missing data': _buildWav([('fmt ', _pcmFormat(24000))]),
      'empty data': _buildWav([('fmt ', _pcmFormat(24000)), ('data', [])]),
      'short fmt': _buildWav([
        ('fmt ', [1, 0]),
        ('data', [0, 0]),
      ]),
      'zero sample rate': _replaceWavUint32(validQwenWav, 24, 0),
      'wrong byte rate': _replaceWavUint32(validQwenWav, 28, 100),
      'zero block alignment': _replaceWavUint32(validQwenWav, 32, 16 << 16),
      'wrong block alignment': _replaceWavUint32(
        validQwenWav,
        32,
        (16 << 16) | 4,
      ),
      'unsupported format': _replaceWavUint32(validQwenWav, 20, (1 << 16) | 2),
      'unaligned individual data chunks': _buildWav([
        ('fmt ', _pcmFormat(24000)),
        ('data', [1]),
        ('data', [2]),
      ]),
    };
    for (final entry in invalidQwenAudio.entries) {
      test('Qwen rejects ${entry.key}', () async {
        await expectLater(
          _synthesizeQwenAudio([entry.value]),
          throwsFormatException,
        );
      });
    }

    test('WAV concatenation still rejects streaming placeholder lengths', () {
      expect(
        () => combineWavAudio([_replaceWavUint32(validQwenWav, 4, 0x7fffffbf)]),
        throwsFormatException,
      );
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

    test('Qwen Audio consumes real WebSocket binary audio frames', () async {
      late HttpRequest upgradeRequest;
      final clientActions = <String>[];
      final server = await _bindServer((request) async {
        upgradeRequest = request;
        final socket = await WebSocketTransformer.upgrade(request);
        await for (final event in socket) {
          if (event is! String) continue;
          final message = jsonDecode(event) as Map<String, dynamic>;
          final header = message['header'] as Map<String, dynamic>;
          final action = header['action'].toString();
          clientActions.add(action);
          if (action == 'run-task') {
            socket.add(
              jsonEncode({
                'header': {'event': 'task-started'},
              }),
            );
          } else if (action == 'finish-task') {
            socket.add(Uint8List.fromList(<int>[1, 2, 3]));
            socket.add(
              jsonEncode({
                'header': {'event': 'result-generated'},
                'payload': {
                  'output': {
                    'sentence': {'text': 'hello'},
                  },
                },
              }),
            );
            socket.add(Uint8List.fromList(<int>[4, 5]));
            socket.add(
              jsonEncode({
                'header': {'event': 'task-finished'},
              }),
            );
          }
        }
      });
      addTearDown(() async => server.close(force: true));

      final result = await NetworkTtsService.synthesize(
        options: QwenAudioTtsOptions(
          enabled: true,
          name: 'Qwen Audio',
          apiKey: 'qwen-audio-key',
          workspaceId: 'workspace',
          model: 'qwen-audio-3.0-tts-flash',
          voice: 'longanhuan_v3.6',
          format: 'mp3',
          sampleRate: 22050,
        ),
        text: 'hello',
        qwenAudioWebSocketConnector: (_, {headers}) => WebSocket.connect(
          'ws://${server.address.address}:${server.port}',
          headers: headers,
        ),
      );

      expect(
        upgradeRequest.headers.value(HttpHeaders.authorizationHeader),
        'Bearer qwen-audio-key',
      );
      expect(
        upgradeRequest.headers.value('X-DashScope-WorkSpace'),
        'workspace',
      );
      expect(clientActions, <String>[
        'run-task',
        'continue-task',
        'finish-task',
      ]);
      expect(result.bytes, <int>[1, 2, 3, 4, 5]);
      expect(result.mime, 'audio/mpeg');
    });

    test(
      'MiniMax omits automatic emotion and sends advanced settings',
      () async {
        late Map<String, dynamic> requestBody;
        final server = await _bindServer((request) async {
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
              'data': {'audio': '010203'},
              'base_resp': {'status_code': 0, 'status_msg': 'success'},
            })}\n\n',
          );
          request.response.write('data: [DONE]\n\n');
          await request.response.close();
        });
        addTearDown(() async => server.close(force: true));

        final result = await NetworkTtsService.synthesize(
          options: MiniMaxTtsOptions(
            enabled: true,
            name: 'MiniMax',
            apiKey: 'minimax-key',
            baseUrl: _baseUrl(server),
            model: 'speech-2.8-turbo',
            voiceId: 'female-shaonv',
            emotion: '',
            speed: 1.1,
            volume: 0.8,
            pitch: 2,
            languageBoost: 'Chinese',
            format: 'mp3',
            sampleRate: 32000,
            bitrate: 128000,
            channel: 2,
            subtitleEnable: true,
            pronunciationDictionary: const <String>['Kelivo/ke-li-vo'],
          ),
          text: 'hello',
        );

        final voiceSetting =
            requestBody['voice_setting'] as Map<String, dynamic>;
        expect(voiceSetting.containsKey('emotion'), isFalse);
        expect(voiceSetting['vol'], 0.8);
        expect(voiceSetting['pitch'], 2);
        expect(requestBody['language_boost'], 'Chinese');
        expect(requestBody['audio_setting'], {
          'sample_rate': 32000,
          'bitrate': 128000,
          'format': 'mp3',
          'channel': 2,
        });
        expect(requestBody['pronunciation_dict'], {
          'tone': <String>['Kelivo/ke-li-vo'],
        });
        expect(requestBody['subtitle_enable'], isTrue);
        expect(result.bytes, <int>[1, 2, 3]);
      },
    );

    test('MiniMax accepts official fluent and whipser emotions', () async {
      final emotions = <String>[];
      final server = await _bindServer((request) async {
        final body =
            jsonDecode(await utf8.decoder.bind(request).join())
                as Map<String, dynamic>;
        emotions.add(
          ((body['voice_setting'] as Map)['emotion'] ?? '').toString(),
        );
        request.response.statusCode = HttpStatus.ok;
        request.response.write(
          'data: ${jsonEncode({
            'data': {'audio': '0102'},
            'base_resp': {'status_code': 0},
          })}\n\n',
        );
        request.response.write('data: [DONE]\n\n');
        await request.response.close();
      });
      addTearDown(() async => server.close(force: true));

      for (final emotion in const <String>['fluent', 'whipser']) {
        await NetworkTtsService.synthesize(
          options: MiniMaxTtsOptions(
            enabled: true,
            name: 'MiniMax',
            apiKey: 'minimax-key',
            baseUrl: _baseUrl(server),
            model: 'speech-2.6-turbo',
            voiceId: 'female-shaonv',
            emotion: emotion,
          ),
          text: 'hello',
        );
      }

      expect(emotions, <String>['fluent', 'whipser']);
    });

    test('MiniMax wraps PCM audio as WAV', () async {
      final server = await _bindServer((request) async {
        await utf8.decoder.bind(request).join();
        request.response.statusCode = HttpStatus.ok;
        request.response.write(
          'data: ${jsonEncode({
            'data': {'audio': '01020304'},
            'base_resp': {'status_code': 0},
          })}\n\n',
        );
        request.response.write('data: [DONE]\n\n');
        await request.response.close();
      });
      addTearDown(() async => server.close(force: true));

      final result = await NetworkTtsService.synthesize(
        options: MiniMaxTtsOptions(
          enabled: true,
          name: 'MiniMax',
          apiKey: 'minimax-key',
          baseUrl: _baseUrl(server),
          model: 'speech-2.8-turbo',
          voiceId: 'female-shaonv',
          format: 'pcm',
          sampleRate: 16000,
        ),
        text: 'hello',
      );

      expect(result.mime, 'audio/wav');
      expect(result.sampleRate, 16000);
      expect(_riffChunkData(result.bytes, 'data'), <int>[1, 2, 3, 4]);
    });

    test('MiniMax surfaces business errors from HTTP 200 SSE', () async {
      final server = await _bindServer((request) async {
        await utf8.decoder.bind(request).join();
        request.response.statusCode = HttpStatus.ok;
        request.response.write(
          'data: ${jsonEncode({
            'base_resp': {'status_code': 1004, 'status_msg': 'bad request'},
          })}\n\n',
        );
        await request.response.close();
      });
      addTearDown(() async => server.close(force: true));

      expect(
        () => NetworkTtsService.synthesize(
          options: _miniMaxOptions(_baseUrl(server)),
          text: 'hello',
        ),
        throwsA(
          predicate((error) => error.toString().contains('1004 bad request')),
        ),
      );
    });

    test(
      'MiniMax rejects malformed SSE instead of returning empty MP3',
      () async {
        final server = await _bindServer((request) async {
          await utf8.decoder.bind(request).join();
          request.response.statusCode = HttpStatus.ok;
          request.response.write('data: {not-json}\n\n');
          await request.response.close();
        });
        addTearDown(() async => server.close(force: true));

        expect(
          () => NetworkTtsService.synthesize(
            options: _miniMaxOptions(_baseUrl(server)),
            text: 'hello',
          ),
          throwsFormatException,
        );
      },
    );

    test('MiniMax cancellation aborts a stalled SSE parser', () async {
      final server = await _bindServer((request) async {
        await utf8.decoder.bind(request).join();
        request.response.statusCode = HttpStatus.ok;
        request.response.write(
          'data: ${jsonEncode({
            'base_resp': {'status_code': 0},
          })}\n\n',
        );
        await request.response.flush();
        await Future<void>.delayed(const Duration(seconds: 1));
        await request.response.close();
      });
      addTearDown(() async => server.close(force: true));
      var checks = 0;

      expect(
        () => NetworkTtsService.synthesize(
          options: _miniMaxOptions(_baseUrl(server)),
          text: 'hello',
          cancelled: () => checks++ > 0,
        ),
        throwsA(anything),
      );
    });

    test('Fish Audio validates reference ID and format/sample rate pair', () {
      expect(
        () => NetworkTtsService.synthesize(
          options: FishAudioTtsOptions(
            enabled: true,
            name: 'Fish',
            apiKey: 'fish-key',
            baseUrl: 'https://api.fish.audio',
            model: 's2.1-pro',
            referenceId: 'ref',
            format: 'opus',
            sampleRate: 32000,
          ),
          text: 'hello',
        ),
        throwsArgumentError,
      );
      expect(
        () => NetworkTtsService.synthesize(
          options: FishAudioTtsOptions(
            enabled: true,
            name: 'Fish',
            apiKey: 'fish-key',
            baseUrl: 'https://api.fish.audio',
            model: 's2.1-pro',
            referenceId: '',
          ),
          text: 'hello',
        ),
        throwsArgumentError,
      );
    });

    test('Fish Audio wraps raw PCM response as WAV', () async {
      final server = await _bindServer((request) async {
        await utf8.decoder.bind(request).join();
        request.response.statusCode = HttpStatus.ok;
        request.response.add(<int>[1, 2, 3, 4]);
        await request.response.close();
      });
      addTearDown(() async => server.close(force: true));

      final result = await NetworkTtsService.synthesize(
        options: FishAudioTtsOptions(
          enabled: true,
          name: 'Fish',
          apiKey: 'fish-key',
          baseUrl: _hostOnlyBaseUrl(server),
          model: 's2.1-pro',
          referenceId: 'reference-id',
          format: 'pcm',
          sampleRate: 16000,
        ),
        text: 'hello',
      );

      expect(result.mime, 'audio/wav');
      expect(result.sampleRate, 16000);
      expect(_riffChunkData(result.bytes, 'data'), <int>[1, 2, 3, 4]);
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

    test('wraps ElevenLabs PCM response as WAV with v1 base url', () async {
      late HttpRequest captured;
      final audioBytes = <int>[2, 4, 6, 8];
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
          outputFormat: 'pcm_24000',
        ),
        text: 'hello',
      );

      expect(captured.uri.path, '/api/v1/text-to-speech/pNInz6obpgDQGcFmaJgB');
      expect(captured.uri.queryParameters['output_format'], 'pcm_24000');
      expect(result.mime, 'audio/wav');
      expect(result.sampleRate, 24000);
      expect(utf8.decode(result.bytes.take(4).toList()), 'RIFF');
      expect(result.bytes.sublist(44), audioBytes);
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
            model: 'mimo-v2.5-tts',
            voice: 'mimo_default',
          ),
          text: 'hello',
        );

        expect(captured.uri.path, '/api/v1/chat/completions');
        expect(captured.headers.value('api-key'), 'mimo-key');
        expect(captured.headers.value(HttpHeaders.authorizationHeader), isNull);
        expect(requestBody['model'], 'mimo-v2.5-tts');
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

    test('synthesizes MiMo V2.5 non-streaming wav response', () async {
      late Map<String, dynamic> requestBody;
      final audio = base64Encode(<int>[5, 6, 7, 8]);
      final server = await _bindServer((request) async {
        requestBody =
            jsonDecode(await utf8.decoder.bind(request).join())
                as Map<String, dynamic>;
        request.response.statusCode = HttpStatus.ok;
        request.response.headers.contentType = ContentType.json;
        request.response.write(
          jsonEncode({
            'choices': [
              {
                'message': {
                  'audio': {'data': audio},
                },
              },
            ],
          }),
        );
        await request.response.close();
      });

      addTearDown(() async => server.close(force: true));

      final result = await NetworkTtsService.synthesize(
        options: MimoTtsOptions(
          enabled: true,
          name: 'MiMo',
          apiKey: 'mimo-key',
          baseUrl: _baseUrl(server),
          model: 'mimo-v2.5-tts',
          voice: 'Chloe',
          stream: false,
        ),
        text: 'hello',
      );

      expect(requestBody['stream'], isFalse);
      expect(requestBody['audio'], {'format': 'wav', 'voice': 'Chloe'});
      expect(result.mime, 'audio/wav');
      expect(result.bytes, <int>[5, 6, 7, 8]);
    });

    test(
      'MiMo Voice Design sends description without a built-in voice',
      () async {
        late Map<String, dynamic> requestBody;
        final audio = base64Encode(<int>[5, 6, 7, 8]);
        final server = await _bindServer((request) async {
          requestBody =
              jsonDecode(await utf8.decoder.bind(request).join())
                  as Map<String, dynamic>;
          request.response.statusCode = HttpStatus.ok;
          request.response.write(
            jsonEncode({
              'choices': [
                {
                  'message': {
                    'audio': {'data': audio},
                  },
                },
              ],
            }),
          );
          await request.response.close();
        });
        addTearDown(() async => server.close(force: true));

        await NetworkTtsService.synthesize(
          options: MimoTtsOptions(
            enabled: true,
            name: 'MiMo Design',
            apiKey: 'mimo-key',
            baseUrl: _baseUrl(server),
            model: 'mimo-v2.5-tts-voicedesign',
            voice: '',
            instruction: 'A warm young narrator',
            stream: false,
            optimizeTextPreview: true,
          ),
          text: 'hello',
        );

        expect(requestBody['messages'], [
          {'role': 'user', 'content': 'A warm young narrator'},
          {'role': 'assistant', 'content': 'hello'},
        ]);
        expect(requestBody['audio'], {
          'format': 'wav',
          'optimize_text_preview': true,
        });
      },
    );

    test('MiMo Voice Clone requires a valid audio data URI', () {
      expect(
        () => NetworkTtsService.synthesize(
          options: MimoTtsOptions(
            enabled: true,
            name: 'MiMo Clone',
            apiKey: 'mimo-key',
            baseUrl: 'https://api.xiaomimimo.com/v1',
            model: 'mimo-v2.5-tts-voiceclone',
            voice: 'not-a-data-uri',
            stream: false,
          ),
          text: 'hello',
        ),
        throwsArgumentError,
      );
    });

    test('MiMo Voice Clone sends Base64 reference audio', () async {
      late Map<String, dynamic> requestBody;
      final outputAudio = base64Encode(<int>[5, 6, 7, 8]);
      final server = await _bindServer((request) async {
        requestBody =
            jsonDecode(await utf8.decoder.bind(request).join())
                as Map<String, dynamic>;
        request.response.statusCode = HttpStatus.ok;
        request.response.write(
          jsonEncode({
            'choices': [
              {
                'message': {
                  'audio': {'data': outputAudio},
                },
              },
            ],
          }),
        );
        await request.response.close();
      });
      addTearDown(() async => server.close(force: true));
      final reference =
          'data:audio/mpeg;base64,${base64Encode(<int>[1, 2, 3, 4])}';

      await NetworkTtsService.synthesize(
        options: MimoTtsOptions(
          enabled: true,
          name: 'MiMo Clone',
          apiKey: 'mimo-key',
          baseUrl: _baseUrl(server),
          model: 'mimo-v2.5-tts-voiceclone',
          voice: reference,
          stream: false,
        ),
        text: 'hello',
      );

      expect(requestBody['messages'], [
        {'role': 'user', 'content': ''},
        {'role': 'assistant', 'content': 'hello'},
      ]);
      expect(requestBody['audio'], {'format': 'wav', 'voice': reference});
    });

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
              model: 'mimo-v2.5-tts',
              voice: 'mimo_default',
            ),
            text: 'hello',
          ),
          throwsA(isA<Exception>()),
        );
      },
    );

    test(
      'StepFun uses snake_case speech fields and chunks long text',
      () async {
        final bodies = <Map<String, dynamic>>[];
        final server = await _bindServer((request) async {
          bodies.add(
            jsonDecode(await utf8.decoder.bind(request).join())
                as Map<String, dynamic>,
          );
          request.response.statusCode = HttpStatus.ok;
          request.response.add(<int>[1, 2, 3]);
          await request.response.close();
        });
        addTearDown(() async => server.close(force: true));

        final long = 'a' * 1001;
        final result = await NetworkTtsService.synthesize(
          options: StepTtsOptions(
            enabled: true,
            name: 'Step',
            apiKey: 'step-key',
            baseUrl: _baseUrl(server),
            model: 'stepaudio-2.5-tts',
            voice: 'cixingnansheng',
            instruction: 'calm',
            responseFormat: 'mp3',
          ),
          text: long,
        );

        expect(bodies, hasLength(2));
        expect(bodies.first['response_format'], 'mp3');
        expect(bodies.first['sample_rate'], 24000);
        expect(bodies.first['instruction'], 'calm');
        expect(bodies.first.containsKey('responseFormat'), isFalse);
        expect(result.bytes.length, greaterThan(3));
      },
    );

    test('StepFun merges PCM chunks and wraps them as one WAV', () async {
      var requestCount = 0;
      final server = await _bindServer((request) async {
        requestCount++;
        await utf8.decoder.bind(request).join();
        request.response.statusCode = HttpStatus.ok;
        request.response.add(<int>[1, 2, 3, 4]);
        await request.response.close();
      });
      addTearDown(() async => server.close(force: true));

      final result = await NetworkTtsService.synthesize(
        options: StepTtsOptions(
          enabled: true,
          name: 'Step',
          apiKey: 'step-key',
          baseUrl: _baseUrl(server),
          model: 'stepaudio-2.5-tts',
          voice: 'cixingnansheng',
          responseFormat: 'pcm',
          sampleRate: 16000,
        ),
        text: 'a' * 1001,
      );

      expect(requestCount, 2);
      expect(result.mime, 'audio/wav');
      expect(result.sampleRate, 16000);
      expect(_riffChunkData(result.bytes, 'data'), <int>[
        1,
        2,
        3,
        4,
        1,
        2,
        3,
        4,
      ]);
    });
  });

  test('combines WAV data after variable RIFF chunks', () {
    final format = _pcmFormat(24000);
    final first = _buildWav(<(String, List<int>)>[
      ('JUNK', <int>[9, 8, 7]),
      ('fmt ', format),
      ('LIST', <int>[1, 2, 3, 4]),
      ('fact', _uint32Bytes(1)),
      ('data', <int>[1, 2]),
    ]);
    final second = _buildWav(<(String, List<int>)>[
      ('fmt ', format),
      ('fact', _uint32Bytes(1)),
      ('data', <int>[3, 4]),
    ]);

    final combined = combineWavAudio(<Uint8List>[first, second]);

    expect(_riffChunkOffset(first, 'data'), greaterThan(44));
    expect(_riffChunkData(combined, 'data'), <int>[1, 2, 3, 4]);
    expect(
      () => combineWavAudio(<Uint8List>[
        first,
        _buildWav(<(String, List<int>)>[
          ('fmt ', _pcmFormat(16000)),
          ('fact', _uint32Bytes(1)),
          ('data', <int>[3, 4]),
        ]),
      ]),
      throwsFormatException,
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

Future<NetworkTtsResult> _synthesizeQwenAudio(
  List<List<int>> audioParts,
) async {
  final server = await _bindServer((request) async {
    await request.drain<void>();
    request.response.headers.contentType = ContentType('text', 'event-stream');
    for (final part in audioParts) {
      request.response.write(
        'data: ${jsonEncode({
          'output': {
            'audio': {'data': base64Encode(part)},
          },
        })}\n\n',
      );
    }
    request.response.write('data: [DONE]\n\n');
    await request.response.close();
  });
  try {
    return await NetworkTtsService.synthesize(
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
  } finally {
    await server.close(force: true);
  }
}

Uint8List _replaceWavUint32(Uint8List wav, int offset, int value) {
  final bytes = Uint8List.fromList(wav);
  ByteData.sublistView(bytes).setUint32(offset, value, Endian.little);
  return bytes;
}

String _baseUrl(HttpServer server) {
  return 'http://${server.address.address}:${server.port}/api/v1';
}

String _hostOnlyBaseUrl(HttpServer server) {
  return 'http://${server.address.address}:${server.port}';
}

MiniMaxTtsOptions _miniMaxOptions(String baseUrl) {
  return MiniMaxTtsOptions(
    enabled: true,
    name: 'MiniMax',
    apiKey: 'minimax-key',
    baseUrl: baseUrl,
    model: 'speech-2.8-turbo',
    voiceId: 'female-shaonv',
  );
}

Uint8List _pcmFormat(int sampleRate) {
  final format = ByteData(16)
    ..setUint16(0, 1, Endian.little)
    ..setUint16(2, 1, Endian.little)
    ..setUint32(4, sampleRate, Endian.little)
    ..setUint32(8, sampleRate * 2, Endian.little)
    ..setUint16(12, 2, Endian.little)
    ..setUint16(14, 16, Endian.little);
  return format.buffer.asUint8List();
}

Uint8List _uint32Bytes(int value) {
  final bytes = ByteData(4)..setUint32(0, value, Endian.little);
  return bytes.buffer.asUint8List();
}

Uint8List _buildWav(List<(String, List<int>)> chunks) {
  final body = BytesBuilder(copy: false)..add(utf8.encode('WAVE'));
  for (final chunk in chunks) {
    body
      ..add(utf8.encode(chunk.$1))
      ..add(_uint32Bytes(chunk.$2.length))
      ..add(chunk.$2);
    if (chunk.$2.length.isOdd) body.addByte(0);
  }
  final bodyBytes = body.takeBytes();
  return (BytesBuilder(copy: false)
        ..add(utf8.encode('RIFF'))
        ..add(_uint32Bytes(bodyBytes.length))
        ..add(bodyBytes))
      .takeBytes();
}

int _riffChunkOffset(Uint8List wav, String id) {
  final view = ByteData.sublistView(wav);
  final end = 8 + view.getUint32(4, Endian.little);
  var offset = 12;
  while (offset + 8 <= end) {
    if (utf8.decode(wav.sublist(offset, offset + 4)) == id) return offset;
    final size = view.getUint32(offset + 4, Endian.little);
    offset += 8 + size + (size.isOdd ? 1 : 0);
  }
  throw StateError('Missing RIFF chunk $id');
}

Uint8List _riffChunkData(Uint8List wav, String id) {
  final offset = _riffChunkOffset(wav, id);
  final size = ByteData.sublistView(wav).getUint32(offset + 4, Endian.little);
  return wav.sublist(offset + 8, offset + 8 + size);
}
