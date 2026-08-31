import 'package:flutter/material.dart';

import '../../icons/lucide_adapter.dart';
import '../../l10n/app_localizations.dart';
import '../../utils/url_launcher_ext.dart';

/// Shown when the installed database was written by a newer app version;
/// restarting cannot help, so the only immediate action is updating Kelivo.
class UpdateRequiredScreen extends StatelessWidget {
  const UpdateRequiredScreen({
    super.key,
    required this.diagnosticCode,
    this.openConversionTool,
  });

  static const conversionToolUrl = 'https://kelivo.psycheas.top/tools';

  final String diagnosticCode;

  /// Overridable so widget tests do not have to wait on a platform channel.
  final Future<void> Function()? openConversionTool;

  Future<void> _openConversionTool(BuildContext context) {
    if (openConversionTool != null) return openConversionTool!();
    return context.openUrl(conversionToolUrl);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: colors.surface,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Material(
                color: colors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(20),
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: colors.primaryContainer,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(
                          Icons.system_update_alt_rounded,
                          size: 30,
                          color: colors.onPrimaryContainer,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        l10n.startupDatabaseUpdateRequiredTitle,
                        style: textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        l10n.startupDatabaseUpdateRequiredContent,
                        style: textTheme.bodyLarge?.copyWith(
                          color: colors.onSurfaceVariant,
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Divider(
                        height: 1,
                        color: colors.outlineVariant.withValues(alpha: 0.7),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        l10n.startupDatabaseUpdateRequiredDowngradeTitle,
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        l10n.startupDatabaseUpdateRequiredDowngradeIntro,
                        style: textTheme.bodyMedium?.copyWith(
                          color: colors.onSurfaceVariant,
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _NumberedStep(
                        number: 1,
                        text: l10n.startupDatabaseUpdateRequiredDowngradeStep1,
                      ),
                      const SizedBox(height: 12),
                      _NumberedStep(
                        number: 2,
                        text: l10n.startupDatabaseUpdateRequiredDowngradeStep2(
                          conversionToolUrl,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _NumberedStep(
                        number: 3,
                        text: l10n.startupDatabaseUpdateRequiredDowngradeStep3,
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 44,
                        child: OutlinedButton.icon(
                          onPressed: () => _openConversionTool(context),
                          icon: const Icon(Lucide.ExternalLink, size: 18),
                          label: Text(
                            l10n.startupDatabaseUpdateRequiredOpenTool,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SelectableText(
                        conversionToolUrl,
                        style: textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                          fontFamily: 'monospace',
                        ),
                      ),
                      const SizedBox(height: 24),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: colors.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: SelectableText(
                          l10n.backupRestoreFailureDiagnostic(diagnosticCode),
                          style: textTheme.bodySmall?.copyWith(
                            color: colors.onSurfaceVariant,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NumberedStep extends StatelessWidget {
  const _NumberedStep({required this.number, required this.text});

  final int number;
  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: colors.secondaryContainer,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '$number',
            style: textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w600,
              color: colors.onSecondaryContainer,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Text(
              text,
              style: textTheme.bodyMedium?.copyWith(
                color: colors.onSurface,
                height: 1.45,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
