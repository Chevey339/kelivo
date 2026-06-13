import 'package:flutter/material.dart';
import '../../core/services/troubleshoot/troubleshoot_data.dart';
import '../../features/troubleshoot/troubleshoot_content.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/app_font_weights.dart';

class DesktopTroubleshootPane extends StatelessWidget {
  final String? initialFaqKey;
  final void Function(TroubleshootAction action)? onAction;

  const DesktopTroubleshootPane({super.key, this.initialFaqKey, this.onAction});

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
            l10n.troubleshootPageTitle,
            style: TextStyle(
              fontSize: 18,
              fontWeight: AppFontWeights.semibold,
              color: cs.onSurface,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Expanded(
          child: TroubleshootContent(
            initialEntryKey: initialFaqKey,
            onDesktopAction: onAction,
          ),
        ),
      ],
    );
  }
}

DesktopTroubleshootPane buildTroubleshootPane({
  String? initialFaqKey,
  void Function(TroubleshootAction action)? onAction,
}) {
  return DesktopTroubleshootPane(
    initialFaqKey: initialFaqKey,
    onAction: onAction,
  );
}
