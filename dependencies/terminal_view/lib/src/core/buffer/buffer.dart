import 'dart:math' show max, min;

import 'package:terminal_view/src/core/buffer/cell_offset.dart';
import 'package:terminal_view/src/core/buffer/line.dart';
import 'package:terminal_view/src/core/buffer/range_line.dart';
import 'package:terminal_view/src/core/buffer/range.dart';
import 'package:terminal_view/src/core/charset.dart';
import 'package:terminal_view/src/core/cursor.dart';
import 'package:terminal_view/src/core/reflow.dart';
import 'package:terminal_view/src/core/state.dart';
import 'package:terminal_view/src/utils/circular_buffer.dart';
import 'package:terminal_view/src/utils/unicode_v16.dart';

const _zeroWidthJoiner = 0x200D;

const _emojiPresentationSelector = 0xFE0F;

const _textPresentationSelector = 0xFE0E;

const _skinToneFirst = 0x1F3FB;

const _skinToneLast = 0x1F3FF;

class Buffer {
  final TerminalState terminal;

  final int maxLines;

  final bool isAltBuffer;

  /// Characters that break selection when calling [getWordBoundary]. If null,
  /// defaults to [defaultWordSeparators].
  final Set<int>? wordSeparators;

  Buffer(
    this.terminal, {
    required this.maxLines,
    required this.isAltBuffer,
    this.wordSeparators,
  }) {
    for (int i = 0; i < terminal.viewHeight; i++) {
      lines.push(_newEmptyLine());
    }

    resetVerticalMargins();
  }

  int _cursorX = 0;

  int _cursorY = 0;

  BufferLine? _currentLine;

  var _currentLineIndex = -1;

  var _currentLineBufferVersion = -1;

  late int _marginTop;

  late int _marginBottom;

  var _savedCursorX = 0;

  var _savedCursorY = 0;

  var _pendingJoiner = false;

  final _savedCursorStyle = CursorStyle();

  final charset = Charset();

  /// Width of the viewport in columns. Also the index of the last column.
  int get viewWidth => terminal.viewWidth;

  /// Height of the viewport in rows. Also the index of the last line.
  int get viewHeight => terminal.viewHeight;

  /// lines of the buffer. the length of [lines] should always be equal or
  /// greater than [viewHeight].
  late final lines = IndexAwareCircularBuffer<BufferLine>(maxLines);

  /// Total number of lines in the buffer. Always equal or greater than
  /// [viewHeight].
  int get height => lines.length;

  /// Horizontal position of the cursor relative to the top-left cornor of the
  /// screen, starting from 0.
  int get cursorX => _cursorX.clamp(0, terminal.viewWidth - 1);

  /// Vertical position of the cursor relative to the top-left cornor of the
  /// screen, starting from 0.
  int get cursorY => _cursorY;

  /// Index of the first line in the scroll region.
  int get marginTop => _marginTop;

  /// Index of the last line in the scroll region.
  int get marginBottom => _marginBottom;

  /// The number of lines above the viewport.
  int get scrollBack => height - viewHeight;

  /// Vertical position of the cursor relative to the top of the buffer,
  /// starting from 0.
  int get absoluteCursorY => _cursorY + scrollBack;

  /// Absolute index of the first line in the scroll region.
  int get absoluteMarginTop => _marginTop + scrollBack;

  /// Absolute index of the last line in the scroll region.
  int get absoluteMarginBottom => _marginBottom + scrollBack;

  /// Writes data to the _terminal. Terminal sequences or special characters are
  /// not interpreted and directly added to the buffer.
  ///
  /// See also: [Terminal.write]
  void write(String text) {
    for (var char in text.runes) {
      writeChar(char);
    }
  }

  /// Writes a single character to the _terminal. Escape sequences or special
  /// characters are not interpreted and directly added to the buffer.
  ///
  /// See also: [Terminal.writeChar]
  void writeChar(int codePoint) {
    codePoint = charset.translate(codePoint);

    if (codePoint == _zeroWidthJoiner) {
      _appendToPreviousCell(codePoint);
      _pendingJoiner = true;
      return;
    }

    if (_pendingJoiner) {
      _pendingJoiner = false;
      _appendToPreviousCell(codePoint);
      return;
    }

    if (codePoint >= _skinToneFirst && codePoint <= _skinToneLast) {
      _appendToPreviousCell(codePoint);
      return;
    }

    if (codePoint == _textPresentationSelector) {
      return;
    }

    if (codePoint == _emojiPresentationSelector) {
      _applyEmojiPresentation();
      return;
    }

    final cellWidth = unicodeV16.wcwidth(codePoint);
    if (cellWidth == 0) {
      _appendToPreviousCell(codePoint);
      return;
    }

    if (_cursorX + cellWidth > viewWidth) {
      if (terminal.autoWrapMode) {
        _wrapLine();
      } else {
        _cursorX = viewWidth - cellWidth;
        if (_cursorX < 0) return;
      }
    }

    final line = currentLine;

    if (terminal.insertMode) {
      line.insertCells(_cursorX, cellWidth, terminal.cursor);
    }

    line.setCell(_cursorX, codePoint, cellWidth, terminal.cursor);

    if (cellWidth == 2) {
      line.setCell(_cursorX + 1, 0, 0, terminal.cursor);
    }

    _cursorX += cellWidth;
  }

  void _appendToPreviousCell(int codePoint) {
    var x = _cursorX - 1;
    if (x < 0) return;

    final line = currentLine;
    if (line.getCodePoint(x) == 0 && x > 0) x -= 1;
    if (line.getCodePoint(x) == 0) return;

    final existing = line.getCombined(x) ?? '';
    line.setCombined(x, existing + String.fromCharCode(codePoint));
  }

  void _wrapLine() {
    if (_cursorX < viewWidth) {
      currentLine.eraseRange(_cursorX, viewWidth, terminal.cursor);
    }

    index();
    setCursorX(0);
    currentLine.isWrapped = true;
  }

  void _applyEmojiPresentation() {
    final x = _cursorX - 1;
    if (x < 0 || _cursorX >= viewWidth) return;

    final line = currentLine;
    if (line.getWidth(x) != 1) return;

    final codePoint = line.getCodePoint(x);
    if (codePoint == 0) return;

    line.setCell(x, codePoint, 2, terminal.cursor);
    line.setCell(_cursorX, 0, 0, terminal.cursor);
    _cursorX++;
  }

  /// The line at the current cursor position.
  @pragma('vm:prefer-inline')
  BufferLine get currentLine {
    final index = absoluteCursorY;
    final bufferVersion = lines.version;
    if (_currentLine == null ||
        _currentLineIndex != index ||
        _currentLineBufferVersion != bufferVersion) {
      _currentLine = lines[index];
      _currentLineIndex = index;
      _currentLineBufferVersion = bufferVersion;
    }
    return _currentLine!;
  }

  /// Clamps the raw cursor column into the screen.
  ///
  /// After a write that fills the last column, [_cursorX] is left at
  /// [viewWidth] as a pending-wrap sentinel. Operations that address cells -
  /// erases, deletes, inserts, relative moves - must collapse the sentinel to
  /// the last real column first, the way xterm's _restrictCursor does, or they
  /// act on an empty range past the end of the line (and DCH asserts).
  @pragma('vm:prefer-inline')
  void _restrictCursor() {
    if (_cursorX >= viewWidth) {
      _cursorX = viewWidth - 1;
    }
  }

  void backspace() {
    // xterm: collapse the pending-wrap sentinel first, then step one left;
    // BS from the sentinel position therefore lands two columns behind it.
    _restrictCursor();
    if (_cursorX > 0) {
      _cursorX--;
    }
  }

  /// Erases the viewport from the cursor position to the end of the buffer,
  /// including the cursor position.
  void eraseDisplayFromCursor() {
    _restrictCursor();
    eraseLineFromCursor();

    for (var i = absoluteCursorY + 1; i < height; i++) {
      final line = lines[i];
      line.isWrapped = false;
      line.eraseRange(0, viewWidth, terminal.cursor);
    }
  }

  /// Erases the viewport from the top-left corner to the cursor, including the
  /// cursor.
  void eraseDisplayToCursor() {
    eraseLineToCursor();

    for (var i = 0; i < _cursorY; i++) {
      final line = lines[i + scrollBack];
      line.isWrapped = false;
      line.eraseRange(0, viewWidth, terminal.cursor);
    }
  }

  /// Erases the whole viewport.
  void eraseDisplay() {
    for (var i = 0; i < viewHeight; i++) {
      final line = lines[i + scrollBack];
      line.isWrapped = false;
      line.eraseRange(0, viewWidth, terminal.cursor);
    }
  }

  /// Erases the line from the cursor to the end of the line, including the
  /// cursor position.
  void eraseLineFromCursor() {
    _restrictCursor();
    currentLine.isWrapped = false;
    currentLine.eraseRange(_cursorX, viewWidth, terminal.cursor);
  }

  /// Erases the line from the start of the line to the cursor, including the
  /// cursor. ECMA-48: "from the beginning ... through the active position".
  void eraseLineToCursor() {
    _restrictCursor();
    currentLine.isWrapped = false;
    currentLine.eraseRange(0, _cursorX + 1, terminal.cursor);
  }

  /// Erases the line at the current cursor position.
  void eraseLine() {
    currentLine.isWrapped = false;
    currentLine.eraseRange(0, viewWidth, terminal.cursor);
  }

  /// Erases [count] cells starting at the cursor position.
  void eraseChars(int count) {
    _restrictCursor();
    final start = _cursorX;
    currentLine.eraseRange(start, start + count, terminal.cursor);
  }

  void scrollDown(int lines) {
    // Must use move() not []= here. The []= operator (_adoptChild) updates
    // the moved object's index but leaves the source slot pointing at the
    // same object. The next iteration then _detach()es that object through
    // the stale source pointer, corrupting the destination slot (null owner).
    // move() nulls the source slot after moving, preventing the aliasing.
    for (var i = absoluteMarginBottom; i >= absoluteMarginTop; i--) {
      if (i >= absoluteMarginTop + lines) {
        this.lines.move(i - lines, i);
      } else {
        this.lines[i] = _newEmptyLine();
      }
    }
  }

  void scrollUp(int lines) {
    for (var i = absoluteMarginTop; i <= absoluteMarginBottom; i++) {
      if (i <= absoluteMarginBottom - lines) {
        this.lines.move(i + lines, i);
      } else {
        this.lines[i] = _newEmptyLine();
      }
    }
  }

  /// https://vt100.net/docs/vt100-ug/chapter3.html#IND IND – Index
  ///
  /// ESC D
  ///
  /// [index] causes the active position to move downward one line without
  /// changing the column position. If the active position is at the bottom
  /// margin, a scroll up is performed.
  void index() {
    if (isInVerticalMargin) {
      if (_cursorY == _marginBottom) {
        if (marginTop == 0 && !isAltBuffer) {
          lines.insert(absoluteMarginBottom + 1, _newEmptyLine());
        } else {
          scrollUp(1);
        }
      } else {
        moveCursorY(1);
      }
      return;
    }

    // the cursor is not in the scrollable region
    if (_cursorY >= viewHeight - 1) {
      // we are at the bottom
      if (isAltBuffer) {
        scrollUp(1);
      } else {
        lines.push(_newEmptyLine());
      }
    } else {
      // there're still lines so we simply move cursor down.
      moveCursorY(1);
    }
  }

  void lineFeed() {
    index();
    if (terminal.lineFeedMode) {
      setCursorX(0);
    }
  }

  /// https://terminalguide.namepad.de/seq/a_esc_cm/
  void reverseIndex() {
    if (isInVerticalMargin) {
      if (_cursorY == _marginTop) {
        scrollDown(1);
      } else {
        moveCursorY(-1);
      }
    } else {
      moveCursorY(-1);
    }
  }

  void cursorGoForward() {
    _cursorX = min(_cursorX + 1, viewWidth);
  }

  void setCursorX(int cursorX) {
    _pendingJoiner = false;
    _cursorX = cursorX.clamp(0, viewWidth - 1);
  }

  void setCursorY(int cursorY) {
    _pendingJoiner = false;
    _cursorY = cursorY.clamp(0, viewHeight - 1);
  }

  void moveCursorX(int offset) {
    // Relative moves resolve from the displayed cursor position, so collapse
    // the pending-wrap sentinel first (xterm _moveCursor does the same).
    _restrictCursor();
    setCursorX(_cursorX + offset);
  }

  void moveCursorY(int offset) {
    var target = _cursorY + offset;

    if (offset > 0 && _cursorY <= _marginBottom) {
      target = min(target, _marginBottom);
    } else if (offset < 0 && _cursorY >= _marginTop) {
      target = max(target, _marginTop);
    }

    setCursorY(target);
  }

  void setCursor(int cursorX, int cursorY) {
    var maxCursorY = viewHeight - 1;

    if (terminal.originMode) {
      cursorY += _marginTop;
      maxCursorY = _marginBottom;
    }

    _pendingJoiner = false;
    _cursorX = cursorX.clamp(0, viewWidth - 1);
    _cursorY = cursorY.clamp(0, maxCursorY);
  }

  void moveCursor(int offsetX, int offsetY) {
    _restrictCursor();
    setCursorX(_cursorX + offsetX);
    moveCursorY(offsetY);
  }

  /// Save cursor position, charmap and text attributes.
  void saveCursor() {
    _savedCursorX = _cursorX;
    _savedCursorY = _cursorY;
    _savedCursorStyle.foreground = terminal.cursor.foreground;
    _savedCursorStyle.background = terminal.cursor.background;
    _savedCursorStyle.attrs = terminal.cursor.attrs;
    charset.save();
  }

  void softReset() {
    _savedCursorX = 0;
    _savedCursorY = 0;
    _savedCursorStyle.reset();
    _pendingJoiner = false;
    charset.reset();
    resetVerticalMargins();
    setCursor(0, 0);
  }

  /// Restore cursor position, charmap and text attributes.
  void restoreCursor() {
    // The saved position can be off-screen after a resize; clamp it so the
    // next write lands where the cursor is drawn instead of wrapping.
    _pendingJoiner = false;
    _cursorX = _savedCursorX.clamp(0, viewWidth - 1);
    _cursorY = _savedCursorY.clamp(0, viewHeight - 1);
    terminal.cursor.foreground = _savedCursorStyle.foreground;
    terminal.cursor.background = _savedCursorStyle.background;
    terminal.cursor.attrs = _savedCursorStyle.attrs;
    charset.restore();
  }

  /// Sets the vertical scrolling margin to [top] and [bottom].
  /// Both values must be between 0 and [viewHeight] - 1.
  void setVerticalMargins(int top, int bottom) {
    _marginTop = top.clamp(0, viewHeight - 1);
    _marginBottom = bottom.clamp(0, viewHeight - 1);

    _marginTop = min(_marginTop, _marginBottom);
    _marginBottom = max(_marginTop, _marginBottom);
  }

  bool get isInVerticalMargin {
    return _cursorY >= _marginTop && _cursorY <= _marginBottom;
  }

  void resetVerticalMargins() {
    setVerticalMargins(0, viewHeight - 1);
  }

  void deleteChars(int count) {
    _restrictCursor();
    final start = _cursorX.clamp(0, viewWidth);
    count = min(count, viewWidth - start);
    currentLine.removeCells(start, count, terminal.cursor);
  }

  /// Remove all lines above the top of the viewport.
  void clearScrollback() {
    if (height <= viewHeight) {
      return;
    }

    lines.trimStart(scrollBack);
  }

  /// Clears the viewport and scrollback buffer. Then fill with empty lines.
  void clear() {
    lines.clear();
    for (int i = 0; i < viewHeight; i++) {
      lines.push(_newEmptyLine());
    }
  }

  void insertBlankChars(int count) {
    _restrictCursor();
    currentLine.insertCells(_cursorX, count, terminal.cursor);
  }

  void insertLines(int count) {
    if (!isInVerticalMargin) {
      return;
    }

    setCursorX(0);

    // Number of lines from the cursor to the bottom of the scrollable region
    // including the cursor itself.
    final linesBelow = absoluteMarginBottom - absoluteCursorY + 1;

    // Number of empty lines to insert.
    final linesToInsert = min(count, linesBelow);

    // Number of lines to move up.
    final linesToMove = linesBelow - linesToInsert;

    for (var i = 0; i < linesToMove; i++) {
      final index = absoluteMarginBottom - i;
      lines[index] = lines.swap(index - linesToInsert, _newEmptyLine());
    }

    for (var i = linesToMove; i < linesToInsert; i++) {
      lines[absoluteCursorY + i] = _newEmptyLine();
    }
  }

  /// Remove [count] lines starting at the current cursor position. Lines below
  /// the removed lines are shifted up. This only affects the scrollable region.
  /// Lines outside the scrollable region are not affected.
  void deleteLines(int count) {
    if (!isInVerticalMargin) {
      return;
    }

    setCursorX(0);

    count = min(count, absoluteMarginBottom - absoluteCursorY + 1);

    final linesToMove = absoluteMarginBottom - absoluteCursorY + 1 - count;

    for (var i = 0; i < linesToMove; i++) {
      final index = absoluteCursorY + i;
      lines.move(index + count, index);
    }

    for (var i = 0; i < count; i++) {
      lines[absoluteMarginBottom - i] = _newEmptyLine();
    }
  }

  void resize(int oldWidth, int oldHeight, int newWidth, int newHeight) {
    // 1. Adjust the height.
    if (newHeight > oldHeight) {
      // Grow larger
      for (var i = 0; i < newHeight - oldHeight; i++) {
        if (newHeight > lines.length) {
          lines.push(_newEmptyLine(newWidth));
        } else {
          _cursorY++;
        }
      }
    } else {
      // Shrink smaller
      for (var i = 0; i < oldHeight - newHeight; i++) {
        if (_cursorY > newHeight - 1) {
          _cursorY--;
        } else {
          lines.pop();
        }
      }
    }

    // Ensure cursor is within the screen.
    _cursorX = _cursorX.clamp(0, newWidth - 1);
    _cursorY = _cursorY.clamp(0, newHeight - 1);

    // 2. Adjust the width.
    if (newWidth != oldWidth) {
      if (terminal.reflowEnabled && !isAltBuffer) {
        final cursorLine = (max(lines.length - newHeight, 0) + _cursorY)
            .clamp(0, lines.length - 1);

        final anchor = createAnchor(
          _cursorX.clamp(0, lines[cursorLine].length),
          cursorLine,
        );

        final reflowResult = reflow(lines, oldWidth, newWidth);

        while (reflowResult.length < newHeight) {
          reflowResult.add(_newEmptyLine(newWidth));
        }

        lines.replaceWith(reflowResult);

        if (anchor.attached) {
          final scrollBack = max(lines.length - newHeight, 0);
          _cursorX = anchor.x.clamp(0, newWidth - 1);
          _cursorY = (anchor.y - scrollBack).clamp(0, newHeight - 1);
        }

        anchor.dispose();
      } else {
        lines.forEach((item) => item.resize(newWidth));
      }
    }
  }

  /// Create a new [CellAnchor] at the specified [x] and [y] coordinates.
  CellAnchor createAnchor(int x, int y) {
    return lines[y].createAnchor(x);
  }

  /// Create a new [CellAnchor] at the specified [x] and [y] coordinates.
  CellAnchor createAnchorFromOffset(CellOffset offset) {
    return lines[offset.y].createAnchor(offset.x);
  }

  CellAnchor createAnchorFromCursor() {
    return createAnchor(cursorX, absoluteCursorY);
  }

  /// Create a new empty [BufferLine] with the current [viewWidth] if [width]
  /// is not specified.
  BufferLine _newEmptyLine([int? width]) {
    final line = BufferLine(width ?? viewWidth);
    return line;
  }

  static final defaultWordSeparators = <int>{
    0,
    r' '.codeUnitAt(0),
    r'.'.codeUnitAt(0),
    r':'.codeUnitAt(0),
    r'-'.codeUnitAt(0),
    r'\'.codeUnitAt(0),
    r'"'.codeUnitAt(0),
    r'*'.codeUnitAt(0),
    r'+'.codeUnitAt(0),
    r'/'.codeUnitAt(0),
    r'\'.codeUnitAt(0),
  };

  BufferRangeLine? getWordBoundary(CellOffset position) {
    var separators = wordSeparators ?? defaultWordSeparators;
    if (position.y >= lines.length) {
      return null;
    }

    var line = lines[position.y];
    var start = position.x;
    var end = position.x;

    do {
      if (start == 0) {
        break;
      }
      final char = line.getCodePoint(start - 1);
      if (separators.contains(char)) {
        break;
      }
      start--;
    } while (true);

    do {
      if (end >= viewWidth) {
        break;
      }
      final char = line.getCodePoint(end);
      if (separators.contains(char)) {
        break;
      }
      end++;
    } while (true);

    if (start == end) {
      return null;
    }

    return BufferRangeLine(
      CellOffset(start, position.y),
      CellOffset(end, position.y),
    );
  }

  /// Get the plain text content of the buffer including the scrollback.
  /// Accepts an optional [range] to get a specific part of the buffer.
  String getText([BufferRange? range]) {
    range ??= BufferRangeLine(
      CellOffset(0, 0),
      CellOffset(viewWidth - 1, height - 1),
    );

    range = range.normalized;

    final builder = StringBuffer();

    for (var segment in range.toSegments()) {
      if (segment.line < 0 || segment.line >= height) {
        continue;
      }
      final line = lines[segment.line];
      if (!(segment.line == range.begin.y ||
          segment.line == 0 ||
          line.isWrapped)) {
        builder.write("\n");
      }
      builder.write(line.getText(segment.start, segment.end));
    }

    return builder.toString();
  }

  /// Returns a debug representation of the buffer.
  @override
  String toString() {
    final builder = StringBuffer();
    final lineNumberLength = lines.length.toString().length;

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];

      builder.write('${i.toString().padLeft(lineNumberLength)}: |${lines[i]}|');

      if (line.isWrapped) {
        builder.write(' (⏎)');
      }

      builder.write('\n');
    }

    return builder.toString();
  }
}
