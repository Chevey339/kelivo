import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/models/provider_oauth.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/ios_settings_rows.dart';
import '../../../shared/widgets/ios_tactile.dart';
import '../../../theme/app_font_weights.dart';
import 'oauth_account_card.dart';

/// Read-only account connection details. Credentials are never rendered here.
class OAuthConnectionInfo extends StatelessWidget {
  const OAuthConnectionInfo({
    super.key,
    required this.config,
    this.desktop = false,
  });

  final ProviderConfig config;
  final bool desktop;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final credentials = config.oauthCredentials;
    final fields = <(String, String)>[
      (l.oauthEndpoint, config.oauthProvider!.baseUrl),
      if (config.oauthProvider!.scope.isNotEmpty)
        (l.oauthScope, config.oauthProvider!.scope),
      if (credentials?.accountId case final id?) (l.oauthAccountId, id),
      if (credentials != null)
        (l.oauthTokenExpiry, oauthDisplayTime(context, credentials.expiresAt)),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (desktop) ...[
          const SizedBox(height: 12),
          Text(
            l.oauthConnectionInfo,
            style: TextStyle(fontSize: 14, fontWeight: AppFontWeights.semibold),
          ),
          const SizedBox(height: 6),
        ],
        for (final (label, value) in fields)
          if (desktop)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 13,
                        color: cs.onSurface.withValues(alpha: .65),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 260,
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            value,
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                        IosIconButton(
                          icon: LucideIcons.copy,
                          size: 14,
                          semanticLabel: label,
                          onTap: () =>
                              Clipboard.setData(ClipboardData(text: value)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            )
          else
            IosNavRow(
              label: label,
              subtitle: value,
              subtitleMaxLines: null,
              trailing: const Icon(LucideIcons.copy, size: 14),
              onTap: () => Clipboard.setData(ClipboardData(text: value)),
            ),
        if (desktop) const SizedBox(height: 12),
      ],
    );
  }
}
