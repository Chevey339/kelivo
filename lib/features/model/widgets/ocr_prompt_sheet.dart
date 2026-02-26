import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:re_editor/re_editor.dart';

import '../../../core/providers/settings_provider.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/input_height_constraints.dart';
import '../../../shared/widgets/plain_text_code_editor.dart';

Future<void> showOcrPromptSheet(BuildContext context) async {
  final cs = Theme.of(context).colorScheme;
  final l10n = AppLocalizations.of(context)!;
  final settings = context.read<SettingsProvider>();
  final controller = CodeLineEditingController.fromText(settings.ocrPrompt);

  try {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: cs.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 12,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: cs.onSurface.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  l10n.defaultModelPagePromptLabel,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Builder(
                  builder: (innerCtx) {
                    final maxPromptHeight = computeInputMaxHeight(
                      context: innerCtx,
                      reservedHeight: 220,
                      softCapFraction: 0.45,
                      minHeight: 120,
                    );
                    return ConstrainedBox(
                      constraints: BoxConstraints(minHeight: 120, maxHeight: maxPromptHeight),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Theme.of(ctx).brightness == Brightness.dark ? Colors.white10 : const Color(0xFFF2F3F5),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.4)),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: PlainTextCodeEditor(
                          controller: controller,
                          autofocus: false,
                          hint: l10n.defaultModelPageOcrPromptHint,
                          padding: const EdgeInsets.all(12),
                          fontSize: 14,
                          fontHeight: 1.4,
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    TextButton(
                      onPressed: () async {
                        await settings.resetOcrPrompt();
                        controller.text = settings.ocrPrompt;
                      },
                      child: Text(l10n.defaultModelPageResetDefault),
                    ),
                    const Spacer(),
                    FilledButton(
                      onPressed: () async {
                        await settings.setOcrPrompt(controller.text.trim());
                        if (ctx.mounted) Navigator.of(ctx).pop();
                      },
                      child: Text(l10n.defaultModelPageSave),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  } finally {
    controller.dispose();
  }
}

