import 'package:flutter/material.dart';

import '../../../core/models/world_book.dart';
import '../../../icons/lucide_adapter.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/ios_checkbox.dart';
import '../../../shared/widgets/ios_tactile.dart';
import '../../../theme/app_font_weights.dart';

typedef WorldBookSelection = ({bool checked, VoidCallback onToggle});

class WorldBookCardHeader extends StatelessWidget {
  const WorldBookCardHeader({
    super.key,
    required this.book,
    required this.collapsed,
    required this.onToggle,
    required this.onAddEntry,
    required this.onExport,
    required this.onEdit,
    required this.onDelete,
    this.onSelectEntries,
    this.selection,
    this.wrapTitle,
  });

  final WorldBook book;
  final bool collapsed;
  final VoidCallback onToggle;
  final VoidCallback onAddEntry;
  final VoidCallback onExport;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback? onSelectEntries;
  final WorldBookSelection? selection;
  final Widget Function(Widget)? wrapTitle;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final selected = selection;
    final title = book.name.trim();
    final description = book.description.trim();
    final titleRow = IosCardPress(
      baseColor: Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      pressedScale: 1,
      haptics: false,
      focusable: true,
      onTap: selected?.onToggle ?? onToggle,
      padding: const EdgeInsetsDirectional.fromSTEB(2, 6, 4, 6),
      child: Row(
        children: [
          if (selected == null)
            AnimatedRotation(
              turns: collapsed ? 0 : .25,
              duration: const Duration(milliseconds: 200),
              child: Icon(
                Lucide.ChevronRight,
                size: 16,
                color: colors.onSurfaceVariant,
              ),
            )
          else
            const SizedBox(width: 16),
          const SizedBox(width: 6),
          Icon(
            book.enabled ? Lucide.BookOpen : Lucide.Ban,
            size: 18,
            color: book.enabled ? colors.primary : colors.error,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title.isEmpty ? l10n.worldBookUnnamed : title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: AppFontWeights.emphasis,
                  ),
                ),
                if (!book.enabled || description.isNotEmpty)
                  Text.rich(
                    TextSpan(
                      children: [
                        if (!book.enabled)
                          TextSpan(
                            text: l10n.worldBookDisabledTag,
                            style: TextStyle(color: colors.error),
                          ),
                        if (description.isNotEmpty)
                          TextSpan(
                            text: book.enabled
                                ? description
                                : ' · $description',
                          ),
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );

    final heading = <Widget>[
      Expanded(child: wrapTitle?.call(titleRow) ?? titleRow),
      const SizedBox(width: 6),
      Text(
        '${book.enabledEntryCount}/${book.entries.length}',
        style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
      ),
      const SizedBox(width: 4),
    ];
    final actions = <Widget>[
      if (selected != null)
        IosCheckbox(
          key: ValueKey('world-book-select-${book.id}'),
          value: selected.checked,
          onChanged: (_) => selected.onToggle(),
          semanticLabel: title.isEmpty ? l10n.worldBookUnnamed : title,
        )
      else ...[
        if (onSelectEntries != null)
          IosIconButton(
            icon: Lucide.ListChecks,
            tooltip: l10n.worldBookSelectEntries,
            minSize: 32,
            size: 17,
            onTap: onSelectEntries,
          )
        else
          const SizedBox(width: 32),
        IosIconButton(
          icon: Lucide.Plus,
          tooltip: l10n.worldBookAddEntry,
          minSize: 32,
          size: 17,
          onTap: onAddEntry,
        ),
        IosIconButton(
          icon: Lucide.Share2,
          tooltip: l10n.worldBookExport,
          minSize: 32,
          size: 17,
          onTap: onExport,
        ),
        IosIconButton(
          icon: Lucide.Settings2,
          tooltip: l10n.worldBookConfig,
          minSize: 32,
          size: 17,
          onTap: onEdit,
        ),
        IosIconButton(
          icon: Lucide.Trash2,
          tooltip: l10n.worldBookDelete,
          minSize: 32,
          size: 17,
          onTap: onDelete,
        ),
      ],
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final countSize = MediaQuery.textScalerOf(context).scale(12);
        final stackActions =
            selected == null &&
            constraints.maxWidth < 300 + (countSize - 12).clamp(0, 36);
        if (!stackActions) return Row(children: [...heading, ...actions]);
        return Column(
          children: [
            Row(children: heading),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: Wrap(children: actions),
            ),
          ],
        );
      },
    );
  }
}
