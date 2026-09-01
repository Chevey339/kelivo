import 'dart:async';
import 'dart:io';

import 'package:Kelivo/core/providers/tts_provider.dart';
import 'package:Kelivo/core/services/tts/network_tts.dart';
import 'package:Kelivo/core/services/tts/tts_playback_models.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import '../../support/business_preferences_test_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = null;

  const channel = MethodChannel('flutter_tts');
  const audioGlobalChannel = MethodChannel('xyz.luan/audioplayers.global');
  const audioChannel = MethodChannel('xyz.luan/audioplayers');
  late Set<String> audioEventChannels;
  late int speakCallCount;
  late List<String> spokenTexts;
  late String? audioPlayerEventChannel;
  late BusinessPreferencesTestHarness harness;
  late BusinessPreferencesTestSession session;

  setUp(() async {
    harness = await BusinessPreferencesTestHarness.create();
    session = await harness.open();
    audioEventChannels = <String>{};
    speakCallCount = 0;
    spokenTexts = <String>[];
    audioPlayerEventChannel = null;
    _mockAudioEventStream('xyz.luan/audioplayers.global/events');
    audioEventChannels.add('xyz.luan/audioplayers.global/events');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(audioGlobalChannel, (_) async => null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(audioChannel, (call) async {
          final args = call.arguments as Map<dynamic, dynamic>;
          final playerId = args['playerId'] as String;
          final eventChannel = 'xyz.luan/audioplayers/events/$playerId';
          if (call.method == 'create') {
            audioPlayerEventChannel = eventChannel;
            _mockAudioEventStream(eventChannel);
            audioEventChannels.add(eventChannel);
          } else if (call.method == 'setSourceUrl') {
            scheduleMicrotask(() {
              unawaited(
                _emitAudioEvent(eventChannel, {
                  'event': 'audio.onPrepared',
                  'value': true,
                }),
              );
            });
          }
          return null;
        });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          switch (call.method) {
            case 'getLanguages':
              return const <String>['en-US', 'zh-CN'];
            case 'getEngines':
              return const <String>['test-tts'];
            case 'isLanguageAvailable':
              return true;
            case 'speak':
              speakCallCount++;
              final arguments = call.arguments;
              final text = arguments is Map
                  ? arguments['text']?.toString()
                  : arguments?.toString();
              spokenTexts.add(text ?? '');
              await _emitTtsCallback('speak.onStart');
              return 1;
            case 'stop':
              await _emitTtsCallback('speak.onComplete');
              return 1;
            default:
              return null;
          }
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(audioGlobalChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(audioChannel, null);
    for (final channelName in audioEventChannels) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMessageHandler(channelName, null);
    }
    return harness.dispose();
  });

  test('maps network audio MIME types to matching file extensions', () {
    expect(ttsAudioFileExtensionForMime('audio/mpeg'), 'mp3');
    expect(ttsAudioFileExtensionForMime('audio/wav'), 'wav');
    expect(ttsAudioFileExtensionForMime('audio/flac'), 'flac');
    expect(ttsAudioFileExtensionForMime('audio/pcm'), 'pcm');
  });

  test(
    'changing system TTS speed keeps the current playback position',
    () async {
      final provider = TtsProvider(preferences: session.preferences);
      addTearDown(provider.dispose);

      await _waitUntil(() => provider.isAvailable);

      final text = List.filled(240, 'a').join();
      unawaited(provider.speakSystem(text));
      await _waitUntil(
        () => provider.playbackState.status == TtsPlaybackStatus.playing,
      );

      await _emitTtsCallback('speak.onProgress', {
        'text': text,
        'start': 0,
        'end': 80,
        'word': 'a',
      });
      final beforeSpeedChange = provider.playbackState.position;
      expect(beforeSpeedChange, greaterThan(Duration.zero));
      expect(beforeSpeedChange, lessThan(provider.playbackState.duration));

      await provider.setPlaybackSpeed(1.2);

      expect(provider.playbackState.status, isNot(TtsPlaybackStatus.ended));
      expect(provider.playbackState.position, beforeSpeedChange);
    },
  );

  test(
    'finished system TTS can be replayed from the floating player',
    () async {
      final provider = TtsProvider(preferences: session.preferences);
      addTearDown(provider.dispose);

      await _waitUntil(() => provider.isAvailable);

      unawaited(provider.speakSystem('hello again'));
      await _waitUntil(
        () => provider.playbackState.status == TtsPlaybackStatus.playing,
      );
      await _emitTtsCallback('speak.onComplete');
      await _waitUntil(
        () => provider.playbackState.status == TtsPlaybackStatus.ended,
      );

      expect(provider.playbackState.isActive, isFalse);
      expect(provider.playbackState.isPlayerVisible, isTrue);
      final callsBeforeReplay = speakCallCount;

      unawaited(provider.togglePause());
      await _waitUntil(
        () =>
            provider.playbackState.status == TtsPlaybackStatus.playing &&
            speakCallCount == callsBeforeReplay + 1,
      );

      expect(spokenTexts.last, 'hello again');
      expect(provider.playbackState.position, Duration.zero);
    },
  );

  test('system TTS strips supported Markdown code ranges', () async {
    final provider = TtsProvider(preferences: session.preferences);
    addTearDown(provider.dispose);

    await _waitUntil(() => provider.isAvailable);

    unawaited(
      provider.speakSystem(
        '保留\n'
        '``print("行内代码")``\n'
        '~~~dart\n'
        'print("波浪线围栏");\n'
        '~~~\n'
        '```dart\n'
        'print("未闭合围栏");',
      ),
    );
    await _waitUntil(
      () => provider.playbackState.status == TtsPlaybackStatus.playing,
    );

    expect(spokenTexts.last, '保留');
  });

  test('network replay uses cached audio only when enabled', () async {
    final originalPathProvider = PathProviderPlatform.instance;
    final tempDirectory = await Directory.systemTemp.createTemp(
      'kelivo_tts_replay_test_',
    );
    PathProviderPlatform.instance = _FakePathProviderPlatform(
      tempDirectory.path,
    );
    addTearDown(() async {
      PathProviderPlatform.instance = originalPathProvider;
      await tempDirectory.delete(recursive: true);
    });

    var requestCount = 0;
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      requestCount++;
      await request.drain<void>();
      request.response.statusCode = HttpStatus.ok;
      request.response.add(const <int>[1, 2, 3]);
      await request.response.close();
    });
    addTearDown(() => server.close(force: true));

    final provider = TtsProvider(preferences: session.preferences);
    addTearDown(provider.dispose);
    await _waitUntil(() => provider.isAvailable);

    expect(provider.cacheNetworkAudioForReplay, isFalse);
    await provider.setCacheNetworkAudioForReplay(true);
    expect(
      session.preferences.getBool('tts_cache_network_audio_for_replay_v1'),
      isTrue,
    );

    final service = OpenAiTtsOptions(
      enabled: true,
      name: 'Local TTS',
      apiKey: 'test-key',
      baseUrl: 'http://${server.address.address}:${server.port}/v1',
      model: 'test-model',
      voice: 'alloy',
    );
    unawaited(provider.speakWithNetworkService(service, 'hello network'));
    await _waitUntil(
      () =>
          requestCount == 1 &&
          provider.playbackState.status == TtsPlaybackStatus.playing,
    );
    await _emitAudioEvent(audioPlayerEventChannel!, {
      'event': 'audio.onComplete',
    });
    await _waitUntil(
      () => provider.playbackState.status == TtsPlaybackStatus.ended,
    );

    unawaited(provider.togglePause());
    await _waitUntil(
      () => provider.playbackState.status == TtsPlaybackStatus.playing,
    );
    expect(requestCount, 1);
    await _emitAudioEvent(audioPlayerEventChannel!, {
      'event': 'audio.onComplete',
    });
    await _waitUntil(
      () => provider.playbackState.status == TtsPlaybackStatus.ended,
    );

    await provider.setCacheNetworkAudioForReplay(false);
    unawaited(provider.togglePause());
    await _waitUntil(
      () =>
          requestCount == 2 &&
          provider.playbackState.status == TtsPlaybackStatus.playing,
    );
    await _emitAudioEvent(audioPlayerEventChannel!, {
      'event': 'audio.onComplete',
    });
    await _waitUntil(
      () => provider.playbackState.status == TtsPlaybackStatus.ended,
    );
  });
}

Future<void> _waitUntil(bool Function() condition) async {
  final deadline = DateTime.now().add(const Duration(seconds: 2));
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) {
      fail('Timed out waiting for TTS provider condition');
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

Future<void> _emitTtsCallback(String method, [dynamic arguments]) async {
  final data = const StandardMethodCodec().encodeMethodCall(
    MethodCall(method, arguments),
  );
  final completer = Completer<void>();
  await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .handlePlatformMessage('flutter_tts', data, (_) => completer.complete());
  await completer.future;
}

Future<void> _emitAudioEvent(String channel, Map<String, dynamic> event) async {
  final data = const StandardMethodCodec().encodeSuccessEnvelope(event);
  final completer = Completer<void>();
  await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .handlePlatformMessage(channel, data, (_) => completer.complete());
  await completer.future;
}

void _mockAudioEventStream(String channel) {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMessageHandler(channel, (message) async {
        final methodCall = const StandardMethodCodec().decodeMethodCall(
          message,
        );
        if (methodCall.method == 'listen' || methodCall.method == 'cancel') {
          return const StandardMethodCodec().encodeSuccessEnvelope(null);
        }
        fail(
          'Unexpected audioplayers event stream method ${methodCall.method}',
        );
      });
}

class _FakePathProviderPlatform extends PathProviderPlatform {
  _FakePathProviderPlatform(this.path);

  final String path;

  @override
  Future<String?> getTemporaryPath() async => path;
}
