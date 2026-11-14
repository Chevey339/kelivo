import 'dart:async';
import 'dart:convert';
import 'dart:io' as io;
import 'dart:typed_data' show BytesBuilder;
import 'dart:ui' as ui;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../services/tts/tts_text_selection.dart';
import '../database/business_preferences.dart';
import '../services/tts/network_tts.dart';
import '../services/mobile_background.dart';
import '../services/tts/tts_playback_models.dart';
import '../services/tts/tts_replay_cache.dart';
import '../services/tts/tts_text_chunker.dart';

String ttsAudioFileExtensionForMime(String? mime) {
  switch ((mime ?? '').toLowerCase()) {
    case 'audio/mpeg':
    case 'audio/mp3':
      return 'mp3';
    case 'audio/wav':
    case 'audio/x-wav':
      return 'wav';
    case 'audio/ogg':
    case 'audio/opus':
      return 'ogg';
    case 'audio/flac':
      return 'flac';
    case 'audio/pcm':
      return 'pcm';
    default:
      return 'mp3';
  }
}

/// System and network TTS coordinator.
///
/// Long text is split into smaller chunks. Network TTS chunks are prefetched
/// while the current chunk is playing; system TTS chunks are sequenced through
/// flutter_tts with progress callbacks.
class TtsProvider extends ChangeNotifier {
  static const String _rateKey = 'tts_speech_rate_v1';
  static const String _playbackSpeedKey = 'tts_playback_speed_v1';
  static const String _pitchKey = 'tts_pitch_v1';
  static const String _engineKey = 'tts_engine_v1';
  static const String _langKey = 'tts_language_v1';
  static const String _cacheNetworkAudioForReplayKey =
      'tts_cache_network_audio_for_replay_v1';
  static const int _systemChunkMaxLength = 360;
  static const int _networkPrefetchCount = 3;
  static const Duration _seekStep = Duration(seconds: 15);

  final BusinessPreferences preferences;
  final MobileBackgroundCoordinator _background;
  bool _previewPlaying = false;
  late FlutterTts _tts;
  final AudioPlayer _player = AudioPlayer();
  final _replayCache = TtsReplayCache();

  final List<TtsTextChunk> _chunks = <TtsTextChunk>[];
  final _networkCache = <int, Future<io.File>>{};
  final _resolvedNetworkChunks = <int, io.File>{};
  final _temporaryAudio = <io.File>{};

  TtsPlaybackTimeline _timeline = TtsPlaybackTimeline(const <TtsTextChunk>[]);
  TtsPlaybackState _playbackState = const TtsPlaybackState();

  bool _initialized = false;
  bool _engineReady = false;
  bool _isSpeaking = false;
  bool _isPaused = false;
  bool _usingNetwork = false;
  bool _ignoreTtsStopCallbacks = false;
  bool _networkSeekInterruptedChunk = false;
  String? _error;
  String? _lastReplayContent;
  TtsServiceOptions? _lastReplayNetworkService;
  String? _networkServiceKey;

  // Settings
  double _speechRate = 0.5; // flutter_tts platform value, 0.5 is normal.
  double _preferredPlaybackSpeed = 1.0;
  double _pitch = 1.0;
  bool _cacheNetworkAudioForReplay = false;
  String? _engineId;
  String? _languageTag;

  int _sessionId = 0;
  int _readySessionId = 0;
  Object? _systemUtterance;
  double? _submittedSystemSpeed;
  int _currentChunkIndex = 0;
  int _currentChunkTextOffset = 0;
  Duration _currentChunkPosition = Duration.zero;
  Duration? _currentChunkDuration;
  Duration _pendingNetworkSeekOffset = Duration.zero;
  Completer<void>? _speakingCompleter;
  Completer<void>? _networkChunkCompleter;

  StreamSubscription<AudioEvent>? _playerEventSub;
  StreamSubscription<Duration>? _playerPositionSub;
  StreamSubscription<PlayerState>? _playerStateSub;

  bool get _backgroundSpeechAllowed =>
      _background.platform != TargetPlatform.iOS ||
      (!_background.hasCaptureAudio &&
          (_background.isForeground ||
              _background.settings.backgroundSpeechEnabled));

  Future<void> _claimSpeechAudio() async {
    await _background.setAudioOwner('speechBuffering', true);
    await _background.setAudioOwner('speech', true);
  }

  void _releaseSpeechWork() {
    _releaseSpeechAudio();
    unawaited(_background.setAudioOwner('speechBuffering', false));
  }

  void _releaseSpeechAudio() {
    unawaited(_background.setAudioOwner('speech', false));
  }

  bool get isAvailable => _initialized;
  bool get isSpeaking => _isSpeaking || _previewPlaying;
  bool get isPaused => _isPaused;
  bool get usingNetwork => _usingNetwork;
  String? get error => _error;
  double get speechRate => _speechRate;
  double get pitch => _pitch;
  bool get cacheNetworkAudioForReplay => _cacheNetworkAudioForReplay;
  String? get engineId => _engineId;
  String? get languageTag => _languageTag;
  TtsPlaybackState get playbackState => _playbackState;
  Duration get seekStep => _seekStep;
  bool get canSaveNetworkAudio =>
      _readySessionId == _sessionId &&
      _lastReplayNetworkService != null &&
      _chunks.isNotEmpty;

  TtsProvider({
    required this.preferences,
    MobileBackgroundCoordinator? background,
  }) : _background = background ?? MobileBackgroundCoordinator.instance {
    _init();
  }

  Future<void> _init() async {
    try {
      _tts = FlutterTts();
      await preferences.load();
      _speechRate = (preferences.getDouble(_rateKey) ?? 0.5)
          .clamp(0.1, 1.0)
          .toDouble();
      _pitch = (preferences.getDouble(_pitchKey) ?? 1.0)
          .clamp(0.5, 2.0)
          .toDouble();
      _cacheNetworkAudioForReplay =
          preferences.getBool(_cacheNetworkAudioForReplayKey) ?? false;
      _engineId = preferences.getString(_engineKey);
      _languageTag = preferences.getString(_langKey);
      _preferredPlaybackSpeed = TtsPlaybackSpeed.normalize(
        preferences.getDouble(_playbackSpeedKey) ?? _speechRate * 2,
      );
      _playbackState = _playbackState.copyWith(speed: _preferredPlaybackSpeed);

      _bindTtsHandlers();
      _bindAudioPlayerHandlers();

      await _kickEngine();
      await _ensureBound(timeout: const Duration(seconds: 5));
      await _selectEngine();
      await _applyConfig();

      _initialized = true;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _initialized = false;
      _playbackState = _playbackState.copyWith(
        status: TtsPlaybackStatus.error,
        errorMessage: _error,
      );
      notifyListeners();
    }
  }

  void _bindTtsHandlers() {
    _tts.setStartHandler(() {
      _isSpeaking = true;
      _isPaused = false;
      _updatePlaybackState(status: TtsPlaybackStatus.playing, clearError: true);
    });
    _tts.setCompletionHandler(() {
      if (_ignoreTtsStopCallbacks) return;
      if (!_usingNetwork) _advanceSystemChunkOrFinish();
    });
    _tts.setCancelHandler(() {
      if (_ignoreTtsStopCallbacks) return;
      _stopInternal(updateState: true);
    });
    _tts.setPauseHandler(() {
      _isPaused = true;
      _updatePlaybackState(status: TtsPlaybackStatus.paused);
    });
    _tts.setContinueHandler(() {
      _isPaused = false;
      _updatePlaybackState(status: TtsPlaybackStatus.playing);
    });
    _tts.setProgressHandler((text, start, end, word) {
      if (_usingNetwork || _chunks.isEmpty) return;
      final chunk = _chunks[_currentChunkIndex];
      final spokenEnd = (_currentChunkTextOffset + end)
          .clamp(0, chunk.text.length)
          .toInt();
      _currentChunkPosition = _estimatedPositionInChunk(chunk, spokenEnd);
      _updatePositionFromCurrentChunk();
    });
    _tts.setErrorHandler((msg) {
      _error = msg?.toString();
      _stopInternal(updateState: false);
      _playbackState = _playbackState.copyWith(
        status: TtsPlaybackStatus.error,
        errorMessage: _error,
      );
      notifyListeners();
    });
  }

  void _bindAudioPlayerHandlers() {
    _playerEventSub = _player.eventStream.listen(
      (event) {
        if (event.eventType == AudioEventType.complete) {
          _completeNetworkChunk();
        } else if (event.eventType == AudioEventType.duration &&
            _usingNetwork &&
            _chunks.isNotEmpty) {
          _currentChunkDuration = event.duration;
          _updatePositionFromCurrentChunk();
        }
      },
      onError: (Object error, StackTrace stack) {
        final chunk = _networkChunkCompleter;
        if (chunk != null && !chunk.isCompleted) {
          chunk.completeError(error, stack);
        }
      },
    );
    _playerPositionSub = _player.onPositionChanged.listen((position) {
      if (!_usingNetwork || _chunks.isEmpty) return;
      _currentChunkPosition = position;
      _updatePositionFromCurrentChunk();
    });
    _playerStateSub = _player.onPlayerStateChanged.listen((state) {
      if (state != PlayerState.playing) {
        if (_usingNetwork) {
          _releaseSpeechAudio();
        } else {
          _previewPlaying = false;
          _releaseSpeechWork();
        }
      }
      if (!_usingNetwork) return;
      switch (state) {
        case PlayerState.playing:
          _isSpeaking = true;
          _isPaused = false;
          _updatePlaybackState(status: TtsPlaybackStatus.playing);
          break;
        case PlayerState.paused:
          _isPaused = true;
          _updatePlaybackState(status: TtsPlaybackStatus.paused);
          break;
        case PlayerState.stopped:
        case PlayerState.completed:
        case PlayerState.disposed:
          break;
      }
    });
  }

  Future<void> _setSystemSpeechRate(double rate) async {
    try {
      await _tts.setSpeechRate(rate);
    } catch (_) {}
  }

  Future<void> _applyConfig() async {
    await _setSystemSpeechRate(_speechRate);
    try {
      await _tts.setPitch(_pitch);
    } catch (_) {}
    try {
      await _tts.setVolume(1.0);
    } catch (_) {}
    final loc = ui.PlatformDispatcher.instance.locale;
    final defaultTag = _localeToTag(loc);
    try {
      if (_engineId != null && _engineId!.isNotEmpty) {
        try {
          await _tts.setEngine(_engineId!);
        } catch (_) {}
      }
      final tag = (_languageTag == null || _languageTag!.isEmpty)
          ? defaultTag
          : _languageTag!;
      final res = await _tts.isLanguageAvailable(tag);
      if (res == true) {
        await _tts.setLanguage(tag);
      } else {
        final zh = loc.languageCode.toLowerCase().startsWith('zh');
        final fb = zh ? 'zh-CN' : 'en-US';
        final ok = await _tts.isLanguageAvailable(fb);
        if (ok == true) {
          await _tts.setLanguage(fb);
        }
      }
    } catch (_) {}
    try {
      await _tts.awaitSpeakCompletion(true);
    } catch (_) {}
    try {
      await _tts.awaitSynthCompletion(true);
    } catch (_) {}
    try {
      await _tts.setQueueMode(1);
    } catch (_) {}
  }

  Future<void> _recreateEngine() async {
    await _stopSystemTtsIgnoringCallbacks();
    _engineReady = false;
    _tts = FlutterTts();
    _bindTtsHandlers();
    await _kickEngine();
    await _ensureBound(timeout: const Duration(seconds: 2));
    await _selectEngine();
    await _applyConfig();
  }

  Future<void> _kickEngine() async {
    try {
      await _tts.getLanguages;
    } catch (_) {}
    try {
      await _tts.getEngines;
    } catch (_) {}
  }

  Future<void> _ensureBound({
    Duration timeout = const Duration(seconds: 3),
  }) async {
    if (_engineReady) return;
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      try {
        final langs = await _tts.getLanguages;
        if (langs != null) {
          _engineReady = true;
          notifyListeners();
          return;
        }
      } catch (_) {}
      await Future.delayed(const Duration(milliseconds: 120));
    }
  }

  Future<void> _selectEngine() async {
    try {
      final engines = await _tts.getEngines;
      if (engines is List && engines.isNotEmpty) {
        String? chosen;
        for (final e in engines) {
          final s = e.toString();
          if (s.toLowerCase().contains('google')) {
            chosen = s;
            break;
          }
        }
        chosen ??= engines.first.toString();
        try {
          await _tts.setEngine(chosen);
        } catch (_) {}
      }
    } catch (_) {}
  }

  Future<void> setSpeechRate(double rate) async {
    final r = rate.clamp(0.1, 1.0).toDouble();
    final speed = TtsPlaybackSpeed.normalize(r * 2);
    if (_speechRate == r && _preferredPlaybackSpeed == speed) return;
    _speechRate = r;
    _preferredPlaybackSpeed = speed;
    if (!_playbackState.isActive) {
      _playbackState = _playbackState.copyWith(speed: _preferredPlaybackSpeed);
    }
    await Future.wait<void>([
      preferences.setMany({
        _rateKey: r,
        _playbackSpeedKey: _preferredPlaybackSpeed,
      }),
      _setSystemSpeechRate(r),
    ]);
    notifyListeners();
  }

  Future<void> setPitch(double v) async {
    final p = v.clamp(0.5, 2.0).toDouble();
    if (_pitch == p) return;
    _pitch = p;
    try {
      await _tts.setPitch(_pitch);
    } catch (_) {}
    notifyListeners();
    await preferences.setDouble(_pitchKey, _pitch);
  }

  Future<void> setCacheNetworkAudioForReplay(bool value) async {
    if (_cacheNetworkAudioForReplay == value) return;
    _cacheNetworkAudioForReplay = value;
    notifyListeners();
    await preferences.setBool(_cacheNetworkAudioForReplayKey, value);
  }

  Future<List<String>> listEngines() async {
    try {
      final res = await _tts.getEngines;
      if (res is List) return res.map((e) => e.toString()).toList();
    } catch (_) {}
    return const <String>[];
  }

  Future<List<String>> listLanguages() async {
    try {
      final res = await _tts.getLanguages;
      if (res is List) return res.map((e) => e.toString()).toList();
    } catch (_) {}
    return const <String>[];
  }

  Future<void> setEngineId(String id) async {
    _engineId = id;
    await preferences.setString(_engineKey, id);
    try {
      await _tts.setEngine(id);
    } catch (_) {}
    await _applyConfig();
    notifyListeners();
  }

  Future<void> setLanguageTag(String tag) async {
    _languageTag = tag;
    await preferences.setString(_langKey, tag);
    try {
      await _tts.setLanguage(tag);
    } catch (_) {}
    notifyListeners();
  }

  /// With [waitForCompletion] false, returns after old-player cleanup and the
  /// native buffering lease are complete. Generation may then end safely;
  /// neither a network response nor the spoken audio blocks that handoff.
  Future<void> speak(
    String text, {
    bool flush = true,
    bool waitForCompletion = true,
    bool plainText = false,
  }) async {
    if (!_initialized) return;
    final selected = await _getSelectedNetworkService();
    if (selected != null && selected.enabled) {
      return _speakQueued(
        text,
        networkService: selected,
        flush: flush,
        waitForCompletion: waitForCompletion,
        plainText: plainText,
      );
    }
    return _speakQueued(
      text,
      flush: flush,
      waitForCompletion: waitForCompletion,
      plainText: plainText,
    );
  }

  Future<void> speakSystem(
    String text, {
    bool flush = true,
    bool plainText = false,
  }) async {
    if (!_initialized) return;
    return _speakQueued(text, flush: flush, plainText: plainText);
  }

  Future<void> speakWithNetworkService(
    TtsServiceOptions service,
    String text, {
    bool flush = true,
    bool plainText = false,
  }) async {
    await _speakQueued(
      text,
      networkService: service,
      flush: flush,
      plainText: plainText,
    );
  }

  Future<void> _speakQueued(
    String text, {
    TtsServiceOptions? networkService,
    bool flush = true,
    bool waitForCompletion = true,
    bool plainText = false,
  }) async {
    final content = (plainText ? text : TtsTextSelection.stripMarkdown(text))
        .trim();
    if (content.isEmpty) return;
    final session = ++_sessionId;
    _systemUtterance = null;
    _submittedSystemSpeed = null;
    final previousService = _lastReplayNetworkService;
    _speakingCompleter?.complete();
    _speakingCompleter = null;
    final chunks = TtsTextChunker.split(
      content,
      maxChunkLength: networkService == null
          ? _systemChunkMaxLength
          : networkTtsMaxCharsPerRequest(networkService),
    );
    final useCache = _cacheNetworkAudioForReplay && networkService != null;
    final serviceKey = useCache
        ? await TtsReplayCache.serviceKey(networkService)
        : null;
    if (session != _sessionId) return;
    _replayCache.retain({
      if (serviceKey != null)
        for (final chunk in chunks)
          TtsReplayCache.chunkKey(serviceKey, chunk.text),
    });
    if (flush) await _stopPlaybackEngines();
    if (session != _sessionId) return;
    // Enabling replay after a first, uncached listen can promote its files.
    final previousKey =
        useCache && content == _lastReplayContent && previousService != null
        ? _networkServiceKey ?? await TtsReplayCache.serviceKey(previousService)
        : null;
    if (session != _sessionId) return;
    if (!useCache || serviceKey != previousKey) {
      _resolvedNetworkChunks.clear();
      await _clearTemporaryAudio();
      if (session != _sessionId) return;
    }
    _networkServiceKey = serviceKey;
    _readySessionId = session;
    _lastReplayContent = content;
    _lastReplayNetworkService = networkService;

    _previewPlaying = false;
    _usingNetwork = networkService != null;
    _networkCache.clear();
    _chunks
      ..clear()
      ..addAll(chunks);
    if (_chunks.isEmpty) return;

    _timeline = TtsPlaybackTimeline(_chunks);
    _currentChunkIndex = 0;
    _currentChunkTextOffset = 0;
    _currentChunkPosition = Duration.zero;
    _currentChunkDuration = null;
    _pendingNetworkSeekOffset = Duration.zero;
    _networkSeekInterruptedChunk = false;
    _isSpeaking = true;
    _isPaused = false;
    _error = null;
    _speakingCompleter = Completer<void>();
    final playbackFuture = _speakingCompleter!.future;
    _playbackState = TtsPlaybackState(
      status: TtsPlaybackStatus.buffering,
      duration: _timeline.estimatedDuration,
      speed: _preferredPlaybackSpeed,
      totalChunks: _chunks.length,
      usingNetwork: _usingNetwork,
    );
    notifyListeners();

    if (!_backgroundSpeechAllowed) {
      _isPaused = true;
      _updatePlaybackState(status: TtsPlaybackStatus.paused);
    } else {
      await _background.setAudioOwner('speechBuffering', true);
    }
    if (session != _sessionId) return;
    if (_usingNetwork) {
      unawaited(_runNetworkQueue(session, networkService!));
    } else if (!_isPaused) {
      final playback = _ensureBound().then(
        (_) => _speakCurrentSystemChunk(session),
      );
      if (waitForCompletion) {
        await playback;
      } else {
        unawaited(
          playback.catchError((Object error) {
            if (session != _sessionId) return;
            _error = error.toString();
            _finishPlayback(status: TtsPlaybackStatus.error, error: _error);
          }),
        );
      }
    }
    if (waitForCompletion) return playbackFuture;
  }

  Future<void> pause() async {
    if (_previewPlaying) {
      _previewPlaying = false;
      try {
        await _player.pause();
      } finally {
        _releaseSpeechWork();
      }
      return;
    }
    if (!_initialized || !_isSpeaking || _isPaused) return;
    // Mark immediately so a pending network result cannot start during pause.
    _isPaused = true;
    try {
      if (_usingNetwork) {
        await _player.pause();
      } else {
        await _ensureBound();
        try {
          await _tts.pause();
        } catch (_) {}
      }
    } finally {
      // Audio services can disappear during a call/route change. Even when
      // the player rejects pause, it must not retain the silent-audio lease.
      _isPaused = true;
      _updatePlaybackState(status: TtsPlaybackStatus.paused);
    }
  }

  Future<void> resume() async {
    if (!_initialized || !_isPaused) return;
    if (!_backgroundSpeechAllowed) return;
    if (_usingNetwork) {
      final session = _sessionId;
      final hasSource = _networkChunkCompleter != null;
      if (hasSource) {
        await _claimSpeechAudio();
      } else {
        // The network queue claims audible playback when the source is ready.
        // Buffering alone must let native silent-audio keepalive continue.
        await _background.setAudioOwner('speechBuffering', true);
      }
      if (session != _sessionId || !_backgroundSpeechAllowed) return;
      if (hasSource) await _player.resume();
      _isPaused = false;
      _updatePlaybackState(
        status: hasSource
            ? TtsPlaybackStatus.playing
            : TtsPlaybackStatus.buffering,
      );
      return;
    }
    _isPaused = false;
    await _restartSystemAt(
      _sessionId,
      _currentChunkIndex,
      _currentChunkPosition,
      status: TtsPlaybackStatus.playing,
    );
  }

  Future<void> togglePause() async {
    if (_playbackState.status == TtsPlaybackStatus.ended) {
      await replay();
      return;
    }
    if (_isPaused) {
      await resume();
    } else {
      await pause();
    }
  }

  Future<void> replay() async {
    if (!_initialized) return;
    final content = _lastReplayContent;
    if (content == null || content.isEmpty) return;
    final networkService = _lastReplayNetworkService;
    await _speakQueued(
      content,
      networkService: networkService,
      flush: true,
      plainText: true,
    );
  }

  Future<void> stop() async {
    final session = ++_sessionId;
    _replayCache.retain({});
    await _stopPlaybackEngines();
    if (session == _sessionId) {
      _stopInternal(updateState: true);
      await _clearTemporaryAudio();
    }
  }

  Future<void> seekBackward() => seekRelative(-_seekStep);

  Future<void> seekForward() => seekRelative(_seekStep);

  Future<void> seekRelative(Duration delta) async {
    if (_chunks.isEmpty || !_playbackState.isActive) return;
    final target = _timeline.seekTarget(
      currentPosition: _playbackState.position,
      delta: delta,
    );
    await _seekToTarget(target);
  }

  Future<void> seekTo(Duration position) async {
    if (_chunks.isEmpty || !_playbackState.isActive) return;
    final target = _timeline.seekTarget(
      currentPosition: Duration.zero,
      delta: position,
    );
    await _seekToTarget(target);
  }

  Future<void> cyclePlaybackSpeed() async {
    await setPlaybackSpeed(TtsPlaybackSpeed.next(_playbackState.speed));
  }

  Future<void> setPlaybackSpeed(double speed) async {
    final normalized = TtsPlaybackSpeed.normalize(speed);
    _preferredPlaybackSpeed = normalized;
    _playbackState = _playbackState.copyWith(speed: normalized);
    await Future.wait<void>([
      preferences.setDouble(_playbackSpeedKey, normalized),
      _applyPlaybackSpeed(normalized),
    ]);
  }

  Future<void> _applyPlaybackSpeed(double speed) async {
    notifyListeners();
    if (_usingNetwork) {
      try {
        await _player.setPlaybackRate(speed);
      } catch (_) {}
    } else if (_submittedSystemSpeed != null &&
        _submittedSystemSpeed != speed &&
        !_isPaused &&
        _playbackState.isActive) {
      // Native speech captures its rate when the utterance is submitted.
      await _restartSystemAt(
        _sessionId,
        _currentChunkIndex,
        _currentChunkPosition,
      );
    }
  }

  Future<String?> testNetworkService(
    TtsServiceOptions service,
    String text,
  ) async {
    final content = TtsTextSelection.stripMarkdown(text).trim();
    if (content.isEmpty) return null;
    try {
      final res = await NetworkTtsService.synthesize(
        options: service,
        text: content,
      );
      try {
        await _player.stop();
      } catch (_) {}
      if (_backgroundSpeechAllowed) {
        await _playAudioBytes(res.bytes, mime: res.mime);
      }
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  Future<void> _runNetworkQueue(int session, TtsServiceOptions service) async {
    try {
      while (session == _sessionId && _currentChunkIndex < _chunks.length) {
        if (_isPaused) {
          await Future<void>.delayed(const Duration(milliseconds: 80));
          continue;
        }
        final chunkIndex = _currentChunkIndex;
        _networkSeekInterruptedChunk = false;
        _prefetchNetworkChunks(service, session, chunkIndex);
        _currentChunkPosition = Duration.zero;
        _currentChunkDuration = null;
        _updatePlaybackState(
          status: TtsPlaybackStatus.buffering,
          currentChunkIndex: chunkIndex,
        );
        _releaseSpeechAudio();
        final file = await _networkFileFor(
          service,
          session,
          chunkIndex,
          consume: true,
        );
        if (!_backgroundSpeechAllowed && session == _sessionId) {
          _isPaused = true;
          _updatePlaybackState(status: TtsPlaybackStatus.paused);
        }
        while (_isPaused && session == _sessionId) {
          await Future<void>.delayed(const Duration(milliseconds: 80));
        }
        if (session != _sessionId) break;
        if (_currentChunkIndex != chunkIndex) continue;
        final seekOffset = _pendingNetworkSeekOffset;
        _pendingNetworkSeekOffset = Duration.zero;
        final played = await _playNetworkFile(
          file,
          session: session,
          seekOffset: seekOffset,
        );
        if (!played) continue;
        if (session != _sessionId) break;
        final wasInterruptedForSeek = _networkSeekInterruptedChunk;
        if (_currentChunkIndex == chunkIndex && !wasInterruptedForSeek) {
          _currentChunkIndex++;
        }
      }
      if (session == _sessionId) {
        _finishPlayback(status: TtsPlaybackStatus.ended);
      }
    } catch (e) {
      if (session != _sessionId) return;
      _error = e.toString();
      _finishPlayback(status: TtsPlaybackStatus.error, error: _error);
    }
  }

  void _prefetchNetworkChunks(
    TtsServiceOptions service,
    int session,
    int startIndex,
  ) {
    final end = (startIndex + _networkPrefetchCount)
        .clamp(0, _chunks.length)
        .toInt();
    for (var i = startIndex; i < end; i++) {
      _networkFileFor(service, session, i);
    }
  }

  Future<io.File> _networkFileFor(
    TtsServiceOptions service,
    int session,
    int index, {
    bool consume = false,
  }) {
    final pending = _networkCache.putIfAbsent(
      index,
      () =>
          _loadNetworkFile(service, _chunks[index].text, session, index)
            ..ignore(),
    );
    if (!consume) return pending;
    // Report a prefetch failure to its first consumer. A subsequent save or
    // playback can then retry that chunk.
    return () async {
      try {
        final file = await pending;
        if (await file.exists()) return file;
        if (session != _sessionId) throw StateError('TTS playback stopped.');
      } catch (_) {
        if (identical(_networkCache[index], pending)) {
          _networkCache.remove(index);
        }
        rethrow;
      }
      // Storage settings or the OS can clear an already-prefetched file.
      if (identical(_networkCache[index], pending)) _networkCache.remove(index);
      return _networkFileFor(service, session, index, consume: true);
    }();
  }

  Future<io.File> _loadNetworkFile(
    TtsServiceOptions service,
    String text,
    int session,
    int index,
  ) async {
    final resolved = _resolvedNetworkChunks[index];
    final cacheForReplay = _cacheNetworkAudioForReplay;
    if (!cacheForReplay && resolved != null && await resolved.exists()) {
      return resolved;
    }
    Future<io.File> generate({
      String? pathWithoutExtension,
      http.Client? client,
      required bool Function() cancelled,
    }) async {
      final result = await NetworkTtsService.synthesize(
        options: service,
        text: text,
        client: client,
        cancelled: cancelled,
      );
      if (result.bytes.isEmpty) {
        throw StateError('TTS service returned empty audio.');
      }
      final path =
          pathWithoutExtension ??
          p.join(
            (await getTemporaryDirectory()).path,
            'kelivo_tts_${const Uuid().v4()}',
          );
      if (cancelled()) throw StateError('TTS playback stopped.');
      final file = io.File('$path.${_extForMime(result.mime)}');
      try {
        await file.writeAsBytes(result.bytes, flush: true);
      } on io.FileSystemException {
        if (await file.exists()) await file.delete();
        rethrow;
      }
      if (pathWithoutExtension == null) {
        if (cancelled()) {
          await _deleteAudioFile(file);
          throw StateError('TTS playback stopped.');
        }
        _temporaryAudio.add(file);
      }
      return file;
    }

    if (cacheForReplay && _networkServiceKey == null) {
      final key = await TtsReplayCache.serviceKey(service);
      if (session != _sessionId) throw StateError('TTS playback stopped.');
      _networkServiceKey = key;
    }
    final promotingTemporary =
        cacheForReplay && resolved != null && _temporaryAudio.remove(resolved);
    late final io.File file;
    try {
      file = cacheForReplay
          ? await _replayCache.audioFile(
              key: TtsReplayCache.chunkKey(_networkServiceKey!, text),
              generate: (path, client, cancelled) async {
                // A listener may enable replay just after hearing this audio.
                if (resolved != null && await resolved.exists()) {
                  return resolved.copy('$path${p.extension(resolved.path)}');
                }
                return generate(
                  pathWithoutExtension: path,
                  client: client,
                  cancelled: cancelled,
                );
              },
            )
          : await generate(cancelled: () => session != _sessionId);
      if (session == _sessionId) _resolvedNetworkChunks[index] = file;
      return file;
    } finally {
      if (promotingTemporary) {
        if (_resolvedNetworkChunks.containsValue(resolved)) {
          _temporaryAudio.add(resolved);
        } else {
          await _deleteAudioFile(resolved);
        }
      }
    }
  }

  Future<void> _deleteAudioFile(io.File file) async {
    try {
      await file.delete();
    } on io.PathNotFoundException {
      // The system or storage settings can already have cleared this file.
    }
  }

  Future<void> _clearTemporaryAudio() {
    final files = _temporaryAudio.toList();
    _temporaryAudio.clear();
    return Future.wait(
      files.map((file) async {
        try {
          await _deleteAudioFile(file);
        } on io.FileSystemException {
          // A native player may still hold a file on Windows. Retry cleanup
          // after the next release without interrupting the new narration.
          _temporaryAudio.add(file);
        }
      }),
    );
  }

  // audioplayers reports both decoder and audio-device errors on the same
  // stream. Only a rejected media source should invalidate paid audio.
  bool _rejectedAudio(Object error) {
    if (error is! PlatformException) return false;
    final reason = '${error.message} ${error.details}'.toLowerCase();
    return switch (error.code) {
      'AndroidAudioError' =>
        reason.contains('media_error_malformed') ||
            reason.contains('media_error_unsupported') ||
            (reason.contains('failed to set source') &&
                reason.contains('media_error_system') &&
                !reason.contains('media_error_server_died')),
      'DarwinAudioError' => reason.contains('avplayeritem.status.failed'),
      'LinuxAudioError' => reason.contains('gst-stream-error-quark'),
      '3' || '4' =>
        error.message == 'MediaEngine error', // MF decode/unsupported source.
      'WindowsAudioError' =>
        reason.contains('0xc00d36c4') ||
            reason.contains('unsupported byte stream'),
      _ => false,
    };
  }

  Future<bool> _playNetworkFile(
    io.File file, {
    required int session,
    Duration seekOffset = Duration.zero,
  }) async {
    await _player.stop();
    await Future<void>.delayed(const Duration(milliseconds: 20));
    if (session != _sessionId) return false;
    if (_isPaused || !_backgroundSpeechAllowed) {
      _isPaused = true;
      _updatePlaybackState(status: TtsPlaybackStatus.paused);
      return false;
    }
    await _claimSpeechAudio();
    if (session != _sessionId) return false;
    if (_isPaused || !_backgroundSpeechAllowed) {
      _isPaused = true;
      _updatePlaybackState(status: TtsPlaybackStatus.paused);
      return false;
    }
    final chunk = Completer<void>();
    chunk.future.ignore(); // A decoder error can arrive during preparation.
    _networkChunkCompleter = chunk;
    try {
      try {
        await _player.setSource(DeviceFileSource(file.path));
      } catch (error) {
        if (_rejectedAudio(error) &&
            session == _sessionId &&
            identical(_networkChunkCompleter, chunk)) {
          await _deleteAudioFile(file);
        }
        rethrow;
      }
      if (session != _sessionId || !identical(_networkChunkCompleter, chunk)) {
        return false;
      }
      if (_isPaused || !_backgroundSpeechAllowed) {
        _isPaused = true;
        _updatePlaybackState(status: TtsPlaybackStatus.paused);
        return false;
      }
      await _player.resume();
      try {
        await _player.setPlaybackRate(_playbackState.speed);
      } catch (_) {}
      if (seekOffset > Duration.zero) {
        try {
          await _player.seek(seekOffset);
        } catch (_) {}
      }
      try {
        await chunk.future;
      } catch (error) {
        if (_rejectedAudio(error) &&
            session == _sessionId &&
            identical(_networkChunkCompleter, chunk)) {
          await _deleteAudioFile(file);
        }
        rethrow;
      }
      return true;
    } finally {
      if (identical(_networkChunkCompleter, chunk)) {
        _networkChunkCompleter = null;
      }
    }
  }

  Future<void> _speakCurrentSystemChunk(int session) async {
    if (session != _sessionId) return;
    if (_currentChunkIndex >= _chunks.length) {
      _finishPlayback(status: TtsPlaybackStatus.ended);
      return;
    }
    final chunk = _chunks[_currentChunkIndex];
    final utterance = _systemUtterance = Object();
    _submittedSystemSpeed = null;
    _currentChunkTextOffset = 0;
    _currentChunkPosition = Duration.zero;
    _updatePlaybackState(
      status: TtsPlaybackStatus.buffering,
      currentChunkIndex: _currentChunkIndex,
    );
    final ok = await _trySpeak(chunk.text, session, utterance);
    if (!ok &&
        session == _sessionId &&
        identical(utterance, _systemUtterance)) {
      _error = 'TTS speak failed';
      _finishPlayback(status: TtsPlaybackStatus.error, error: _error);
    }
  }

  Future<void> _restartSystemAt(
    int session,
    int chunkIndex,
    Duration offset, {
    TtsPlaybackStatus status = TtsPlaybackStatus.buffering,
  }) async {
    if (session != _sessionId || _chunks.isEmpty) return;
    final utterance = _systemUtterance = Object();
    _submittedSystemSpeed = null;
    _currentChunkIndex = chunkIndex.clamp(0, _chunks.length - 1).toInt();
    final chunk = _chunks[_currentChunkIndex];
    final charOffset = _charOffsetForChunkPosition(chunk, offset);
    _currentChunkTextOffset = charOffset;
    _currentChunkPosition = _estimatedPositionInChunk(chunk, charOffset);
    _updatePositionFromCurrentChunk(status: status);
    await _stopSystemTtsIgnoringCallbacks();
    if (session != _sessionId || !identical(utterance, _systemUtterance)) {
      return;
    }
    if (charOffset >= chunk.text.length) {
      _advanceSystemChunkOrFinish();
      return;
    }
    final text = chunk.text.substring(charOffset);
    final ok = await _trySpeak(text, session, utterance);
    if (!ok &&
        session == _sessionId &&
        identical(utterance, _systemUtterance)) {
      _error = 'TTS speak failed';
      _finishPlayback(status: TtsPlaybackStatus.error, error: _error);
    }
  }

  Future<bool> _trySpeak(String text, int session, Object utterance) async {
    bool isCurrent() =>
        session == _sessionId && identical(utterance, _systemUtterance);
    if (!isCurrent()) return true;
    if (_isPaused || !_backgroundSpeechAllowed) {
      _isPaused = true;
      _updatePlaybackState(status: TtsPlaybackStatus.paused);
      return true;
    }
    await _claimSpeechAudio();
    if (io.Platform.isIOS) {
      await _tts.autoStopSharedSession(false);
      await _tts.setIosAudioCategory(IosTextToSpeechAudioCategory.playback, [
        IosTextToSpeechAudioCategoryOptions.mixWithOthers,
      ], IosTextToSpeechAudioMode.spokenAudio);
      await _tts.setSharedInstance(true);
    }
    await _ensureBound();
    Future<bool> submit() async {
      double speed;
      do {
        if (!isCurrent()) return true;
        speed = _playbackState.speed;
        await _setSystemSpeechRate(TtsPlaybackSpeed.toSystemRate(speed));
        if (!isCurrent()) return true;
      } while (_playbackState.speed != speed);
      if (_isPaused || !_backgroundSpeechAllowed) {
        _isPaused = true;
        _updatePlaybackState(status: TtsPlaybackStatus.paused);
        return true;
      }
      _submittedSystemSpeed = speed;
      try {
        if (_speakOk(await _tts.speak(text, focus: true))) return true;
      } catch (_) {}
      if (!isCurrent()) return true;
      _submittedSystemSpeed = null;
      return false;
    }

    if (await submit()) return true;
    for (final recreate in [false, true]) {
      if (!isCurrent()) return true;
      if (recreate) {
        await _recreateEngine();
      } else {
        await _selectEngine();
      }
      final delay = Duration(milliseconds: recreate ? 200 : 180);
      for (var i = 0; i < 5; i++) {
        await Future<void>.delayed(delay);
        if (await submit()) return true;
      }
    }
    return false;
  }

  bool _speakOk(dynamic res) {
    if (res == null) return false;
    if (res is int) return res == 1;
    if (res is bool) return res;
    final s = res.toString().toLowerCase();
    return s == '1' || s == 'true' || s == 'success';
  }

  void _advanceSystemChunkOrFinish() {
    if (_usingNetwork || _chunks.isEmpty) return;
    if (_currentChunkIndex < _chunks.length - 1) {
      _currentChunkIndex += 1;
      unawaited(_speakCurrentSystemChunk(_sessionId));
      return;
    }
    _finishPlayback(status: TtsPlaybackStatus.ended);
  }

  Future<void> _seekToTarget(TtsSeekTarget target) async {
    _currentChunkIndex = target.chunkIndex;
    _currentChunkPosition = target.offsetInChunk;
    _updatePositionFromCurrentChunk();
    if (_usingNetwork) {
      _pendingNetworkSeekOffset = target.offsetInChunk;
      _networkSeekInterruptedChunk |= _networkChunkCompleter != null;
      _completeNetworkChunk();
      try {
        await _player.stop();
      } catch (_) {}
      return;
    }
    await _restartSystemAt(
      _sessionId,
      target.chunkIndex,
      target.offsetInChunk,
      status: _isPaused ? TtsPlaybackStatus.paused : TtsPlaybackStatus.playing,
    );
  }

  void _updatePositionFromCurrentChunk({TtsPlaybackStatus? status}) {
    if (_chunks.isEmpty) return;
    final chunkDuration =
        _currentChunkDuration ??
        _estimatedChunkDuration(_chunks[_currentChunkIndex]);
    final position = _timeline.positionForChunkProgress(
      chunkIndex: _currentChunkIndex,
      chunkPosition: _currentChunkPosition,
      chunkDuration: chunkDuration,
    );
    _updatePlaybackState(
      status: status,
      position: position,
      duration: _timeline.estimatedDuration,
      currentChunkIndex: _currentChunkIndex,
    );
  }

  void _updatePlaybackState({
    TtsPlaybackStatus? status,
    Duration? position,
    Duration? duration,
    int? currentChunkIndex,
    bool clearError = false,
  }) {
    if (status == TtsPlaybackStatus.paused) _releaseSpeechWork();
    _playbackState = _playbackState.copyWith(
      status: status,
      position: position,
      duration: duration ?? _timeline.estimatedDuration,
      currentChunkIndex: currentChunkIndex,
      totalChunks: _chunks.length,
      clearError: clearError,
      usingNetwork: _usingNetwork,
    );
    notifyListeners();
  }

  Duration _estimatedPositionInChunk(TtsTextChunk chunk, int charOffset) {
    final duration = _estimatedChunkDuration(chunk);
    if (chunk.text.isEmpty) return Duration.zero;
    final ratio = charOffset.clamp(0, chunk.text.length) / chunk.text.length;
    return Duration(milliseconds: (duration.inMilliseconds * ratio).round());
  }

  Duration _estimatedChunkDuration(TtsTextChunk chunk) {
    final ms = (chunk.text.length * 200).clamp(1000, 60000).toInt();
    return Duration(milliseconds: ms);
  }

  int _charOffsetForChunkPosition(TtsTextChunk chunk, Duration position) {
    final duration = _estimatedChunkDuration(chunk);
    if (duration <= Duration.zero || chunk.text.isEmpty) return 0;
    final ratio = (position.inMilliseconds / duration.inMilliseconds).clamp(
      0.0,
      1.0,
    );
    return (chunk.text.length * ratio)
        .round()
        .clamp(0, chunk.text.length)
        .toInt();
  }

  void _finishPlayback({required TtsPlaybackStatus status, String? error}) {
    _systemUtterance = null;
    _submittedSystemSpeed = null;
    _releaseSpeechWork();
    _isSpeaking = false;
    _isPaused = false;
    _usingNetwork = false;
    _networkSeekInterruptedChunk = false;
    _networkCache.clear();
    final position = status == TtsPlaybackStatus.ended
        ? _timeline.estimatedDuration
        : _playbackState.position;
    _playbackState = _playbackState.copyWith(
      status: status,
      position: position,
      errorMessage: error,
      usingNetwork: false,
    );
    if (_speakingCompleter != null && !_speakingCompleter!.isCompleted) {
      _speakingCompleter!.complete();
    }
    _speakingCompleter = null;
    notifyListeners();
  }

  Future<void> _stopPlaybackEngines() async {
    _completeNetworkChunk();
    try {
      await _player.stop();
    } catch (_) {}
    await _stopSystemTtsIgnoringCallbacks();
  }

  void _stopInternal({bool updateState = false}) {
    _systemUtterance = null;
    _submittedSystemSpeed = null;
    _previewPlaying = false;
    _releaseSpeechWork();
    _chunks.clear();
    _networkCache.clear();
    _resolvedNetworkChunks.clear();
    _currentChunkIndex = 0;
    _currentChunkTextOffset = 0;
    _currentChunkPosition = Duration.zero;
    _currentChunkDuration = null;
    _pendingNetworkSeekOffset = Duration.zero;
    _networkSeekInterruptedChunk = false;
    _isSpeaking = false;
    _isPaused = false;
    _usingNetwork = false;
    _lastReplayContent = null;
    _lastReplayNetworkService = null;
    _networkServiceKey = null;
    _timeline = TtsPlaybackTimeline(const <TtsTextChunk>[]);
    _playbackState = TtsPlaybackState(speed: _playbackState.speed);
    _completeNetworkChunk();
    if (_speakingCompleter != null && !_speakingCompleter!.isCompleted) {
      _speakingCompleter!.complete();
    }
    _speakingCompleter = null;
    if (updateState) notifyListeners();
  }

  void _completeNetworkChunk() {
    final completer = _networkChunkCompleter;
    if (completer != null && !completer.isCompleted) {
      completer.complete();
    }
    _networkChunkCompleter = null;
  }

  Future<void> _stopSystemTtsIgnoringCallbacks() async {
    _ignoreTtsStopCallbacks = true;
    try {
      await _tts.stop();
    } catch (_) {}
    await Future<void>.delayed(const Duration(milliseconds: 20));
    _ignoreTtsStopCallbacks = false;
  }

  static String _localeToTag(ui.Locale l) {
    final lang = l.languageCode;
    final country = l.countryCode;
    if (country != null && country.isNotEmpty) return '$lang-$country';
    return lang;
  }

  Future<void> _playAudioBytes(Uint8List bytes, {String? mime}) async {
    final session = _sessionId;
    try {
      await _player.stop();
      await Future<void>.delayed(const Duration(milliseconds: 20));
    } catch (_) {}
    try {
      final ext = _extForMime(mime);
      final dir = await getTemporaryDirectory();
      final path = p.join(
        dir.path,
        'kelivo_tts_${DateTime.now().millisecondsSinceEpoch}.$ext',
      );
      final f = io.File(path);
      await f.writeAsBytes(bytes, flush: true);
      if (session != _sessionId || !_backgroundSpeechAllowed) return;
      await _claimSpeechAudio();
      if (session != _sessionId || !_backgroundSpeechAllowed) {
        _releaseSpeechWork();
        return;
      }
      _previewPlaying = true;
      await _player.play(DeviceFileSource(path));
    } catch (e) {
      _releaseSpeechWork();
      _previewPlaying = false;
      _error = e.toString();
      _isSpeaking = false;
      notifyListeners();
    }
  }

  String _extForMime(String? mime) => ttsAudioFileExtensionForMime(mime);

  Future<(Uint8List, String)?> synthesizeAllAndCollect() async {
    final service = _lastReplayNetworkService;
    if (_readySessionId != _sessionId || service == null || _chunks.isEmpty) {
      return null;
    }

    final session = _sessionId;
    final files = <io.File>[];
    for (var i = 0; i < _chunks.length; i++) {
      final played = _resolvedNetworkChunks[i];
      if (played != null && await played.exists()) {
        files.add(played);
      } else {
        if (session != _sessionId) return null;
        files.add(await _networkFileFor(service, session, i, consume: true));
      }
      if (session != _sessionId) return null;
    }
    final suffix = p.extension(files.first.path);
    if (files.any((file) => p.extension(file.path) != suffix)) {
      throw StateError('TTS audio chunks use different formats.');
    }
    final extension = suffix.substring(1);
    if (extension == 'flac' && files.length > 1) {
      throw StateError('FLAC TTS chunks cannot be exported as one audio file.');
    }

    final parts = <Uint8List>[];
    for (final file in files) {
      parts.add(await file.readAsBytes());
      if (session != _sessionId) return null;
    }
    if (extension == 'wav') return (combineWavAudio(parts), extension);
    if (parts.length == 1) return (parts.single, extension);
    final bytes = BytesBuilder(copy: false);
    for (final part in parts) {
      bytes.add(part);
    }
    return (bytes.takeBytes(), extension);
  }

  Future<TtsServiceOptions?> _getSelectedNetworkService() async {
    try {
      await preferences.load();
      final jsonStr = preferences.getString('tts_services_v1') ?? '';
      if (jsonStr.isEmpty) return null;
      final list = jsonDecode(jsonStr) as List;
      final selectedId = preferences.getString('tts_selected_service_id_v1');
      if (selectedId != null && selectedId.isNotEmpty) {
        for (final obj in list) {
          final map = obj is Map<String, dynamic>
              ? obj
              : Map<String, dynamic>.from(obj as Map);
          if ((map['id'] ?? '').toString() == selectedId) {
            return TtsServiceOptions.fromJson(map);
          }
        }
        return null;
      }

      // Compatibility for profiles not yet loaded by SettingsProvider.
      final legacyIndex = preferences.getInt('tts_selected_v1') ?? -1;
      if (legacyIndex < 0 || legacyIndex >= list.length) return null;
      final obj = list[legacyIndex];
      return TtsServiceOptions.fromJson(
        obj is Map<String, dynamic>
            ? obj
            : Map<String, dynamic>.from(obj as Map),
      );
    } catch (_) {
      return null;
    }
  }

  @override
  void dispose() {
    _sessionId++;
    _replayCache.retain({});
    _completeNetworkChunk();
    _speakingCompleter?.complete();
    _speakingCompleter = null;
    _playerEventSub?.cancel();
    _playerPositionSub?.cancel();
    _playerStateSub?.cancel();
    _ignoreTtsStopCallbacks = true;
    unawaited(_disposePlaybackResources());
    super.dispose();
  }

  Future<void> _disposePlaybackResources() async {
    try {
      await _tts.stop();
    } catch (_) {}
    try {
      await _player.dispose();
    } catch (_) {}
    await _clearTemporaryAudio();
  }
}
