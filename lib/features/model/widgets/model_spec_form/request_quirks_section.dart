import 'package:flutter/material.dart';

import '../../../../core/models/model_spec.dart';
import '../../../../core/providers/settings_provider.dart';
import '../../../../core/services/api/builtin_tools.dart';
import '../../../../core/services/model_spec/model_spec_resolver.dart';
import '../../../../l10n/app_localizations.dart';
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
}
