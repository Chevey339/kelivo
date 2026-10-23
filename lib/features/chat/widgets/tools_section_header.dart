import 'package:flutter/material.dart';

import '../../../icons/lucide_adapter.dart';
import '../../../l10n/app_localizations.dart';
import '../../../theme/app_font_weights.dart';
import '../../../theme/app_semantic_colors.dart';

/// Shared hierarchy for the mobile tools sheet and desktop popover.
class ToolsSectionHeader extends StatelessWidget {
  const ToolsSectionHeader({
    super.key,
    required this.title,
    required this.summary,
    required this.expanded,
    required this.onToggle,
    this.onManage,
    this.compact = false,
  });

  final String title;
  final String summary;
  final bool expanded;
  final VoidCallback onToggle;
  final VoidCallback? onManage;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(
          child: Semantics(
            expanded: expanded,
            child: InkWell(
              onTap: onToggle,
              borderRadius: BorderRadius.circular(8),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 44),
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: compact ? 13 : 14,
                          fontWeight: AppFontWeights.emphasis,
                          color: cs.onSurface,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: context.appColors.surfaceFill,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          summary,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: compact ? 11 : 12,
                            fontWeight: AppFontWeights.emphasis,
                            color: cs.onSurface.withValues(alpha: .62),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (onManage != null)
          TextButton(
            onPressed: onManage,
            style: TextButton.styleFrom(
              minimumSize: const Size(44, 44),
              padding: const EdgeInsets.symmetric(horizontal: 6),
              foregroundColor: cs.primary,
              textStyle: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(fontSize: compact ? 12 : 13),
            ),
            child: Text(AppLocalizations.of(context)!.toolsSheetManage),
          ),
        // The trailing disclosure is part of the same toggle action; omit it
        // from keyboard traversal and semantics to avoid a duplicate stop.
        ExcludeFocus(
          child: ExcludeSemantics(
            child: InkWell(
              onTap: onToggle,
              child: SizedBox(
                width: 24,
                height: 44,
                child: Icon(
                  expanded ? Lucide.ChevronDown : Lucide.ChevronRight,
                  size: compact ? 14 : 16,
                  color: cs.onSurface.withValues(alpha: .45),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
