import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/painting.dart';

import 'package:terminal_view/src/ui/palette_builder.dart';
import 'package:terminal_view/src/ui/paragraph_cache.dart';
import 'package:terminal_view/src/utils/hash_values.dart';
import 'package:terminal_view/terminal_view.dart';

/// Lowest code point that [TerminalPainter] will batch into a shared run.
const _kBatchableMin = 0x20;

/// One past the highest batchable code point. A shared paragraph assumes every
/// glyph advances exactly one cell, which only holds for ASCII in a monospace
/// font - a fallback font may return any width for symbol and CJK ranges.
const _kBatchableEnd = 0x7f;

/// Encapsulates the logic for painting various terminal elements.
class TerminalPainter {
  TerminalPainter({
    required TerminalTheme theme,
    required TerminalStyle textStyle,
    required TextScaler textScaler,
  })  : _textStyle = textStyle,
        _theme = theme,
        _textScaler = textScaler;

  /// A lookup table from terminal colors to Flutter colors.
  late var _colorPalette = PaletteBuilder(_theme).build();

  /// Size of each character in the terminal.
  late var _cellSize = _measureCharSize();

  /// The cached for cells in the terminal. Should be cleared when the same
  /// cell no longer produces the same visual output. For example, when
  /// [_textStyle] is changed, or when the system font changes.
  final _paragraphCache = ParagraphCache(2048);

  /// Code points of the run being assembled. Reused so painting a frame does
  /// not allocate; grown on demand for terminals wider than its initial size.
  var _runBuffer = Uint32List(256);

  /// Whether blinking text should currently be drawn or hidden this frame.
  bool blinkVisible = true;

  /// Reused across every rect painted in a frame - [Canvas] reads the paint at
  /// call time.
  final _fillPaint = Paint();

  /// Recorded drawings of lines that have not changed lately. Sized to cover a
  /// viewport plus the lines either side that a scroll drags past.
  final _lineCache = _LinePictureCache(192);

  TerminalStyle get textStyle => _textStyle;
  TerminalStyle _textStyle;
  set textStyle(TerminalStyle value) {
    if (value == _textStyle) return;
    _textStyle = value;
    _cellSize = _measureCharSize();
    _paragraphCache.clear();
    _lineCache.clear();
  }

  TextScaler get textScaler => _textScaler;
  TextScaler _textScaler = TextScaler.linear(1.0);
  set textScaler(TextScaler value) {
    if (value == _textScaler) return;
    _textScaler = value;
    _cellSize = _measureCharSize();
    _paragraphCache.clear();
    _lineCache.clear();
  }

  TerminalTheme get theme => _theme;
  TerminalTheme _theme;
  set theme(TerminalTheme value) {
    if (value == _theme) return;
    _theme = value;
    _colorPalette = PaletteBuilder(value).build();
    _paragraphCache.clear();
    _lineCache.clear();
  }

  Size _measureCharSize() {
    const test = 'mmmmmmmmmm';

    final textStyle = _textStyle.toTextStyle();
    final builder = ParagraphBuilder(
      textStyle.getParagraphStyle(
        strutStyle: _textStyle.toStrutStyle(),
        textScaler: _textScaler,
      ),
    );
    builder.pushStyle(
      textStyle.getTextStyle(textScaler: _textScaler),
    );
    builder.addText(test);

    final paragraph = builder.build();
    paragraph.layout(ParagraphConstraints(width: double.infinity));

    final result = Size(
      paragraph.maxIntrinsicWidth / test.length,
      paragraph.height,
    );

    paragraph.dispose();
    return result;
  }

  /// The size of each character in the terminal.
  Size get cellSize => _cellSize;

  /// When the set of font available to the system changes, call this method to
  /// clear cached state related to font rendering.
  void clearFontCache() {
    _cellSize = _measureCharSize();
    _paragraphCache.clear();
    _lineCache.clear();
  }

  /// Paints the cursor based on the current cursor type.
  void paintCursor(
    Canvas canvas,
    Offset offset, {
    required TerminalCursorType cursorType,
    bool hasFocus = true,
  }) {
    final paint = Paint()
      ..color = _theme.cursor
      ..strokeWidth = 1;

    if (!hasFocus) {
      paint.style = PaintingStyle.stroke;
      canvas.drawRect(offset & _cellSize, paint);
      return;
    }

    switch (cursorType) {
      case TerminalCursorType.block:
        paint.style = PaintingStyle.fill;
        canvas.drawRect(offset & _cellSize, paint);
        return;
      case TerminalCursorType.underline:
        return canvas.drawLine(
          Offset(offset.dx, offset.dy + _cellSize.height - 1),
          Offset(
            offset.dx + _cellSize.width,
            offset.dy + _cellSize.height - 1,
          ),
          paint,
        );
      case TerminalCursorType.verticalBar:
        return canvas.drawLine(
          Offset(offset.dx, offset.dy),
          Offset(offset.dx, offset.dy + _cellSize.height),
          paint,
        );
    }
  }

  @pragma('vm:prefer-inline')
  void paintHighlight(Canvas canvas, Offset offset, int length, Color color) {
    final endOffset =
        offset.translate(length * _cellSize.width, _cellSize.height);

    _fillPaint.color = color;

    canvas.drawRect(
      Rect.fromPoints(offset, endOffset),
      _fillPaint,
    );
  }

  /// Paints [line] to [canvas] at [offset]. The x offset of [offset] is usually
  /// 0, and the y offset is the top of the line.
  void paintLine(
    Canvas canvas,
    Offset offset,
    BufferLine line,
  ) {
    if (_lineHasBlink(line)) {
      _paintLineDirect(canvas, offset, line);
      return;
    }

    final version = line.version;
    final entry = _lineCache.get(line);

    if (entry != null && entry.version == version) {
      var picture = entry.picture;

      if (picture == null) {
        // Held still across two frames, so recording it will pay off. On first
        // sight it would not: streaming output changes every line by the next
        // frame and the recording would never be replayed.
        final recorder = PictureRecorder();
        _paintLineDirect(Canvas(recorder), Offset.zero, line);
        picture = recorder.endRecording();
        entry.picture = picture;
      }

      canvas.save();
      canvas.translate(offset.dx, offset.dy);
      canvas.drawPicture(picture);
      canvas.restore();
      return;
    }

    _lineCache.put(line, version);
    _paintLineDirect(canvas, offset, line);
  }

  bool _lineHasBlink(BufferLine line) {
    final length = line.length;
    for (var i = 0; i < length; i++) {
      if (line.getAttributes(i) & CellFlags.blink != 0) return true;
    }
    return false;
  }

  /// Paints [line] straight onto [canvas], bypassing the picture cache.
  ///
  /// Two passes, so runs of either kind can be merged without a later cell's
  /// background covering an earlier cell's glyph.
  void _paintLineDirect(Canvas canvas, Offset offset, BufferLine line) {
    final length = line.length;
    if (length > _runBuffer.length) {
      _runBuffer = Uint32List(length);
    }

    _paintLineBackground(canvas, offset, line, length);
    _paintLineForeground(canvas, offset, line, length);
  }

  /// Fills the backgrounds of [line], merging neighbouring cells that resolve
  /// to the same color into a single rect.
  void _paintLineBackground(
    Canvas canvas,
    Offset offset,
    BufferLine line,
    int length,
  ) {
    final cellWidth = _cellSize.width;
    final cellHeight = _cellSize.height;

    // -1 when the cells seen so far had no background to paint.
    var runStart = -1;
    var runColor = const Color(0x00000000);

    for (var i = 0; i <= length; i++) {
      Color? color;

      if (i < length) {
        final flags = line.getAttributes(i);
        final background = line.getBackground(i);

        if (flags & CellFlags.inverse != 0) {
          color = resolveForegroundColor(
            line.getForeground(i),
            bold: flags & CellFlags.bold != 0,
          );
        } else if (background & CellColor.typeMask != CellColor.normal) {
          color = resolveBackgroundColor(background);
        }
      }

      if (runStart >= 0 && color == runColor) continue;

      if (runStart >= 0) {
        // The extra pixel hides the seam between runs at fractional cell
        // widths; runs paint left to right, so the next one covers it.
        _fillPaint.color = runColor;
        canvas.drawRect(
          Rect.fromLTWH(
            offset.dx + runStart * cellWidth,
            offset.dy,
            (i - runStart) * cellWidth + 1,
            cellHeight,
          ),
          _fillPaint,
        );
        runStart = -1;
      }

      if (color != null) {
        runStart = i;
        runColor = color;
      }
    }
  }

  /// Draws the glyphs of [line], batching neighbouring cells that share a style
  /// into a single paragraph where it is safe to do so.
  void _paintLineForeground(
    Canvas canvas,
    Offset offset,
    BufferLine line,
    int length,
  ) {
    final cellWidth = _cellSize.width;
    final buffer = _runBuffer;

    CellData? cellData;
    var i = 0;

    while (i < length) {
      final content = line.getContent(i);
      final charCode = content & CellContent.codepointMask;
      final charWidth = content >> CellContent.widthShift;
      final step = charWidth == 2 ? 2 : 1;

      if (charCode == 0) {
        i += step;
        continue;
      }

      if (charCode >= _kBatchableMin && charCode < _kBatchableEnd) {
        final foreground = line.getForeground(i);
        final flags = line.getAttributes(i);
        final background = line.getBackground(i);
        // Background only affects the glyph color when the cell is inverted.
        final inverse = flags & CellFlags.inverse != 0;

        var runLength = 0;
        var j = i;
        while (j < length) {
          final code = line.getContent(j) & CellContent.codepointMask;
          if (code < _kBatchableMin || code >= _kBatchableEnd) break;
          if (line.getForeground(j) != foreground) break;
          if (line.getAttributes(j) != flags) break;
          if (inverse && line.getBackground(j) != background) break;
          buffer[runLength++] = code;
          j++;
        }

        _paintRun(
          canvas,
          offset.translate(i * cellWidth, 0),
          buffer,
          runLength,
          foreground: foreground,
          background: background,
          flags: flags,
          // A batched run assumes each glyph advances exactly one cell. When
          // the font's advance differs (bold or a fallback took over), the
          // drift accumulates across the run and the glyphs walk off the
          // grid the cursor is drawn on - so correct the run to the grid.
          fitWidth: cellWidth * runLength,
        );

        i = j;
        continue;
      }

      cellData ??= CellData.empty();
      line.getCellData(i, cellData);
      paintCellForeground(
        canvas,
        offset.translate(i * cellWidth, 0),
        cellData,
        fitWidth: cellWidth * (charWidth == 2 ? 2 : 1),
        combined: line.getCombined(i),
      );
      i += step;
    }
  }

  /// Draws the first [length] code points of [codePoints] as one paragraph,
  /// starting at [offset].
  ///
  /// [fitWidth] scales the glyph horizontally onto the cells it owns. A cell is
  /// a fraction of a pixel wide and a fallback font advances by whatever it
  /// likes, so box drawing left at its natural width leaves seams between the
  /// segments of a border, and a wide symbol runs over its neighbour.
  void _paintRun(
    Canvas canvas,
    Offset offset,
    Uint32List codePoints,
    int length, {
    required int foreground,
    required int background,
    required int flags,
    double? fitWidth,
    Color? overrideColor,
  }) {
    if (overrideColor == null) {
      final invisible = flags & CellFlags.invisible != 0;
      final blinkHidden = flags & CellFlags.blink != 0 && !blinkVisible;
      if (invisible || blinkHidden) return;
    }

    final bold = flags & CellFlags.bold != 0;
    final decoration = _decorationFor(flags);
    final colorBits = overrideColor?.toARGB32() ?? 0;
    final styleKey =
        hashValues(foreground, background, flags, _textScaler, colorBits);

    var key = styleKey;
    for (var i = 0; i < length; i++) {
      key = 0x1fffffff & (key * 31 + codePoints[i]);
    }

    var paragraph = _paragraphCache.getLayoutFromCache(
      key,
      styleKey,
      codePoints,
      length,
    );

    if (paragraph == null) {
      final color = _resolveRunColor(
        overrideColor: overrideColor,
        foreground: foreground,
        background: background,
        flags: flags,
        bold: bold,
      );

      paragraph = _paragraphCache.performAndCacheLayout(
        codePoints,
        length,
        _textStyle.toTextStyle(
          color: color,
          bold: bold,
          italic: flags & CellFlags.italic != 0,
          decoration: decoration,
        ),
        _textStyle.toStrutStyle(),
        _textScaler,
        key,
        styleKey,
      );
    }

    if (fitWidth != null) {
      final naturalWidth = paragraph.maxIntrinsicWidth;
      final delta = fitWidth - naturalWidth;
      if (naturalWidth > 0 && delta.abs() > 0.05) {
        final spacing = delta / length;
        final spacingKey = 0x1fffffff & (key * 31 + (spacing * 100).round());

        var spacedParagraph = _paragraphCache.getLayoutFromCache(
          spacingKey,
          styleKey,
          codePoints,
          length,
        );

        if (spacedParagraph == null) {
          final color = _resolveRunColor(
            overrideColor: overrideColor,
            foreground: foreground,
            background: background,
            flags: flags,
            bold: bold,
          );

          spacedParagraph = _paragraphCache.performAndCacheLayout(
            codePoints,
            length,
            _textStyle.toTextStyle(
              color: color,
              bold: bold,
              italic: flags & CellFlags.italic != 0,
              decoration: decoration,
              letterSpacing: spacing,
            ),
            _textStyle.toStrutStyle(),
            _textScaler,
            spacingKey,
            styleKey,
          );
        }

        canvas.drawParagraph(spacedParagraph, offset);
        return;
      }
    }

    canvas.drawParagraph(paragraph, offset);
  }

  Color _resolveRunColor({
    required Color? overrideColor,
    required int foreground,
    required int background,
    required int flags,
    required bool bold,
  }) {
    if (overrideColor != null) return overrideColor;

    final inverse = flags & CellFlags.inverse != 0;
    var color = inverse
        ? resolveBackgroundColor(background)
        : resolveForegroundColor(foreground, bold: bold);

    if (flags & CellFlags.faint != 0) {
      color = color.withValues(alpha: 0.5);
    }

    if (_theme.minimumContrastRatio > 1.0) {
      final bgColor = inverse
          ? resolveForegroundColor(foreground, bold: bold)
          : resolveBackgroundColor(background);
      color = _ensureContrast(color, bgColor, _theme.minimumContrastRatio);
    }

    return color;
  }

  /// Underline ([CellFlags.underline]) is parsed and tracked like every other
  /// attribute but never drawn: it lands on the baseline of a grid whose rows
  /// are exactly one line tall, where it runs into the descenders above it and
  /// into the cursor and the selection below. Everything that emits it - man
  /// pages, `ls` colours, hyperlinks - says the same thing with colour too.
  TextDecoration _decorationFor(int flags) =>
      flags & CellFlags.strikethrough != 0
      ? TextDecoration.lineThrough
      : TextDecoration.none;

  double _contrastRatio(Color a, Color b) {
    final la = a.computeLuminance();
    final lb = b.computeLuminance();
    final lighter = la > lb ? la : lb;
    final darker = la > lb ? lb : la;
    return (lighter + 0.05) / (darker + 0.05);
  }

  Color _ensureContrast(Color fg, Color bg, double minRatio) {
    if (_contrastRatio(fg, bg) >= minRatio) return fg;

    final towardsWhite = bg.computeLuminance() < 0.5;
    final extreme =
        towardsWhite ? const Color(0xFFFFFFFF) : const Color(0xFF000000);

    if (_contrastRatio(extreme, bg) < minRatio) return extreme;

    var lo = 0.0;
    var hi = 1.0;
    var best = extreme;
    for (var i = 0; i < 8; i++) {
      final mid = (lo + hi) / 2;
      final candidate = Color.lerp(fg, extreme, mid)!;
      if (_contrastRatio(candidate, bg) >= minRatio) {
        best = candidate;
        hi = mid;
      } else {
        lo = mid;
      }
    }
    return best;
  }

  @pragma('vm:prefer-inline')
  void paintCell(Canvas canvas, Offset offset, CellData cellData) {
    paintCellBackground(canvas, offset, cellData);
    paintCellForeground(canvas, offset, cellData);
  }

  void paintCellForeground(
    Canvas canvas,
    Offset offset,
    CellData cellData, {
    double? fitWidth,
    String? combined,
  }) {
    final charCode = cellData.content & CellContent.codepointMask;
    if (charCode == 0) return;

    Uint32List codePoints;
    int length;

    if (combined != null && combined.isNotEmpty) {
      final runes = combined.runes.toList(growable: false);
      final needed = 1 + runes.length;
      if (needed > _graphemeBuffer.length) {
        _graphemeBuffer = Uint32List(needed);
      }
      _graphemeBuffer[0] = charCode;
      for (var i = 0; i < runes.length; i++) {
        _graphemeBuffer[i + 1] = runes[i];
      }
      codePoints = _graphemeBuffer;
      length = needed;
    } else {
      _singleCellBuffer[0] = charCode;
      codePoints = _singleCellBuffer;
      length = 1;
    }

    _paintRun(
      canvas,
      offset,
      codePoints,
      length,
      foreground: cellData.foreground,
      background: cellData.background,
      flags: cellData.flags,
      fitWidth: fitWidth,
    );
  }

  void paintCellForegroundColor(
    Canvas canvas,
    Offset offset,
    CellData cellData,
    Color color,
  ) {
    final charCode = cellData.content & CellContent.codepointMask;
    if (charCode == 0) return;

    _singleCellBuffer[0] = charCode;
    final doubleWidth = cellData.content >> CellContent.widthShift == 2;

    _paintRun(
      canvas,
      offset,
      _singleCellBuffer,
      1,
      foreground: cellData.foreground,
      background: cellData.background,
      flags: cellData.flags,
      fitWidth: _cellSize.width * (doubleWidth ? 2 : 1),
      overrideColor: color,
    );
  }

  /// Kept apart from [_runBuffer] so painting one cell cannot disturb a run
  /// being assembled.
  final _singleCellBuffer = Uint32List(1);

  var _graphemeBuffer = Uint32List(16);

  /// Paints the background of a cell represented by [cellData] to [canvas] at
  /// [offset].
  @pragma('vm:prefer-inline')
  void paintCellBackground(Canvas canvas, Offset offset, CellData cellData) {
    late Color color;
    final colorType = cellData.background & CellColor.typeMask;

    if (cellData.flags & CellFlags.inverse != 0) {
      color = resolveForegroundColor(
        cellData.foreground,
        bold: cellData.flags & CellFlags.bold != 0,
      );
    } else if (colorType == CellColor.normal) {
      return;
    } else {
      color = resolveBackgroundColor(cellData.background);
    }

    _fillPaint.color = color;
    final doubleWidth = cellData.content >> CellContent.widthShift == 2;
    final widthScale = doubleWidth ? 2 : 1;
    final size = Size(_cellSize.width * widthScale + 1, _cellSize.height);
    canvas.drawRect(offset & size, _fillPaint);
  }

  /// Releases everything this painter is holding on to.
  void dispose() {
    _paragraphCache.clear();
    _lineCache.clear();
  }

  /// Get the effective foreground color for a cell from information encoded in
  /// [cellColor].
  @pragma('vm:prefer-inline')
  Color resolveForegroundColor(int cellColor, {bool bold = false}) {
    final colorType = cellColor & CellColor.typeMask;
    var colorValue = cellColor & CellColor.valueMask;

    if (bold &&
        _theme.drawBoldTextInBrightColors &&
        colorType == CellColor.named &&
        colorValue < 8) {
      colorValue += 8;
    }

    switch (colorType) {
      case CellColor.normal:
        return _theme.foreground;
      case CellColor.named:
      case CellColor.palette:
        return _colorPalette[colorValue];
      case CellColor.rgb:
      default:
        return Color(colorValue | 0xFF000000);
    }
  }

  /// Get the effective background color for a cell from information encoded in
  /// [cellColor].
  @pragma('vm:prefer-inline')
  Color resolveBackgroundColor(int cellColor) {
    final colorType = cellColor & CellColor.typeMask;
    final colorValue = cellColor & CellColor.valueMask;

    switch (colorType) {
      case CellColor.normal:
        return _theme.background;
      case CellColor.named:
      case CellColor.palette:
        return _colorPalette[colorValue];
      case CellColor.rgb:
      default:
        return Color(colorValue | 0xFF000000);
    }
  }
}

class _CachedLine {
  _CachedLine(this.version);

  /// The [BufferLine.version] this entry was made for.
  int version;

  /// Null until the line has held still long enough to be worth recording.
  Picture? picture;
}

/// Recorded drawings of terminal lines, keyed by line identity.
///
/// Bounded generationally like [ParagraphCache]: when the hot generation fills,
/// the previous one is dropped whole. A line that scrolled out of view and back
/// is redrawn once, which is cheaper than tracking it precisely.
class _LinePictureCache {
  _LinePictureCache(this.maximumSize);

  final int maximumSize;

  var _hot = <BufferLine, _CachedLine>{};

  var _cold = <BufferLine, _CachedLine>{};

  _CachedLine? get(BufferLine line) {
    final hit = _hot[line];
    if (hit != null) return hit;

    final promoted = _cold.remove(line);
    if (promoted != null) {
      _hot[line] = promoted;
      return promoted;
    }

    return null;
  }

  void put(BufferLine line, int version) {
    final existing = _hot[line];
    if (existing != null) {
      existing.picture?.dispose();
      existing.picture = null;
      existing.version = version;
      return;
    }

    if (_hot.length >= maximumSize) _rotate();
    _hot[line] = _CachedLine(version);
  }

  void _rotate() {
    for (final entry in _cold.values) {
      entry.picture?.dispose();
    }
    _cold = _hot;
    _hot = <BufferLine, _CachedLine>{};
  }

  void clear() {
    for (final entry in _cold.values) {
      entry.picture?.dispose();
    }
    for (final entry in _hot.values) {
      entry.picture?.dispose();
    }
    _cold = <BufferLine, _CachedLine>{};
    _hot = <BufferLine, _CachedLine>{};
  }
}
