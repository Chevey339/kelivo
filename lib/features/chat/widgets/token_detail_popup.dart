import 'package:flutter/material.dart';
import '../../../icons/lucide_adapter.dart';
import '../../../l10n/app_localizations.dart';

/// A bubble card showing detailed token usage info.
///
/// Shows up to 4 rows (hidden when data is null/0):
/// - ArrowUp: prompt tokens (with cached count if > 0)
/// - ArrowDown: completion tokens
/// - Zap: tok/s (completionTokens / durationSeconds)
/// - Timer: duration in seconds
class TokenDetailPopup extends StatelessWidget {
  const TokenDetailPopup({
    super.key,
    this.promptTokens,
    this.completionTokens,
    this.cachedTokens,
    this.durationMs,
  });

  final int? promptTokens;
  final int? completionTokens;
  final int? cachedTokens;
  final int? durationMs;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final rows = <Widget>[];

    // Prompt tokens row
    if (promptTokens != null && promptTokens! > 0) {
      final cached = (cachedTokens ?? 0) > 0 ? cachedTokens! : 0;
      rows.add(
        _buildRow(
          icon: Lucide.ArrowUp,
          text: cached > 0
              ? l10n.tokenDetailPromptTokensWithCache(promptTokens!, cached)
              : l10n.tokenDetailPromptTokens(promptTokens!),
          cs: cs,
        ),
      );
    }

    // Completion tokens row
    if (completionTokens != null && completionTokens! > 0) {
      rows.add(
        _buildRow(
          icon: Lucide.ArrowDown,
          text: l10n.tokenDetailCompletionTokens(completionTokens!),
          cs: cs,
        ),
      );
    }

    // tok/s row
    if (completionTokens != null &&
        completionTokens! > 0 &&
        durationMs != null &&
        durationMs! > 0) {
      final durationSec = durationMs! / 1000.0;
      final tokPerSec = completionTokens! / durationSec;
      rows.add(
        _buildRow(
          icon: Lucide.Zap,
          text: l10n.tokenDetailSpeed(tokPerSec.toStringAsFixed(1)),
          cs: cs,
        ),
      );
    }

    // Duration row
    if (durationMs != null && durationMs! > 0) {
      final durationSec = (durationMs! / 1000.0).toStringAsFixed(1);
      rows.add(
        _buildRow(
          icon: Lucide.clock,
          text: l10n.tokenDetailDuration(durationSec),
          cs: cs,
        ),
      );
    }

    if (rows.isEmpty) return const SizedBox.shrink();

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 220),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: cs.shadow.withValues(alpha: 0.12),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
            BoxShadow(
              color: cs.shadow.withValues(alpha: 0.06),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (int i = 0; i < rows.length; i++) ...[
                if (i > 0) const SizedBox(height: 4),
                rows[i],
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRow({
    required IconData icon,
    required String text,
    required ColorScheme cs,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: cs.onSurface.withValues(alpha: 0.5)),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 12,
              color: cs.onSurface.withValues(alpha: 0.8),
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ),
      ],
    );
  }
}
