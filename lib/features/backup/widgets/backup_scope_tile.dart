import 'package:flutter/material.dart';

import '../../../core/models/backup_scope.dart';
import '../../../icons/lucide_adapter.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/form_sheet.dart';
import '../../../shared/widgets/ios_switch.dart';
import '../../../shared/widgets/ios_tactile.dart';
import '../../../shared/widgets/ios_text_button.dart';
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
  static const _contentCategories = [
    BackupCategory.chats,
    BackupCategory.files,
  ];

  late BackupScope _scope = widget.scope;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
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
                IosTextButton(
                  key: const ValueKey('backup-scope-save'),
                  label: l10n.backupPageSave,
                  fontSize: 15,
                  onPressed: () => Navigator.of(context).pop(_scope),
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
                              IosTextButton(
                                label: l10n.sideDrawerSelectionSelectAll,
                                onPressed: () => setState(
                                  () => _scope = const BackupScope(),
                                ),
                              ),
                              IosTextButton(
                                label: l10n.sideDrawerSelectionDeselectAll,
                                onPressed: () => setState(
                                  () => _scope = BackupScope(
                                    excluded: BackupCategory.values.toSet(),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  _buildCategoryGroup(context, _contentCategories),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 8, 4, 16),
                    child: Text(
                      l10n.backupPageFilesDescription,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.45,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ),
                  _buildCategoryGroup(
                    context,
                    BackupCategory.values
                        .where(
                          (category) => !_contentCategories.contains(category),
                        )
                        .toList(),
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

  Widget _buildCategoryGroup(
    BuildContext context,
    List<BackupCategory> categories,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final showDividers = showSheetTileDividers(context);
    return SectionCard(
      radius: 14,
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (final category in categories) ...[
            if (showDividers && category != categories.first)
              Divider(
                height: 0.5,
                thickness: 0.5,
                indent: 50,
                endIndent: 14,
                color: cs.outlineVariant.withValues(alpha: 0.18),
              ),
            IosCardPress(
              baseColor: Colors.transparent,
              borderRadius: BorderRadius.zero,
              onTap: () => setState(
                () => _scope = _scope.withCategory(
                  category,
                  !_scope.includes(category),
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              child: Row(
                children: [
                  SizedBox(
                    width: 24,
                    child: Icon(
                      category.icon,
                      size: 20,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      category.label(l10n),
                      style: const TextStyle(fontSize: 15),
                    ),
                  ),
                  const SizedBox(width: 12),
                  IosSwitch(
                    key: ValueKey('backup-scope-${category.name}'),
                    semanticLabel: category.label(l10n),
                    value: _scope.includes(category),
                    onChanged: (value) => setState(
                      () => _scope = _scope.withCategory(category, value),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
