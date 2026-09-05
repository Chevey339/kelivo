import 'dart:async';

import 'package:Kelivo/core/models/assistant.dart';
import 'package:Kelivo/core/models/skills_binding.dart';
import 'package:Kelivo/core/providers/assistant_provider.dart';
import 'package:Kelivo/core/services/chat/chat_service.dart';
import 'package:Kelivo/core/services/haptics.dart';
import 'package:Kelivo/core/services/skills/skills_service.dart';
import 'package:Kelivo/features/settings/widgets/custom_theme_widgets.dart';
import 'package:Kelivo/features/workspace/widgets/skills/skill_detail.dart';
import 'package:Kelivo/features/workspace/widgets/skills/skill_labels.dart';
import 'package:Kelivo/icons/lucide_adapter.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/features/workspace/workspace_layout.dart';
import 'package:Kelivo/shared/widgets/form_sheet.dart';
import 'package:Kelivo/shared/widgets/ios_settings_rows.dart';
import 'package:Kelivo/shared/widgets/ios_checkbox.dart';
import 'package:Kelivo/shared/widgets/ios_tactile.dart';
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
  if (useDesktopWorkspaceLayout(context)) {
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
    this.compact = false,
    this.footerAction,
  });

  final String conversationId;
  final Assistant? assistant;
  final bool compact;
  final Widget? footerAction;

  Widget _group({required List<Widget> children}) => compact
      ? Column(mainAxisSize: MainAxisSize.min, children: children)
      : SectionCard(children: children);

  Widget _switchRow({
    required Key key,
    IconData? icon,
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
    VoidCallback? onLongPress,
  }) {
    if (!compact) {
      return IosSwitchRow(
        key: key,
        icon: icon,
        label: label,
        value: value,
        onChanged: onChanged,
        onLongPress: onLongPress,
      );
    }
    return Builder(
      key: key,
      builder: (context) {
        final cs = Theme.of(context).colorScheme;
        final color = value ? cs.primary : cs.onSurface;
        return Semantics(
          toggled: value,
          child: IosCardPress(
            baseColor: Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            padding: const EdgeInsets.symmetric(horizontal: 8),
            haptics: false,
            onTap: () => onChanged(!value),
            onLongPress: onLongPress,
            child: SizedBox(
              height: 40,
              child: Row(
                children: [
                  SizedBox(
                    width: 22,
                    child: icon == null
                        ? null
                        : Icon(icon, size: 16, color: color),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 13, color: color),
                    ),
                  ),
                  SizedBox(
                    width: 16,
                    child: value
                        ? Icon(Lucide.Check, size: 16, color: cs.primary)
                        : null,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

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

  Future<void> _writeGlobal(BuildContext context, String id, bool enabled) {
    return context.read<SkillsService>().setEnabled(id, enabled);
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
    final followGlobal = inherit && live?.skillIds == null;
    final listed = followGlobal
        ? skillsService.skills
        : [
            for (final skill in skillsService.skills)
              if (skill.record.enabled) skill,
          ];
    final active = skillsService.resolveForAssistant(
      live,
      conversationOverride: binding.skillIds,
    );
    final activeIds = {for (final skill in active) skill.record.id};

    void setInherit(bool value) {
      if (value) {
        unawaited(_writeConversation(context, null));
        return;
      }
      final snapshot = [
        for (final skill in skillsService.resolveForAssistant(live))
          skill.record.id,
      ];
      unawaited(_writeConversation(context, snapshot));
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!compact) ...[
          _group(
            children: [
              _switchRow(
                key: inheritKey,
                label: l10n.skillsInheritAssistant,
                value: inherit,
                onChanged: setInherit,
              ),
            ],
          ),
          const SizedBox(height: 12),
        ],
        if (listed.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 24),
            child: Column(
              children: [
                Icon(
                  Lucide.WandSparkles,
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
          _group(
            children: [
              for (var i = 0; i < listed.length; i++) ...[
                if (i > 0 && !compact) const IosRowDivider(),
                _switchRow(
                  key: ConversationSkillsPanel.skillKey(listed[i].record.id),
                  icon: Lucide.WandSparkles,
                  label: listed[i].name,
                  value: followGlobal
                      ? listed[i].record.enabled
                      : inherit
                      ? activeIds.contains(listed[i].record.id)
                      : (binding.skillIds ?? const <String>[]).contains(
                          listed[i].record.id,
                        ),
                  onLongPress: () {
                    Haptics.light();
                    unawaited(
                      showSkillDetail(context, skillId: listed[i].record.id),
                    );
                  },
                  onChanged: (checked) {
                    final skillId = listed[i].record.id;
                    if (followGlobal) {
                      unawaited(_writeGlobal(context, skillId, checked));
                      return;
                    }
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
        if (compact) ...[
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: IosCardPress(
                  key: inheritKey,
                  baseColor: Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 8,
                  ),
                  haptics: false,
                  onTap: () => setInherit(!inherit),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IosCheckbox(
                        value: inherit,
                        onChanged: setInherit,
                        size: 16,
                        hitTestSize: 20,
                        borderWidth: 1.5,
                        activeColor: cs.primary,
                        enableHaptics: false,
                        semanticLabel: l10n.skillsInheritAssistant,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          l10n.skillsInheritAssistant,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12, color: cs.onSurface),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (footerAction != null) ...[
                const SizedBox(width: 8),
                footerAction!,
              ],
            ],
          ),
        ],
      ],
    );
  }
}
