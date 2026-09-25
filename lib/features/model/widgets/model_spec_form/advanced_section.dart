import 'package:flutter/material.dart';

import '../../../../core/services/model_spec/model_spec_resolver.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../provider/widgets/provider_custom_request_editor.dart';
import 'model_spec_form_controller.dart';
import 'request_quirks_section.dart';
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
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
              child: ProviderCustomRequestEditor(
                headers: headers,
                body: const <Map<String, String>>[],
                showHeader: false,
                showSectionTitles: false,
                showBodySection: false,
                onHeadersChanged: (rows) async => controller.setHeaders(rows),
                onBodyChanged: (_) async {},
              ),
            ),
            const SizedBox(height: 16),
            SpecFieldHeader(
              label: l10n.modelDetailSheetCustomBodyTitle,
              source: controller.isBodyOverridden
                  ? SpecSource.override
                  : SpecSource.fallback,
              overridden: controller.isBodyOverridden,
              onReset: controller.resetBody,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
              child: ProviderCustomRequestEditor(
                headers: const <Map<String, String>>[],
                body: body,
                showHeader: false,
                showSectionTitles: false,
                showHeadersSection: false,
                onHeadersChanged: (_) async {},
                onBodyChanged: (rows) async => controller.setBody(rows),
              ),
            ),
            RequestQuirksSection(controller: controller),
          ],
        );
      },
    );
  }
}
