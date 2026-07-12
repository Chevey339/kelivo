import 'package:flutter/material.dart';

import '../../../icons/lucide_adapter.dart';
import '../../../l10n/app_localizations.dart';
import '../models/stats_models.dart';
import '../../../theme/app_font_weights.dart';

class StatsMetricGrid extends StatelessWidget {
  const StatsMetricGrid({super.key, required this.summary});

  final StatsSummary summary;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final items = [
      _MetricItem(
        icon: Lucide.MessagesSquare,
        label: l10n.statsPageTotalConversations,
        value: _formatCompact(summary.totalConversations),
      ),
      _MetricItem(
        icon: Lucide.MessageCircle,
        label: l10n.statsPageTotalMessages,
        value:
            '${_formatCompact(summary.totalMessages)} / '
            '${_formatCompact(summary.allRevisionMessages)}',
      ),
      _MetricItem(
        icon: Lucide.Activity,
        label: l10n.statsPageInputTokens,
        value:
            '${_formatCompact(summary.inputTokens)} / '
            '${_formatCompact(summary.allRevisionInputTokens)}',
      ),
      _MetricItem(
        icon: Lucide.Activity,
        label: l10n.statsPageOutputTokens,
        value:
            '${_formatCompact(summary.outputTokens)} / '
            '${_formatCompact(summary.allRevisionOutputTokens)}',
      ),
      _MetricItem(
        icon: Lucide.Zap,
        label: l10n.statsPageCachedTokens,
        value:
            '${_formatCompact(summary.cachedTokens)} / '
            '${_formatCompact(summary.allRevisionCachedTokens)}',
      ),
      _MetricItem(
        icon: Lucide.Activity,
        label: l10n.statsPageLaunchCount,
        value: _formatCompact(summary.launchCount),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 720
            ? 3
            : constraints.maxWidth >= 420
            ? 2
            : 1;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisExtent: 78,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          itemCount: items.length,
          itemBuilder: (context, index) => _MetricTile(item: items[index]),
        );
      },
    );
  }
}

class _MetricItem {
  const _MetricItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({required this.item});

  final _MetricItem item;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.06)
            : cs.surfaceContainerHighest.withValues(alpha: 0.38),
        borderRadius: BorderRadius.circular(10),
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Icon(item.icon, size: 20, color: cs.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  item.value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: cs.onSurface,
                    fontSize: 18,
                    fontWeight: AppFontWeights.emphasis,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: cs.onSurface.withValues(alpha: 0.62),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _formatCompact(int value) {
  if (value >= 1000000000) {
    return '${(value / 1000000000).toStringAsFixed(2)}B';
  }
  if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(2)}M';
  if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}K';
  return value.toString();
}
