import 'dart:math' as math;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart'
    show Theme; // for Material color scheme primary
import '../../core/services/haptics.dart';
import 'package:provider/provider.dart';
import '../../core/providers/settings_provider.dart';

/// A refined, iOS‑inspired switch with subtle animations
/// tailored to the app's visual style.
class IosSwitch extends StatefulWidget {
  const IosSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    this.width = 44,
    this.height = 26,
    this.activeColor,
    this.inactiveColor,
    this.thumbColor,
    this.shadowColor,
    this.enableHaptics = true,
    this.semanticLabel,
    this.animationDuration = const Duration(milliseconds: 220),
    this.animationCurve = Curves.easeOutCubic,
    this.hitTestSize = 44,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;

  // Sizing
  final double width;
  final double height;
  final double hitTestSize; // Minimum tap target extent for both width/height

  // Colors
  final Color? activeColor; // track when ON
  final Color? inactiveColor; // track when OFF
  final Color? thumbColor; // thumb fill
  final Color? shadowColor; // thumb shadow

  // UX
  final bool enableHaptics;
  final String? semanticLabel;

  // Animation
  final Duration animationDuration;
  final Curve animationCurve;

  @override
  State<IosSwitch> createState() => _IosSwitchState();
}

class _IosSwitchState extends State<IosSwitch> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    // Prefer Material color scheme primary to better match app theme; fall back to Cupertino default
    final primary = widget.activeColor ?? cs.primary;

    final bool isDark = theme.brightness == Brightness.dark;
    final bool isOn = widget.value;

    // Track color when OFF; dark mode uses a deeper fill.
    // Matches the original Cupertino look (light: black @ ~0.08,
    // dark: systemGrey6 #1C1C1E) derived from the active scheme.
    final Color offTrack =
        widget.inactiveColor ??
        (isDark
            ? Color.alphaBlend(cs.onSurface.withValues(alpha: 0.02), cs.surface)
            : cs.onSurface.withValues(alpha: 0.08));

    final bool enabled = widget.onChanged != null;
    final double radius = widget.height / 2;
    final double thumbSize = widget.height - 6; // visual margin
    final double tapW = math.max(widget.width, widget.hitTestSize);
    final double tapH = math.max(widget.height, widget.hitTestSize);
    final double pressScale = _pressed && enabled ? 0.98 : 1.0;

    // Minimal solid active track, no glow/shadow
    final Decoration onDecoration = BoxDecoration(
      borderRadius: BorderRadius.circular(radius),
      color: primary,
    );

    final Decoration offDecoration = BoxDecoration(
      color: offTrack,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        // systemGrey3/4 @ 0.65/0.35 in the original design; outlineVariant is
        // pure black/white in some palettes, so derive from onSurface instead.
        color: cs.onSurface.withValues(
          alpha: (isDark ? 0.24 : 0.20) * (enabled ? 0.65 : 0.35),
        ),
        width: 1,
      ),
    );

    // Thumb color (matches the original Cupertino greys):
    // - Dark + OFF: medium grey (#636366)
    // - Dark + ON: deep grey (#1C1C1E)
    // - Light: white thumb
    final Color thumb =
        widget.thumbColor ??
        (isDark
            ? (isOn
                  ? Color.alphaBlend(
                      cs.onSurface.withValues(alpha: 0.02),
                      cs.surface,
                    )
                  : Color.alphaBlend(
                      cs.onSurface.withValues(alpha: 0.36),
                      cs.surface,
                    ))
            : cs.surfaceContainerLowest);

    return Semantics(
      label: widget.semanticLabel,
      checked: widget.value,
      button: false,
      enabled: enabled,
      onTap: enabled ? _handleTap : null,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: enabled ? _handleTap : null,
        onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
        onTapUp: enabled ? (_) => setState(() => _pressed = false) : null,
        onTapCancel: enabled ? () => setState(() => _pressed = false) : null,
        child: SizedBox(
          width: tapW,
          height: tapH,
          child: Center(
            child: AnimatedScale(
              scale: pressScale,
              duration: const Duration(milliseconds: 100),
              curve: Curves.easeOut,
              child: AnimatedContainer(
                duration: widget.animationDuration,
                curve: widget.animationCurve,
                width: widget.width,
                height: widget.height,
                padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 3),
                decoration: widget.value ? onDecoration : offDecoration,
                child: Stack(
                  children: [
                    // Thumb
                    AnimatedAlign(
                      duration: widget.animationDuration,
                      curve: widget.animationCurve,
                      alignment: widget.value
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: _Thumb(
                        size: thumbSize,
                        color: enabled ? thumb : thumb.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _handleTap() {
    // Only vibrate if both widget-level and settings-level toggles allow,
    // global master switch is enforced within Haptics.* methods.
    if (widget.enableHaptics) {
      var hapticsOn = false;
      try {
        hapticsOn = context.read<SettingsProvider>().hapticsIosSwitch;
      } catch (_) {}
      if (hapticsOn) Haptics.soft();
    }
    widget.onChanged?.call(!widget.value);
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}
