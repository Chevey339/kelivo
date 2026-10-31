import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../../shared/widgets/export_capture_scope.dart';

/// Virtualizes blocks inside a message using the *outer* scroll position.
/// There is no nested Scrollable or shrink-wrapping viewport. Only the visible
/// range and a small cache area own element/render subtrees; measured extents
/// remain as numbers when those subtrees are released.
class ViewportBlockList extends StatefulWidget {
  const ViewportBlockList({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    required this.itemKey,
    required this.estimateExtent,
    required this.structureToken,
    this.keepAlive,
    this.spacing = 0,
    this.threshold = 24,
  });

  final int itemCount;
  final Widget Function(BuildContext context, int index) itemBuilder;
  final Object Function(int index) itemKey;
  final double Function(int index, double width) estimateExtent;
  final Object structureToken;
  final bool Function(int index)? keepAlive;
  final double spacing;
  final int threshold;

  @override
  State<ViewportBlockList> createState() => _ViewportBlockListState();
}

class _ViewportBlockListState extends State<ViewportBlockList> {
  final _boxKey = GlobalKey();
  final _extents = _ExtentIndex();
  final _measurements = <int, double>{};
  final _mountedIndices = <int>{};
  ScrollPosition? _position;
  double? _width;
  double? _textScale;
  int _first = 0, _last = 0;
  bool _scheduled = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final position = Scrollable.maybeOf(context)?.position;
    if (!identical(position, _position)) {
      _position?.removeListener(_scheduleRefresh);
      _position = position;
      _position?.addListener(_scheduleRefresh);
    }
    final scale = MediaQuery.textScalerOf(context).scale(1);
    if (_textScale != scale) {
      _textScale = scale;
      _width = null;
    }
    _scheduleRefresh();
  }

  @override
  void didUpdateWidget(ViewportBlockList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.structureToken != widget.structureToken) {
      // A changed shape may insert/reorder blocks. Transfer only measured
      // extents with the same stable identity; payloads are never retained.
      final previous = {
        for (var i = 0; i < math.min(_extents.length, oldWidget.itemCount); i++)
          oldWidget.itemKey(i): _extents.value(i),
      };
      final retainedKeys = {
        for (final i in _mountedIndices)
          if (i < oldWidget.itemCount) oldWidget.itemKey(i),
      };
      _extents.clear();
      _mountedIndices.clear();
      for (var i = 0; i < widget.itemCount; i++) {
        if (retainedKeys.contains(widget.itemKey(i))) _mountedIndices.add(i);
        _extents.add(
          previous[widget.itemKey(i)] ??
              widget.estimateExtent(i, _width ?? 400) + widget.spacing,
        );
      }
      _measurements.clear();
    }
    _scheduleRefresh();
  }

  @override
  void dispose() {
    _position?.removeListener(_scheduleRefresh);
    super.dispose();
  }

  void _scheduleRefresh() {
    if (_scheduled) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (!mounted || _extents.length == 0) return;
      final position = _position;
      final box = _boxKey.currentContext?.findRenderObject();
      if (position == null ||
          !position.hasPixels ||
          box is! RenderBox ||
          !box.hasSize) {
        return;
      }
      final viewport = RenderAbstractViewport.maybeOf(box);
      if (viewport == null) return;
      final origin = viewport.getOffsetToReveal(box, 0).offset;
      var start = position.pixels - origin;
      final readingInside = start > 0 && start < _extents.total;
      final anchor = _extents.indexAt(math.max(0, start));
      final anchorBefore = _extents.prefix(anchor);
      var sizeChanged = false;
      for (final entry in _measurements.entries) {
        if (entry.key >= _extents.length) continue;
        if ((_extents.value(entry.key) - entry.value).abs() < .5) continue;
        _extents.set(entry.key, entry.value);
        sizeChanged = true;
      }
      _measurements.clear();
      // Changes above the currently read block should not move its text.
      final correction = _extents.prefix(anchor) - anchorBefore;
      if (correction.abs() >= .5 && readingInside) {
        position.correctBy(correction);
        start += correction;
      }
      final cache = math.max(400.0, position.viewportDimension);
      final first = _extents.indexAt(math.max(0, start - cache));
      final last =
          (_extents.indexAt(
                    math.max(0, start + position.viewportDimension + cache),
                  ) +
                  1)
              .clamp(first, widget.itemCount);
      if (first != _first || last != _last || sizeChanged) {
        setState(() {
          _first = first;
          _last = last;
        });
        if (sizeChanged) _scheduleRefresh();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.itemCount <= widget.threshold ||
        _position == null ||
        ExportCaptureScope.of(context)) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < widget.itemCount; i++) ...[
            if (i > 0) SizedBox(height: widget.spacing),
            KeyedSubtree(
              key: ValueKey(widget.itemKey(i)),
              child: widget.itemBuilder(context, i),
            ),
          ],
        ],
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        if (_width != constraints.maxWidth) {
          _width = constraints.maxWidth;
          _extents.clear();
          _measurements.clear();
        }
        while (_extents.length > widget.itemCount) {
          _extents.removeLast();
        }
        while (_extents.length < widget.itemCount) {
          final i = _extents.length;
          _extents.add(
            widget.estimateExtent(i, constraints.maxWidth) + widget.spacing,
          );
        }
        if (_last == 0) {
          _last = math.min(widget.itemCount, 24);
        }
        final indices = <int>{
          for (final index in _mountedIndices)
            if (index < widget.itemCount &&
                (widget.keepAlive?.call(index) ?? false))
              index,
          for (var i = _first; i < math.min(_last, widget.itemCount); i++) i,
        }.toList()..sort();
        _mountedIndices
          ..clear()
          ..addAll(indices);
        _scheduleRefresh();
        return SizedBox(
          key: _boxKey,
          width: constraints.maxWidth,
          height: math.max(0, _extents.total - widget.spacing),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              for (final index in indices)
                Positioned(
                  key: ValueKey(widget.itemKey(index)),
                  left: 0,
                  right: 0,
                  top: _extents.prefix(index),
                  child: _MeasureBlock(
                    onSize: (size) {
                      _measurements[index] = size.height + widget.spacing;
                      _scheduleRefresh();
                    },
                    child: widget.itemBuilder(context, index),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Fenwick tree: visible-range lookup and size corrections are logarithmic.
class _ExtentIndex {
  final _values = <double>[];
  final _tree = <double>[0];
  int get length => _values.length;
  double get total => prefix(length);
  double value(int index) => _values[index];
  void clear() {
    _values.clear();
    _tree
      ..clear()
      ..add(0);
  }

  void removeLast() {
    _values.removeLast();
    _tree.removeLast();
  }

  void add(double value) {
    final n = length + 1;
    final preceding = prefix(n - 1) - prefix(n - (n & -n));
    _values.add(value);
    _tree.add(preceding + value);
  }

  void set(int index, double value) {
    final delta = value - _values[index];
    _values[index] = value;
    for (var i = index + 1; i < _tree.length; i += i & -i) {
      _tree[i] += delta;
    }
  }

  double prefix(int count) {
    var result = 0.0;
    for (var i = count; i > 0; i -= i & -i) {
      result += _tree[i];
    }
    return result;
  }

  int indexAt(double offset) {
    var index = 0;
    var sum = 0.0;
    var bit = 1;
    while (bit <= length) {
      bit <<= 1;
    }
    for (bit >>= 1; bit > 0; bit >>= 1) {
      final next = index + bit;
      if (next <= length && sum + _tree[next] <= offset) {
        index = next;
        sum += _tree[next];
      }
    }
    return index.clamp(0, math.max(0, length - 1));
  }
}

class _MeasureBlock extends SingleChildRenderObjectWidget {
  const _MeasureBlock({required this.onSize, required super.child});
  final ValueChanged<Size> onSize;
  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderMeasureBlock(onSize);
  @override
  void updateRenderObject(
    BuildContext context,
    _RenderMeasureBlock renderObject,
  ) {
    renderObject.onSize = onSize;
    renderObject
      .._reported = null
      ..markNeedsLayout();
  }
}

class _RenderMeasureBlock extends RenderProxyBox {
  _RenderMeasureBlock(this.onSize);
  ValueChanged<Size> onSize;
  Size? _reported;
  @override
  void performLayout() {
    super.performLayout();
    if (_reported == size) return;
    _reported = size;
    onSize(size);
  }
}
