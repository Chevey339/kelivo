import 'dart:async';
import 'dart:math' show max;
import 'dart:ui';

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:terminal_view/src/core/cell.dart';
import 'package:terminal_view/src/core/buffer/cell_offset.dart';
import 'package:terminal_view/src/core/buffer/range.dart';
import 'package:terminal_view/src/core/buffer/range_line.dart';
import 'package:terminal_view/src/core/buffer/segment.dart';
import 'package:terminal_view/src/core/mouse/button.dart';
import 'package:terminal_view/src/core/mouse/button_state.dart';
import 'package:terminal_view/src/terminal.dart';
import 'package:terminal_view/src/ui/controller.dart';
import 'package:terminal_view/src/core/cursor_type.dart';
import 'package:terminal_view/src/ui/painter.dart';
import 'package:terminal_view/src/ui/selection_mode.dart';
import 'package:terminal_view/src/ui/terminal_size.dart';
import 'package:terminal_view/src/ui/terminal_text_style.dart';
import 'package:terminal_view/src/ui/terminal_theme.dart';

typedef EditableRectCallback = void Function(Rect rect, Rect caretRect);

class RenderTerminal extends RenderBox with RelayoutWhenSystemFontsChangeMixin {
  RenderTerminal({
    required Terminal terminal,
    required TerminalController controller,
    required ViewportOffset offset,
    required EdgeInsets padding,
    required bool autoResize,
    required TerminalStyle textStyle,
    required TextScaler textScaler,
    required TerminalTheme theme,
    required FocusNode focusNode,
    required TerminalCursorType cursorType,
    required bool alwaysShowCursor,
    Duration? blinkInterval,
    EditableRectCallback? onEditableRect,
    String? composingText,
  })  : _blinkInterval = blinkInterval,
        _terminal = terminal,
        _controller = controller,
        _offset = offset,
        _padding = padding,
        _autoResize = autoResize,
        _focusNode = focusNode,
        _cursorType = cursorType,
        _alwaysShowCursor = alwaysShowCursor,
        _onEditableRect = onEditableRect,
        _composingText = composingText,
        _painter = TerminalPainter(
          theme: theme,
          textStyle: textStyle,
          textScaler: textScaler,
        );

  Terminal _terminal;
  set terminal(Terminal terminal) {
    if (_terminal == terminal) return;
    if (attached) _terminal.removeListener(_onTerminalChange);
    _terminal = terminal;
    if (attached) _terminal.addListener(_onTerminalChange);
    _resizeTerminalIfNeeded();
    markNeedsLayout();
  }

  TerminalController _controller;
  set controller(TerminalController controller) {
    if (_controller == controller) return;
    if (attached) _controller.removeListener(_onControllerUpdate);
    _controller = controller;
    if (attached) _controller.addListener(_onControllerUpdate);
    markNeedsLayout();
  }

  ViewportOffset _offset;
  set offset(ViewportOffset value) {
    if (value == _offset) return;
    if (attached) _offset.removeListener(_onScroll);
    _offset = value;
    if (attached) _offset.addListener(_onScroll);
    markNeedsLayout();
  }

  EdgeInsets _padding;
  set padding(EdgeInsets value) {
    if (value == _padding) return;
    _padding = value;
    markNeedsLayout();
  }

  bool _autoResize;
  set autoResize(bool value) {
    if (value == _autoResize) return;
    _autoResize = value;
    markNeedsLayout();
  }

  set textStyle(TerminalStyle value) {
    if (value == _painter.textStyle) return;
    _painter.textStyle = value;
    markNeedsLayout();
  }

  set textScaler(TextScaler value) {
    if (value == _painter.textScaler) return;
    _painter.textScaler = value;
    markNeedsLayout();
  }

  set theme(TerminalTheme value) {
    if (value == _painter.theme) return;
    _painter.theme = value;
    markNeedsPaint();
  }

  FocusNode _focusNode;
  set focusNode(FocusNode value) {
    if (value == _focusNode) return;
    if (attached) _focusNode.removeListener(_onFocusChange);
    _focusNode = value;
    if (attached) _focusNode.addListener(_onFocusChange);
    _restartBlink();
    markNeedsPaint();
  }

  TerminalCursorType _cursorType;
  set cursorType(TerminalCursorType value) {
    if (value == _cursorType) return;
    _cursorType = value;
    markNeedsPaint();
  }

  bool _alwaysShowCursor;
  set alwaysShowCursor(bool value) {
    if (value == _alwaysShowCursor) return;
    _alwaysShowCursor = value;
    markNeedsPaint();
  }

  /// Whether the cursor blinks, and how fast. Null holds it steady.
  ///
  /// Driven here rather than by the embedder rebuilding twice a second: a
  /// rebuild re-measures the font and flushes the paragraph cache, where a
  /// repaint is all that's needed.
  Duration? _blinkInterval;
  set blinkInterval(Duration? value) {
    if (value == _blinkInterval) return;
    _blinkInterval = value;
    _restartBlink();
  }

  Timer? _blinkTimer;

  var _blinkVisible = true;

  void _restartBlink() {
    _blinkTimer?.cancel();
    _blinkTimer = null;

    final interval = _blinkInterval;
    if (interval == null || !attached || !_focusNode.hasFocus) {
      if (!_blinkVisible) {
        _blinkVisible = true;
        markNeedsPaint();
      }
      return;
    }

    _blinkVisible = true;
    _blinkTimer = Timer.periodic(interval, (_) {
      _blinkVisible = !_blinkVisible;
      markNeedsPaint();
    });
  }

  /// Shows the cursor and restarts the blink phase, so it stays solid while
  /// output is arriving instead of flickering away mid-keystroke.
  void _resetBlinkPhase() {
    if (_blinkTimer == null) return;
    if (!_blinkVisible) markNeedsPaint();
    _restartBlink();
  }

  EditableRectCallback? _onEditableRect;
  set onEditableRect(EditableRectCallback? value) {
    if (value == _onEditableRect) return;
    _onEditableRect = value;
    _lastEditableRect = null;
    _lastCaretRect = null;
    markNeedsLayout();
  }

  Rect? _lastEditableRect;

  Rect? _lastCaretRect;

  String? _composingText;
  set composingText(String? value) {
    if (value == _composingText) return;
    _composingText = value;
    markNeedsPaint();
  }

  TerminalSize? _viewportSize;

  final TerminalPainter _painter;

  var _stickToBottom = true;

  void _onScroll() {
    _stickToBottom = _scrollOffset >= _maxScrollExtent;
    markNeedsLayout();
    _notifyEditableRect();
  }

  void _onFocusChange() {
    _restartBlink();
    markNeedsPaint();
  }

  void _onTerminalChange() {
    // Only a changed line count moves the scroll extent, and this runs on every
    // chunk of output, so a repaint beats a relayout for the common case.
    final lineCount = _terminal.buffer.lines.length;
    if (lineCount != _lastLineCount) {
      _lastLineCount = lineCount;
      markNeedsLayout();
      _notifyEditableRect();
    } else {
      markNeedsPaint();
      _notifyEditableRect();
    }

    _resetBlinkPhase();
  }

  var _lastLineCount = -1;

  void _onControllerUpdate() {
    markNeedsLayout();
  }

  @override
  final isRepaintBoundary = true;

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _offset.addListener(_onScroll);
    _terminal.addListener(_onTerminalChange);
    _controller.addListener(_onControllerUpdate);
    _focusNode.addListener(_onFocusChange);
    _restartBlink();
  }

  @override
  void detach() {
    super.detach();
    _offset.removeListener(_onScroll);
    _terminal.removeListener(_onTerminalChange);
    _controller.removeListener(_onControllerUpdate);
    _focusNode.removeListener(_onFocusChange);
    _blinkTimer?.cancel();
    _blinkTimer = null;
  }

  @override
  void dispose() {
    _blinkTimer?.cancel();
    _blinkTimer = null;
    _painter.dispose();
    super.dispose();
  }

  @override
  bool hitTestSelf(Offset position) {
    return true;
  }

  @override
  void systemFontsDidChange() {
    _painter.clearFontCache();
    super.systemFontsDidChange();
  }

  @override
  void performLayout() {
    size = constraints.biggest;

    _updateViewportSize();

    _updateScrollOffset();

    if (_stickToBottom) {
      _offset.correctBy(_maxScrollExtent - _scrollOffset);
    }
  }

  /// Total height of the terminal in pixels. Includes scrollback buffer.
  double get _terminalHeight =>
      _terminal.buffer.lines.length * _painter.cellSize.height;

  /// The distance from the top of the terminal to the top of the viewport.
  double get _scrollOffset => _offset.pixels;

  /// The height of a terminal line in pixels. This includes the line spacing.
  /// Height of the entire terminal is expected to be a multiple of this value.
  double get lineHeight => _painter.cellSize.height;

  /// Get the top-left corner of the cell at [cellOffset] in pixels.
  Offset getOffset(CellOffset cellOffset) {
    final row = cellOffset.y;
    final col = cellOffset.x;
    final x = col * _painter.cellSize.width;
    final y = row * _painter.cellSize.height;
    return Offset(x + _padding.left, y + _padding.top - _scrollOffset);
  }

  /// Get the [CellOffset] of the cell that [offset] is in.
  CellOffset getCellOffset(Offset offset) {
    final x = offset.dx - _padding.left;
    final y = offset.dy - _padding.top + _scrollOffset;
    final row = y ~/ _painter.cellSize.height;
    final col = x ~/ _painter.cellSize.width;
    return CellOffset(
      col.clamp(0, _terminal.viewWidth - 1),
      row.clamp(0, _terminal.buffer.lines.length - 1),
    );
  }

  /// Like [getCellOffset], but relative to the visible screen. Mouse reports
  /// need this: the application only knows the screen it drew, so a row counted
  /// from the top of the scrollback would land in the wrong place.
  CellOffset getViewportCellOffset(Offset offset) {
    final x = offset.dx - _padding.left;
    final y = offset.dy - _padding.top;
    final row = y ~/ _painter.cellSize.height;
    final col = x ~/ _painter.cellSize.width;
    return CellOffset(
      col.clamp(0, _terminal.viewWidth - 1),
      row.clamp(0, _terminal.viewHeight - 1),
    );
  }

  /// The word that contains [offset], or the single cell at [offset] when there
  /// is no word there, so selection can start on a blank cell or empty line.
  BufferRangeLine _wordOrCellAt(CellOffset offset) {
    return _terminal.buffer.getWordBoundary(offset) ??
        BufferRangeLine(offset, CellOffset(offset.x + 1, offset.y));
  }

  /// Selects entire words in the terminal that contains [from] and [to].
  void selectWord(Offset from, [Offset? to]) {
    final fromOffset = getCellOffset(from);
    final fromBoundary = _wordOrCellAt(fromOffset);
    if (to == null) {
      _controller.setSelection(
        _terminal.buffer.createAnchorFromOffset(fromBoundary.begin),
        _terminal.buffer.createAnchorFromOffset(fromBoundary.end),
        mode: SelectionMode.line,
      );
    } else {
      final toOffset = getCellOffset(to);
      final toBoundary = _wordOrCellAt(toOffset);
      final range = fromBoundary.merge(toBoundary);
      _controller.setSelection(
        _terminal.buffer.createAnchorFromOffset(range.begin),
        _terminal.buffer.createAnchorFromOffset(range.end),
        mode: SelectionMode.line,
      );
    }
  }

  /// Selects characters in the terminal that starts from [from] to [to]. At
  /// least one cell is selected even if [from] and [to] are same.
  void selectCharacters(Offset from, [Offset? to]) {
    final fromPosition = getCellOffset(from);
    if (to == null) {
      _controller.setSelection(
        _terminal.buffer.createAnchorFromOffset(fromPosition),
        _terminal.buffer.createAnchorFromOffset(fromPosition),
      );
    } else {
      var toPosition = getCellOffset(to);
      // Range end is exclusive: push whichever end comes last one cell forward
      // so the cell under the pointer stays selected in either drag direction.
      final backwards = toPosition.y < fromPosition.y ||
          (toPosition.y == fromPosition.y && toPosition.x < fromPosition.x);
      final basePosition = backwards
          ? CellOffset(fromPosition.x + 1, fromPosition.y)
          : fromPosition;
      if (!backwards) {
        toPosition = CellOffset(toPosition.x + 1, toPosition.y);
      }
      _controller.setSelection(
        _terminal.buffer.createAnchorFromOffset(basePosition),
        _terminal.buffer.createAnchorFromOffset(toPosition),
      );
    }
  }

  /// Send a mouse event at [offset] with [button] being currently in [buttonState].
  bool mouseEvent(
    TerminalMouseButton button,
    TerminalMouseButtonState buttonState,
    Offset offset,
  ) {
    final position = getViewportCellOffset(offset);
    return _terminal.mouseInput(button, buttonState, position);
  }

  void _notifyEditableRect() {
    final callback = _onEditableRect;
    if (callback == null) return;

    final cursor = localToGlobal(cursorOffset);

    final rect = Rect.fromLTRB(
      cursor.dx,
      cursor.dy,
      size.width,
      cursor.dy + _painter.cellSize.height,
    );

    final caretRect = cursor & _painter.cellSize;

    if (rect == _lastEditableRect && caretRect == _lastCaretRect) return;

    _lastEditableRect = rect;
    _lastCaretRect = caretRect;
    callback(rect, caretRect);
  }

  /// Update the viewport size in cells based on the current widget size in
  /// pixels.
  void _updateViewportSize() {
    if (size <= _painter.cellSize) {
      return;
    }

    final viewportSize = TerminalSize(
      size.width ~/ _painter.cellSize.width,
      _viewportHeight ~/ _painter.cellSize.height,
    );

    if (_viewportSize != viewportSize) {
      _viewportSize = viewportSize;
      _resizeTerminalIfNeeded();
    }
  }

  /// Notify the underlying terminal that the viewport size has changed.
  ///
  /// This runs synchronously inside [performLayout], not through
  /// [_onTerminalChange] the way remote output does - `Buffer.resize` can
  /// change `lines.length` right here without [_lastLineCount] ever
  /// learning about it. Left stale, the next real output event reads a
  /// [_lastLineCount] from before the resize, so its own line-count check
  /// can come out wrong and skip the layout pass that would have
  /// recomputed the scroll bounds for the size that was just applied -
  /// exactly the moment that matters most. Syncing it here closes that gap.
  void _resizeTerminalIfNeeded() {
    if (_autoResize && _viewportSize != null) {
      _terminal.resize(
        _viewportSize!.width,
        _viewportSize!.height,
        _painter.cellSize.width.round(),
        _painter.cellSize.height.round(),
      );
      _lastLineCount = _terminal.buffer.lines.length;
    }
  }

  /// Update the scroll offset based on the current terminal state. This should
  /// be called in [performLayout] after the viewport size has been updated.
  void _updateScrollOffset() {
    _offset.applyViewportDimension(_viewportHeight);
    _offset.applyContentDimensions(0, _maxScrollExtent);
  }

  bool get _isComposingText {
    return _composingText != null && _composingText!.isNotEmpty;
  }

  bool get _shouldShowCursor {
    if (!_blinkVisible && !_isComposingText) return false;
    return _terminal.cursorVisibleMode || _alwaysShowCursor || _isComposingText;
  }

  double get _viewportHeight {
    return size.height - _padding.vertical;
  }

  double get _maxScrollExtent {
    return max(_terminalHeight - _viewportHeight, 0.0);
  }

  double get _lineOffset {
    return -_scrollOffset + _padding.top;
  }

  double _rowY(int row) {
    return (row * _painter.cellSize.height + _lineOffset).truncateToDouble();
  }

  /// The offset of the cursor from the top left corner of this render object.
  Offset get cursorOffset {
    return Offset(
      _terminal.buffer.cursorX * _painter.cellSize.width,
      _rowY(_terminal.buffer.absoluteCursorY),
    );
  }

  Size get cellSize {
    return _painter.cellSize;
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    // At a fractional scroll offset the first and last row stick out of the
    // viewport and would bleed over whatever sits above or below it.
    context.pushClipRect(
      needsCompositing,
      offset,
      Offset.zero & size,
      _paint,
      clipBehavior: Clip.hardEdge,
    );
    context.setWillChangeHint();
  }

  void _paint(PaintingContext context, Offset offset) {
    final canvas = context.canvas;

    final lines = _terminal.buffer.lines;
    final charHeight = _painter.cellSize.height;

    final firstLineOffset = _scrollOffset - _padding.top;
    final lastLineOffset = _scrollOffset + size.height + _padding.bottom;

    final firstLine = firstLineOffset ~/ charHeight;
    final lastLine = lastLineOffset ~/ charHeight;

    final effectFirstLine = firstLine.clamp(0, lines.length - 1);
    final effectLastLine = lastLine.clamp(0, lines.length - 1);

    _painter.blinkVisible = _blinkVisible;

    for (var i = effectFirstLine; i <= effectLastLine; i++) {
      _painter.paintLine(
        canvas,
        offset.translate(0, _rowY(i)),
        lines[i],
      );
    }

    if (_terminal.buffer.absoluteCursorY >= effectFirstLine &&
        _terminal.buffer.absoluteCursorY <= effectLastLine) {
      if (_isComposingText) {
        _paintComposingText(canvas, offset + cursorOffset);
      }

      if (_shouldShowCursor) {
        _painter.paintCursor(
          canvas,
          offset + cursorOffset,
          cursorType: _cursorType,
          hasFocus: _focusNode.hasFocus,
        );

        if (_focusNode.hasFocus) {
          _paintCursorAccent(canvas, offset);
        }
      }
    }

    _paintHighlights(
      canvas,
      _controller.highlights,
      effectFirstLine,
      effectLastLine,
    );

    if (_controller.selection != null) {
      _paintSelection(
        canvas,
        _controller.selection!,
        effectFirstLine,
        effectLastLine,
      );
    }
  }

  /// Paints the text that is currently being composed in IME to [canvas] at
  /// [offset]. [offset] is usually the cursor position.
  void _paintComposingText(Canvas canvas, Offset offset) {
    final composingText = _composingText;
    if (composingText == null) {
      return;
    }

    final style = _painter.textStyle.toTextStyle(
      color: _painter.resolveForegroundColor(_terminal.cursor.foreground),
      backgroundColor: _painter.theme.background,
    );

    final builder = ParagraphBuilder(
      style.getParagraphStyle(
        strutStyle: _painter.textStyle.toStrutStyle(),
        textScaler: _painter.textScaler,
      ),
    );
    builder.addPlaceholder(
      offset.dx,
      _painter.cellSize.height,
      PlaceholderAlignment.middle,
    );
    builder.pushStyle(
      style.getTextStyle(textScaler: _painter.textScaler),
    );
    builder.addText(composingText);

    final paragraph = builder.build();
    paragraph.layout(ParagraphConstraints(width: size.width));

    canvas.drawParagraph(paragraph, Offset(0, offset.dy));
  }

  void _paintSelection(
    Canvas canvas,
    BufferRange selection,
    int firstLine,
    int lastLine,
  ) {
    for (final segment in selection.toSegments()) {
      if (segment.line >= _terminal.buffer.lines.length) {
        break;
      }

      if (segment.line < firstLine) {
        continue;
      }

      if (segment.line > lastLine) {
        break;
      }

      _paintSegment(
        canvas,
        segment,
        _painter.theme.selection,
        textColor: _painter.theme.selectionForeground,
      );
    }
  }

  void _paintHighlights(
    Canvas canvas,
    List<TerminalHighlight> highlights,
    int firstLine,
    int lastLine,
  ) {
    for (var highlight in _controller.highlights) {
      final range = highlight.range?.normalized;

      if (range == null ||
          range.begin.y > lastLine ||
          range.end.y < firstLine) {
        continue;
      }

      for (var segment in range.toSegments()) {
        if (segment.line < firstLine) {
          continue;
        }

        if (segment.line > lastLine) {
          break;
        }

        _paintSegment(canvas, segment, highlight.color);
      }
    }
  }

  void _paintSegment(
    Canvas canvas,
    BufferSegment segment,
    Color color, {
    Color? textColor,
  }) {
    final start = segment.start ?? 0;
    final end = segment.end ?? _terminal.viewWidth;

    final startOffset = Offset(
      start * _painter.cellSize.width,
      _rowY(segment.line),
    );

    _painter.paintHighlight(canvas, startOffset, end - start, color);

    if (textColor == null) return;

    final line = _terminal.buffer.lines[segment.line];
    final cellWidth = _painter.cellSize.width;
    final clampedEnd = end.clamp(0, line.length);
    final cellData = CellData.empty();

    for (var i = start; i < clampedEnd; i++) {
      line.getCellData(i, cellData);
      _painter.paintCellForegroundColor(
        canvas,
        startOffset.translate((i - start) * cellWidth, 0),
        cellData,
        textColor,
      );
    }
  }

  void _paintCursorAccent(Canvas canvas, Offset offset) {
    final accent = _painter.theme.cursorAccent;
    if (accent == null || _cursorType != TerminalCursorType.block) return;

    final buffer = _terminal.buffer;
    final line = buffer.lines[buffer.absoluteCursorY];
    final cellData = CellData.empty();
    line.getCellData(buffer.cursorX, cellData);

    _painter.paintCellForegroundColor(
      canvas,
      offset + cursorOffset,
      cellData,
      accent,
    );
  }
}
