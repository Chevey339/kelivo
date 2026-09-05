import 'package:flutter/material.dart';

import 'package:Kelivo/theme/app_font_weights.dart';
import 'package:Kelivo/theme/app_semantic_colors.dart';

/// Compact, keyboard-focusable action for workspace toolbars and dialogs.
class DesktopWorkspaceButton extends StatelessWidget {
  const DesktopWorkspaceButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.primary = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return TextButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
      style:
          TextButton.styleFrom(
            splashFactory: NoSplash.splashFactory,
            foregroundColor: primary ? cs.onPrimary : cs.onSurface,
            backgroundColor: primary
                ? cs.primary
                : context.appColors.surfaceFill,
            disabledBackgroundColor: cs.onSurface.withValues(alpha: 0.05),
            minimumSize: const Size(0, 36),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
              fontSize: 13,
              fontWeight: AppFontWeights.medium,
            ),
          ).copyWith(
            overlayColor: WidgetStateProperty.resolveWith((states) {
              final ink = primary ? cs.onPrimary : cs.onSurface;
              if (states.contains(WidgetState.pressed)) {
                return ink.withValues(alpha: 0.10);
              }
              if (states.contains(WidgetState.focused)) {
                return ink.withValues(alpha: 0.08);
              }
              if (states.contains(WidgetState.hovered)) {
                return ink.withValues(alpha: 0.045);
              }
              return Colors.transparent;
            }),
          ),
    );
  }
}
