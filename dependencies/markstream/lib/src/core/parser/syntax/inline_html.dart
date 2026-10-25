import '../../ast/nodes.dart';
import '../../html/html_fragment.dart';
import '../mapped_text.dart';
import 'html_block.dart';
import 'html_tag.dart';

({int end, List<InlineNode> nodes})? readInlineHtml(
  MappedText input,
  int start, {
  bool entities = true,
}) {
  final text = input.text;
  final tag = readHtmlTag(text, start, text.length);
  var end = text.length;
  if (tag == null) {
    if (!text.startsWith('<!--', start)) return null;
    final close = text.indexOf('-->', start + 4);
    if (close >= 0) end = close + 3;
  } else if (tag.closing) {
    end = tag.end;
  } else {
    final tracker = HtmlBlockTracker(HtmlBlockStart(rootTag: tag.name));
    tracker.feed(text, start, text.length);
    end = tracker.closedOffset ?? text.length;
  }
  return (
    end: end,
    nodes: parseHtmlFragment(input.slice(start, end), entities: entities),
  );
}
