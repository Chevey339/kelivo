import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/providers/assistant_provider.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/services/haptics.dart';
import '../../../icons/lucide_adapter.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/ios_tactile.dart';
import '../../../theme/app_font_weights.dart';

/// Shared content for the document processing configuration panel.
///
/// Used by both the mobile bottom sheet and the desktop popover.
class DocumentProcessingConfigContent extends StatelessWidget {
  const DocumentProcessingConfigContent({super.key, this.assistantId});

  final String? assistantId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final assistantProvider = context.watch<AssistantProvider>();
    final assistant = assistantProvider.currentAssistant;
    final settings = context.watch<SettingsProvider>();
    final hasOcrModel =
        settings.ocrModelProvider != null && settings.ocrModelId != null;

    final ocrEnabled = settings.ocrEnabled;
    final docxMode = assistant?.docxMode ?? 'extract';
    final pdfMode = assistant?.pdfMode ?? 'extract';
    final otherMode = assistant?.otherOfficeMode ?? 'direct';

    Future<void> updateDocx(String v) async {
      final a = assistantProvider.currentAssistant;
      if (a == null) return;
      await assistantProvider.updateAssistant(a.copyWith(docxMode: v));
    }

    Future<void> updatePdf(String v) async {
      final a = assistantProvider.currentAssistant;
      if (a == null) return;
      await assistantProvider.updateAssistant(a.copyWith(pdfMode: v));
    }

    Future<void> updateOther(String v) async {
      final a = assistantProvider.currentAssistant;
      if (a == null) return;
      await assistantProvider.updateAssistant(a.copyWith(otherOfficeMode: v));
    }

    Future<void> resetAll() async {
      final a = assistantProvider.currentAssistant;
      if (a == null) return;
      final updated = a.copyWith(
        docxMode: 'extract',
        pdfMode: 'extract',
        otherOfficeMode: 'direct',
      );
      await assistantProvider.updateAssistant(updated);
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Image without vision model (OCR toggle)
          _SectionHeader(label: l10n.documentProcessingImageWithoutVision),
          const SizedBox(height: 4),
          _ModeSegmentedControl(
            options: [
              _ModeOption(value: 'ocr', label: l10n.documentProcessingModeOcr),
              _ModeOption(
                value: 'discard',
                label: l10n.documentProcessingModeDiscard,
              ),
            ],
            selected: ocrEnabled ? 'ocr' : 'discard',
            disabledValue: hasOcrModel ? null : 'ocr',
            onChanged: (v) async {
              Haptics.light();
              await settings.setOcrEnabled(v == 'ocr');
            },
          ),
          if (!hasOcrModel)
            Padding(
              padding: const EdgeInsets.only(top: 4, left: 4),
              child: Text(
                l10n.documentProcessingOcrNotConfigured,
                style: TextStyle(
                  fontSize: 12,
                  color: cs.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ),

          const SizedBox(height: 16),

          // DOCX
          _SectionHeader(label: l10n.documentProcessingDocx),
          const SizedBox(height: 4),
          _ModeSegmentedControl(
            options: [
              _ModeOption(
                value: 'extract',
                label: l10n.documentProcessingModeLocalParse,
              ),
              _ModeOption(
                value: 'direct',
                label: l10n.documentProcessingModeDirectUpload,
              ),
            ],
            selected: docxMode,
            onChanged: (v) async {
              Haptics.light();
              await updateDocx(v);
            },
          ),

          const SizedBox(height: 16),

          // PDF
          _SectionHeader(label: l10n.documentProcessingPdf),
          const SizedBox(height: 4),
          _ModeSegmentedControl(
            options: [
              _ModeOption(
                value: 'extract',
                label: l10n.documentProcessingModeLocalParse,
              ),
              _ModeOption(
                value: 'direct',
                label: l10n.documentProcessingModeDirectUpload,
              ),
            ],
            selected: pdfMode,
            onChanged: (v) async {
              Haptics.light();
              await updatePdf(v);
            },
          ),

          const SizedBox(height: 16),

          // Other Office
          _SectionHeader(label: l10n.documentProcessingOtherOffice),
          const SizedBox(height: 4),
          _ModeSegmentedControl(
            options: [
              _ModeOption(
                value: 'discard',
                label: l10n.documentProcessingModeDiscard,
              ),
              _ModeOption(
                value: 'direct',
                label: l10n.documentProcessingModeDirectUpload,
              ),
            ],
            selected: otherMode,
            onChanged: (v) async {
              Haptics.light();
              await updateOther(v);
            },
          ),

          const SizedBox(height: 16),

          // Disclaimer note
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              l10n.documentProcessingDisclaimer,
              style: TextStyle(
                fontSize: 12,
                color: cs.onSurface.withValues(alpha: 0.6),
                height: 1.5,
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Reset to defaults
          SizedBox(
            width: double.infinity,
            child: IosCardPress(
              baseColor: cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
              onTap: () async {
                Haptics.light();
                await resetAll();
              },
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: Text(
                  l10n.documentProcessingResetDefault,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: AppFontWeights.medium,
                    color: cs.primary,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _ModeOption {
  final String value;
  final String label;
  const _ModeOption({required this.value, required this.label});
}

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 2),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 14,
          fontWeight: AppFontWeights.semibold,
          color: cs.onSurface.withValues(alpha: 0.8),
        ),
      ),
    );
  }
}

class _ModeSegmentedControl extends StatelessWidget {
  final List<_ModeOption> options;
  final String selected;
  final String? disabledValue;
  final ValueChanged<String> onChanged;

  const _ModeSegmentedControl({
    required this.options,
    required this.selected,
    this.disabledValue,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (int i = 0; i < options.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: _ModeButton(
              option: options[i],
              selected: options[i].value == selected,
              disabled:
                  disabledValue != null && options[i].value == disabledValue,
              onTap: () {
                if (disabledValue != null &&
                    options[i].value == disabledValue) {
                  return;
                }
                onChanged(options[i].value);
              },
            ),
          ),
        ],
      ],
    );
  }
}

class _ModeButton extends StatelessWidget {
  final _ModeOption option;
  final bool selected;
  final bool disabled;
  final VoidCallback onTap;

  const _ModeButton({
    required this.option,
    required this.selected,
    this.disabled = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bg = selected
        ? cs.primary.withValues(alpha: 0.15)
        : cs.surfaceContainerHighest.withValues(alpha: 0.5);
    final fg = disabled
        ? cs.onSurface.withValues(alpha: 0.3)
        : selected
        ? cs.primary
        : cs.onSurface.withValues(alpha: 0.7);

    return IosCardPress(
      baseColor: bg,
      borderRadius: BorderRadius.circular(10),
      duration: const Duration(milliseconds: 200),
      pressedScale: 0.97,
      onTap: onTap,
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Center(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selected && !disabled)
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Icon(Lucide.Check, size: 14, color: fg),
              ),
            Flexible(
              child: Text(
                option.label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: selected
                      ? AppFontWeights.semibold
                      : AppFontWeights.medium,
                  color: fg,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
