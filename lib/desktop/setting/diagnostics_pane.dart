import 'package:flutter/material.dart';

import '../../features/diagnostics/pages/conversation_select_page.dart';
import '../../l10n/app_localizations.dart';
import 'package:Kelivo/theme/app_font_weights.dart';

/// Thin desktop wrapper around [ConversationSelectPage].
class DesktopDiagnosticsPane extends StatelessWidget {
  const DesktopDiagnosticsPane({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 48,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                l10n.settingsPageDiagnostics,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: AppFontWeights.regular,
                  color: cs.onSurface.withValues(alpha: 0.9),
                ),
              ),
            ),
          ),
        ),
        const Expanded(child: ConversationSelectPage(embedded: true)),
      ],
    );
  }
}

