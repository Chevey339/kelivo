import 'dart:async';
import 'dart:typed_data';

// ignore: depend_on_referenced_packages
import 'package:audioplayers_platform_interface/audioplayers_platform_interface.dart';

/// In-memory audioplayers backend. Calls are recorded against the source
/// their player holds, source loads can be held open per path, and events can
/// be pushed to the player of one source.
class FakeAudioplayersPlatform extends AudioplayersPlatformInterface {
  final List<String> calls = <String>[];
  final Map<String, StreamController<AudioEvent>> _events = {};
  final Map<String, String> _sourceOf = {};

  /// Loads of these paths wait until their completer finishes.
  final Map<String, Completer<void>> sourceGates = {};

  List<String> get sources => [
    for (final call in calls)
      if (call.startsWith('source:')) call.substring('source:'.length),
  ];

  List<String> get resumed => [
    for (final call in calls)
      if (call.startsWith('resume:')) call.substring('resume:'.length),
  ];

  Iterable<StreamController<AudioEvent>> _playersOf(String path) => [
    for (final entry in _sourceOf.entries)
      if (entry.value == path && _events[entry.key] != null)
        _events[entry.key]!,
  ];

  void completePlayback(String path) {
    for (final events in _playersOf(path)) {
      events.add(const AudioEvent(eventType: AudioEventType.complete));
    }
  }

  void failPlayback(String path, Object error) {
    for (final events in _playersOf(path)) {
      events.addError(error);
    }
  }

  @override
  Future<void> create(String playerId) async {
    _events[playerId] = StreamController<AudioEvent>.broadcast();
  }

  @override
  Stream<AudioEvent> getEventStream(String playerId) =>
      _events[playerId]!.stream;

  @override
  Future<void> stop(String playerId) async {
    calls.add('stop:${_sourceOf[playerId]}');
  }

  @override
  Future<void> setSourceUrl(
    String playerId,
    String url, {
    bool? isLocal,
    String? mimeType,
  }) async {
    calls.add('source:$url');
    _sourceOf[playerId] = url;
    await sourceGates[url]?.future;
    scheduleMicrotask(
      () => _events[playerId]?.add(
        const AudioEvent(eventType: AudioEventType.prepared, isPrepared: true),
      ),
    );
  }

  @override
  Future<void> resume(String playerId) async {
    calls.add('resume:${_sourceOf[playerId]}');
    // Every clip reports a 12 s length once it starts playing.
    scheduleMicrotask(
      () => _events[playerId]?.add(
        const AudioEvent(
          eventType: AudioEventType.duration,
          duration: Duration(seconds: 12),
        ),
      ),
    );
  }

  @override
  Future<void> pause(String playerId) async =>
      calls.add('pause:${_sourceOf[playerId]}');

  @override
  Future<void> dispose(String playerId) async {
    calls.add('dispose:${_sourceOf[playerId]}');
    await _events.remove(playerId)?.close();
  }

  @override
  Future<void> release(String playerId) async {}

  @override
  Future<void> seek(String playerId, Duration position) async {}

  @override
  Future<void> setBalance(String playerId, double balance) async {}

  @override
  Future<void> setVolume(String playerId, double volume) async {}

  @override
  Future<void> setReleaseMode(String playerId, ReleaseMode releaseMode) async {}

  @override
  Future<void> setPlaybackRate(String playerId, double playbackRate) async {}

  @override
  Future<void> setSourceBytes(
    String playerId,
    Uint8List bytes, {
    String? mimeType,
  }) async {}

  @override
  Future<void> setAudioContext(
    String playerId,
    AudioContext audioContext,
  ) async {}

  @override
  Future<void> setPlayerMode(String playerId, PlayerMode playerMode) async {}

  @override
  Future<int?> getDuration(String playerId) async => null;

  @override
  Future<int?> getCurrentPosition(String playerId) async => 0;

  @override
  Future<void> emitLog(String playerId, String message) async {}

  @override
  Future<void> emitError(String playerId, String code, String message) async {}
}

class FakeGlobalAudioplayersPlatform
    extends GlobalAudioplayersPlatformInterface {
  @override
  Future<void> init() async {}

  @override
  Future<void> setGlobalAudioContext(AudioContext ctx) async {}

  @override
  Future<void> emitGlobalLog(String message) async {}

  @override
  Future<void> emitGlobalError(String code, String message) async {}

  @override
  Stream<GlobalAudioEvent> getGlobalEventStream() => const Stream.empty();
}
