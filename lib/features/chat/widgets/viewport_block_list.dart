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
    this.storageId,
    this.revealIndex,
  });

  final int itemCount;
  final Widget Function(BuildContext context, int index) itemBuilder;
  final Object Function(int index) itemKey;
  final double Function(int index, double width) estimateExtent;
  final Object structureToken;
  final bool Function(int index)? keepAlive;
  final double spacing;
  final int threshold;

  /// Identifies the measured extents kept in the enclosing [PageStorage].
  /// Without it extents live only as long as this widget's state.
  final Object? storageId;

  /// Keep a navigation target mounted while its exact text geometry is read.
  final int? revealIndex;

  @override
  State<ViewportBlockList> createState() => _ViewportBlockListState();
}

class _ViewportBlockListState extends State<ViewportBlockList> {
  final _boxKey = GlobalKey();
  final _extents = _ExtentIndex();
  final _measurements = <int, double>{};
  final _mountedIndices = <int>{};
  Map<Object, double>? _storedExtents;
  PageStorageBucket? _storage;
  ScrollPosition? _position;
  double? _width;
  double? _textScale;
  ({Object key, double offset})? _pendingAnchor;
  WeakReference<_ViewportBlockListState>? _descendantAnchor;
  int _first = 0, _last = 0;
  bool _scheduled = false;

  bool get _anchoredByDescendant {
    final descendant = _descendantAnchor?.target;
    return descendant != null &&
        descendant.mounted &&
        descendant._pendingAnchor != null;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final position = Scrollable.maybeOf(context)?.position;
    if (!identical(position, _position)) {
      _position?.removeListener(_onScroll);
      _position = position;
      _pendingAnchor = null;
      _position?.addListener(_onScroll);
    }
    final scale = MediaQuery.textScalerOf(context).scale(1);
    if (_textScale != scale) {
      _preserveReadingAnchor(widget);
      _textScale = scale;
      _width = null;
    }
    _syncStorage();
    _scheduleRefresh();
  }

  void _syncStorage({bool storageIdChanged = false}) {
    final storage = PageStorage.maybeOf(context);
    if (!storageIdChanged && identical(storage, _storage)) return;
    _storage = storage;
    _storedExtents = _readStoredExtents();
    _extents.clear();
    _measurements.clear();
  }

  /// Extents outlive this state in the enclosing [PageStorage], so a rebuilt
  /// list starts from real heights instead of falling back to estimates.
  Map<Object, double>? _readStoredExtents() {
    final storageId = widget.storageId;
    final storage = _storage;
    if (storageId == null || storage == null) return null;
    final stored = storage.readState(context, identifier: storageId);
    if (stored is Map<Object, double>) return stored;
    final created = <Object, double>{};
    storage.writeState(context, created, identifier: storageId);
    return created;
  }

  /// Heights are only valid for the width and text scale they were measured
  /// at, so both are part of the key.
  double? _storedExtent(int index, double width) {
    final stored = _storedExtents;
    final scale = _textScale;
    if (stored == null || scale == null) return null;
    return stored[(widget.itemKey(index), width, scale)];
  }

  void _storeExtent(int index, double extent) {
    final stored = _storedExtents;
    final width = _width;
    final scale = _textScale;
    if (stored == null || width == null || scale == null) return;
    stored[(widget.itemKey(index), width, scale)] = extent;
  }

  void _pruneStoredExtents({Set<Object>? itemKeys}) {
    final width = _width;
    final scale = _textScale;
    _storedExtents?.removeWhere((key, _) {
      if (key is! (Object, double, double)) return true;
      // A newly mounted folded list has no layout width yet. Keep its cached
      // dimensions until LayoutBuilder can check the actual constraints.
      return (width != null && key.$2 != width) ||
          (scale != null && key.$3 != scale) ||
          (itemKeys != null && !itemKeys.contains(key.$1));
    });
  }

  @override
  void didUpdateWidget(ViewportBlockList oldWidget) {
    super.didUpdateWidget(oldWidget);
    // PageStorage is not inherited: replacing its bucket does not trigger
    // didChangeDependencies. Switch caches before pruning or measuring a new
    // message version, even when it keeps the same storageId.
    _syncStorage(storageIdChanged: oldWidget.storageId != widget.storageId);
    if (oldWidget.structureToken != widget.structureToken) {
      _preserveReadingAnchor(oldWidget);
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
      final width = _width;
      for (var i = 0; i < widget.itemCount; i++) {
        if (retainedKeys.contains(widget.itemKey(i))) _mountedIndices.add(i);
        _extents.add(
          previous[widget.itemKey(i)] ??
              (width == null ? null : _storedExtent(i, width)) ??
              widget.estimateExtent(i, width ?? 400) + widget.spacing,
        );
      }
      _pruneStoredExtents(
        itemKeys: {
          for (var i = 0; i < widget.itemCount; i++) widget.itemKey(i),
        },
      );
      _measurements.clear();
    }
    _scheduleRefresh();
  }

  @override
  void dispose() {
    _pendingAnchor = null;
    _position?.removeListener(_onScroll);
    super.dispose();
  }

  void _onScroll() {
    if (_position?.isScrollingNotifier.value ?? false) {
      _pendingAnchor = null;
    }
    _scheduleRefresh();
  }

  ({double origin, double start, double height})? _viewportGeometry() {
    final position = _position;
    final box = _boxKey.currentContext?.findRenderObject();
    if (position == null ||
        !position.hasPixels ||
        box is! RenderBox ||
        !box.hasSize) {
      return null;
    }
    final viewport = RenderAbstractViewport.maybeOf(box);
    if (viewport == null) return null;
    final origin = viewport.getOffsetToReveal(box, 0).offset;
    return (
      origin: origin,
      start: position.pixels - origin,
      height: box.size.height,
    );
  }

  void _preserveReadingAnchor(ViewportBlockList source) {
    if (_pendingAnchor != null ||
        _anchoredByDescendant ||
        _extents.length == 0) {
      return;
    }
    final geometry = _viewportGeometry();
    // An offscreen nested list must leave positioning to its outer list.
    if (geometry == null ||
        geometry.start < 0 ||
        geometry.start >= geometry.height) {
      return;
    }
    final position = _position!;
    // Bottom-following belongs to the outer scrollable, not a reading anchor.
    if (position.hasContentDimensions &&
        position.pixels >= position.maxScrollExtent - .5) {
      return;
    }
    final index = _extents.indexAt(geometry.start);
    if (index >= source.itemCount) return;
    _pendingAnchor = (
      key: source.itemKey(index),
      offset: geometry.start - _extents.prefix(index),
    );
    // Both lists can invalidate in the same layout. Only the innermost
    // reading anchor owns the intra-item offset while their sizes settle.
    context.visitAncestorElements((element) {
      if (element is StatefulElement) {
        final ancestor = element.state;
        if (ancestor is _ViewportBlockListState &&
            identical(ancestor._position, _position)) {
          ancestor._pendingAnchor = null;
          ancestor._descendantAnchor = WeakReference(this);
        }
      }
      return true;
    });
  }

  void _scheduleRefresh() {
    if (_scheduled) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (!mounted || _extents.length == 0) return;
      final position = _position;
      final geometry = _viewportGeometry();
      if (position == null || geometry == null) return;
      var start = geometry.start;
      int? pendingIndex;
      final pending = _pendingAnchor;
      if (pending != null) {
        for (var i = 0; i < widget.itemCount; i++) {
          if (widget.itemKey(i) == pending.key) {
            pendingIndex = i;
            break;
          }
        }
        if (pendingIndex == null) _pendingAnchor = null;
      }
      final readingInside =
          !_anchoredByDescendant && start >= 0 && start < geometry.height;
      final anchor = _extents.indexAt(math.max(0, start));
      final anchorBefore = _extents.prefix(anchor);
      var sizeChanged = false;
      for (final entry in _measurements.entries) {
        if (entry.key >= _extents.length) continue;
        _storeExtent(entry.key, entry.value);
        if ((_extents.value(entry.key) - entry.value).abs() < .5) continue;
        _extents.set(entry.key, entry.value);
        sizeChanged = true;
      }
      _measurements.clear();
      // Changes above the currently read block should not move its text.
      final correction = pendingIndex != null
          ? geometry.origin +
                _extents.prefix(pendingIndex) +
                pending!.offset -
                position.pixels
          : readingInside
          ? _extents.prefix(anchor) - anchorBefore
          : 0.0;
      final positionChanged = correction.abs() >= .5;
      if (positionChanged) {
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
      final rangeChanged = first != _first || last != _last;
      if (!positionChanged && !rangeChanged && !sizeChanged) {
        _pendingAnchor = null;
      }
      if (rangeChanged || sizeChanged || positionChanged) {
        setState(() {
          _first = first;
          _last = last;
        });
        if (sizeChanged || positionChanged) _scheduleRefresh();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.itemCount <= widget.threshold ||
        _position == null ||
        ExportCaptureScope.of(context)) {
      _pendingAnchor = null;
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
          _preserveReadingAnchor(widget);
          _width = constraints.maxWidth;
          _pruneStoredExtents();
          _extents.clear();
          _measurements.clear();
        }
        while (_extents.length > widget.itemCount) {
          _extents.removeLast();
        }
        while (_extents.length < widget.itemCount) {
          final i = _extents.length;
          _extents.add(
            _storedExtent(i, constraints.maxWidth) ??
                widget.estimateExtent(i, constraints.maxWidth) + widget.spacing,
          );
        }
        if (_last == 0) {
          _last = math.min(widget.itemCount, 24);
        }
        final indices = <int>{
          if (widget.revealIndex case final index?
              when index >= 0 && index < widget.itemCount)
            index,
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
