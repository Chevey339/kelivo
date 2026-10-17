import '../../html/html_fragment.dart';
import 'html_tag.dart';

final class HtmlBlockStart {
  const HtmlBlockStart({
    this.terminator,
    this.rootTag,
    this.fullDocument = false,
    this.interrupts = true,
  });
  final String? terminator;
  final String? rootTag;
  final bool fullDocument;
  final bool interrupts;
}

HtmlBlockStart? matchHtmlBlock(String source, int start, int end) {
  if (start >= end || source.codeUnitAt(start) != 60) return null;
  final text = source.substring(start, end);
  final lower = text.toLowerCase();
  if (lower.startsWith('<!doctype html'))
    return const HtmlBlockStart(rootTag: 'html', fullDocument: true);
  if (text.startsWith('<!--')) return const HtmlBlockStart(terminator: '-->');
  if (text.startsWith('<?')) return const HtmlBlockStart(terminator: '?>');
  if (text.startsWith('<![CDATA['))
    return const HtmlBlockStart(terminator: ']]>');
  if (RegExp(r'^<![A-Z]').hasMatch(text))
    return const HtmlBlockStart(terminator: '>');
  final tag = readHtmlTag(source, start, end);
  if (tag == null) return null;
  if (tag.name == 'html')
    return const HtmlBlockStart(rootTag: 'html', fullDocument: true);
  if (htmlBlockTags.contains(tag.name) || discardedHtmlTags.contains(tag.name))
    return HtmlBlockStart(rootTag: tag.name);
  if (source.substring(tag.end, end).trim().isEmpty)
    return const HtmlBlockStart(interrupts: false);
  return null;
}

/// Tracks native HTML block nesting without interpreting text as Markdown.
final class HtmlBlockTracker {
  HtmlBlockTracker(this.start);
  final HtmlBlockStart start;
  final _tags = <String>[];
  String? _opaque;
  bool _seenRoot = false;
  int? closedOffset;

  bool feed(String source, int beginning, int end) {
    final text = source.substring(beginning, end);
    closedOffset = null;
    if (start.terminator case final terminator?) {
      final index = text.indexOf(terminator);
      if (index >= 0) closedOffset = beginning + index + terminator.length;
      return index >= 0;
    }
    if (start.rootTag == null) return false;
    final lower = text.toLowerCase();
    var i = 0;
    while (i < text.length) {
      if (_opaque case final opaque?) {
        final close = lower.indexOf(opaque, i);
        if (close < 0) return false;
        if (opaque == '-->') {
          i = close + 3;
          _opaque = null;
          continue;
        }
        final tag = readHtmlTag(text, close, text.length);
        if (tag?.closing != true || tag?.name != opaque.substring(2)) {
          i = close + opaque.length;
          continue;
        }
        i = close;
        _opaque = null;
      }
      final next = text.indexOf('<', i);
      if (next < 0) break;
      i = next;
      if (text.startsWith('<!--', i)) {
        _opaque = '-->';
        i += 4;
        continue;
      }
      final tag = readHtmlTag(text, i, text.length);
      if (tag == null) {
        i++;
        continue;
      }
      i = tag.end;
      if (tag.closing) {
        final index = _tags.lastIndexOf(tag.name);
        if (index >= 0) _tags.removeRange(index, _tags.length);
        if (tag.name == start.rootTag && _tags.isEmpty) {
          closedOffset = beginning + tag.end;
          return true;
        }
      } else if (!tag.selfClosing &&
          !const {
            'hr',
            'br',
            'img',
            'meta',
            'link',
            'input',
            'wbr',
            'source',
            'col',
          }.contains(tag.name)) {
        _tags.add(tag.name);
        _seenRoot = true;
        if (discardedHtmlTags.contains(tag.name) || tag.name == 'pre')
          _opaque = '</${tag.name}';
      } else if (!_seenRoot && tag.name == start.rootTag) {
        closedOffset = beginning + tag.end;
        return true;
      }
    }
    final closed = _seenRoot && _tags.isEmpty;
    if (closed) closedOffset = end;
    return closed;
  }
}
