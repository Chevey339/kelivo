import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../l10n/app_localizations.dart';
import '../models/stats_models.dart';
import '../../../theme/app_font_weights.dart';

const double _usageDetailBubbleWidth = 228;
const double _usageDetailBubbleTop = 8;

class StatsUsageChart extends StatefulWidget {
  const StatsUsageChart({super.key, required this.days});

  final List<StatsTrendDay> days;

  @override
  State<StatsUsageChart> createState() => _StatsUsageChartState();
}

class _StatsUsageChartState extends State<StatsUsageChart> {
  final ScrollController _scrollController = ScrollController();
  int? _selectedDayIndex;
  double? _dragStartOffset;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final providers = <String>{};
    var maxDayTotal = 0;
    for (final day in widget.days) {
      var dayTotal = 0;
      for (final entry in day.providerTokens.entries) {
        if (_bucketWeight(entry.value) > 0) {
          providers.add(entry.key);
        }
        dayTotal += _bucketWeight(entry.value);
      }
      if (dayTotal > maxDayTotal) maxDayTotal = dayTotal;
    }
    final providerList = providers.toList();
    final maxDetailRows = widget.days.fold<int>(0, (previous, day) {
      final count = day.providerTokens.values.where(_hasDetailTokens).length;
      return count > previous ? count : previous;
    });
    final chartHeight = (82 + maxDetailRows * 31.0).clamp(160.0, 360.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: chartHeight,
          child: widget.days.isEmpty
              ? const SizedBox.shrink()
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final barWidth = widget.days.length > 45 ? 8.0 : 12.0;
                    final gap = widget.days.length > 45 ? 3.0 : 5.0;
                    final contentWidth =
                        widget.days.length * barWidth +
                        (widget.days.length - 1) * gap;
                    final chartWidth = contentWidth < constraints.maxWidth
                        ? constraints.maxWidth
                        : contentWidth;
                    final selectedIndex = _selectedDayIndex;
                    final chart = MouseRegion(
                      onHover: (event) => _selectDayAt(
                        event.localPosition,
                        barWidth: barWidth,
                        gap: gap,
                      ),
                      onExit: (_) {
                        if (_selectedDayIndex != null) {
                          setState(() => _selectedDayIndex = null);
                        }
                      },
                      child: GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onTapDown: (details) => _selectDayAt(
                          details.localPosition,
                          barWidth: barWidth,
                          gap: gap,
                        ),
                        onHorizontalDragStart: (_) {
                          _dragStartOffset = _scrollController.hasClients
                              ? _scrollController.offset
                              : null;
                        },
                        onHorizontalDragUpdate: (details) {
                          _handleHorizontalDrag(details.primaryDelta ?? 0);
                        },
                        onHorizontalDragEnd: (_) {
                          _dragStartOffset = null;
                        },
                        onHorizontalDragCancel: () {
                          _dragStartOffset = null;
                        },
                        child: RepaintBoundary(
                          key: const ValueKey('stats-usage-chart-bars'),
                          child: SizedBox(
                            height: constraints.maxHeight,
                            width: chartWidth,
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                CustomPaint(
                                  size: Size(chartWidth, constraints.maxHeight),
                                  painter: _UsageChartPainter(
                                    days: widget.days,
                                    providers: providerList,
                                    maxTotal: maxDayTotal,
                                    barWidth: barWidth,
                                    gap: gap,
                                    selectedDayIndex: selectedIndex,
                                    isDark:
                                        Theme.of(context).brightness ==
                                        Brightness.dark,
                                  ),
                                ),
                                if (selectedIndex != null &&
                                    selectedIndex >= 0 &&
                                    selectedIndex < widget.days.length)
                                  _UsageDetailBubble(
                                    day: widget.days[selectedIndex],
                                    providers: providerList,
                                    barLeft:
                                        selectedIndex * (barWidth + gap) +
                                        barWidth / 2,
                                    chartWidth: chartWidth,
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                    final scrollView = Listener(
                      onPointerSignal: _handlePointerSignal,
                      onPointerMove: _handlePointerMove,
                      child: SingleChildScrollView(
                        key: const ValueKey('stats-usage-chart-scroll'),
                        controller: _scrollController,
                        scrollDirection: Axis.horizontal,
                        reverse: true,
                        child: Align(
                          alignment: Alignment.bottomLeft,
                          child: chart,
                        ),
                      ),
                    );
                    return ScrollConfiguration(
                      behavior: ScrollConfiguration.of(context).copyWith(
                        dragDevices: {
                          PointerDeviceKind.touch,
                          PointerDeviceKind.mouse,
                          PointerDeviceKind.trackpad,
                          PointerDeviceKind.stylus,
                        },
                      ),
                      child: scrollView,
                    );
                  },
                ),
        ),
        if (providerList.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 6,
            children: [
              for (var i = 0; i < providerList.length; i++)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 9,
                      height: 9,
                      decoration: BoxDecoration(
                        color: _providerColor(context, i),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      providerList[i],
                      style: TextStyle(
                        color: cs.onSurface.withValues(alpha: 0.62),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ],
    );
  }

  void _selectDayAt(
    Offset position, {
    required double barWidth,
    required double gap,
  }) {
    final nextIndex = _dayIndexAt(
      position.dx,
      daysLength: widget.days.length,
      barWidth: barWidth,
      gap: gap,
    );
    if (nextIndex != null && !_hasDayDetailTokens(widget.days[nextIndex])) {
      if (_selectedDayIndex == null) return;
      setState(() => _selectedDayIndex = null);
      return;
    }
    if (_selectedDayIndex == nextIndex) return;
    setState(() => _selectedDayIndex = nextIndex);
  }

  void _handlePointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent || !_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.maxScrollExtent <= position.minScrollExtent) return;
    GestureBinding.instance.pointerSignalResolver.register(event, (
      PointerSignalEvent resolvedEvent,
    ) {
      if (resolvedEvent is! PointerScrollEvent ||
          !_scrollController.hasClients) {
        return;
      }
      final position = _scrollController.position;
      if (position.maxScrollExtent <= position.minScrollExtent) return;
      final scrollDelta =
          resolvedEvent.scrollDelta.dx.abs() >
              resolvedEvent.scrollDelta.dy.abs()
          ? resolvedEvent.scrollDelta.dx
          : resolvedEvent.scrollDelta.dy;
      if (scrollDelta == 0) return;
      final nextOffset = (_scrollController.offset + scrollDelta).clamp(
        position.minScrollExtent,
        position.maxScrollExtent,
      );
      if (nextOffset == _scrollController.offset) return;
      _scrollController.jumpTo(nextOffset);
    });
  }

  void _handlePointerMove(PointerMoveEvent event) {
    if (event.kind != PointerDeviceKind.mouse ||
        event.buttons & kPrimaryMouseButton == 0 ||
        !_scrollController.hasClients) {
      return;
    }
    _scrollByDragDelta(event.delta.dx);
  }

  void _handleHorizontalDrag(double delta) {
    if (delta == 0 || !_scrollController.hasClients) return;
    _scrollByDragDelta(delta);
  }

  void _scrollByDragDelta(double delta) {
    final position = _scrollController.position;
    final direction = position.axisDirection == AxisDirection.left ? 1.0 : -1.0;
    final baseOffset = _dragStartOffset ?? _scrollController.offset;
    final nextOffset = (baseOffset + delta * direction).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    if (nextOffset == _scrollController.offset) return;
    _scrollController.jumpTo(nextOffset);
    _dragStartOffset = nextOffset;
  }
}

int? _dayIndexAt(
  double dx, {
  required int daysLength,
  required double barWidth,
  required double gap,
}) {
  if (daysLength <= 0 || dx < 0) return null;
  final slot = barWidth + gap;
  final index = (dx / slot).floor();
  if (index < 0 || index >= daysLength) return null;

  final slotStart = index * slot;
  final hitStart = (slotStart - gap / 2).clamp(0.0, double.infinity);
  final hitEnd = slotStart + barWidth + gap / 2;
  if (dx < hitStart || dx > hitEnd) return null;
  return index;
}

class _UsageChartPainter extends CustomPainter {
  const _UsageChartPainter({
    required this.days,
    required this.providers,
    required this.maxTotal,
    required this.barWidth,
    required this.gap,
    required this.selectedDayIndex,
    required this.isDark,
  });

  final List<StatsTrendDay> days;
  final List<String> providers;
  final int maxTotal;
  final double barWidth;
  final double gap;
  final int? selectedDayIndex;
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    final baselinePaint = Paint()
      ..color = isDark
          ? Colors.white.withValues(alpha: 0.08)
          : const Color(0xFFE2E5E9);
    final baselineTop = size.height - 3;
    for (var i = 0; i < days.length; i++) {
      final x = i * (barWidth + gap);
      final selected = selectedDayIndex == i;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, baselineTop, barWidth, 3),
          const Radius.circular(2),
        ),
        baselinePaint,
      );

      final total = days[i].providerTokens.values.fold<int>(
        0,
        (sum, bucket) => sum + _bucketWeight(bucket),
      );
      if (total <= 0 || maxTotal <= 0) continue;

      final barHeight = (size.height * total / maxTotal)
          .clamp(8.0, size.height)
          .toDouble();
      final barRect = Rect.fromLTWH(
        x,
        size.height - barHeight,
        barWidth,
        barHeight,
      );
      canvas.save();
      canvas.clipRRect(
        RRect.fromRectAndRadius(barRect, const Radius.circular(4)),
      );

      var segmentBottom = size.height;
      for (
        var providerIndex = 0;
        providerIndex < providers.length;
        providerIndex++
      ) {
        final weight = _bucketWeight(
          days[i].providerTokens[providers[providerIndex]],
        );
        if (weight <= 0) continue;
        final segmentHeight = barHeight * weight / total;
        final segmentTop = segmentBottom - segmentHeight;
        final paint = Paint()
          ..color = _providerColorForIndex(isDark, providerIndex);
        canvas.drawRect(
          Rect.fromLTWH(x, segmentTop, barWidth, segmentHeight),
          paint,
        );
        segmentBottom = segmentTop;
      }
      canvas.restore();

      if (selected) {
        final selectedPaint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..color = isDark
              ? Colors.white.withValues(alpha: 0.72)
              : Colors.black.withValues(alpha: 0.46);
        canvas.drawRRect(
          RRect.fromRectAndRadius(barRect.inflate(2), const Radius.circular(5)),
          selectedPaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _UsageChartPainter oldDelegate) {
    return oldDelegate.days != days ||
        oldDelegate.providers != providers ||
        oldDelegate.maxTotal != maxTotal ||
        oldDelegate.barWidth != barWidth ||
        oldDelegate.gap != gap ||
        oldDelegate.selectedDayIndex != selectedDayIndex ||
        oldDelegate.isDark != isDark;
  }
}

class _UsageDetailBubble extends StatelessWidget {
  const _UsageDetailBubble({
    required this.day,
    required this.providers,
    required this.barLeft,
    required this.chartWidth,
  });

  final StatsTrendDay day;
  final List<String> providers;
  final double barLeft;
  final double chartWidth;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final maxLeft = (chartWidth - _usageDetailBubbleWidth).clamp(
      0.0,
      double.infinity,
    );
    final left = (barLeft - _usageDetailBubbleWidth / 2).clamp(0.0, maxLeft);
    final providerRows = <(int, String, StatsTokenBucket)>[];
    for (var i = 0; i < providers.length; i++) {
      final bucket = day.providerTokens[providers[i]];
      if (bucket != null && _hasDetailTokens(bucket)) {
        providerRows.add((i, providers[i], bucket));
      }
    }
    if (providerRows.isEmpty) return const SizedBox.shrink();

    return Positioned(
      left: left,
      top: _usageDetailBubbleTop,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF24272D) : const Color(0xFFF7F8FA),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.26 : 0.12),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: SizedBox(
          width: _usageDetailBubbleWidth,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 11),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  DateFormat('yyyy-MM-dd').format(day.date),
                  style: TextStyle(
                    color: cs.onSurface.withValues(alpha: 0.82),
                    fontSize: 12,
                    fontWeight: AppFontWeights.emphasis,
                  ),
                ),
                const SizedBox(height: 8),
                for (final (providerIndex, provider, bucket) in providerRows)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 7),
                    child: _UsageProviderDetailRow(
                      color: _providerColor(context, providerIndex),
                      provider: provider,
                      bucket: bucket,
                      l10n: l10n,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _UsageProviderDetailRow extends StatelessWidget {
  const _UsageProviderDetailRow({
    required this.color,
    required this.provider,
    required this.bucket,
    required this.l10n,
  });

  final Color color;
  final String provider;
  final StatsTokenBucket bucket;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(width: 7),
            Expanded(
              child: Text(
                provider,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: cs.onSurface.withValues(alpha: 0.86),
                  fontSize: 12,
                  fontWeight: AppFontWeights.emphasis,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              l10n.tokenDetailTotalTokens(_detailTokenTotal(bucket)),
              style: TextStyle(
                color: cs.onSurface.withValues(alpha: 0.7),
                fontSize: 11,
                fontWeight: AppFontWeights.semibold,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

int _bucketWeight(StatsTokenBucket? bucket) {
  if (bucket == null) return 0;
  if (bucket.chartWeight > 0) return bucket.chartWeight;
  return 1;
}

bool _hasDayDetailTokens(StatsTrendDay day) {
  return day.providerTokens.values.any(_hasDetailTokens);
}

bool _hasDetailTokens(StatsTokenBucket bucket) {
  return _detailTokenTotal(bucket) > 0;
}

int _detailTokenTotal(StatsTokenBucket bucket) {
  return bucket.totalTokens;
}

Color _providerColor(BuildContext context, int index) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  return _providerColorForIndex(isDark, index);
}

Color _providerColorForIndex(bool isDark, int index) {
  final palette = isDark
      ? [
          const Color(0xFF60A5FA),
          const Color(0xFF5EEAD4),
          const Color(0xFFFB923C),
          const Color(0xFFA78BFA),
          const Color(0xFFFB7185),
          const Color(0xFF86EFAC),
          const Color(0xFFFACC15),
          const Color(0xFF67E8F9),
        ]
      : [
          const Color(0xFF2563EB),
          const Color(0xFF0F8F83),
          const Color(0xFFEA580C),
          const Color(0xFF8B5CF6),
          const Color(0xFFE11D48),
          const Color(0xFF16A34A),
          const Color(0xFFCA8A04),
          const Color(0xFF0891B2),
        ];
  return palette[index % palette.length];
}
