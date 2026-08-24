import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';

import '../../../../core/providers/assistant_provider.dart';
import '../../../../core/providers/settings_provider.dart';
import '../../../../utils/sandbox_path_resolver.dart';

/// When true, [FrostedSurface] always uses a live [BackdropFilter].
///
/// Used by goldens to generate a reference image. Never flip this during
/// a frame in production — the switch is one-way at runtime as well.
bool debugFrostedForceLiveBackdropFilter = false;

/// When true, [ChatFrostedBackdrop] treats snapshot capture as failed.
///
/// Distinct from [debugFrostedForceLiveBackdropFilter]: this exercises the
/// real failure path (`snapshotUnsupported`) so wallpaper removal can still
/// return to the solid-color fast path.
bool debugFrostedForceSnapshotFailure = false;

/// Down-sample factor for a pre-blur snapshot.
///
/// `Δ = σ/6` keeps the bilinear reconstruction error below one 8-bit LSB
/// before the frosted tint attenuates it further. `σ <= 0` is a no-op.
double frostedSampleScale({required double sigma, required double dpr}) {
  if (sigma <= 0) return 0;
  return (6.0 / sigma).clamp(0.05, dpr);
}

enum FrostedRenderMode { uniform, cached, liveBackdropFilter }

/// Identity of the static chat backdrop a frosted snapshot was built from.
class ChatBackdropSpec {
  const ChatBackdropSpec({
    required this.backgroundRaw,
    required this.active,
    required this.maskStrength,
    required this.surface,
    required this.shadow,
    required this.brightness,
    required this.logicalSize,
    required this.dpr,
  });

  final String backgroundRaw;
  final bool active;
  final double maskStrength;
  final Color surface;
  final Color shadow;
  final Brightness brightness;
  final Size logicalSize;
  final double dpr;

  /// Whether a wallpaper (local file or network) is actually shown.
  ///
  /// Lifted from [HomePage]'s `_assistantBackgroundActive` so "has wallpaper"
  /// is decided in one place.
  static ChatBackdropSpec resolve(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final mq = MediaQuery.of(context);
    final backgroundRaw = context.select<AssistantProvider, String>(
      (p) => (p.currentAssistant?.background ?? '').trim(),
    );
    final maskStrength = context.select<SettingsProvider, double>(
      (s) => s.chatBackgroundMaskStrength,
    );
    return ChatBackdropSpec(
      backgroundRaw: backgroundRaw,
      active: isBackgroundActive(backgroundRaw),
      maskStrength: maskStrength,
      surface: cs.surface,
      shadow: cs.shadow,
      brightness: theme.brightness,
      logicalSize: mq.size,
      dpr: mq.devicePixelRatio,
    );
  }

  static bool isBackgroundActive(String backgroundRaw) {
    final bgRaw = backgroundRaw.trim();
    if (bgRaw.isEmpty) return false;
    if (bgRaw.startsWith('http')) return true;
    try {
      return File(SandboxPathResolver.fix(bgRaw)).existsSync();
    } catch (_) {
      return false;
    }
  }

  @override
  bool operator ==(Object other) =>
      other is ChatBackdropSpec &&
      other.backgroundRaw == backgroundRaw &&
      other.active == active &&
      other.maskStrength == maskStrength &&
      other.surface == surface &&
      other.shadow == shadow &&
      other.brightness == brightness &&
      other.logicalSize == logicalSize &&
      other.dpr == dpr;

  @override
  int get hashCode => Object.hash(
    backgroundRaw,
    active,
    maskStrength,
    surface,
    shadow,
    brightness,
    logicalSize,
    dpr,
  );
}

class FrostedBackdropSnapshot {
  const FrostedBackdropSnapshot({
    required this.image,
    required this.logicalSize,
    required this.sigma,
    required this.generation,
  });

  final ui.Image image;
  final Size logicalSize;
  final double sigma;
  final int generation;
}

class _SnapshotBucket {
  _SnapshotBucket() : notifier = ValueNotifier<FrostedBackdropSnapshot?>(null);

  final ValueNotifier<FrostedBackdropSnapshot?> notifier;
  int refs = 0;
}

/// Owns the pinned backdrop [LayerLink] and per-sigma blur snapshots.
///
/// Desktop/tablet bubbles near the chat-panel edge no longer ingest sidebar
/// pixels: the snapshot is taken from the artwork layer only, which is
/// painted on a [ColoredBox] of [ColorScheme.surface]. The visual difference
/// versus sampling the composited sidebar is negligible.
class ChatFrostedBackdropController extends ChangeNotifier {
  ChatFrostedBackdropController();

  final LayerLink link = LayerLink();

  FrostedRenderMode mode = FrostedRenderMode.uniform;

  /// Capture is permanently disabled for cached mode only. Removing wallpaper
  /// still returns to [FrostedRenderMode.uniform].
  bool snapshotUnsupported = false;

  final Map<double, _SnapshotBucket> _buckets = <double, _SnapshotBucket>{};
  final List<ui.Image> _pendingDispose = <ui.Image>[];
  int _generation = 0;
  bool _disposed = false;
  var _retireScheduled = false;
  VoidCallback? onSnapshotRequested;

  ValueNotifier<FrostedBackdropSnapshot?> acquireSnapshot(double sigma) {
    final bucket = _buckets.putIfAbsent(sigma, _SnapshotBucket.new);
    final wasZero = bucket.refs == 0;
    bucket.refs += 1;
    if (wasZero) {
      onSnapshotRequested?.call();
    }
    return bucket.notifier;
  }

  void releaseSnapshot(double sigma) {
    final bucket = _buckets[sigma];
    if (bucket == null) return;
    bucket.refs -= 1;
    if (bucket.refs > 0) return;
    // Delay one frame so a still-compositing RawImage is not handed a
    // disposed ui.Image / notifier.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_disposed) return;
      final current = _buckets[sigma];
      if (current == null || current.refs > 0 || !identical(current, bucket)) {
        return;
      }
      final snap = current.notifier.value;
      current.notifier.value = null;
      _buckets.remove(sigma);
      current.notifier.dispose();
      if (snap != null) {
        _pendingDispose.add(snap.image);
        _scheduleDisposeRetired();
      }
    });
  }

  Iterable<double> get acquiredSigmas => [
    for (final entry in _buckets.entries)
      if (entry.value.refs > 0) entry.key,
  ];

  bool hasCurrentSnapshot(double sigma) {
    if (sigma <= 0) return true;
    final bucket = _buckets[sigma];
    final snap = bucket?.notifier.value;
    return bucket != null &&
        bucket.refs > 0 &&
        snap != null &&
        snap.generation == _generation;
  }

  bool get hasAllCurrentSnapshots {
    for (final sigma in acquiredSigmas) {
      if (!hasCurrentSnapshot(sigma)) return false;
    }
    return true;
  }

  @visibleForTesting
  int get debugBucketCount => _buckets.length;

  @visibleForTesting
  int get debugAcquiredSigmaCount => acquiredSigmas.length;

  void applyBackdropState({required bool wallpaperActive}) {
    final FrostedRenderMode next;
    if (debugFrostedForceLiveBackdropFilter) {
      next = FrostedRenderMode.liveBackdropFilter;
    } else if (!wallpaperActive) {
      next = FrostedRenderMode.uniform;
    } else if (snapshotUnsupported) {
      next = FrostedRenderMode.liveBackdropFilter;
    } else {
      next = FrostedRenderMode.cached;
    }
    if (mode == next) return;
    mode = next;
    notifyListeners();
  }

  void markSnapshotUnsupported() {
    if (snapshotUnsupported && mode == FrostedRenderMode.liveBackdropFilter) {
      return;
    }
    snapshotUnsupported = true;
    if (mode == FrostedRenderMode.uniform &&
        !debugFrostedForceLiveBackdropFilter) {
      return;
    }
    if (mode == FrostedRenderMode.liveBackdropFilter) return;
    mode = FrostedRenderMode.liveBackdropFilter;
    notifyListeners();
  }

  /// Transfers [snapshot] ownership on success. Returns `false` if the caller
  /// must dispose [snapshot.image].
  bool publish(double sigma, FrostedBackdropSnapshot snapshot) {
    if (_disposed) return false;
    final bucket = _buckets[sigma];
    if (bucket == null || bucket.refs <= 0) return false;
    if (snapshot.generation != _generation) return false;
    final previous = bucket.notifier.value;
    bucket.notifier.value = snapshot;
    if (previous != null) {
      _pendingDispose.add(previous.image);
    }
    return true;
  }

  /// Bump generation and immediately hide every cached crop.
  ///
  /// Old images stay alive for one frame so [RawImage] can finish compositing.
  int invalidateSnapshots() {
    _generation += 1;
    for (final bucket in _buckets.values) {
      final previous = bucket.notifier.value;
      bucket.notifier.value = null;
      if (previous != null) {
        _pendingDispose.add(previous.image);
      }
    }
    _scheduleDisposeRetired();
    return _generation;
  }

  void _scheduleDisposeRetired() {
    if (_retireScheduled || _disposed) return;
    _retireScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _retireScheduled = false;
      if (!_disposed) {
        disposeRetiredImages();
      }
    });
  }

  void disposeRetiredImages() {
    for (final image in _pendingDispose) {
      image.dispose();
    }
    _pendingDispose.clear();
  }

  int get generation => _generation;

  @override
  void dispose() {
    _disposed = true;
    for (final bucket in _buckets.values) {
      bucket.notifier.value?.image.dispose();
      bucket.notifier.dispose();
    }
    _buckets.clear();
    disposeRetiredImages();
    super.dispose();
  }

  bool get isDisposed => _disposed;
}

class ChatFrostedBackdropScope extends InheritedWidget {
  const ChatFrostedBackdropScope({
    super.key,
    required this.controller,
    required super.child,
  });

  final ChatFrostedBackdropController controller;

  static ChatFrostedBackdropScope? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<ChatFrostedBackdropScope>();
  }

  static ChatFrostedBackdropScope? maybeOfStatic(BuildContext context) {
    return context.getInheritedWidgetOfExactType<ChatFrostedBackdropScope>();
  }

  @override
  bool updateShouldNotify(ChatFrostedBackdropScope oldWidget) =>
      oldWidget.controller != controller;
}

/// Pins a static chat backdrop and publishes pre-blurred snapshots for
/// [FrostedSurface] to crop via [CompositedTransformFollower].
class ChatFrostedBackdrop extends StatefulWidget {
  const ChatFrostedBackdrop({
    super.key,
    required this.backdrop,
    required this.child,
  });

  final Widget backdrop;
  final Widget child;

  @override
  State<ChatFrostedBackdrop> createState() => _ChatFrostedBackdropState();
}

class _ChatFrostedBackdropState extends State<ChatFrostedBackdrop> {
  final ChatFrostedBackdropController _controller =
      ChatFrostedBackdropController();
  final GlobalKey _boundaryKey = GlobalKey();
  final BackdropKey _backdropKey = BackdropKey();
  ChatBackdropSpec? _lastSpec;
  var _capturePending = false;
  VoidCallback? _onDirty;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _scheduleCapture() {
    if (_capturePending || !mounted || _controller.isDisposed) return;
    if (_controller.mode != FrostedRenderMode.cached) return;
    if (_controller.hasAllCurrentSnapshots) return;
    _capturePending = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _capturePending = false;
      if (!mounted || _controller.isDisposed) return;
      _capture();
      _controller._scheduleDisposeRetired();
    });
  }

  void _capture() {
    if (debugFrostedForceLiveBackdropFilter) {
      _controller.applyBackdropState(
        wallpaperActive: _lastSpec?.active ?? false,
      );
      return;
    }
    if (debugFrostedForceSnapshotFailure) {
      _controller.markSnapshotUnsupported();
      return;
    }
    if (_controller.mode != FrostedRenderMode.cached) return;
    if (_controller.hasAllCurrentSnapshots) return;
    final boundary =
        _boundaryKey.currentContext?.findRenderObject()
            as _RenderBackdropCaptureBoundary?;
    if (boundary == null || !boundary.hasSize || boundary.size.isEmpty) {
      return;
    }
    final spec = _lastSpec;
    if (spec == null) return;
    try {
      final generation = _controller.generation;
      final sigmas = _controller.acquiredSigmas.toList(growable: false);
      if (sigmas.isEmpty) return;
      boundary.suppressPaintNotify = true;
      try {
        for (final sigma in sigmas) {
          if (sigma <= 0) continue;
          final sample = frostedSampleScale(sigma: sigma, dpr: spec.dpr);
          if (sample <= 0) continue;
          ui.Image? raw;
          try {
            raw = boundary.toImageSync(pixelRatio: sample);
            final blurred = _blurImage(raw, sigma * sample);
            final published = _controller.publish(
              sigma,
              FrostedBackdropSnapshot(
                image: blurred,
                logicalSize: boundary.size,
                sigma: sigma,
                generation: generation,
              ),
            );
            if (!published) {
              blurred.dispose();
            }
          } finally {
            raw?.dispose();
          }
        }
      } finally {
        boundary.suppressPaintNotify = false;
      }
    } catch (_) {
      _controller.markSnapshotUnsupported();
    }
  }

  ui.Image _blurImage(ui.Image src, double sigmaPx) {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final rect =
        Offset.zero & Size(src.width.toDouble(), src.height.toDouble());
    canvas.saveLayer(
      rect,
      Paint()
        ..imageFilter = ui.ImageFilter.blur(
          sigmaX: sigmaPx,
          sigmaY: sigmaPx,
          tileMode: TileMode.clamp,
        ),
    );
    canvas.drawImage(src, Offset.zero, Paint());
    canvas.restore();
    final picture = recorder.endRecording();
    try {
      return picture.toImageSync(src.width, src.height);
    } finally {
      picture.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final spec = ChatBackdropSpec.resolve(context);
    final specChanged = _lastSpec != spec;
    _lastSpec = spec;

    if (specChanged) {
      _controller.invalidateSnapshots();
    }
    _controller.applyBackdropState(wallpaperActive: spec.active);

    if (specChanged && _controller.mode == FrostedRenderMode.cached) {
      _scheduleCapture();
    }

    _controller.onSnapshotRequested ??= _scheduleCapture;
    _onDirty ??= () {
      if (_controller.mode != FrostedRenderMode.cached) return;
      if (_controller.hasAllCurrentSnapshots) return;
      _scheduleCapture();
    };

    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: _BackdropCaptureBoundary(
            key: _boundaryKey,
            onPainted: _onDirty!,
            child: CompositedTransformTarget(
              link: _controller.link,
              child: widget.backdrop,
            ),
          ),
        ),
        BackdropGroup(
          backdropKey: _backdropKey,
          child: ChatFrostedBackdropScope(
            controller: _controller,
            child: widget.child,
          ),
        ),
      ],
    );
  }
}

class _BackdropCaptureBoundary extends SingleChildRenderObjectWidget {
  const _BackdropCaptureBoundary({
    super.key,
    required this.onPainted,
    required super.child,
  });

  final VoidCallback onPainted;

  @override
  RenderRepaintBoundary createRenderObject(BuildContext context) {
    return _RenderBackdropCaptureBoundary(onPainted: onPainted);
  }

  @override
  void updateRenderObject(
    BuildContext context,
    covariant _RenderBackdropCaptureBoundary renderObject,
  ) {
    renderObject.onPainted = onPainted;
  }
}

class _RenderBackdropCaptureBoundary extends RenderRepaintBoundary {
  _RenderBackdropCaptureBoundary({required this.onPainted});

  VoidCallback onPainted;
  bool suppressPaintNotify = false;

  @override
  void paint(PaintingContext context, Offset offset) {
    super.paint(context, offset);
    if (!suppressPaintNotify) onPainted();
  }
}
