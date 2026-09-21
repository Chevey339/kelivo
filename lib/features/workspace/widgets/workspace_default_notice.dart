import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import 'package:Kelivo/core/providers/assistant_provider.dart';
import 'package:Kelivo/core/providers/workspace_provider.dart';
import 'package:Kelivo/core/services/workspace/workspace_binding_actions.dart';
import 'package:Kelivo/features/assistant/pages/assistant_settings_edit_page.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/widgets/snackbar.dart';

void showWorkspaceDefaultNotice(
  BuildContext context, {
  required WorkspaceDefaultNotice? notice,
  required String workspaceId,
}) {
  if (notice == null) return;
  final assistants = context.read<AssistantProvider>();
  final workspaces = context.read<WorkspaceProvider>();
  final assistant = notice.assistant;
  final current = assistants.getById(assistant.id);
  if (current == null ||
      !identical(
        current.defaultWorkspaceChangeToken,
        assistant.defaultWorkspaceChangeToken,
      )) {
    return;
  }
  final navigator = Navigator.of(context);
  final l10n = AppLocalizations.of(context)!;
  showAppSnackBar(
    context,
    message: notice.automaticallyRemembered
        ? l10n.workspaceBindingRememberedDefault(current.name)
        : l10n.workspaceBindingSuggestDefault(current.name),
    duration: const Duration(seconds: 8),
    actionLabel: notice.automaticallyRemembered
        ? l10n.workspaceBindingUndoDefault
        : l10n.workspaceBindingUseAsDefault,
    onTap: () {
      if (!navigator.mounted || assistants.getById(assistant.id) == null) {
        return;
      }
      unawaited(
        openAssistantBasicSettings(
          navigator.context,
          assistantId: assistant.id,
        ),
      );
    },
    onAction: () async {
      // Only a later default-workspace edit expires this action, including an
      // explicit selection of the same workspace (or of None).
      final latest = assistants.getById(assistant.id);
      if (!navigator.mounted ||
          latest == null ||
          !identical(
            latest.defaultWorkspaceChangeToken,
            assistant.defaultWorkspaceChangeToken,
          )) {
        return;
      }
      if (!notice.automaticallyRemembered &&
          workspaces.byId(workspaceId) == null) {
        return;
      }
      await assistants.updateAssistant(
        latest.copyWith(
          clearDefaultWorkspaceId: notice.automaticallyRemembered,
          defaultWorkspaceId: notice.automaticallyRemembered
              ? null
              : workspaceId,
        ),
      );
    },
  );
}
