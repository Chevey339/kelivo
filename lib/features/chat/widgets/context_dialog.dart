import 'package:flutter/material.dart';

import '../../../desktop/widgets/desktop_form_dialog.dart';
import '../../../icons/lucide_adapter.dart';
import '../../../shared/widgets/ios_tactile.dart';
import '../../../shared/widgets/section_card.dart';
import '../../../theme/app_font_weights.dart';
import '../../../theme/app_semantic_colors.dart';

/// The existing compression dialog surface, shared by context actions.
class ContextDialog extends StatelessWidget {
  const ContextDialog({super.key, required this.child, this.maxWidth = 420});
  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) => AnimatedPadding(
    padding: MediaQuery.viewInsetsOf(context),
    duration: MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 160),
    child: SafeArea(
      child: DesktopFormDialog(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: child,
        ),
      ),
    ),
  );
}

/// Preserves the compression dialog's IosCardPress button and theme tokens.
class ContextDialogActionButton extends StatelessWidget {
  const ContextDialogActionButton({
    super.key,
    required this.label,
    required this.onTap,
    this.primary = false,
    this.maxLines = 1,
  });
  final String label;
  final VoidCallback? onTap;
  final bool primary;
  final int? maxLines;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Opacity(
      opacity: onTap == null ? .45 : 1,
      child: IosCardPress(
        baseColor: primary ? cs.primary : Colors.transparent,
        border: primary
            ? null
            : Border.all(color: context.appColors.hairlineStrong),
        borderRadius: BorderRadius.circular(12),
        pressedScale: .98,
        haptics: false,
        focusable: true,
        onTap: onTap,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Center(
          child: Text(
            label,
            textAlign: TextAlign.center,
            maxLines: maxLines,
            overflow: maxLines == null
                ? TextOverflow.clip
                : TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 14,
              fontWeight: AppFontWeights.emphasis,
              color: primary ? cs.onPrimary : cs.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}

/// One consistent row for every action in the context-management sheet.
class ContextActionRow extends StatelessWidget {
  const ContextActionRow({
    super.key,
    required this.icon,
    required this.label,
    this.onTap,
    this.trailing,
    this.showChevron = false,
  });
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final Widget? trailing;
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return IosCardPress(
      baseColor: sheetTileColor(context),
      borderRadius: BorderRadius.circular(14),
      pressedScale: .98,
      duration: const Duration(milliseconds: 260),
      focusable: true,
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44),
        child: Row(
          children: [
            Icon(icon, size: 20, color: cs.onSurface),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: AppFontWeights.medium,
                  color: cs.onSurface,
                ),
              ),
            ),
            if (trailing != null) ...[const SizedBox(width: 12), trailing!],
            if (showChevron) ...[
              const SizedBox(width: 10),
              Icon(
                Lucide.ChevronRight,
                size: 17,
                color: cs.onSurface.withValues(alpha: .35),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class ContextStatusChip extends StatelessWidget {
  const ContextStatusChip({
    super.key,
    required this.label,
    this.icon,
    this.muted = false,
  });
  final String label;
  final IconData? icon;
  final bool muted;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = muted ? cs.onSurfaceVariant : cs.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: muted ? .06 : .12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: AppFontWeights.medium,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ContextDetailRow extends StatelessWidget {
  const ContextDetailRow({
    super.key,
    required this.label,
    required this.value,
    this.labelWidth = 84,
  });
  final String label;
  final String value;
  final double labelWidth;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 7),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: labelWidth,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              height: 1.4,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(value, style: const TextStyle(fontSize: 13, height: 1.4)),
        ),
      ],
    ),
  );
}

String contextTokenValue(int value) =>
    value >= 1000 ? '${(value / 1000).toStringAsFixed(1)}k' : value.toString();
