import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../../theme/chat_bubble_style.dart';
import 'chat_frosted_backdrop.dart';

/// Frosted chat bubble surface.
///
/// Tier 0 (uniform / no scope / `blurSigma <= 0`): a [DecoratedBox] tint.
/// Tier 1 (cached snapshot): a pinned, pre-blurred crop plus the same tint.
/// Live [BackdropFilter] handles theme/animated-backdrop transitions and
/// snapshot failures. Uniform/cached modes keep the filter disabled.
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
    return ClipRRect(
      borderRadius: borderRadius,
      clipBehavior: Clip.antiAlias,
      child: ListenableBuilder(
        listenable: scope?.controller ?? const AlwaysStoppedAnimation(0),
        child: _tint(child),
        builder: (context, content) {
          final sigma = style.blurSigma;
          final live =
              sigma > 0 &&
              (debugFrostedForceLiveBackdropFilter ||
                  scope?.controller.mode ==
                      FrostedRenderMode.liveBackdropFilter);
          return BackdropFilter.grouped(
            enabled: live,
            filter: ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
            child: Stack(
              // Keep the filter, tint and content at the same element paths.
              // Disabled filters create no BackdropFilterLayer; live filters
              // retain the original compositing order around the foreground.
              fit: StackFit.passthrough,
              children: [
                Positioned.fill(
                  child: IgnorePointer(child: _backdrop(scope?.controller)),
                ),
                content!,
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _backdrop(ChatFrostedBackdropController? controller) {
    final sigma = style.blurSigma;
    if (sigma <= 0) return const SizedBox.shrink();
    if (debugFrostedForceLiveBackdropFilter ||
        controller?.mode == FrostedRenderMode.liveBackdropFilter) {
      return controller != null && !debugFrostedForceLiveBackdropFilter
          ? _FrostedSnapshotLease(controller: controller, sigma: sigma)
          : const SizedBox.shrink();
    }
    if (controller?.mode == FrostedRenderMode.cached) {
      return _FrostedBackdropCrop(controller: controller!, sigma: sigma);
    }
    return const SizedBox.shrink();
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
