import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/providers/assistant_provider.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/ios_switch.dart';

class OAuthModelSwitch extends StatelessWidget {
  const OAuthModelSwitch({
    super.key,
    required this.providerId,
    required this.modelId,
  });

  final String providerId;
  final String modelId;

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final config = settings.getProviderConfig(providerId);
    final name =
        (config.modelOverrides[modelId] as Map?)?['name'] as String? ?? modelId;
    return IosSwitch(
      key: ValueKey('oauth-model-enabled-$modelId'),
      semanticLabel:
          '${AppLocalizations.of(context)!.addProviderSheetEnabledLabel}: $name',
      value: config.isModelEnabled(modelId),
      onChanged: (enabled) async {
        final assistants = context.read<AssistantProvider>();
        await settings.setModelEnabled(providerId, modelId, enabled);
        if (!enabled &&
            settings
                .getProviderConfig(providerId)
                .disabledModels
                .contains(modelId)) {
          await assistants.clearModelSelectionsForProvider(
            providerId,
            modelId: modelId,
          );
        }
      },
    );
  }
}
