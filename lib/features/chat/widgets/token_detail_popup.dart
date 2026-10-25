import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:Kelivo/theme/app_semantic_colors.dart';
import '../../../core/models/token_usage.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/services/model_spec/model_spec_resolver.dart';
import '../../../core/utils/model_cost.dart';
import '../../../icons/lucide_adapter.dart';
import '../../../l10n/app_localizations.dart';

/// A bubble card showing detailed token usage info.
class TokenDetailPopup extends StatelessWidget {
  const TokenDetailPopup({
    super.key,
    this.promptTokens,
    this.completionTokens,
    this.cachedTokens,
    this.reasoningTokens,
    this.cacheWriteTokens,
    this.durationMs,
    this.firstTokenMs,
    this.totalCompletionTokens,
    this.providerId,
    this.modelId,
  });

  final int? promptTokens;
  final int? completionTokens;
  final int? cachedTokens;
  final int? reasoningTokens;
  final int? cacheWriteTokens;
  final int? durationMs;
  final int? firstTokenMs;

  /// Output across the whole generation, matching [durationMs], even when
  /// the token rows are configured to show only the final API request.
  final int? totalCompletionTokens;
  final String? providerId;
  final String? modelId;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final rows = <Widget>[];

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

    if (completionTokens != null && completionTokens! > 0) {
      rows.add(
        _buildRow(
          icon: Lucide.ArrowDown,
          text: l10n.tokenDetailCompletionTokens(completionTokens!),
          cs: cs,
        ),
      );
    }

    if (reasoningTokens != null && reasoningTokens! > 0) {
      rows.add(
        _buildRow(
          icon: Lucide.Brain,
          text: l10n.tokenDetailReasoningTokens(reasoningTokens!),
          cs: cs,
        ),
      );
    }

    if (cacheWriteTokens != null && cacheWriteTokens! > 0) {
      rows.add(
        _buildRow(
          icon: Lucide.Database,
          text: l10n.tokenDetailCacheWriteTokens(cacheWriteTokens!),
          cs: cs,
        ),
      );
    }

    final speedTokens = totalCompletionTokens ?? completionTokens;
    if (speedTokens != null &&
        speedTokens > 0 &&
        durationMs != null &&
        durationMs! > 0) {
      final durationSec = durationMs! / 1000.0;
      final tokPerSec = speedTokens / durationSec;
      rows.add(
        _buildRow(
          icon: Lucide.Zap,
          text: l10n.tokenDetailSpeed(tokPerSec.toStringAsFixed(1)),
          cs: cs,
        ),
      );
    }

    if (firstTokenMs != null && firstTokenMs! >= 0) {
      rows.add(
        _buildRow(
          icon: Lucide.Timer,
          text: l10n.tokenDetailFirstToken(
            (firstTokenMs! / 1000.0).toStringAsFixed(2),
          ),
          cs: cs,
        ),
      );
    }

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

    final cost = _resolveCost(context);
    if (cost != null) {
      rows.add(
        _buildRow(
          icon: Lucide.Coins,
          text: l10n.tokenDetailCost(formatModelCost(cost)),
          cs: cs,
        ),
      );
    }

    if (rows.isEmpty) return const SizedBox.shrink();

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 280),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: context.overlaySurface,
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
        child: SingleChildScrollView(
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
      ),
    );
  }

  ModelCost? _resolveCost(BuildContext context) {
    final providerKey = providerId?.trim();
    final modelKey = modelId?.trim();
    if (providerKey == null ||
        providerKey.isEmpty ||
        modelKey == null ||
        modelKey.isEmpty) {
      return null;
    }
    final settings = context.read<SettingsProvider>();
    return estimateModelCost(
      TokenUsage(
        promptTokens: promptTokens ?? 0,
        completionTokens: completionTokens ?? 0,
        cachedTokens: cachedTokens ?? 0,
        cacheWriteTokens: cacheWriteTokens ?? 0,
      ),
      ModelSpecResolver.instance
          .spec(settings.getProviderConfig(providerKey), modelKey)
          .pricing,
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
