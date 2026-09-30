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
///
/// Every non-system session also keeps the raw PCM, so a recording can end as
/// an audio clip for models that accept audio natively instead of as text.
///
/// Each recording owns an [_AsrSession]; ending one detaches it before its
/// asynchronous cleanup, and only the current or winding-down session may
/// write the public state. Late work of an old recording therefore can never
/// truncate, reset, or overwrite the next one.
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
  _AsrSession? _session;
  // The session being wound down after [_session] was detached from it; it
  // alone may publish the final state once its cleanup finishes.
  _AsrSession? _ending;
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

  Future<bool> _claimCaptureAudio(_AsrSession session) async {
    final owner = 'capture:${session.generation}';
    await MobileBackgroundCoordinator.instance.setAudioOwner(owner, true);
    if (!_isCurrent(session)) {
      await MobileBackgroundCoordinator.instance.setAudioOwner(owner, false);
      return false;
    }
    session.audioOwner = owner;
    return true;
  }

  /// Starts a session. A null [options] records without recognition; such a
  /// session can only end through [finishAudio].
  Future<void> start(AsrServiceOptions? options) async {
    _ensureNotDisposed();
    if (isActive) throw StateError('An ASR session is already active.');
    if (options != null && !options.isConfigured) {
      throw StateError('${options.name} is not configured.');
    }

    final session = _AsrSession(++_generation, options);
    _session = session;
    // A failed session may still be cleaning up; it no longer owns the state.
    _ending = null;
    _activeService = options;
    _state = AsrSessionState.connecting;
    _transcript = '';
    _error = null;
    _soundLevel = 0;
    notifyListeners();

    try {
      if (options is SherpaOnnxAsrOptions) {
        final installed = await _localModelInstalledChecker(options.modelId);
        if (!_isCurrent(session)) return;
        _localAvailability[options.modelId] = installed;
        if (!installed) {
          throw StateError('The selected offline ASR model is not downloaded.');
        }
      }

      if (options is SystemAsrOptions) {
        if (!await _claimCaptureAudio(session)) return;
        final started = await _systemService.start(
          localeId: options.localeId.trim().isEmpty ? null : options.localeId,
          onTranscript: (text, _) {
            if (!_isCurrent(session)) return;
            _transcript = text.trim();
            notifyListeners();
          },
          onSoundLevel: (level) {
            if (!_isCurrent(session)) return;
            _soundLevel = _normalizeSystemLevel(level);
            notifyListeners();
          },
          onError: (asrError) {
            if (!_isCurrent(session)) return;
            unawaited(
              _failSession(session, asrError.message, cancelSystem: true),
            );
          },
          onDone: () {
            // finish() drives its own session to idle.
            if (!_isCurrent(session) || session.finishing) return;
            _session = null;
            unawaited(_release(session, cancelRemote: true));
            _state = AsrSessionState.idle;
            _activeService = null;
            _soundLevel = 0;
            notifyListeners();
          },
        );
        if (!_isCurrent(session)) return;
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
      session.capture = capture;
      final hasPermission = await capture.hasPermission();
      if (!_isCurrent(session)) return;
      if (!hasPermission) {
        throw StateError('Microphone permission was not granted.');
      }

      if (options != null && options is! SherpaOnnxAsrOptions) {
        final cloud = await _cloudSessionStarter(options);
        if (!_isCurrent(session)) {
          await _cancelStaleCloudSession(cloud);
          return;
        }
        session.cloud = cloud;
        session.partialSubscription = cloud.partialTranscripts.listen(
          (text) {
            if (!_isCurrent(session)) return;
            _transcript = text.trim();
            notifyListeners();
          },
          onError: (Object exception, StackTrace stackTrace) {
            if (_isCurrent(session)) {
              unawaited(_failSession(session, exception.toString()));
            }
          },
        );
      }

      session.sampleRate = _sampleRateOf(options);
      if (!await _claimCaptureAudio(session)) return;
      final stream = await capture.start(sampleRate: session.sampleRate);
      if (!_isCurrent(session)) {
        // Cleanup may have run while the recorder was still starting.
        await _cancelStaleCapture(capture);
        return;
      }
      final done = Completer<void>();
      session.captureDone = done;
      session.captureSubscription = stream.listen(
        (chunk) {
          if (!_isCurrent(session)) return;
          _soundLevel = normalizedPcm16Level(chunk);
          session.pcm.add(chunk);
          final cloud = session.cloud;
          if (cloud != null) {
            session.writeTail = session.writeTail
                .then((_) => cloud.addPcm16(chunk))
                .catchError((Object exception, StackTrace stackTrace) {
                  if (_isCurrent(session)) {
                    unawaited(_failSession(session, exception.toString()));
                  }
                });
          }
          notifyListeners();
        },
        onError: (Object exception, StackTrace stackTrace) {
          if (!done.isCompleted) done.complete();
          if (_isCurrent(session)) {
            unawaited(_failSession(session, exception.toString()));
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
      if (!_isCurrent(session)) return;
      await _failSession(session, error);
      rethrow;
    } finally {
      // A session superseded mid-start never reached anyone who would free it.
      if (!_isCurrent(session) && !identical(_ending, session)) {
        unawaited(_release(session, cancelRemote: true));
      }
    }
  }

  Future<String> finish() async {
    _ensureNotDisposed();
    final session = _session;
    if (session == null || !isActive) return _transcript.trim();
    session.finishing = true;
    _state = AsrSessionState.transcribing;
    _soundLevel = 0;
    notifyListeners();

    try {
      final options = session.options;
      if (options is SystemAsrOptions) {
        await _systemService.stop();
        await _finishSystemSession(session);
      } else {
        await session.stopCapture();
        if (!_isCurrent(session)) return '';
        // Read after the stream closed so the last chunks' writes are included.
        await session.writeTail;
        final String? text;
        if (options is SherpaOnnxAsrOptions) {
          text = (await _localTranscriber(
            options,
            session.pcm.takeBytes(),
          )).trim();
        } else {
          final cloud = session.cloud;
          text = cloud == null ? null : (await cloud.finish()).trim();
        }
        if (!_isCurrent(session)) return '';
        if (text != null) _transcript = text;
      }
      if (!_isCurrent(session)) return '';
      final transcript = _transcript.trim();
      await _windDown(session, cancelRemote: false, () {
        _state = AsrSessionState.idle;
        _activeService = null;
      });
      return transcript;
    } catch (error) {
      await _failSession(session, error);
      rethrow;
    }
  }

  /// Ends capture and returns the recording as WAV without recognizing it.
  /// Unavailable for system recognition, which never exposes raw audio.
  Future<Uint8List> finishAudio() async {
    _ensureNotDisposed();
    final session = _session;
    if (session == null ||
        !isListening ||
        session.options is SystemAsrOptions) {
      throw StateError('No raw audio is being recorded.');
    }
    session.finishing = true;
    _state = AsrSessionState.transcribing;
    _transcript = '';
    _soundLevel = 0;
    notifyListeners();

    try {
      await session.stopCapture();
      if (!_isCurrent(session)) {
        throw StateError('The recording was cancelled.');
      }
      final wav = pcm16MonoToWav(
        session.pcm.takeBytes(),
        sampleRate: session.sampleRate,
      );
      // Cancels the cloud recognition this recording no longer needs.
      await _windDown(session, cancelRemote: true, () {
        _state = AsrSessionState.idle;
        _activeService = null;
      });
      return wav;
    } catch (error) {
      await _failSession(session, error);
      rethrow;
    }
  }

  Future<void> cancel() async {
    if (_disposed) return;
    final session = _session;
    if (session == null) {
      // An ending already in progress settles the state itself.
      if (_ending != null || _state == AsrSessionState.idle) return;
      _state = AsrSessionState.idle;
      _activeService = null;
      _transcript = '';
      _error = null;
      _soundLevel = 0;
      notifyListeners();
      return;
    }
    await _windDown(
      session,
      cancelRemote: true,
      cancelCapture: true,
      cancelSystem: session.options is SystemAsrOptions,
      () {
        _state = AsrSessionState.idle;
        _activeService = null;
        _transcript = '';
        _error = null;
        _soundLevel = 0;
      },
    );
  }

  void clearError() {
    if (_state != AsrSessionState.error) return;
    _state = AsrSessionState.idle;
    _error = null;
    notifyListeners();
  }

  Future<void> _finishSystemSession(_AsrSession session) async {
    final deadline = DateTime.now().add(const Duration(seconds: 2));
    while (_isCurrent(session) &&
        _systemService.state == SystemAsrState.stopping &&
        DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 40));
    }
    // Never expose Provider idle while the native service still guards an
    // active session. Some platforms omit the final done status after stop.
    if (_isCurrent(session) &&
        _systemService.state == SystemAsrState.stopping) {
      await _systemService.cancel();
    }
  }

  /// Detaches [session], frees it, then applies [settle] unless a newer
  /// session or ending took over meanwhile. The state stays active until
  /// then, so no new recording can start on top of the cleanup.
  Future<void> _windDown(
    _AsrSession session,
    void Function() settle, {
    required bool cancelRemote,
    bool cancelCapture = false,
    bool cancelSystem = false,
  }) async {
    if (!_isCurrent(session)) return;
    _session = null;
    _ending = session;
    try {
      if (cancelSystem) await _systemService.cancel();
    } finally {
      await _release(
        session,
        cancelRemote: cancelRemote,
        cancelCapture: cancelCapture,
      );
      if (!_disposed && identical(_ending, session)) {
        _ending = null;
        settle();
        notifyListeners();
      }
    }
  }

  /// Publishes the failure at once, then frees the session.
  Future<void> _failSession(
    _AsrSession session,
    Object error, {
    bool cancelSystem = false,
  }) async {
    if (!_isCurrent(session)) return;
    _session = null;
    _ending = session;
    _fail(_messageOf(error));
    try {
      if (cancelSystem) await _systemService.cancel();
    } catch (_) {
    } finally {
      await _release(session, cancelRemote: true, cancelCapture: true);
      if (!_disposed && identical(_ending, session)) {
        _ending = null;
        _activeService = null;
      }
    }
  }

  Future<void> _release(
    _AsrSession session, {
    required bool cancelRemote,
    bool cancelCapture = true,
  }) async {
    if (session.released) return;
    session.released = true;
    try {
      await session.captureSubscription?.cancel();
      await session.partialSubscription?.cancel();
      if (cancelRemote) {
        try {
          await session.cloud?.cancel();
        } catch (_) {}
      }
      final capture = session.capture;
      if (capture != null) {
        try {
          if (cancelCapture) await capture.cancel();
        } catch (_) {}
        try {
          await capture.dispose();
        } catch (_) {}
      }
    } finally {
      final audioOwner = session.audioOwner;
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

  bool _isCurrent(_AsrSession session) =>
      !_disposed && identical(_session, session);

  void _fail(String message) {
    if (_disposed) return;
    _state = AsrSessionState.error;
    _error = message;
    _soundLevel = 0;
    notifyListeners();
  }

  static int _sampleRateOf(AsrServiceOptions? options) => switch (options) {
    null => 16000,
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
    final session = _session;
    _session = null;
    if (session != null) unawaited(_release(session, cancelRemote: true));
    super.dispose();
  }
}

/// Resources of one recording, freed only through [AsrProvider._release].
final class _AsrSession {
  _AsrSession(this.generation, this.options);

  final int generation;
  final AsrServiceOptions? options;
  final BytesBuilder pcm = BytesBuilder(copy: false);
  int sampleRate = 0;
  AsrAudioCapture? capture;
  CloudAsrSession? cloud;
  StreamSubscription<Uint8List>? captureSubscription;
  StreamSubscription<String>? partialSubscription;
  Completer<void>? captureDone;
  // Cloud writes of this recording only; never shared with the next one.
  Future<void> writeTail = Future<void>.value();
  String? audioOwner;
  bool finishing = false;
  bool released = false;

  Future<void> stopCapture() async {
    await capture?.stop();
    await captureDone?.future.timeout(
      const Duration(seconds: 2),
      onTimeout: () {},
    );
  }
}
