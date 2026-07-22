import 'package:flutter/material.dart';

import '../../features/stats/pages/stats_page.dart';
import '../../l10n/app_localizations.dart';
import 'package:KelivoDev/theme/app_font_weights.dart';

class DesktopStatsPane extends StatelessWidget {
  const DesktopStatsPane({super.key});

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
                l10n.statsPageTitle,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: AppFontWeights.regular,
                  color: cs.onSurface.withValues(alpha: 0.9),
                ),
              ),
            ),
          ),
        ),
        const Expanded(child: StatsPage(showAppBar: false)),
      ],
    );
  }
}
