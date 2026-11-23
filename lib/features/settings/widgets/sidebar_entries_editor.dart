import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/models/sidebar_layout.dart';
import '../../../icons/lucide_adapter.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/segmented_tabs.dart';
import '../../../shared/widgets/sidebar_entry_labels.dart';
import '../../../theme/app_font_weights.dart';
import '../../../theme/app_semantic_colors.dart';

class SidebarEntriesEditor extends StatelessWidget {
  const SidebarEntriesEditor({
    super.key,
    required this.entries,
    required this.onChanged,
    this.mobileStyle,
  });

  final Map<SidebarEntry, SidebarVisibility> entries;
  final ValueChanged<Map<SidebarEntry, SidebarVisibility>> onChanged;
  final SidebarStyle? mobileStyle;

  String _location(SidebarEntry entry, AppLocalizations l10n) {
    return switch (entries[entry]!) {
      SidebarVisibility.more => l10n.sidebarLocationMore,
      SidebarVisibility.hidden => l10n.sidebarLocationHidden,
      SidebarVisibility.show => switch (mobileStyle) {
        SidebarStyle.list => l10n.sidebarLocationEntries,
        _ when entry == SidebarEntry.history => l10n.sidebarLocationSearch,
        SidebarStyle.icons => l10n.sidebarLocationUserBar,
        null => l10n.sidebarLocationRail,
      },
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final scaler = MediaQuery.textScalerOf(context);
    final labels = [
      for (final value in SidebarVisibility.values) value.label(l10n),
    ];
    double controlWidth = 0;
    final measure = TextPainter(
      textDirection: Directionality.of(context),
      textScaler: scaler,
      maxLines: 1,
    );
    for (final label in labels) {
      measure.text = TextSpan(
        text: label,
        style: TextStyle(fontSize: 12, fontWeight: AppFontWeights.semibold),
      );
      measure.layout();
      controlWidth = math.max(controlWidth, measure.width);
    }
    measure.dispose();
    // Three equal segments with 4px padding each, 2px gaps and a 3px shell.
    controlWidth = math.max(126, (controlWidth * 3 + 36).ceilToDouble());
    final controlHeight = math.max(30.0, scaler.scale(12) * 1.2 + 10);
    final textHeight = math.max(
      40.0,
      scaler.scale(14) * 1.3 + scaler.scale(11) * 1.3,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth - 16;
        final stackControl = width < controlWidth + 138;
        return SidebarReorderList<SidebarEntry>(
          items: entries.keys.toList(),
          itemExtent:
              (stackControl
                  ? textHeight + 4 + controlHeight
                  : math.max(textHeight, controlHeight)) +
              12,
          onMove: (entry, target) {
            final order = entries.keys.toList()..remove(entry);
            order.insert(target, entry);
            onChanged({for (final id in order) id: entries[id]!});
          },
          itemBuilder: (context, entry, handle) {
            final title = Row(
              children: [
                handle,
                Icon(entry.icon, size: 18, color: cs.onSurfaceVariant),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.label(l10n),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        _location(entry, l10n),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
            final control = SizedBox(
              width: math.min(controlWidth, width),
              child: SegmentedTabs(
                key: ValueKey(('sidebar-visibility', entry)),
                height: controlHeight,
                compact: true,
                expand: width >= controlWidth,
                radioGroup: true,
                backgroundColor: context.appColors.surfaceFill,
                tabs: [for (final label in labels) SegmentedTab(label: label)],
                index: entries[entry]!.index,
                onChanged: (index) => onChanged({
                  ...entries,
                  entry: SidebarVisibility.values[index],
                }),
              ),
            );
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: stackControl
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [title, const SizedBox(height: 4), control],
                    )
                  : Row(
                      children: [
                        Expanded(child: title),
                        const SizedBox(width: 8),
                        control,
                      ],
                    ),
            );
          },
        );
      },
    );
  }
}

typedef SidebarReorderItemBuilder<T> =
    Widget Function(BuildContext, T, Widget dragHandle);

class SidebarReorderList<T extends Enum> extends StatefulWidget {
  const SidebarReorderList({
    super.key,
    required this.items,
    required this.itemExtent,
    required this.onMove,
    required this.itemBuilder,
    this.separator,
  });

  final List<T> items;
  final double itemExtent;
  final void Function(T item, int target) onMove;
  final SidebarReorderItemBuilder<T> itemBuilder;
  final T? separator;

  @override
  State<SidebarReorderList<T>> createState() => _SidebarReorderListState<T>();
}

class _SidebarReorderListState<T extends Enum>
    extends State<SidebarReorderList<T>> {
  T? _dragged;
  double _dragOffset = 0;

  @override
  void initState() {
    super.initState();
    FocusManager.instance.addEarlyKeyEventHandler(_cancelWithEscape);
  }

  @override
  void dispose() {
    FocusManager.instance.removeEarlyKeyEventHandler(_cancelWithEscape);
    super.dispose();
  }

  KeyEventResult _cancelWithEscape(KeyEvent event) {
    final dragged = _dragged;
    if (dragged != null &&
        event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.escape) {
      _endDrag(dragged);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  void didUpdateWidget(covariant SidebarReorderList<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!listEquals(oldWidget.items, widget.items) ||
        oldWidget.itemExtent != widget.itemExtent) {
      _dragged = null;
      _dragOffset = 0;
    }
  }

  void _endDrag(T item, {int? target}) {
    if (_dragged != item) return;
    setState(() {
      _dragged = null;
      _dragOffset = 0;
    });
    if (target != null && target != widget.items.indexOf(item)) {
      widget.onMove(item, target);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final items = widget.items;
    if (items.isEmpty) return const SizedBox.shrink();
    final extent = widget.itemExtent;
    final from = _dragged == null ? 0 : items.indexOf(_dragged!);
    final target = _dragged == null
        ? from
        : (from + _dragOffset / extent).round().clamp(0, items.length - 1);
    final offsetIndicator = _dragged != null && target != from;

    Widget row(T item) {
      final index = items.indexOf(item);
      final lifted = _dragged == item;
      final collapsed = _dragged != null && index > from && !lifted;
      final position = collapsed ? index - 1 : index;
      final distance = position < target
          ? target - position - 1
          : position - target;
      final shift = offsetIndicator && !lifted
          ? (position < target ? -8 : 8) * math.pow(.7, distance).toDouble()
          : 0.0;
      final delay = offsetIndicator && !lifted ? 24 * distance : 0;
      final handle = item == widget.separator
          ? const SizedBox(width: 32)
          : Focus(
              onKeyEvent: (_, event) {
                if (event is! KeyDownEvent || _dragged != null) {
                  return KeyEventResult.ignored;
                }
                final delta = switch (event.logicalKey) {
                  LogicalKeyboardKey.arrowUp => -1,
                  LogicalKeyboardKey.arrowDown => 1,
                  _ => 0,
                };
                if (delta == 0) return KeyEventResult.ignored;
                final destination = index + delta;
                if (destination >= 0 && destination < items.length) {
                  widget.onMove(item, destination);
                }
                return KeyEventResult.handled;
              },
              child: Builder(
                builder: (context) {
                  final focus = Focus.of(context);
                  return Listener(
                    onPointerCancel: (_) => _endDrag(item),
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      dragStartBehavior: DragStartBehavior.down,
                      onTap: focus.requestFocus,
                      onVerticalDragStart: (_) {
                        if (_dragged != null) return;
                        focus.requestFocus();
                        setState(() => _dragged = item);
                      },
                      onVerticalDragUpdate: (details) {
                        if (_dragged != item) return;
                        setState(() {
                          _dragOffset = (_dragOffset + details.delta.dy).clamp(
                            -(index + .5) * extent,
                            (items.length - index - .5) * extent,
                          );
                        });
                      },
                      onVerticalDragEnd: (_) {
                        // A move and release can arrive before the next frame.
                        final destination = (index + _dragOffset / extent)
                            .round()
                            .clamp(0, items.length - 1);
                        _endDrag(item, target: destination);
                      },
                      onVerticalDragCancel: () => _endDrag(item),
                      child: Semantics(
                        label: l10n.sidebarReorderHandle,
                        child: MouseRegion(
                          cursor: lifted
                              ? SystemMouseCursors.grabbing
                              : SystemMouseCursors.grab,
                          child: Container(
                            alignment: Alignment.center,
                            width: 32,
                            height: 40,
                            decoration: focus.hasFocus
                                ? BoxDecoration(
                                    border: Border.all(color: cs.primary),
                                    borderRadius: BorderRadius.circular(8),
                                  )
                                : null,
                            child: Icon(
                              Lucide.GripVertical,
                              size: 16,
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            );
      return AnimatedPositioned(
        key: ValueKey(item),
        top: lifted ? index * extent + _dragOffset : position * extent + shift,
        left: 0,
        right: 0,
        height: extent,
        duration: reduceMotion || lifted
            ? Duration.zero
            : Duration(milliseconds: 220 + delay),
        curve: Interval(
          delay / (220 + delay),
          1,
          curve: const Cubic(.32, .72, 0, 1),
        ),
        child: Transform.translate(
          offset: Offset(lifted ? 14 : 0, 0),
          child: Transform.scale(
            scale: lifted ? .9 : 1,
            child: Material(
              color: lifted
                  ? context.appColors.surfaceCard
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(14),
              child: widget.itemBuilder(context, item, handle),
            ),
          ),
        ),
      );
    }

    return SizedBox(
      height: extent * items.length,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (final item in items)
            if (item != _dragged) row(item),
          if (offsetIndicator)
            Positioned(
              key: const ValueKey('sidebar-drop-indicator'),
              top: target * extent,
              left: 10,
              right: 10,
              height: 2,
              child: IgnorePointer(
                child: ColoredBox(color: cs.onSurface.withValues(alpha: .15)),
              ),
            ),
          if (_dragged != null) row(_dragged!),
        ],
      ),
    );
  }
}
