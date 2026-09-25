import 'package:flutter/material.dart';

import '../../../../core/models/model_spec.dart';
import '../../../../core/services/model_spec/model_spec_resolver.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/ios_checkbox.dart';
import 'model_spec_form_controller.dart';
import 'spec_field_header.dart';

class ModalityAbilitySection extends StatelessWidget {
  const ModalityAbilitySection({super.key, required this.controller});

  final ModelSpecFormController controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final l10n = AppLocalizations.of(context)!;
        final spec = controller.spec;
        final hideChatFields = spec.type == ModelType.embedding;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SpecFieldHeader(
              label: l10n.modelDetailSheetInputModesLabel,
              source: controller.sourceOf(ModelSpecField.input),
              overridden: controller.isOverridden(ModelSpecField.input),
              onReset: () => controller.reset(ModelSpecField.input),
            ),
            _CheckRow(
              label: l10n.modelDetailSheetTextMode,
              value: spec.input.contains(Modality.text),
              onChanged: (_) => controller.toggleInput(Modality.text),
            ),
            _CheckRow(
              label: l10n.modelDetailSheetImageMode,
              value: spec.input.contains(Modality.image),
              onChanged: (_) => controller.toggleInput(Modality.image),
            ),
            _CheckRow(
              label: l10n.modelSpecFormAudioMode,
              value: spec.input.contains(Modality.audio),
              onChanged: (_) => controller.toggleInput(Modality.audio),
            ),
            _CheckRow(
              label: l10n.modelSpecFormVideoMode,
              value: spec.input.contains(Modality.video),
              onChanged: (_) => controller.toggleInput(Modality.video),
            ),
            _CheckRow(
              label: l10n.modelSpecFormPdfMode,
              value: spec.input.contains(Modality.pdf),
              onChanged: (_) => controller.toggleInput(Modality.pdf),
            ),
            if (!hideChatFields) ...[
              const SizedBox(height: 8),
              SpecFieldHeader(
                label: l10n.modelDetailSheetOutputModesLabel,
                source: controller.sourceOf(ModelSpecField.output),
                overridden: controller.isOverridden(ModelSpecField.output),
                onReset: () => controller.reset(ModelSpecField.output),
              ),
              _CheckRow(
                label: l10n.modelDetailSheetTextMode,
                value: spec.output.contains(Modality.text),
                onChanged: (_) => controller.toggleOutput(Modality.text),
              ),
              _CheckRow(
                label: l10n.modelDetailSheetImageMode,
                value: spec.output.contains(Modality.image),
                onChanged: (_) => controller.toggleOutput(Modality.image),
              ),
              _CheckRow(
                label: l10n.modelSpecFormAudioMode,
                value: spec.output.contains(Modality.audio),
                onChanged: (_) => controller.toggleOutput(Modality.audio),
              ),
              const SizedBox(height: 8),
              SpecFieldHeader(
                label: l10n.modelDetailSheetAbilitiesLabel,
                source: controller.sourceOf(ModelSpecField.abilities),
                overridden: controller.isOverridden(ModelSpecField.abilities),
                onReset: () => controller.reset(ModelSpecField.abilities),
              ),
              _CheckRow(
                checkboxKey: const ValueKey('model-spec-ability-tool'),
                label: l10n.modelDetailSheetToolsAbility,
                value: spec.abilities.contains(ModelAbility.tool),
                onChanged: (_) => controller.toggleAbility(ModelAbility.tool),
              ),
              _CheckRow(
                checkboxKey: const ValueKey('model-spec-ability-reasoning'),
                label: l10n.modelDetailSheetReasoningAbility,
                value: spec.abilities.contains(ModelAbility.reasoning),
                onChanged: (_) =>
                    controller.toggleAbility(ModelAbility.reasoning),
              ),
              _CheckRow(
                checkboxKey: const ValueKey(
                  'model-spec-ability-structuredOutput',
                ),
                label: l10n.modelSpecFormStructuredOutputAbility,
                value: spec.abilities.contains(ModelAbility.structuredOutput),
                onChanged: (_) =>
                    controller.toggleAbility(ModelAbility.structuredOutput),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _CheckRow extends StatelessWidget {
  const _CheckRow({
    required this.label,
    required this.value,
    required this.onChanged,
    this.checkboxKey,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  final Key? checkboxKey;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: () => onChanged(!value),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          children: [
            IosCheckbox(
              key: checkboxKey,
              value: value,
              onChanged: onChanged,
              semanticLabel: label,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  color: cs.onSurface.withValues(alpha: 0.9),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
