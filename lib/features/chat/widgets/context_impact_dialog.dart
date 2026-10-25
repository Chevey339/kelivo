import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/models/context_operation.dart';
import '../../../core/models/context_compression_task.dart';
import '../../../l10n/app_localizations.dart';
import '../../../theme/app_font_weights.dart';
import '../../../theme/app_semantic_colors.dart';
import 'context_dialog.dart';

enum ContextImpactKind { undo, clear, edit, source, deleteSource }

class ContextImpactDialog extends StatelessWidget {
  const ContextImpactDialog({
    super.key,
    required this.operations,
    required this.affectedIds,
    required this.kind,
    this.targetId,
    this.before,
    this.after,
    this.sourceLabel,
  });
  final List<ContextOperation> operations;
  final Set<String> affectedIds;
  final ContextImpactKind kind;
  final String? targetId;
  final CompressionBudget? before, after;
  final String? sourceLabel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final count =
        affectedIds.length -
        (kind == ContextImpactKind.edit && affectedIds.contains(targetId)
            ? 1
            : 0);
    final title = switch (kind) {
      ContextImpactKind.undo => l10n.contextImpactUndoTitle,
      ContextImpactKind.clear => l10n.contextImpactClearTitle,
      ContextImpactKind.edit => l10n.contextImpactEditTitle,
      ContextImpactKind.source => l10n.contextImpactSourceTitle,
      ContextImpactKind.deleteSource => l10n.contextImpactDeleteTitle,
    };
    return ContextDialog(
      maxWidth: 460,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                kind == ContextImpactKind.edit ||
                        kind == ContextImpactKind.source
                    ? LucideIcons.pencil
                    : kind == ContextImpactKind.deleteSource
                    ? LucideIcons.trash2
                    : LucideIcons.undo2,
                size: 20,
                color: cs.primary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: AppFontWeights.emphasis,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    kind == ContextImpactKind.source
                        ? l10n.contextImpactSourceDescription
                        : kind == ContextImpactKind.deleteSource
                        ? l10n.contextImpactDeleteDescription
                        : l10n.contextImpactDescription,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.4,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: context.appColors.surfaceFill,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      children: [
                        if (sourceLabel != null)
                          _row(
                            context,
                            kind == ContextImpactKind.deleteSource
                                ? LucideIcons.trash2
                                : LucideIcons.pencil,
                            sourceLabel!,
                            kind == ContextImpactKind.deleteSource
                                ? l10n.homePageDelete
                                : l10n.contextImpactSave,
                            kind == ContextImpactKind.deleteSource,
                          ),
                        for (
                          var index = 0;
                          index < operations.length;
                          index++
                        ) ...[
                          if (index > 0 || sourceLabel != null)
                            Divider(
                              height: 1,
                              color: context.appColors.hairline,
                            ),
                          _row(
                            context,
                            operations[index].isCompression
                                ? LucideIcons.package2
                                : LucideIcons.eraser,
                            '${operations[index].isCompression ? l10n.contextDividerCompressed : l10n.homePageClearContext} · '
                            '${MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(operations[index].createdAt.toLocal()))}',
                            kind == ContextImpactKind.edit &&
                                    operations[index].id == targetId
                                ? l10n.contextImpactSave
                                : affectedIds.contains(operations[index].id)
                                ? operations[index].id == targetId
                                      ? l10n.contextImpactUndoOne
                                      : l10n.contextImpactUndoAlso
                                : l10n.contextImpactKeep,
                            affectedIds.contains(operations[index].id) &&
                                !(kind == ContextImpactKind.edit &&
                                    operations[index].id == targetId),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    l10n.contextImpactUsage(
                      before == null
                          ? '—'
                          : contextTokenValue(before!.usedTokens),
                      after == null
                          ? '—'
                          : contextTokenValue(after!.usedTokens),
                    ),
                    style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                  ),
                  if (after?.contextWindow != null &&
                      after!.usedTokens > after!.contextWindow!)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        l10n.contextOverLimitWarning,
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.4,
                          color: context.appColors.warning,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: ContextDialogActionButton(
                  label: l10n.homePageCancel,
                  onTap: () => Navigator.of(context).pop(false),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ContextDialogActionButton(
                  label: kind == ContextImpactKind.edit
                      ? count == 0
                            ? l10n.messageEditPageSave
                            : l10n.contextImpactSaveConfirm(count)
                      : l10n.contextImpactConfirm(count),
                  primary: true,
                  onTap: () => Navigator.of(context).pop(true),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _row(
    BuildContext context,
    IconData icon,
    String title,
    String result,
    bool revoked,
  ) {
    final cs = Theme.of(context).colorScheme;
    final color = revoked ? cs.error : cs.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: color.withValues(alpha: .10),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 14, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(title, style: const TextStyle(fontSize: 13))),
          const SizedBox(width: 8),
          Text(
            result,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: revoked
                  ? AppFontWeights.semibold
                  : AppFontWeights.medium,
            ),
          ),
        ],
      ),
    );
  }
}
