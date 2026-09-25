import 'package:flutter/material.dart';

import '../../../../core/models/model_spec.dart';
import '../../../../core/providers/settings_provider.dart';
import '../../../../core/services/api/builtin_tools.dart';
import '../../../../core/services/model_spec/model_spec_resolver.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/ios_settings_rows.dart';
import '../../../../shared/widgets/option_sheet.dart';
import '../../../../shared/widgets/ios_switch.dart';
import 'model_spec_form_controller.dart';
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
              subtitle: spec.reasoning.replayField.wireName,
              onTap: () => _pickReplayField(context),
            ),
            ..._requestQuirks(context, l10n, spec),
          ],
        );
      },
    );
  }

  /// Each flag only shows where the request path reads it.
  List<Widget> _requestQuirks(
    BuildContext context,
    AppLocalizations l10n,
    ModelSpec spec,
  ) {
    final cfg = controller.config;
    final isOpenAI =
        ProviderConfig.classify(cfg.id, explicitType: cfg.providerType) ==
        ProviderKind.openai;
    final rows = <Widget>[
      if (BuiltInToolsHelper.supportsClaudeDynamicWebSearchForModel(
        cfg: cfg,
        modelId: controller.modelKey,
      ))
        ..._quirk(
          context: context,
          field: ModelSpecField.dynamicWebSearch,
          label: l10n.modelSpecFormDynamicWebSearch,
          subtitle: l10n.modelSpecFormDynamicWebSearchSubtitle,
          value: spec.dynamicWebSearch,
          onChanged: controller.setDynamicWebSearch,
        ),
      if (isOpenAI && spec.supportsImageInput)
        ..._quirk(
          context: context,
          field: ModelSpecField.remoteImageUrls,
          label: l10n.modelSpecFormRemoteImageUrls,
          subtitle: l10n.modelSpecFormRemoteImageUrlsSubtitle,
          value: spec.remoteImageUrls,
          onChanged: controller.setRemoteImageUrls,
        ),
      if (isOpenAI && BuiltInToolsHelper.isOpenRouterProvider(cfg))
        ..._quirk(
          context: context,
          field: ModelSpecField.promptCacheControl,
          label: l10n.modelSpecFormPromptCacheControl,
          subtitle: l10n.modelSpecFormPromptCacheControlSubtitle,
          value: spec.promptCacheControl,
          onChanged: controller.setPromptCacheControl,
        ),
    ];
    return rows;
  }

  List<Widget> _quirk({
    required BuildContext context,
    required ModelSpecField field,
    required String label,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    final cs = Theme.of(context).colorScheme;
    return [
      const SizedBox(height: 8),
      SpecFieldHeader(
        label: label,
        source: controller.sourceOf(field),
        overridden: controller.isOverridden(field),
        onReset: () => controller.reset(field),
        trailing: IosSwitch(
          key: ValueKey('model-spec-${field.name}'),
          value: value,
          onChanged: onChanged,
          semanticLabel: label,
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
        child: Text(
          subtitle,
          style: TextStyle(
            fontSize: 12,
            color: cs.onSurface.withValues(alpha: 0.6),
          ),
        ),
      ),
    ];
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
        OptionSheetItem(
          value: ReasoningReplayField.reasoningContent,
          label: l10n.modelSpecFormReplayFieldReasoningContent,
        ),
        OptionSheetItem(
          value: ReasoningReplayField.reasoning,
          label: l10n.modelSpecFormReplayFieldReasoning,
        ),
        OptionSheetItem(
          value: ReasoningReplayField.reasoningDetails,
          label: l10n.modelSpecFormReplayFieldReasoningDetails,
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
