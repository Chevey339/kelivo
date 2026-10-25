import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/providers/mcp_provider.dart';
import '../../../core/services/mcp/mcp_oauth_service.dart';
import '../../../l10n/app_localizations.dart';
import '../../../icons/lucide_adapter.dart';
import '../../../shared/widgets/ios_tile_button.dart';

class McpOAuthProgress extends StatelessWidget {
  const McpOAuthProgress({super.key, required this.serverId});
  final String serverId;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<McpProvider>();
    final stage = provider.oauthStageFor(serverId);
    if (stage == null) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context)!;
    final label = switch (stage) {
      McpOAuthStage.discovery => l10n.mcpOAuthDiscovering,
      McpOAuthStage.registration => l10n.mcpOAuthRegistering,
      McpOAuthStage.browser => l10n.mcpOAuthWaitingBrowser,
      McpOAuthStage.token => l10n.mcpOAuthExchangingToken,
      McpOAuthStage.reconnect => l10n.mcpPageStatusConnecting,
    };
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(fontSize: 12))),
          const SizedBox(width: 8),
          IosTileButton(
            key: ValueKey('mcp-oauth-cancel-$serverId'),
            onTap: () => provider.cancelAuthorization(serverId),
            label: l10n.oauthCancel,
            icon: Lucide.X,
            fontSize: 12,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          ),
        ],
      ),
    );
  }
}
