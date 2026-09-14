import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/providers/settings_provider.dart';
import '../../../icons/lucide_adapter.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/ios_tactile.dart';
import '../widgets/provider_custom_request_editor.dart';

class ProviderCustomRequestPage extends StatelessWidget {
  const ProviderCustomRequestPage({
    super.key,
    required this.providerKey,
    required this.providerDisplayName,
  });

  final String providerKey;
  final String providerDisplayName;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final settings = context.watch<SettingsProvider>();
    final config = settings.getProviderConfig(
      providerKey,
      defaultName: providerDisplayName,
    );

    return Scaffold(
      appBar: AppBar(
        leadingWidth: 52,
        leading: Padding(
          padding: const EdgeInsets.only(left: 8),
          child: IosIconButton(
            icon: Lucide.ArrowLeft,
            size: 22,
            semanticLabel: l10n.settingsPageBackButton,
            minSize: 44,
            onTap: () => Navigator.of(context).maybePop(),
          ),
        ),
        title: Text(
          l10n.providerDetailPageCustomRequestTitle,
          style: const TextStyle(fontSize: 16),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          Text(
            l10n.providerDetailPageCustomRequestDescription,
            style: TextStyle(
              fontSize: 13,
              height: 1.45,
              color: cs.onSurface.withValues(alpha: 0.68),
            ),
          ),
          const SizedBox(height: 18),
          ProviderCustomRequestEditor(
            key: ValueKey('provider-custom-request-$providerKey'),
            showHeader: false,
            headers: config.customHeaders,
            body: config.customBody,
            onHeadersChanged: (rows) async {
              final old = settings.getProviderConfig(
                providerKey,
                defaultName: providerDisplayName,
              );
              await settings.setProviderConfig(
                providerKey,
                old.copyWith(customHeaders: rows),
              );
            },
            onBodyChanged: (rows) async {
              final old = settings.getProviderConfig(
                providerKey,
                defaultName: providerDisplayName,
              );
              await settings.setProviderConfig(
                providerKey,
                old.copyWith(customBody: rows),
              );
            },
          ),
        ],
      ),
    );
  }
}
