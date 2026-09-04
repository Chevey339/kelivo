import 'package:flutter/material.dart';

import 'package:Kelivo/icons/lucide_adapter.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/widgets/ios_tile_button.dart';
import 'package:Kelivo/shared/widgets/section_card.dart';
import 'package:Kelivo/theme/app_font_weights.dart';

class SystemTerminalCard extends StatelessWidget {
  const SystemTerminalCard({super.key, required this.hostDir, this.onOpen});

  static const cardKey = ValueKey<String>('terminal-system-card');
  static const openKey = ValueKey<String>('terminal-open-system');

  final String hostDir;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final canOpen = onOpen != null;
    return Center(
      child: ConstrainedBox(
        key: cardKey,
        constraints: const BoxConstraints(maxWidth: 440),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: SectionCard(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l10n.terminalTitle,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: AppFontWeights.semibold,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  l10n.terminalHostDirectory,
                  style: TextStyle(
                    fontSize: 12,
                    color: cs.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(height: 4),
                SelectableText(
                  hostDir,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: AppFontWeights.medium,
                    color: cs.onSurface.withValues(alpha: 0.88),
                  ),
                ),
                const SizedBox(height: 16),
                KeyedSubtree(
                  key: openKey,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: IosTileButton(
                      icon: Lucide.Terminal,
                      label: l10n.terminalOpenInSystem,
                      enabled: canOpen,
                      onTap: onOpen ?? () {},
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
