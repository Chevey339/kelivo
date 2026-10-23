import 'package:markstream/markstream_core.dart';

/// Splits assistant markdown into paragraph chunks, one per bubble.
///
/// A blank line starts a new chunk, except where that would break a Markdown
/// construct. Structure state comes from [MarkdownStructure] — the same rules the renderer applies — so code
/// fences, `<details>` blocks, and `$$`/`\[…\]` display math keep their blank
/// lines, including while an unclosed one is still streaming. On top of that,
/// indented continuations stay attached to the block above them, adjacent list
/// blocks stay together (so ordered lists do not restart numbering in every
/// bubble), and a lone heading is kept with the block it introduces.
///
/// Returns a single-element list holding [text] unchanged when there is
/// nothing to split.
List<String> splitAssistantParagraphs(String text) => [
  for (final paragraph in splitAssistantParagraphsWithSource(text))
    paragraph.text,
];

/// Display text retains the existing normalization; [span] also preserves the
/// exact original interval for widgets whose identity belongs to source text.
class AssistantParagraph {
  const AssistantParagraph(this.text, this.span);
  final String text;
  final SourceSpan span;
}

List<AssistantParagraph> splitAssistantParagraphsWithSource(String text) {
  final whole = AssistantParagraph(text, SourceSpan(0, text.length));
  if (text.trim().isEmpty) return [whole];

  final lines = text.split('\n');
  final chunks = <AssistantParagraph>[];
  final current = <String>[];
  final structure = MarkdownStructure(text);
  var offset = 0;
  var currentStart = 0, currentEnd = 0;

  void flush() {
    final chunk = current.join('\n').trim();
    if (chunk.isNotEmpty) {
      chunks.add(
        AssistantParagraph(chunk, SourceSpan(currentStart, currentEnd)),
      );
    }
    current.clear();
  }

  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    final lineStart = offset;
    offset += line.length + 1;

    final breaksParagraph =
        line.trim().isEmpty &&
        !structure.protects(lineStart) &&
        !_continuesBlock(lines, i + 1);
    if (breaksParagraph) {
      flush();
      continue;
    }
    if (current.isEmpty) currentStart = lineStart;
    currentEnd = lineStart + line.length;
    current.add(line);
  }
  flush();

  if (chunks.length < 2) return [whole];
  return _mergeRelatedChunks(chunks);
}

final RegExp _listItemPattern = RegExp(r'^\s*([-*+]\s|\d+[.)]\s)');
final RegExp _headingPattern = RegExp(r'^#{1,6}\s');

/// A blank line followed by an indented line is a continuation (indented code,
/// lazy list continuation), not a paragraph break.
bool _continuesBlock(List<String> lines, int from) {
  for (var i = from; i < lines.length; i++) {
    if (lines[i].trim().isEmpty) continue;
    return lines[i].startsWith('    ') || lines[i].startsWith('\t');
  }
  return false;
}

List<AssistantParagraph> _mergeRelatedChunks(List<AssistantParagraph> chunks) {
  final merged = <AssistantParagraph>[];
  for (final chunk in chunks) {
    if (merged.isNotEmpty && _shouldMerge(merged.last.text, chunk.text)) {
      merged[merged.length - 1] = AssistantParagraph(
        '${merged.last.text}\n\n${chunk.text}',
        SourceSpan(merged.last.span.start, chunk.span.end),
      );
      continue;
    }
    merged.add(chunk);
  }
  return merged;
}

bool _shouldMerge(String previous, String next) {
  if (_isHeadingOnly(previous)) return true;
  return _startsList(previous) && _startsList(next);
}

bool _isHeadingOnly(String chunk) =>
    !chunk.contains('\n') && _headingPattern.hasMatch(chunk);

bool _startsList(String chunk) => _listItemPattern.hasMatch(chunk);
