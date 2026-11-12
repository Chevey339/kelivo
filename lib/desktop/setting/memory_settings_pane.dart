import 'package:flutter/material.dart';

import '../../features/settings/pages/memory_settings_page.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/app_font_weights.dart';

/// Desktop right-side pane for global memory settings.
class DesktopMemorySettingsPane extends StatelessWidget {
  const DesktopMemorySettingsPane({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 960),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: 36,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    l10n.memorySettingsPageTitle,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: AppFontWeights.regular,
                      color: cs.onSurface.withValues(alpha: 0.9),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Expanded(
                child: MemorySettingsContent(padding: EdgeInsets.zero),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
