import '../../../theme/app_semantic_colors.dart';
import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../models/browser_models.dart';
import 'native_browser_glass.dart';

/// A page-local material choice, captured with the browser's overlay routes.
/// This deliberately does not alter the rest of Kelivo's theme.
class BrowserGlassScope extends InheritedTheme {
  const BrowserGlassScope({
    super.key,
    required this.style,
    required super.child,
  });

  final BrowserSurfaceStyle style;

  static BrowserSurfaceStyle of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<BrowserGlassScope>()?.style ??
      BrowserSurfaceStyle.solid;

  @override
  bool updateShouldNotify(BrowserGlassScope oldWidget) =>
      style != oldWidget.style;

  @override
  Widget wrap(BuildContext context, Widget child) =>
      BrowserGlassScope(style: style, child: child);
}

/// Identifies the scene a material samples. Flutter-only pages must not create
/// UIKit backdrop hosts: those split Flutter's foreground into native overlay
/// slices and cannot move atomically with a route or a tab-card transition.
class BrowserGlassBackdrop extends InheritedTheme {
  const BrowserGlassBackdrop({
    super.key,
    required this.native,
    required super.child,
  });

  final bool native;

  static bool nativeOf(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<BrowserGlassBackdrop>()
          ?.native ??
      true;

  @override
  bool updateShouldNotify(BrowserGlassBackdrop oldWidget) =>
      native != oldWidget.native;

  @override
  Widget wrap(BuildContext context, Widget child) =>
      BrowserGlassBackdrop(native: native, child: child);
}

/// Optical browser chrome. UIKit composites real glass over WKWebView on iOS;
/// Impeller refracts the Flutter scene (including Android's texture WebView).
/// Neither path takes WebView screenshots. Contents remain sharp above it.
class BrowserGlass extends StatefulWidget {
  const BrowserGlass({
    super.key,
    required this.child,
    this.radius = 46,
    this.padding = EdgeInsets.zero,
    this.elevated = true,
    this.blur = true,
    this.clear = false,
    this.opacity = 1,
    this.onReady,
  }) : assert(opacity >= 0 && opacity <= 1);

  final Widget child;
  final double radius;
  final EdgeInsetsGeometry padding;
  final bool elevated;
  final bool blur;
  final bool clear;

  /// Fades the material in its own compositor and the ordinary Flutter
  /// foreground separately. Never wrap a glass surface in [Opacity].
  final double opacity;

  /// Reports once after material preparation and a framework frame containing
  /// it have completed. This does not confirm GPU presentation. Adding the
  /// callback after mounting is supported; rebuilding never reports it twice.
  final VoidCallback? onReady;

  static Future<void>? _shaderWarmUp;

  /// Preload the small browser renderer before its first visible transition.
  /// Native Apple material and software test renderers do not load shaders.
  static Future<void> prewarm({bool nativeBackdrop = true}) {
    if ((nativeBackdrop && NativeBrowserGlass.isSupported) ||
        !ImageFilter.isShaderFilterSupported) {
      return Future<void>.value();
    }
    return _shaderWarmUp ??= defaultTargetPlatform == TargetPlatform.windows
        ? LightweightLiquidGlass.preWarm()
        : LiquidGlassWidgets.preloadPremiumGlass();
  }

  @override
  State<BrowserGlass> createState() => _BrowserGlassState();
}

class _BrowserGlassState extends State<BrowserGlass>
    with SingleTickerProviderStateMixin {
  static const _transitionDuration = Duration(milliseconds: 160);
  late final AnimationController _cover = AnimationController(
    vsync: this,
    value: 1,
    duration: _transitionDuration,
  )..addStatusListener(_coverStatusChanged);
  BrowserSurfaceStyle? _style;
  BrowserSurfaceStyle? _opticalStyle;
  bool _opticalReady = false;
  bool _opticalPreparationScheduled = false;
  bool _readyReported = false;
  bool _readyScheduled = false;
  bool _reduceMotion = false;
  bool _nativeBackdrop = true;
  int _materialGeneration = 0;
  int _readyGeneration = 0;

  bool get _targetSolid => _style == BrowserSurfaceStyle.solid;
  bool get _canReportReady => _targetSolid ? _cover.value == 1 : _opticalReady;

  bool _usesNative(BrowserSurfaceStyle? style) =>
      style != null && _nativeBackdrop && NativeBrowserGlass.isSupported;

  bool _usesShader(BrowserSurfaceStyle? style) =>
      style == BrowserSurfaceStyle.liquid && !_usesNative(style);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final contrast = MediaQuery.highContrastOf(context);
    final nativeBackdrop = BrowserGlassBackdrop.nativeOf(context);
    final rendererChanged =
        NativeBrowserGlass.isSupported && _nativeBackdrop != nativeBackdrop;
    _nativeBackdrop = nativeBackdrop;
    final requested = contrast
        ? BrowserSurfaceStyle.solid
        : BrowserGlassScope.of(context);
    // Unsupported software renderers deliberately use opaque Flutter paint.
    final style =
        requested == BrowserSurfaceStyle.liquid &&
            !_usesNative(requested) &&
            !ImageFilter.isShaderFilterSupported
        ? BrowserSurfaceStyle.solid
        : requested;
    final reduceMotion = contrast || MediaQuery.disableAnimationsOf(context);
    final firstPresentation = _style == null;
    if (style == _style && reduceMotion == _reduceMotion && !rendererChanged) {
      return;
    }
    _style = style;
    _reduceMotion = reduceMotion;
    _readyGeneration++;
    _readyScheduled = false;
    if (_targetSolid) {
      if (_reduceMotion || _cover.value == 1) {
        _discardOpticalSurface();
        _cover.value = 1;
      } else {
        _cover.animateTo(1, duration: _transitionDuration);
      }
    } else {
      final sameRenderer =
          !rendererChanged &&
          _opticalStyle != null &&
          (_usesNative(style) || _opticalStyle == style);
      if (!sameRenderer) {
        _materialGeneration++;
        _opticalReady = false;
        _opticalPreparationScheduled = false;
        // A fresh/reattached optical host must not flash an opaque plate.
        // Keep the cover only when the user explicitly changes from solid;
        // the optical renderer supplies its own translucent preparation paint.
        if (firstPresentation || rendererChanged) _cover.value = 0;
      }
      _opticalStyle = style;
      if (_opticalReady) _revealOpticalSurface();
    }
  }

  void _discardOpticalSurface() {
    if (_opticalStyle == null) return;
    _opticalStyle = null;
    _opticalReady = false;
    _opticalPreparationScheduled = false;
    _materialGeneration++;
  }

  void _coverStatusChanged(AnimationStatus status) {
    if (status != AnimationStatus.completed || !_targetSolid) return;
    if (_opticalStyle != null) {
      setState(_discardOpticalSurface);
    }
  }

  void _revealOpticalSurface() {
    if (_reduceMotion || widget.opacity == 0) {
      // Menus prepare an invisible host before starting their reveal. Remove
      // the cover before handing readiness back, so their first lens frame
      // does not briefly expose the preparation paint.
      _cover.value = 0;
    } else {
      _cover.animateBack(0, duration: _transitionDuration);
    }
  }

  void _reportReady() {
    if (!mounted ||
        !_canReportReady ||
        _readyReported ||
        widget.onReady == null) {
      return;
    }
    _readyReported = true;
    widget.onReady!();
  }

  void _materialReady(int generation) {
    if (!mounted ||
        generation != _materialGeneration ||
        _opticalStyle == null) {
      return;
    }
    _opticalReady = true;
    if (!_targetSolid) _revealOpticalSurface();
    // Both preparation paths have already crossed the host-frame boundary.
    _reportReady();
  }

  Future<void> _prepareFlutterSurface(int generation) async {
    await (_usesShader(_opticalStyle)
        ? BrowserGlass.prewarm(nativeBackdrop: _nativeBackdrop)
        : Future<void>.value());
    if (!mounted || generation != _materialGeneration) return;
    await WidgetsBinding.instance.endOfFrame;
    _materialReady(generation);
  }

  Future<void> _reportAfterFrame(int generation) async {
    try {
      // This also handles callbacks added to an already-mounted surface.
      await Future<void>.value();
      if (!mounted) return;
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted || generation != _readyGeneration) return;
      _reportReady();
    } finally {
      if (generation == _readyGeneration) _readyScheduled = false;
    }
  }

  @override
  void dispose() {
    _cover.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final child = widget.child;
    final radius = widget.radius;
    final padding = widget.padding;
    final elevated = widget.elevated;
    final blur = widget.blur;
    final clear = widget.clear;
    final opacity = widget.opacity;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final contrast = MediaQuery.highContrastOf(context);
    final style = _style!;
    final interaction = _BrowserGlassInteraction.of(context, opticsOnly: true);
    // Touch uses the shared, clipped highlight below. The material itself is
    // not independently brightened on top of that legacy-style response.
    final opticalIntensity = interaction.touch
        ? 0.0
        : interaction.intensity.clamp(0.0, 1.0);
    final isClear = clear || !blur;
    final windowsGlass = defaultTargetPlatform == TargetPlatform.windows;
    final corners = BorderRadius.circular(radius);

    final materialGeneration = _materialGeneration;
    if (_opticalStyle != null &&
        !_usesNative(_opticalStyle) &&
        !_opticalPreparationScheduled) {
      _opticalPreparationScheduled = true;
      unawaited(_prepareFlutterSurface(materialGeneration));
    }
    if (_canReportReady &&
        widget.onReady != null &&
        !_readyReported &&
        !_readyScheduled) {
      _readyScheduled = true;
      unawaited(_reportAfterFrame(_readyGeneration));
    }

    Widget surface;
    if (_usesNative(_opticalStyle)) {
      // The native view owns its mask. An Opacity or Clip ancestor would
      // isolate UIKit's backdrop and prevent it from sampling the webpage.
      surface = NativeBrowserGlass(
        key: ValueKey(materialGeneration),
        radius: radius,
        style: _opticalStyle!.name,
        elevated: elevated,
        dark: dark,
        clear: isClear,
        intensity: opticalIntensity * .4,
        opacity: opacity,
        onReady: () => _materialReady(materialGeneration),
      );
    } else if (_usesShader(_opticalStyle)) {
      surface = GlassTheme(
        data: GlassThemeData(
          brightness: dark ? Brightness.dark : Brightness.light,
        ),
        child: AdaptiveGlass(
          shape: LiquidRoundedSuperellipse(borderRadius: radius),
          // Match the glass library's Windows quality cap: its multi-pass
          // SDF renderer can block ANGLE's raster thread on the first paint.
          // Standard retains the lightweight glass shader and live blur.
          quality: windowsGlass ? GlassQuality.standard : GlassQuality.premium,
          platformViewBackdrop: false,
          useOwnLayer: true,
          clipExpansion: const EdgeInsets.all(18),
          settings: LiquidGlassSettings(
            visibility: opacity,
            // Match the native legacy backdrop's theme wash. Using a much
            // lower tint here made the same button gray on Flutter wallpaper
            // and white over a WKWebView.
            glassColor:
                (dark ? const Color(0xFF121212) : const Color(0xFFFAFAFA))
                    .withValues(alpha: isClear ? .47 : .62),
            bodyMode: GlassBodyMode.clear,
            lensModel: GlassLensModel.edgeWarp,
            // Explicit standard quality expects pre-calibrated values; use
            // AdaptiveGlass's existing premium-to-standard scale factors.
            thickness:
                ((isClear ? 24 : 30) + opticalIntensity * 8) *
                (windowsGlass ? .4 : 1),
            blur: isClear ? 0 : 2,
            refractiveIndex: 1.20 + opticalIntensity * .04,
            chromaticAberration: 0,
            lightAngle:
                -.75 + (interaction.touch ? 0 : interaction.position.dx * .32),
            lightIntensity:
                (.42 + opticalIntensity * .45) * (windowsGlass ? .6 : 1),
            ambientStrength: .15,
            ambientRim: .07,
            saturation: 1.08,
            shadow: const [],
            backerColor: null,
          ),
          child: const SizedBox.expand(),
        ),
      );
    } else if (_opticalStyle == BrowserSurfaceStyle.frosted) {
      surface = ClipRRect(
        borderRadius: corners,
        child: BackdropFilter(
          enabled: opacity > 0 && widget.blur,
          // Keep the filter in the scene's backdrop pass while it dissolves.
          // An Opacity/ColorFiltered ancestor would isolate its input.
          filter: _frostedFilter(opacity),
          child: ColoredBox(
            color: (dark ? const Color(0xFF252A30) : Colors.white).withValues(
              alpha: (.48 + opticalIntensity * .08) * opacity,
            ),
          ),
        ),
      );
    } else {
      surface = const SizedBox.expand();
    }

    if (_opticalStyle != null && !_usesNative(_opticalStyle)) {
      // A zero shader visibility still submits the backdrop/refraction passes.
      // Skip painting fully hidden Flutter materials while retaining their
      // prepared renderers, without introducing a separate backdrop render pass.
      surface = Visibility(
        visible: opacity > 0,
        maintainState: true,
        maintainAnimation: true,
        maintainSize: true,
        child: surface,
      );
    }

    final solidColor = widget.clear
        ? Theme.of(context).colorScheme.surface
        : context.appColors.surfaceCard;
    final solidBorder = contrast
        ? Theme.of(context).colorScheme.onSurface.withValues(alpha: .6)
        : context.appColors.hairline;
    final cover = AnimatedBuilder(
      animation: _cover,
      builder: (context, _) => DecoratedBox(
        key: const ValueKey('browserMaterialCover'),
        decoration: BoxDecoration(
          color: solidColor.withValues(alpha: opacity * _cover.value),
          borderRadius: corners,
          border: Border.all(
            color: solidBorder.withValues(
              alpha: solidBorder.a * opacity * _cover.value,
            ),
            width: contrast ? 1.25 : .5,
          ),
        ),
      ),
    );

    final hasShadow =
        elevated &&
        (!_usesNative(style) || style != BrowserSurfaceStyle.liquid);
    final content = Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          key: const ValueKey('browserMaterialSurface'),
          child: IgnorePointer(child: surface),
        ),
        Positioned.fill(
          key: const ValueKey('browserMaterialCoverSlot'),
          child: IgnorePointer(child: cover),
        ),
        Positioned.fill(
          child: IgnorePointer(
            child: Builder(
              builder: (context) {
                final feedback = _BrowserGlassInteraction.of(context);
                return feedback.intensity <= 0
                    ? const SizedBox.expand()
                    : CustomPaint(
                        key: const ValueKey('browserGlassTouchLight'),
                        painter: _GlassTouchLightPainter(
                          radius: radius,
                          intensity:
                              feedback.intensity.clamp(0.0, 1.0) * opacity,
                          position: feedback.position,
                          touch: feedback.touch,
                          dark: dark,
                        ),
                      );
              },
            ),
          ),
        ),
        Opacity(
          key: const ValueKey('browserGlassForeground'),
          opacity: opacity,
          child: Padding(padding: padding, child: child),
        ),
        Positioned.fill(
          child: IgnorePointer(
            child: Builder(
              builder: (context) {
                if (!_BrowserGlassInteraction.of(context).focused) {
                  return const SizedBox.expand();
                }
                return DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: corners,
                    border: Border.all(
                      color: Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: opacity),
                      width: 2,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
    return RepaintBoundary(
      child: defaultTargetPlatform == TargetPlatform.android
          ? CustomPaint(
              painter: hasShadow
                  ? _BrowserSurfaceShadow(radius, (dark ? .19 : .10) * opacity)
                  : null,
              child: content,
            )
          : DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: corners,
                boxShadow: hasShadow
                    ? [
                        BoxShadow(
                          color: Colors.black.withValues(
                            alpha: (dark ? .19 : .10) * opacity,
                          ),
                          blurRadius: 22,
                          offset: const Offset(0, 6),
                        ),
                      ]
                    : null,
              ),
              child: content,
            ),
    );
  }
}

/// Feedback for icons embedded in a shared glass surface. It consumes the
/// nearest BrowserPress without adding another optical or native surface.
class BrowserControlFeedback extends StatelessWidget {
  const BrowserControlFeedback({
    super.key,
    required this.child,
    this.radius = 22,
  });

  final Widget child;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final interaction = _BrowserGlassInteraction.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final intensity = interaction.intensity.clamp(0.0, 1.0);
    final desktop = switch (defaultTargetPlatform) {
      TargetPlatform.macOS ||
      TargetPlatform.windows ||
      TargetPlatform.linux => true,
      _ => false,
    };
    return Stack(
      clipBehavior: Clip.none,
      children: [
        if (desktop)
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                key: const ValueKey('browserControlHitFootprint'),
                // macOS platform-view hit testing uses foreground paint
                // regions, not Flutter's gesture bounds. Keep the full local
                // control painted even when only its small icon is visible.
                decoration: BoxDecoration(
                  color: const Color(0x01000000),
                  borderRadius: BorderRadius.circular(radius),
                ),
              ),
            ),
          ),
        if (intensity > 0)
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                key: const ValueKey('browserControlFeedbackPaint'),
                painter: _GlassTouchLightPainter(
                  radius: radius,
                  intensity: intensity,
                  position: interaction.position,
                  touch: interaction.touch,
                  dark: dark,
                ),
              ),
            ),
          ),
        child,
        if (interaction.focused)
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                key: const ValueKey('browserControlFeedbackFocus'),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(radius),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.primary,
                    width: 2,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Press state is separate from the content so the material can respond to
/// pointer movement without painting a second rectangular highlight over it.
enum _BrowserInteractionPart { optics, feedback }

class _BrowserGlassInteraction extends InheritedModel<_BrowserInteractionPart> {
  const _BrowserGlassInteraction({
    required this.intensity,
    required this.position,
    required this.focused,
    required this.touch,
    required super.child,
  });

  final double intensity;
  final Offset position;
  final bool focused;
  final bool touch;

  static _BrowserGlassInteraction of(
    BuildContext context, {
    bool opticsOnly = false,
  }) =>
      InheritedModel.inheritFrom<_BrowserGlassInteraction>(
        context,
        aspect: opticsOnly
            ? _BrowserInteractionPart.optics
            : _BrowserInteractionPart.feedback,
      ) ??
      const _BrowserGlassInteraction(
        intensity: 0,
        position: Offset.zero,
        focused: false,
        touch: false,
        child: SizedBox.shrink(),
      );

  @override
  bool updateShouldNotify(_BrowserGlassInteraction oldWidget) =>
      intensity != oldWidget.intensity ||
      position != oldWidget.position ||
      focused != oldWidget.focused ||
      touch != oldWidget.touch;

  @override
  bool updateShouldNotifyDependent(
    _BrowserGlassInteraction oldWidget,
    Set<_BrowserInteractionPart> dependencies,
  ) =>
      dependencies.contains(_BrowserInteractionPart.feedback) ||
      (touch ? 0 : intensity) != (oldWidget.touch ? 0 : oldWidget.intensity) ||
      (touch ? Offset.zero : position) !=
          (oldWidget.touch ? Offset.zero : oldWidget.position);
}

/// A glass control grows under a finger, stretches toward it, and springs home.
/// Pointer cancellation, disabled controls, keyboard activation, and reduced
/// motion all share this interaction path. There is no Material ink layer.
class BrowserPress extends StatefulWidget {
  const BrowserPress({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.onLongPressStart,
    this.semanticLabel,
    this.enabled = true,
    this.draggable = false,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// Transfers the held pointer to an overlay without ending its gesture.
  /// When present, this handles pointer long presses; [onLongPress] remains
  /// the accessibility action and the fallback for existing callers.
  final void Function(int pointer, LongPressStartDetails details)?
  onLongPressStart;
  final String? semanticLabel;
  final bool enabled;
  final bool draggable;

  @override
  State<BrowserPress> createState() => _BrowserPressState();
}

class _BrowserPressState extends State<BrowserPress>
    with TickerProviderStateMixin {
  // Pointer dispatch visits the deepest hit first. Claiming there keeps nested
  // controls from also stretching a parent capsule or whole floating panel.
  static final Map<int, _BrowserPressState> _owners = {};
  late final AnimationController _motion = AnimationController.unbounded(
    vsync: this,
    value: 1,
  );
  late final AnimationController _light = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 120),
    reverseDuration: const Duration(milliseconds: 220),
  );
  late final CurvedAnimation _lightOpacity = CurvedAnimation(
    parent: _light,
    curve: Curves.easeOut,
    reverseCurve: Curves.easeInOut,
  );
  int? _pointer;
  Offset? _origin;
  Offset _fromScale = const Offset(1, 1);
  Offset _targetScale = const Offset(1, 1);
  Offset _fromOffset = Offset.zero;
  Offset _targetOffset = Offset.zero;
  Offset _position = Offset.zero;
  Size _controlSize = Size.zero;
  Offset _localPoint = Offset.zero;
  bool _focused = false;
  bool _hovered = false;
  bool _touch = false;
  bool _dragAccepted = false;
  bool _longPressAccepted = false;
  bool _allowTap = false;
  bool _feedbackStarted = false;
  bool _deferPress = false;

  bool get _reduceMotion => MediaQuery.disableAnimationsOf(context);
  bool get _mobile =>
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;

  // A surface inside a scrolling page is a tap target, not a competing pan.
  bool get _canDrag => widget.draggable && Scrollable.maybeOf(context) == null;

  // Telegram's shared TouchEffect uses different lift and release springs.
  // All transform components interpolate together from their current values.
  static const _liftOn = SpringDescription(
    mass: 1.36,
    stiffness: 568,
    damping: 39.7,
  );
  static const _liftOff = SpringDescription(
    mass: 2,
    stiffness: 460,
    damping: 21.8,
  );

  Offset get _currentScale =>
      Offset.lerp(_fromScale, _targetScale, _motion.value)!;
  Offset get _currentOffset =>
      Offset.lerp(_fromOffset, _targetOffset, _motion.value)!;

  void _setTransform({
    required Offset scale,
    required Offset offset,
    required bool pressed,
    bool animated = true,
  }) {
    final currentScale = _currentScale;
    final currentOffset = _currentOffset;
    _motion.stop();
    _fromScale = currentScale;
    _fromOffset = currentOffset;
    _targetScale = scale;
    _targetOffset = offset;
    if (!animated || _reduceMotion || !_touch) {
      _motion.value = 1;
    } else {
      _motion.value = 0;
      _motion.animateWith(
        SpringSimulation(pressed ? _liftOn : _liftOff, 0, 1, 0),
      );
    }
  }

  void _setTracking(bool tracking) {
    if (_reduceMotion || !_touch) {
      _light.value = tracking ? 1 : 0;
    } else if (tracking) {
      _light.forward();
    } else {
      _light.reverse();
    }
  }

  void _trackTransform(Offset delta, {required bool animated}) {
    final width = math.max(1.0, _controlSize.width);
    final height = math.max(1.0, _controlSize.height);
    final aspect = width / height;
    final base = 1 + 20 / math.max(width, height);
    final adjusted = Offset(delta.dx / aspect, delta.dy);
    final length = adjusted.distance;
    if (length == 0) {
      _setTransform(
        scale: Offset(base, base),
        offset: Offset.zero,
        pressed: true,
        animated: animated,
      );
      return;
    }
    final direction = adjusted / length;
    final k = 1 - 1 / (length / height / (5 * aspect) + 1);
    final stretch = 16 / height * k;
    final difference = (direction.dx.abs() - direction.dy.abs()).abs();
    final factor = 1 + stretch * difference;
    final horizontal = direction.dx.abs() > direction.dy.abs();
    _setTransform(
      scale: horizontal
          ? Offset(base * factor, base / factor)
          : Offset(base / factor, base * factor),
      offset: direction * (24 * k),
      pressed: true,
      animated: animated,
    );
  }

  bool _ownsPointer(int pointer) => identical(_owners[pointer], this);

  void _down(PointerDownEvent event) {
    if (_pointer != null || _owners.containsKey(event.pointer)) return;
    _owners[event.pointer] = this;
    _pointer = event.pointer;
    // Disabled children still shield their parent from a press/drag response.
    if (!widget.enabled) return;
    setState(() {
      _origin = event.position;
      _touch =
          _mobile &&
          (event.kind == PointerDeviceKind.touch ||
              event.kind == PointerDeviceKind.stylus ||
              event.kind == PointerDeviceKind.invertedStylus);
      _dragAccepted = false;
      _longPressAccepted = false;
      _allowTap = true;
      _feedbackStarted = false;
      _deferPress = _touch && Scrollable.maybeOf(context) != null;
      _updatePosition(event.localPosition);
    });
    if (!_deferPress) _beginFeedback();
  }

  void _beginFeedback() {
    if (_pointer == null || !widget.enabled || _feedbackStarted) return;
    _feedbackStarted = true;
    _trackTransform(Offset.zero, animated: true);
    _setTracking(true);
  }

  void _updatePosition(Offset local) {
    final box = context.findRenderObject() as RenderBox?;
    final size = box?.size;
    if (size == null || size.isEmpty) return;
    _controlSize = size;
    _localPoint = local;
    _position = Offset(
      (local.dx / size.width * 2 - 1).clamp(-1.0, 1.0),
      (local.dy / size.height * 2 - 1).clamp(-1.0, 1.0),
    );
  }

  void _move(PointerMoveEvent event) {
    if (!widget.enabled || event.pointer != _pointer) return;
    if (_deferPress && (event.position - _origin!).distance > kTouchSlop) {
      _release(cancelled: true);
      return;
    }
    setState(() {
      _updatePosition(event.localPosition);
      if (_feedbackStarted && _touch && _canDrag && !_reduceMotion) {
        _trackTransform(event.position - _origin!, animated: false);
      }
      // Pointer movement before the scroll/tap arena resolves must not flash
      // a full-strength highlight for a gesture that is actually scrolling.
      if (_feedbackStarted && _touch) _light.value = 1;
    });
  }

  void _release({int? pointer, bool cancelled = false}) {
    if (_pointer == null || (pointer != null && pointer != _pointer)) return;
    _owners.remove(_pointer);
    _pointer = null;
    _origin = null;
    _feedbackStarted = false;
    if (cancelled) _allowTap = false;
    _setTransform(
      scale: const Offset(1, 1),
      offset: Offset.zero,
      pressed: false,
    );
    if (cancelled && _deferPress) {
      _light.value = 0;
    } else {
      _setTracking(false);
    }
  }

  void _tapCancelled() {
    _allowTap = false;
    // Our pan/long-press recognizer can win in the same event. Otherwise the
    // surrounding scroll view won: immediately retire the press response.
    scheduleMicrotask(() {
      if (mounted && !_dragAccepted && !_longPressAccepted) {
        _release(cancelled: true);
      }
    });
  }

  void _startLongPress(LongPressStartDetails details) {
    final pointer = _pointer;
    _longPressAccepted = pointer != null && _ownsPointer(pointer);
    if (_longPressAccepted) {
      widget.onLongPressStart?.call(pointer!, details);
    }
  }

  void _endLongPress(LongPressEndDetails details) {
    _longPressAccepted = false;
    _release(cancelled: true);
  }

  @override
  void didUpdateWidget(BrowserPress oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.enabled && !widget.enabled) _release(cancelled: true);
  }

  @override
  void dispose() {
    if (_pointer != null && _ownsPointer(_pointer!)) _owners.remove(_pointer);
    _motion.dispose();
    _lightOpacity.dispose();
    _light.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasLongPress =
        widget.onLongPress != null || widget.onLongPressStart != null;
    final menuLongPress = _mobile && widget.onLongPressStart != null;
    final actionable = widget.onTap != null || hasLongPress;
    final motion = _touch && _mobile && !_reduceMotion;
    return Semantics(
      label: widget.semanticLabel,
      button: actionable,
      enabled: actionable ? widget.enabled : null,
      onTap: widget.enabled ? widget.onTap : null,
      onLongPress: widget.enabled ? widget.onLongPress : null,
      child: FocusableActionDetector(
        enabled: widget.enabled && actionable,
        mouseCursor: widget.enabled && actionable
            ? SystemMouseCursors.click
            : SystemMouseCursors.basic,
        onShowFocusHighlight: (value) => setState(() => _focused = value),
        onShowHoverHighlight: (value) => setState(() {
          _hovered = value;
          if (value) _touch = false;
        }),
        shortcuts: const {
          SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
          SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
        },
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              if (widget.enabled) widget.onTap?.call();
              return null;
            },
          ),
        },
        child: RawGestureDetector(
          gestures: {
            if (widget.enabled && menuLongPress)
              _BrowserMenuLongPressGestureRecognizer:
                  GestureRecognizerFactoryWithHandlers<
                    _BrowserMenuLongPressGestureRecognizer
                  >(
                    () => _BrowserMenuLongPressGestureRecognizer(
                      ownsPointer: _ownsPointer,
                    ),
                    (recognizer) => recognizer
                      ..onLongPressStart = _startLongPress
                      ..onLongPressEnd = _endLongPress,
                  ),
            if (_mobile && widget.enabled && _canDrag)
              _BrowserPanGestureRecognizer:
                  GestureRecognizerFactoryWithHandlers<
                    _BrowserPanGestureRecognizer
                  >(
                    () =>
                        _BrowserPanGestureRecognizer(ownsPointer: _ownsPointer),
                    (recognizer) => recognizer
                      ..onStart = (_) {
                        _dragAccepted = true;
                        _allowTap = false;
                      }
                      ..onUpdate = (_) {}
                      ..onEnd = (_) {
                        _dragAccepted = false;
                        _release(cancelled: true);
                      }
                      ..onCancel = () {
                        _dragAccepted = false;
                      },
                  ),
          },
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            excludeFromSemantics: true,
            onTapDown: widget.enabled ? (_) => _beginFeedback() : null,
            onTap: widget.enabled && widget.onTap != null
                ? () {
                    if (_allowTap) widget.onTap!();
                    _allowTap = false;
                  }
                : null,
            onTapCancel: widget.enabled ? _tapCancelled : null,
            onLongPressStart: widget.enabled && hasLongPress && !menuLongPress
                ? _startLongPress
                : null,
            onLongPress:
                widget.enabled &&
                    widget.onLongPress != null &&
                    widget.onLongPressStart == null
                ? () {
                    if (_longPressAccepted) widget.onLongPress!();
                  }
                : null,
            onLongPressEnd: widget.enabled && hasLongPress && !menuLongPress
                ? _endLongPress
                : null,
            child: Listener(
              behavior: HitTestBehavior.opaque,
              onPointerDown: _down,
              onPointerMove: _move,
              onPointerUp: (event) => _release(pointer: event.pointer),
              onPointerCancel: (event) =>
                  _release(pointer: event.pointer, cancelled: true),
              child: AnimatedBuilder(
                animation: Listenable.merge([_motion, _lightOpacity]),
                child: widget.child,
                builder: (context, child) {
                  final scale = motion ? _currentScale : const Offset(1, 1);
                  final offset = motion ? _currentOffset : Offset.zero;
                  final scaleX = scale.dx;
                  final scaleY = scale.dy;
                  final center = _controlSize.center(Offset.zero);
                  final point = _localPoint - center - offset;
                  final lightPosition = !_touch || _controlSize.isEmpty
                      ? _position
                      : Offset(
                          point.dx / scaleX / _controlSize.width * 2,
                          point.dy / scaleY / _controlSize.height * 2,
                        );
                  return Transform.translate(
                    key: const ValueKey('browserSpringTransform'),
                    offset: offset,
                    child: Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.diagonal3Values(scaleX, scaleY, 1),
                      child: _BrowserGlassInteraction(
                        intensity: widget.enabled
                            ? math.max(
                                _lightOpacity.value,
                                _focused ? .32 : (_hovered ? .3 : 0),
                              )
                            : 0,
                        position: lightPosition,
                        focused: _focused,
                        touch: _touch,
                        child: child!,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BrowserMenuLongPressGestureRecognizer
    extends LongPressGestureRecognizer {
  _BrowserMenuLongPressGestureRecognizer({required this.ownsPointer})
    : super(
        // ContextGesture's 120 ms delay plus 200 ms activation progress.
        duration: const Duration(milliseconds: 320),
        supportedDevices: const {
          PointerDeviceKind.touch,
          PointerDeviceKind.stylus,
          PointerDeviceKind.invertedStylus,
        },
      );

  final bool Function(int) ownsPointer;

  @override
  bool isPointerAllowed(PointerDownEvent event) =>
      ownsPointer(event.pointer) && super.isPointerAllowed(event);
}

class _BrowserPanGestureRecognizer extends PanGestureRecognizer {
  _BrowserPanGestureRecognizer({required this.ownsPointer})
    : super(
        supportedDevices: const {
          PointerDeviceKind.touch,
          PointerDeviceKind.stylus,
          PointerDeviceKind.invertedStylus,
        },
      );

  final bool Function(int) ownsPointer;

  @override
  bool isPointerAllowed(PointerEvent event) =>
      ownsPointer(event.pointer) && super.isPointerAllowed(event);
}

/// This is an illumination layer, not a backdrop replacement. Only its own
/// pixels are clipped; the live native/Impeller glass underneath stays intact.
class _GlassTouchLightPainter extends CustomPainter {
  const _GlassTouchLightPainter({
    required this.radius,
    required this.intensity,
    required this.position,
    required this.touch,
    required this.dark,
  });

  final double radius;
  final double intensity;
  final Offset position;
  final bool touch;
  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty || intensity <= 0) return;
    final bounds = Offset.zero & size;
    final cornerRadius = math.min(radius, size.shortestSide / 2);
    final shape = RRect.fromRectAndRadius(
      bounds,
      Radius.circular(cornerRadius),
    );
    canvas.save();
    canvas.clipRRect(shape);
    if (!touch) {
      canvas.drawRect(
        bounds,
        Paint()
          ..color = (dark ? Colors.white : Colors.black).withValues(
            alpha: .075 * intensity,
          ),
      );
      canvas.restore();
      return;
    }
    final point = Offset(
      (position.dx + 1) * size.width / 2,
      (position.dy + 1) * size.height / 2,
    );
    // Telegram's legacy TouchEffect clips a 300-point radial light to the
    // actual surface shape. It is not an edge-only mask or a pointer marker.
    // The whole layer peaks at 10% white; the outer half fades with easeInOut.
    final colors = <Color>[Colors.white.withValues(alpha: .1 * intensity)];
    final stops = <double>[0];
    for (var index = 0; index < 7; index++) {
      final step = index / 6;
      colors.add(
        Colors.white.withValues(
          alpha: .05 * (1 - Curves.easeInOut.transform(step)) * intensity,
        ),
      );
      stops.add(.5 + .5 * step);
    }
    canvas.drawRect(
      bounds,
      Paint()
        ..shader = RadialGradient(
          colors: colors,
          stops: stops,
        ).createShader(Rect.fromCircle(center: point, radius: 150)),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_GlassTouchLightPainter oldDelegate) =>
      radius != oldDelegate.radius ||
      intensity != oldDelegate.intensity ||
      position != oldDelegate.position ||
      touch != oldDelegate.touch ||
      dark != oldDelegate.dark;
}

/// Passive drag affordance retained for browser groups with their own controls.
class BrowserSpring extends StatelessWidget {
  const BrowserSpring({super.key, required this.child, this.draggable = true});

  final Widget child;
  final bool draggable;

  @override
  Widget build(BuildContext context) =>
      BrowserPress(draggable: draggable, child: child);
}

/// Static silver silk: enough edges and tonal depth for optical glass to bend,
/// with no image capture, asset decoding, animated noise, or idle tickers.
class BrowserWallpaper extends StatelessWidget {
  const BrowserWallpaper({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: CustomPaint(
      painter: _WallpaperPainter(
        colors: Theme.of(context).colorScheme,
        highContrast: MediaQuery.highContrastOf(context),
      ),
      child: child,
    ),
  );
}

class _WallpaperPainter extends CustomPainter {
  const _WallpaperPainter({required this.colors, required this.highContrast});

  final ColorScheme colors;
  bool get dark => colors.brightness == Brightness.dark;
  final bool highContrast;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colors.surface,
            colors.surfaceContainerLow,
            colors.surfaceContainer,
          ],
        ).createShader(rect),
    );
    if (highContrast) return;
    canvas.save();
    canvas.clipRect(rect);
    final h = size.height;
    final w = size.width;
    for (var i = 0; i < 5; i++) {
      final shift = i * h * .055;
      final ribbon = Path()
        ..moveTo(-w * .3, h * .70 + shift)
        ..cubicTo(
          w * .20,
          h * .48 + shift,
          w * .38,
          h * 1.08 + shift,
          w * 1.25,
          h * .60 + shift,
        )
        ..lineTo(w * 1.25, h * .78 + shift)
        ..cubicTo(
          w * .40,
          h * 1.22 + shift,
          w * .10,
          h * .57 + shift,
          -w * .3,
          h * .90 + shift,
        )
        ..close();
      canvas.drawPath(
        ribbon,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              colors.onSurface.withValues(alpha: dark ? .05 : .025),
              colors.onSurfaceVariant.withValues(alpha: dark ? .04 : .02),
              colors.surfaceContainerHigh.withValues(alpha: .34),
            ],
          ).createShader(rect),
      );
    }
    final grain = math.Random(17);
    final dot = Paint()
      ..color = (dark ? Colors.white : Colors.black).withValues(
        alpha: dark ? .022 : .008,
      )
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;
    // Preserve the fine grain with one draw instead of 650 individual circles.
    canvas.drawPoints(PointMode.points, [
      for (var i = 0; i < 650; i++)
        Offset(grain.nextDouble() * w, grain.nextDouble() * h),
    ], dot);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_WallpaperPainter oldDelegate) =>
      oldDelegate.colors != colors || oldDelegate.highContrast != highContrast;
}

class _BrowserSurfaceShadow extends CustomPainter {
  const _BrowserSurfaceShadow(this.radius, this.opacity);
  final double radius;
  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    if (opacity <= 0) return;
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius)),
      );
    canvas.drawShadow(path, Colors.black.withValues(alpha: opacity), 6, true);
  }

  @override
  bool shouldRepaint(_BrowserSurfaceShadow oldDelegate) =>
      radius != oldDelegate.radius || opacity != oldDelegate.opacity;
}

ImageFilter _frostedFilter(double opacity) {
  final sigma = 20 * opacity;
  if (defaultTargetPlatform != TargetPlatform.android) {
    return ImageFilter.blur(sigmaX: sigma, sigmaY: sigma);
  }
  // Blur a smaller intermediate while preserving the same effective radius.
  // A fixed small kernel avoids large Gaussian passes and changing kernels
  // throughout an optical fade. The foreground and webpage stay full resolution.
  final scale = (sigma / 5).clamp(1.0, 4.0);
  final blur = ImageFilter.blur(sigmaX: sigma / scale, sigmaY: sigma / scale);
  if (scale == 1) return blur;
  return ImageFilter.compose(
    outer: ImageFilter.matrix(Matrix4.diagonal3Values(scale, scale, 1).storage),
    inner: ImageFilter.compose(
      outer: blur,
      inner: ImageFilter.matrix(
        Matrix4.diagonal3Values(1 / scale, 1 / scale, 1).storage,
      ),
    ),
  );
}
