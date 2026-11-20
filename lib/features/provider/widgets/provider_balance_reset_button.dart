import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/ios_text_button.dart';
import '../../../theme/app_font_weights.dart';
import '../../settings/widgets/custom_theme_widgets.dart';

class ProviderBalanceResetButton extends StatelessWidget {
  const ProviderBalanceResetButton({super.key, required this.onConfirmed});

  final Future<void> Function() onConfirmed;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: IosTextButton(
        label: l10n.providerDetailPageBalanceResetDefaultsButton,
        color: Theme.of(context).colorScheme.error,
        padding: EdgeInsets.zero,
        onPressed: () => _confirmReset(context),
      ),
    );
  }

  Future<void> _confirmReset(BuildContext context) async {
    // Keep the route dependency on this button so the form retains its draft.
    final sourceRoute = ModalRoute.of(context);
    if (sourceRoute?.isCurrent == false) return;

    final confirmed = await showAppDialog<bool>(
      context,
      maxWidth: 380,
      child: Builder(
        builder: (dialogContext) {
          final l10n = AppLocalizations.of(dialogContext)!;
          final colors = Theme.of(dialogContext).colorScheme;
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l10n.providerDetailPageBalanceResetDefaultsButton,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: AppFontWeights.emphasis,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.providerDetailPageBalanceResetConfirmMessage,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.4,
                    color: colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 8,
                  children: [
                    IosTextButton(
                      label: l10n.providerDetailPageCancelButton,
                      color: colors.onSurface,
                      onPressed: () => Navigator.of(dialogContext).pop(false),
                    ),
                    IosTextButton(
                      label: l10n.providerDetailPageBalanceResetConfirmButton,
                      color: colors.error,
                      onPressed: () => Navigator.of(dialogContext).pop(true),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
    if (confirmed == true &&
        context.mounted &&
        sourceRoute?.isCurrent != false) {
      await onConfirmed();
    }
  }
}
