import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/models/message_part.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/ios_tactile.dart';
import '../../../theme/app_semantic_colors.dart';
import '../pages/oauth_provider_detail_page.dart';

class OAuthMessageRecovery extends StatelessWidget {
  const OAuthMessageRecovery({super.key, required this.error});
  final ProviderAuthErrorPart error;

  @override
  Widget build(BuildContext context) {
    final config = context
        .watch<SettingsProvider>()
        .providerConfigs[error.providerId];
    if (config == null || !config.isOAuth) return const SizedBox.shrink();
    final l = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final connected =
        config.oauthCredentials != null &&
        !config.oauthCredentials!.requiresLogin;
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Wrap(
        spacing: 12,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Icon(
            connected ? LucideIcons.circleCheck : LucideIcons.circleAlert,
            size: 15,
            color: connected ? context.appColors.success : cs.error,
          ),
          Text(
            connected ? l.oauthLoginRestored : l.oauthExpired(config.name),
            style: TextStyle(
              fontSize: 13,
              color: connected ? context.appColors.success : cs.error,
            ),
          ),
          if (!connected)
            IosCardPress(
              baseColor: Colors.transparent,
              onTap: () => showOAuthProviderDetails(
                context,
                config.id,
                startLogin: true,
              ),
              child: Text(
                l.oauthRelogin,
                style: TextStyle(fontSize: 13, color: cs.primary),
              ),
            ),
          IosCardPress(
            baseColor: Colors.transparent,
            onTap: () => showOAuthProviderDetails(context, config.id),
            child: Text(
              l.oauthDetails,
              style: TextStyle(fontSize: 13, color: cs.primary),
            ),
          ),
        ],
      ),
    );
  }
}
