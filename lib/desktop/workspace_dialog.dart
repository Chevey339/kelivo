import 'package:flutter/material.dart';

import 'package:Kelivo/features/settings/widgets/custom_theme_widgets.dart';
import 'package:Kelivo/features/workspace/pages/workspaces_page.dart';
import 'package:Kelivo/features/workspace/widgets/desktop_workspace_button.dart';
import 'package:Kelivo/features/workspace/widgets/workspace_section.dart';
import 'package:Kelivo/icons/lucide_adapter.dart';
import 'package:Kelivo/l10n/app_localizations.dart';

/// Use a navigator route so nested pickers and creation dialogs receive input
/// above this panel, and Escape/back dismisses the current surface only.
Future<void> showDesktopWorkspaceDialog(
  BuildContext context, {
  required Listenable conversationListenable,
  required String? Function() conversationId,
  String? assistantId,
}) {
  return showAppDialog<void>(
    context,
    maxWidth: 520,
    child: Builder(
      builder: (dialogContext) {
        final l10n = AppLocalizations.of(dialogContext)!;
        final cs = Theme.of(dialogContext).colorScheme;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppDialogHeader(title: l10n.workspaceDeskBarTitle),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                child: ListenableBuilder(
                  listenable: conversationListenable,
                  builder: (context, _) => WorkspaceSection(
                    key: ValueKey<String?>(conversationId()),
                    conversationId: conversationId(),
                    assistantId: assistantId,
                    onClose: () => Navigator.of(dialogContext).pop(),
                  ),
                ),
              ),
            ),
            Divider(
              height: 1,
              thickness: 0.5,
              color: cs.outlineVariant.withValues(alpha: 0.12),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Align(
                alignment: Alignment.centerRight,
                child: DesktopWorkspaceButton(
                  key: WorkspaceSection.manageKey,
                  label: l10n.workspaceEntryManage,
                  icon: Lucide.Settings2,
                  onPressed: () async {
                    Navigator.of(dialogContext).pop();
                    await openWorkspacesPage(context);
                  },
                ),
              ),
            ),
          ],
        );
      },
    ),
  );
}
