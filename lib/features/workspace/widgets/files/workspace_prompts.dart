import 'package:Kelivo/features/settings/widgets/custom_theme_widgets.dart';
import 'package:Kelivo/icons/lucide_adapter.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/features/workspace/workspace_layout.dart';
import 'package:Kelivo/shared/widgets/form_sheet.dart';
import 'package:Kelivo/shared/widgets/ios_form_text_field.dart';
import 'package:Kelivo/shared/widgets/ios_tile_button.dart';
import 'package:Kelivo/shared/widgets/section_card.dart';
import 'package:Kelivo/theme/app_font_weights.dart';
import 'package:flutter/material.dart';

export 'package:Kelivo/features/workspace/widgets/files/file_browser.dart'
    show showWorkspaceFolderPicker;

Future<String?> showWorkspaceNamePrompt({
  required BuildContext context,
  required String title,
  required String label,
  required String hint,
  required String confirmLabel,
  String initial = '',
}) {
  if (useDesktopWorkspaceLayout(context)) {
    return showAppDialog<String>(
      context,
      child: _NamePromptDialog(
        title: title,
        label: label,
        hint: hint,
        confirmLabel: confirmLabel,
        initial: initial,
      ),
    );
  }
  return showFormSheet<String>(
    context,
    builder: (ctx) => _NamePromptSheet(
      title: title,
      label: label,
      hint: hint,
      confirmLabel: confirmLabel,
      initial: initial,
    ),
  );
}

class _NamePromptSheet extends StatefulWidget {
  const _NamePromptSheet({
    required this.title,
    required this.label,
    required this.hint,
    required this.confirmLabel,
    required this.initial,
  });

  final String title;
  final String label;
  final String hint;
  final String confirmLabel;
  final String initial;

  @override
  State<_NamePromptSheet> createState() => _NamePromptSheetState();
}

class _NamePromptSheetState extends State<_NamePromptSheet> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initial,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _controller.text.trim();
    if (name.isEmpty) return;
    Navigator.of(context).pop(name);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final canSubmit = _controller.text.trim().isNotEmpty;
    return FormSheet(
      title: widget.title,
      actions: FormSheetActions(
        key: const ValueKey<String>('workspace-prompt-confirm'),
        cancelLabel: l10n.workspaceFilesCancel,
        confirmLabel: widget.confirmLabel,
        onCancel: () => Navigator.of(context).pop(),
        onConfirm: canSubmit ? _submit : null,
      ),
      children: [
        SectionCard(
          children: [
            IosFormTextField(
              label: widget.label,
              controller: _controller,
              hintText: widget.hint,
              inlineLabel: false,
              autofocus: true,
              textInputAction: TextInputAction.done,
              onChanged: (_) => setState(() {}),
            ),
          ],
        ),
      ],
    );
  }
}

class _NamePromptDialog extends StatefulWidget {
  const _NamePromptDialog({
    required this.title,
    required this.label,
    required this.hint,
    required this.confirmLabel,
    required this.initial,
  });

  final String title;
  final String label;
  final String hint;
  final String confirmLabel;
  final String initial;

  @override
  State<_NamePromptDialog> createState() => _NamePromptDialogState();
}

class _NamePromptDialogState extends State<_NamePromptDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initial,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _controller.text.trim();
    if (name.isEmpty) return;
    Navigator.of(context).pop(name);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 16 + bottomInset),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: AppFontWeights.emphasis,
              ),
            ),
            const SizedBox(height: 12),
            IosFormTextField(
              label: widget.label,
              controller: _controller,
              hintText: widget.hint,
              autofocus: true,
              textInputAction: TextInputAction.done,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: IosTileButton(
                    icon: Lucide.X,
                    label: l10n.workspaceFilesCancel,
                    onTap: () => Navigator.of(context).pop(),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: IosTileButton(
                    key: const ValueKey<String>('workspace-prompt-confirm'),
                    icon: Lucide.Check,
                    label: widget.confirmLabel,
                    onTap: _submit,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

Future<bool> showWorkspaceConfirm({
  required BuildContext context,
  required String title,
  required String message,
  required String confirmLabel,
  bool destructive = false,
  Widget? extra,
}) async {
  final l10n = AppLocalizations.of(context)!;
  final cs = Theme.of(context).colorScheme;
  final result = await showAppDialog<bool>(
    context,
    child: Builder(
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: AppFontWeights.emphasis,
                ),
              ),
              const SizedBox(height: 10),
              Text(message, style: const TextStyle(fontSize: 14, height: 1.4)),
              if (extra != null) ...[const SizedBox(height: 12), extra],
              const SizedBox(height: 16),
              IosTileButton(
                key: const ValueKey<String>('workspace-confirm-accept'),
                icon: Lucide.Trash,
                label: confirmLabel,
                backgroundColor: destructive ? cs.error : null,
                onTap: () => Navigator.of(ctx).pop(true),
              ),
              const SizedBox(height: 8),
              IosTileButton(
                icon: Lucide.X,
                label: l10n.workspaceFilesCancel,
                onTap: () => Navigator.of(ctx).pop(false),
              ),
            ],
          ),
        );
      },
    ),
  );
  return result == true;
}
