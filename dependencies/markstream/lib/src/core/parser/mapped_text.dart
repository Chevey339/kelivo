import '../ast/nodes.dart';
import '../ast/source_span.dart';

/// Text after container prefixes and normalized newlines, mapped to its source.
final class MappedText {
  MappedText(List<TextNode> fragments)
    : fragments = List.unmodifiable(fragments),
      text = fragments.map((f) => f.text).join() {
    var offset = 0;
    for (final fragment in fragments) {
      _starts.add(offset);
      offset += fragment.text.length;
    }
  }
  final List<TextNode> fragments;
  final String text;
  final _starts = <int>[];

  SourceSpan span(int start, int end) =>
      SourceSpan(_offset(start, false), _offset(end, start != end));

  int _offset(int offset, bool end) {
    if (fragments.isEmpty) return 0;
    if (offset <= 0) return fragments.first.span.start;
    if (offset >= text.length) return fragments.last.span.end;
    final index = _index(offset, end);
    final fragment = fragments[index];
    final relative = offset - _starts[index];
    if (fragment.text.isEmpty) return fragment.span.start;
    final scaled = relative * fragment.span.length / fragment.text.length;
    return fragment.span.start + (end ? scaled.ceil() : scaled.floor());
  }

  int _index(int offset, bool end) {
    var low = 0;
    var high = _starts.length;
    while (low < high) {
      final mid = (low + high) ~/ 2;
      if (_starts[mid] < offset || (!end && _starts[mid] == offset)) {
        low = mid + 1;
      } else {
        high = mid;
      }
    }
    return low == 0 ? 0 : low - 1;
  }

  List<TextNode> slice(int start, int end) {
    final result = <TextNode>[];
    if (start == end || fragments.isEmpty) return result;
    for (var i = _index(start, false); i < fragments.length; i++) {
      final a = start > _starts[i] ? start : _starts[i];
      final boundary = _starts[i] + fragments[i].text.length;
      final b = end < boundary ? end : boundary;
      if (a < b)
        result.add(TextNode(span: span(a, b), text: text.substring(a, b)));
      if (boundary >= end) break;
    }
    return result;
  }
}
