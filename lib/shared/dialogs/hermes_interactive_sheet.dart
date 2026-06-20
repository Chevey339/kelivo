import 'package:flutter/material.dart';

import '../../core/providers/hermes_gateway_provider.dart';
import '../../hermes/hermes_gateway.dart';
import '../../hermes/hermes_models.dart';
import '../../hermes/hermes_rpc.dart';
import '../../l10n/app_localizations.dart';

/// Unified sheet widget for Hermes interactive requests:
/// Approval, Clarify, Sudo, Secret.
///
/// Each request type has its own static `show*` factory.
class HermesInteractiveSheet {
  // ── Approval ─────────────────────────────────────────────────────────

  /// Show an approval request sheet (tool execution, file write, etc.).
  ///
  /// [gateway] is used to send `approval.respond`.
  /// [request] contains the session_id and payload.
  static Future<void> showApproval({
    required BuildContext context,
    required HermesGateway gateway,
    required HermesPendingRequest request,
  }) async {
    final l10n = AppLocalizations.of(context)!;
    final event = request.event as ApprovalRequest;
    final title = _extractTitle(event.payload) ?? l10n.hermesApprovalTitle;
    final description = _extractDescription(event.payload);
    final toolName = event.payload['tool']?.toString() ?? '';

    final reasonController = TextEditingController();

    try {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              const Icon(Icons.security, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(title, style: const TextStyle(fontSize: 16)),
              ),
            ],
          ),
          content: SizedBox(
            width: 360,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (description != null) ...[
                  Text(description),
                  const SizedBox(height: 12),
                ],
                if (toolName.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      toolName,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 13,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                TextField(
                  controller: reasonController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: l10n.hermesApprovalReasonLabel,
                    border: const OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                gateway.approvalRespond(
                  request.sessionId,
                  false,
                  reason: reasonController.text.trim().isEmpty
                      ? null
                      : reasonController.text.trim(),
                );
              },
              child: Text(l10n.hermesApprovalDeny),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                gateway.approvalRespond(request.sessionId, true);
              },
              child: Text(l10n.hermesApprovalApprove),
            ),
          ],
        ),
      );
    } finally {
      reasonController.dispose();
    }
  }

  // ── Clarify ────────────────────────────────────────────────────────

  /// Show a clarification request sheet (agent needs user input to proceed).
  static Future<void> showClarify({
    required BuildContext context,
    required HermesGateway gateway,
    required HermesPendingRequest request,
  }) async {
    final l10n = AppLocalizations.of(context)!;
    final event = request.event as ClarifyRequest;
    final title = _extractTitle(event.payload) ?? l10n.hermesClarifyTitle;
    final question = _extractDescription(event.payload);
    final controller = TextEditingController();

    try {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(title),
          content: SizedBox(
            width: 360,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (question != null) ...[
                  Text(question),
                  const SizedBox(height: 12),
                ],
                TextField(
                  controller: controller,
                  autofocus: true,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: '...',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                gateway.clarifyRespond(request.sessionId, {'cancelled': true});
              },
              child: Text(l10n.hermesClarifyCancel),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                gateway.clarifyRespond(request.sessionId, {
                  'response': controller.text,
                });
              },
              child: Text(l10n.hermesClarifySubmit),
            ),
          ],
        ),
      );
    } finally {
      controller.dispose();
    }
  }

  // ── Sudo ───────────────────────────────────────────────────────────

  /// Show a sudo escalation request (elevated permissions).
  static Future<void> showSudo({
    required BuildContext context,
    required HermesGateway gateway,
    required HermesPendingRequest request,
  }) async {
    final l10n = AppLocalizations.of(context)!;
    final event = request.event as SudoRequest;
    final title = _extractTitle(event.payload) ?? l10n.hermesSudoTitle;
    final description = _extractDescription(event.payload);

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(
              Icons.admin_panel_settings,
              size: 20,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 360,
          child: description != null
              ? Text(description)
              : const SizedBox.shrink(),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              gateway.sudoRespond(request.sessionId, false);
            },
            child: Text(l10n.hermesSudoDeny),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              gateway.sudoRespond(request.sessionId, true);
            },
            child: Text(l10n.hermesSudoApprove),
          ),
        ],
      ),
    );
  }

  // ── Secret ─────────────────────────────────────────────────────────

  /// Show a secret/API-key request sheet.
  static Future<void> showSecret({
    required BuildContext context,
    required HermesGateway gateway,
    required HermesPendingRequest request,
  }) async {
    final l10n = AppLocalizations.of(context)!;
    final event = request.event as SecretRequest;
    final title = _extractTitle(event.payload) ?? l10n.hermesSecretTitle;
    final hint = _extractDescription(event.payload);
    final controller = TextEditingController();
    final obscure = ValueNotifier<bool>(true);

    try {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(
                Icons.key,
                size: 20,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(child: Text(title)),
            ],
          ),
          content: SizedBox(
            width: 360,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (hint != null) ...[Text(hint), const SizedBox(height: 12)],
                ValueListenableBuilder<bool>(
                  valueListenable: obscure,
                  builder: (ctx, isObscured, _) => TextField(
                    controller: controller,
                    autofocus: true,
                    obscureText: isObscured,
                    decoration: InputDecoration(
                      border: const OutlineInputBorder(),
                      hintText: 'sk-...',
                      suffixIcon: IconButton(
                        icon: Icon(
                          isObscured ? Icons.visibility_off : Icons.visibility,
                        ),
                        onPressed: () => obscure.value = !isObscured,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                gateway.secretRespond(request.sessionId, '');
              },
              child: Text(l10n.hermesSecretCancel),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                gateway.secretRespond(request.sessionId, controller.text);
              },
              child: Text(l10n.hermesSecretSubmit),
            ),
          ],
        ),
      );
    } finally {
      controller.dispose();
      obscure.dispose();
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────

  static String? _extractTitle(Map<String, dynamic> payload) {
    return payload['title']?.toString();
  }

  static String? _extractDescription(Map<String, dynamic> payload) {
    final desc =
        payload['description'] ?? payload['message'] ?? payload['prompt'];
    return desc?.toString();
  }
}
