import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/providers/settings_provider.dart';
import '../../../l10n/app_localizations.dart';

Future<void> showOcrPromptSheet(BuildContext context) async {
  final cs = Theme.of(context).colorScheme;
  final l10n = AppLocalizations.of(context)!;
  final settings = context.read<SettingsProvider>();
  final controller = TextEditingController(text: settings.ocrPrompt);

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
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: controller,
                maxLines: 8,
                decoration: InputDecoration(
                  hintText: l10n.defaultModelPageOcrPromptHint,
                  filled: true,
                  fillColor: Theme.of(ctx).brightness == Brightness.dark
                      ? Colors.white10
                      : const Color(0xFFF2F3F5),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: cs.outlineVariant.withValues(alpha: 0.4),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: cs.outlineVariant.withValues(alpha: 0.4),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: cs.primary.withValues(alpha: 0.5),
                    ),
                  ),
                ),
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
}
