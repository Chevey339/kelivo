import 'package:flutter/material.dart';

import '../../../../core/services/model_spec/model_spec_resolver.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/ios_form_text_field.dart';
import 'model_spec_form_controller.dart';
import 'spec_field_header.dart';

const double kModelSpecValueFieldWidth = 120;

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
              key: const ValueKey('model-spec-context-window'),
              label: l10n.modelSpecFormContextWindow,
              controller: controller.contextWindowController,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.right,
              fieldWidth: kModelSpecValueFieldWidth,
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
              key: const ValueKey('model-spec-max-output'),
              label: l10n.modelSpecFormMaxOutput,
              controller: controller.maxOutputController,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.right,
              fieldWidth: kModelSpecValueFieldWidth,
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
            const SizedBox(height: 8),
            SpecFieldHeader(
              label: l10n.modelSpecFormPricingSection,
              source: controller.sourceOf(ModelSpecField.pricing),
              overridden: controller.isOverridden(ModelSpecField.pricing),
              onReset: () => controller.reset(ModelSpecField.pricing),
            ),
            IosFormTextField(
              key: const ValueKey('model-spec-pricing-input'),
              label: l10n.modelSpecFormPricingInput,
              controller: controller.pricingInputController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              textAlign: TextAlign.right,
              fieldWidth: kModelSpecValueFieldWidth,
              onChanged: (raw) => _setDouble(raw, controller.setPricingInput),
            ),
            IosFormTextField(
              key: const ValueKey('model-spec-pricing-output'),
              label: l10n.modelSpecFormPricingOutput,
              controller: controller.pricingOutputController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              textAlign: TextAlign.right,
              fieldWidth: kModelSpecValueFieldWidth,
              onChanged: (raw) => _setDouble(raw, controller.setPricingOutput),
            ),
            IosFormTextField(
              key: const ValueKey('model-spec-pricing-cache-read'),
              label: l10n.modelSpecFormPricingCacheRead,
              controller: controller.pricingCacheReadController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              textAlign: TextAlign.right,
              fieldWidth: kModelSpecValueFieldWidth,
              onChanged: (raw) =>
                  _setDouble(raw, controller.setPricingCacheRead),
            ),
            IosFormTextField(
              key: const ValueKey('model-spec-pricing-cache-write'),
              label: l10n.modelSpecFormPricingCacheWrite,
              controller: controller.pricingCacheWriteController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              textAlign: TextAlign.right,
              fieldWidth: kModelSpecValueFieldWidth,
              onChanged: (raw) =>
                  _setDouble(raw, controller.setPricingCacheWrite),
            ),
            IosFormTextField(
              key: const ValueKey('model-spec-currency'),
              label: l10n.modelSpecFormCurrency,
              controller: controller.currencyController,
              hintText: 'USD',
              textAlign: TextAlign.right,
              fieldWidth: kModelSpecValueFieldWidth,
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
