import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../../theme/chat_bubble_style.dart';
import 'chat_frosted_backdrop.dart';

/// Frosted chat bubble surface.
///
/// Tier 0 (uniform / no scope / `blurSigma <= 0`): a [DecoratedBox] tint.
/// Tier 1 (cached snapshot): a pinned, pre-blurred crop plus the same tint.
/// Live [BackdropFilter] is only a fallback if snapshot capture fails,
/// or when [debugFrostedForceLiveBackdropFilter] is set.
///
/// A missing snapshot never flips to live glass — it shows the tint only.
class FrostedSurface extends StatelessWidget {
  const FrostedSurface({
    super.key,
    required this.style,
    required this.borderRadius,
    required this.child,
    this.isUser = false,
  });

  final ResolvedBubbleStyle style;
  final BorderRadius borderRadius;
  final Widget child;
  final bool isUser;

  @override
  Widget build(BuildContext context) {
    final scope = ChatFrostedBackdropScope.maybeOf(context);
    final sigma = style.blurSigma;
    final Widget painted;
    if (debugFrostedForceLiveBackdropFilter && sigma > 0) {
      painted = _liveBackdrop(child);
    } else if (scope == null || sigma <= 0) {
      painted = _tint(child);
    } else {
      painted = ListenableBuilder(
        listenable: scope.controller,
        builder: (context, _) {
          final mode = scope.controller.mode;
          if (mode == FrostedRenderMode.uniform) {
            return _tint(child);
          }
          if (mode == FrostedRenderMode.liveBackdropFilter) {
            return Stack(
              fit: StackFit.passthrough,
              children: [
                _FrostedSnapshotLease(
                  controller: scope.controller,
                  sigma: sigma,
                ),
                _liveBackdrop(child),
              ],
            );
          }
          // passthrough: a loose Stack would shrink-wrap the tint while the
          // Positioned.fill crop still spans the incoming (often tight-width)
          // constraints, so the glass would overflow the bubble border.
          return Stack(
            fit: StackFit.passthrough,
            children: [
              Positioned.fill(
                child: IgnorePointer(
                  child: _FrostedBackdropCrop(
                    controller: scope.controller,
                    sigma: sigma,
                  ),
                ),
              ),
              _tint(child),
            ],
          );
        },
      );
    }
    return ClipRRect(
      borderRadius: borderRadius,
      clipBehavior: Clip.antiAlias,
      child: painted,
    );
  }

  Widget _tint(Widget child) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: style.background,
        borderRadius: borderRadius,
        border: Border.all(color: style.border, width: style.borderWidth),
      ),
      child: child,
    );
  }

  Widget _liveBackdrop(Widget child) {
    return BackdropFilter.grouped(
      filter: ui.ImageFilter.blur(
        sigmaX: style.blurSigma,
        sigmaY: style.blurSigma,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: style.background,
          borderRadius: borderRadius,
          border: Border.all(color: style.border, width: style.borderWidth),
        ),
        child: child,
      ),
    );
  }
}

/// Holds a snapshot bucket so capture can resume after live glass stops.
/// Does not paint [RawImage].
class _FrostedSnapshotLease extends StatefulWidget {
  const _FrostedSnapshotLease({required this.controller, required this.sigma});

  final ChatFrostedBackdropController controller;
  final double sigma;

  @override
  State<_FrostedSnapshotLease> createState() => _FrostedSnapshotLeaseState();
}

class _FrostedSnapshotLeaseState extends State<_FrostedSnapshotLease> {
  @override
  void initState() {
    super.initState();
    widget.controller.acquireSnapshot(widget.sigma);
  }

  @override
  void didUpdateWidget(covariant _FrostedSnapshotLease oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller ||
        oldWidget.sigma != widget.sigma) {
      oldWidget.controller.releaseSnapshot(oldWidget.sigma);
      widget.controller.acquireSnapshot(widget.sigma);
    }
  }

  @override
  void dispose() {
    widget.controller.releaseSnapshot(widget.sigma);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

class _FrostedBackdropCrop extends StatefulWidget {
  const _FrostedBackdropCrop({required this.controller, required this.sigma});

  final ChatFrostedBackdropController controller;
  final double sigma;

  @override
  State<_FrostedBackdropCrop> createState() => _FrostedBackdropCropState();
}

class _FrostedBackdropCropState extends State<_FrostedBackdropCrop> {
  late ValueNotifier<FrostedBackdropSnapshot?> _listenable;

  @override
  void initState() {
    super.initState();
    _listenable = widget.controller.acquireSnapshot(widget.sigma);
  }

  @override
  void didUpdateWidget(covariant _FrostedBackdropCrop oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller ||
        oldWidget.sigma != widget.sigma) {
      oldWidget.controller.releaseSnapshot(oldWidget.sigma);
      _listenable = widget.controller.acquireSnapshot(widget.sigma);
    }
  }

  @override
  void dispose() {
    widget.controller.releaseSnapshot(widget.sigma);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<FrostedBackdropSnapshot?>(
      valueListenable: _listenable,
      builder: (context, snapshot, _) {
        if (snapshot == null ||
            snapshot.generation != widget.controller.generation) {
          return const SizedBox.shrink();
        }
        assert(() {
          // A follower with no leader hides its child. Capturing this
          // subtree with toImage would produce a blank glass — export
          // and screenshots must go through the no-scope Tier 0 path.
          return true;
        }());
        return OverflowBox(
          alignment: Alignment.topLeft,
          minWidth: 0,
          minHeight: 0,
          maxWidth: double.infinity,
          maxHeight: double.infinity,
          child: CompositedTransformFollower(
            link: widget.controller.link,
            showWhenUnlinked: false,
            targetAnchor: Alignment.topLeft,
            followerAnchor: Alignment.topLeft,
            child: SizedBox(
              width: snapshot.logicalSize.width,
              height: snapshot.logicalSize.height,
              child: RawImage(
                image: snapshot.image,
                fit: BoxFit.fill,
                filterQuality: FilterQuality.low,
              ),
            ),
          ),
        );
      },
    );
  }
}
