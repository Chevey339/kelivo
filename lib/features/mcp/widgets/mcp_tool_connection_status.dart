import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/providers/mcp_provider.dart';
import '../../../icons/lucide_adapter.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/form_sheet.dart';
import '../../../shared/widgets/ios_tactile.dart';
import '../../../shared/widgets/ios_text_button.dart';
import '../../../shared/widgets/snackbar.dart';
import 'mcp_error_details_sheet.dart';
import 'mcp_server_avatar.dart';

/// Connection actions remain separate from the chat's server selection.
class McpToolConnectionStatus extends StatelessWidget {
  const McpToolConnectionStatus({
    super.key,
    required this.serverId,
    this.desktop = false,
  });

  final String serverId;
  final bool desktop;

  @override
  Widget build(BuildContext context) {
    final mcp = context.watch<McpProvider>();
    final server = mcp.getById(serverId);
    final status = mcp.statusFor(serverId);
    if (server == null || status == McpStatus.connected) {
      return const SizedBox.shrink();
    }
    final l10n = AppLocalizations.of(context)!;
    final busy =
        status == McpStatus.connecting || status == McpStatus.authorizing;
    final label = switch (status) {
      McpStatus.idle => l10n.mcpPageStatusDisconnected,
      McpStatus.connecting => l10n.mcpPageStatusConnecting,
      McpStatus.authorizing => l10n.mcpPageStatusAuthorizing,
      McpStatus.needsAuthorization => l10n.mcpPageStatusAuthorizationRequired,
      _ => l10n.mcpPageStatusFailed,
    };
    final error = mcp.errorFor(serverId);
    Future<void> recover() async {
      try {
        if (status == McpStatus.needsAuthorization) {
          await mcp.authorize(serverId);
        } else {
          await mcp.reconnect(serverId);
        }
      } catch (_) {
        if (context.mounted) {
          showAppSnackBar(
            context,
            message: l10n.mcpPageConnectionFailed,
            type: NotificationType.error,
          );
        }
      }
    }

    void details() {
      void retry(BuildContext dialogContext) {
        Navigator.of(dialogContext).pop();
        unawaited(recover());
      }

      if (desktop) {
        unawaited(
          showDialog<void>(
            context: context,
            builder: (ctx) => McpErrorDetailsDialog(
              serverName: server.name,
              message: error,
              onReconnect: () => retry(ctx),
            ),
          ),
        );
      } else {
        unawaited(
          showFormSheet<void>(
            context,
            builder: (ctx) => McpErrorDetailsSheet(
              serverName: server.name,
              message: error,
              onReconnect: () => retry(ctx),
            ),
          ),
        );
      }
    }

    return Padding(
      padding: EdgeInsets.only(left: desktop ? 36 : 42, right: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                color: mcpStatusColor(context, status),
              ),
            ),
          ),
          if (error?.isNotEmpty == true)
            IosIconButton(
              icon: Lucide.BadgeInfo,
              size: 15,
              minSize: 44,
              semanticLabel: l10n.mcpPageDetails,
              tooltip: l10n.mcpPageDetails,
              onTap: details,
            ),
          if (!busy)
            Flexible(
              child: IosTextButton(
                key: ValueKey('mcp-reconnect-$serverId'),
                label: status == McpStatus.needsAuthorization
                    ? l10n.mcpPageOAuthSignIn
                    : l10n.mcpPageReconnect,
                fontSize: 12,
                padding: const EdgeInsets.symmetric(horizontal: 6),
                onPressed: () => unawaited(recover()),
              ),
            ),
        ],
      ),
    );
  }
}
