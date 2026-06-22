import 'package:flutter/material.dart';
import '../../features/faq/faq_content.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/app_font_weights.dart';

class DesktopFaqPane extends StatelessWidget {
  final String? initialFaqKey;

  const DesktopFaqPane({super.key, this.initialFaqKey});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
          child: Text(
            l10n.faqPageTitle,
            style: TextStyle(
              fontSize: 18,
              fontWeight: AppFontWeights.semibold,
              color: cs.onSurface,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Expanded(child: FaqContent(initialEntryKey: initialFaqKey)),
      ],
    );
  }
}
