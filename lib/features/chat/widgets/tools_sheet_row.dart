import 'package:flutter/material.dart';

import 'package:Kelivo/icons/lucide_adapter.dart';
import 'package:Kelivo/shared/widgets/ios_tactile.dart';
import 'package:Kelivo/shared/widgets/section_card.dart';
import 'package:Kelivo/theme/app_font_weights.dart';

/// Single tile used by the chat ＋ tools sheet (`BottomToolsSheet` and
/// `WorkspaceSection`).
///
/// Anatomy matches `_LearningAndClearSection._row`: 48px
/// (`IosCardPress`, radius 14, [sheetTileColor], pad h12), bare 20px
/// icon, 10px gap, 15/medium label, optional custom [trailing] or a
/// 18px chevron at α0.55. Two-line tiles grow to 56px.
class ToolsSheetRow extends StatelessWidget {
  const ToolsSheetRow({
    super.key,
    required this.icon,
    required this.label,
    this.subtitle,
    this.detail,
    this.selected = false,
    this.onTap,
    this.onLongPress,
    this.trailing,
  });

  final IconData icon;
  final String label;
  final String? subtitle;
  final String? detail;
  final bool selected;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Widget? trailing;

  static Widget chevron(BuildContext context) {
    return Icon(
      Lucide.ChevronRight,
      size: 18,
      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final onColor = selected ? cs.primary : cs.onSurface;
    final hasSubtitle = subtitle != null && subtitle!.isNotEmpty;
    return SizedBox(
      height: hasSubtitle ? 56 : 48,
      child: IosCardPress(
        borderRadius: BorderRadius.circular(14),
        baseColor: sheetTileColor(context),
        duration: const Duration(milliseconds: 260),
        onTap: onTap,
        onLongPress: onLongPress,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            Icon(icon, size: 20, color: onColor),
            const SizedBox(width: 10),
            Expanded(
              child: hasSubtitle
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: AppFontWeights.medium,
                            color: onColor,
                          ),
                        ),
                        Text(
                          subtitle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            color: cs.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    )
                  : Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: AppFontWeights.medium,
                        color: onColor,
                      ),
                    ),
            ),
            if (detail != null && detail!.isNotEmpty) ...[
              Text(
                detail!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  color: cs.onSurface.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(width: 6),
            ],
            trailing ??
                (selected
                    ? Icon(Lucide.Check, size: 18, color: cs.primary)
                    : const SizedBox(width: 18)),
          ],
        ),
      ),
    );
  }
}
