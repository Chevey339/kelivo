import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'dart:ui' as ui;
import '../../../l10n/app_localizations.dart';
import '../../../icons/lucide_adapter.dart';
import '../../../core/services/haptics.dart';

/// Toolbar for selection mode with cancel and confirm buttons.
class SelectionToolbar extends StatelessWidget {
  const SelectionToolbar({
    super.key,
    required this.onCancel,
    required this.onConfirm,
    required this.onSelectAll,
    required this.onClearAll,
  });

  final VoidCallback onCancel;
  final VoidCallback onConfirm;
  final VoidCallback onSelectAll;
  final VoidCallback onClearAll;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final captionStyle = theme.textTheme.labelSmall?.copyWith(
      color: cs.onSurfaceVariant,
      fontSize: 11,
      height: 1.1,
    );

    double measureCaptionWidth(String text) {
      final painter = TextPainter(
        text: TextSpan(text: text, style: captionStyle),
        textDirection: Directionality.of(context),
        maxLines: 2,
        textAlign: TextAlign.center,
      )..layout();
      return painter.size.width;
    }

    final captions = <String>[
      AppLocalizations.of(context)!.homePageCancel,
      AppLocalizations.of(context)!.homePageDone,
      AppLocalizations.of(context)!.homePageSelectAll,
      AppLocalizations.of(context)!.homePageClearAll,
    ];
    final maxCaptionWidth = captions.map(measureCaptionWidth).fold(0.0, math.max);
    final actionWidth = math.max(maxCaptionWidth, 40).toDouble();

    Widget buildAction({
      required IconData icon,
      required Color color,
      required VoidCallback onTap,
      required String semanticLabel,
      required String caption,
    }) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GlassCircleButtonSmall(
            icon: icon,
            color: color,
            onTap: onTap,
            semanticLabel: semanticLabel,
          ),
          const SizedBox(height: 4),
          Text(
            caption,
            textAlign: TextAlign.center,
            maxLines: 2,
            style: theme.textTheme.labelSmall?.copyWith(
              color: cs.onSurfaceVariant,
              fontSize: 11,
              height: 1.1,
            ),
          ),
        ],
      );
    }
    final isDark = theme.brightness == Brightness.dark;
    final glassBase = isDark ? Colors.black.withOpacity(0.12) : Colors.white.withOpacity(0.72);
    final borderColor = isDark
        ? cs.outlineVariant.withOpacity(0.25)
        : cs.onSurfaceVariant.withOpacity(0.12);
    // Use compact icon-only glass buttons to avoid taking too much width
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: glassBase,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor, width: 1.0),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: actionWidth,
                child: buildAction(
                  icon: Lucide.X,
                  color: cs.onSurface,
                  onTap: onCancel,
                  semanticLabel: AppLocalizations.of(context)!.homePageCancel,
                  caption: AppLocalizations.of(context)!.homePageCancel,
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: actionWidth,
                child: buildAction(
                  icon: Lucide.Check,
                  color: cs.primary,
                  onTap: onConfirm,
                  semanticLabel: AppLocalizations.of(context)!.homePageDone,
                  caption: AppLocalizations.of(context)!.homePageDone,
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: actionWidth,
                child: buildAction(
                  icon: Lucide.CopyCheck,
                  color: cs.onSurface,
                  onTap: onSelectAll,
                  semanticLabel: AppLocalizations.of(context)!.homePageSelectAll,
                  caption: AppLocalizations.of(context)!.homePageSelectAll,
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: actionWidth,
                child: buildAction(
                  icon: Lucide.CopyMinus,
                  color: cs.onSurface,
                  onTap: onClearAll,
                  semanticLabel: AppLocalizations.of(context)!.homePageClearAll,
                  caption: AppLocalizations.of(context)!.homePageClearAll,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Animated container that slides/fades in/out like provider multi-select bar.
class AnimatedSelectionBar extends StatelessWidget {
  const AnimatedSelectionBar({
    super.key,
    required this.visible,
    required this.child,
  });

  final bool visible;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedSlide(
      offset: visible ? Offset.zero : const Offset(0, 1),
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      child: AnimatedOpacity(
        opacity: visible ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        child: IgnorePointer(ignoring: !visible, child: child),
      ),
    );
  }
}

/// iOS-style glass capsule button (no ripple), similar to providers multi-select style.
class GlassCapsuleButton extends StatefulWidget {
  const GlassCapsuleButton({
    super.key,
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  State<GlassCapsuleButton> createState() => _GlassCapsuleButtonState();
}

class _GlassCapsuleButtonState extends State<GlassCapsuleButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    // Glass background, match providers' capsule taste
    final glassBase = isDark ? Colors.black.withOpacity(0.06) : Colors.white.withOpacity(0.65);
    final overlay = isDark ? Colors.black.withOpacity(0.06) : Colors.black.withOpacity(0.05);
    final tileColor = _pressed ? Color.alphaBlend(overlay, glassBase) : glassBase;
    final borderColor = cs.outlineVariant.withOpacity(isDark ? 0.35 : 0.40);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: () {
        Haptics.light();
        widget.onTap();
      },
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOutCubic,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: tileColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: borderColor, width: 1.0),
              ),
              alignment: Alignment.center,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(widget.icon, size: 16, color: widget.color),
                  const SizedBox(width: 6),
                  Text(
                    widget.label,
                    style: TextStyle(color: widget.color, fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Compact icon-only glass button to minimize width (like providers multi-select icons).
class GlassCircleButtonSmall extends StatefulWidget {
  const GlassCircleButtonSmall({
    super.key,
    required this.icon,
    required this.color,
    required this.onTap,
    this.semanticLabel,
    this.size = 40,
  });

  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final String? semanticLabel;
  final double size; // diameter

  @override
  State<GlassCircleButtonSmall> createState() => _GlassCircleButtonSmallState();
}

class _GlassCircleButtonSmallState extends State<GlassCircleButtonSmall> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final glassBase = isDark ? Colors.black.withOpacity(0.06) : Colors.white.withOpacity(0.06);
    final overlay = isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.05);
    final tileColor = _pressed ? Color.alphaBlend(overlay, glassBase) : glassBase;
    final borderColor = cs.outlineVariant.withOpacity(isDark ? 0.10 : 0.10);

    final child = SizedBox(
      width: widget.size,
      height: widget.size,
      child: Center(child: Icon(widget.icon, size: 18, color: widget.color)),
    );

    return Semantics(
      button: true,
      label: widget.semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: () {
          Haptics.light();
          widget.onTap();
        },
        child: AnimatedScale(
          scale: _pressed ? 0.95 : 1.0,
          duration: const Duration(milliseconds: 110),
          curve: Curves.easeOutCubic,
          child: ClipOval(
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                decoration: BoxDecoration(
                  color: tileColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: borderColor, width: 1.0),
                ),
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
