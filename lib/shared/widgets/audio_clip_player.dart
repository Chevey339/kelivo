import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

import '../../icons/lucide_adapter.dart';
import '../../l10n/app_localizations.dart';
import 'ios_tactile.dart';
import 'snackbar.dart';

/// What the shared clip player is doing; `null` in [AudioClipPlayback.status]
/// means nothing is loaded.
@immutable
class AudioClipStatus {
  const AudioClipStatus({
    required this.owner,
    required this.path,
    required this.playing,
    this.position = Duration.zero,
    this.duration,
  });

  final Object owner;
  final String path;
  final bool playing;
  final Duration position;
  final Duration? duration;

  AudioClipStatus copyWith({
    bool? playing,
    Duration? position,
    Duration? duration,
  }) => AudioClipStatus(
    owner: owner,
    path: path,
    playing: playing ?? this.playing,
    position: position ?? this.position,
    duration: duration ?? this.duration,
  );
}

/// Plays one local audio attachment at a time. Starting another clip stops
/// the current one, and each clip belongs to the widget that started it so
/// that widget can stop it when it leaves the tree.
///
/// Every play request gets its own native player, released as soon as the
/// request is replaced or stopped. Native events carry no source, so this is
/// what keeps a replaced request's late events and start from ever reaching
/// the next one.
class AudioClipPlayback {
  AudioClipPlayback._();

  static final AudioClipPlayback instance = AudioClipPlayback._();

  final ValueNotifier<AudioClipStatus?> status = ValueNotifier(null);
  _ClipRequest? _current;

  Future<void> toggle({required Object owner, required String path}) async {
    final current = _current;
    final shown = status.value;
    if (current != null &&
        shown != null &&
        identical(current.owner, owner) &&
        current.path == path) {
      final playing = !shown.playing;
      status.value = shown.copyWith(playing: playing);
      // While loading, the load itself starts only if still wanted.
      if (!current.loaded) return;
      playing ? await current.player.resume() : await current.player.pause();
      return;
    }

    _stopCurrent();
    final request = _ClipRequest(owner: owner, path: path)..listen(this);
    _current = request;
    status.value = AudioClipStatus(owner: owner, path: path, playing: true);
    try {
      await request.player.setSource(DeviceFileSource(path));
      if (!identical(_current, request)) return;
      request.loaded = true;
      if (status.value?.playing != true) return;
      await request.player.resume();
    } catch (_) {
      // A replaced or stopped request's failure concerns no one.
      if (!identical(_current, request)) return;
      _stopCurrent();
      rethrow;
    }
  }

  Future<void> stopFor(Object owner) async {
    if (!identical(_current?.owner, owner)) return;
    _stopCurrent(notify: false);
    // Called during widget updates and disposal: cancel immediately, then
    // notify listeners once Flutter has unlocked the tree. A newer clip wins.
    await Future<void>.value();
    if (_current == null) status.value = null;
  }

  void _stopCurrent({bool notify = true}) {
    final request = _current;
    _current = null;
    if (notify) status.value = null;
    if (request != null) unawaited(request.dispose());
  }

  void _update(
    _ClipRequest request,
    AudioClipStatus Function(AudioClipStatus status) change,
  ) {
    final shown = status.value;
    if (identical(_current, request) && shown != null) {
      status.value = change(shown);
    }
  }

  void _end(_ClipRequest request) {
    if (identical(_current, request)) _stopCurrent();
  }
}

/// One play request and the native player that serves only it.
final class _ClipRequest {
  _ClipRequest({required this.owner, required this.path});

  final Object owner;
  final String path;
  final AudioPlayer player = AudioPlayer();
  bool loaded = false;
  final List<StreamSubscription<Object?>> _subscriptions = [];

  void listen(AudioClipPlayback playback) {
    // Decode or I/O failures arrive on the event streams; without handlers
    // they escape as uncaught errors. While loading, setSource() reports them.
    void onError(Object error) {
      if (!loaded) return;
      debugPrint('[AudioClipPlayback] Playback failed: $error');
      playback._end(this);
    }

    _subscriptions.addAll([
      player.onPositionChanged.listen(
        (position) =>
            playback._update(this, (s) => s.copyWith(position: position)),
        onError: onError,
      ),
      player.onDurationChanged.listen(
        (duration) =>
            playback._update(this, (s) => s.copyWith(duration: duration)),
        onError: onError,
      ),
      player.onPlayerComplete.listen(
        (_) => playback._end(this),
        onError: onError,
      ),
    ]);
  }

  Future<void> dispose() async {
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    try {
      await player.dispose();
    } catch (_) {}
  }
}

String formatClipDuration(Duration value) {
  final seconds = value.inSeconds;
  return '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
}

/// Play/pause control for a local audio file. Stops its clip when disposed,
/// so a scrolled-away or removed attachment never keeps playing unseen.
class AudioClipPlayer extends StatefulWidget {
  const AudioClipPlayer({super.key, required this.path, required this.builder});

  final String path;

  /// Receives the play/pause button and, while this clip is loaded, its
  /// `elapsed / total` label; callers lay both out in their own chrome.
  final Widget Function(BuildContext context, Widget button, String? time)
  builder;

  @override
  State<AudioClipPlayer> createState() => _AudioClipPlayerState();
}

class _AudioClipPlayerState extends State<AudioClipPlayer> {
  final Object _owner = Object();

  @override
  void didUpdateWidget(AudioClipPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.path != widget.path) {
      unawaited(AudioClipPlayback.instance.stopFor(_owner));
    }
  }

  @override
  void dispose() {
    unawaited(AudioClipPlayback.instance.stopFor(_owner));
    super.dispose();
  }

  Future<void> _toggle() async {
    try {
      await AudioClipPlayback.instance.toggle(owner: _owner, path: widget.path);
    } catch (_) {
      if (!mounted) return;
      showAppSnackBar(
        context,
        message: AppLocalizations.of(context)!.audioClipPlaybackFailed,
        type: NotificationType.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    return ValueListenableBuilder<AudioClipStatus?>(
      valueListenable: AudioClipPlayback.instance.status,
      builder: (context, status, _) {
        final mine = status != null && identical(status.owner, _owner)
            ? status
            : null;
        final playing = mine?.playing ?? false;
        final button = IosIconButton(
          icon: playing ? Lucide.Pause : Lucide.Play,
          size: 16,
          padding: const EdgeInsets.all(4),
          color: cs.primary,
          tooltip: playing
              ? l10n.audioClipPauseTooltip
              : l10n.audioClipPlayTooltip,
          onTap: () => unawaited(_toggle()),
        );
        final duration = mine?.duration;
        final time = mine == null
            ? null
            : duration == null
            ? formatClipDuration(mine.position)
            : '${formatClipDuration(mine.position)} / '
                  '${formatClipDuration(duration)}';
        return widget.builder(context, button, time);
      },
    );
  }
}
