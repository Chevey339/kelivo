import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/app_localizations.dart';

class ReasoningBudgetCustomDialog {
  static Future<int?> show(
    BuildContext context, {
    required int initialValue,
  }) async {
    final l10n = AppLocalizations.of(context)!;
    final controller = TextEditingController(text: initialValue.toString());

    int? parseValue() => int.tryParse(controller.text.trim());
    bool isValid(int? v) => v != null && v > 0;

    try {
      return await showDialog<int>(
        context: context,
        builder: (ctx) {
          return StatefulBuilder(
            builder: (ctx, setLocal) {
              final parsed = parseValue();
              final valid = isValid(parsed);
              void submit() {
                if (!valid || parsed == null) return;
                Navigator.of(ctx).pop(parsed);
              }

              return AlertDialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                title: Text(l10n.reasoningLevelCustomBudget),
                content: SizedBox(
                  width: 360,
                  child: TextField(
                    controller: controller,
                    autofocus: true,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      helperText: l10n.reasoningLevelCustomBudgetHint,
                    ),
                    onChanged: (_) => setLocal(() {}),
                    onSubmitted: (_) => submit(),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: Text(l10n.assistantEditEmojiDialogCancel),
                  ),
                  TextButton(
                    onPressed: valid ? submit : null,
                    child: Text(l10n.assistantEditEmojiDialogSave),
                  ),
                ],
              );
            },
          );
        },
      );
    } finally {
      WidgetsBinding.instance.addPostFrameCallback((_) => controller.dispose());
    }
  }
}
