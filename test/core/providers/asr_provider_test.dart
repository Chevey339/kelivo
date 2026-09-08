import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/providers/asr_provider.dart';
import 'package:Kelivo/core/services/asr/asr_audio_capture.dart';
import 'package:Kelivo/core/services/asr/asr_service_options.dart';
import 'package:Kelivo/core/services/asr/cloud_asr_service.dart';
import 'package:Kelivo/core/services/asr/system_asr_service.dart';

void main() {
  test('unconfigured and unavailable local services stay hidden', () async {
    final provider = AsrProvider(
      localModelInstalledChecker: (_) async => false,
    );
    addTearDown(provider.dispose);

    expect(provider.canUse(OpenAiRealtimeAsrOptions()), isFalse);
    final local = SherpaOnnxAsrOptions(modelId: 'missing-model');
    await provider.refreshAvailability(local);
    expect(provider.canUse(local), isFalse);
    expect(provider.canUse(SystemAsrOptions()), isTrue);
  });

  test('streams PCM to cloud and returns its final transcript', () async {
    final capture = _FakeAudioCapture();
    final session = _FakeCloudSession(finalTranscript: 'hello world');
    final provider = AsrProvider(
      audioCaptureFactory: () => capture,
      cloudSessionStarter: (_) async => session,
    );
    addTearDown(provider.dispose);
    final options = OpenAiRealtimeAsrOptions(apiKey: 'test-key');

    await provider.start(options);
    expect(provider.state, AsrSessionState.listening);
    capture.add(_pcm16(6000));
    session.emitPartial('hello');
    await Future<void>.delayed(Duration.zero);

    expect(provider.transcript, 'hello');
    expect(provider.soundLevel, greaterThan(0));
    final result = await provider.finish();

    expect(result, 'hello world');
    expect(provider.state, AsrSessionState.idle);
    expect(session.receivedAudio, isNotEmpty);
    expect(capture.stopped, isTrue);
  });

  for (final sampleRate in [16000, 8000]) {
    test('Qwen Audio streams and finishes at $sampleRate Hz', () async {
      final capture = _FakeAudioCapture();
      final session = _FakeCloudSession(finalTranscript: 'hello world');
      final options = QwenAudioAsrOptions(
        apiKey: 'test-key',
        sampleRate: sampleRate,
      );
      final provider = AsrProvider(
        audioCaptureFactory: () => capture,
        cloudSessionStarter: (service) async {
          expect(service, same(options));
          return session;
        },
      );
      addTearDown(provider.dispose);

      await provider.start(options);
      expect(provider.state, AsrSessionState.listening);
      expect(capture.sampleRate, sampleRate);

      final pcm = _pcm16(6000);
      capture.add(pcm);
      session.emitPartial('hello');
      await Future<void>.delayed(Duration.zero);
      expect(provider.transcript, 'hello');

      expect(await provider.finish(), 'hello world');
      expect(session.receivedAudio, [pcm]);
      expect(capture.stopped, isTrue);
      expect(provider.state, AsrSessionState.idle);
    });
  }

  test('captures audio at each cloud provider sample rate', () async {
    final captures = <_FakeAudioCapture>[];
    final provider = AsrProvider(
      audioCaptureFactory: () {
        final capture = _FakeAudioCapture();
        captures.add(capture);
        return capture;
      },
      cloudSessionStarter: (_) async => _FakeCloudSession(finalTranscript: ''),
    );
    addTearDown(provider.dispose);

    await provider.start(VolcengineAsrOptions(apiKey: 'volc-key'));
    expect(captures.single.sampleRate, 16000);
    await provider.cancel();

    await provider.start(StepAsrOptions(apiKey: 'step-key', sampleRate: 8000));
    expect(captures.last.sampleRate, 8000);
    await provider.cancel();
  });

  test('runs downloaded local models only after capture stops', () async {
    final capture = _FakeAudioCapture();
    Uint8List? transcribedAudio;
    final provider = AsrProvider(
      audioCaptureFactory: () => capture,
      localModelInstalledChecker: (_) async => true,
      localTranscriber: (options, pcm16) async {
        transcribedAudio = pcm16;
        return '本地识别';
      },
    );
    addTearDown(provider.dispose);
    final options = SherpaOnnxAsrOptions(modelId: 'local-model');

    await provider.refreshAvailability(options);
    expect(provider.canUse(options), isTrue);
    await provider.start(options);
    final chunk = _pcm16(4000);
    capture.add(chunk);
    await Future<void>.delayed(Duration.zero);

    expect(await provider.finish(), '本地识别');
    expect(transcribedAudio, chunk);
    expect(provider.state, AsrSessionState.idle);
  });

  test('cancel discards partial text and closes remote work', () async {
    final capture = _FakeAudioCapture();
    final session = _FakeCloudSession(finalTranscript: 'ignored');
    final provider = AsrProvider(
      audioCaptureFactory: () => capture,
      cloudSessionStarter: (_) async => session,
    );
    addTearDown(provider.dispose);

    await provider.start(OpenAiRealtimeAsrOptions(apiKey: 'test-key'));
    session.emitPartial('discard me');
    await Future<void>.delayed(Duration.zero);
    await provider.cancel();

    expect(provider.transcript, isEmpty);
    expect(provider.state, AsrSessionState.idle);
    expect(session.cancelled, isTrue);
    expect(capture.cancelled, isTrue);
  });

  test(
    'cancel while cloud session connects cancels the late session',
    () async {
      final capture = _FakeAudioCapture();
      final session = _FakeCloudSession(finalTranscript: 'ignored');
      final starter = Completer<CloudAsrSession>();
      var starterCalled = false;
      final provider = AsrProvider(
        audioCaptureFactory: () => capture,
        cloudSessionStarter: (_) {
          starterCalled = true;
          return starter.future;
        },
      );
      addTearDown(provider.dispose);

      final startFuture = provider.start(
        OpenAiRealtimeAsrOptions(apiKey: 'test-key'),
      );
      await _waitUntil(() => starterCalled);
      await provider.cancel();

      starter.complete(session);
      await startFuture;

      expect(session.cancelled, isTrue);
      expect(capture.startCalls, isZero);
      expect(provider.state, AsrSessionState.idle);
      expect(provider.activeService, isNull);
    },
  );

  test('a late cloud session cannot replace the next session', () async {
    final firstCapture = _FakeAudioCapture();
    final secondCapture = _FakeAudioCapture();
    final captures = <_FakeAudioCapture>[firstCapture, secondCapture];
    var captureIndex = 0;
    final lateSession = _FakeCloudSession(finalTranscript: 'stale');
    final currentSession = _FakeCloudSession(finalTranscript: 'current');
    final firstStarter = Completer<CloudAsrSession>();
    var starterCalls = 0;
    final provider = AsrProvider(
      audioCaptureFactory: () => captures[captureIndex++],
      cloudSessionStarter: (_) {
        starterCalls++;
        return starterCalls == 1
            ? firstStarter.future
            : Future<CloudAsrSession>.value(currentSession);
      },
    );
    addTearDown(provider.dispose);
    final options = OpenAiRealtimeAsrOptions(apiKey: 'test-key');

    final firstStart = provider.start(options);
    await _waitUntil(() => starterCalls == 1);
    await provider.cancel();
    await provider.start(options);

    firstStarter.complete(lateSession);
    await firstStart;
    currentSession.emitPartial('still current');
    await Future<void>.delayed(Duration.zero);

    expect(lateSession.cancelled, isTrue);
    expect(firstCapture.startCalls, isZero);
    expect(secondCapture.startCalls, 1);
    expect(provider.state, AsrSessionState.listening);
    expect(provider.transcript, 'still current');

    await provider.cancel();
    expect(currentSession.cancelled, isTrue);
  });

  test('cancel invalidates a pending microphone permission check', () async {
    final permission = Completer<bool>();
    final capture = _FakeAudioCapture(permission: permission.future);
    var starterCalls = 0;
    final provider = AsrProvider(
      audioCaptureFactory: () => capture,
      cloudSessionStarter: (_) async {
        starterCalls++;
        return _FakeCloudSession(finalTranscript: 'ignored');
      },
    );
    addTearDown(provider.dispose);

    final startFuture = provider.start(
      OpenAiRealtimeAsrOptions(apiKey: 'test-key'),
    );
    await _waitUntil(() => provider.state == AsrSessionState.connecting);
    await provider.cancel();
    permission.complete(true);
    await startFuture;

    expect(starterCalls, isZero);
    expect(capture.startCalls, isZero);
    expect(provider.state, AsrSessionState.idle);
  });

  test('cancel invalidates a pending local model check', () async {
    final installed = Completer<bool>();
    var captureFactoryCalls = 0;
    final provider = AsrProvider(
      localModelInstalledChecker: (_) => installed.future,
      audioCaptureFactory: () {
        captureFactoryCalls++;
        return _FakeAudioCapture();
      },
    );
    addTearDown(provider.dispose);

    final startFuture = provider.start(
      SherpaOnnxAsrOptions(modelId: 'local-model'),
    );
    await _waitUntil(() => provider.state == AsrSessionState.connecting);
    await provider.cancel();
    installed.complete(true);
    await startFuture;

    expect(captureFactoryCalls, isZero);
    expect(provider.state, AsrSessionState.idle);
    expect(provider.activeService, isNull);
  });

  test(
    'cancelled system startup does not mark the service unavailable',
    () async {
      final backend = _FakeSystemAsrBackend();
      final provider = AsrProvider(
        systemService: SystemAsrService(backend: backend),
      );
      addTearDown(provider.dispose);
      final options = SystemAsrOptions();

      final startFuture = provider.start(options);
      await _waitUntil(() => backend.initializeCalls == 1);
      await provider.cancel();
      backend.initialization.complete(false);
      await startFuture;

      expect(provider.state, AsrSessionState.idle);
      expect(provider.activeService, isNull);
      expect(provider.canUse(options), isTrue);
    },
  );

  test('system final waits for native done before becoming idle', () async {
    final backend = _FakeSystemAsrBackend();
    backend.initialization.complete(true);
    final provider = AsrProvider(
      systemService: SystemAsrService(backend: backend),
    );
    addTearDown(provider.dispose);
    final options = SystemAsrOptions();

    await provider.start(options);
    backend.emitTranscript('final transcript', true);

    expect(provider.transcript, 'final transcript');
    expect(provider.state, AsrSessionState.listening);
    expect(provider.activeService, same(options));
    await expectLater(provider.start(options), throwsStateError);

    backend.emitStatus('done');

    expect(provider.state, AsrSessionState.idle);
    expect(provider.activeService, isNull);
    await provider.start(options);
    expect(provider.state, AsrSessionState.listening);
  });

  test(
    'system finish cancels a native session that never reports done',
    () async {
      final backend = _FakeSystemAsrBackend();
      backend.initialization.complete(true);
      final provider = AsrProvider(
        systemService: SystemAsrService(backend: backend),
      );
      addTearDown(provider.dispose);
      final options = SystemAsrOptions();

      await provider.start(options);
      final finish = provider.finish();

      expect(provider.state, AsrSessionState.transcribing);
      expect(provider.activeService, same(options));
      await Future<void>.delayed(const Duration(milliseconds: 2200));
      await finish;

      expect(backend.cancelCalls, 1);
      expect(provider.state, AsrSessionState.idle);
      expect(provider.activeService, isNull);
      await provider.start(options);
      expect(provider.state, AsrSessionState.listening);
    },
  );
}

Future<void> _waitUntil(bool Function() predicate) async {
  for (var attempt = 0; attempt < 20; attempt++) {
    if (predicate()) return;
    await Future<void>.delayed(Duration.zero);
  }
  fail('Condition was not reached before the test timed out.');
}

Uint8List _pcm16(int value) {
  final result = Uint8List(32);
  final data = ByteData.sublistView(result);
  for (var offset = 0; offset < result.length; offset += 2) {
    data.setInt16(offset, value, Endian.little);
  }
  return result;
}

final class _FakeAudioCapture implements AsrAudioCapture {
  _FakeAudioCapture({Future<bool>? permission})
    : _permission = permission ?? Future<bool>.value(true);

  final Future<bool> _permission;
  final StreamController<Uint8List> _controller =
      StreamController<Uint8List>.broadcast();
  bool stopped = false;
  bool cancelled = false;
  int startCalls = 0;
  int? sampleRate;

  void add(Uint8List chunk) => _controller.add(chunk);

  @override
  Future<bool> hasPermission() => _permission;

  @override
  Future<Stream<Uint8List>> start({required int sampleRate}) async {
    startCalls++;
    this.sampleRate = sampleRate;
    return _controller.stream;
  }

  @override
  Future<void> stop() async {
    stopped = true;
    await _controller.close();
  }

  @override
  Future<void> cancel() async {
    cancelled = true;
    if (!_controller.isClosed) await _controller.close();
  }

  @override
  Future<void> dispose() async {
    if (!_controller.isClosed) await _controller.close();
  }
}

final class _FakeCloudSession implements CloudAsrSession {
  _FakeCloudSession({required this.finalTranscript});

  final String finalTranscript;
  final StreamController<String> _partial =
      StreamController<String>.broadcast();
  final List<Uint8List> receivedAudio = <Uint8List>[];
  bool cancelled = false;

  void emitPartial(String value) => _partial.add(value);

  @override
  Stream<String> get partialTranscripts => _partial.stream;

  @override
  Future<void> addPcm16(Uint8List chunk) async {
    receivedAudio.add(Uint8List.fromList(chunk));
  }

  @override
  Future<String> finish() async {
    if (!_partial.isClosed) await _partial.close();
    return finalTranscript;
  }

  @override
  Future<void> cancel() async {
    cancelled = true;
    if (!_partial.isClosed) await _partial.close();
  }
}

final class _FakeSystemAsrBackend implements SystemAsrBackend {
  final Completer<bool> initialization = Completer<bool>();
  int initializeCalls = 0;
  int cancelCalls = 0;
  SystemAsrTranscriptCallback? _onTranscript;
  void Function(String status)? _onStatus;

  void emitTranscript(String text, bool isFinal) {
    _onTranscript?.call(text, isFinal);
  }

  void emitStatus(String status) {
    _onStatus?.call(status);
  }

  @override
  Future<bool> initialize({
    required SystemAsrErrorCallback onError,
    required void Function(String status) onStatus,
  }) {
    initializeCalls++;
    _onStatus = onStatus;
    return initialization.future;
  }

  @override
  Future<void> cancel() async {
    cancelCalls++;
  }

  @override
  Future<void> listen({
    required String? localeId,
    required Duration listenFor,
    required Duration pauseFor,
    required SystemAsrTranscriptCallback onTranscript,
    required SystemAsrSoundLevelCallback onSoundLevel,
  }) async {
    _onTranscript = onTranscript;
  }

  @override
  Future<List<SystemAsrLocale>> locales() async => const <SystemAsrLocale>[];

  @override
  Future<void> stop() async {}

  @override
  Future<SystemAsrLocale?> systemLocale() async => null;
}
