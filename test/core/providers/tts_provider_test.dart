import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:Kelivo/core/providers/tts_provider.dart';
import 'package:Kelivo/core/models/mobile_background_settings.dart';
import 'package:Kelivo/core/services/mobile_background.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/core/services/tts/network_tts.dart';
import 'package:Kelivo/core/services/tts/tts_playback_models.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
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
  const backgroundChannel = MethodChannel('test.tts.background');
  final audioOwners = <String>{};
  var networkSources = 0;
  var networkResumes = 0;
  var rejectPause = false;
  Completer<void>? stopEntered;
  Completer<void>? stopGate;
  Completer<void>? speechGate;
  final terminalAudioOwners = <Set<String>>[];

  setUp(() async {
    harness = await BusinessPreferencesTestHarness.create();
    session = await harness.open();
    audioOwners.clear();
    networkSources = 0;
    networkResumes = 0;
    rejectPause = false;
    stopEntered = null;
    stopGate = null;
    speechGate = null;
    terminalAudioOwners.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(backgroundChannel, (call) async {
          if (call.method == 'audioOwner') {
            final args = call.arguments as Map;
            if (args['active'] == true) {
              audioOwners.add(args['owner'] as String);
            } else {
              audioOwners.remove(args['owner']);
            }
          } else if (call.method == 'sync' &&
              (call.arguments as Map)['terminal'] != null) {
            terminalAudioOwners.add(Set.of(audioOwners));
          }
          return call.method == 'sync' ? <String, dynamic>{} : null;
        });
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
          if (call.method == 'stop' && stopGate != null) {
            if (stopEntered?.isCompleted == false) stopEntered!.complete();
            await stopGate!.future;
          }
          if (call.method == 'resume') networkResumes++;
          if (call.method == 'pause' && rejectPause) {
            throw PlatformException(code: 'audio_services_reset');
          }
          final args = call.arguments as Map<dynamic, dynamic>;
          final playerId = args['playerId'] as String;
          final eventChannel = 'xyz.luan/audioplayers/events/$playerId';
          if (call.method == 'create') {
            audioPlayerEventChannel = eventChannel;
            _mockAudioEventStream(eventChannel);
            audioEventChannels.add(eventChannel);
          } else if (call.method == 'setSourceUrl') {
            networkSources++;
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
              await speechGate?.future;
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
        .setMockMethodCallHandler(backgroundChannel, null);
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

  Future<MobileBackgroundCoordinator> iosBackground({
    bool speech = false,
  }) async {
    final background = MobileBackgroundCoordinator(
      platform: TargetPlatform.iOS,
      channel: backgroundChannel,
    );
    await background.configure(
      MobileBackgroundSettings(backgroundSpeechEnabled: speech),
      await AppLocalizations.delegate.load(const Locale('en')),
    );
    addTearDown(background.dispose);
    return background;
  }

  test(
    'iOS default pauses speech and capture retains priority over resume',
    () async {
      final background = await iosBackground();
      final provider = TtsProvider(
        preferences: session.preferences,
        background: background,
      );
      background.pauseSpeech = provider.pause;
      addTearDown(provider.dispose);
      await _waitUntil(() => provider.isAvailable);
      background.didChangeAppLifecycleState(AppLifecycleState.paused);
      unawaited(provider.speakSystem('continue after capture'));
      await _waitUntil(() => provider.isPaused);
      expect(speakCallCount, 0);
      background.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await provider.resume();
      expect(speakCallCount, 1);
      await background.setAudioOwner('capture:2', true);
      expect(provider.isPaused, isTrue);
      await background.setAudioOwner('capture:old', false);
      await provider.resume();
      expect(speakCallCount, 1);
      expect(background.hasCaptureAudio, isTrue);
      await background.setAudioOwner('capture:2', false);
      await provider.resume();
      expect(speakCallCount, 2);
      await provider.stop();
      await background.flush();
      expect(audioOwners, isEmpty);
    },
  );

  test(
    'automatic system narration acknowledges cleanup and ownership before generation ends',
    () async {
      final background = await iosBackground(speech: true);
      background.didChangeAppLifecycleState(AppLifecycleState.paused);
      await background.start(
        id: 'generation',
        conversationId: 'chat',
        title: 'Test',
        cancel: () async {},
      );
      final provider = TtsProvider(
        preferences: session.preferences,
        background: background,
      );
      addTearDown(provider.dispose);
      await _waitUntil(() => provider.isAvailable);
      stopEntered = Completer<void>();
      stopGate = Completer<void>();
      speechGate = Completer<void>();
      var handedOff = false;
      final handoff = provider
          .speak('read the completed answer', waitForCompletion: false)
          .then((_) async {
            handedOff = true;
            await background.finish(
              'generation',
              BackgroundTaskOutcome.completed,
            );
          });
      await stopEntered!.future;
      await background.flush();
      expect(handedOff, isFalse);
      expect(background.activeTaskIds, {'generation'});
      expect(terminalAudioOwners, isEmpty);
      stopGate!.complete();
      await handoff.timeout(const Duration(seconds: 3));
      await _waitUntil(() => speakCallCount == 1);
      expect(speechGate!.isCompleted, isFalse);
      expect(background.activeTaskIds, isEmpty);
      expect(terminalAudioOwners.single, contains('speechBuffering'));
      expect(provider.playbackState.isActive, isTrue);
      speechGate!.complete();
      await _emitTtsCallback('speak.onComplete');
      await _waitUntil(() => !provider.isSpeaking);
      await background.flush();
      expect(audioOwners, isEmpty);
    },
  );

  test(
    'automatic network narration takes over before the server responds',
    () async {
      final background = await iosBackground(speech: true);
      background.didChangeAppLifecycleState(AppLifecycleState.paused);
      await background.start(
        id: 'generation',
        conversationId: 'chat',
        title: 'Test',
        cancel: () async {},
      );
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      final requested = Completer<void>();
      final response = Completer<void>();
      server.listen((request) async {
        await request.drain<void>();
        requested.complete();
        await response.future;
        request.response.headers.contentType = ContentType('audio', 'mpeg');
        request.response.add([1, 2, 3, 4]);
        await request.response.close();
      });
      final options = OpenAiTtsOptions(
        id: 'network',
        enabled: true,
        name: 'test',
        apiKey: '',
        baseUrl: 'http://${server.address.address}:${server.port}/v1',
        model: 'tts',
        voice: 'alloy',
      );
      await session.preferences.setString(
        'tts_services_v1',
        jsonEncode([options.toJson()]),
      );
      await session.preferences.setString(
        'tts_selected_service_id_v1',
        'network',
      );
      final provider = TtsProvider(
        preferences: session.preferences,
        background: background,
      );
      addTearDown(provider.dispose);
      await _waitUntil(() => provider.isAvailable);
      await provider
          .speak('read after network buffering', waitForCompletion: false)
          .timeout(const Duration(seconds: 3));
      await background.finish('generation', BackgroundTaskOutcome.completed);
      await requested.future;
      expect(terminalAudioOwners, [
        {'speechBuffering'},
      ]);
      expect(provider.playbackState.status, TtsPlaybackStatus.buffering);
      expect(networkSources, 0);
      expect(response.isCompleted, isFalse);
      await provider.pause();
      await background.flush();
      expect(audioOwners, isEmpty);
      response.complete();
      await provider.stop();
    },
  );

  test(
    'empty or disabled background narration does not retain execution',
    () async {
      final background = await iosBackground();
      background.didChangeAppLifecycleState(AppLifecycleState.paused);
      final provider = TtsProvider(
        preferences: session.preferences,
        background: background,
      );
      addTearDown(provider.dispose);
      await _waitUntil(() => provider.isAvailable);
      await provider.speak('```\ncode only\n```', waitForCompletion: false);
      await provider.speak(
        'background speech is off',
        waitForCompletion: false,
      );
      await background.flush();
      expect(audioOwners, isEmpty);
      expect(speakCallCount, 0);
      expect(provider.isPaused, isTrue);
      await provider.stop();
    },
  );

  test(
    'resuming a pending network request only holds the buffering lease',
    () async {
      final background = await iosBackground(speech: true);
      final provider = TtsProvider(
        preferences: session.preferences,
        background: background,
      );
      addTearDown(provider.dispose);
      await _waitUntil(() => provider.isAvailable);
      final directory = await Directory.systemTemp.createTemp(
        'kelivo-tts-resume',
      );
      final previousPaths = PathProviderPlatform.instance;
      PathProviderPlatform.instance = _FakePathProviderPlatform(directory.path);
      addTearDown(() async {
        PathProviderPlatform.instance = previousPaths;
        await directory.delete(recursive: true);
      });
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      final requested = Completer<void>();
      final response = Completer<void>();
      server.listen((request) async {
        await request.drain<void>();
        requested.complete();
        await response.future;
        request.response.headers.contentType = ContentType('audio', 'mpeg');
        request.response.add([1, 2, 3, 4]);
        await request.response.close();
      });
      unawaited(
        provider.speakWithNetworkService(
          OpenAiTtsOptions(
            enabled: true,
            name: 'test',
            apiKey: '',
            baseUrl: 'http://${server.address.address}:${server.port}/v1',
            model: 'tts',
            voice: 'alloy',
          ),
          'pause and resume before the server answers',
        ),
      );
      await requested.future;
      await provider.pause();
      await provider.resume();
      await background.flush();
      expect(networkResumes, 0);
      expect(networkSources, 0);
      expect(audioOwners, {'speechBuffering'});
      expect(provider.playbackState.status, TtsPlaybackStatus.buffering);

      response.complete();
      await _waitUntil(() => networkResumes > 0);
      expect(audioOwners, contains('speech'));
      expect(networkSources, 1);
      await provider.pause();
      await background.flush();
      expect(audioOwners, isEmpty);
      final resumesBefore = networkResumes;
      await provider.resume();
      expect(networkResumes, resumesBefore + 1);
      expect(provider.playbackState.status, TtsPlaybackStatus.playing);
      expect(audioOwners, contains('speech'));
      await provider.stop();
      await background.flush();
      expect(audioOwners, isEmpty);
    },
  );

  test(
    'late network audio waits through capture and does not restart after stop',
    () async {
      final background = await iosBackground(speech: true);
      final provider = TtsProvider(
        preferences: session.preferences,
        background: background,
      );
      background.pauseSpeech = provider.pause;
      addTearDown(provider.dispose);
      await _waitUntil(() => provider.isAvailable);
      final directory = await Directory.systemTemp.createTemp(
        'kelivo-tts-background',
      );
      final previousPaths = PathProviderPlatform.instance;
      PathProviderPlatform.instance = _FakePathProviderPlatform(directory.path);
      addTearDown(() async {
        PathProviderPlatform.instance = previousPaths;
        await directory.delete(recursive: true);
      });
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      final requested = Completer<void>();
      final response = Completer<void>();
      final answered = Completer<void>();
      server.listen((request) async {
        await request.drain<void>();
        requested.complete();
        await response.future;
        request.response.headers.contentType = ContentType('audio', 'mpeg');
        request.response.add([1, 2, 3, 4]);
        await request.response.close();
        answered.complete();
      });
      unawaited(
        provider.speakWithNetworkService(
          OpenAiTtsOptions(
            enabled: true,
            name: 'test',
            apiKey: '',
            baseUrl: 'http://${server.address.address}:${server.port}/v1',
            model: 'tts',
            voice: 'alloy',
          ),
          'wait for a network response',
        ),
      );
      await requested.future;
      rejectPause = true;
      await background.setAudioOwner('capture:1', true);
      background.didChangeAppLifecycleState(AppLifecycleState.paused);
      response.complete();
      await answered.future;
      await Future<void>.delayed(const Duration(milliseconds: 120));
      expect(networkSources, 0);
      expect(provider.isPaused, isTrue);
      await provider.resume();
      expect(networkSources, 0);
      await provider.stop();
      await background.setAudioOwner('capture:1', false);
      await Future<void>.delayed(const Duration(milliseconds: 120));
      expect(networkSources, 0);
      await background.flush();
      expect(audioOwners, isEmpty);
    },
  );

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
