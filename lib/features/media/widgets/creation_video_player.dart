import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:open_filex/open_filex.dart';
import 'package:video_player/video_player.dart';

import '../../../core/database/app_database.dart';
import '../../../icons/lucide_adapter.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/ios_tactile.dart';
import '../../../shared/widgets/snackbar.dart';
import '../../../utils/sandbox_path_resolver.dart';

class CreationVideoPlayer extends StatefulWidget {
  const CreationVideoPlayer({
    super.key,
    required this.item,
    required this.cover,
  });

  final GenerationItemRow item;
  final Widget cover;

  @override
  State<CreationVideoPlayer> createState() => _CreationVideoPlayerState();
}

class _CreationVideoPlayerState extends State<CreationVideoPlayer> {
  VideoPlayerController? _player;
  bool _ready = false;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    unawaited(_openPlayer());
  }

  Future<void> _openPlayer() async {
    if (Platform.isLinux) return;
    final path = SandboxPathResolver.resolveForIo(widget.item.path);
    if (path == null) return;
    final player = VideoPlayerController.file(
      File(path),
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
    );
    _player = player;
    _loading = true;
    try {
      await player.initialize();
      if (mounted) setState(() => _ready = true);
    } catch (_) {
      // The local file can still be opened in a system player.
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openExternally() async {
    final path = SandboxPathResolver.resolveForIo(widget.item.path);
    final result = path == null
        ? null
        : await OpenFilex.open(path, type: widget.item.mime);
    if (mounted && result?.type != ResultType.done) {
      showAppSnackBar(
        context,
        message: AppLocalizations.of(context)!.creationActionFailed,
      );
    }
  }

  @override
  void dispose() {
    unawaited(_player?.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final player = _player;
    if (_ready && player != null) {
      return _VideoSurface(
        player: player,
        onFullScreen: () => Navigator.of(context).push<void>(
          MaterialPageRoute(
            fullscreenDialog: true,
            builder: (context) => Scaffold(
              backgroundColor: Colors.black,
              body: SafeArea(
                child: _VideoSurface(
                  player: player,
                  expanded: true,
                  onFullScreen: () => Navigator.of(context).pop(),
                ),
              ),
            ),
          ),
        ),
      );
    }
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: AspectRatio(
        aspectRatio: (widget.item.width ?? 16) / (widget.item.height ?? 9),
        child: Stack(
          fit: StackFit.expand,
          alignment: Alignment.center,
          children: [
            widget.cover,
            Center(
              child: _loading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : IosIconButton(
                      icon: Lucide.Play,
                      minSize: 52,
                      color: Colors.white,
                      tooltip: l10n.creationOpenVideo,
                      onTap: _openExternally,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VideoSurface extends StatelessWidget {
  const _VideoSurface({
    required this.player,
    required this.onFullScreen,
    this.expanded = false,
  });

  final VideoPlayerController player;
  final VoidCallback onFullScreen;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return ValueListenableBuilder(
      valueListenable: player,
      builder: (context, value, _) {
        final duration = value.duration.inMilliseconds;
        final position = value.position.inMilliseconds.clamp(0, duration);
        final muted = value.volume == 0;
        return Stack(
          fit: StackFit.expand,
          children: [
            Center(
              child: AspectRatio(
                aspectRatio: value.aspectRatio,
                child: VideoPlayer(player),
              ),
            ),
            PositionedDirectional(
              start: 8,
              end: 8,
              bottom: 8,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                  child: ColoredBox(
                    color: Colors.black.withValues(alpha: .45),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Row(
                        children: [
                          _button(
                            value.isPlaying ? Lucide.Pause : Lucide.Play,
                            value.isPlaying
                                ? l10n.creationPauseVideo
                                : l10n.creationPlayVideo,
                            value.isPlaying ? player.pause : player.play,
                          ),
                          _time(value.position),
                          Expanded(
                            child: Slider(
                              max: duration > 0 ? duration.toDouble() : 1,
                              value: position.toDouble(),
                              onChanged: duration == 0
                                  ? null
                                  : (position) => unawaited(
                                      player.seekTo(
                                        Duration(
                                          milliseconds: position.round(),
                                        ),
                                      ),
                                    ),
                            ),
                          ),
                          _time(value.duration),
                          _button(
                            muted ? LucideIcons.volumeX : Lucide.Volume2,
                            muted
                                ? l10n.creationUnmuteVideo
                                : l10n.creationMuteVideo,
                            () => player.setVolume(muted ? 1 : 0),
                          ),
                          _button(
                            expanded ? Lucide.Minimize2 : Lucide.Maximize2,
                            expanded
                                ? l10n.creationExitFullScreen
                                : l10n.creationFullScreen,
                            onFullScreen,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _button(IconData icon, String tooltip, VoidCallback onTap) =>
      IosIconButton(
        icon: icon,
        size: 17,
        minSize: 34,
        color: Colors.white,
        tooltip: tooltip,
        onTap: onTap,
      );

  Widget _time(Duration duration) => Text(
    creationVideoTime(duration.inMilliseconds),
    style: const TextStyle(color: Colors.white, fontSize: 11),
  );
}

String creationVideoTime(int milliseconds) {
  final duration = Duration(milliseconds: milliseconds);
  final minutes = duration.inMinutes.toString().padLeft(2, '0');
  final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
}
