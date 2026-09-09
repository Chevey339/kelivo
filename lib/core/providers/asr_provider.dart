import 'dart:async';
import 'dart:typed_data';

import '../services/mobile_background.dart';

import 'package:flutter/foundation.dart';

import '../services/asr/asr_audio_capture.dart';
import '../services/asr/asr_service_options.dart';
import '../services/asr/cloud_asr_service.dart';
import '../services/asr/sherpa_asr_service.dart';
import '../services/asr/system_asr_service.dart';
import 'settings_provider.dart';

enum AsrSessionState { idle, connecting, listening, transcribing, error }

typedef AsrAudioCaptureFactory = AsrAudioCapture Function();
typedef CloudAsrSessionStarter =
    Future<CloudAsrSession> Function(AsrServiceOptions options);
typedef LocalAsrTranscriber =
    Future<String> Function(SherpaOnnxAsrOptions options, Uint8List pcm16);
typedef LocalModelInstalledChecker = Future<bool> Function(String modelId);

/// Coordinates microphone capture with the selected system, local, or cloud
/// recognizer. Settings own configuration; this provider owns one live session.
class AsrProvider extends ChangeNotifier {
  AsrProvider({
    SettingsProvider? settingsProvider,
    SystemAsrService? systemService,
    CloudAsrService? cloudService,
    SherpaAsrService? sherpaService,
    AsrAudioCaptureFactory? audioCaptureFactory,
    CloudAsrSessionStarter? cloudSessionStarter,
    LocalAsrTranscriber? localTranscriber,
    LocalModelInstalledChecker? localModelInstalledChecker,
  }) : _settingsProvider = settingsProvider,
       _systemService = systemService ?? SystemAsrService(),
       _audioCaptureFactory =
           audioCaptureFactory ?? (() => RecordAsrAudioCapture()) {
    final cloud = cloudService ?? CloudAsrService();
    final sherpa = sherpaService ?? SherpaAsrService();
    _cloudSessionStarter = cloudSessionStarter ?? cloud.startSession;
    _localTranscriber =
        localTranscriber ??
        (options, pcm16) => sherpa.transcribePcm16(
          modelId: options.modelId,
          pcm16: pcm16,
          sampleRate: options.sampleRate,
          language: options.language,
          modelDirectoryPath: options.modelDirectory.trim().isEmpty
              ? null
              : options.modelDirectory,
        );
    _localModelInstalledChecker =
        localModelInstalledChecker ?? sherpa.modelManager.isInstalled;
    settingsProvider?.addListener(_handleSettingsChanged);
    unawaited(_refreshSelectedAvailability());
  }

  final SettingsProvider? _settingsProvider;
  final SystemAsrService _systemService;
  final AsrAudioCaptureFactory _audioCaptureFactory;
  late final CloudAsrSessionStarter _cloudSessionStarter;
  late final LocalAsrTranscriber _localTranscriber;
  late final LocalModelInstalledChecker _localModelInstalledChecker;

  AsrSessionState _state = AsrSessionState.idle;
  AsrServiceOptions? _activeService;
  AsrAudioCapture? _capture;
  StreamSubscription<Uint8List>? _captureSubscription;
  StreamSubscription<String>? _partialSubscription;
  CloudAsrSession? _cloudSession;
  BytesBuilder? _localAudio;
  Future<void> _audioWriteTail = Future<void>.value();
  Completer<void>? _captureDone;
  final Map<String, bool> _localAvailability = <String, bool>{};
  bool _systemUnavailable = false;
  bool _disposed = false;
  int _generation = 0;
  String _transcript = '';
  String? _error;
  double _soundLevel = 0;

  AsrSessionState get state => _state;
  AsrServiceOptions? get activeService => _activeService;
  String get transcript => _transcript;
  String? get error => _error;
  double get soundLevel => _soundLevel;
  bool get isActive =>
      _state == AsrSessionState.connecting ||
      _state == AsrSessionState.listening ||
      _state == AsrSessionState.transcribing;
  bool get isListening => _state == AsrSessionState.listening;

  bool canUse(AsrServiceOptions? options) {
    if (options == null || !options.isConfigured) return false;
    return switch (options) {
      SherpaOnnxAsrOptions() => _localAvailability[options.modelId] ?? false,
      SystemAsrOptions() => !_systemUnavailable,
      _ => true,
    };
  }

  Future<void> refreshAvailability([AsrServiceOptions? options]) async {
    final target = options ?? _settingsProvider?.selectedAsrService;
    if (target is! SherpaOnnxAsrOptions || target.modelId.trim().isEmpty) {
      return;
    }
    final installed = await _localModelInstalledChecker(target.modelId);
    if (_disposed) return;
    final previous = _localAvailability[target.modelId];
    _localAvailability[target.modelId] = installed;
    if (previous != installed) notifyListeners();
  }

  Future<bool> checkSystemAvailability() async {
    try {
      final available = await _systemService.initialize();
      if (_disposed) return false;
      _systemUnavailable = !available;
      notifyListeners();
      return available;
    } catch (_) {
      if (_disposed) return false;
      _systemUnavailable = true;
      notifyListeners();
      return false;
    }
  }

  String? _backgroundAudioOwner;

  Future<bool> _claimCaptureAudio(int generation) async {
    final owner = 'capture:$generation';
    await MobileBackgroundCoordinator.instance.setAudioOwner(owner, true);
    if (!_isCurrent(generation)) {
      await MobileBackgroundCoordinator.instance.setAudioOwner(owner, false);
      return false;
    }
    _backgroundAudioOwner = owner;
    return true;
  }

  void _releaseSystemAudio() {
    final owner = _backgroundAudioOwner;
    _backgroundAudioOwner = null;
    if (owner != null) {
      unawaited(
        MobileBackgroundCoordinator.instance.setAudioOwner(owner, false),
      );
    }
  }

  Future<void> start(AsrServiceOptions options) async {
    _ensureNotDisposed();
    if (isActive) throw StateError('An ASR session is already active.');
    if (!options.isConfigured) {
      throw StateError('${options.name} is not configured.');
    }

    final generation = ++_generation;
    _activeService = options;
    _state = AsrSessionState.connecting;
    _transcript = '';
    _error = null;
    _soundLevel = 0;
    notifyListeners();

    try {
      if (options is SherpaOnnxAsrOptions) {
        final installed = await _localModelInstalledChecker(options.modelId);
        if (!_isCurrent(generation)) return;
        _localAvailability[options.modelId] = installed;
        if (!installed) {
          throw StateError('The selected offline ASR model is not downloaded.');
        }
      }

      if (options is SystemAsrOptions) {
        if (!await _claimCaptureAudio(generation)) return;
        final started = await _systemService.start(
          localeId: options.localeId.trim().isEmpty ? null : options.localeId,
          onTranscript: (text, _) {
            if (!_isCurrent(generation)) return;
            _transcript = text.trim();
            notifyListeners();
          },
          onSoundLevel: (level) {
            if (!_isCurrent(generation)) return;
            _soundLevel = _normalizeSystemLevel(level);
            notifyListeners();
          },
          onError: (asrError) {
            if (!_isCurrent(generation)) return;
            _fail(asrError.message);
            final owner = _backgroundAudioOwner;
            _backgroundAudioOwner = null;
            unawaited(
              _systemService.cancel().whenComplete(() async {
                if (owner != null) {
                  await MobileBackgroundCoordinator.instance.setAudioOwner(
                    owner,
                    false,
                  );
                }
              }),
            );
            _activeService = null;
          },
          onDone: () {
            if (!_isCurrent(generation)) return;
            _releaseSystemAudio();
            _state = AsrSessionState.idle;
            _activeService = null;
            _soundLevel = 0;
            notifyListeners();
          },
        );
        if (!_isCurrent(generation)) return;
        if (!started) {
          _systemUnavailable = true;
          throw StateError('System speech recognition is unavailable.');
        }
        _systemUnavailable = false;
        if (_state == AsrSessionState.connecting) {
          _state = AsrSessionState.listening;
        }
        notifyListeners();
        return;
      }

      final capture = _audioCaptureFactory();
      _capture = capture;
      final hasPermission = await capture.hasPermission();
      if (!_isCurrent(generation)) {
        await _cancelStaleCapture(capture);
        return;
      }
      if (!hasPermission) {
        throw StateError('Microphone permission was not granted.');
      }

      if (options is SherpaOnnxAsrOptions) {
        _localAudio = BytesBuilder(copy: false);
      } else {
        final session = await _cloudSessionStarter(options);
        if (!_isCurrent(generation)) {
          await _cancelStaleCloudSession(session);
          return;
        }
        _cloudSession = session;
        _partialSubscription = session.partialTranscripts.listen(
          (text) {
            if (!_isCurrent(generation)) return;
            _transcript = text.trim();
            notifyListeners();
          },
          onError: (Object exception, StackTrace stackTrace) {
            if (_isCurrent(generation)) {
              _failActiveSession(generation, exception.toString());
            }
          },
        );
      }

      final sampleRate = _sampleRateOf(options);
      if (!await _claimCaptureAudio(generation)) {
        await _cancelStaleCapture(capture);
        return;
      }
      final stream = await capture.start(sampleRate: sampleRate);
      if (!_isCurrent(generation)) {
        await _cancelStaleCapture(capture);
        return;
      }
      final done = Completer<void>();
      _captureDone = done;
      _captureSubscription = stream.listen(
        (chunk) {
          if (!_isCurrent(generation)) return;
          _soundLevel = normalizedPcm16Level(chunk);
          _localAudio?.add(chunk);
          final session = _cloudSession;
          if (session != null) {
            _audioWriteTail = _audioWriteTail
                .then((_) => session.addPcm16(chunk))
                .catchError((Object exception, StackTrace stackTrace) {
                  if (_isCurrent(generation)) {
                    _failActiveSession(generation, exception.toString());
                  }
                });
          }
          notifyListeners();
        },
        onError: (Object exception, StackTrace stackTrace) {
          if (!done.isCompleted) done.complete();
          if (_isCurrent(generation)) {
            _failActiveSession(generation, exception.toString());
          }
        },
        onDone: () {
          if (!done.isCompleted) done.complete();
        },
        cancelOnError: false,
      );
      _state = AsrSessionState.listening;
      notifyListeners();
    } catch (error) {
      if (!_isCurrent(generation)) return;
      await _releaseSession(cancelRemote: true, cancelCapture: true);
      _fail(_messageOf(error));
      rethrow;
    }
  }

  Future<String> finish() async {
    _ensureNotDisposed();
    if (!isActive) return _transcript.trim();
    final generation = _generation;
    _state = AsrSessionState.transcribing;
    _soundLevel = 0;
    notifyListeners();

    try {
      final options = _activeService;
      if (options is SystemAsrOptions) {
        await _systemService.stop();
        await _finishSystemSession(generation);
      } else {
        await _capture?.stop();
        await _captureDone?.future.timeout(
          const Duration(seconds: 2),
          onTimeout: () {},
        );
        await _audioWriteTail;
        if (options is SherpaOnnxAsrOptions) {
          final pcm = _localAudio?.takeBytes() ?? Uint8List(0);
          _transcript = (await _localTranscriber(options, pcm)).trim();
        } else {
          final session = _cloudSession;
          if (session != null) {
            _transcript = (await session.finish()).trim();
          }
        }
      }
      if (_isCurrent(generation)) {
        await _releaseSession(cancelRemote: false, cancelCapture: false);
        _state = AsrSessionState.idle;
        _activeService = null;
        notifyListeners();
      }
      return _transcript.trim();
    } catch (error) {
      if (_isCurrent(generation)) {
        await _releaseSession(cancelRemote: true, cancelCapture: true);
        _fail(_messageOf(error));
      }
      rethrow;
    }
  }

  Future<void> cancel() async {
    if (_disposed ||
        (!isActive &&
            _capture == null &&
            _cloudSession == null &&
            _activeService == null)) {
      return;
    }
    ++_generation;
    if (_activeService is SystemAsrOptions) {
      await _systemService.cancel();
    }
    await _releaseSession(cancelRemote: true, cancelCapture: true);
    _state = AsrSessionState.idle;
    _activeService = null;
    _transcript = '';
    _error = null;
    _soundLevel = 0;
    notifyListeners();
  }

  void clearError() {
    if (_state != AsrSessionState.error) return;
    _state = AsrSessionState.idle;
    _error = null;
    notifyListeners();
  }

  Future<void> _finishSystemSession(int generation) async {
    final deadline = DateTime.now().add(const Duration(seconds: 2));
    while (_isCurrent(generation) &&
        _systemService.state == SystemAsrState.stopping &&
        DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 40));
    }
    // Never expose Provider idle while the native service still guards an
    // active session. Some platforms omit the final done status after stop.
    if (_isCurrent(generation) &&
        _systemService.state == SystemAsrState.stopping) {
      await _systemService.cancel();
    }
  }

  Future<void> _releaseSession({
    required bool cancelRemote,
    required bool cancelCapture,
  }) async {
    final audioOwner = _backgroundAudioOwner;
    _backgroundAudioOwner = null;
    try {
      final capture = _capture;
      final cloud = _cloudSession;
      _capture = null;
      _cloudSession = null;
      _localAudio = null;
      _captureDone = null;
      final captureSubscription = _captureSubscription;
      final partialSubscription = _partialSubscription;
      _captureSubscription = null;
      _partialSubscription = null;
      await captureSubscription?.cancel();
      await partialSubscription?.cancel();
      if (cancelRemote) {
        try {
          await cloud?.cancel();
        } catch (_) {}
      }
      if (capture != null) {
        try {
          if (cancelCapture) await capture.cancel();
        } catch (_) {}
        try {
          await capture.dispose();
        } catch (_) {}
      }
      _audioWriteTail = Future<void>.value();
    } finally {
      if (audioOwner != null) {
        await MobileBackgroundCoordinator.instance.setAudioOwner(
          audioOwner,
          false,
        );
      }
    }
  }

  Future<void> _cancelStaleCapture(AsrAudioCapture capture) async {
    try {
      await capture.cancel();
    } catch (_) {}
    try {
      await capture.dispose();
    } catch (_) {}
  }

  Future<void> _cancelStaleCloudSession(CloudAsrSession session) async {
    try {
      await session.cancel();
    } catch (_) {}
  }

  void _handleSettingsChanged() {
    final selected = _settingsProvider?.selectedAsrService;
    final active = _activeService;
    if (active != null && selected?.id != active.id) {
      unawaited(cancel());
    }
    unawaited(_refreshSelectedAvailability());
  }

  Future<void> _refreshSelectedAvailability() async {
    final selected = _settingsProvider?.selectedAsrService;
    if (selected is SherpaOnnxAsrOptions) {
      await refreshAvailability(selected);
    }
  }

  bool _isCurrent(int generation) => !_disposed && generation == _generation;

  void _fail(String message) {
    if (_disposed) return;
    _state = AsrSessionState.error;
    _error = message;
    _soundLevel = 0;
    notifyListeners();
  }

  void _failActiveSession(int generation, String message) {
    if (!_isCurrent(generation)) return;
    _fail(_messageOf(message));
    unawaited(
      _releaseSession(cancelRemote: true, cancelCapture: true).then((_) {
        if (_isCurrent(generation)) _activeService = null;
      }),
    );
  }

  static int _sampleRateOf(AsrServiceOptions options) => switch (options) {
    SherpaOnnxAsrOptions() => options.sampleRate,
    OpenAiRealtimeAsrOptions() => options.sampleRate,
    DashScopeAsrOptions() => options.sampleRate,
    QwenAudioAsrOptions() => options.sampleRate,
    VolcengineAsrOptions() => 16000,
    MimoAsrOptions() => options.sampleRate,
    StepAsrOptions() => options.sampleRate,
    SystemAsrOptions() => 16000,
    _ => throw StateError('Unsupported ASR service: ${options.kind.id}'),
  };

  static double _normalizeSystemLevel(double value) {
    if (!value.isFinite) return 0;
    if (value <= 0) return ((value + 60) / 60).clamp(0.0, 1.0).toDouble();
    return (value / 12).clamp(0.0, 1.0).toDouble();
  }

  static String _messageOf(Object error) {
    if (error is AsrException) return error.message;
    return error.toString().replaceFirst(RegExp(r'^\w+(?:<[^>]+>)?:\s*'), '');
  }

  void _ensureNotDisposed() {
    if (_disposed) throw StateError('AsrProvider has been disposed.');
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _settingsProvider?.removeListener(_handleSettingsChanged);
    unawaited(_systemService.dispose());
    final capture = _capture;
    final cloud = _cloudSession;
    _capture = null;
    _cloudSession = null;
    unawaited(_captureSubscription?.cancel());
    unawaited(_partialSubscription?.cancel());
    if (capture != null) unawaited(capture.dispose());
    if (cloud != null) unawaited(cloud.cancel());
    super.dispose();
  }
}
