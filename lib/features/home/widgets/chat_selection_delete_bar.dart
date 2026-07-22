import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../icons/lucide_adapter.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/ios_tactile.dart';
import '../../../theme/design_tokens.dart';
import 'package:Kelivo/theme/app_font_weights.dart';

class ChatSelectionDeleteBar extends StatelessWidget {
  const ChatSelectionDeleteBar({
    super.key,
    required this.hasMultiVersionSelection,
    required this.onDeleteCurrentVersions,
    required this.onDeleteAllVersions,
  });

  final bool hasMultiVersionSelection;
  final VoidCallback onDeleteCurrentVersions;
  final VoidCallback onDeleteAllVersions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context)!;

    final bg = isDark
        ? Colors.black.withValues(alpha: 0.35)
        : cs.surface.withValues(alpha: 0.78);
    final shadowColor = isDark
        ? Colors.black.withValues(alpha: 0.40)
        : Colors.black.withValues(alpha: 0.10);

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
        boxShadow: [
          BoxShadow(
            color: shadowColor,
            blurRadius: 22,
            offset: const Offset(0, -10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: ColoredBox(
            color: bg,
            child: SafeArea(
              top: false,
              left: false,
              right: false,
              bottom: true,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.sm,
                  AppSpacing.xs,
                  AppSpacing.sm,
                  AppSpacing.sm,
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final compact = constraints.maxWidth < 380;
                    if (!hasMultiVersionSelection) {
                      return SizedBox(
                        width: double.infinity,
                        child: _DeleteButton(
                          icon: Lucide.Trash2,
                          label: l10n.homePageDelete,
                          color: cs.error,
                          onTap: onDeleteCurrentVersions,
                          dense: compact,
                        ),
                      );
                    }

                    return Row(
                      children: [
                        Expanded(
                          child: _DeleteButton(
                            icon: Lucide.Trash2,
                            label: l10n.homePageDeleteMessage,
                            color: cs.error,
                            onTap: onDeleteCurrentVersions,
                            dense: compact,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _DeleteButton(
                            icon: Lucide.Trash,
                            label: l10n.homePageDeleteAllVersions,
                            color: cs.error,
                            onTap: onDeleteAllVersions,
                            dense: compact,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DeleteButton extends StatelessWidget {
  const _DeleteButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    required this.dense,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = Color.alphaBlend(
      (isDark ? Colors.white : Colors.black).withValues(alpha: 0.04),
      color.withValues(alpha: isDark ? 0.18 : 0.14),
    );

    return IosCardPress(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      baseColor: bg,
      pressedBlendStrength: isDark ? 0.20 : 0.16,
      pressedScale: 0.98,
      padding: dense
          ? const EdgeInsets.symmetric(horizontal: 8, vertical: 10)
          : const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: dense ? 16 : 18, color: color),
            SizedBox(width: dense ? 4 : 6),
            Text(
              label,
              style: TextStyle(
                fontSize: dense ? 13 : 14,
                fontWeight: AppFontWeights.medium,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
