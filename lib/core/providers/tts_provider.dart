import 'dart:async';
import 'dart:convert';
import 'dart:io' as io;
import 'dart:ui' as ui;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/tts/network_tts.dart';
import '../services/tts/tts_playback_models.dart';
import '../services/tts/tts_text_chunker.dart';

/// System and network TTS coordinator.
///
/// Long text is split into smaller chunks. Network TTS chunks are prefetched
/// while the current chunk is playing; system TTS chunks are sequenced through
/// flutter_tts with progress callbacks.
class TtsProvider extends ChangeNotifier {
  static const String _rateKey = 'tts_speech_rate_v1';
  static const String _pitchKey = 'tts_pitch_v1';
  static const String _engineKey = 'tts_engine_v1';
  static const String _langKey = 'tts_language_v1';
  static const int _systemChunkMaxLength = 360;
  static const int _networkChunkMaxLength = 220;
  static const int _networkPrefetchCount = 3;
  static const Duration _seekStep = Duration(seconds: 15);

  late FlutterTts _tts;
  final AudioPlayer _player = AudioPlayer();

  final List<TtsTextChunk> _chunks = <TtsTextChunk>[];
  final Map<int, Future<NetworkTtsResult>> _networkCache =
      <int, Future<NetworkTtsResult>>{};

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

  // Settings
  double _speechRate = 0.5; // flutter_tts platform value, 0.5 is normal.
  double _pitch = 1.0;
  String? _engineId;
  String? _languageTag;

  int _sessionId = 0;
  int _currentChunkIndex = 0;
  int _currentChunkTextOffset = 0;
  Duration _currentChunkPosition = Duration.zero;
  Duration? _currentChunkDuration;
  Duration _pendingNetworkSeekOffset = Duration.zero;
  Completer<void>? _speakingCompleter;
  Completer<void>? _networkChunkCompleter;

  StreamSubscription<void>? _playerCompleteSub;
  StreamSubscription<Duration>? _playerPositionSub;
  StreamSubscription<Duration>? _playerDurationSub;
  StreamSubscription<PlayerState>? _playerStateSub;

  bool get isAvailable => _initialized;
  bool get isSpeaking => _isSpeaking;
  bool get isPaused => _isPaused;
  bool get usingNetwork => _usingNetwork;
  String? get error => _error;
  double get speechRate => _speechRate;
  double get pitch => _pitch;
  String? get engineId => _engineId;
  String? get languageTag => _languageTag;
  TtsPlaybackState get playbackState => _playbackState;
  Duration get seekStep => _seekStep;

  TtsProvider() {
    _init();
  }

  Future<void> _init() async {
    try {
      _tts = FlutterTts();
      final prefs = await SharedPreferences.getInstance();
      _speechRate = (prefs.getDouble(_rateKey) ?? 0.5)
          .clamp(0.1, 1.0)
          .toDouble();
      _pitch = (prefs.getDouble(_pitchKey) ?? 1.0).clamp(0.5, 2.0).toDouble();
      _engineId = prefs.getString(_engineKey);
      _languageTag = prefs.getString(_langKey);
      _playbackState = _playbackState.copyWith(
        speed: TtsPlaybackSpeed.normalize(_speechRate * 2),
      );

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
    _playerCompleteSub = _player.onPlayerComplete.listen((_) {
      _completeNetworkChunk();
    });
    _playerPositionSub = _player.onPositionChanged.listen((position) {
      if (!_usingNetwork || _chunks.isEmpty) return;
      _currentChunkPosition = position;
      _updatePositionFromCurrentChunk();
    });
    _playerDurationSub = _player.onDurationChanged.listen((duration) {
      if (!_usingNetwork || _chunks.isEmpty) return;
      _currentChunkDuration = duration;
      _updatePositionFromCurrentChunk();
    });
    _playerStateSub = _player.onPlayerStateChanged.listen((state) {
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

  Future<void> _applyConfig() async {
    try {
      await _tts.setSpeechRate(_speechRate);
    } catch (_) {}
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
    if (_speechRate == r) return;
    _speechRate = r;
    if (!_playbackState.isActive) {
      _playbackState = _playbackState.copyWith(
        speed: TtsPlaybackSpeed.normalize(_speechRate * 2),
      );
    }
    try {
      await _tts.setSpeechRate(_speechRate);
    } catch (_) {}
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_rateKey, _speechRate);
  }

  Future<void> setPitch(double v) async {
    final p = v.clamp(0.5, 2.0).toDouble();
    if (_pitch == p) return;
    _pitch = p;
    try {
      await _tts.setPitch(_pitch);
    } catch (_) {}
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_pitchKey, _pitch);
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
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_engineKey, id);
    try {
      await _tts.setEngine(id);
    } catch (_) {}
    await _applyConfig();
    notifyListeners();
  }

  Future<void> setLanguageTag(String tag) async {
    _languageTag = tag;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_langKey, tag);
    try {
      await _tts.setLanguage(tag);
    } catch (_) {}
    notifyListeners();
  }

  Future<void> speak(String text, {bool flush = true}) async {
    if (!_initialized) return;
    final selected = await _getSelectedNetworkService();
    if (selected != null && selected.enabled) {
      return _speakQueued(text, networkService: selected, flush: flush);
    }
    return _speakQueued(text, flush: flush);
  }

  Future<void> speakSystem(String text, {bool flush = true}) async {
    if (!_initialized) return;
    return _speakQueued(text, flush: flush);
  }

  Future<void> speakWithNetworkService(
    TtsServiceOptions service,
    String text, {
    bool flush = true,
  }) async {
    await _speakQueued(text, networkService: service, flush: flush);
  }

  Future<void> _speakQueued(
    String text, {
    TtsServiceOptions? networkService,
    bool flush = true,
  }) async {
    final content = _stripMarkdown(text).trim();
    if (content.isEmpty) return;
    if (flush) await _stopPlaybackEngines();
    _lastReplayContent = content;
    _lastReplayNetworkService = networkService;

    final session = ++_sessionId;
    _usingNetwork = networkService != null;
    _networkCache.clear();
    _chunks
      ..clear()
      ..addAll(
        TtsTextChunker.split(
          content,
          maxChunkLength: _usingNetwork
              ? _networkChunkMaxLength
              : _systemChunkMaxLength,
        ),
      );
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
      speed: _playbackState.speed,
      totalChunks: _chunks.length,
      usingNetwork: _usingNetwork,
    );
    notifyListeners();

    if (_usingNetwork) {
      unawaited(_runNetworkQueue(session, networkService!));
    } else {
      await _ensureBound();
      await _speakCurrentSystemChunk(session);
    }
    return playbackFuture;
  }

  Future<void> pause() async {
    if (!_initialized || !_isSpeaking || _isPaused) return;
    if (_usingNetwork) {
      await _player.pause();
      _isPaused = true;
      _updatePlaybackState(status: TtsPlaybackStatus.paused);
      return;
    }
    await _ensureBound();
    try {
      await _tts.pause();
    } catch (_) {}
    _isPaused = true;
    _updatePlaybackState(status: TtsPlaybackStatus.paused);
  }

  Future<void> resume() async {
    if (!_initialized || !_isPaused) return;
    if (_usingNetwork) {
      await _player.resume();
      _isPaused = false;
      _updatePlaybackState(status: TtsPlaybackStatus.playing);
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
    await _speakQueued(
      content,
      networkService: _lastReplayNetworkService,
      flush: true,
    );
  }

  Future<void> stop() async {
    _sessionId++;
    await _stopPlaybackEngines();
    _stopInternal(updateState: true);
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
    _playbackState = _playbackState.copyWith(speed: normalized);
    if (_usingNetwork) {
      try {
        await _player.setPlaybackRate(normalized);
      } catch (_) {}
    } else {
      try {
        await _tts.setSpeechRate(TtsPlaybackSpeed.toSystemRate(normalized));
      } catch (_) {}
      if (_playbackState.isActive && !_isPaused) {
        await _restartSystemAt(
          _sessionId,
          _currentChunkIndex,
          _currentChunkPosition,
        );
      }
    }
    notifyListeners();
  }

  Future<String?> testNetworkService(
    TtsServiceOptions service,
    String text,
  ) async {
    final content = _stripMarkdown(text).trim();
    if (content.isEmpty) return null;
    try {
      final res = await NetworkTtsService.synthesize(
        options: service,
        text: content,
      );
      try {
        await _player.stop();
      } catch (_) {}
      await _playAudioBytes(res.bytes, mime: res.mime);
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
        _prefetchNetworkChunks(service, session, chunkIndex);
        _currentChunkPosition = Duration.zero;
        _currentChunkDuration = null;
        _updatePlaybackState(
          status: TtsPlaybackStatus.buffering,
          currentChunkIndex: chunkIndex,
        );
        final result = await _networkResultFor(service, session, chunkIndex);
        if (session != _sessionId) break;
        if (_currentChunkIndex != chunkIndex) continue;
        final seekOffset = _pendingNetworkSeekOffset;
        _pendingNetworkSeekOffset = Duration.zero;
        await _playNetworkResult(result, seekOffset: seekOffset);
        if (session != _sessionId) break;
        final wasInterruptedForSeek = _networkSeekInterruptedChunk;
        _networkSeekInterruptedChunk = false;
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
      _networkResultFor(service, session, i);
    }
  }

  Future<NetworkTtsResult> _networkResultFor(
    TtsServiceOptions service,
    int session,
    int index,
  ) {
    return _networkCache.putIfAbsent(index, () {
      return NetworkTtsService.synthesize(
        options: service,
        text: _chunks[index].text,
        cancelled: () => session != _sessionId,
      );
    });
  }

  Future<void> _playNetworkResult(
    NetworkTtsResult result, {
    Duration seekOffset = Duration.zero,
  }) async {
    await _player.stop();
    await Future<void>.delayed(const Duration(milliseconds: 20));
    final ext = _extForMime(result.mime);
    final dir = await getTemporaryDirectory();
    final path = p.join(
      dir.path,
      'kelivo_tts_${DateTime.now().microsecondsSinceEpoch}.$ext',
    );
    final f = io.File(path);
    await f.writeAsBytes(result.bytes, flush: true);

    final chunkCompleter = Completer<void>();
    _networkChunkCompleter = chunkCompleter;
    await _player.play(DeviceFileSource(path));
    try {
      await _player.setPlaybackRate(_playbackState.speed);
    } catch (_) {}
    if (seekOffset > Duration.zero) {
      try {
        await _player.seek(seekOffset);
      } catch (_) {}
    }
    await chunkCompleter.future;
  }

  Future<void> _speakCurrentSystemChunk(int session) async {
    if (session != _sessionId || _currentChunkIndex >= _chunks.length) {
      _finishPlayback(status: TtsPlaybackStatus.ended);
      return;
    }
    final chunk = _chunks[_currentChunkIndex];
    _currentChunkTextOffset = 0;
    _currentChunkPosition = Duration.zero;
    _updatePlaybackState(
      status: TtsPlaybackStatus.buffering,
      currentChunkIndex: _currentChunkIndex,
    );
    final ok = await _trySpeak(chunk.text);
    if (!ok && session == _sessionId) {
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
    _currentChunkIndex = chunkIndex.clamp(0, _chunks.length - 1).toInt();
    final chunk = _chunks[_currentChunkIndex];
    final charOffset = _charOffsetForChunkPosition(chunk, offset);
    _currentChunkTextOffset = charOffset;
    _currentChunkPosition = _estimatedPositionInChunk(chunk, charOffset);
    _updatePositionFromCurrentChunk(status: status);
    await _stopSystemTtsIgnoringCallbacks();
    if (charOffset >= chunk.text.length) {
      _advanceSystemChunkOrFinish();
      return;
    }
    final text = chunk.text.substring(charOffset);
    final ok = await _trySpeak(text);
    if (!ok && session == _sessionId) {
      _error = 'TTS speak failed';
      _finishPlayback(status: TtsPlaybackStatus.error, error: _error);
    }
  }

  Future<bool> _trySpeak(String text) async {
    await _ensureBound();
    try {
      await _tts.setSpeechRate(
        TtsPlaybackSpeed.toSystemRate(_playbackState.speed),
      );
    } catch (_) {}
    dynamic res;
    try {
      res = await _tts.speak(text, focus: true);
    } catch (_) {}
    if (_speakOk(res)) return true;
    await _selectEngine();
    for (var i = 0; i < 5; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 180));
      try {
        res = await _tts.speak(text, focus: true);
      } catch (_) {}
      if (_speakOk(res)) return true;
    }
    await _recreateEngine();
    for (var i = 0; i < 5; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 200));
      try {
        res = await _tts.speak(text, focus: true);
      } catch (_) {}
      if (_speakOk(res)) return true;
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
      _networkSeekInterruptedChunk = _networkChunkCompleter != null;
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
    _chunks.clear();
    _networkCache.clear();
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

  static String _stripMarkdown(String input) {
    var s = input;
    s = s.replaceAll(RegExp(r'```[\s\S]*?```', multiLine: true), ' ');
    s = s.replaceAll(RegExp(r'`[^`]*`'), ' ');
    s = s.replaceAllMapped(
      RegExp(r'\[([^\]]+)\]\([^\)]+\)'),
      (m) => m.group(1) ?? '',
    );
    s = s.replaceAll(RegExp(r'!\[[^\]]*\]\([^\)]*\)'), ' ');
    s = s.replaceAll(RegExp(r'^[#>\-\*\+]+\s*', multiLine: true), '');
    s = s.replaceAll(RegExp(r'[*_~]{1,3}'), '');
    s = s.replaceAll('|', ' ');
    s = s.replaceAll(RegExp(r'\s+'), ' ');
    return s;
  }

  Future<void> _playAudioBytes(Uint8List bytes, {String? mime}) async {
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
      await _player.play(DeviceFileSource(path));
    } catch (e) {
      _error = e.toString();
      _isSpeaking = false;
      notifyListeners();
    }
  }

  String _extForMime(String? mime) {
    switch ((mime ?? '').toLowerCase()) {
      case 'audio/mpeg':
      case 'audio/mp3':
        return 'mp3';
      case 'audio/wav':
      case 'audio/x-wav':
        return 'wav';
      case 'audio/ogg':
        return 'ogg';
      default:
        return 'mp3';
    }
  }

  Future<TtsServiceOptions?> _getSelectedNetworkService() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final selected = prefs.getInt('tts_selected_v1') ?? -1;
      if (selected < 0) return null;
      final jsonStr = prefs.getString('tts_services_v1') ?? '';
      if (jsonStr.isEmpty) return null;
      final list = jsonDecode(jsonStr) as List;
      if (selected >= list.length) return null;
      final obj = list[selected];
      final map = obj is Map<String, dynamic>
          ? obj
          : Map<String, dynamic>.from(obj as Map);
      return TtsServiceOptions.fromJson(map);
    } catch (_) {
      return null;
    }
  }

  @override
  void dispose() {
    _sessionId++;
    _playerCompleteSub?.cancel();
    _playerPositionSub?.cancel();
    _playerDurationSub?.cancel();
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
  }
}
