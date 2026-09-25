import 'package:flutter/material.dart';

import '../../../../core/models/model_spec.dart';
import '../../../../core/services/api/reasoning/reasoning_dialects.dart';
import '../../../../core/services/model_spec/model_spec_resolver.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/ios_checkbox.dart';
import '../../../../shared/widgets/ios_form_text_field.dart';
import '../../../../shared/widgets/ios_settings_rows.dart';
import '../../../../shared/widgets/ios_switch.dart';
import '../../../../shared/widgets/option_sheet.dart';
import 'model_spec_form_controller.dart';
import 'spec_field_header.dart';

class ReasoningSection extends StatelessWidget {
  const ReasoningSection({super.key, required this.controller});

  final ModelSpecFormController controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final l10n = AppLocalizations.of(context)!;
        final spec = controller.spec;
        final dialect = spec.reasoning.dialect;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SpecFieldHeader(
              label: l10n.modelSpecFormDialect,
              source: controller.sourceOf(ModelSpecField.reasoningDialect),
              overridden: controller.isOverridden(
                ModelSpecField.reasoningDialect,
              ),
              onReset: () => controller.reset(ModelSpecField.reasoningDialect),
            ),
            IosNavRow(
              label: dialectLabel(l10n, dialect),
              subtitle: dialectSubtitle(l10n, dialect),
              subtitleMaxLines: 2,
              onTap: () => _pickDialect(context),
            ),
            const SizedBox(height: 8),
            SpecFieldHeader(
              label: l10n.modelSpecFormLevels,
              source: controller.sourceOf(ModelSpecField.reasoningLevels),
              overridden: controller.isOverridden(
                ModelSpecField.reasoningLevels,
              ),
              onReset: () => controller.reset(ModelSpecField.reasoningLevels),
            ),
            for (final level in kModelSpecEditableLevels)
              _CheckRow(
                label: reasoningLevelLabel(l10n, level),
                value: spec.reasoning.levels.contains(level),
                onChanged: (_) => controller.toggleLevel(level),
              ),
            const SizedBox(height: 8),
            SpecFieldHeader(
              label: l10n.modelSpecFormCanDisable,
              source: controller.sourceOf(ModelSpecField.reasoningCanDisable),
              overridden: controller.isOverridden(
                ModelSpecField.reasoningCanDisable,
              ),
              onReset: () =>
                  controller.reset(ModelSpecField.reasoningCanDisable),
              trailing: IosSwitch(
                key: const ValueKey('model-spec-can-disable'),
                value: spec.reasoning.canDisable,
                onChanged: controller.setCanDisable,
                semanticLabel: l10n.modelSpecFormCanDisable,
              ),
            ),
            const SizedBox(height: 8),
            SpecFieldHeader(
              label: l10n.modelSpecFormDefaultLevel,
              source: controller.sourceOf(ModelSpecField.reasoningDefaultLevel),
              overridden: controller.isOverridden(
                ModelSpecField.reasoningDefaultLevel,
              ),
              onReset: () =>
                  controller.reset(ModelSpecField.reasoningDefaultLevel),
            ),
            IosNavRow(
              label: reasoningLevelLabel(l10n, spec.reasoning.defaultLevel),
              onTap: () => _pickDefaultLevel(context),
            ),
            if (isBudgetDialect(dialect)) ...[
              const SizedBox(height: 8),
              SpecFieldHeader(
                label: l10n.modelSpecFormBudgets,
                source: controller.sourceOf(ModelSpecField.reasoningBudgets),
                overridden: controller.isOverridden(
                  ModelSpecField.reasoningBudgets,
                ),
                onReset: () =>
                    controller.reset(ModelSpecField.reasoningBudgets),
              ),
              for (final level in spec.reasoning.levels)
                IosFormTextField(
                  key: ValueKey('model-spec-budget-${level.name}'),
                  label: reasoningLevelLabel(l10n, level),
                  controller: controller.budgetControllers[level]!,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.right,
                  fieldWidth: 120,
                  hintText: l10n.modelSpecFormBudgetPlaceholder(
                    '${resolveBudget(spec, level) ?? ''}',
                  ),
                  onChanged: (raw) {
                    final trimmed = raw.trim();
                    if (trimmed.isEmpty) {
                      controller.setBudget(level, null);
                      return;
                    }
                    final value = int.tryParse(trimmed);
                    if (value != null) controller.setBudget(level, value);
                  },
                ),
            ],
            if (dialect == ReasoningDialect.custom)
              for (final level in spec.reasoning.levels) ...[
                IosFormTextField(
                  label: l10n.modelSpecFormCustomPatch(
                    reasoningLevelLabel(l10n, level),
                  ),
                  controller: controller.customPatchControllers[level]!,
                  hintText: l10n.modelSpecFormCustomPatchHint,
                  maxLines: 6,
                  minLines: 3,
                  inlineLabel: false,
                  keyboardType: TextInputType.multiline,
                  onChanged: (text) =>
                      controller.setCustomPatchText(level, text),
                ),
                if (controller.customPatchError(level) != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                    child: Text(
                      l10n.modelSpecFormInvalidJson,
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
              ],
          ],
        );
      },
    );
  }

  Future<void> _pickDialect(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final picked = await showOptionSheet<ReasoningDialect>(
      context,
      title: l10n.modelSpecFormDialect,
      selected: controller.spec.reasoning.dialect,
      items: [
        for (final dialect in ReasoningDialect.values)
          OptionSheetItem(
            value: dialect,
            label: dialectLabel(l10n, dialect),
            subtitle: dialectSubtitle(l10n, dialect),
          ),
      ],
    );
    if (picked != null) controller.setDialect(picked);
  }

  Future<void> _pickDefaultLevel(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final spec = controller.spec;
    final options = <ReasoningLevel>[
      ReasoningLevel.auto,
      if (spec.reasoning.canDisable) ReasoningLevel.off,
      ...spec.reasoning.levels,
    ];
    final picked = await showOptionSheet<ReasoningLevel>(
      context,
      title: l10n.modelSpecFormDefaultLevel,
      selected: spec.reasoning.defaultLevel,
      items: [
        for (final level in options)
          OptionSheetItem(
            value: level,
            label: reasoningLevelLabel(l10n, level),
          ),
      ],
    );
    if (picked != null) controller.setDefaultLevel(picked);
  }
}

class _CheckRow extends StatelessWidget {
  const _CheckRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: () => onChanged(!value),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          children: [
            IosCheckbox(
              value: value,
              onChanged: onChanged,
              semanticLabel: label,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  color: cs.onSurface.withValues(alpha: 0.9),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String reasoningLevelLabel(AppLocalizations l10n, ReasoningLevel level) {
  return switch (level) {
    ReasoningLevel.auto => l10n.reasoningLevelAuto,
    ReasoningLevel.off => l10n.reasoningLevelOff,
    ReasoningLevel.minimal => l10n.reasoningLevelMinimal,
    ReasoningLevel.low => l10n.reasoningLevelLow,
    ReasoningLevel.medium => l10n.reasoningLevelMedium,
    ReasoningLevel.high => l10n.reasoningLevelHigh,
    ReasoningLevel.xhigh => l10n.reasoningLevelXhigh,
    ReasoningLevel.max => l10n.reasoningLevelMax,
  };
}

String dialectLabel(AppLocalizations l10n, ReasoningDialect dialect) {
  return switch (dialect) {
    ReasoningDialect.none => l10n.modelSpecFormDialectNone,
    ReasoningDialect.openaiReasoningEffort =>
      l10n.modelSpecFormDialectOpenaiReasoningEffort,
    ReasoningDialect.openaiResponsesReasoning =>
      l10n.modelSpecFormDialectOpenaiResponsesReasoning,
    ReasoningDialect.openrouterReasoning =>
      l10n.modelSpecFormDialectOpenrouterReasoning,
    ReasoningDialect.anthropicBudget =>
      l10n.modelSpecFormDialectAnthropicBudget,
    ReasoningDialect.anthropicAdaptiveEffort =>
      l10n.modelSpecFormDialectAnthropicAdaptiveEffort,
    ReasoningDialect.anthropicEffort =>
      l10n.modelSpecFormDialectAnthropicEffort,
    ReasoningDialect.geminiThinkingBudget =>
      l10n.modelSpecFormDialectGeminiThinkingBudget,
    ReasoningDialect.geminiThinkingLevel =>
      l10n.modelSpecFormDialectGeminiThinkingLevel,
    ReasoningDialect.qwenEnableThinking =>
      l10n.modelSpecFormDialectQwenEnableThinking,
    ReasoningDialect.thinkingType => l10n.modelSpecFormDialectThinkingType,
    ReasoningDialect.siliconflowEnableThinking =>
      l10n.modelSpecFormDialectSiliconflowEnableThinking,
    ReasoningDialect.internThinkingMode =>
      l10n.modelSpecFormDialectInternThinkingMode,
    ReasoningDialect.chatTemplateKwargs =>
      l10n.modelSpecFormDialectChatTemplateKwargs,
    ReasoningDialect.kimiThinking => l10n.modelSpecFormDialectKimiThinking,
    ReasoningDialect.custom => l10n.modelSpecFormDialectCustom,
  };
}

String dialectSubtitle(AppLocalizations l10n, ReasoningDialect dialect) {
  return switch (dialect) {
    ReasoningDialect.none => l10n.modelSpecFormDialectNoneSubtitle,
    ReasoningDialect.openaiReasoningEffort =>
      l10n.modelSpecFormDialectOpenaiReasoningEffortSubtitle,
    ReasoningDialect.openaiResponsesReasoning =>
      l10n.modelSpecFormDialectOpenaiResponsesReasoningSubtitle,
    ReasoningDialect.openrouterReasoning =>
      l10n.modelSpecFormDialectOpenrouterReasoningSubtitle,
    ReasoningDialect.anthropicBudget =>
      l10n.modelSpecFormDialectAnthropicBudgetSubtitle,
    ReasoningDialect.anthropicAdaptiveEffort =>
      l10n.modelSpecFormDialectAnthropicAdaptiveEffortSubtitle,
    ReasoningDialect.anthropicEffort =>
      l10n.modelSpecFormDialectAnthropicEffortSubtitle,
    ReasoningDialect.geminiThinkingBudget =>
      l10n.modelSpecFormDialectGeminiThinkingBudgetSubtitle,
    ReasoningDialect.geminiThinkingLevel =>
      l10n.modelSpecFormDialectGeminiThinkingLevelSubtitle,
    ReasoningDialect.qwenEnableThinking =>
      l10n.modelSpecFormDialectQwenEnableThinkingSubtitle,
    ReasoningDialect.thinkingType =>
      l10n.modelSpecFormDialectThinkingTypeSubtitle,
    ReasoningDialect.siliconflowEnableThinking =>
      l10n.modelSpecFormDialectSiliconflowEnableThinkingSubtitle,
    ReasoningDialect.internThinkingMode =>
      l10n.modelSpecFormDialectInternThinkingModeSubtitle,
    ReasoningDialect.chatTemplateKwargs =>
      l10n.modelSpecFormDialectChatTemplateKwargsSubtitle,
    ReasoningDialect.kimiThinking =>
      l10n.modelSpecFormDialectKimiThinkingSubtitle,
    ReasoningDialect.custom => l10n.modelSpecFormDialectCustomSubtitle,
  };
}
