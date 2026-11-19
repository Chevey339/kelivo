import 'package:flutter/material.dart';

import '../../../../core/models/model_spec.dart';
import '../../../../core/providers/settings_provider.dart';
import '../../../../core/services/api/builtin_tools.dart';
import '../../../../core/services/api/response_speed.dart';
import '../../../../core/services/model_spec/model_spec_resolver.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/ios_checkbox.dart';
import '../../../../shared/widgets/ios_settings_rows.dart';
import '../../../../shared/widgets/ios_switch.dart';
import 'model_spec_form_controller.dart';
import 'spec_field_header.dart';

/// Per-model request quirks. Independent of reasoning support, so it lives
/// with the other request-shaping settings.
class RequestQuirksSection extends StatelessWidget {
  const RequestQuirksSection({super.key, required this.controller});

  final ModelSpecFormController controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final l10n = AppLocalizations.of(context)!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: _requestQuirks(context, l10n, controller.spec),
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
    final kind = ProviderConfig.classify(
      cfg.id,
      explicitType: cfg.providerType,
    );
    final isOpenAI = kind == ProviderKind.openai;
    final rows = <Widget>[
      // Judged on the draft: a new model has no key until it is saved.
      if (spec.type == ModelType.chat &&
          kind == ProviderKind.claude &&
          BuiltInToolsHelper.isOfficialAnthropicEndpoint(cfg))
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
      if (ResponseSpeedCapabilities.allowsManualTiers(cfg, spec))
        ..._responseSpeedTiers(context, l10n, spec),
    ];
    return rows;
  }

  List<Widget> _responseSpeedTiers(
    BuildContext context,
    AppLocalizations l10n,
    ModelSpec spec,
  ) {
    final tiers = controller.draft.responseSpeedTiers;
    final overridden = tiers != null;
    return [
      const SizedBox(height: 8),
      SpecFieldHeader(
        label: l10n.modelSpecFormResponseSpeedTiers,
        source: overridden ? SpecSource.override : SpecSource.fallback,
        overridden: overridden,
        onReset: () => controller.setResponseSpeedTiers(null),
        trailing: IosSwitch(
          key: const ValueKey('model-spec-response-speed-tiers'),
          value: overridden,
          onChanged: (value) => controller.setResponseSpeedTiers(
            value
                ? ResponseSpeedCapabilities.defaultTiersFor(spec.upstreamId)
                : null,
          ),
          semanticLabel: l10n.modelSpecFormResponseSpeedTiers,
        ),
      ),
      _subtitle(context, l10n.modelSpecFormResponseSpeedTiersSubtitle),
      if (tiers != null)
        for (final (speed, label) in const [
          (ResponseSpeed.fast, 'Fast'),
          (ResponseSpeed.ultrafast, 'UltraFast'),
        ])
          IosNavRow(
            label: label,
            subtitle:
                speed == ResponseSpeed.ultrafast &&
                    controller.config.useResponseApi != true
                ? l10n.responseSpeedUltrafastNeedsResponses
                : null,
            subtitleMaxLines: null,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
            onTap: () =>
                controller.setResponseSpeedTier(speed, !tiers.contains(speed)),
            trailing: IosCheckbox(
              key: ValueKey('model-spec-response-speed-${speed.name}'),
              value: tiers.contains(speed),
              onChanged: (value) =>
                  controller.setResponseSpeedTier(speed, value),
              semanticLabel: label,
            ),
          ),
    ];
  }

  List<Widget> _quirk({
    required BuildContext context,
    required ModelSpecField field,
    required String label,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
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
      _subtitle(context, subtitle),
    ];
  }

  Widget _subtitle(BuildContext context, String text) => Padding(
    padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 12,
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
      ),
    ),
  );
}
