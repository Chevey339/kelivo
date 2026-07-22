import 'package:flutter/material.dart';
import 'package:Kelivo/theme/app_font_weights.dart';

import '../../../icons/lucide_adapter.dart';
import '../../../l10n/app_localizations.dart';
import '../models/stats_models.dart';
import 'stats_section_card.dart';

class StatsRankSection extends StatelessWidget {
  const StatsRankSection({
    super.key,
    required this.title,
    required this.leftHeader,
    required this.rightHeader,
    required this.items,
    this.icon,
    this.leadingBuilder,
  });

  final String title;
  final String leftHeader;
  final String rightHeader;
  final List<StatsRankItem> items;
  final IconData? icon;
  final Widget Function(BuildContext context, StatsRankItem item)?
  leadingBuilder;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final showExpand = items.length > 5;
    return StatsSectionCard(
      title: title,
      trailing: showExpand
          ? Tooltip(
              message: l10n.statsPageShowAllTooltip,
              child: IconButton(
                icon: const Icon(Lucide.Maximize, size: 16),
                visualDensity: VisualDensity.compact,
                onPressed: () => _showAll(context),
              ),
            )
          : null,
      child: _RankBody(
        leftHeader: leftHeader,
        rightHeader: rightHeader,
        items: items.take(5).toList(),
        icon: icon,
        leadingBuilder: leadingBuilder,
      ),
    );
  }

  void _showAll(BuildContext context) {
    if (MediaQuery.sizeOf(context).width < 560) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (context) => _RankFullPage(
            title: title,
            leftHeader: leftHeader,
            rightHeader: rightHeader,
            items: items,
            icon: icon,
            leadingBuilder: leadingBuilder,
          ),
        ),
      );
      return;
    }

    showDialog<void>(
      context: context,
      builder: (context) {
        final l10n = AppLocalizations.of(context)!;
        final mediaSize = MediaQuery.sizeOf(context);
        return AlertDialog(
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 24,
          ),
          title: Text(title),
          content: SizedBox(
            width: 520,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: mediaSize.height * 0.64),
              child: SingleChildScrollView(
                child: _RankBody(
                  leftHeader: leftHeader,
                  rightHeader: rightHeader,
                  items: items,
                  icon: icon,
                  leadingBuilder: leadingBuilder,
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l10n.statsPageClose),
            ),
          ],
        );
      },
    );
  }
}

class _RankFullPage extends StatelessWidget {
  const _RankFullPage({
    required this.title,
    required this.leftHeader,
    required this.rightHeader,
    required this.items,
    required this.icon,
    required this.leadingBuilder,
  });

  final String title;
  final String leftHeader;
  final String rightHeader;
  final List<StatsRankItem> items;
  final IconData? icon;
  final Widget Function(BuildContext context, StatsRankItem item)?
  leadingBuilder;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            _RankBody(
              leftHeader: leftHeader,
              rightHeader: rightHeader,
              items: items,
              icon: icon,
              leadingBuilder: leadingBuilder,
            ),
          ],
        ),
      ),
    );
  }
}

class _RankBody extends StatelessWidget {
  const _RankBody({
    required this.leftHeader,
    required this.rightHeader,
    required this.items,
    required this.icon,
    required this.leadingBuilder,
  });

  final String leftHeader;
  final String rightHeader;
  final List<StatsRankItem> items;
  final IconData? icon;
  final Widget Function(BuildContext context, StatsRankItem item)?
  leadingBuilder;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    if (items.isEmpty) {
      return SizedBox(
        height: 132,
        child: Center(
          child: Text(
            l10n.statsPageEmptyTitle,
            style: TextStyle(
              fontSize: 13,
              color: cs.onSurface.withValues(alpha: 0.58),
            ),
          ),
        ),
      );
    }

    final maxValue = items.fold<int>(
      0,
      (previous, item) => item.value > previous ? item.value : previous,
    );

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              Expanded(child: _HeaderText(leftHeader)),
              _HeaderText(rightHeader),
            ],
          ),
        ),
        for (final item in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _RankRow(
              item: item,
              maxValue: maxValue,
              icon: icon,
              leadingBuilder: leadingBuilder,
            ),
          ),
      ],
    );
  }
}

class _HeaderText extends StatelessWidget {
  const _HeaderText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Text(
      text,
      style: TextStyle(
        fontSize: 11,
        color: cs.onSurface.withValues(alpha: 0.52),
        fontWeight: AppFontWeights.semibold,
      ),
    );
  }
}

class _RankRow extends StatelessWidget {
  const _RankRow({
    required this.item,
    required this.maxValue,
    required this.icon,
    required this.leadingBuilder,
  });

  final StatsRankItem item;
  final int maxValue;
  final IconData? icon;
  final Widget Function(BuildContext context, StatsRankItem item)?
  leadingBuilder;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ratio = maxValue <= 0 ? 0.0 : item.value / maxValue;
    final widthFactor = (0.36 + ratio * 0.64).clamp(0.36, 1.0);
    final fillColor = isDark
        ? Colors.white.withValues(alpha: 0.1)
        : const Color(0xFFF2F3F5);
    final leading = leadingBuilder?.call(context, item);

    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 34,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.centerLeft,
              children: [
                FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: widthFactor,
                  child: Container(
                    height: 34,
                    decoration: BoxDecoration(
                      color: fillColor,
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Row(
                      children: [
                        if (leading != null)
                          SizedBox(
                            width: 24,
                            height: 24,
                            child: Center(child: leading),
                          )
                        else if (icon != null)
                          Icon(
                            icon,
                            size: 15,
                            color: cs.onSurface.withValues(alpha: 0.58),
                          ),
                        const SizedBox(width: 7),
                        Flexible(
                          child: Text(
                            item.label,
                            maxLines: 1,
                            softWrap: false,
                            style: TextStyle(
                              color: cs.onSurface.withValues(alpha: 0.86),
                              fontSize: 12,
                              fontWeight: AppFontWeights.semibold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 52,
          child: Text(
            item.value.toString(),
            textAlign: TextAlign.right,
            style: TextStyle(
              color: cs.onSurface.withValues(alpha: 0.76),
              fontSize: 12,
              fontWeight: AppFontWeights.semibold,
            ),
          ),
        ),
      ],
    );
  }
}
