import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart' show CupertinoActivityIndicator;
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:open_filex/open_filex.dart';
import 'package:video_player/video_player.dart';

import '../../../core/database/app_database.dart';
import '../../../icons/lucide_adapter.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/ios_tactile.dart';
import '../../../shared/widgets/snackbar.dart';
import '../../../utils/sandbox_path_resolver.dart';
import '../../../shared/widgets/sliding_segmented_tabs.dart';
import 'creation_slider.dart';

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
          PageRouteBuilder<void>(
            transitionDuration: handoffDuration(context, 220),
            reverseTransitionDuration: handoffDuration(context, 220),
            pageBuilder: (context, _, _) => ColoredBox(
              color: Colors.black,
              child: SafeArea(
                child: _VideoSurface(
                  player: player,
                  expanded: true,
                  onFullScreen: () => Navigator.of(context).pop(),
                ),
              ),
            ),
            transitionsBuilder: (_, animation, _, child) => FadeTransition(
              opacity: animation.drive(CurveTween(curve: handoffCurve)),
              child: child,
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
                  ? CupertinoActivityIndicator(
                      color: Colors.white,
                      animating: !MediaQuery.disableAnimationsOf(context),
                    )
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
        final toggle = value.isPlaying ? player.pause : player.play;
        final playLabel = value.isPlaying
            ? l10n.creationPauseVideo
            : l10n.creationPlayVideo;
        final play = _button(
          value.isPlaying ? Lucide.Pause : Lucide.Play,
          playLabel,
          toggle,
        );
        final mute = _button(
          muted ? LucideIcons.volumeX : Lucide.Volume2,
          muted ? l10n.creationUnmuteVideo : l10n.creationMuteVideo,
          () => player.setVolume(muted ? 1 : 0),
        );
        final full = _button(
          expanded ? Lucide.Minimize2 : Lucide.Maximize2,
          expanded ? l10n.creationExitFullScreen : l10n.creationFullScreen,
          onFullScreen,
        );
        final seek = CreationSlider(
          label: l10n.creationVideo,
          formatValue: (v) => creationVideoTime(v.round()),
          thumb: false,
          activeColor: Colors.white,
          trackColor: Colors.white24,
          max: duration > 0 ? duration.toDouble() : 1,
          value: position.toDouble(),
          onChanged: duration == 0
              ? null
              : (next) => unawaited(
                  player.seekTo(Duration(milliseconds: next.round())),
                ),
        );
        return Center(
          child: AspectRatio(
            aspectRatio: value.aspectRatio,
            child: Stack(
              fit: StackFit.expand,
              children: [
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  excludeFromSemantics: true,
                  onTap: toggle,
                  child: VideoPlayer(player),
                ),
                if (!value.isPlaying)
                  Center(
                    child: DecoratedBox(
                      decoration: const BoxDecoration(
                        color: Colors.black45,
                        shape: BoxShape.circle,
                      ),
                      child: IosIconButton(
                        icon: Lucide.Play,
                        size: 24,
                        minSize: 52,
                        color: Colors.white,
                        tooltip: playLabel,
                        onTap: toggle,
                      ),
                    ),
                  ),
                PositionedDirectional(
                  start: 12,
                  end: 12,
                  bottom: 12,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                      child: ColoredBox(
                        color: Colors.black.withValues(alpha: .45),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          child: LayoutBuilder(
                            builder: (context, box) {
                              if (box.maxWidth < 245) {
                                return Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    seek,
                                    Wrap(
                                      alignment: WrapAlignment.center,
                                      crossAxisAlignment:
                                          WrapCrossAlignment.center,
                                      children: [
                                        play,
                                        _time(value.position),
                                        _time(value.duration),
                                        mute,
                                        full,
                                      ],
                                    ),
                                  ],
                                );
                              }
                              return Row(
                                children: [
                                  play,
                                  _time(value.position),
                                  const SizedBox(width: 8),
                                  Expanded(child: seek),
                                  const SizedBox(width: 8),
                                  _time(value.duration),
                                  mute,
                                  full,
                                ],
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
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
    style: const TextStyle(
      color: Colors.white,
      fontSize: 12,
      decoration: TextDecoration.none,
      fontFeatures: [FontFeature.tabularFigures()],
    ),
  );
}

String creationVideoTime(int milliseconds) {
  final duration = Duration(milliseconds: milliseconds);
  final minutes = duration.inMinutes.toString().padLeft(2, '0');
  final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
}
