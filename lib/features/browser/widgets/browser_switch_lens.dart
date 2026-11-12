import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/material.dart';

/// One clipped backdrop pass for the Flutter switch track, never a native view
/// or a screenshot. The face is opaque at rest, clear while being pressed.
class BrowserSwitchLens extends StatefulWidget {
  const BrowserSwitchLens({
    super.key,
    required this.progress,
    required this.opaque,
  });
  final double progress;
  final bool opaque;

  static Future<ui.FragmentProgram>? _program;
  static Future<ui.FragmentProgram> _loadProgram() => _program ??=
      ui.FragmentProgram.fromAsset('shaders/browser_switch_lens.frag');

  /// Warm the shared program after the browser's first frame. A settings page
  /// does not allocate one fragment instance per idle switch on opening.
  static Future<void> prewarm() async {
    if (!ui.ImageFilter.isShaderFilterSupported) return;
    try {
      await _loadProgram();
    } catch (_) {
      // The ordinary thumb remains available when shader filters cannot load.
    }
  }

  @override
  State<BrowserSwitchLens> createState() => _BrowserSwitchLensState();
}

class _BrowserSwitchLensState extends State<BrowserSwitchLens> {
  ui.FragmentShader? _shader;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _prepare();
  }

  @override
  void didUpdateWidget(BrowserSwitchLens oldWidget) {
    super.didUpdateWidget(oldWidget);
    if ((oldWidget.opaque && !widget.opaque) ||
        (oldWidget.progress <= 0 && widget.progress > 0)) {
      _prepare();
    }
  }

  void _prepare() {
    if (!widget.opaque &&
        widget.progress > 0 &&
        !_loading &&
        _shader == null &&
        ui.ImageFilter.isShaderFilterSupported) {
      _loading = true;
      BrowserSwitchLens._loadProgram().then(
        (program) {
          if (mounted) setState(() => _shader = program.fragmentShader());
        },
        onError: (Object _, StackTrace __) {
          // Software renderers retain the clear, unwarped Flutter track.
        },
      );
    }
  }

  @override
  void dispose() {
    _shader?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final progress = widget.opaque ? 0.0 : widget.progress;
    Widget face = ColoredBox(
      color: const Color(0xffffffff).withValues(alpha: 1 - progress),
    );
    if (_shader != null && progress > 0) {
      face = _SwitchLensFilter(
        shader: _shader!,
        progress: progress,
        dpr: MediaQuery.devicePixelRatioOf(context),
        dark: Theme.of(context).brightness == Brightness.dark,
        child: face,
      );
    }
    return ClipRRect(borderRadius: BorderRadius.circular(1000), child: face);
  }
}

@visibleForTesting
List<double> browserSwitchLensUniforms({
  required Offset origin,
  required Size size,
  required double dpr,
  required double progress,
  required bool dark,
}) => [
  origin.dx * dpr,
  origin.dy * dpr,
  size.width * dpr,
  size.height * dpr,
  dpr,
  progress,
  dark ? 1 : 0,
];

class _SwitchLensFilter extends SingleChildRenderObjectWidget {
  const _SwitchLensFilter({
    required this.shader,
    required this.progress,
    required this.dpr,
    required this.dark,
    required super.child,
  });
  final ui.FragmentShader shader;
  final double progress, dpr;
  final bool dark;
  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderSwitchLens(shader, progress, dpr, dark);
  @override
  void updateRenderObject(
    BuildContext context,
    _RenderSwitchLens renderObject,
  ) => renderObject.update(shader, progress, dpr, dark);
}

class _RenderSwitchLens extends RenderProxyBox {
  _RenderSwitchLens(this.shader, this.progress, this.dpr, this.dark);
  ui.FragmentShader shader;
  double progress, dpr;
  bool dark;
  void update(
    ui.FragmentShader nextShader,
    double nextProgress,
    double nextDpr,
    bool nextDark,
  ) {
    if (identical(shader, nextShader) &&
        progress == nextProgress &&
        dpr == nextDpr &&
        dark == nextDark) {
      return;
    }
    shader = nextShader;
    progress = nextProgress;
    dpr = nextDpr;
    dark = nextDark;
    markNeedsPaint();
  }

  @override
  bool get alwaysNeedsCompositing => true;
  @override
  BackdropFilterLayer? get layer => super.layer as BackdropFilterLayer?;
  @override
  void paint(PaintingContext context, Offset offset) {
    // Paint-time origin follows scrolling/route transforms without a callback
    // or a one-frame stale position. Engine supplies texture size and sampler.
    final values = browserSwitchLensUniforms(
      origin: localToGlobal(Offset.zero),
      size: size,
      dpr: dpr,
      progress: progress,
      dark: dark,
    );
    for (var i = 0; i < values.length; i++) {
      shader.setFloat(i + 2, values[i]);
    }
    (layer ??= BackdropFilterLayer()).filter = ui.ImageFilter.shader(shader);
    context.pushLayer(layer!, super.paint, offset);
  }
}
