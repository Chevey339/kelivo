/// A half-open interval of UTF-16 code-unit offsets in the original source.
final class SourceSpan {
  const SourceSpan(this.start, this.end) : assert(start >= 0 && end >= start);

  final int start;
  final int end;
  int get length => end - start;
  bool get isEmpty => start == end;
  bool contains(int offset) => start <= offset && offset < end;
  bool overlaps(SourceSpan other) =>
      !isEmpty && !other.isEmpty && start < other.end && other.start < end;
  String slice(String source) => source.substring(start, end);
  SourceSpan shift(int delta) => SourceSpan(start + delta, end + delta);

  Map<String, int> toJson() => {'start': start, 'end': end};

  @override
  bool operator ==(Object other) =>
      other is SourceSpan && start == other.start && end == other.end;

  @override
  int get hashCode => Object.hash(start, end);

  @override
  String toString() => 'SourceSpan($start, $end)';
}
