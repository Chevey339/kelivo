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
  var rejectNextSource = false;
  Completer<void>? prepareGate;
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
    rejectNextSource = false;
    prepareGate = null;
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
          } else if (call.method == 'seek') {
            scheduleMicrotask(
              () => _emitAudioEvent(eventChannel, {
                'event': 'audio.onSeekComplete',
              }),
            );
          } else if (call.method == 'setSourceUrl') {
            networkSources++;
            await prepareGate?.future;
            if (rejectNextSource) {
              rejectNextSource = false;
              scheduleMicrotask(() => _emitAudioError(eventChannel));
              return null;
            }
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

  test(
    'prepared UI text reaches system TTS and replay without being stripped',
    () async {
      final provider = TtsProvider(preferences: session.preferences);
      addTearDown(provider.dispose);
      await _waitUntil(() => provider.isAvailable);
      const text = '-3 `literal value` *times* [data](local)';
      unawaited(provider.speakSystem(text, plainText: true));
      await _waitUntil(() => spokenTexts.isNotEmpty);
      expect(spokenTexts.single, text);
      await _emitTtsCallback('speak.onComplete');
      await _waitUntil(
        () => provider.playbackState.status == TtsPlaybackStatus.ended,
      );
      unawaited(provider.replay());
      await _waitUntil(() => spokenTexts.length == 2);
      expect(spokenTexts, [text, text]);
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

  for (final kind in [NetworkTtsKind.openai, NetworkTtsKind.mimo]) {
    for (final replaceSession in [false, true]) {
      test(
        '${kind.name} prefetch cancellation is handled after '
        '${replaceSession ? 'starting another session' : 'stopping'}',
        () async {
          final provider = TtsProvider(preferences: session.preferences);
          addTearDown(provider.dispose);
          await _waitUntil(() => provider.isAvailable);
          final requests = <HttpRequest>[];
          final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
          addTearDown(() => server.close(force: true));
          server.listen((request) async {
            await request.drain<void>();
            requests.add(request);
          });
          final baseUrl = 'http://${server.address.address}:${server.port}/v1';
          final TtsServiceOptions service = kind == NetworkTtsKind.mimo
              ? MimoTtsOptions(
                  enabled: true,
                  name: 'test',
                  apiKey: '',
                  baseUrl: baseUrl,
                  model: 'mimo-v2.5-tts',
                  voice: 'mimo_default',
                )
              : OpenAiTtsOptions(
                  enabled: true,
                  name: 'test',
                  apiKey: '',
                  baseUrl: baseUrl,
                  model: 'tts',
                  voice: 'alloy',
                );
          unawaited(
            provider.speakWithNetworkService(
              service,
              List.filled(650, 'a').join(),
            ),
          );
          await _waitUntil(() => requests.length == 3);

          if (replaceSession) {
            await provider.speak(
              'replacement session',
              waitForCompletion: false,
            );
            await _waitUntil(
              () => provider.playbackState.status == TtsPlaybackStatus.playing,
            );
          } else {
            await provider.stop();
          }
          for (final request in requests) {
            request.response.add([1, 2, 3, 4]);
            await request.response.close();
          }
          // Let the cancelled synthesis futures settle, including the two
          // prefetched chunks that the playback queue will never await.
          await Future<void>.delayed(const Duration(milliseconds: 100));
          expect(networkSources, 0);
          expect(provider.error, isNull);
          expect(
            provider.playbackState.status,
            replaceSession ? TtsPlaybackStatus.playing : TtsPlaybackStatus.idle,
          );
          await provider.stop();
        },
      );
    }
  }

  test('prefetch failures remain available to the playback queue', () async {
    final directory = await Directory.systemTemp.createTemp(
      'kelivo_tts_prefetch_error_',
    );
    final previousPaths = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _FakePathProviderPlatform(directory.path);
    addTearDown(() async {
      PathProviderPlatform.instance = previousPaths;
      await directory.delete(recursive: true);
    });
    final provider = TtsProvider(preferences: session.preferences);
    addTearDown(provider.dispose);
    await _waitUntil(() => provider.isAvailable);
    final requests = <String, HttpRequest>{};
    var requestCount = 0;
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    server.listen((request) async {
      final body = jsonDecode(await utf8.decoder.bind(request).join()) as Map;
      requestCount++;
      requests[(body['input'] as String)[0]] = request;
    });
    final playback = provider.speakWithNetworkService(
      OpenAiTtsOptions(
        enabled: true,
        name: 'test',
        apiKey: '',
        baseUrl: 'http://${server.address.address}:${server.port}/v1',
        model: 'tts',
        voice: 'alloy',
      ),
      ['a', 'b', 'c'].map((letter) => List.filled(220, letter).join()).join(),
    );
    await _waitUntil(() => requests.length == 3);
    for (final letter in ['b', 'c']) {
      requests[letter]!.response
        ..statusCode = HttpStatus.serviceUnavailable
        ..write('temporary provider failure');
      await requests[letter]!.response.close();
    }
    // The future must handle an error even before its chunk is consumed.
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(provider.playbackState.status, TtsPlaybackStatus.buffering);
    expect(provider.error, isNull);

    requests['a']!.response.add([1, 2, 3, 4]);
    await requests['a']!.response.close();
    await _waitUntil(
      () => provider.playbackState.status == TtsPlaybackStatus.playing,
    );
    await _emitAudioEvent(audioPlayerEventChannel!, {
      'event': 'audio.onComplete',
    });
    await playback;
    expect(provider.playbackState.status, TtsPlaybackStatus.error);
    expect(provider.error, contains('503'));
    expect(provider.error, contains('temporary provider failure'));
    expect(networkSources, 1);
    expect(requestCount, 3);
  });

  test(
    'prepared UI values reach network TTS unchanged on first play and replay',
    () async {
      final previousPaths = PathProviderPlatform.instance;
      final directory = await Directory.systemTemp.createTemp(
        'kelivo_genui_speech_',
      );
      PathProviderPlatform.instance = _FakePathProviderPlatform(directory.path);
      addTearDown(() async {
        PathProviderPlatform.instance = previousPaths;
        await directory.delete(recursive: true);
      });
      final inputs = <String>[];
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      server.listen((request) async {
        final body = jsonDecode(await utf8.decoder.bind(request).join()) as Map;
        inputs.add(body['input'] as String);
        request.response.headers.contentType = ContentType('audio', 'mpeg');
        request.response.add([1, 2, 3, 4]);
        await request.response.close();
      });
      final provider = TtsProvider(preferences: session.preferences);
      addTearDown(provider.dispose);
      await _waitUntil(() => provider.isAvailable);
      const text = '-3 `kept` [data](https://example.invalid) _unit_';
      final playback = provider.speakWithNetworkService(
        OpenAiTtsOptions(
          enabled: true,
          name: 'Loopback',
          apiKey: '',
          baseUrl: 'http://${server.address.address}:${server.port}/v1',
          model: 'test',
          voice: 'alloy',
        ),
        text,
        plainText: true,
      );
      await _waitUntil(
        () => provider.playbackState.status == TtsPlaybackStatus.playing,
      );
      await _emitAudioEvent(audioPlayerEventChannel!, {
        'event': 'audio.onComplete',
      });
      await playback;
      expect(inputs, [text]);
      final replay = provider.replay();
      await _waitUntil(
        () =>
            inputs.length == 2 &&
            provider.playbackState.status == TtsPlaybackStatus.playing,
      );
      await _emitAudioEvent(audioPlayerEventChannel!, {
        'event': 'audio.onComplete',
      });
      await replay;
      expect(inputs, [text, text]);
    },
  );

  test(
    'cached narration survives message changes and a fresh player',
    () async {
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

      final requests = <(String, String)>[];
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((request) async {
        final body = jsonDecode(await utf8.decoder.bind(request).join()) as Map;
        requests.add((body['input'] as String, body['voice'] as String));
        request.response.add([requests.length]);
        await request.response.close();
      });
      addTearDown(() => server.close(force: true));

      var provider = TtsProvider(preferences: session.preferences);
      addTearDown(() => provider.dispose());
      await _waitUntil(() => provider.isAvailable);

      expect(provider.cacheNetworkAudioForReplay, isFalse);
      await provider.setCacheNetworkAudioForReplay(true);
      expect(
        session.preferences.getBool('tts_cache_network_audio_for_replay_v1'),
        isTrue,
      );

      final service = OpenAiTtsOptions(
        id: 'narration',
        enabled: true,
        name: 'Local TTS',
        apiKey: 'test-key',
        baseUrl: 'http://${server.address.address}:${server.port}/v1',
        model: 'test-model',
        voice: 'alloy',
      );
      Future<void> selectVoice(
        String voice, {
        String? id,
        String? apiKey,
      }) async {
        await session.preferences.setString(
          'tts_services_v1',
          jsonEncode([
            {
              ...service.toJson(),
              'voice': voice,
              'id': id ?? service.id,
              'apiKey': apiKey ?? service.apiKey,
            },
          ]),
        );
        await session.preferences.setString(
          'tts_selected_service_id_v1',
          id ?? service.id,
        );
      }

      Future<void> play(Future<void> playback, int expectedAudio) async {
        await _waitUntil(
          () => provider.playbackState.status == TtsPlaybackStatus.playing,
        );
        await _emitAudioEvent(audioPlayerEventChannel!, {
          'event': 'audio.onComplete',
        });
        await playback;
        expect(provider.playbackState.status, TtsPlaybackStatus.ended);
        final audio = await provider.synthesizeAllAndCollect();
        expect(audio?.$1, [expectedAudio]);
        expect(audio?.$2, 'mp3');
      }

      await selectVoice('alloy');
      await play(provider.speak('first'), 1);
      await selectVoice('alloy', id: 'equivalent-profile');
      final firstReplay = provider.togglePause();
      await play(provider.togglePause(), 1);
      await firstReplay;
      expect(spokenTexts, isEmpty);
      await play(provider.speak('first'), 1);
      await provider.stop();
      await play(provider.speak('second'), 2);
      await play(provider.speak('first'), 1);

      await provider.stop();
      provider.dispose();
      provider = TtsProvider(preferences: session.preferences);
      await _waitUntil(() => provider.isAvailable);
      expect(provider.cacheNetworkAudioForReplay, isTrue);
      await play(provider.speak('first'), 1);
      await selectVoice('nova');
      await play(provider.speak('first'), 3);
      await selectVoice('alloy');
      await play(provider.speak('first'), 1);
      await provider.setCacheNetworkAudioForReplay(false);
      await play(provider.togglePause(), 4);
      await play(provider.speak('first'), 5);
      await provider.setCacheNetworkAudioForReplay(true);
      expect((await provider.synthesizeAllAndCollect())?.$1, [5]);
      await Directory(
        '${tempDirectory.path}/tts_replay',
      ).delete(recursive: true);
      await play(provider.speak('first'), 5);
      await provider.stop();
      await play(provider.speak('first'), 5);
      await provider.stop();
      await Directory(
        '${tempDirectory.path}/tts_replay',
      ).delete(recursive: true);
      await play(provider.speak('first'), 6);
      await selectVoice('alloy', apiKey: 'second-account');
      await play(provider.speak('first'), 7);
      expect(requests, [
        ('first', 'alloy'),
        ('second', 'alloy'),
        ('first', 'nova'),
        ('first', 'alloy'),
        ('first', 'alloy'),
        ('first', 'alloy'),
        ('first', 'alloy'),
      ]);
    },
  );

  test('replay shares pending chunks and retries only failed audio', () async {
    final oldPaths = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _FakePathProviderPlatform(
      harness.directory.path,
    );
    addTearDown(() => PathProviderPlatform.instance = oldPaths);
    final attempts = <String, int>{};
    final attemptedReplay = Completer<void>();
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    server.listen((request) async {
      final body = jsonDecode(await utf8.decoder.bind(request).join()) as Map;
      final letter = (body['input'] as String)[0];
      final attempt = attempts.update(letter, (n) => n + 1, ifAbsent: () => 1);
      if (letter == 'a') await attemptedReplay.future;
      if (letter == 'b' && attempt == 1) {
        request.response.statusCode = HttpStatus.serviceUnavailable;
      } else {
        request.response.add(letter.codeUnits);
      }
      await request.response.close();
    });
    final provider = TtsProvider(preferences: session.preferences);
    addTearDown(provider.dispose);
    await _waitUntil(() => provider.isAvailable);
    await provider.setCacheNetworkAudioForReplay(true);
    final service = OpenAiTtsOptions(
      enabled: true,
      name: 'Loopback',
      apiKey: '',
      baseUrl: 'http://${server.address.address}:${server.port}/v1',
      model: 'tts',
      voice: 'alloy',
    );
    final text = ['a', 'a', 'b'].map((letter) => letter * 220).join();
    final first = provider.speakWithNetworkService(service, text);
    await _waitUntil(() => attempts.containsKey('b'));
    final replacement = provider.speakWithNetworkService(service, text);
    await first;
    await _waitUntil(() => attempts['b'] == 2);
    attemptedReplay.complete();
    for (var i = 0; i < 3; i++) {
      await _waitUntil(
        () =>
            provider.playbackState.status == TtsPlaybackStatus.playing &&
            provider.playbackState.currentChunkIndex == i,
      );
      await _emitAudioEvent(audioPlayerEventChannel!, {
        'event': 'audio.onComplete',
      });
    }
    await replacement;
    expect(provider.playbackState.status, TtsPlaybackStatus.ended);
    expect((await provider.synthesizeAllAndCollect())?.$1, 'aab'.codeUnits);
    expect(attempts, {'a': 1, 'b': 2});
  });

  Future<(TtsProvider, OpenAiTtsOptions)> networkPlayer(
    Future<void> Function(HttpRequest request) respond, {
    bool cache = true,
  }) async {
    final paths = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _FakePathProviderPlatform(
      harness.directory.path,
    );
    addTearDown(() => PathProviderPlatform.instance = paths);
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    server.listen(respond);
    final provider = TtsProvider(preferences: session.preferences);
    addTearDown(provider.dispose);
    await _waitUntil(() => provider.isAvailable);
    await provider.setCacheNetworkAudioForReplay(cache);
    return (
      provider,
      OpenAiTtsOptions(
        enabled: true,
        name: 'Loopback',
        apiKey: '',
        baseUrl: 'http://${server.address.address}:${server.port}/v1',
        model: 'tts',
        voice: 'alloy',
      ),
    );
  }

  test('a rejected audio source is regenerated on the next playback', () async {
    var requests = 0;
    final (provider, service) = await networkPlayer((request) async {
      await request.drain<void>();
      request.response.add([++requests]);
      await request.response.close();
    });
    rejectNextSource = true;
    await provider.speakWithNetworkService(service, 'hello');
    expect(provider.playbackState.status, TtsPlaybackStatus.error);
    final replay = provider.speakWithNetworkService(service, 'hello');
    await _waitUntil(
      () => provider.playbackState.status == TtsPlaybackStatus.playing,
    );
    await _emitAudioError(
      audioPlayerEventChannel!,
      details: 'MEDIA_ERROR_SERVER_DIED',
    );
    await replay;
    expect(provider.playbackState.status, TtsPlaybackStatus.error);
    final recovered = provider.speakWithNetworkService(service, 'hello');
    await _waitUntil(
      () => provider.playbackState.status == TtsPlaybackStatus.playing,
    );
    await _emitAudioEvent(audioPlayerEventChannel!, {
      'event': 'audio.onComplete',
    });
    await recovered;
    expect((await provider.synthesizeAllAndCollect())?.$1, [2]);
    expect(requests, 2);
  });

  test(
    'stop releases a stalled cached request so replay can start fresh',
    () async {
      var requests = 0;
      final started = Completer<void>();
      final (provider, service) = await networkPlayer((request) async {
        await request.drain<void>();
        if (++requests == 1) {
          started.complete();
          return;
        }
        request.response.add([42]);
        await request.response.close();
      });
      final first = provider.speakWithNetworkService(service, 'hello');
      await started.future;
      await provider.stop();
      await first;
      final replay = provider.speakWithNetworkService(service, 'hello');
      await _waitUntil(
        () => provider.playbackState.status == TtsPlaybackStatus.playing,
      );
      await _emitAudioEvent(audioPlayerEventChannel!, {
        'event': 'audio.onComplete',
      });
      await replay;
      expect((await provider.synthesizeAllAndCollect())?.$1, [42]);
      expect(requests, 2);
    },
  );

  test('stopping cached Azure narration cancels its pending retry', () async {
    var requests = 0;
    final throttled = Completer<void>();
    final (provider, endpoint) = await networkPlayer((request) async {
      await request.drain<void>();
      requests++;
      request.response.statusCode = HttpStatus.serviceUnavailable;
      await request.response.close();
      if (!throttled.isCompleted) throttled.complete();
    });
    final first = provider.speakWithNetworkService(
      AzureTtsOptions(
        enabled: true,
        name: 'Azure',
        apiKey: '',
        baseUrl: endpoint.baseUrl,
        language: 'en-US',
        voice: 'voice',
      ),
      'hello',
    );
    await throttled.future;
    await provider.stop();
    await first;
    await Future<void>.delayed(const Duration(milliseconds: 350));
    expect(requests, 1);
  });

  test('seeking during preparation plays the target chunk once', () async {
    final (provider, service) = await networkPlayer((request) async {
      await request.drain<void>();
      request.response.add([1]);
      await request.response.close();
    });
    prepareGate = Completer<void>();
    final speech = provider.speakWithNetworkService(
      service,
      'a' * 220 + 'b' * 220,
    );
    await _waitUntil(() => networkSources == 1);
    await provider.seekTo(const Duration(seconds: 45));
    prepareGate!.complete();
    await _waitUntil(
      () =>
          networkSources == 2 &&
          provider.playbackState.status == TtsPlaybackStatus.playing,
    );
    await _emitAudioEvent(audioPlayerEventChannel!, {
      'event': 'audio.onComplete',
    });
    await speech.timeout(const Duration(seconds: 2));
    expect(networkSources, 2);
    expect(provider.playbackState.status, TtsPlaybackStatus.ended);
  });

  test('export recovers a prefetched file cleared during playback', () async {
    final attempts = <String, int>{};
    final (provider, service) = await networkPlayer((request) async {
      final body = jsonDecode(await utf8.decoder.bind(request).join()) as Map;
      final letter = (body['input'] as String)[0];
      final count = attempts.update(letter, (n) => n + 1, ifAbsent: () => 1);
      if (letter == 'b' && count == 2) {
        request.response.statusCode = HttpStatus.serviceUnavailable;
      } else {
        request.response.add(letter.codeUnits);
      }
      await request.response.close();
    });
    final speech = provider.speakWithNetworkService(
      service,
      'a' * 220 + 'b' * 220,
    );
    await _waitUntil(
      () => provider.playbackState.status == TtsPlaybackStatus.playing,
    );
    await provider.pause();
    expect((await provider.synthesizeAllAndCollect())?.$1, 'ab'.codeUnits);
    await Directory(
      '${harness.directory.path}/tts_replay',
    ).delete(recursive: true);
    await expectLater(
      provider.synthesizeAllAndCollect(),
      throwsA(predicate((e) => e.toString().contains('503'))),
    );
    expect((await provider.synthesizeAllAndCollect())?.$1, 'ab'.codeUnits);
    expect(attempts, {'a': 2, 'b': 3});
    await provider.stop();
    await speech;
  });

  test(
    'a paused export retries only its failed chunk and releases temporary files',
    () async {
      final attempts = <String, int>{};
      final (provider, service) = await networkPlayer((request) async {
        final body = jsonDecode(await utf8.decoder.bind(request).join()) as Map;
        final letter = (body['input'] as String)[0];
        final count = attempts.update(letter, (n) => n + 1, ifAbsent: () => 1);
        if (letter == 'd' && count == 1) {
          request.response.statusCode = HttpStatus.serviceUnavailable;
        } else {
          request.response.add(letter.codeUnits);
        }
        await request.response.close();
      }, cache: false);
      final speech = provider.speakWithNetworkService(
        service,
        ['a', 'b', 'c', 'd'].map((ch) => ch * 220).join(),
      );
      await _waitUntil(
        () => provider.playbackState.status == TtsPlaybackStatus.playing,
      );
      await provider.pause();
      await expectLater(
        provider.synthesizeAllAndCollect(),
        throwsA(predicate((e) => e.toString().contains('503'))),
      );
      expect((await provider.synthesizeAllAndCollect())?.$1, 'abcd'.codeUnits);
      expect(attempts, {'a': 1, 'b': 1, 'c': 1, 'd': 2});
      stopEntered = Completer<void>();
      stopGate = Completer<void>();
      final stopping = provider.stop();
      await stopEntered!.future;
      expect(await provider.synthesizeAllAndCollect(), isNull);
      stopGate!.complete();
      await stopping;
      await speech;
      expect(
        harness.directory.listSync().where(
          (file) => file.path.endsWith('.mp3'),
        ),
        isEmpty,
      );
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

Future<void> _emitAudioEvent(String channel, Map<String, dynamic> event) async {
  final data = const StandardMethodCodec().encodeSuccessEnvelope(event);
  final completer = Completer<void>();
  await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .handlePlatformMessage(channel, data, (_) => completer.complete());
  await completer.future;
}

Future<void> _emitAudioError(
  String channel, {
  String details = 'MEDIA_ERROR_MALFORMED',
}) async {
  final data = const StandardMethodCodec().encodeErrorEnvelope(
    code: 'AndroidAudioError',
    message: 'MediaPlayer error',
    details: details,
  );
  await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .handlePlatformMessage(channel, data, (_) {});
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

  @override
  Future<String?> getApplicationCachePath() async => path;
}
