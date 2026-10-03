part of 're_editor.dart';

const int _kCodeLineSegamentDefaultSize = 256;

class CodeLines {

  final List<CodeLineSegment> segments;

  const CodeLines(this.segments);

  factory CodeLines.empty() {
    return CodeLines.of([]);
  }

  factory CodeLines.fromText(String text) {
    return text.codeLines;
  }

  factory CodeLines.from(CodeLines codeLines) {
    final List<CodeLineSegment> segments = [];
    for (final CodeLineSegment segment in codeLines.segments) {
      if (segment.isEmpty) {
        continue;
      }
      segments.add(segment.copyWith(
        dirty: true
      ));
    }
    return CodeLines(segments);
  }

  factory CodeLines.of(Iterable<CodeLine> elements) {
    final List<CodeLineSegment> segments = [];
    int count = 0;
    for (int i = 0; i < elements.length; i++) {
      if (count == 0) {
        segments.add(CodeLineSegment.of(codeLines: []));
      }
      segments.last.add(elements.elementAt(i));
      count++;
      if (count >= _kCodeLineSegamentDefaultSize) {
        count = 0;
      }
    }
    return CodeLines(segments);
  }

  CodeLine get first => segments.first.first;

  CodeLine get last => segments.last.last;

  int get length => segments.fold(0, (previousValue, element) => previousValue += element.length);

  bool get isEmpty => segments.isEmpty || length == 0;

  bool get isNotEmpty => !isEmpty;

  int get lineCount => segments.fold(0, (previousValue, element) => previousValue += element.lineCount);

  CodeLine operator [](int index) {
    int offset = 0;
    for (final CodeLineSegment segment in segments) {
      if (index - offset >= segment.length) {
        offset += segment.length;
      } else {
        return segment[index - offset];
      }
    }
    throw RangeError.range(index, 0, length - 1);
  }

  void operator []=(int index, CodeLine value) {
    int offset = 0;
    for (int i = 0; i < segments.length; i++) {
      CodeLineSegment segment = segments[i];
      if (index - offset >= segment.length) {
        offset += segment.length;
      } else {
        if (segment.dirty) {
          segment = segment.clone();
          segments[i] = segment;
        }
        segment[index - offset] = value;
        return;
      }
    }
    throw RangeError.range(index, 0, length - 1);
  }

  void add(CodeLine value) {
    if (isEmpty || segments.last.length >= _kCodeLineSegamentDefaultSize) {
      segments.add(CodeLineSegment.of(
        codeLines: [
          value
        ]
      ));
    } else {
      CodeLineSegment segment = segments.last;
      if (segment.dirty) {
        segment = segment.clone();
        segments.last = segment;
      }
      segment.add(value);
    }
  }

  void addAll(Iterable<CodeLine> iterable) {
    if (isEmpty) {
      segments.addAll(CodeLines.of(iterable).segments);
      return;
    }
    final CodeLineSegment segment = segments.last;
    int count;
    if (segment.length >= _kCodeLineSegamentDefaultSize) {
      count = 0;
    } else {
      count = segment.length;
      if (segment.dirty) {
        segments.last = segment.clone();
      }
    }
    for (int i = 0; i < iterable.length; i++) {
      if (count == 0) {
        segments.add(CodeLineSegment.of(codeLines: []));
      }
      segments.last.add(iterable.elementAt(i));
      count++;
      if (count >= _kCodeLineSegamentDefaultSize) {
        count = 0;
      }
    }
  }

  void addFrom(CodeLines codeLines, int start, [int? end]) {
    final CodeLines sub = codeLines.sublines(start, end);
    if (sub.isEmpty) {
      return;
    }
    if (isEmpty) {
      segments.addAll(sub.segments);
      return;
    }
    final List<CodeLineSegment> appendSegments = sub.segments;
    for (int i = 0; i < appendSegments.length; i++) {
      CodeLineSegment tail = segments.last;
      final CodeLineSegment appendSegment = appendSegments[i];
      if (tail.length + appendSegment.length <= _kCodeLineSegamentDefaultSize) {
        if (tail.dirty) {
          tail = tail.clone();
          segments.last = tail;
        }
        tail.addAll(appendSegment);
      } else {
        segments.add(appendSegment);
      }
    }
  }

  bool equals(CodeLines? codeLines) {
    if (codeLines == null) {
      return false;
    }
    // Quick comparation
    if (isEmpty && codeLines.isEmpty) {
      return true;
    }
    if (isEmpty && codeLines.isNotEmpty) {
      return false;
    }
    if (isNotEmpty && codeLines.isEmpty) {
      return false;
    }
    if (first != codeLines.first) {
      return false;
    }
    if (last != codeLines.last) {
      return false;
    }
    final int length1 = length;
    final int length2 = codeLines.length;
    if (length1 != length2) {
      return false;
    }
    final int minSegmentLength = min(segments.length, codeLines.segments.length);
    int offset = 0;
    for (int i = 0; i < minSegmentLength; i++) {
      if (segments[i].length != codeLines.segments[i].length) {
        break;
      }
      if (!listEquals(segments[i].codeLines, codeLines.segments[i].codeLines)) {
        return false;
      }
      offset += segments[i].length;
    }
    // The worst is the distributions are different, we should compare them one by one
    for (int i = offset; i < length1; i++) {
      if (this[i] != codeLines[i]) {
        return false;
      }
    }
    return true;
  }

  CodeLines sublines(int start, [int? end]) {
    end ??= length;
    if (end > length) {
      throw RangeError.range(end, 0, length - 1);
    }
    if (start > end) {
      throw RangeError('start $start should be less than end $end');
    }
    if (start == end) {
      return CodeLines.empty();
    }
    final List<CodeLineSegment> newSegments = [];
    int offset = 0;
    for (final CodeLineSegment segment in segments) {
      if (start - offset >= segment.length) {
        offset += segment.length;
        continue;
      }
      if (start <= offset) {
        if (end - offset >= segment.length) {
          newSegments.add(segment.copyWith(
            dirty: true
          ));
          offset += segment.length;
          continue;
        } else {
          if (end > offset) {
            newSegments.add(segment.clone(0, end - offset));
          }
          break;
        }
      } else {
        if (end - offset >= segment.length) {
          newSegments.add(segment.clone(start - offset, segment.length));
          offset += segment.length;
          continue;
        } else {
          newSegments.add(segment.clone(start - offset, end - offset));
          break;
        }
      }
    }
    return CodeLines(newSegments);
  }

  void clear() {
    segments.clear();
  }

  String asString(TextLineBreak lineBreak, [bool expandChunks = true]) {
    final StringBuffer sb = StringBuffer();
    final int length = this.length;
    int count = 0;
    for (final CodeLineSegment segment in segments) {
      for (final CodeLine codeLine in segment.codeLines) {
        count++;
        if (expandChunks) {
          sb.write(codeLine.asString(0, lineBreak));
        } else {
          sb.write(codeLine.text);
        }
        if (count != length) {
          sb.write(lineBreak.value);
        }
      }
    }
    return sb.toString();
  }

  int index2lineIndex(int index) {
    if (index < 0 || index >= length) {
      return -1;
    }
    int lineIndex = 0;
    int offset = 0;
    for (final CodeLineSegment segment in segments) {
      if (index - offset >= segment.length) {
        offset += segment.length;
        lineIndex += segment.lineCount;
      } else {
        for (int j = 0; j < index - offset; j++) {
          lineIndex += segment[j].lineCount;
        }
        break;
      }
    }
    return lineIndex;
  }

  CodeLineIndex lineIndex2Index(int lineIndex) {
    if (lineIndex < 0) {
      return const CodeLineIndex(-1, -1);
    }
    // Find the segment first
    int segmentIndex = -1;
    int lineCount = 0;
    for (int i = 0, start = 0; i < segments.length; i++) {
      final int end = start + segments[i].lineCount;
      if (lineIndex >= start && lineIndex < end) {
        segmentIndex = i;
        lineIndex -= start;
        break;
      }
      start = end;
      lineCount += segments[i].length;
    }
    if (segmentIndex < 0) {
      return const CodeLineIndex(-1, -1);
    }
    // Find the index in the segment
    final List<CodeLine> codeLines = segments[segmentIndex].codeLines;
    int index = -1;
    int start = 0;
    for (int i = 0; i < codeLines.length; i++) {
      final int end = start + codeLines[i].lineCount;
      if (lineIndex >= start && lineIndex < end) {
        index = i;
        start++;
        break;
      }
      start = end;
    }
    if (index == -1) {
      return const CodeLineIndex(-1, -1);
    }
    // Find the index in the chunk
    int chunkIndex = -1;
    final List<CodeLine> chunks = codeLines[index].chunks;
    for (int i = 0; i < chunks.length; i++) {
      final int end = start + chunks[i].lineCount;
      if (lineIndex >= start && lineIndex < end) {
        chunkIndex = i;
        break;
      }
      start = end;
    }
    return CodeLineIndex(index + lineCount, chunkIndex);
  }

  List<CodeLine> toList() {
    final List<CodeLine> codeLines = [];
    for (final CodeLineSegment segment in segments) {
      codeLines.addAll(segment.codeLines);
    }
    return codeLines;
  }

  @override
  int get hashCode => segments.hashCode;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is CodeLines
        && listEquals(other.segments, segments);
  }

  @override
  String toString() {
    return '[ ${segments.join(',')} ]';
  }

}

class CodeLineSegment with ListMixin<CodeLine> {

  final List<CodeLine> codeLines;
  final bool dirty;

  const CodeLineSegment({
    required this.codeLines,
    this.dirty = false
  });

  factory CodeLineSegment.of({
    required List<CodeLine> codeLines,
    bool dirty = false
  }) => _CodeLineSegmentQuckLineCount(
    codeLines: codeLines,
    dirty: dirty
  );

  @override
  int get length  => codeLines.length;

  int get lineCount => codeLines.fold(0, (previousValue, element) => previousValue += element.lineCount);

  @override
  CodeLine operator [](int index) {
    return codeLines[index];
  }

  @override
  void operator []=(int index, CodeLine value) {
    if (dirty) {
      // Not support write operation
      throw UnimplementedError();
    } else {
      codeLines[index] = value;
    }
  }

  @override
  set length(int newLength) {
    if (dirty) {
      // Not support write operation
      throw UnimplementedError();
    } else {
      codeLines.length = newLength;
    }
  }

  @override
  void add(CodeLine element) {
    if (dirty) {
      // Not support write operation
      throw UnimplementedError();
    } else {
      codeLines.add(element);
    }
  }

  CodeLineSegment clone([int start = 0, int? end]) => CodeLineSegment.of(
    codeLines: codeLines.sublist(start, end)
  );

  CodeLineSegment copyWith({
    List<CodeLine>? codeLines,
    bool? dirty,
  }) {
    return CodeLineSegment.of(
      codeLines: codeLines ?? this.codeLines,
      dirty: dirty ?? this.dirty
    );
  }

  @override
  int get hashCode => Object.hash(codeLines, lineCount, dirty);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is CodeLineSegment
        && listEquals(other.codeLines, codeLines)
        && other.lineCount == lineCount
        && other.dirty == dirty;
  }

  @override
  String toString() {
    return '[ ${join(',')} ]';
  }

}