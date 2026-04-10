import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

typedef VoiceMessagePlaybackPlay = Future<void> Function(String path);
typedef VoiceMessagePlaybackAction = Future<void> Function();

class VoiceMessagePlaybackProvider extends ChangeNotifier {
  VoiceMessagePlaybackProvider({
    VoiceMessagePlaybackPlay? play,
    VoiceMessagePlaybackAction? stop,
    VoiceMessagePlaybackAction? disposePlayer,
    Stream<void>? completionStream,
    Stream<Duration>? positionStream,
    Stream<Duration>? durationStream,
  }) : _play = play,
       _stop = stop,
       _disposePlayer = disposePlayer {
    if (_play == null ||
        _stop == null ||
        _disposePlayer == null ||
        completionStream == null ||
        positionStream == null ||
        durationStream == null) {
      final player = AudioPlayer();
      _play ??= (path) => player.play(DeviceFileSource(path));
      _stop ??= player.stop;
      _disposePlayer ??= player.dispose;
      completionStream ??= player.onPlayerComplete.map((_) {});
      positionStream ??= player.onPositionChanged;
      durationStream ??= player.onDurationChanged;
    }

    _completionSub = completionStream.listen((_) {
      _clearPlaybackState();
    });
    _positionSub = positionStream.listen(_updatePosition);
    _durationSub = durationStream.listen(_updateDuration);
  }

  VoiceMessagePlaybackPlay? _play;
  VoiceMessagePlaybackAction? _stop;
  VoiceMessagePlaybackAction? _disposePlayer;
  StreamSubscription<void>? _completionSub;
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<Duration>? _durationSub;

  String? _currentPlaybackId;
  Duration _currentPosition = Duration.zero;
  Duration _currentDuration = Duration.zero;
  bool _actionInFlight = false;

  String? get currentPlaybackId => _currentPlaybackId;
  Duration get currentPosition => _currentPosition;
  Duration get currentDuration => _currentDuration;

  bool isPlayingItem(String playbackId) => _currentPlaybackId == playbackId;

  double progressFor(String playbackId) {
    if (!isPlayingItem(playbackId)) return 0;
    final totalMs = _currentDuration.inMilliseconds;
    if (totalMs <= 0) return 0;
    return (_currentPosition.inMilliseconds / totalMs).clamp(0, 1).toDouble();
  }

  Duration? remainingFor(String playbackId) {
    if (!isPlayingItem(playbackId)) return null;
    final remaining = _currentDuration - _currentPosition;
    return remaining.isNegative ? Duration.zero : remaining;
  }

  Future<void> toggle({
    required String playbackId,
    required String path,
    Duration? fallbackDuration,
    Future<void> Function()? beforePlay,
  }) async {
    if (_actionInFlight) return;

    _actionInFlight = true;
    try {
      if (isPlayingItem(playbackId)) {
        await stop();
        return;
      }

      if (beforePlay != null) {
        await beforePlay();
      }
      await play(
        playbackId: playbackId,
        path: path,
        fallbackDuration: fallbackDuration,
      );
    } finally {
      _actionInFlight = false;
    }
  }

  Future<void> play({
    required String playbackId,
    required String path,
    Duration? fallbackDuration,
  }) async {
    await stop();

    _currentPlaybackId = playbackId;
    _currentPosition = Duration.zero;
    _currentDuration = _sanitizeDuration(fallbackDuration);
    notifyListeners();

    try {
      await _play!(path);
    } catch (_) {
      _clearPlaybackState();
      rethrow;
    }
  }

  Future<void> stop() async {
    final hadPlayback =
        _currentPlaybackId != null ||
        _currentPosition > Duration.zero ||
        _currentDuration > Duration.zero;
    _currentPlaybackId = null;
    _currentPosition = Duration.zero;
    _currentDuration = Duration.zero;
    if (hadPlayback) {
      notifyListeners();
    }
    try {
      await _stop!();
    } catch (_) {}
  }

  void _clearPlaybackState() {
    if (_currentPlaybackId == null &&
        _currentPosition == Duration.zero &&
        _currentDuration == Duration.zero) {
      return;
    }
    _currentPlaybackId = null;
    _currentPosition = Duration.zero;
    _currentDuration = Duration.zero;
    notifyListeners();
  }

  void _updatePosition(Duration position) {
    if (_currentPlaybackId == null) return;
    final sanitized = _sanitizeDuration(position);
    final next =
        _currentDuration > Duration.zero && sanitized > _currentDuration
        ? _currentDuration
        : sanitized;
    if (next == _currentPosition) return;
    _currentPosition = next;
    notifyListeners();
  }

  void _updateDuration(Duration duration) {
    if (_currentPlaybackId == null) return;
    final sanitized = _sanitizeDuration(duration);
    if (sanitized == Duration.zero && _currentDuration > Duration.zero) {
      return;
    }
    if (sanitized == _currentDuration) return;
    _currentDuration = sanitized;
    if (_currentPosition > _currentDuration) {
      _currentPosition = _currentDuration;
    }
    notifyListeners();
  }

  Duration _sanitizeDuration(Duration? duration) {
    if (duration == null || duration.isNegative) return Duration.zero;
    return duration;
  }

  @override
  void dispose() {
    _completionSub?.cancel();
    _positionSub?.cancel();
    _durationSub?.cancel();
    try {
      _disposePlayer?.call();
    } catch (_) {}
    super.dispose();
  }
}
