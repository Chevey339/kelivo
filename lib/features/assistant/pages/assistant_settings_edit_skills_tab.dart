import 'dart:async';

import 'package:Kelivo/core/providers/assistant_provider.dart';
import 'package:Kelivo/core/services/skills/skills_service.dart';
import 'package:Kelivo/features/workspace/pages/skills_page.dart';
import 'package:Kelivo/features/workspace/widgets/skills/skill_labels.dart';
import 'package:Kelivo/icons/lucide_adapter.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/widgets/ios_checkbox.dart';
import 'package:Kelivo/shared/widgets/ios_switch.dart';
import 'package:Kelivo/shared/widgets/ios_tactile.dart';
import 'package:Kelivo/shared/widgets/ios_tile_button.dart';
import 'package:Kelivo/shared/widgets/section_card.dart';
import 'package:Kelivo/theme/app_font_weights.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class AssistantSettingsEditSkillsTab extends StatelessWidget {
  const AssistantSettingsEditSkillsTab({super.key, required this.assistantId});

  final String assistantId;

  static const Key useAllKey = SkillsKeys.useAll;
  static const Key openPageKey = SkillsKeys.openPage;

  static Key skillKey(String id) => SkillsKeys.check(id);

  Future<void> _persist({
    required BuildContext context,
    required List<String>? skillIds,
  }) async {
    final ap = context.read<AssistantProvider>();
    final assistant = ap.getById(assistantId);
    if (assistant == null) return;
    if (skillIds == null) {
      await ap.updateAssistant(assistant.copyWith(clearSkillIds: true));
      return;
    }
    await ap.updateAssistant(assistant.copyWith(skillIds: skillIds));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final assistant = context.watch<AssistantProvider>().getById(assistantId);
    final skills = context.watch<SkillsService>().skills;
    if (assistant == null) return const SizedBox.shrink();

    final useAll = assistant.skillIds == null;
    final selected = {...?assistant.skillIds};

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      children: [
        SectionCard(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.skillsUseAll,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: AppFontWeights.semibold,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          l10n.skillsUseAllSubtitle,
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.25,
                            color: cs.onSurface.withValues(alpha: 0.62),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IosSwitch(
                    key: useAllKey,
                    value: useAll,
                    semanticLabel: l10n.skillsUseAll,
                    onChanged: (value) {
                      if (value) {
                        unawaited(_persist(context: context, skillIds: null));
                        return;
                      }
                      final enabledIds = [
                        for (final skill in skills)
                          if (skill.record.enabled) skill.record.id,
                      ];
                      unawaited(
                        _persist(context: context, skillIds: enabledIds),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (skills.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Text(
              l10n.skillsEmptyTitle,
              style: TextStyle(color: cs.onSurface.withValues(alpha: 0.6)),
            ),
          )
        else
          SectionCard(
            dividers: true,
            children: [
              for (final skill in skills)
                _AssistantSkillRow(
                  name: skill.name,
                  description: skill.description,
                  enabled: skill.record.enabled,
                  selected: useAll
                      ? skill.record.enabled
                      : selected.contains(skill.record.id),
                  disabledHint: l10n.skillsDisabledHint,
                  onChanged: useAll || !skill.record.enabled
                      ? null
                      : (checked) {
                          final next = {...selected};
                          if (checked) {
                            next.add(skill.record.id);
                          } else {
                            next.remove(skill.record.id);
                          }
                          unawaited(
                            _persist(context: context, skillIds: next.toList()),
                          );
                        },
                  rowKey: skillKey(skill.record.id),
                ),
            ],
          ),
        const SizedBox(height: 16),
        IosTileButton(
          key: openPageKey,
          icon: Lucide.Sparkles,
          label: l10n.skillsOpenPage,
          onTap: () => unawaited(openSkillsPage(context)),
        ),
      ],
    );
  }
}

class _AssistantSkillRow extends StatelessWidget {
  const _AssistantSkillRow({
    required this.name,
    required this.description,
    required this.enabled,
    required this.selected,
    required this.disabledHint,
    required this.onChanged,
    required this.rowKey,
  });

  final String name;
  final String description;
  final bool enabled;
  final bool selected;
  final String disabledHint;
  final ValueChanged<bool>? onChanged;
  final Key rowKey;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final dim = !enabled;
    return IosCardPress(
      key: rowKey,
      onTap: onChanged == null ? null : () => onChanged!(!selected),
      padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
      child: Row(
        children: [
          IosCheckbox(
            value: enabled && selected,
            onChanged: onChanged,
            semanticLabel: name,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: AppFontWeights.medium,
                    color: dim
                        ? cs.onSurface.withValues(alpha: 0.42)
                        : cs.onSurface,
                  ),
                ),
                if (description.trim().isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.25,
                      color: cs.onSurface.withValues(alpha: dim ? 0.38 : 0.62),
                    ),
                  ),
                ],
                if (dim) ...[
                  const SizedBox(height: 3),
                  Text(
                    disabledHint,
                    style: TextStyle(
                      fontSize: 12,
                      color: cs.onSurface.withValues(alpha: 0.45),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
