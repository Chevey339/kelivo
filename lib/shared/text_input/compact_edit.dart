/// One replacement equivalent to a sequence of UTF-16 native replacements.
/// Only materializes their affected span, not a full document per operation.
class CompactEdit {
  const CompactEdit(this.start, this.end, this.text);
  final int start;
  final int end;
  final String text;

  static CompactEdit? coalesce(String original, List<Object?> patches) {
    if (patches.isEmpty) return null;
    var start = 0, end = 0;
    var segment = '';
    var first = true;
    for (final entry in patches) {
      final patch = entry as List;
      final left = (patch[0] as num).toInt();
      final right = (patch[1] as num).toInt();
      final inserted = patch[2] as String;
      final currentLength = original.length - (end - start) + segment.length;
      if (left < 0 || right < left || right > currentLength) {
        throw StateError('Patch outside authoritative text');
      }
      if (first) {
        start = left;
        end = right;
        segment = inserted;
        first = false;
        continue;
      }
      final oldStart = start;
      final spanEnd = oldStart + segment.length;
      if (left < oldStart) {
        segment = original.substring(left, oldStart) + segment;
        start = left;
      }
      if (right > spanEnd) {
        final nextEnd = end + right - spanEnd;
        segment += original.substring(end, nextEnd);
        end = nextEnd;
      }
      segment = segment.replaceRange(left - start, right - start, inserted);
    }
    return CompactEdit(start, end, segment);
  }
}
