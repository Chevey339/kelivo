import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/ios_form_text_field.dart';
import '../../../shared/widgets/segmented_tabs.dart';
import 'provider_custom_request_editor.dart';

/// Request controls shared by the mobile balance page and desktop dialog.
class ProviderBalanceRequestEditor extends StatelessWidget {
  const ProviderBalanceRequestEditor({
    super.key,
    required this.method,
    required this.headers,
    required this.bodyController,
    required this.onMethodChanged,
    required this.onHeadersChanged,
    required this.onBodyChanged,
  });

  final String method;
  final List<Map<String, String>> headers;
  final TextEditingController bodyController;
  final ValueChanged<String> onMethodChanged;
  final ProviderRequestRowsChanged onHeadersChanged;
  final ValueChanged<String> onBodyChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.providerDetailPageBalanceMethodLabel,
          style: TextStyle(
            fontSize: 13,
            color: cs.onSurface.withValues(alpha: 0.8),
          ),
        ),
        const SizedBox(height: 6),
        SegmentedTabs(
          key: const ValueKey('provider-balance-method'),
          tabs: const [
            SegmentedTab(label: 'GET'),
            SegmentedTab(label: 'POST'),
          ],
          index: method == 'POST' ? 1 : 0,
          radioGroup: true,
          onChanged: (index) => onMethodChanged(index == 1 ? 'POST' : 'GET'),
        ),
        const SizedBox(height: 12),
        Text(
          l10n.providerDetailPageBalanceRequestHint('{{apiKey}}'),
          style: TextStyle(
            fontSize: 12,
            height: 1.4,
            color: cs.onSurface.withValues(alpha: 0.65),
          ),
        ),
        const SizedBox(height: 12),
        ProviderCustomRequestEditor(
          headers: headers,
          body: const [],
          showHeader: false,
          showBodySection: false,
          onHeadersChanged: onHeadersChanged,
          onBodyChanged: (_) async {},
        ),
        if (method == 'POST') ...[
          const SizedBox(height: 12),
          IosFormTextField(
            key: const ValueKey('provider-balance-body'),
            label: l10n.providerDetailPageBalanceBodyLabel,
            controller: bodyController,
            minLines: 3,
            maxLines: 6,
            outerPadding: EdgeInsets.zero,
            autocorrect: false,
            enableSuggestions: false,
            onChanged: onBodyChanged,
          ),
          const SizedBox(height: 6),
          Text(
            l10n.providerDetailPageBalanceBodyHint,
            style: TextStyle(
              fontSize: 12,
              height: 1.4,
              color: cs.onSurface.withValues(alpha: 0.65),
            ),
          ),
        ],
      ],
    );
  }
}
