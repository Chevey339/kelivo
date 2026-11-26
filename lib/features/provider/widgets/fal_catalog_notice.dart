import 'package:flutter/material.dart';

import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../l10n/app_localizations.dart';
import '../../../core/services/media/fal_model_discovery.dart';

String falCatalogErrorMessage(AppLocalizations l10n, Object error) =>
    switch (error) {
      FalUnsupportedEndpoint(input: final key?) => l10n.falUnsupportedInput(
        key,
      ),
      FalUnsupportedEndpoint() => l10n.falUnsupportedOutput,
      _ => l10n.falCatalogLoadFailed(error.toString()),
    };

class FalCatalogNotice extends StatelessWidget {
  const FalCatalogNotice({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: colors.primary.withValues(alpha: .06),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(LucideIcons.info, size: 14, color: colors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              AppLocalizations.of(context)!.creationFalCatalogHint,
              style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}
