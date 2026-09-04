import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'package:Kelivo/icons/lucide_adapter.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/widgets/ios_tile_button.dart';
import 'package:Kelivo/theme/app_font_weights.dart';

class PreviewLoading extends StatelessWidget {
  const PreviewLoading({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(child: CupertinoActivityIndicator(radius: 12));
  }
}

class PreviewError extends StatelessWidget {
  const PreviewError({super.key, required this.onRetry, this.message});

  final VoidCallback onRetry;
  final String? message;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message ?? l10n.workspacePreviewLoadError,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: cs.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 16),
            IosTileButton(
              icon: Lucide.RotateCcw,
              label: l10n.workspacePreviewRetry,
              onTap: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}

class PreviewEmptyHint extends StatelessWidget {
  const PreviewEmptyHint({
    super.key,
    required this.title,
    this.hint,
    this.icon = Lucide.File,
  });

  final String title;
  final String? hint;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final hintText = hint;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 44, color: cs.onSurface.withValues(alpha: 0.26)),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                fontWeight: AppFontWeights.semibold,
                color: cs.onSurface.withValues(alpha: 0.72),
              ),
            ),
            if (hintText != null && hintText.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                hintText,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12.5,
                  color: cs.onSurface.withValues(alpha: 0.52),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
