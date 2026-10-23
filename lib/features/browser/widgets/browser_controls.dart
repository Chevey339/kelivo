import '../../../theme/app_semantic_colors.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'browser_text_field.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../l10n/app_localizations.dart';
import 'browser_glass.dart';
import '../models/browser_models.dart';

/// Browser controls intentionally have no Material ink or app-wide press paint.
class BrowserActionButton extends StatelessWidget {
  const BrowserActionButton({
    super.key,
    required this.label,
    required this.icon,
    this.onPressed,
    this.selected = false,
    this.compact = false,
    this.child,
    this.surface = false,
    this.onLongPress,
    this.onLongPressStart,
    this.opacity = 1,
    this.anchorKey,
    this.iconSize,
    this.size,
    this.useParentFeedback = false,
    this.foregroundShadows,
  });
  final double opacity;
  final double? iconSize;
  final double? size;
  final List<Shadow>? foregroundShadows;

  /// Split actions in one capsule use its shared press/light, while preserving
  /// independent pointer, keyboard and accessibility activation.
  final bool useParentFeedback;
  final GlobalKey? anchorKey;
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final VoidCallback? onLongPress;
  final void Function(int pointer, LongPressStartDetails details)?
  onLongPressStart;
  final bool selected, compact, surface;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final enabled = onPressed != null;
    final color = (selected ? cs.primary : cs.onSurface).withValues(
      alpha: enabled ? 1 : .28,
    );
    Widget content = SizedBox(
      width: size ?? (compact ? 38 : 48),
      height: size ?? (compact ? 38 : 48),
      child: Center(
        child: IconTheme(
          data: IconThemeData(
            color: color,
            size: iconSize ?? (compact ? 16 : 23),
            shadows: enabled ? foregroundShadows : const [],
          ),
          child: child ?? Icon(icon),
        ),
      ),
    );
    if (useParentFeedback) {
      return Tooltip(
        message: label,
        triggerMode: TooltipTriggerMode.manual,
        child: Semantics(
          label: label,
          child: CupertinoButton(
            padding: EdgeInsets.zero,
            minimumSize: Size.zero,
            pressedOpacity: 1,
            borderRadius: BorderRadius.circular(1000),
            onPressed: onPressed,
            onLongPress: enabled ? onLongPress : null,
            child: content,
          ),
        ),
      );
    }
    content = surface
        ? BrowserGlass(radius: 1000, opacity: opacity, child: content)
        : BrowserControlFeedback(radius: 1000, child: content);
    return Tooltip(
      message: label,
      triggerMode: TooltipTriggerMode.manual,
      child: BrowserPress(
        enabled: enabled,
        semanticLabel: label,
        onTap: onPressed,
        onLongPress: onLongPress,
        onLongPressStart: onLongPressStart,
        draggable: surface,
        child: KeyedSubtree(key: anchorKey, child: content),
      ),
    );
  }
}

class BrowserAddressBar extends StatelessWidget {
  const BrowserAddressBar({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.onSubmitted,
    required this.loading,
    required this.progress,
    required this.onReload,
    required this.secure,
    this.compact = false,
    this.editing = true,
    this.collapseProgress = 0,
    this.onEdit,
    this.onPageMenu,
    this.displayText,
    this.opacity = 1,
    this.foregroundShadows,
    this.siteIcon,
    this.expandedContentWidth,
    this.collapsedContentWidth,
    this.stabilizeTruncation = false,
  });
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onSubmitted;
  final bool loading, secure, compact, editing;
  final double collapseProgress;
  final double opacity;
  bool get collapsed => collapseProgress >= .995;
  final double progress;
  final VoidCallback? onReload, onEdit, onPageMenu;
  final String? displayText;
  final List<Shadow>? foregroundShadows;
  final Widget? siteIcon;
  final double? expandedContentWidth, collapsedContentWidth;
  final bool stabilizeTruncation;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final appTextStyle = Theme.of(context).textTheme.bodyMedium!;
    final t = collapseProgress.clamp(0.0, 1.0);
    Widget contents(double t) {
      final collapsed = t >= .995;
      final expandedHeight = compact ? 32.0 : 48.0;
      final height = expandedHeight + (34 - expandedHeight) * t;
      Widget sideControl(Widget child) => ClipRect(
        child: Align(
          widthFactor: 1 - t,
          child: Opacity(opacity: 1 - t, child: child),
        ),
      );
      return SizedBox(
        height: height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 5 + 7 * t),
              child: Row(
                children: [
                  if (!collapsed && !editing && !compact)
                    sideControl(
                      BrowserActionButton(
                        compact: true,
                        label: l.browserPageOptions,
                        icon: LucideIcons.globe,
                        onPressed: onPageMenu,
                        foregroundShadows: foregroundShadows,
                        child: siteIcon,
                      ),
                    ),
                  if (compact && !editing) const SizedBox(width: 30),
                  if (editing) const SizedBox(width: 12),
                  Expanded(
                    child: editing
                        ? BrowserTextField(
                            key: const ValueKey('browserAddressField'),
                            controller: controller,
                            focusNode: focusNode,
                            autofocus: false,
                            autocorrect: false,
                            enableSuggestions: false,
                            keyboardType: TextInputType.url,
                            textInputAction: TextInputAction.go,
                            placeholder: l.browserSearchHint,
                            placeholderStyle: TextStyle(
                              color: cs.onSurfaceVariant,
                              fontSize: compact ? 12.5 : 15,
                              shadows: foregroundShadows,
                            ),
                            style: TextStyle(
                              fontFamily: appTextStyle.fontFamily,
                              fontFamilyFallback:
                                  appTextStyle.fontFamilyFallback,
                              color: cs.onSurface,
                              fontSize: compact ? 13 : 16,
                              shadows: foregroundShadows,
                            ),
                            padding: EdgeInsets.symmetric(
                              vertical: compact ? 5 : 8,
                            ),
                            onSubmitted: onSubmitted,
                          )
                        : _AddressLabel(
                            displayText?.isNotEmpty == true
                                ? displayText!
                                : l.browserSearchHint,
                            scale: compact ? 1 : (16 - 3 * t) / 16,
                            style: TextStyle(
                              color: cs.onSurface,
                              shadows: foregroundShadows,
                              fontSize: compact ? 12.5 : 16,
                              height: 1.15,
                              fontWeight: compact
                                  ? FontWeight.w400
                                  : FontWeight.w500,
                            ),
                          ),
                  ),
                  if (!collapsed)
                    sideControl(
                      BrowserActionButton(
                        compact: true,
                        size: compact ? 30 : null,
                        iconSize: compact ? 14 : null,
                        label: loading ? l.browserStop : l.browserReload,
                        icon: loading ? LucideIcons.x : LucideIcons.rotateCw,
                        onPressed: onReload,
                        foregroundShadows: foregroundShadows,
                      ),
                    ),
                ],
              ),
            ),
            if (loading)
              Positioned(
                left: 18,
                right: 18,
                bottom: 0,
                child: LinearProgressIndicator(
                  minHeight: 2,
                  value: progress.clamp(.03, 1),
                  backgroundColor: Colors.transparent,
                  color: cs.primary,
                ),
              ),
          ],
        ),
      );
    }

    final content =
        stabilizeTruncation &&
            !editing &&
            !compact &&
            expandedContentWidth != null &&
            collapsedContentWidth != null &&
            t > 0 &&
            t < 1
        ? ClipRect(
            child: Stack(
              fit: StackFit.expand,
              children: [
                for (final endpoint in [0.0, 1.0])
                  IgnorePointer(
                    child: Opacity(
                      opacity: endpoint == 0 ? 1 - t : t,
                      child: OverflowBox(
                        minWidth: endpoint == 0
                            ? expandedContentWidth
                            : collapsedContentWidth,
                        maxWidth: endpoint == 0
                            ? expandedContentWidth
                            : collapsedContentWidth,
                        minHeight: endpoint == 0 ? 48 : 34,
                        maxHeight: endpoint == 0 ? 48 : 34,
                        child: contents(endpoint),
                      ),
                    ),
                  ),
              ],
            ),
          )
        : contents(t);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final solid =
        BrowserGlassScope.of(context) == BrowserSurfaceStyle.solid ||
        MediaQuery.highContrastOf(context);
    final surface = compact
        ? DecoratedBox(
            key: const ValueKey('browserDesktopAddressSurface'),
            decoration: BoxDecoration(
              color: solid
                  ? context.appColors.surfaceFill
                  : Colors.white.withValues(alpha: dark ? .08 : .38),
              borderRadius: BorderRadius.circular(1000),
              border: Border.all(
                color: cs.onSurface.withValues(alpha: .08),
                width: .5,
              ),
            ),
            child: BrowserControlFeedback(radius: 1000, child: content),
          )
        : BrowserGlass(radius: 1000, opacity: opacity, child: content);
    return BrowserPress(
      onTap: editing ? null : onEdit,
      semanticLabel: editing ? null : l.browserSearchHint,
      draggable: !compact && !editing,
      child: surface,
    );
  }
}

/// Keep one font size/line box while the capsule moves. Fractional font-size
/// layouts round ascent/descent independently, making the URL baseline wobble.
class _AddressLabel extends StatelessWidget {
  const _AddressLabel(this.text, {required this.scale, required this.style});
  final String text;
  final double scale;
  final TextStyle style;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => Transform.scale(
      scale: scale,
      child: OverflowBox(
        minWidth: constraints.maxWidth / scale,
        maxWidth: constraints.maxWidth / scale,
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: style,
        ),
      ),
    ),
  );
}

class BrowserEmptyState extends StatelessWidget {
  const BrowserEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.action,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 36, color: cs.onSurfaceVariant),
              const SizedBox(height: 18),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 10),
                Text(
                  subtitle!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    height: 1.5,
                    fontSize: 13,
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ],
              if (action != null) ...[const SizedBox(height: 20), action!],
            ],
          ),
        ),
      ),
    );
  }
}
