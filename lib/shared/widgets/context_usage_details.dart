import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/utils/token_format.dart';
import '../../features/home/services/context_usage_service.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/app_font_weights.dart';

String contextUsageStateLabel(
  AppLocalizations l10n,
  ContextUsageSnapshot? snapshot,
) {
  return switch (snapshot?.state) {
    ContextUsageState.exact => l10n.contextUsageStateExact,
    ContextUsageState.estimated => l10n.contextUsageStateEstimated,
    ContextUsageState.stale => l10n.contextUsageStateStale,
    ContextUsageState.computing => l10n.contextUsageStateComputing,
    ContextUsageState.none || null => l10n.contextUsageStateNone,
  };
}

String contextUsageSummaryText(
  AppLocalizations l10n,
  ContextUsageSnapshot? snapshot,
) {
  final window = snapshot?.contextWindow;
  if (snapshot == null || window == null || window <= 0) {
    return l10n.contextUsageNoWindow;
  }
  final percent = ((snapshot.ratio ?? 0) * 100).round();
  return l10n.contextUsageUsedWindow(
    formatTokenCount(snapshot.usedTokens),
    formatTokenCount(window),
    percent,
  );
}

List<({String key, String label, int tokens})> contextUsageVisibleBuckets(
  AppLocalizations l10n,
  ContextUsageBuckets buckets,
) {
  return [
    (
      key: 'system',
      label: l10n.contextUsageBucketSystem,
      tokens: buckets.system,
    ),
    (
      key: 'injections',
      label: l10n.contextUsageBucketInjections,
      tokens: buckets.injections,
    ),
    (
      key: 'history',
      label: l10n.contextUsageBucketHistory,
      tokens: buckets.history,
    ),
    (key: 'tools', label: l10n.contextUsageBucketTools, tokens: buckets.tools),
    (
      key: 'attachments',
      label: l10n.contextUsageBucketAttachments,
      tokens: buckets.attachments,
    ),
    (key: 'draft', label: l10n.contextUsageBucketDraft, tokens: buckets.draft),
  ].where((entry) => entry.tokens > 0).toList(growable: false);
}

class ContextUsageBucketBars extends StatelessWidget {
  const ContextUsageBucketBars({super.key, required this.snapshot});

  final ContextUsageSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final entries = contextUsageVisibleBuckets(l10n, snapshot.buckets);
    if (entries.isEmpty) return const SizedBox.shrink();
    final denom = math.max(snapshot.contextWindow ?? snapshot.usedTokens, 1);

    return Column(
      children: [
        for (var i = 0; i < entries.length; i++) ...[
          if (i > 0) const SizedBox(height: 8),
          _BucketRow(
            key: ValueKey('context-usage-bucket-${entries[i].key}'),
            label: entries[i].label,
            tokens: entries[i].tokens,
            fraction: entries[i].tokens / denom,
            color: cs.primary,
            trackColor: cs.outline.withValues(alpha: 0.16),
          ),
        ],
      ],
    );
  }
}

class _BucketRow extends StatelessWidget {
  const _BucketRow({
    super.key,
    required this.label,
    required this.tokens,
    required this.fraction,
    required this.color,
    required this.trackColor,
  });

  final String label;
  final int tokens;
  final double fraction;
  final Color color;
  final Color trackColor;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: AppFontWeights.medium,
                  color: cs.onSurface,
                ),
              ),
            ),
            Text(
              formatTokenCount(tokens),
              style: TextStyle(
                fontSize: 12,
                fontWeight: AppFontWeights.medium,
                color: cs.onSurface.withValues(alpha: 0.62),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: SizedBox(
            height: 4,
            child: Stack(
              fit: StackFit.expand,
              children: [
                ColoredBox(color: trackColor),
                FractionallySizedBox(
                  alignment: AlignmentDirectional.centerStart,
                  widthFactor: fraction.clamp(0.0, 1.0),
                  child: ColoredBox(color: color),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
