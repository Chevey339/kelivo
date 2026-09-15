import 'package:flutter/material.dart';

import '../../../../core/services/model_spec/model_spec_resolver.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/ios_form_text_field.dart';
import 'model_spec_form_controller.dart';
import 'spec_field_header.dart';

class LimitsPricingSection extends StatelessWidget {
  const LimitsPricingSection({super.key, required this.controller});

  final ModelSpecFormController controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final l10n = AppLocalizations.of(context)!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SpecFieldHeader(
              label: l10n.modelSpecFormLimitsSection,
              source: _limitsSource(),
              overridden:
                  controller.isOverridden(ModelSpecField.contextWindow) ||
                  controller.isOverridden(ModelSpecField.maxOutput),
              onReset: _resetLimits,
            ),
            IosFormTextField(
              label: l10n.modelSpecFormContextWindow,
              controller: controller.contextWindowController,
              keyboardType: TextInputType.number,
              onChanged: (raw) {
                final trimmed = raw.trim();
                if (trimmed.isEmpty) {
                  controller.setContextWindow(null);
                  return;
                }
                final value = int.tryParse(trimmed);
                if (value != null) controller.setContextWindow(value);
              },
            ),
            IosFormTextField(
              label: l10n.modelSpecFormMaxOutput,
              controller: controller.maxOutputController,
              keyboardType: TextInputType.number,
              onChanged: (raw) {
                final trimmed = raw.trim();
                if (trimmed.isEmpty) {
                  controller.setMaxOutput(null);
                  return;
                }
                final value = int.tryParse(trimmed);
                if (value != null) controller.setMaxOutput(value);
              },
            ),
            SpecFieldHeader(
              label: l10n.modelSpecFormPricingSection,
              source: controller.sourceOf(ModelSpecField.pricing),
              overridden: controller.isOverridden(ModelSpecField.pricing),
              onReset: () => controller.reset(ModelSpecField.pricing),
            ),
            IosFormTextField(
              label: l10n.modelSpecFormPricingInput,
              controller: controller.pricingInputController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              onChanged: (raw) => _setDouble(raw, controller.setPricingInput),
            ),
            IosFormTextField(
              label: l10n.modelSpecFormPricingOutput,
              controller: controller.pricingOutputController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              onChanged: (raw) => _setDouble(raw, controller.setPricingOutput),
            ),
            IosFormTextField(
              label: l10n.modelSpecFormPricingCacheRead,
              controller: controller.pricingCacheReadController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              onChanged: (raw) =>
                  _setDouble(raw, controller.setPricingCacheRead),
            ),
            IosFormTextField(
              label: l10n.modelSpecFormPricingCacheWrite,
              controller: controller.pricingCacheWriteController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              onChanged: (raw) =>
                  _setDouble(raw, controller.setPricingCacheWrite),
            ),
            IosFormTextField(
              label: l10n.modelSpecFormCurrency,
              controller: controller.currencyController,
              hintText: 'USD',
              onChanged: controller.setCurrency,
            ),
          ],
        );
      },
    );
  }

  SpecSource _limitsSource() {
    if (controller.isOverridden(ModelSpecField.contextWindow) ||
        controller.isOverridden(ModelSpecField.maxOutput)) {
      return SpecSource.override;
    }
    final contextSource = controller.sourceOf(ModelSpecField.contextWindow);
    if (contextSource != SpecSource.fallback) return contextSource;
    return controller.sourceOf(ModelSpecField.maxOutput);
  }

  void _resetLimits() {
    controller.reset(ModelSpecField.contextWindow);
    controller.reset(ModelSpecField.maxOutput);
  }

  void _setDouble(String raw, void Function(double? value) set) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      set(null);
      return;
    }
    final value = double.tryParse(trimmed);
    if (value != null) set(value);
  }
}
