import 'dart:async';

import 'package:Cuplivo/core/providers/tts_provider.dart';
import 'package:Cuplivo/core/services/tts/tts_playback_models.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('flutter_tts');
  const audioGlobalChannel = MethodChannel('xyz.luan/audioplayers.global');
  const audioChannel = MethodChannel('xyz.luan/audioplayers');
  late Set<String> audioEventChannels;
  late int speakCallCount;
  late List<String> spokenTexts;

  setUp(() {
    SharedPreferences.setMockInitialValues(const {});
    audioEventChannels = <String>{};
    speakCallCount = 0;
    spokenTexts = <String>[];
    _mockAudioEventStream('xyz.luan/audioplayers.global/events');
    audioEventChannels.add('xyz.luan/audioplayers.global/events');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(audioGlobalChannel, (_) async => null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(audioChannel, (call) async {
          if (call.method == 'create') {
            final args = call.arguments as Map<dynamic, dynamic>;
            final playerId = args['playerId'] as String;
            final eventChannel = 'xyz.luan/audioplayers/events/$playerId';
            _mockAudioEventStream(eventChannel);
            audioEventChannels.add(eventChannel);
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
  });

  test(
    'changing system TTS speed keeps the current playback position',
    () async {
      final provider = TtsProvider();
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
      final provider = TtsProvider();
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
