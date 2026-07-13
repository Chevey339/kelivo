import 'package:flutter/material.dart';

import '../../../../icons/lucide_adapter.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../theme/app_font_weights.dart';
import '../../diagnostic_models.dart';

/// iOS-style card for one diagnostic finding.
class DiagnosticCard extends StatelessWidget {
  const DiagnosticCard({super.key, required this.finding});

  final DiagnosticFinding finding;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final isUrgent = finding.severity == DiagnosticSeverity.urgent;
    final accent = isUrgent ? cs.error : const Color(0xFFE0A32B); // amber
    final badge = isUrgent ? l10n.diagSeverityUrgent : l10n.diagSeverityRisk;
    final title = _interpolate(finding.title, l10n);
    final resolvedSuffix = finding.titleSuffix ?? '';
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isUrgent
                            ? Lucide.MessageCircleWarning
                            : Lucide.MessageCircleQuestionMark,
                        size: 12,
                        color: accent,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        badge,
                        style: TextStyle(
                          color: accent,
                          fontSize: 11,
                          fontWeight: AppFontWeights.semibold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '$title$resolvedSuffix',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: AppFontWeights.semibold,
                      color: cs.onSurface,
                    ),
                  ),
                ),
              ],
            ),
            if (finding.subtitle.isNotEmpty) ...[
              const SizedBox(height: 8),
              for (final s in finding.subtitle)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    '${_interpolate(s.key, l10n)}${s.suffix}',
                    style: TextStyle(
                      fontSize: 13,
                      color: cs.onSurface.withValues(alpha: 0.75),
                      height: 1.4,
                    ),
                  ),
                ),
            ],
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: cs.onSurface.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Lucide.Wrench,
                    size: 14,
                    color: cs.onSurface.withValues(alpha: 0.55),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _interpolate(finding.solution, l10n),
                      style: TextStyle(
                        fontSize: 12.5,
                        color: cs.onSurface.withValues(alpha: 0.8),
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Resolve a translation key to its localised string. Falls back to the
  /// key itself when the string is missing, so the UI never crashes.
  String _interpolate(String key, AppLocalizations l10n) {
    switch (key) {
      case 'diagA1Title':
        return l10n.diagA1Title;
      case 'diagA1Subtitle':
        return l10n.diagA1Subtitle;
      case 'diagA1Solution':
        return l10n.diagA1Solution;
      case 'diagA2Title':
        return l10n.diagA2Title;
      case 'diagA2Subtitle':
        return l10n.diagA2Subtitle;
      case 'diagA2Solution':
        return l10n.diagA2Solution;
      case 'diagA3Title':
        return l10n.diagA3Title;
      case 'diagA3Subtitle':
        return l10n.diagA3Subtitle;
      case 'diagA3Solution':
        return l10n.diagA3Solution;
      case 'diagA4Title':
        return l10n.diagA4Title;
      case 'diagA4SubContent':
        return l10n.diagA4SubContent;
      case 'diagA4SubHour':
        return l10n.diagA4SubHour;
      case 'diagA4Solution':
        return l10n.diagA4Solution;
      case 'diagA6Title':
        return l10n.diagA6Title;
      case 'diagA6Subtitle':
        return l10n.diagA6Subtitle;
      case 'diagA6Solution':
        return l10n.diagA6Solution;
      case 'diagT1Title':
        return l10n.diagT1Title;
      case 'diagT1Subtitle':
        return l10n.diagT1Subtitle;
      case 'diagT1Solution':
        return l10n.diagT1Solution;
      case 'diagF1aTitle':
        return l10n.diagF1aTitle;
      case 'diagF1aSubtitle':
        return l10n.diagF1aSubtitle;
      case 'diagF1aSolution':
        return l10n.diagF1aSolution;
      case 'diagF1bTitle':
        return l10n.diagF1bTitle;
      case 'diagF1bSubtitle':
        return l10n.diagF1bSubtitle;
      case 'diagF1bSolution':
        return l10n.diagF1bSolution;
      default:
        return key;
    }
  }
}
