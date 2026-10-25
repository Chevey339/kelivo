import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:Kelivo/core/models/tool_permission_mode.dart';
import 'package:Kelivo/core/services/chat/chat_service.dart';
import 'package:Kelivo/core/services/conversation_tool_permissions.dart';
import 'package:Kelivo/features/home/services/tool_approval_service.dart';
import 'package:Kelivo/icons/lucide_adapter.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/widgets/action_sheet.dart';
import 'package:Kelivo/shared/widgets/ios_tactile.dart';
import 'package:Kelivo/shared/widgets/snackbar.dart';
import 'package:Kelivo/theme/app_semantic_colors.dart';
import 'tools_sheet_row.dart';

Future<bool> setToolPermissionFromUi(
  BuildContext context,
  String id,
  ToolPermissionMode mode, {
  bool notify = true,
}) async {
  return _saveToolPermission(
    Navigator.maybeOf(context, rootNavigator: true)?.context ?? context,
    AppLocalizations.of(context)!,
    ConversationToolPermissions.forChat(context.read<ChatService>()),
    context.read<ToolApprovalService?>(),
    id,
    mode,
    notify: notify,
  );
}

// A notification can outlive the settings dialog or approval row that created
// it. Capture the service and navigator, not that short-lived widget context.
Future<bool> _saveToolPermission(
  BuildContext context,
  AppLocalizations l10n,
  ConversationToolPermissions permissions,
  ToolApprovalService? approvals,
  String id,
  ToolPermissionMode mode, {
  bool notify = true,
}) async {
  final previous = permissions.read(id);
  if (previous == null) return false;
  try {
    await permissions.setMode(id, mode, approvals: approvals);
  } catch (_) {
    if (context.mounted) {
      showAppSnackBar(
        context,
        message: l10n.toolPermissionSaveFailed,
        type: NotificationType.error,
      );
    }
    return false;
  }
  final current = permissions.read(id);
  if (context.mounted &&
      notify &&
      mode == ToolPermissionMode.fullAccess &&
      current?.mode == mode &&
      current?.workspaceId == previous.workspaceId &&
      current?.assistantId == previous.assistantId) {
    showAppSnackBar(
      context,
      message: l10n.toolPermissionEnabledSnack,
      actionLabel: l10n.toolPermissionUndo,
      onAction: () {
        final current = permissions.read(id);
        if (current == null ||
            current.workspaceId != previous.workspaceId ||
            current.assistantId != previous.assistantId) {
          return;
        }
        unawaited(
          _saveToolPermission(
            context,
            l10n,
            permissions,
            approvals,
            id,
            previous.mode,
            notify: false,
          ),
        );
      },
    );
  }
  return true;
}

void showToolPermissionReset(BuildContext context, String id) {
  final permissions = ConversationToolPermissions.forChat(
    context.read<ChatService>(),
  );
  final owner = permissions.read(id);
  final approvals = context.read<ToolApprovalService?>();
  final l10n = AppLocalizations.of(context)!;
  final toastContext =
      Navigator.maybeOf(context, rootNavigator: true)?.context ?? context;
  showAppSnackBar(
    toastContext,
    message: l10n.toolPermissionResetSnack,
    actionLabel: l10n.toolPermissionUndo,
    onAction: () {
      final current = permissions.read(id);
      if (owner == null ||
          current == null ||
          current.workspaceId != owner.workspaceId ||
          current.assistantId != owner.assistantId) {
        return;
      }
      unawaited(
        _saveToolPermission(
          toastContext,
          l10n,
          permissions,
          approvals,
          id,
          ToolPermissionMode.fullAccess,
        ),
      );
    },
  );
}

class ToolPermissionRow extends StatelessWidget {
  const ToolPermissionRow({
    super.key,
    required this.conversationId,
    required this.ensureConversationId,
  });
  final String? conversationId;
  final Future<String?> Function() ensureConversationId;
  static const rowKey = ValueKey('tool-permission-row');
  @override
  Widget build(BuildContext context) {
    final chat = context.watch<ChatService>();
    final mode = ToolPermissionMode.fromExtras(
      chat.getConversation(conversationId ?? '')?.extras ?? {},
    );
    final full = mode == ToolPermissionMode.fullAccess;
    final l10n = AppLocalizations.of(context)!;
    final mobile =
        defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
    return Builder(
      builder: (rowContext) => ToolsSheetRow(
        key: rowKey,
        leading: Icon(
          full ? Lucide.ShieldAlert : Lucide.Shield,
          size: 20,
          color: full
              ? context.appColors.warning
              : Theme.of(context).colorScheme.onSurface,
        ),
        label: l10n.toolPermissionTitle,
        subtitle: full
            ? (mobile
                  ? l10n.toolPermissionFullAccessDescMobile
                  : l10n.toolPermissionFullAccessDesc)
            : l10n.toolPermissionRequestApprovalDesc,
        subtitleMaxLines: 2,
        detail: full
            ? l10n.toolPermissionFullAccess
            : l10n.toolPermissionRequestApproval,
        detailColor: full ? context.appColors.warning : null,
        trailing: ToolsSheetRow.chevron(context),
        onTap: () {
          final box = rowContext.findRenderObject() as RenderBox?;
          final anchor = box == null
              ? Offset.zero
              : box.localToGlobal(Offset(box.size.width, box.size.height));
          unawaited(
            showAdaptiveActionMenu(
              context,
              anchor: anchor,
              title: l10n.toolPermissionTitle,
              items: [
                for (final candidate in ToolPermissionMode.values)
                  ActionSheetItem(
                    key: ValueKey('tool-permission-${candidate.name}'),
                    icon: candidate == ToolPermissionMode.fullAccess
                        ? Lucide.ShieldAlert
                        : Lucide.Shield,
                    label: candidate == ToolPermissionMode.fullAccess
                        ? l10n.toolPermissionFullAccess
                        : l10n.toolPermissionRequestApproval,
                    checked: candidate == mode,
                    onTap: () async {
                      final id = conversationId ?? await ensureConversationId();
                      if (id == null || !context.mounted) return;
                      await setToolPermissionFromUi(context, id, candidate);
                    },
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class SwitchToFullAccess extends StatelessWidget {
  const SwitchToFullAccess({super.key, required this.conversationId});
  final String conversationId;
  @override
  Widget build(BuildContext context) => IosCardPress(
    baseColor: Colors.transparent,
    borderRadius: BorderRadius.circular(8),
    padding: const EdgeInsets.symmetric(vertical: 6),
    onTap: () => unawaited(
      setToolPermissionFromUi(
        context,
        conversationId,
        ToolPermissionMode.fullAccess,
      ),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Lucide.ShieldAlert, size: 13, color: context.appColors.warning),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            AppLocalizations.of(context)!.toolApprovalSwitchToFullAccess,
            style: TextStyle(fontSize: 12.5, color: context.appColors.warning),
          ),
        ),
      ],
    ),
  );
}

class ToolPermissionDot extends StatelessWidget {
  const ToolPermissionDot({
    super.key,
    required this.conversationId,
    required this.child,
  });
  final String? conversationId;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    bool full = false;
    try {
      full = context.select<ChatService, bool>(
        (chat) =>
            ToolPermissionMode.fromExtras(
              chat.getConversation(conversationId ?? '')?.extras ?? {},
            ) ==
            ToolPermissionMode.fullAccess,
      );
    } on ProviderNotFoundException {
      /* No conversation host in isolated previews. */
    }
    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        if (full)
          Positioned(
            top: 1,
            right: 1,
            child: Tooltip(
              message: AppLocalizations.of(context)!.toolPermissionFullAccess,
              child: Container(
                key: const ValueKey('tool-permission-dot'),
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: context.appColors.warning,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class ToolPermissionBadge extends StatelessWidget {
  const ToolPermissionBadge({super.key, required this.conversationId});
  final String conversationId;
  @override
  Widget build(BuildContext context) {
    final full = context.select<ChatService, bool>(
      (chat) =>
          ToolPermissionMode.fromExtras(
            chat.getConversation(conversationId)?.extras ?? {},
          ) ==
          ToolPermissionMode.fullAccess,
    );
    if (!full) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: Tooltip(
        message: AppLocalizations.of(context)!.toolPermissionFullAccess,
        child: Icon(
          Lucide.ShieldAlert,
          size: 16,
          color: context.appColors.warning,
        ),
      ),
    );
  }
}

class ToolPermissionResultStatus extends StatelessWidget {
  const ToolPermissionResultStatus({super.key, this.metadata});
  final Map<String, dynamic>? metadata;
  static bool isVisible(Map<String, dynamic>? metadata) =>
      metadata?['toolPermissionError'] == 'approval_denied' ||
      metadata?['toolPermission'] == 'fullAccess';
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final denied = metadata?['toolPermissionError'] == 'approval_denied';
    final label = denied
        ? l10n.toolApprovalDenied
        : metadata?['toolPermission'] == 'fullAccess'
        ? l10n.toolApprovalByFullAccess
        : null;
    if (label == null) return const SizedBox.shrink();
    return Text(
      label,
      style: TextStyle(
        fontSize: 12,
        color: denied
            ? Theme.of(context).colorScheme.error
            : Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }
}
