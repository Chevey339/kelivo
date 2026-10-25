import 'package:flutter/material.dart';

import '../../../shared/widgets/ios_tactile.dart';
import '../../../theme/app_font_weights.dart';
import '../../../theme/app_semantic_colors.dart';

/// The existing compression dialog surface, shared by context actions.
class ContextDialog extends StatelessWidget {
  const ContextDialog({super.key, required this.child, this.maxWidth = 420});
  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) => Dialog(
    insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
    backgroundColor: Colors.transparent,
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Material(
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
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
  });
  final String label;
  final VoidCallback? onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Opacity(
      opacity: onTap == null ? .45 : 1,
      child: IosCardPress(
        baseColor: primary ? cs.primary : context.appColors.surfaceFill,
        borderRadius: BorderRadius.circular(11),
        pressedScale: .98,
        haptics: false,
        onTap: onTap,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Center(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
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
