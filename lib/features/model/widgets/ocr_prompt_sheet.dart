import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:Kelivo/theme/app_font_weights.dart';

import '../../../core/providers/settings_provider.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/ios_switch.dart';
import 'package:Kelivo/theme/app_semantic_colors.dart';

Future<void> showOcrPromptSheet(BuildContext context) async {
  final cs = Theme.of(context).colorScheme;
  final l10n = AppLocalizations.of(context)!;
  final settings = context.read<SettingsProvider>();
  final controller = TextEditingController(text: settings.ocrPrompt);

  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: context.overlaySurface,
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
              const SizedBox(height: 14),
              Consumer<SettingsProvider>(
                builder: (context, settings, _) {
                  final value = settings.ocrGenerationThinkingEnabled;
                  return InkWell(
                    onTap: () =>
                        settings.setOcrGenerationThinkingEnabled(!value),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              l10n.titleModelThinkingTitle,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: AppFontWeights.medium,
                                color: cs.onSurface.withValues(alpha: 0.92),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          IosSwitch(
                            value: value,
                            semanticLabel: l10n.titleModelThinkingTitle,
                            onChanged: settings.setOcrGenerationThinkingEnabled,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 18),
              Text(
                l10n.defaultModelPagePromptLabel,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: AppFontWeights.semibold,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: controller,
                maxLines: 8,
                decoration: InputDecoration(
                  hintText: l10n.defaultModelPageOcrPromptHint,
                  filled: true,
                  fillColor: ctx.appColors.surfaceFill,
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
                      await settings.resetOcrGenerationThinkingEnabled();
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
