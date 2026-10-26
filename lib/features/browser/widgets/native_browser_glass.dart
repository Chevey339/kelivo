import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// A passive native material below Flutter's browser controls. On iOS/macOS 26,
/// `liquid` uses the system's live glass compositor above the WKWebView.
/// Earlier iOS versions use UIKit blur with subtle edge lighting.
/// Flutter-only pages use BrowserGlass's shader instead of this native host.
///
/// Size this widget from its parent. Keep Flutter opacity and clipping outside
/// its ancestry: the native effect owns its corners and backdrop. Use [opacity]
/// to fade its native composition without a Flutter offscreen opacity layer.
class NativeBrowserGlass extends StatefulWidget {
  const NativeBrowserGlass({
    super.key,
    required this.radius,
    required this.style,
    required this.dark,
    this.elevated = true,
    this.clear = false,
    this.intensity = 0,
    this.opacity = 1,
    this.onReady,
  }) : assert(radius >= 0 && radius < double.infinity),
       assert(style == 'liquid' || style == 'frosted' || style == 'solid');

  final double radius;
  final String style;
  final bool dark;

  /// On macOS, attached surfaces do not draw the native glass shadow beyond
  /// their bounds. Floating controls retain the transparent shadow allowance.
  final bool elevated;
  final bool clear;
  final double intensity;
  final double opacity;

  /// Reports once after creation, pending parameter synchronization and a
  /// framework frame containing this host. It is not a GPU-presented signal.
  final VoidCallback? onReady;

  /// Uses the actual host as well as the target platform. Flutter's unit-test
  /// process has no registered native views, even when its target is overridden.
  static bool get isSupported =>
      !kIsWeb &&
      !Platform.environment.containsKey('FLUTTER_TEST') &&
      ((defaultTargetPlatform == TargetPlatform.iOS && Platform.isIOS) ||
          (defaultTargetPlatform == TargetPlatform.macOS && Platform.isMacOS));

  @override
  State<NativeBrowserGlass> createState() => _NativeBrowserGlassState();
}

class _NativeBrowserGlassState extends State<NativeBrowserGlass> {
  // Flutter's macOS platform-view host clips to its rectangular bounds. Leave
  // room outside NSGlassEffectView for its native shadow to fade naturally.
  // AppKit's soft shadow is still visible 24 points beyond a popover's edge;
  // this larger transparent margin keeps that tail inside the host's clip.
  static const double _macOutset = 64;
  MethodChannel? _channel;
  Future<void>? _updateFuture;
  bool _updatePending = false;
  bool _readyScheduled = false;
  bool _readyReported = false;

  double get _outset => Platform.isMacOS && widget.elevated ? _macOutset : 0;

  Map<String, Object> get _parameters => {
    'radius': widget.radius,
    'style': widget.style,
    'dark': widget.dark,
    'clear': widget.clear,
    'elevated': widget.elevated,
    'outset': _outset,
    'intensity': widget.intensity.isFinite
        ? widget.intensity.clamp(0.0, 1.0)
        : 0.0,
    'opacity': widget.opacity.isFinite ? widget.opacity.clamp(0.0, 1.0) : 1.0,
  };

  @override
  void didUpdateWidget(covariant NativeBrowserGlass oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.radius != widget.radius ||
        oldWidget.style != widget.style ||
        oldWidget.dark != widget.dark ||
        oldWidget.elevated != widget.elevated ||
        oldWidget.clear != widget.clear ||
        oldWidget.intensity != widget.intensity ||
        oldWidget.opacity != widget.opacity) {
      unawaited(_update());
    }
    _scheduleReady();
  }

  Future<void> _update() {
    final channel = _channel;
    if (channel == null || !mounted) return Future<void>.value();
    _updatePending = true;
    return _updateFuture ??= _flushUpdates(channel);
  }

  Future<void> _flushUpdates(MethodChannel channel) async {
    try {
      while (mounted && _updatePending) {
        _updatePending = false;
        await channel.invokeMethod<void>('update', _parameters);
      }
    } on MissingPluginException {
      // Removal can finish before an in-flight update reply.
      if (mounted) rethrow;
    } finally {
      _updateFuture = null;
    }
  }

  void _scheduleReady() {
    if (_channel == null ||
        widget.onReady == null ||
        _readyReported ||
        _readyScheduled) {
      return;
    }
    _readyScheduled = true;
    unawaited(_reportAfterHostFrame());
  }

  Future<void> _reportAfterHostFrame() async {
    try {
      // Await the shared flush, including changes queued while creation or a
      // previous update was in flight. The callback from UiKitView itself runs
      // BEFORE Flutter installs its controller, so it is too early to notify.
      await _update();
      if (!mounted) return;
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted || _readyReported || widget.onReady == null) return;
      _readyReported = true;
      widget.onReady!();
    } finally {
      _readyScheduled = false;
    }
  }

  @override
  void dispose() {
    final channel = _channel;
    _channel = null;
    _updatePending = false;
    if (channel != null) unawaited(_disposeNative(channel));
    super.dispose();
  }

  Future<void> _disposeNative(MethodChannel channel) async {
    try {
      await channel.invokeMethod<void>('dispose');
    } on MissingPluginException {
      // Flutter may have already released the native platform view.
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!NativeBrowserGlass.isSupported) return const SizedBox.expand();
    final view = Platform.isMacOS
        ? LayoutBuilder(
            builder: (context, constraints) => OverflowBox(
              minWidth: constraints.maxWidth + _outset * 2,
              maxWidth: constraints.maxWidth + _outset * 2,
              minHeight: constraints.maxHeight + _outset * 2,
              maxHeight: constraints.maxHeight + _outset * 2,
              child: AppKitView(
                viewType: 'app.browser_glass',
                hitTestBehavior: PlatformViewHitTestBehavior.transparent,
                creationParams: _parameters,
                creationParamsCodec: const StandardMessageCodec(),
                onPlatformViewCreated: _onPlatformViewCreated,
              ),
            ),
          )
        : UiKitView(
            viewType: 'app.browser_glass',
            hitTestBehavior: PlatformViewHitTestBehavior.transparent,
            creationParams: _parameters,
            creationParamsCodec: const StandardMessageCodec(),
            onPlatformViewCreated: _onPlatformViewCreated,
          );
    return IgnorePointer(child: ExcludeSemantics(child: view));
  }

  void _onPlatformViewCreated(int id) {
    if (!mounted) return;
    _channel = MethodChannel('app.browser_glass/$id');
    // Parameters may have changed while the platform was creating the view.
    if (widget.onReady == null) {
      unawaited(_update());
    } else {
      _scheduleReady();
    }
  }
}
