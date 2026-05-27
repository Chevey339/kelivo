import 'tts_text_chunker.dart';

enum TtsPlaybackStatus { idle, buffering, playing, paused, ended, error }

class TtsPlaybackState {
  const TtsPlaybackState({
    this.status = TtsPlaybackStatus.idle,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.speed = 1.0,
    this.currentChunkIndex = 0,
    this.totalChunks = 0,
    this.errorMessage,
    this.usingNetwork = false,
  });

  final TtsPlaybackStatus status;
  final Duration position;
  final Duration duration;
  final double speed;
  final int currentChunkIndex;
  final int totalChunks;
  final String? errorMessage;
  final bool usingNetwork;

  bool get isActive =>
      status == TtsPlaybackStatus.buffering ||
      status == TtsPlaybackStatus.playing ||
      status == TtsPlaybackStatus.paused;

  bool get isPlayerVisible => isActive || status == TtsPlaybackStatus.ended;

  double get progress {
    if (duration <= Duration.zero) return 0;
    return (position.inMilliseconds / duration.inMilliseconds)
        .clamp(0.0, 1.0)
        .toDouble();
  }

  TtsPlaybackState copyWith({
    TtsPlaybackStatus? status,
    Duration? position,
    Duration? duration,
    double? speed,
    int? currentChunkIndex,
    int? totalChunks,
    String? errorMessage,
    bool clearError = false,
    bool? usingNetwork,
  }) {
    return TtsPlaybackState(
      status: status ?? this.status,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      speed: speed ?? this.speed,
      currentChunkIndex: currentChunkIndex ?? this.currentChunkIndex,
      totalChunks: totalChunks ?? this.totalChunks,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      usingNetwork: usingNetwork ?? this.usingNetwork,
    );
  }
}

class TtsSeekTarget {
  const TtsSeekTarget({
    required this.chunkIndex,
    required this.offsetInChunk,
    required this.position,
  });

  final int chunkIndex;
  final Duration offsetInChunk;
  final Duration position;
}

class TtsPlaybackTimeline {
  TtsPlaybackTimeline(
    List<TtsTextChunk> chunks, {
    this.millisecondsPerCharacter = 200,
  }) : chunks = List.unmodifiable(chunks);

  final List<TtsTextChunk> chunks;
  final int millisecondsPerCharacter;

  Duration get estimatedDuration {
    final total = chunks.fold<int>(
      0,
      (sum, chunk) => sum + _durationForChunk(chunk).inMilliseconds,
    );
    return Duration(milliseconds: total);
  }

  Duration positionForChunkProgress({
    required int chunkIndex,
    required Duration chunkPosition,
    Duration? chunkDuration,
  }) {
    final clampedIndex = _clampChunkIndex(chunkIndex);
    var elapsed = Duration.zero;
    for (var i = 0; i < clampedIndex; i++) {
      elapsed += _durationForChunk(chunks[i]);
    }
    final duration = chunkDuration ?? _durationForChunk(chunks[clampedIndex]);
    final clampedPosition = _clampDuration(chunkPosition, duration);
    return _clampDuration(elapsed + clampedPosition, estimatedDuration);
  }

  TtsSeekTarget seekTarget({
    required Duration currentPosition,
    required Duration delta,
  }) {
    final target = _clampDuration(currentPosition + delta, estimatedDuration);
    var remaining = target;
    for (var i = 0; i < chunks.length; i++) {
      final duration = _durationForChunk(chunks[i]);
      if (remaining <= duration || i == chunks.length - 1) {
        return TtsSeekTarget(
          chunkIndex: i,
          offsetInChunk: _clampDuration(remaining, duration),
          position: target,
        );
      }
      remaining -= duration;
    }
    return const TtsSeekTarget(
      chunkIndex: 0,
      offsetInChunk: Duration.zero,
      position: Duration.zero,
    );
  }

  Duration offsetForChunk(int chunkIndex) {
    final clampedIndex = _clampChunkIndex(chunkIndex);
    var elapsed = Duration.zero;
    for (var i = 0; i < clampedIndex; i++) {
      elapsed += _durationForChunk(chunks[i]);
    }
    return elapsed;
  }

  Duration _durationForChunk(TtsTextChunk chunk) {
    final ms = (chunk.text.length * millisecondsPerCharacter)
        .clamp(1000, 60000)
        .toInt();
    return Duration(milliseconds: ms);
  }

  int _clampChunkIndex(int index) {
    if (chunks.isEmpty) return 0;
    return index.clamp(0, chunks.length - 1).toInt();
  }

  static Duration _clampDuration(Duration value, Duration max) {
    if (value < Duration.zero) return Duration.zero;
    if (value > max) return max;
    return value;
  }
}

class TtsPlaybackSpeed {
  const TtsPlaybackSpeed._();

  static const List<double> values = <double>[0.8, 1.0, 1.2, 1.5, 2.0];

  static double next(double current) {
    final index = values.indexWhere((value) => (value - current).abs() < 0.01);
    if (index == -1 || index == values.length - 1) return values.first;
    return values[index + 1];
  }

  static double normalize(double value) =>
      value.clamp(values.first, values.last).toDouble();

  static double toSystemRate(double speed) =>
      (speed / 2).clamp(0.1, 1.0).toDouble();
}
