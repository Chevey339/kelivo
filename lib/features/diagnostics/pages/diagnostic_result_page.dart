import 'package:flutter/material.dart';

import '../../../icons/lucide_adapter.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/ios_tactile.dart';
import '../../../theme/app_font_weights.dart';
import '../diagnostic_models.dart';
import 'widgets/cache_ring_chart.dart';
import 'widgets/diagnostic_card.dart';

/// Result page that renders the ring chart and the diagnostic findings.
class DiagnosticResultPage extends StatelessWidget {
  const DiagnosticResultPage({super.key, required this.report});

  final DiagnosticReport report;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final findings = [...report.findings]
      ..sort((a, b) {
        // urgent first, then risk
        final sa = a.severity == DiagnosticSeverity.urgent ? 0 : 1;
        final sb = b.severity == DiagnosticSeverity.urgent ? 0 : 1;
        return sa.compareTo(sb);
      });
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.diagResultTitle),
        leading: IconButton(
          icon: const Icon(Lucide.ArrowLeft),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(0, 12, 0, 24),
        children: [
          _Header(report: report),
          if (findings.isEmpty)
            _AllGood(message: l10n.diagAllGood)
          else
            for (final f in findings) DiagnosticCard(finding: f),
          const SizedBox(height: 12),
          _AggregateFooter(report: report),
        ],
      ),
      backgroundColor: cs.surface,
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.report});
  final DiagnosticReport report;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final agg = report.aggregate;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        children: [
          CacheRingChart(
            hitRate: agg.hitRate,
            totalTokens: agg.inputTokens,
            cachedTokens: agg.cachedTokens,
          ),
          const SizedBox(height: 12),
          Text(
            l10n.diagSampleWindow(
              agg.assistantMessageCount,
              agg.userMessageCount,
            ),
            style: TextStyle(
              fontSize: 12,
              color: cs.onSurface.withValues(alpha: 0.6),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _AggregateFooter extends StatelessWidget {
  const _AggregateFooter({required this.report});
  final DiagnosticReport report;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final agg = report.aggregate;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: cs.onSurface.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _Metric(label: l10n.diagMetricTotal, value: _fmt(agg.inputTokens)),
          _Metric(
            label: l10n.diagMetricCached,
            value: _fmt(agg.cachedTokens),
            color: const Color(0xFFA0DCFD),
          ),
          _Metric(
            label: l10n.diagMetricUncached,
            value: _fmt(agg.uncachedTokens),
            color: const Color(0xFF60B3FE),
          ),
        ],
      ),
    );
  }

  String _fmt(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return n.toString();
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value, this.color});
  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: AppFontWeights.strong,
            color: color ?? cs.onSurface,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            color: cs.onSurface.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }
}

class _AllGood extends StatelessWidget {
  const _AllGood({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
      child: IosCardPress(
        onTap: () {},
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Lucide.CheckCircle, color: cs.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(color: cs.onSurface.withValues(alpha: 0.85)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
