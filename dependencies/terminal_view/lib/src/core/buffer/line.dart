import 'dart:math' show min;
import 'dart:typed_data';

import 'package:terminal_view/src/core/buffer/cell_offset.dart';
import 'package:terminal_view/src/core/cell.dart';
import 'package:terminal_view/src/core/cursor.dart';
import 'package:terminal_view/src/utils/circular_buffer.dart';
import 'package:terminal_view/src/utils/unicode_v16.dart';

const _cellSize = 4;

const _cellForeground = 0;

const _cellBackground = 1;

const _cellAttributes = 2;

const _cellContent = 3;

class BufferLine with IndexedItem {
  BufferLine(
    this._length, {
    this.isWrapped = false,
  }) : _data = Uint32List(_calcCapacity(_length) * _cellSize);

  int _length;

  /// Bumped by every change to the cells of this line, so a renderer can tell
  /// whether what it derived from the line (a recorded picture) is still valid.
  int _version = 0;

  int get version => _version;

  Uint32List _data;

  Uint32List get data => _data;

  Map<int, String>? _combined;

  String? getCombined(int index) => _combined?[index];

  void setCombined(int index, String suffix) {
    _version++;
    (_combined ??= {})[index] = suffix;
  }

  var isWrapped = false;

  int get length => _length;

  final _anchors = <CellAnchor>[];

  List<CellAnchor> get anchors => _anchors;

  int getForeground(int index) {
    return _data[index * _cellSize + _cellForeground];
  }

  int getBackground(int index) {
    return _data[index * _cellSize + _cellBackground];
  }

  int getAttributes(int index) {
    return _data[index * _cellSize + _cellAttributes];
  }

  int getContent(int index) {
    return _data[index * _cellSize + _cellContent];
  }

  int getCodePoint(int index) {
    return _data[index * _cellSize + _cellContent] & CellContent.codepointMask;
  }

  int getWidth(int index) {
    return _data[index * _cellSize + _cellContent] >> CellContent.widthShift;
  }

  void getCellData(int index, CellData cellData) {
    final offset = index * _cellSize;
    cellData.foreground = _data[offset + _cellForeground];
    cellData.background = _data[offset + _cellBackground];
    cellData.flags = _data[offset + _cellAttributes];
    cellData.content = _data[offset + _cellContent];
  }

  CellData createCellData(int index) {
    final cellData = CellData.empty();
    final offset = index * _cellSize;
    _data[offset + _cellForeground] = cellData.foreground;
    _data[offset + _cellBackground] = cellData.background;
    _data[offset + _cellAttributes] = cellData.flags;
    _data[offset + _cellContent] = cellData.content;
    return cellData;
  }

  void setForeground(int index, int value) {
    _version++;
    _data[index * _cellSize + _cellForeground] = value;
  }

  void setBackground(int index, int value) {
    _version++;
    _data[index * _cellSize + _cellBackground] = value;
  }

  void setAttributes(int index, int value) {
    _version++;
    _data[index * _cellSize + _cellAttributes] = value;
  }

  void setContent(int index, int value) {
    _version++;
    _data[index * _cellSize + _cellContent] = value;
  }

  void setCodePoint(int index, int char) {
    final width = unicodeV16.wcwidth(char);
    setContent(index, char | (width << CellContent.widthShift));
  }

  void setCell(int index, int char, int witdh, CursorStyle style) {
    _version++;
    final offset = index * _cellSize;
    _data[offset + _cellForeground] = style.foreground;
    _data[offset + _cellBackground] = style.background;
    _data[offset + _cellAttributes] = style.attrs;
    _data[offset + _cellContent] = char | (witdh << CellContent.widthShift);
    _combined?.remove(index);
  }

  void setCellData(int index, CellData cellData) {
    _version++;
    final offset = index * _cellSize;
    _data[offset + _cellForeground] = cellData.foreground;
    _data[offset + _cellBackground] = cellData.background;
    _data[offset + _cellAttributes] = cellData.flags;
    _data[offset + _cellContent] = cellData.content;
    _combined?.remove(index);
  }

  void eraseCell(int index, CursorStyle style) {
    _version++;
    final offset = index * _cellSize;
    _data[offset + _cellForeground] = style.foreground;
    _data[offset + _cellBackground] = style.background;
    _data[offset + _cellAttributes] = style.attrs;
    _data[offset + _cellContent] = 0;
    _combined?.remove(index);
  }

  void resetCell(int index) {
    _version++;
    final offset = index * _cellSize;
    _data[offset + _cellForeground] = 0;
    _data[offset + _cellBackground] = 0;
    _data[offset + _cellAttributes] = 0;
    _data[offset + _cellContent] = 0;
    _combined?.remove(index);
  }

  /// Erase cells whose index satisfies [start] <= index < [end]. Erased cells
  /// are filled with [style].
  void eraseRange(int start, int end, CursorStyle style) {
    // reset cell one to the left if start is second cell of a wide char
    if (start > 0 && getWidth(start - 1) == 2) {
      eraseCell(start - 1, style);
    }

    // reset cell one to the right if end is second cell of a wide char
    if (end < _length && getWidth(end - 1) == 2) {
      eraseCell(end - 1, style);
    }

    end = min(end, _length);
    for (var i = start; i < end; i++) {
      eraseCell(i, style);
    }
  }

  /// Remove [count] cells starting at [start]. Cells that are empty after the
  /// removal are filled with [style].
  void removeCells(int start, int count, [CursorStyle? style]) {
    _version++;
    assert(start >= 0 && start < _length);
    assert(count >= 0 && start + count <= _length);

    style ??= CursorStyle.empty;

    _combined?.clear();

    if (start + count < _length) {
      final moveStart = start * _cellSize;
      final moveEnd = (_length - count) * _cellSize;
      final moveOffset = count * _cellSize;
      for (var i = moveStart; i < moveEnd; i++) {
        _data[i] = _data[i + moveOffset];
      }
    }

    for (var i = _length - count; i < _length; i++) {
      eraseCell(i, style);
    }

    if (start > 0 && getWidth(start - 1) == 2) {
      eraseCell(start - 1, style);
    }

    // Update anchors, remove anchors that are inside the removed range.
    for (var i = 0; i < _anchors.length; i++) {
      final anchor = _anchors[i];
      if (anchor.x >= start) {
        if (anchor.x < start + count) {
          anchor.dispose();
        } else {
          anchor.reposition(anchor.x - count);
        }
      }
    }
  }

  /// Inserts [count] cells at [start]. New cells are initialized with [style].
  void insertCells(int start, int count, [CursorStyle? style]) {
    _version++;
    style ??= CursorStyle.empty;

    _combined?.clear();

    if (start > 0 && getWidth(start - 1) == 2) {
      eraseCell(start - 1, style);
    }

    if (start + count < _length) {
      final moveStart = start * _cellSize;
      final moveEnd = (_length - count) * _cellSize;
      final moveOffset = count * _cellSize;
      for (var i = moveEnd - 1; i >= moveStart; i--) {
        _data[i + moveOffset] = _data[i];
      }
    }

    final end = min(start + count, _length);
    for (var i = start; i < end; i++) {
      eraseCell(i, style);
    }

    if (getWidth(_length - 1) == 2) {
      eraseCell(_length - 1, style);
    }

    // Update anchors, move anchors that are after the inserted range.
    for (var i = 0; i < _anchors.length; i++) {
      final anchor = _anchors[i];
      if (anchor.x >= start + count) {
        anchor.reposition(anchor.x + count);

        // Remove anchors that are now outside the buffer.
        if (anchor.x >= _length) {
          anchor.dispose();
        }
      }
    }
  }

  void resize(int length) {
    assert(length >= 0);

    if (length == _length) {
      return;
    }

    _version++;

    if (length > _length) {
      final newBufferSize = _calcCapacity(length) * _cellSize;

      if (newBufferSize > _data.length) {
        final newBuffer = Uint32List(newBufferSize);
        newBuffer.setRange(0, _data.length, _data);
        _data = newBuffer;
      }
    }

    _length = length;

    for (var i = 0; i < _anchors.length; i++) {
      final anchor = _anchors[i];
      if (anchor.x > _length) {
        anchor.reposition(_length);
      }
    }
  }

  /// Returns the offset of the last cell that has content from the start of
  /// the line.
  int getTrimmedLength([int? cols]) {
    if (cols == null || cols > _length) {
      cols = _length;
    }

    if (cols <= 0) {
      return 0;
    }

    for (var i = cols - 1; i >= 0; i--) {
      var codePoint = getCodePoint(i);

      if (codePoint != 0) {
        // Last cell with content, so the length is its index plus its width.
        final lastCellWidth = getWidth(i);
        return i + lastCellWidth;
      }
    }
    return 0;
  }

  /// Copies [len] cells from [src] starting at [srcCol] to [dstCol] at this
  /// line.
  void copyFrom(BufferLine src, int srcCol, int dstCol, int len) {
    _version++;
    resize(dstCol + len);

    var srcOffset = srcCol * _cellSize;
    var dstOffset = dstCol * _cellSize;

    for (var i = 0; i < len * _cellSize; i++) {
      _data[dstOffset++] = src._data[srcOffset++];
    }

    final srcCombined = src._combined;
    for (var i = 0; i < len; i++) {
      final value = srcCombined?[srcCol + i];
      if (value != null) {
        (_combined ??= {})[dstCol + i] = value;
      } else {
        _combined?.remove(dstCol + i);
      }
    }
  }

  /// Rounds [length] up to the allocation granularity so a line growing a
  /// column at a time doesn't reallocate on every step.
  ///
  /// A flat 32-cell step rather than doubling: at 80 columns doubling rounded
  /// up to 128 cells, leaving a third of a 10k-line scrollback never written.
  static int _calcCapacity(int length) {
    assert(length >= 0);

    if (length <= 32) return 32;

    return (length + 31) & ~31;
  }

  /// The text of this line between [from] and [to].
  ///
  /// A cell holds no code point in three different situations, and only one of
  /// them means "nothing is here": the second half of a double-width glyph,
  /// which belongs to the glyph before it; a cell the program skipped over
  /// with a tab or a cursor move rather than writing a space into; and a cell
  /// that was erased. The last two are blanks on screen and are blanks here
  /// too - dropping them is what turned a copied `a<tab>b` into `ab`.
  ///
  /// Blanks are held back until a glyph follows, so a selection that runs past
  /// the end of the text does not come back padded with spaces.
  String getText([int? from, int? to]) {
    if (from == null || from < 0) {
      from = 0;
    }

    if (to == null || to > _length) {
      to = _length;
    }

    final builder = StringBuffer();
    var pendingBlanks = 0;
    for (var i = from; i < to; i++) {
      final codePoint = getCodePoint(i);
      final width = getWidth(i);
      if (codePoint == 0) {
        final continuesWideGlyph = i > 0 && getWidth(i - 1) == 2;
        if (!continuesWideGlyph) pendingBlanks++;
        continue;
      }
      // A wide glyph the range cuts in half belongs to neither side.
      if (i + width > to) continue;
      for (var blank = 0; blank < pendingBlanks; blank++) {
        builder.writeCharCode(0x20);
      }
      pendingBlanks = 0;
      builder.writeCharCode(codePoint);
      final combined = _combined?[i];
      if (combined != null) builder.write(combined);
    }

    return builder.toString();
  }

  CellAnchor createAnchor(int offset) {
    final anchor = CellAnchor(offset, owner: this);
    _anchors.add(anchor);
    return anchor;
  }

  void dispose() {
    for (final anchor in _anchors) {
      anchor.dispose();
    }
  }

  @override
  String toString() {
    return getText();
  }
}

/// A handle to a cell in a [BufferLine] that can be used to track the location
/// of the cell. Anchors are guaranteed to be stable, retaining their relative
/// position to each other after mutations to the buffer.
class CellAnchor {
  CellAnchor(int offset, {BufferLine? owner})
      : _offset = offset,
        _owner = owner;

  int _offset;

  int get x {
    return _offset;
  }

  int get y {
    assert(attached);
    return _owner!.index;
  }

  CellOffset get offset {
    assert(attached);
    return CellOffset(_offset, _owner!.index);
  }

  BufferLine? _owner;

  BufferLine? get line => _owner;

  bool get attached => _owner?.attached ?? false;

  void reparent(BufferLine owner, int offset) {
    _owner?._anchors.remove(this);
    _owner = owner;
    _owner?._anchors.add(this);
    _offset = offset;
  }

  void reposition(int offset) {
    _offset = offset;
  }

  void dispose() {
    _owner?._anchors.remove(this);
    _owner = null;
  }

  @override
  String toString() {
    if (attached) {
      return 'CellAnchor($x, $y)';
    } else {
      return 'CellAnchor($x, detached)';
    }
  }
}
