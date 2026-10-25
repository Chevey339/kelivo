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
    this.icon,
    this.leading,
    required this.label,
    this.subtitle,
    this.subtitleMaxLines = 1,
    this.detailColor,
    this.detail,
    this.selected = false,
    this.onTap,
    this.onLongPress,
    this.trailing,
  }) : assert(icon != null || leading != null);

  final IconData? icon;
  final Widget? leading;
  final String label;
  final String? subtitle;
  final int subtitleMaxLines;
  final Color? detailColor;
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
    final subtitleScale = hasSubtitle && subtitleMaxLines > 1
        ? MediaQuery.textScalerOf(context).scale(13) / 13
        : 1.0;
    return SizedBox(
      height:
          (hasSubtitle ? 56.0 : 48.0) * (subtitleScale > 1 ? subtitleScale : 1),
      child: IosCardPress(
        borderRadius: BorderRadius.circular(14),
        baseColor: sheetTileColor(context),
        duration: const Duration(milliseconds: 260),
        onTap: onTap,
        onLongPress: onLongPress,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            leading ?? Icon(icon, size: 20, color: onColor),
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
                          maxLines: subtitleMaxLines,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            height: subtitleMaxLines > 1 ? 1.2 : null,
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
                  color: detailColor ?? cs.onSurface.withValues(alpha: 0.6),
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
