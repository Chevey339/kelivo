import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/form_sheet.dart';
import '../../../shared/widgets/section_card.dart';

/// FormSheet bounds and scrolls the details while keeping actions reachable.
class McpErrorDetailsSheet extends StatelessWidget {
  const McpErrorDetailsSheet({
    super.key,
    required this.serverName,
    required this.message,
    required this.onReconnect,
  });

  final String serverName;
  final String? message;
  final VoidCallback onReconnect;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return FormSheet(
      title: l10n.mcpPageErrorDialogTitle,
      actions: FormSheetActions(
        cancelLabel: l10n.mcpPageClose,
        confirmLabel: l10n.mcpPageReconnect,
        onCancel: () => Navigator.of(context).pop(),
        onConfirm: onReconnect,
      ),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            serverName,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(height: 12),
        SectionCard(
          padding: const EdgeInsets.all(12),
          child: SizedBox(
            width: double.infinity,
            child: SelectableText(
              message?.isNotEmpty == true
                  ? message!
                  : l10n.mcpPageErrorNoDetails,
            ),
          ),
        ),
      ],
    );
  }
}
