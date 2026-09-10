import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/models/assistant.dart';
import '../../../core/models/conversation.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/services/api/builtin_tools.dart';
import '../../../core/services/chat/runtime_context.dart';
import '../../../icons/lucide_adapter.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/ios_switch.dart';
import '../../../shared/widgets/section_card.dart';
import '../../../theme/app_font_weights.dart';
import '../../home/utils/model_display_helper.dart';

/// Shared by assistant settings and the chat inspector. This preview only
/// reads configuration; it never runs message preparation or device tools.
class RuntimeContextSettingsCard extends StatelessWidget {
  const RuntimeContextSettingsCard({
    super.key,
    required this.assistant,
    required this.onChanged,
    this.conversation,
    this.now,
  });

  final Assistant assistant;
  final ValueChanged<Assistant> onChanged;
  final Conversation? conversation;
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final settings = context.watch<SettingsProvider>();
    final info = getModelDisplayInfo(
      settings,
      assistant: assistant,
      conversation: conversation,
    );
    final preview = RuntimeContextSnapshot.capture(
      assistant: assistant.copyWith(
        appendCurrentTimeToUserMessage: true,
        includeAppLocaleInContext: true,
        includeModelInfoInContext: true,
      ),
      now: now ?? DateTime.now(),
      appLocale: Localizations.localeOf(context).toLanguageTag(),
      modelName: info.modelDisplay ?? l10n.harnessNotConfigured,
      modelId: info.modelId == null
          ? l10n.harnessNotConfigured
          : BuiltInToolNames.effectiveModelId(
              cfg: info.getConfig(settings),
              modelId: info.modelId,
            ),
    );
    final timeConflict =
        assistant.appendCurrentTimeToUserMessage &&
        detectTimeVariablesInSystemPrompt(assistant.systemPrompt).isNotEmpty;
    return SectionCard(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.harnessBuiltInContext,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: AppFontWeights.emphasis,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  l10n.harnessAssistantScope,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          _ContextOption(
            id: 'time',
            title: l10n.harnessTime,
            description:
                '${l10n.harnessTimeDescription}\n${preview.formattedTime} · '
                '${preview.weekday} · ${preview.timezoneName}',
            value: assistant.appendCurrentTimeToUserMessage,
            onChanged: (value) => onChanged(
              assistant.copyWith(appendCurrentTimeToUserMessage: value),
            ),
          ),
          _ContextOption(
            id: 'locale',
            title: l10n.harnessLocale,
            description:
                '${l10n.harnessLocaleDescription}\n${preview.appLocale}',
            value: assistant.includeAppLocaleInContext,
            onChanged: (value) =>
                onChanged(assistant.copyWith(includeAppLocaleInContext: value)),
          ),
          _ContextOption(
            id: 'model',
            title: l10n.harnessModel,
            description:
                '${l10n.harnessModelDescription}\n${preview.modelName} · ${preview.modelId}',
            value: assistant.includeModelInfoInContext,
            onChanged: (value) =>
                onChanged(assistant.copyWith(includeModelInfoInContext: value)),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              l10n.harnessRequestOnly,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          if (timeConflict)
            Padding(
              key: const ValueKey('runtime-context-time-warning'),
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Lucide.BadgeInfo, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l10n.harnessTimeConflict,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ContextOption extends StatelessWidget {
  const _ContextOption({
    required this.id,
    required this.title,
    required this.description,
    required this.value,
    required this.onChanged,
  });
  final String id;
  final String title;
  final String description;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(12),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(fontWeight: AppFontWeights.semibold),
              ),
              const SizedBox(height: 4),
              Text(description, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Semantics(
          label: title,
          child: IosSwitch(
            key: ValueKey('runtime-context-$id'),
            value: value,
            onChanged: onChanged,
          ),
        ),
      ],
    ),
  );
}
