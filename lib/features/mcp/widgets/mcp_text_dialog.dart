import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/ios_form_text_field.dart';
import '../../../shared/widgets/ios_text_button.dart';
import '../../../desktop/widgets/desktop_form_dialog.dart';
import '../../../theme/app_font_weights.dart';

/// Owns the controller until the dialog's closing animation is finished.
class McpTextDialog extends StatefulWidget {
  const McpTextDialog({
    super.key,
    required this.title,
    required this.hint,
    required this.submitLabel,
    required this.valid,
    this.initialValue = '',
    this.invalidMessage,
  });
  final String title;
  final String hint;
  final String submitLabel;
  final String initialValue;
  final String? invalidMessage;
  final bool Function(String) valid;

  @override
  State<McpTextDialog> createState() => _McpTextDialogState();
}

class _McpTextDialogState extends State<McpTextDialog> {
  late final controller = TextEditingController(text: widget.initialValue);
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void _submit() {
    final value = controller.text.trim();
    if (widget.valid(value)) Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    final valid = widget.valid(controller.text.trim());
    return AnimatedPadding(
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOutCubic,
      padding: MediaQuery.viewInsetsOf(context) + const EdgeInsets.all(24),
      child: DesktopFormDialog(
        constraints: const BoxConstraints(maxWidth: 360),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 12, 8),
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
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: IosFormTextField(
                  label: '',
                  controller: controller,
                  hintText: widget.hint,
                  autofocus: true,
                  inlineLabel: false,
                  outerPadding: EdgeInsets.zero,
                  onChanged: (_) => setState(() {}),
                  onSubmitted: (_) => _submit(),
                ),
              ),
              if (!valid &&
                  controller.text.isNotEmpty &&
                  widget.invalidMessage != null)
                Text(
                  widget.invalidMessage!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IosTextButton(
                    label: AppLocalizations.of(context)!.mcpPageCancel,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 8),
                  IosTextButton(
                    label: widget.submitLabel,
                    onPressed: valid ? _submit : null,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
