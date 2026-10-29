import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../icons/lucide_adapter.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/ios_tactile.dart';
import '../../../shared/widgets/option_sheet.dart';
import '../../../theme/design_tokens.dart';
import 'package:Kelivo/theme/app_font_weights.dart';

class ChatSelectionActionBar extends StatelessWidget {
  const ChatSelectionActionBar({
    super.key,
    required this.hasSelection,
    required this.hasMultiVersionSelection,
    required this.onShare,
    required this.onDeleteCurrentVersions,
    required this.onDeleteAllVersions,
  });

  final bool hasSelection;
  final bool hasMultiVersionSelection;
  final VoidCallback onShare;
  final VoidCallback onDeleteCurrentVersions;
  final VoidCallback onDeleteAllVersions;

  Future<void> _delete(BuildContext context) async {
    if (!hasMultiVersionSelection) {
      onDeleteCurrentVersions();
      return;
    }
    final l10n = AppLocalizations.of(context)!;
    final allVersions = await showOptionSheet<bool>(
      context,
      title: l10n.homePageDelete,
      items: [
        OptionSheetItem(
          value: false,
          icon: Lucide.Trash2,
          label: l10n.homePageDeleteMessage,
        ),
        OptionSheetItem(
          value: true,
          icon: Lucide.Trash,
          label: l10n.homePageDeleteAllVersions,
        ),
      ],
    );
    if (!context.mounted || allVersions == null) return;
    if (allVersions) {
      onDeleteAllVersions();
    } else {
      onDeleteCurrentVersions();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context)!;

    final bg = cs.surface.withValues(alpha: isDark ? 0.35 : 0.78);
    final shadowColor = cs.shadow.withValues(alpha: isDark ? 0.40 : 0.10);

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
                    return Row(
                      children: [
                        Expanded(
                          child: _ActionButton(
                            icon: Lucide.Share,
                            label: l10n.messageMoreSheetShare,
                            color: cs.primary,
                            onTap: hasSelection ? onShare : null,
                            dense: compact,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _ActionButton(
                            icon: Lucide.Trash2,
                            label: l10n.homePageDelete,
                            color: cs.error,
                            onTap: hasSelection ? () => _delete(context) : null,
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

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    required this.dense,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;
    final bg = Color.alphaBlend(
      cs.onSurface.withValues(alpha: 0.04),
      color.withValues(alpha: isDark ? 0.18 : 0.14),
    );

    return Semantics(
      button: true,
      enabled: onTap != null,
      child: Opacity(
        opacity: onTap == null ? 0.45 : 1,
        child: IosCardPress(
          onTap: onTap,
          focusable: true,
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
        ),
      ),
    );
  }
}
