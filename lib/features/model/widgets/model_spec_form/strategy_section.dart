import 'package:flutter/material.dart';

import '../../../../core/models/model_spec.dart';
import '../../../../core/services/model_spec/model_spec_resolver.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/ios_settings_rows.dart';
import '../../../../shared/widgets/option_sheet.dart';
import 'model_spec_form_controller.dart';
import 'reasoning_section.dart';
import 'spec_field_header.dart';

class StrategySection extends StatelessWidget {
  const StrategySection({super.key, required this.controller});

  final ModelSpecFormController controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final l10n = AppLocalizations.of(context)!;
        final spec = controller.spec;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SpecFieldHeader(
              label: l10n.modelSpecFormSampling,
              source: controller.sourceOf(ModelSpecField.sampling),
              overridden: controller.isOverridden(ModelSpecField.sampling),
              onReset: () => controller.reset(ModelSpecField.sampling),
            ),
            IosNavRow(
              label: _samplingLabel(l10n, spec.sampling),
              subtitle: _samplingSubtitle(l10n, spec.sampling),
              subtitleMaxLines: 2,
              onTap: () => _pickSampling(context),
            ),
            const SizedBox(height: 8),
            SpecFieldHeader(
              label: l10n.modelSpecFormReplay,
              source: controller.sourceOf(ModelSpecField.reasoningReplay),
              overridden: controller.isOverridden(
                ModelSpecField.reasoningReplay,
              ),
              onReset: () => controller.reset(ModelSpecField.reasoningReplay),
            ),
            IosNavRow(
              label: _replayLabel(l10n, spec.reasoning.replay),
              subtitle: _replaySubtitle(l10n, spec.reasoning.replay),
              subtitleMaxLines: 2,
              onTap: () => _pickReplay(context),
            ),
            IosNavRow(
              label: l10n.modelSpecFormReplayField,
              subtitle: _replayFieldSubtitle(l10n, spec.reasoning.replayField),
              onTap: () => _pickReplayField(context),
            ),
            if (spec.reasoning.replayField ==
                    ReasoningReplayField.mistralThinking &&
                spec.reasoning.dialect != ReasoningDialect.mistral)
              ReasoningFormWarning(
                key: const ValueKey('model-spec-mistral-replay-field-warning'),
                message: l10n.modelSpecFormMistralReplayFieldWarning,
              ),
          ],
        );
      },
    );
  }

  Future<void> _pickSampling(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final picked = await showOptionSheet<SamplingPolicy>(
      context,
      title: l10n.modelSpecFormSampling,
      selected: controller.spec.sampling,
      items: [
        for (final policy in SamplingPolicy.values)
          OptionSheetItem(
            value: policy,
            label: _samplingLabel(l10n, policy),
            subtitle: _samplingSubtitle(l10n, policy),
          ),
      ],
    );
    if (picked != null) controller.setSampling(picked);
  }

  Future<void> _pickReplay(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final picked = await showOptionSheet<ReasoningReplayPolicy>(
      context,
      title: l10n.modelSpecFormReplay,
      selected: controller.spec.reasoning.replay,
      items: [
        for (final policy in ReasoningReplayPolicy.values)
          OptionSheetItem(
            value: policy,
            label: _replayLabel(l10n, policy),
            subtitle: _replaySubtitle(l10n, policy),
          ),
      ],
    );
    if (picked != null) controller.setReplay(picked);
  }

  Future<void> _pickReplayField(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final picked = await showOptionSheet<ReasoningReplayField>(
      context,
      title: l10n.modelSpecFormReplayField,
      selected: controller.spec.reasoning.replayField,
      items: [
        for (final field in ReasoningReplayField.values)
          OptionSheetItem(
            value: field,
            label: _replayFieldLabel(l10n, field),
            subtitle: _replayFieldSubtitle(l10n, field),
          ),
      ],
    );
    if (picked != null) controller.setReplayField(picked);
  }
}

String _samplingLabel(AppLocalizations l10n, SamplingPolicy policy) {
  return switch (policy) {
    SamplingPolicy.always => l10n.modelSpecFormSamplingAlways,
    SamplingPolicy.onlyWhenReasoningOff =>
      l10n.modelSpecFormSamplingOnlyWhenReasoningOff,
    SamplingPolicy.never => l10n.modelSpecFormSamplingNever,
  };
}

String _samplingSubtitle(AppLocalizations l10n, SamplingPolicy policy) {
  return switch (policy) {
    SamplingPolicy.always => l10n.modelSpecFormSamplingAlwaysSubtitle,
    SamplingPolicy.onlyWhenReasoningOff =>
      l10n.modelSpecFormSamplingOnlyWhenReasoningOffSubtitle,
    SamplingPolicy.never => l10n.modelSpecFormSamplingNeverSubtitle,
  };
}

String _replayLabel(AppLocalizations l10n, ReasoningReplayPolicy policy) {
  return switch (policy) {
    ReasoningReplayPolicy.none => l10n.modelSpecFormReplayNone,
    ReasoningReplayPolicy.toolTurns => l10n.modelSpecFormReplayToolTurns,
    ReasoningReplayPolicy.all => l10n.modelSpecFormReplayAll,
  };
}

String _replaySubtitle(AppLocalizations l10n, ReasoningReplayPolicy policy) {
  return switch (policy) {
    ReasoningReplayPolicy.none => l10n.modelSpecFormReplayNoneSubtitle,
    ReasoningReplayPolicy.toolTurns =>
      l10n.modelSpecFormReplayToolTurnsSubtitle,
    ReasoningReplayPolicy.all => l10n.modelSpecFormReplayAllSubtitle,
  };
}

String _replayFieldLabel(AppLocalizations l10n, ReasoningReplayField field) {
  return switch (field) {
    ReasoningReplayField.reasoningContent =>
      l10n.modelSpecFormReplayFieldReasoningContent,
    ReasoningReplayField.reasoning => l10n.modelSpecFormReplayFieldReasoning,
    ReasoningReplayField.reasoningDetails =>
      l10n.modelSpecFormReplayFieldReasoningDetails,
    ReasoningReplayField.mistralThinking =>
      l10n.modelSpecFormReplayFieldMistralThinking,
  };
}

String _replayFieldSubtitle(AppLocalizations l10n, ReasoningReplayField field) {
  return switch (field) {
    ReasoningReplayField.reasoningContent ||
    ReasoningReplayField.reasoning ||
    ReasoningReplayField.reasoningDetails => field.wireName,
    ReasoningReplayField.mistralThinking =>
      l10n.modelSpecFormReplayFieldMistralThinkingSubtitle,
  };
}
