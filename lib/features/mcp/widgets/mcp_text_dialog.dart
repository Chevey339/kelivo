import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/ios_form_text_field.dart';
import '../../../theme/app_semantic_colors.dart';

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
    return AlertDialog(
      backgroundColor: context.overlaySurface,
      title: Text(widget.title),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            IosFormTextField(
              label: '',
              controller: controller,
              hintText: widget.hint,
              autofocus: true,
              inlineLabel: false,
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _submit(),
            ),
            if (!valid &&
                controller.text.isNotEmpty &&
                widget.invalidMessage != null)
              Text(
                widget.invalidMessage!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(AppLocalizations.of(context)!.mcpPageCancel),
        ),
        TextButton(
          onPressed: valid ? _submit : null,
          child: Text(widget.submitLabel),
        ),
      ],
    );
  }
}
