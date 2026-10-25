import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/utils/token_format.dart';
import '../../features/home/services/context_usage_service.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/app_font_weights.dart';

abstract final class ContextUsagePalette {
  static const Color system = Color(0xFF8E8E93);
  static const Color injections = Color(0xFFEC4899);
  static const Color history = Color(0xFF3B82F6);
  static const Color tools = Color(0xFFF59E0B);
  static const Color memory = Color(0xFF14B8A6);
  static const Color worldBook = Color(0xFF22C55E);
  static const Color skills = Color(0xFFEAB308);
  static const Color workspace = Color(0xFF64748B);
  static const Color search = Color(0xFF06B6D4);
  static const Color mcpTools = Color(0xFFF97316);
  static const Color attachments = Color(0xFFB08968);
  static const Color draft = Color(0xFFA855F7);

  static Color track(ColorScheme cs) => cs.onSurface.withValues(alpha: 0.12);

  static Color of(String key, ColorScheme cs) {
    return switch (key) {
      'system' => system,
      'injections' => injections,
      'history' => history,
      'tools' => tools,
      'memory' => memory,
      'worldBook' => worldBook,
      'skills' => skills,
      'workspace' => workspace,
      'search' => search,
      'mcpTools' => mcpTools,
      'attachments' => attachments,
      'draft' => draft,
      'used' => cs.primary,
      'freeSpace' => track(cs),
      _ => cs.primary,
    };
  }
}

class ContextUsageSegment {
  const ContextUsageSegment({
    required this.key,
    required this.tokens,
    required this.fraction,
  });

  final String key;
  final int tokens;
  final double fraction;

  bool get isFreeSpace => key == 'freeSpace';
}

String contextUsageStateLabel(
  AppLocalizations l10n,
  ContextUsageSnapshot? snapshot,
) {
  final state = snapshot?.state;
  if (state == ContextUsageState.exact && snapshot!.calibrated) {
    return l10n.contextUsageStateExactCalibrated;
  }
  return switch (state) {
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
  final used = snapshot?.usedTokens ?? 0;
  final window = snapshot?.contextWindow;
  if (window == null || window <= 0) {
    return formatTokenCount(used);
  }
  final percent = ((snapshot?.ratio ?? 0) * 100).round();
  return l10n.contextUsageUsedWindow(
    formatTokenCount(used),
    formatTokenCount(window),
    percent,
  );
}

String contextUsageSegmentLabel(AppLocalizations l10n, String key) {
  return switch (key) {
    'system' => l10n.contextUsageBucketSystem,
    'injections' => l10n.contextUsageBucketInjections,
    'history' => l10n.contextUsageBucketHistory,
    'tools' => l10n.contextUsageBucketTools,
    'memory' => l10n.contextUsageBucketMemory,
    'worldBook' => l10n.contextUsageBucketWorldBook,
    'skills' => l10n.contextUsageBucketSkills,
    'workspace' => l10n.contextUsageBucketWorkspace,
    'search' => l10n.contextUsageBucketSearch,
    'mcpTools' => l10n.contextUsageBucketMcpTools,
    'attachments' => l10n.contextUsageBucketAttachments,
    'draft' => l10n.contextUsageBucketDraft,
    'used' => l10n.contextUsageBucketUsed,
    'freeSpace' => l10n.contextUsageFreeSpace,
    _ => key,
  };
}

bool contextUsageHasWindow(ContextUsageSnapshot? snapshot) {
  final window = snapshot?.contextWindow;
  return window != null && window > 0;
}

List<ContextUsageSegment> buildContextUsageSegments(
  ContextUsageSnapshot snapshot,
) {
  if (snapshot.state == ContextUsageState.none) {
    return const [];
  }

  final window = snapshot.contextWindow;
  final hasWindow = window != null && window > 0;
  final used = snapshot.usedTokens;
  final buckets = snapshot.buckets;
  final useBuckets =
      (snapshot.state != ContextUsageState.exact || snapshot.calibrated) &&
      buckets.total > 0;
  final denom = hasWindow
      ? window
      : math.max(useBuckets ? buckets.total : used, 1);

  final items = <ContextUsageSegment>[];
  if (useBuckets) {
    for (final entry in [
      (key: 'history', tokens: buckets.history),
      (key: 'tools', tokens: buckets.tools),
      (key: 'mcpTools', tokens: buckets.mcpTools),
      (key: 'skills', tokens: buckets.skills),
      (key: 'system', tokens: buckets.system),
      (key: 'memory', tokens: buckets.memory),
      (key: 'worldBook', tokens: buckets.worldBook),
      (key: 'injections', tokens: buckets.injections),
      (key: 'workspace', tokens: buckets.workspace),
      (key: 'search', tokens: buckets.search),
      (key: 'attachments', tokens: buckets.attachments),
      (key: 'draft', tokens: buckets.draft),
    ]) {
      if (entry.tokens <= 0) continue;
      items.add(
        ContextUsageSegment(
          key: entry.key,
          tokens: entry.tokens,
          fraction: entry.tokens / denom,
        ),
      );
    }
  } else if (used > 0) {
    items.add(
      ContextUsageSegment(key: 'used', tokens: used, fraction: used / denom),
    );
  }

  if (hasWindow) {
    final free = math.max(window - used, 0);
    if (free > 0) {
      items.add(
        ContextUsageSegment(
          key: 'freeSpace',
          tokens: free,
          fraction: free / window,
        ),
      );
    }
  }
  return items;
}

class ContextUsageSummaryHeader extends StatelessWidget {
  const ContextUsageSummaryHeader({
    super.key,
    required this.snapshot,
    this.trailing,
  });

  final ContextUsageSnapshot? snapshot;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              l10n.contextUsageTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 14,
                fontWeight: AppFontWeights.semibold,
                color: cs.onSurface,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              contextUsageSummaryText(l10n, snapshot),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: AppFontWeights.medium,
                color: cs.onSurface.withValues(alpha: 0.78),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              contextUsageStateLabel(l10n, snapshot),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                color: cs.onSurface.withValues(alpha: 0.45),
              ),
            ),
          ],
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

class ContextUsageStackedBar extends StatelessWidget {
  const ContextUsageStackedBar({
    super.key,
    required this.snapshot,
    this.height = 8,
  });

  final ContextUsageSnapshot snapshot;
  final double height;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final painted = buildContextUsageSegments(
      snapshot,
    ).where((segment) => !segment.isFreeSpace).toList(growable: false);
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: CustomPaint(
          painter: _ContextUsageStackedBarPainter(
            trackColor: ContextUsagePalette.track(cs),
            segments: [
              for (final segment in painted)
                (
                  color: ContextUsagePalette.of(segment.key, cs),
                  fraction: segment.fraction,
                ),
            ],
          ),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

class _ContextUsageStackedBarPainter extends CustomPainter {
  const _ContextUsageStackedBarPainter({
    required this.trackColor,
    required this.segments,
  });

  final Color trackColor;
  final List<({Color color, double fraction})> segments;

  static const double _gap = 1.5;

  @override
  void paint(Canvas canvas, Size size) {
    final radius = Radius.circular(size.height / 2);
    final rrect = RRect.fromLTRBR(0, 0, size.width, size.height, radius);
    canvas.drawRRect(rrect, Paint()..color = trackColor);
    if (segments.isEmpty) return;

    canvas.save();
    canvas.clipRRect(rrect);
    var x = 0.0;
    for (var i = 0; i < segments.length; i++) {
      final width = size.width * segments[i].fraction;
      if (width <= 0) continue;
      // Keep small sources visible instead of consuming them with the gap.
      final gap = math.min(_gap, width * 0.2);
      var left = x;
      var right = x + width;
      if (i > 0) left += gap / 2;
      if (i < segments.length - 1) right -= gap / 2;
      if (right > left) {
        canvas.drawRect(
          Rect.fromLTRB(left, 0, right, size.height),
          Paint()..color = segments[i].color,
        );
      }
      x += width;
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_ContextUsageStackedBarPainter oldDelegate) {
    if (trackColor != oldDelegate.trackColor) return true;
    if (segments.length != oldDelegate.segments.length) return true;
    for (var i = 0; i < segments.length; i++) {
      final a = segments[i];
      final b = oldDelegate.segments[i];
      if (a.color != b.color || a.fraction != b.fraction) return true;
    }
    return false;
  }
}

class ContextUsageLegend extends StatelessWidget {
  const ContextUsageLegend({super.key, required this.snapshot});

  final ContextUsageSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final segments = buildContextUsageSegments(snapshot);
    if (segments.isEmpty) return const SizedBox.shrink();
    final showPercent = contextUsageHasWindow(snapshot);

    return Column(
      children: [
        for (var i = 0; i < segments.length; i++) ...[
          if (i > 0) const SizedBox(height: 8),
          _LegendRow(
            key: ValueKey('context-usage-bucket-${segments[i].key}'),
            color: ContextUsagePalette.of(segments[i].key, cs),
            label: contextUsageSegmentLabel(l10n, segments[i].key),
            tokens: segments[i].tokens,
            percent: showPercent
                ? (segments[i].fraction < 0.001
                      ? '<0.1%'
                      : '${(segments[i].fraction * 100).toStringAsFixed(1)}%')
                : null,
          ),
        ],
      ],
    );
  }
}

class _LegendRow extends StatelessWidget {
  const _LegendRow({
    super.key,
    required this.color,
    required this.label,
    required this.tokens,
    required this.percent,
  });

  final Color color;
  final String label;
  final int tokens;
  final String? percent;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final valueStyle = TextStyle(
      fontSize: 12,
      fontWeight: AppFontWeights.medium,
      color: cs.onSurface.withValues(alpha: 0.58),
    );
    return Row(
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
          child: const SizedBox(width: 10, height: 10),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              fontWeight: AppFontWeights.regular,
              color: cs.onSurface,
            ),
          ),
        ),
        Text(formatTokenCount(tokens), style: valueStyle),
        if (percent != null) ...[
          const SizedBox(width: 8),
          SizedBox(
            width: 46,
            child: Text(percent!, textAlign: TextAlign.end, style: valueStyle),
          ),
        ],
      ],
    );
  }
}

class ContextUsageBreakdown extends StatelessWidget {
  const ContextUsageBreakdown({
    super.key,
    required this.snapshot,
    this.headerTrailing,
  });

  final ContextUsageSnapshot? snapshot;
  final Widget? headerTrailing;

  @override
  Widget build(BuildContext context) {
    final segments = snapshot == null
        ? const <ContextUsageSegment>[]
        : buildContextUsageSegments(snapshot!);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ContextUsageSummaryHeader(snapshot: snapshot, trailing: headerTrailing),
        if (segments.isNotEmpty) ...[
          const SizedBox(height: 10),
          ContextUsageStackedBar(
            key: const ValueKey('context-usage-stacked-bar'),
            snapshot: snapshot!,
          ),
          const SizedBox(height: 12),
          ContextUsageLegend(snapshot: snapshot!),
        ],
      ],
    );
  }
}
