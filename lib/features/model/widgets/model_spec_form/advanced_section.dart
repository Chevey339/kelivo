import 'package:flutter/material.dart';

import '../../../../core/services/model_spec/model_spec_resolver.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../provider/widgets/provider_custom_request_editor.dart';
import 'model_spec_form_controller.dart';
import 'spec_field_header.dart';

class AdvancedSection extends StatelessWidget {
  const AdvancedSection({super.key, required this.controller});

  final ModelSpecFormController controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final l10n = AppLocalizations.of(context)!;
        final headers =
            controller.draft.headers ?? const <Map<String, String>>[];
        final body = controller.draft.body ?? const <Map<String, String>>[];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SpecFieldHeader(
              label: l10n.modelDetailSheetCustomHeadersTitle,
              source: controller.isHeadersOverridden
                  ? SpecSource.override
                  : SpecSource.fallback,
              overridden: controller.isHeadersOverridden,
              onReset: controller.resetHeaders,
            ),
            SpecFieldHeader(
              label: l10n.modelDetailSheetCustomBodyTitle,
              source: controller.isBodyOverridden
                  ? SpecSource.override
                  : SpecSource.fallback,
              overridden: controller.isBodyOverridden,
              onReset: controller.resetBody,
            ),
            ProviderCustomRequestEditor(
              headers: headers,
              body: body,
              showHeader: false,
              onHeadersChanged: (rows) async => controller.setHeaders(rows),
              onBodyChanged: (rows) async => controller.setBody(rows),
            ),
          ],
        );
      },
    );
  }
}
