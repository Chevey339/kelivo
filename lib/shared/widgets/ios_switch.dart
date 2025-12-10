import 'dart:math' as math;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Theme; // for Material color scheme primary
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
    final brightness = CupertinoTheme.brightnessOf(context);
    // Prefer Material color scheme primary to better match app theme; fall back to Cupertino default
    final primary = widget.activeColor ??
        (Theme.of(context).colorScheme.primary);

    final bool isDark = brightness == Brightness.dark;
    final bool isOn = widget.value;

    // Track color when OFF; dark mode uses a deeper fill
    final Color offTrack = widget.inactiveColor ??
        (isDark
            ? CupertinoDynamicColor.resolve(CupertinoColors.systemGrey6, context)
            : const Color(0x14000000)); // subtle black overlay on light

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
        color: (brightness == Brightness.dark
                ? CupertinoColors.systemGrey3
                : CupertinoColors.systemGrey4)
            .withOpacity(enabled ? 0.65 : 0.35),
        width: 1,
      ),
    );

    // Thumb color:
    // - Dark + OFF: medium grey for thumb
    // - Dark + ON: keep prior non-white thumb to match design
    // - Light: white thumb
    final Color thumb = widget.thumbColor ?? (
      isDark
          ? (isOn
              ? CupertinoDynamicColor.resolve(CupertinoColors.systemGrey6, context)
              : CupertinoDynamicColor.resolve(CupertinoColors.systemGrey2, context))
          : CupertinoColors.white
    );

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
                      alignment:
                          widget.value ? Alignment.centerRight : Alignment.centerLeft,
                      child: _Thumb(
                        size: thumbSize,
                        color: enabled ? thumb : thumb.withOpacity(0.7),
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
    final sp = context.read<SettingsProvider>();
    if (widget.enableHaptics && sp.hapticsIosSwitch) Haptics.soft();
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
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }
}
 
