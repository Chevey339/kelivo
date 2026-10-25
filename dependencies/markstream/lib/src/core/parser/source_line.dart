import '../ast/nodes.dart';
import '../ast/source_span.dart';

/// One physical source line; line endings are retained in source coordinates.
final class SourceLine {
  const SourceLine(this.source, this.start, this.end, this.next);
  final String source;
  final int start;
  final int end;
  final int next;

  String get text => source.substring(start, end);

  static Iterable<SourceLine> scan(
    String source, {
    int start = 0,
    bool unicodeLineBreaks = false,
  }) sync* {
    var offset = start;
    while (offset < source.length) {
      final beginning = offset;
      while (offset < source.length) {
        final unit = source.codeUnitAt(offset);
        if (unit == 10 ||
            unit == 13 ||
            (unicodeLineBreaks && (unit == 0x2028 || unit == 0x2029)))
          break;
        offset++;
      }
      final end = offset;
      if (offset < source.length) {
        final cr = source.codeUnitAt(offset++) == 13;
        if (cr && offset < source.length && source.codeUnitAt(offset) == 10)
          offset++;
      }
      yield SourceLine(source, beginning, end, offset);
    }
  }
}

/// Consumes container indentation without expanding tabs in the content itself.
final class LineCursor {
  LineCursor(this.line) : offset = line.start;
  final SourceLine line;
  int offset;
  int column = 0;
  int _tabSpaces = 0;
  int _tabOffset = 0;

  bool get atEnd => offset >= line.end && _tabSpaces == 0;
  String get rest =>
      '${' ' * _tabSpaces}${line.source.substring(offset, line.end)}';
  int get sourceOffset => _tabSpaces > 0 ? _tabOffset : offset;

  ({int width, int end}) get indentation {
    var width = _tabSpaces;
    var index = offset;
    while (index < line.end) {
      final char = line.source.codeUnitAt(index);
      if (char == 32) {
        width++;
      } else if (char == 9) {
        width += 4 - (column + width) % 4;
      } else {
        break;
      }
      index++;
    }
    return (width: width, end: index);
  }

  bool get blank => indentation.end == line.end;

  void indent(int width) {
    var remaining = width;
    while (remaining > 0 && !atEnd) {
      if (_tabSpaces > 0) {
        final consumed = remaining < _tabSpaces ? remaining : _tabSpaces;
        _tabSpaces -= consumed;
        remaining -= consumed;
        column += consumed;
        continue;
      }
      final char = line.source.codeUnitAt(offset);
      if (char == 32) {
        offset++;
        column++;
        remaining--;
      } else if (char == 9) {
        _tabOffset = offset++;
        _tabSpaces = 4 - column % 4;
      } else {
        break;
      }
    }
  }

  void advance(int characters) {
    assert(_tabSpaces == 0);
    for (var i = 0; i < characters && offset < line.end; i++) {
      column += line.source.codeUnitAt(offset++) == 9 ? 4 - column % 4 : 1;
    }
  }

  List<TextNode> textFragments() => [
    if (_tabSpaces > 0)
      TextNode(
        span: SourceSpan(_tabOffset, _tabOffset + 1),
        text: ' ' * _tabSpaces,
      ),
    if (offset < line.end)
      TextNode(
        span: SourceSpan(offset, line.end),
        text: line.source
            .substring(offset, line.end)
            .replaceAll('\u0000', '\uFFFD'),
      ),
  ];
}
