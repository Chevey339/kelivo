import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

@visibleForTesting
int debugGradientPictureBuildCount = 0;
@visibleForTesting
int debugGradientShaderBuildCount = 0;

/// Shares a clock, cached artwork and canvas coordinates across all copies.
/// Moving colors update at most 30 times per second, independently of chat
/// scrolling and token rendering. Static mode schedules no animation frames.
class ChatGradientBackgroundHost extends StatefulWidget {
  const ChatGradientBackgroundHost({
    super.key,
    required this.enabled,
    this.active = true,
    this.offset = Offset.zero,
    this.phase = 0,
    this.onFrame,
    required this.child,
  });

  final bool enabled;
  final bool active;
  final Offset offset;

  /// An actual point on the shared animation timeline, also used when static.
  final double phase;

  /// Used by the settings preview to persist the frame selected by the user.
  final ValueChanged<double>? onFrame;
  final Widget child;

  @override
  State<ChatGradientBackgroundHost> createState() =>
      _ChatGradientBackgroundHostState();
}

class _ChatGradientBackgroundHostState extends State<ChatGradientBackgroundHost>
    with WidgetsBindingObserver {
  late final _seconds = ValueNotifier<double>(widget.phase);
  final _link = LayerLink();
  Timer? _pulse;
  int? _frameId;
  double _startSeconds = 0;
  Duration? _startFrameTime;
  _GradientArtwork? _artwork;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.onFrame?.call(_seconds.value);
  }

  void _scheduleUpdate() {
    if (_frameId != null) return;
    _frameId = WidgetsBinding.instance.scheduleFrameCallback((time) {
      _frameId = null;
      if (!mounted || _pulse == null) return;
      _startFrameTime ??= time;
      _seconds.value =
          _startSeconds +
          (time - _startFrameTime!).inMicroseconds /
              Duration.microsecondsPerSecond;
      widget.onFrame?.call(_seconds.value);
    });
  }

  void _stopAnimation() {
    _pulse?.cancel();
    _pulse = null;
    if (_frameId != null) {
      WidgetsBinding.instance.cancelFrameCallbackWithId(_frameId!);
      _frameId = null;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updateAnimation();
  }

  @override
  void didUpdateWidget(ChatGradientBackgroundHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.phase != oldWidget.phase ||
        (!widget.enabled && oldWidget.enabled)) {
      _seconds.value = widget.phase;
      _startSeconds = widget.phase;
      _startFrameTime = null;
      widget.onFrame?.call(_seconds.value);
    }
    _updateAnimation();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) =>
      _updateAnimation();

  void _updateAnimation() {
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    final animate =
        widget.active &&
        widget.enabled &&
        TickerMode.valuesOf(context).enabled &&
        !MediaQuery.disableAnimationsOf(context) &&
        (lifecycle == null || lifecycle == AppLifecycleState.resumed);
    if (animate && _pulse == null) {
      _startFrameTime = null;
      _startSeconds = _seconds.value;
      // A continuously running Ticker would still request 60/120 app frames
      // even if we skipped painting. Request just one vsync-aligned update per
      // pulse instead, coalescing pulses when the UI thread is busy.
      _pulse = Timer.periodic(
        const Duration(microseconds: 33333),
        (_) => _scheduleUpdate(),
      );
      _scheduleUpdate();
    } else if (!animate) {
      _stopAnimation();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopAnimation();
    _seconds.dispose();
    _artwork?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        if (!widget.active) {
          _artwork?.dispose();
          _artwork = null;
        } else if (_artwork == null ||
            _artwork!.size != size ||
            _artwork!.dark != dark ||
            _artwork!.offset != widget.offset) {
          _artwork?.dispose();
          _artwork = _GradientArtwork(size, dark, widget.offset);
        }
        return _GradientScope(
          seconds: _seconds,
          link: _link,
          artwork: _artwork,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // A lightweight, always-painted anchor. Overlay copies follow it in
              // compositing, so keyboard/sidebar motion needs no new picture.
              Positioned.fill(
                child: CompositedTransformTarget(
                  link: _link,
                  child: const SizedBox.expand(),
                ),
              ),
              widget.child,
            ],
          ),
        );
      },
    );
  }
}

class _GradientScope extends InheritedWidget {
  const _GradientScope({
    required this.seconds,
    required this.link,
    required this.artwork,
    required super.child,
  });

  final ValueNotifier<double> seconds;
  final LayerLink link;
  final _GradientArtwork? artwork;

  @override
  bool updateShouldNotify(_GradientScope oldWidget) =>
      seconds != oldWidget.seconds ||
      link != oldWidget.link ||
      artwork != oldWidget.artwork;
}

class ChatGradientBackground extends StatelessWidget {
  const ChatGradientBackground({super.key, this.pinned = false});

  /// Overlay copies stay at the full background's origin, even inside a
  /// keyboard-resized or horizontally moving panel.
  final bool pinned;

  @override
  Widget build(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<_GradientScope>()!;
    final artwork = scope.artwork!;
    final paint = CustomPaint(
      painter: _GradientPainter(artwork, scope.seconds),
      child: const SizedBox.expand(),
    );
    if (!pinned) return IgnorePointer(child: paint);
    return IgnorePointer(
      child: ClipRect(
        child: OverflowBox(
          alignment: Alignment.topLeft,
          minWidth: artwork.size.width,
          maxWidth: artwork.size.width,
          minHeight: artwork.size.height,
          maxHeight: artwork.size.height,
          child: CompositedTransformFollower(
            link: scope.link,
            showWhenUnlinked: false,
            child: RepaintBoundary(child: paint),
          ),
        ),
      ),
    );
  }
}

class _GradientPainter extends CustomPainter {
  _GradientPainter(this.artwork, this.seconds) : super(repaint: seconds);
  final _GradientArtwork artwork;
  final ValueNotifier<double> seconds;

  @override
  void paint(Canvas canvas, Size size) =>
      canvas.drawPicture(artwork.picture(seconds.value));

  @override
  bool shouldRepaint(_GradientPainter oldDelegate) =>
      artwork != oldDelegate.artwork || seconds != oldDelegate.seconds;
}

/// Shaders are built only when size/theme/position changes. All background
/// copies replay the same display list; trigonometry/recording runs once per
/// animation frame, and never again for unchanged static artwork.
class _GradientArtwork {
  _GradientArtwork(this.size, this.dark, this.offset) {
    final rect = Offset.zero & size;
    _base = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        stops: const [0, 0.22, 0.45, 0.65, 1],
        colors: dark
            ? const [
                Color(0xFF1B2A45),
                Color(0xFF15223A),
                Color(0xFF0D1626),
                Color(0xFF0A0F18),
                Color(0xFF080B12),
              ]
            : const [
                Color(0xFFAFD0F2),
                Color(0xFFCBE0F6),
                Color(0xFFF1F7FD),
                Colors.white,
                Colors.white,
              ],
      ).createShader(rect.shift(Offset(0, offset.dy * size.height * 0.5)));
    final r = math.max(size.width, size.height);
    _radii = [r * 0.36, r * 0.28, r * 0.30, r * 0.26];
    final colors = dark
        ? const [
            Color(0xFF3E6FB0),
            Color(0xFF2E7D74),
            Color(0xFF4A6E96),
            Color(0xFF7C5F9E),
          ]
        : const [
            Color(0xFF9EC5F0),
            Color(0xFFA8E6E0),
            Color(0xFFB6D7F2),
            Color(0xFFFFC8D2),
          ];
    final alphas = dark ? [0.56, 0.44, 0.48, 0.32] : [0.72, 0.56, 0.62, 0.42];
    _blobs = List.generate(
      4,
      (i) => Paint()
        ..shader = RadialGradient(
          colors: [
            colors[i].withValues(alpha: alphas[i]),
            colors[i].withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: Offset.zero, radius: _radii[i])),
    );
    assert(() {
      debugGradientShaderBuildCount += 5;
      return true;
    }());
  }

  final Size size;
  final bool dark;
  final Offset offset;
  late final Paint _base;
  late final List<Paint> _blobs;
  late final List<double> _radii;
  ui.Picture? _picture;
  double? _time;

  ui.Picture picture(double seconds) {
    if (_picture != null && _time == seconds) return _picture!;
    _picture?.dispose();
    _time = seconds;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.clipRect(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, _base);
    final w = size.width;
    final h = size.height;
    final p1 = seconds * 2 * math.pi / 5.5;
    final p2 = seconds * 2 * math.pi / 7;
    final p3 = seconds * 2 * math.pi / 8.5;
    final p4 = seconds * 2 * math.pi / 6.2;
    final centers = [
      Offset(
        w * 0.48 + math.sin(p1) * w * 0.38,
        h * 0.08 + math.cos(p1 * 1.15) * h * 0.18,
      ),
      Offset(
        w * 0.18 + math.sin(p2 + math.pi * 0.55) * w * 0.30,
        h * 0.24 + math.cos(p2) * h * 0.20,
      ),
      Offset(
        w * 0.82 - math.sin(p3 + math.pi * 0.9) * w * 0.34,
        h * 0.12 + math.cos(p3 * 0.9) * h * 0.18,
      ),
      Offset(
        w * 0.58 + math.sin(p4 + math.pi * 1.25) * w * 0.28,
        h * 0.34 + math.cos(p4 * 1.1) * h * 0.16,
      ),
    ];
    for (var i = 0; i < 4; i++) {
      canvas.save();
      canvas.translate(
        centers[i].dx + offset.dx * w * 0.5,
        centers[i].dy + offset.dy * h * 0.5,
      );
      canvas.drawCircle(Offset.zero, _radii[i], _blobs[i]);
      canvas.restore();
    }
    assert(() {
      debugGradientPictureBuildCount++;
      return true;
    }());
    return _picture = recorder.endRecording();
  }

  void dispose() => _picture?.dispose();
}
