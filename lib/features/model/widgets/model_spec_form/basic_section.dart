import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/models/model_spec.dart';
import '../../../../core/services/model_spec/model_spec_resolver.dart';
import '../../../../icons/lucide_adapter.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/ios_form_text_field.dart';
import '../../../../shared/widgets/ios_tactile.dart';
import '../../../../shared/widgets/segmented_tabs.dart';
import '../../../../shared/widgets/snackbar.dart';
import 'model_spec_form_controller.dart';
import 'spec_field_header.dart';

class BasicSection extends StatelessWidget {
  const BasicSection({super.key, required this.controller});

  final ModelSpecFormController controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final l10n = AppLocalizations.of(context)!;
        final spec = controller.spec;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SpecFieldHeader(
              label: l10n.modelDetailSheetModelIdLabel,
              source: controller.isApiModelIdOverridden
                  ? SpecSource.override
                  : SpecSource.fallback,
              overridden: controller.isApiModelIdOverridden && controller.isNew,
              onReset: controller.isNew ? controller.resetApiModelId : null,
            ),
            if (controller.isNew)
              IosFormTextField(
                label: '',
                controller: controller.apiModelIdController,
                hintText: l10n.modelDetailSheetModelIdHint,
                inlineLabel: false,
                onChanged: controller.setApiModelId,
              )
            else
              _ReadOnlyIdField(controller: controller),
            const SizedBox(height: 8),
            SpecFieldHeader(
              label: l10n.modelDetailSheetModelNameLabel,
              source: controller.isDisplayNameOverridden
                  ? SpecSource.override
                  : SpecSource.fallback,
              overridden: controller.isDisplayNameOverridden,
              onReset: controller.resetDisplayName,
            ),
            IosFormTextField(
              label: '',
              controller: controller.displayNameController,
              inlineLabel: false,
              onChanged: controller.setDisplayName,
            ),
            const SizedBox(height: 8),
            SpecFieldHeader(
              label: l10n.modelDetailSheetModelTypeLabel,
              source: controller.sourceOf(ModelSpecField.type),
              overridden: controller.isOverridden(ModelSpecField.type),
              onReset: () => controller.reset(ModelSpecField.type),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
              child: SegmentedTabs(
                tabs: [
                  SegmentedTab(label: l10n.modelDetailSheetChatType),
                  SegmentedTab(label: l10n.modelDetailSheetEmbeddingType),
                  SegmentedTab(label: l10n.modelSpecFormImageType),
                ],
                index: spec.type == ModelType.embedding
                    ? 1
                    : spec.type == ModelType.image
                    ? 2
                    : 0,
                onChanged: (index) {
                  controller.setType(switch (index) {
                    1 => ModelType.embedding,
                    2 => ModelType.image,
                    _ => ModelType.chat,
                  });
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ReadOnlyIdField extends StatelessWidget {
  const _ReadOnlyIdField({required this.controller});

  final ModelSpecFormController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
      child: Row(
        children: [
          Expanded(
            child: IosFormTextField(
              label: '',
              controller: controller.apiModelIdController,
              enabled: false,
              inlineLabel: false,
              outerPadding: EdgeInsets.zero,
            ),
          ),
          IosIconButton(
            icon: Lucide.Copy,
            size: 18,
            minSize: 40,
            tooltip: l10n.shareProviderSheetCopyButton,
            semanticLabel: l10n.shareProviderSheetCopyButton,
            color: cs.onSurface.withValues(alpha: 0.8),
            onTap: () {
              final text = controller.apiModelIdController.text.trim();
              if (text.isEmpty) return;
              Clipboard.setData(ClipboardData(text: text));
              showAppSnackBar(
                context,
                message: l10n.shareProviderSheetCopiedMessage,
                type: NotificationType.success,
              );
            },
          ),
        ],
      ),
    );
  }
}
