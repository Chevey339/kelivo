import 'package:flutter/material.dart';

import '../../../core/models/backup_scope.dart';
import '../../../icons/lucide_adapter.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/form_sheet.dart';
import '../../../shared/widgets/ios_switch.dart';
import '../../../shared/widgets/ios_tactile.dart';
import '../../../shared/widgets/section_card.dart';
import '../../../theme/app_font_weights.dart';
import '../../../theme/app_semantic_colors.dart';
import 'backup_category_labels.dart';

class BackupScopeTile extends StatelessWidget {
  const BackupScopeTile({
    super.key,
    required this.scope,
    required this.onChanged,
    this.desktop = false,
  });

  final BackupScope scope;
  final Future<void> Function(BackupScope)? onChanged;
  final bool desktop;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    return IosCardPress(
      key: const ValueKey('backup-scope-picker'),
      onTap: onChanged == null
          ? null
          : () async {
              final selected = desktop
                  ? await showDialog<BackupScope>(
                      context: context,
                      builder: (_) =>
                          _BackupScopeEditor(scope: scope, desktop: true),
                    )
                  : await showFormSheet<BackupScope>(
                      context,
                      builder: (_) => _BackupScopeEditor(scope: scope),
                    );
              if (selected != null && context.mounted) {
                await onChanged!(selected);
              }
            },
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 26),
        child: Row(
          children: [
            SizedBox(
              width: 36,
              child: Icon(
                Lucide.SlidersHorizontal,
                size: 20,
                color: cs.onSurface.withValues(alpha: 0.9),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                l10n.backupPageScopeTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 15,
                  color: cs.onSurface.withValues(alpha: 0.9),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              l10n.backupPageScopeSelectedCount(
                BackupCategory.values.where(scope.includes).length,
                BackupCategory.values.length,
              ),
              style: TextStyle(
                fontSize: 13,
                color: cs.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(width: 6),
            Icon(Lucide.ChevronRight, size: 16, color: cs.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

class _BackupScopeEditor extends StatefulWidget {
  const _BackupScopeEditor({required this.scope, this.desktop = false});

  final BackupScope scope;
  final bool desktop;

  @override
  State<_BackupScopeEditor> createState() => _BackupScopeEditorState();
}

class _BackupScopeEditorState extends State<_BackupScopeEditor> {
  late BackupScope _scope = widget.scope;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final showDividers = showSheetTileDividers(context);
    final body = SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!widget.desktop)
            Padding(
              padding: const EdgeInsets.only(top: 10, bottom: 4),
              child: Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: cs.onSurface.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 8, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.backupPageScopeTitle,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: AppFontWeights.semibold,
                    ),
                  ),
                ),
                TextButton(
                  key: const ValueKey('backup-scope-save'),
                  onPressed: () => Navigator.of(context).pop(_scope),
                  style: TextButton.styleFrom(
                    minimumSize: const Size(56, 44),
                    textStyle: TextStyle(
                      fontSize: 15,
                      fontWeight: AppFontWeights.semibold,
                    ),
                  ),
                  child: Text(l10n.backupPageSave),
                ),
                IosIconButton(
                  key: const ValueKey('backup-scope-cancel'),
                  builder: (color) => Icon(Lucide.X, size: 18, color: color),
                  minSize: 44,
                  color: cs.onSurfaceVariant,
                  semanticLabel: l10n.backupPageCancel,
                  onTap: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      l10n.backupPageBackupManagementDescription,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.45,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 6, bottom: 4, left: 4),
                    child: Row(
                      children: [
                        Text(
                          l10n.backupPageScopeSelectedCount(
                            BackupCategory.values.where(_scope.includes).length,
                            BackupCategory.values.length,
                          ),
                          style: TextStyle(
                            fontSize: 13,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Wrap(
                            alignment: WrapAlignment.end,
                            children: [
                              TextButton(
                                onPressed: () => setState(
                                  () => _scope = const BackupScope(),
                                ),
                                child: Text(l10n.sideDrawerSelectionSelectAll),
                              ),
                              TextButton(
                                onPressed: () => setState(
                                  () => _scope = BackupScope(
                                    excluded: BackupCategory.values.toSet(),
                                  ),
                                ),
                                child: Text(
                                  l10n.sideDrawerSelectionDeselectAll,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: sheetTileColor(context),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: [
                        for (final category in BackupCategory.values) ...[
                          if (showDividers &&
                              category != BackupCategory.values.first)
                            Divider(
                              height: 0.5,
                              thickness: 0.5,
                              indent: 46,
                              endIndent: 12,
                              color: cs.outlineVariant.withValues(alpha: 0.18),
                            ),
                          IosCardPress(
                            onTap: () => setState(
                              () => _scope = _scope.withCategory(
                                category,
                                !_scope.includes(category),
                              ),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 2,
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  category.icon,
                                  size: 20,
                                  color: cs.onSurfaceVariant,
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Text(
                                    category.label(l10n),
                                    style: const TextStyle(fontSize: 15),
                                  ),
                                ),
                                IosSwitch(
                                  key: ValueKey(
                                    'backup-scope-${category.name}',
                                  ),
                                  semanticLabel: category.label(l10n),
                                  value: _scope.includes(category),
                                  onChanged: (value) => setState(
                                    () => _scope = _scope.withCategory(
                                      category,
                                      value,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
    if (!widget.desktop) {
      return body;
    }
    return Dialog(
      backgroundColor: context.overlaySurface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 480,
          maxHeight: MediaQuery.sizeOf(context).height * 0.85,
        ),
        child: body,
      ),
    );
  }
}
