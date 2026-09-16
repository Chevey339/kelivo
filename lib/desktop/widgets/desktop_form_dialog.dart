import 'package:flutter/material.dart';

import '../../icons/lucide_adapter.dart';
import '../../shared/widgets/ios_tactile.dart';
import '../../theme/app_font_weights.dart';
import 'package:Kelivo/theme/app_semantic_colors.dart';

/// Shared desktop form-dialog chrome used by model spec editing.
///
/// Matches the width, radius, header, and footer conventions of
/// [showDesktopAddProviderDialog] / MCP edit without restyling those dialogs.
class DesktopFormDialog extends StatelessWidget {
  const DesktopFormDialog({
    super.key,
    required this.child,
    this.constraints = const BoxConstraints(
      minWidth: 580,
      maxWidth: 720,
      maxHeight: 640,
    ),
  });

  final Widget child;
  final BoxConstraints constraints;

  static const double cornerRadius = 16;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: ConstrainedBox(
        constraints: constraints,
        child: Material(
          color: context.overlaySurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(cornerRadius),
            side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.25)),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(cornerRadius),
            child: child,
          ),
        ),
      ),
    );
  }
}

class DesktopFormDialogHeader extends StatelessWidget {
  const DesktopFormDialogHeader({
    super.key,
    required this.title,
    required this.onClose,
    this.closeTooltip,
    this.closeSemanticLabel,
  });

  final String title;
  final VoidCallback onClose;
  final String? closeTooltip;
  final String? closeSemanticLabel;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      height: 52,
      color: context.overlaySurface,
      padding: const EdgeInsets.fromLTRB(16, 10, 8, 0),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: AppFontWeights.emphasis,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IosIconButton(
            icon: Lucide.X,
            size: 20,
            minSize: 36,
            tooltip: closeTooltip,
            semanticLabel: closeSemanticLabel,
            color: cs.onSurface.withValues(alpha: 0.9),
            onTap: onClose,
          ),
        ],
      ),
    );
  }
}

class DesktopFormDialogFooter extends StatelessWidget {
  const DesktopFormDialogFooter({
    super.key,
    this.secondaryLabel,
    this.onSecondary,
    required this.primaryLabel,
    required this.onPrimary,
    this.primaryIcon,
    this.primaryKey,
  });

  final String? secondaryLabel;
  final VoidCallback? onSecondary;
  final String primaryLabel;
  final VoidCallback onPrimary;
  final IconData? primaryIcon;
  final Key? primaryKey;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Row(
        children: [
          const Spacer(),
          if (secondaryLabel != null && onSecondary != null) ...[
            DesktopFormTextButton(label: secondaryLabel!, onTap: onSecondary!),
            const SizedBox(width: 8),
          ],
          DesktopFormPrimaryButton(
            key: primaryKey,
            icon: primaryIcon,
            label: primaryLabel,
            onTap: onPrimary,
          ),
        ],
      ),
    );
  }
}

/// Settings-style left-nav row for desktop form dialogs.
class DesktopFormDialogNavItem extends StatefulWidget {
  const DesktopFormDialogNavItem({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.subtitle,
    this.enabled = true,
  });

  final String label;
  final String? subtitle;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  State<DesktopFormDialogNavItem> createState() =>
      _DesktopFormDialogNavItemState();
}

class _DesktopFormDialogNavItemState extends State<DesktopFormDialogNavItem> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final selected = widget.selected && widget.enabled;
    final bg = selected
        ? cs.primary.withValues(alpha: 0.10)
        : (_hover && widget.enabled
              ? cs.onSurface.withValues(alpha: isDark ? 0.06 : 0.04)
              : Colors.transparent);
    final fg = selected
        ? cs.primary
        : cs.onSurface.withValues(alpha: widget.enabled ? 0.9 : 0.45);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        cursor: widget.enabled
            ? SystemMouseCursors.click
            : SystemMouseCursors.basic,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.enabled ? widget.onTap : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOutCubic,
            constraints: const BoxConstraints(minHeight: 40),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  widget.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: AppFontWeights.regular,
                    color: fg,
                    decoration: TextDecoration.none,
                  ),
                ),
                if (widget.subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    widget.subtitle!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      color: cs.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class DesktopFormTextButton extends StatefulWidget {
  const DesktopFormTextButton({
    super.key,
    required this.label,
    required this.onTap,
  });

  final String label;
  final VoidCallback onTap;

  @override
  State<DesktopFormTextButton> createState() => _DesktopFormTextButtonState();
}

class _DesktopFormTextButtonState extends State<DesktopFormTextButton> {
  bool _hover = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bg = _pressed
        ? cs.onSurface.withValues(alpha: 0.08)
        : (_hover ? cs.onSurface.withValues(alpha: 0.05) : Colors.transparent);
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            widget.label,
            style: TextStyle(
              color: cs.onSurface.withValues(alpha: 0.82),
              fontWeight: AppFontWeights.semibold,
            ),
          ),
        ),
      ),
    );
  }
}

class DesktopFormPrimaryButton extends StatefulWidget {
  const DesktopFormPrimaryButton({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
  });

  final String label;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  State<DesktopFormPrimaryButton> createState() =>
      _DesktopFormPrimaryButtonState();
}

class _DesktopFormPrimaryButtonState extends State<DesktopFormPrimaryButton> {
  bool _hover = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bg = _pressed
        ? cs.primary.withValues(alpha: 0.85)
        : (_hover ? cs.primary.withValues(alpha: 0.92) : cs.primary);
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.icon != null) ...[
                Icon(widget.icon, size: 16, color: cs.onPrimary),
                const SizedBox(width: 8),
              ],
              Text(
                widget.label,
                style: TextStyle(
                  color: cs.onPrimary,
                  fontWeight: AppFontWeights.semibold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
