import '../../../support/business_test_harness.dart';

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:provider/provider.dart';

import 'package:Kelivo/core/models/chat_input_data.dart';
import 'package:Kelivo/core/providers/asr_provider.dart';
import 'package:Kelivo/core/providers/assistant_provider.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/asr/asr_audio_capture.dart';
import 'package:Kelivo/core/services/asr/asr_service_options.dart';
import 'package:Kelivo/core/services/asr/system_asr_service.dart';
import 'package:Kelivo/features/home/widgets/chat_input_bar.dart';
import 'package:Kelivo/l10n/app_localizations.dart';

void main() {
  Widget harness({
    required SettingsProvider settings,
    required AsrProvider asr,
    required TextEditingController controller,
    ChatInputBarController? mediaController,
    String? modelId,
    Future<ChatInputSubmissionResult> Function(ChatInputData)? onSend,
    String? conversationId,
  }) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: settings),
        ChangeNotifierProvider.value(
          value: AssistantProvider(
            preferences: createBusinessTestPreferences(),
          ),
        ),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: ChatInputBar(
            conversationId: conversationId,
            controller: controller,
            mediaController: mediaController,
            asrProvider: asr,
            chatModelProviderKey: modelId == null ? null : 'Gemini',
            chatModelId: modelId,
            onSend: onSend ?? (_) async => ChatInputSubmissionResult.rejected,
          ),
        ),
      ),
    );
  }

  testWidgets('microphone is hidden until the user adds an ASR service', (
    tester,
  ) async {
    final settings = SettingsProvider(createBusinessTestPreferences());
    await settings.loaded;
    final asr = AsrProvider();
    final controller = TextEditingController();
    addTearDown(asr.dispose);
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      harness(settings: settings, asr: asr, controller: controller),
    );
    await tester.pump();

    expect(find.byTooltip('Voice input'), findsNothing);
  });

  testWidgets('system ASR replaces partials from a stable draft base', (
    tester,
  ) async {
    final settings = SettingsProvider(createBusinessTestPreferences());
    await settings.loaded;
    final option = SystemAsrOptions(id: 'system-test');
    await settings.setAsrServices(<AsrServiceOptions>[option]);
    final backend = _FakeSystemBackend();
    final asr = AsrProvider(systemService: SystemAsrService(backend: backend));
    final controller = TextEditingController(text: 'draft');
    addTearDown(asr.dispose);
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      harness(settings: settings, asr: asr, controller: controller),
    );
    await tester.tap(find.byTooltip('Voice input'));
    await tester.pump();

    backend.emitTranscript('hello', false);
    await tester.pump();
    expect(controller.text, 'draft hello');
    backend.emitTranscript('hello world', false);
    await tester.pump();
    expect(controller.text, 'draft hello world');

    await tester.tap(find.byTooltip('Stop and transcribe to input'));
    await tester.pumpAndSettle();
    expect(controller.text, 'draft hello world');
    expect(find.byTooltip('Voice input'), findsOneWidget);
  });

  testWidgets('cancelling ASR restores the exact original editing value', (
    tester,
  ) async {
    final settings = SettingsProvider(createBusinessTestPreferences());
    await settings.loaded;
    final option = SystemAsrOptions(id: 'system-test');
    await settings.setAsrServices(<AsrServiceOptions>[option]);
    final backend = _FakeSystemBackend();
    final asr = AsrProvider(systemService: SystemAsrService(backend: backend));
    final controller = TextEditingController(text: '保留内容')
      ..selection = const TextSelection(baseOffset: 1, extentOffset: 3);
    final original = controller.value;
    addTearDown(asr.dispose);
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      harness(settings: settings, asr: asr, controller: controller),
    );
    await tester.tap(find.byTooltip('Voice input'));
    await tester.pump();
    backend.emitTranscript('临时识别', false);
    await tester.pump();

    await tester.tap(find.byTooltip('Discard recording'));
    await tester.pumpAndSettle();
    expect(controller.value, original);
  });

  testWidgets('voice waveform advances on a steady 60 ms sampling clock', (
    tester,
  ) async {
    final settings = SettingsProvider(createBusinessTestPreferences());
    await settings.loaded;
    final option = SystemAsrOptions(id: 'system-test');
    await settings.setAsrServices(<AsrServiceOptions>[option]);
    final backend = _FakeSystemBackend();
    final asr = AsrProvider(systemService: SystemAsrService(backend: backend));
    final controller = TextEditingController();
    addTearDown(asr.dispose);
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      harness(settings: settings, asr: asr, controller: controller),
    );
    await tester.tap(find.byTooltip('Voice input'));
    await tester.pump();
    backend.emitSoundLevel(-12);
    await tester.pump();

    dynamic waveform = tester.widget(
      find.byKey(const ValueKey('voice-waveform')),
    );
    expect(waveform.levels, isEmpty);
    await tester.pump(const Duration(milliseconds: 65));
    waveform = tester.widget(find.byKey(const ValueKey('voice-waveform')));
    final firstCount = (waveform.levels as List<double>).length;
    expect(firstCount, greaterThan(0));
    final waveformPaint = find.descendant(
      of: find.byKey(const ValueKey('voice-waveform')),
      matching: find.byType(CustomPaint),
    );
    expect(waveformPaint, findsOneWidget);
    expect(tester.getSize(waveformPaint).width, greaterThan(0));
    expect(tester.getSize(waveformPaint).height, 32);

    await tester.pump(const Duration(milliseconds: 180));
    waveform = tester.widget(find.byKey(const ValueKey('voice-waveform')));
    expect((waveform.levels as List<double>).length, greaterThan(firstCount));

    await tester.tap(find.byTooltip('Discard recording'));
    await tester.pumpAndSettle();
  });

  testWidgets('local transcription shows a custom recognizing indicator', (
    tester,
  ) async {
    final settings = SettingsProvider(createBusinessTestPreferences());
    await settings.loaded;
    final option = SherpaOnnxAsrOptions(
      id: 'local-test',
      modelId: 'local-model',
    );
    await settings.setAsrServices(<AsrServiceOptions>[option]);
    final capture = _FakeAudioCapture();
    final transcription = Completer<String>();
    var transcriptionCalls = 0;
    final asr = AsrProvider(
      audioCaptureFactory: () => capture,
      localModelInstalledChecker: (_) async => true,
      localTranscriber: (_, _) {
        transcriptionCalls++;
        return transcription.future;
      },
    );
    await asr.refreshAvailability(option);
    final controller = TextEditingController();
    addTearDown(asr.dispose);
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      harness(settings: settings, asr: asr, controller: controller),
    );
    await tester.tap(find.byTooltip('Voice input'));
    await tester.pump();
    capture.add(_pcm16(6000));
    await tester.pump(const Duration(milliseconds: 65));

    expect(asr.soundLevel, greaterThan(0));
    final dynamic localWaveform = tester.widget(
      find.byKey(const ValueKey('voice-waveform')),
    );
    expect((localWaveform.levels as List<double>).last, greaterThan(0));
    final localWaveformPaint = find.descendant(
      of: find.byKey(const ValueKey('voice-waveform')),
      matching: find.byType(CustomPaint),
    );
    expect(tester.getSize(localWaveformPaint).width, greaterThan(0));
    expect(tester.getSize(localWaveformPaint).height, 32);

    await tester.tap(find.byTooltip('Stop and transcribe to input'));
    await tester.pump();

    expect(
      find.byKey(const ValueKey('voice-transcribing-indicator')),
      findsOneWidget,
    );
    expect(find.text('Recognizing…'), findsOneWidget);
    expect(transcriptionCalls, 1);

    await tester.tap(find.byTooltip('Stop and transcribe to input'));
    await tester.pump();
    expect(transcriptionCalls, 1);

    transcription.complete('local result');
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    for (var attempt = 0; attempt < 10 && controller.text.isEmpty; attempt++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.pump(const Duration(milliseconds: 200));

    expect(controller.text, 'local result');
    expect(
      find.byKey(const ValueKey('voice-transcribing-indicator')),
      findsNothing,
    );
  });

  _audioRecordingTests(harness);
}

void _audioRecordingTests(
  Widget Function({
    required SettingsProvider settings,
    required AsrProvider asr,
    required TextEditingController controller,
    ChatInputBarController? mediaController,
    String? modelId,
    Future<ChatInputSubmissionResult> Function(ChatInputData)? onSend,
    String? conversationId,
  })
  harness,
) {
  late Directory tempDir;
  late PathProviderPlatform previousPathProvider;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('kelivo_voice_audio_');
    previousPathProvider = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _FakePathProviderPlatform(tempDir.path);
  });

  tearDown(() async {
    PathProviderPlatform.instance = previousPathProvider;
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  Future<List<DocumentAttachment>> waitForDocuments(
    WidgetTester tester,
    ChatInputBarController media,
  ) async {
    // File writes need real async time; allow for a loaded test machine.
    for (var attempt = 0; attempt < 100; attempt++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
      final docs = media.snapshotInput('').documents;
      if (docs.isNotEmpty) return docs;
    }
    return const [];
  }

  testWidgets('audio models get a recording microphone without ASR', (
    tester,
  ) async {
    final settings = SettingsProvider(createBusinessTestPreferences());
    await settings.loaded;
    final capture = _FakeAudioCapture();
    final asr = AsrProvider(audioCaptureFactory: () => capture);
    final controller = TextEditingController(text: 'draft');
    final media = ChatInputBarController();
    addTearDown(asr.dispose);
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      harness(
        settings: settings,
        asr: asr,
        controller: controller,
        mediaController: media,
      ),
    );
    expect(find.byTooltip('Voice input'), findsNothing);

    await tester.pumpWidget(
      harness(
        settings: settings,
        asr: asr,
        controller: controller,
        mediaController: media,
        modelId: 'gemini-2.5-flash',
      ),
    );
    await tester.tap(find.byTooltip('Voice input'));
    await tester.pump();
    capture.add(Uint8List(16000));
    await tester.pump();

    expect(find.byTooltip('Send recording'), findsOneWidget);
    await tester.tap(find.byTooltip('Stop and attach as audio'));
    final docs = await waitForDocuments(tester, media);

    expect(docs, hasLength(1));
    expect(docs.single.mime, 'audio/wav');
    expect(docs.single.fileName, startsWith('voice_'));
    expect(File(docs.single.path).lengthSync(), 44 + 16000);
    expect(controller.text, 'draft');
  });

  testWidgets('ASR recordings can end as audio and keep the draft text', (
    tester,
  ) async {
    final settings = SettingsProvider(createBusinessTestPreferences());
    await settings.loaded;
    final option = SherpaOnnxAsrOptions(
      id: 'local-test',
      modelId: 'local-model',
    );
    await settings.setAsrServices(<AsrServiceOptions>[option]);
    final capture = _FakeAudioCapture();
    var transcriptionCalls = 0;
    final asr = AsrProvider(
      audioCaptureFactory: () => capture,
      localModelInstalledChecker: (_) async => true,
      localTranscriber: (_, _) async {
        transcriptionCalls++;
        return 'unused';
      },
    );
    await asr.refreshAvailability(option);
    final controller = TextEditingController(text: 'draft');
    final media = ChatInputBarController();
    addTearDown(asr.dispose);
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      harness(
        settings: settings,
        asr: asr,
        controller: controller,
        mediaController: media,
        modelId: 'gemini-2.5-flash',
      ),
    );
    await tester.tap(find.byTooltip('Voice input'));
    await tester.pump();
    capture.add(Uint8List(16000));
    await tester.pump();

    expect(find.byTooltip('Stop and transcribe to input'), findsOneWidget);
    await tester.tap(find.byTooltip('Stop and attach as audio'));
    final docs = await waitForDocuments(tester, media);

    expect(docs.single.mime, 'audio/wav');
    expect(transcriptionCalls, 0);
    expect(controller.text, 'draft');
  });

  testWidgets('a recording cancelled while finishing is never sent', (
    tester,
  ) async {
    final settings = SettingsProvider(createBusinessTestPreferences());
    await settings.loaded;
    final capture = _FakeAudioCapture();
    final asr = AsrProvider(audioCaptureFactory: () => capture);
    final controller = TextEditingController(text: 'draft');
    final media = ChatInputBarController();
    var sends = 0;
    addTearDown(asr.dispose);
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      harness(
        settings: settings,
        asr: asr,
        controller: controller,
        mediaController: media,
        modelId: 'gemini-2.5-flash',
        onSend: (_) async {
          sends++;
          return ChatInputSubmissionResult.sent;
        },
      ),
    );
    await tester.tap(find.byTooltip('Voice input'));
    await tester.pump();
    capture.add(Uint8List(16000));
    await tester.pump();

    capture.stopGate = Completer<void>();
    await tester.tap(find.byTooltip('Send recording'));
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    controller.text = 'typed after cancel';
    capture.stopGate!.complete();
    await waitForDocuments(tester, media);

    expect(sends, 0);
    expect(media.snapshotInput('').documents, isEmpty);
    expect(controller.text, 'typed after cancel');
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    // Let the resume re-enable and tooltip timers run out.
    await tester.pump(const Duration(seconds: 2));
  });

  for (final asAudio in [false, true]) {
    testWidgets('switching conversation while finishing keeps the new draft '
        '(${asAudio ? 'audio' : 'text'})', (tester) async {
      final settings = SettingsProvider(createBusinessTestPreferences());
      await settings.loaded;
      final option = SherpaOnnxAsrOptions(
        id: 'local-test',
        modelId: 'local-model',
      );
      await settings.setAsrServices(<AsrServiceOptions>[option]);
      final capture = _FakeAudioCapture();
      final transcription = Completer<String>();
      final asr = AsrProvider(
        audioCaptureFactory: () => capture,
        localModelInstalledChecker: (_) async => true,
        localTranscriber: (_, _) => transcription.future,
      );
      await asr.refreshAvailability(option);
      final controller = TextEditingController(text: 'draft A');
      final media = ChatInputBarController();
      var sends = 0;
      addTearDown(asr.dispose);
      addTearDown(controller.dispose);
      Widget build(String conversationId) => harness(
        settings: settings,
        asr: asr,
        controller: controller,
        mediaController: media,
        modelId: 'gemini-2.5-flash',
        conversationId: conversationId,
        onSend: (_) async {
          sends++;
          return ChatInputSubmissionResult.sent;
        },
      );

      await tester.pumpWidget(build('A'));
      await tester.tap(find.byTooltip('Voice input'));
      await tester.pump();
      capture.add(Uint8List(16000));
      await tester.pump();

      if (asAudio) capture.stopGate = Completer<void>();
      await tester.tap(
        find.byTooltip(
          asAudio ? 'Stop and attach as audio' : 'Transcribe and send',
        ),
      );
      await tester.pump();
      await tester.pumpWidget(build('B'));
      controller.text = 'draft B';
      if (asAudio) {
        capture.stopGate!.complete();
      } else {
        transcription.complete('words from A');
      }
      await waitForDocuments(tester, media);

      expect(sends, 0);
      expect(controller.text, 'draft B');
      expect(media.snapshotInput('').documents, isEmpty);
      expect(find.byTooltip('Voice input'), findsOneWidget);
      // The abandoned finish still runs out its 2 s capture-done timeout.
      await tester.pump(const Duration(seconds: 3));
    });
  }

  testWidgets('a failed start throwing late keeps the retried recording', (
    tester,
  ) async {
    final settings = SettingsProvider(createBusinessTestPreferences());
    await settings.loaded;
    final denied = _FakeAudioCapture(permission: false)
      ..disposeGate = Completer<void>();
    final granted = _FakeAudioCapture();
    final captures = [denied, granted];
    final asr = AsrProvider(audioCaptureFactory: () => captures.removeAt(0));
    final controller = TextEditingController(text: 'draft');
    addTearDown(asr.dispose);
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      harness(
        settings: settings,
        asr: asr,
        controller: controller,
        modelId: 'gemini-2.5-flash',
      ),
    );
    await tester.tap(find.byTooltip('Voice input'));
    await tester.pump();
    // The failure is published (and cleared) at once; its cleanup and the
    // start's throw are still pending.
    expect(asr.isActive, isFalse);
    await tester.tap(find.byTooltip('Voice input'));
    await tester.pump();
    expect(asr.isListening, isTrue);

    denied.disposeGate!.complete();
    await tester.pump();
    await tester.pump();

    expect(asr.isListening, isTrue);
    expect(find.byTooltip('Send recording'), findsOneWidget);
    expect(controller.text, 'draft');
    await tester.tap(find.byTooltip('Discard recording'));
    // Let the failure notice run out.
    await tester.pump(const Duration(seconds: 10));
  });

  testWidgets('system ASR offers no audio option', (tester) async {
    final settings = SettingsProvider(createBusinessTestPreferences());
    await settings.loaded;
    await settings.setAsrServices(<AsrServiceOptions>[
      SystemAsrOptions(id: 'system-test'),
    ]);
    final asr = AsrProvider(
      systemService: SystemAsrService(backend: _FakeSystemBackend()),
    );
    final controller = TextEditingController();
    addTearDown(asr.dispose);
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      harness(
        settings: settings,
        asr: asr,
        controller: controller,
        modelId: 'gemini-2.5-flash',
      ),
    );
    await tester.tap(find.byTooltip('Voice input'));
    await tester.pump();

    expect(find.byTooltip('Stop and transcribe to input'), findsOneWidget);
    expect(find.byTooltip('Stop and attach as audio'), findsNothing);
    await tester.tap(find.byTooltip('Discard recording'));
    await tester.pumpAndSettle();
  });
}

class _FakePathProviderPlatform extends PathProviderPlatform {
  _FakePathProviderPlatform(this.path);

  final String path;

  @override
  Future<String?> getApplicationDocumentsPath() async => path;

  @override
  Future<String?> getApplicationSupportPath() async => path;
}

final class _FakeSystemBackend implements SystemAsrBackend {
  void Function(String status)? _onStatus;
  SystemAsrTranscriptCallback? _onTranscript;
  SystemAsrSoundLevelCallback? _onSoundLevel;

  void emitTranscript(String text, bool isFinal) {
    _onTranscript?.call(text, isFinal);
  }

  void emitSoundLevel(double level) {
    _onSoundLevel?.call(level);
  }

  @override
  Future<bool> initialize({
    required SystemAsrErrorCallback onError,
    required void Function(String status) onStatus,
  }) async {
    _onStatus = onStatus;
    return true;
  }

  @override
  Future<List<SystemAsrLocale>> locales() async => const <SystemAsrLocale>[];

  @override
  Future<SystemAsrLocale?> systemLocale() async => null;

  @override
  Future<void> listen({
    required String? localeId,
    required Duration listenFor,
    required Duration pauseFor,
    required SystemAsrTranscriptCallback onTranscript,
    required SystemAsrSoundLevelCallback onSoundLevel,
  }) async {
    _onTranscript = onTranscript;
    _onSoundLevel = onSoundLevel;
    _onStatus?.call('listening');
  }

  @override
  Future<void> stop() async {
    _onTranscript?.call('hello world', true);
    _onStatus?.call('done');
  }

  @override
  Future<void> cancel() async {
    _onStatus?.call('done');
  }
}

final class _FakeAudioCapture implements AsrAudioCapture {
  final StreamController<Uint8List> _controller =
      StreamController<Uint8List>.broadcast();
  _FakeAudioCapture({this.permission = true});

  final bool permission;
  Completer<void>? stopGate;
  Completer<void>? disposeGate;

  void add(Uint8List chunk) => _controller.add(chunk);

  @override
  Future<bool> hasPermission() async => permission;

  @override
  Future<Stream<Uint8List>> start({required int sampleRate}) async =>
      _controller.stream;

  @override
  Future<void> stop() async {
    await stopGate?.future;
    if (!_controller.isClosed) await _controller.close();
  }

  @override
  Future<void> cancel() async {
    if (!_controller.isClosed) await _controller.close();
  }

  @override
  Future<void> dispose() async {
    await disposeGate?.future;
    if (!_controller.isClosed) await _controller.close();
  }
}

Uint8List _pcm16(int value) {
  final result = Uint8List(64);
  final data = ByteData.sublistView(result);
  for (var offset = 0; offset < result.length; offset += 2) {
    data.setInt16(offset, value, Endian.little);
  }
  return result;
}
