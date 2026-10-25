import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Joins a non-text inline widget to its surrounding selection, reporting the
/// source represented by the widget as one atomic selection unit.
class SelectableSpanAdapter extends StatelessWidget {
  const SelectableSpanAdapter({
    super.key,
    required this.selectedText,
    required this.child,
    this.mouseCursor = SystemMouseCursors.text,
  });

  final String selectedText;
  final Widget child;
  final MouseCursor mouseCursor;

  @override
  Widget build(BuildContext context) {
    final registrar = SelectionContainer.maybeOf(context);
    if (registrar == null) return child;
    return MouseRegion(
      cursor: mouseCursor,
      child: _SelectableSource(
        registrar: registrar,
        text: selectedText,
        direction: Directionality.of(context),
        color:
            DefaultSelectionStyle.of(context).selectionColor ??
            const Color(0x663F51B5),
        child: SelectionContainer.disabled(child: child),
      ),
    );
  }
}

class _SelectableSource extends SingleChildRenderObjectWidget {
  const _SelectableSource({
    required this.registrar,
    required this.text,
    required this.color,
    required this.direction,
    required super.child,
  });

  final SelectionRegistrar registrar;
  final String text;
  final Color color;
  final TextDirection direction;

  @override
  _RenderSelectableSource createRenderObject(BuildContext context) =>
      _RenderSelectableSource(text, color, direction, registrar);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderSelectableSource object,
  ) {
    object
      ..text = text
      ..direction = direction
      ..color = color
      ..registrar = registrar;
  }
}

class _RenderSelectableSource extends RenderProxyBox
    with Selectable, SelectionRegistrant {
  _RenderSelectableSource(
    this._text,
    this._color,
    this._direction,
    SelectionRegistrar registrar,
  ) {
    _geometry = SelectionGeometry(
      hasContent: _text.isNotEmpty,
      status: SelectionStatus.none,
    );
    this.registrar = registrar;
  }

  final _listeners = _SelectionNotifier();
  late SelectionGeometry _geometry;
  String _text;
  Color _color;
  TextDirection _direction;

  set direction(TextDirection value) {
    if (_direction == value) return;
    _direction = value;
    _updateGeometry(force: true);
  }

  int? _start;
  int? _end;
  LayerLink? _startHandle;
  LayerLink? _endHandle;

  set text(String value) {
    if (_text == value) return;
    _text = value;
    if (_start != null) _start = _start == 0 ? 0 : value.length;
    if (_end != null) _end = _end == 0 ? 0 : value.length;
    if (value.isEmpty) _start = _end = null;
    _updateGeometry(force: true);
  }

  set color(Color value) {
    if (_color == value) return;
    _color = value;
    markNeedsPaint();
  }

  @override
  SelectionGeometry get value => _geometry;

  @override
  int get contentLength => _text.length;

  @override
  List<Rect> get boundingBoxes => hasSize ? [Offset.zero & size] : const [];

  @override
  void addListener(VoidCallback listener) => _listeners.addListener(listener);

  @override
  void removeListener(VoidCallback listener) =>
      _listeners.removeListener(listener);

  @override
  SelectedContent? getSelectedContent() =>
      _start != null && _end != null && _start != _end
      ? SelectedContent(plainText: _text)
      : null;

  @override
  SelectedContentRange? getSelection() => _start == null || _end == null
      ? null
      : SelectedContentRange(startOffset: _start!, endOffset: _end!);

  void _updateGeometry({bool force = false}) {
    final SelectionGeometry next;
    if (_start == null || _end == null || !hasSize || _text.isEmpty) {
      next = SelectionGeometry(
        hasContent: _text.isNotEmpty,
        status: SelectionStatus.none,
      );
    } else {
      SelectionPoint point(int offset, bool start) => SelectionPoint(
        localPosition: Offset(
          (offset == 0) != (_direction == TextDirection.rtl) ? 0 : size.width,
          size.height,
        ),
        lineHeight: size.height,
        handleType: start != (_direction == TextDirection.rtl)
            ? TextSelectionHandleType.left
            : TextSelectionHandleType.right,
      );
      next = SelectionGeometry(
        hasContent: true,
        status: _start == _end
            ? SelectionStatus.collapsed
            : SelectionStatus.uncollapsed,
        startSelectionPoint: point(_start!, _start! <= _end!),
        endSelectionPoint: point(_end!, _start! > _end!),
        selectionRects: _start == _end ? const [] : [Offset.zero & size],
      );
    }
    if (next != _geometry || force) {
      _geometry = next;
      _listeners.changed();
      markNeedsPaint();
    }
  }

  @override
  void performLayout() {
    super.performLayout();
    _updateGeometry();
  }

  SelectionResult _extend({required bool forward, required bool isEnd}) {
    _start ??= forward ? 0 : _text.length;
    _end ??= _start;
    final next = forward ? _text.length : 0;
    final previous = isEnd ? _end : _start;
    if (isEnd) {
      _end = next;
    } else {
      _start = next;
    }
    return previous == next
        ? (forward ? SelectionResult.next : SelectionResult.previous)
        : SelectionResult.end;
  }

  @override
  SelectionResult dispatchSelectionEvent(SelectionEvent event) {
    if (!hasSize && event.type != SelectionEventType.clear) {
      return SelectionResult.pending;
    }
    var result = SelectionResult.none;
    switch (event.type) {
      case SelectionEventType.clear:
        _start = _end = null;
      case SelectionEventType.selectAll:
        _start = 0;
        _end = _text.length;
      case SelectionEventType.selectWord:
      case SelectionEventType.selectParagraph:
        final position = event is SelectWordSelectionEvent
            ? event.globalPosition
            : (event as SelectParagraphSelectionEvent).globalPosition;
        if ((Offset.zero & size).contains(globalToLocal(position)) ||
            (event is SelectParagraphSelectionEvent && event.absorb)) {
          _start = 0;
          _end = _text.length;
        }
      case SelectionEventType.startEdgeUpdate:
      case SelectionEventType.endEdgeUpdate:
        final position = globalToLocal(
          (event as SelectionEdgeUpdateEvent).globalPosition,
        );
        result = SelectionUtils.getResultBasedOnRect(
          Offset.zero & size,
          position,
        );
        if (_direction == TextDirection.rtl &&
            position.dy >= 0 &&
            position.dy <= size.height) {
          result = switch (result) {
            SelectionResult.previous => SelectionResult.next,
            SelectionResult.next => SelectionResult.previous,
            _ => result,
          };
        }
        final offset = switch (result) {
          SelectionResult.previous => 0,
          SelectionResult.next => _text.length,
          _ =>
            (position.dx < size.width / 2) != (_direction == TextDirection.rtl)
                ? 0
                : _text.length,
        };
        if (event.type == SelectionEventType.startEdgeUpdate) {
          _start = offset;
          _end ??= offset;
        } else {
          _end = offset;
          _start ??= offset;
        }
      case SelectionEventType.granularlyExtendSelection:
        final update = event as GranularlyExtendSelectionEvent;
        result = _extend(forward: update.forward, isEnd: update.isEnd);
      case SelectionEventType.directionallyExtendSelection:
        final update = event as DirectionallyExtendSelectionEvent;
        result = _extend(
          forward:
              update.direction == SelectionExtendDirection.forward ||
              update.direction == SelectionExtendDirection.nextLine,
          isEnd: update.isEnd,
        );
    }
    _updateGeometry();
    return result;
  }

  @override
  void pushHandleLayers(LayerLink? startHandle, LayerLink? endHandle) {
    if (_startHandle == startHandle && _endHandle == endHandle) return;
    _startHandle = startHandle;
    _endHandle = endHandle;
    if (attached) markNeedsPaint();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    super.paint(context, offset);
    if (!_geometry.hasSelection) return;
    if (_start != _end) {
      context.canvas.drawRect(
        (Offset.zero & size).shift(offset),
        Paint()..color = _color,
      );
    }
    void handle(LayerLink? link, SelectionPoint? point) {
      if (link == null || point == null) return;
      context.pushLayer(
        LeaderLayer(link: link, offset: offset + point.localPosition),
        (_, _) {},
        Offset.zero,
      );
    }

    handle(_startHandle, _geometry.startSelectionPoint);
    handle(_endHandle, _geometry.endSelectionPoint);
  }

  @override
  void dispose() {
    super.dispose();
    _listeners.dispose();
  }
}

class _SelectionNotifier extends ChangeNotifier {
  void changed() => notifyListeners();
}
