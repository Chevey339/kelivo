import 'dart:async';

import 'package:Kelivo/core/models/assistant.dart';
import 'package:Kelivo/core/models/skills_binding.dart';
import 'package:Kelivo/core/providers/assistant_provider.dart';
import 'package:Kelivo/core/services/chat/chat_service.dart';
import 'package:Kelivo/core/services/skills/skills_service.dart';
import 'package:Kelivo/features/settings/widgets/custom_theme_widgets.dart';
import 'package:Kelivo/features/workspace/widgets/skills/skill_labels.dart';
import 'package:Kelivo/icons/lucide_adapter.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/responsive/screen_type_helper.dart';
import 'package:Kelivo/shared/widgets/form_sheet.dart';
import 'package:Kelivo/shared/widgets/ios_settings_rows.dart';
import 'package:Kelivo/shared/widgets/section_card.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

Future<void> showConversationSkillsSheet(
  BuildContext context, {
  required String conversationId,
  required Assistant? assistant,
}) {
  final l10n = AppLocalizations.of(context)!;
  final panel = ConversationSkillsPanel(
    conversationId: conversationId,
    assistant: assistant,
  );
  if (ResponsiveHelper.isDesktop(context)) {
    return showAppDialog<void>(
      context,
      maxWidth: 480,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppDialogHeader(title: l10n.skillsSessionTitle),
          Flexible(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: panel,
              ),
            ),
          ),
        ],
      ),
    );
  }
  return showFormSheet<void>(
    context,
    builder: (ctx) =>
        FormSheet(title: l10n.skillsSessionTitle, children: [panel]),
  );
}

class ConversationSkillsPanel extends StatelessWidget {
  const ConversationSkillsPanel({
    super.key,
    required this.conversationId,
    required this.assistant,
  });

  final String conversationId;
  final Assistant? assistant;

  static const Key inheritKey = SkillsKeys.inherit;

  static Key skillKey(String id) => SkillsKeys.conversationSkill(id);

  SkillsBinding _binding(ChatService chat) {
    final extras = chat.getConversation(conversationId)?.extras ?? const {};
    return SkillsBinding.fromExtras(extras);
  }

  Future<void> _writeConversation(
    BuildContext context,
    List<String>? skillIds,
  ) {
    return context.read<ChatService>().updateConversationExtras(
      conversationId,
      (extras) => SkillsBinding(skillIds: skillIds).applyTo(extras),
    );
  }

  Future<void> _writeAssistant(BuildContext context, List<String> skillIds) {
    final id = assistant?.id;
    if (id == null) return Future<void>.value();
    final ap = context.read<AssistantProvider>();
    final current = ap.getById(id);
    if (current == null) return Future<void>.value();
    return ap.updateAssistant(current.copyWith(skillIds: skillIds));
  }

  Assistant? _liveAssistant(BuildContext context) {
    final id = assistant?.id;
    if (id == null) return assistant;
    return context.watch<AssistantProvider>().getById(id) ?? assistant;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final chat = context.watch<ChatService>();
    final skillsService = context.watch<SkillsService>();
    final live = _liveAssistant(context);
    final binding = _binding(chat);
    final inherit = binding.skillIds == null;
    final enabled = [
      for (final skill in skillsService.skills)
        if (skill.record.enabled) skill,
    ];
    final active = skillsService.resolveForAssistant(
      live,
      conversationOverride: binding.skillIds,
    );
    final activeIds = {for (final skill in active) skill.record.id};

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionCard(
          children: [
            IosSwitchRow(
              key: inheritKey,
              label: l10n.skillsInheritAssistant,
              value: inherit,
              onChanged: (value) {
                if (value) {
                  unawaited(_writeConversation(context, null));
                  return;
                }
                final snapshot = [
                  for (final skill in skillsService.resolveForAssistant(live))
                    skill.record.id,
                ];
                unawaited(_writeConversation(context, snapshot));
              },
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (enabled.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 24),
            child: Column(
              children: [
                Icon(
                  Lucide.Sparkles,
                  size: 36,
                  color: cs.onSurface.withValues(alpha: 0.26),
                ),
                const SizedBox(height: 12),
                Text(
                  l10n.skillsSessionEmpty,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.35,
                    color: cs.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          )
        else
          SectionCard(
            children: [
              for (var i = 0; i < enabled.length; i++) ...[
                if (i > 0) const IosRowDivider(),
                IosSwitchRow(
                  key: ConversationSkillsPanel.skillKey(enabled[i].record.id),
                  icon: Lucide.Sparkles,
                  label: enabled[i].name,
                  value: inherit
                      ? activeIds.contains(enabled[i].record.id)
                      : (binding.skillIds ?? const <String>[]).contains(
                          enabled[i].record.id,
                        ),
                  onChanged: (checked) {
                    final skillId = enabled[i].record.id;
                    if (inherit) {
                      final ids = {
                        for (final skill in skillsService.resolveForAssistant(
                          live,
                        ))
                          skill.record.id,
                      };
                      if (checked) {
                        ids.add(skillId);
                      } else {
                        ids.remove(skillId);
                      }
                      unawaited(_writeAssistant(context, ids.toList()));
                      return;
                    }
                    final ids = {...?binding.skillIds};
                    if (checked) {
                      ids.add(skillId);
                    } else {
                      ids.remove(skillId);
                    }
                    unawaited(_writeConversation(context, ids.toList()));
                  },
                ),
              ],
            ],
          ),
      ],
    );
  }
}
