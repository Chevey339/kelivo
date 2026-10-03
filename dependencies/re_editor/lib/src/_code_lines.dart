part of 're_editor.dart';

class _CodeLineSegmentQuckLineCount extends CodeLineSegment {

  late int _lineCount;

  _CodeLineSegmentQuckLineCount({
    required super.codeLines,
    required super.dirty,
    int? cachedLineCount,
  }) {
    _lineCount = cachedLineCount ?? super.lineCount;
  }

  @override
  int get lineCount => _lineCount;

  @override
  set length(int newLength) {
    super.length = newLength;
    _lineCount = super.lineCount;
  }

  @override
  void add(CodeLine element) {
    super.add(element);
    _lineCount += element.lineCount;
  }

  @override
  void operator []=(int index, CodeLine value) {
    final int previous = super[index].lineCount;
    super[index] = value;
    _lineCount += value.lineCount - previous;
  }

  @override
  CodeLineSegment copyWith({List<CodeLine>? codeLines, bool? dirty}) {
    final List<CodeLine> lines = codeLines ?? this.codeLines;
    return _CodeLineSegmentQuckLineCount(
      codeLines: lines,
      dirty: dirty ?? this.dirty,
      cachedLineCount: identical(lines, this.codeLines) ? _lineCount : null,
    );
  }

}
