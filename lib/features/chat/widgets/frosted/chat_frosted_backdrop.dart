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
    this.revision = 0,
  });

  final String backgroundRaw;
  final bool active;
  final double maskStrength;
  final Color surface;
  final Color shadow;
  final Brightness brightness;
  final Size logicalSize;
  final double dpr;

  /// Bumped by [ChatFrostedBackdrop] when identity fields change.
  ///
  /// Theme interpolation keeps this moving. Wallpaper paint does not.
  final int revision;

  ChatBackdropSpec withRevision(int revision) {
    return ChatBackdropSpec(
      backgroundRaw: backgroundRaw,
      active: active,
      maskStrength: maskStrength,
      surface: surface,
      shadow: shadow,
      brightness: brightness,
      logicalSize: logicalSize,
      dpr: dpr,
      revision: revision,
    );
  }

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
      other.dpr == dpr &&
      other.revision == revision;

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
    revision,
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

  /// Temporary grouped live glass while the backdrop is changing.
  ///
  /// Theme interpolation, wallpaper switches, and animated wallpapers use
  /// this. Generation and scroll never set it.
  bool liveTransition = false;

  bool _wallpaperActive = false;

  final Map<double, _SnapshotBucket> _buckets = <double, _SnapshotBucket>{};
  final List<ui.Image> _pendingDispose = <ui.Image>[];
  int _generation = 0;
  int _pixelVersion = 0;
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
    var any = false;
    for (final sigma in acquiredSigmas) {
      any = true;
      if (!hasCurrentSnapshot(sigma)) return false;
    }
    return any;
  }

  @visibleForTesting
  int get debugBucketCount => _buckets.length;

  @visibleForTesting
  int get debugAcquiredSigmaCount => acquiredSigmas.length;

  /// Successful [toImageSync] calls for tests (one per sigma per capture).
  @visibleForTesting
  int debugCaptureCount = 0;

  void applyBackdropState({
    required bool wallpaperActive,
    bool enterLive = false,
  }) {
    final nextLive = _nextLiveTransition(
      wallpaperActive: wallpaperActive,
      enterLive: enterLive,
    );
    final next = _nextRenderMode(
      wallpaperActive: wallpaperActive,
      liveTransition: nextLive,
    );
    final changed =
        _wallpaperActive != wallpaperActive ||
        liveTransition != nextLive ||
        mode != next;
    _wallpaperActive = wallpaperActive;
    liveTransition = nextLive;
    mode = next;
    if (changed) notifyListeners();
  }

  bool _nextLiveTransition({
    required bool wallpaperActive,
    required bool enterLive,
  }) {
    if (debugFrostedForceLiveBackdropFilter) return liveTransition;
    if (!wallpaperActive || snapshotUnsupported) return false;
    if (enterLive) return true;
    return liveTransition;
  }

  FrostedRenderMode _nextRenderMode({
    required bool wallpaperActive,
    required bool liveTransition,
  }) {
    if (debugFrostedForceLiveBackdropFilter) {
      return FrostedRenderMode.liveBackdropFilter;
    }
    if (!wallpaperActive) return FrostedRenderMode.uniform;
    if (snapshotUnsupported || liveTransition) {
      return FrostedRenderMode.liveBackdropFilter;
    }
    return FrostedRenderMode.cached;
  }

  void beginLiveTransition() {
    applyBackdropState(wallpaperActive: _wallpaperActive, enterLive: true);
  }

  void endLiveTransition() {
    if (!liveTransition) return;
    liveTransition = false;
    applyBackdropState(wallpaperActive: _wallpaperActive);
  }

  void markSnapshotUnsupported() {
    snapshotUnsupported = true;
    liveTransition = false;
    final next = _nextRenderMode(
      wallpaperActive: _wallpaperActive,
      liveTransition: false,
    );
    if (mode == next) {
      notifyListeners();
      return;
    }
    mode = next;
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

  /// Incremented when the captured backdrop pixels actually change.
  int get pixelVersion => _pixelVersion;

  /// A real backdrop paint (decode / theme / first frame), not a capture paint.
  int noteBackdropPixelsChanged() {
    _pixelVersion += 1;
    return invalidateSnapshots();
  }

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
  var _revision = 0;
  var _capturePending = false;
  var _pendingPixelInvalidate = false;
  var _awaitingStableSpec = false;
  var _deferEndLive = false;
  var _specChangedThisBuild = false;
  var _frame = 0;
  final List<int> _dirtyFrames = <int>[];
  var _paintBurstScheduled = false;
  var _paintsSinceSettle = 0;
  var _paintSettleScheduled = false;
  VoidCallback? _onDirty;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _canCapture =>
      _controller.mode == FrostedRenderMode.cached ||
      _controller.liveTransition;

  void _requestCapture({bool pixelsChanged = false}) {
    if (!mounted || _controller.isDisposed) return;
    if (!_canCapture) return;
    // First paint / first build has no snapshot yet — capture only.
    // A later real paint (decode, theme) invalidates then recaptures.
    if (pixelsChanged && _controller.hasAllCurrentSnapshots) {
      _pendingPixelInvalidate = true;
    }
    if (_capturePending) return;
    if (!pixelsChanged &&
        !_pendingPixelInvalidate &&
        _controller.hasAllCurrentSnapshots) {
      return;
    }
    _capturePending = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _capturePending = false;
      if (!mounted || _controller.isDisposed) return;
      if (!_canCapture) return;
      if (_pendingPixelInvalidate) {
        _pendingPixelInvalidate = false;
        _controller.noteBackdropPixelsChanged();
      }
      _capture();
      _controller._scheduleDisposeRetired();
      if (_deferEndLive) {
        _scheduleSettleFrameCheck();
      }
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
    if (!_canCapture) return;
    if (_controller.hasAllCurrentSnapshots) {
      return;
    }
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
            _controller.debugCaptureCount += 1;
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
        // Capture-induced paints during toImageSync stay suppressed.
        // The next independent paint (decode / theme) must recapture.
        boundary.suppressPaintNotify = false;
      }
    } catch (_) {
      _controller.markSnapshotUnsupported();
      return;
    }
    if (!_controller.hasAllCurrentSnapshots) {
      return;
    }
    if (!_deferEndLive) {
      _controller.endLiveTransition();
      return;
    }
    // Spec-change captures stay live until a later settle frame. A later
    // acquire/recapture on the same revision can return to cached now.
    if (!_specChangedThisBuild) {
      _deferEndLive = false;
      _controller.endLiveTransition();
    }
  }

  void _scheduleSettleFrameCheck() {
    final revision = _revision;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _maybeEndLiveAfterSettle(revision);
    });
  }

  void _maybeEndLiveAfterSettle(int revision) {
    if (!mounted || _controller.isDisposed) return;
    if (_revision != revision) return;
    if (!_controller.hasAllCurrentSnapshots) {
      if (_canCapture && _controller.debugAcquiredSigmaCount > 0) {
        _requestCapture();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _maybeEndLiveAfterSettle(revision);
        });
      }
      return;
    }
    _deferEndLive = false;
    _controller.endLiveTransition();
  }

  void _schedulePaintSettleCapture() {
    if (_paintSettleScheduled) return;
    _paintSettleScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _paintSettleScheduled = false;
      if (!mounted || _controller.isDisposed) return;
      if (_paintsSinceSettle > 0) {
        _paintsSinceSettle = 0;
        _schedulePaintSettleCapture();
        return;
      }
      _requestCapture(pixelsChanged: true);
    });
  }

  void _schedulePaintBurstCheck() {
    if (_paintBurstScheduled) return;
    _paintBurstScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _paintBurstScheduled = false;
      if (!mounted || _controller.isDisposed) return;
      _dirtyFrames.removeWhere((frame) => _frame - frame > 3);
      if (_dirtyFrames.length >= 3) {
        _controller.beginLiveTransition();
        _paintsSinceSettle++;
        _schedulePaintSettleCapture();
        return;
      }
      if (_controller.liveTransition) return;
      if (_dirtyFrames.isNotEmpty) {
        _requestCapture(pixelsChanged: true);
      }
    });
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
    _frame++;
    final incoming = ChatBackdropSpec.resolve(context).withRevision(_revision);
    final specChanged = _lastSpec != incoming;
    if (specChanged) {
      _revision += 1;
    }
    final spec = incoming.withRevision(_revision);
    _lastSpec = spec;
    _specChangedThisBuild = specChanged;

    if (specChanged) {
      _controller.invalidateSnapshots();
      if (spec.active && !_controller.snapshotUnsupported) {
        _controller.applyBackdropState(wallpaperActive: true, enterLive: true);
        _awaitingStableSpec = true;
        _deferEndLive = true;
      } else {
        _controller.applyBackdropState(wallpaperActive: spec.active);
        _awaitingStableSpec = false;
        _deferEndLive = false;
      }
    } else {
      _controller.applyBackdropState(wallpaperActive: spec.active);
      if (_deferEndLive && spec.active) {
        _scheduleSettleFrameCheck();
      }
    }

    if (_awaitingStableSpec && spec.active) {
      _awaitingStableSpec = false;
      _requestCapture();
    } else if (!specChanged &&
        spec.active &&
        _controller.mode == FrostedRenderMode.cached &&
        !_controller.hasAllCurrentSnapshots) {
      _requestCapture();
    }

    _controller.onSnapshotRequested ??= () {
      _requestCapture();
    };
    _onDirty ??= () {
      if (_controller.snapshotUnsupported) return;
      if (_controller.mode == FrostedRenderMode.uniform) return;
      // Spec-driven live (theme / wallpaper identity) is settled by
      // revision checks, not by backdrop paints.
      if (_deferEndLive) return;
      if (_controller.liveTransition) {
        _paintsSinceSettle++;
        _schedulePaintSettleCapture();
        return;
      }
      if (_controller.mode != FrostedRenderMode.cached) return;
      _dirtyFrames.add(_frame);
      _dirtyFrames.removeWhere((frame) => _frame - frame > 3);
      if (_dirtyFrames.length >= 3) {
        _schedulePaintBurstCheck();
        return;
      }
      _requestCapture(pixelsChanged: true);
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
              child: ColoredBox(color: spec.surface, child: widget.backdrop),
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
    if (suppressPaintNotify) return;
    onPainted();
  }
}
