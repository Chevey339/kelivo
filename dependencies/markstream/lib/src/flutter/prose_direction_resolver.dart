import 'dart:ui' show TextDirection;
import '../core/ast/nodes.dart';
import '../core/html/html_fragment.dart' show htmlBlockTags;
import 'render/bidi_classes.dart';

final _strong = RegExp('([$rtlCharacters])|[$ltrCharacters]', unicode: true);
final _rtl = RegExp('[$rtlCharacters]', unicode: true);
final _latin = RegExp(r'\p{Script=Latin}', unicode: true);
final _identifier = RegExp(
  r'[\p{Script=Latin}\p{M}\p{Nd}_.-]{1,64}',
  unicode: true,
);
final _space = RegExp(r'[\t\p{Zs}]+', unicode: true);
final _rtlLetter = RegExp(
  '(?=[$rtlCharacters])'
  r'\p{L}',
  unicode: true,
);
final _paragraphBreak = RegExp(r'[\r\n\u2028\u2029]');
final _ltr = RegExp('[$ltrCharacters]', unicode: true);
final _backticks = RegExp(r'\x60+');
final _closing = {
  for (final pair in [
    '""',
    "''",
    '«»',
    '‹›',
    '“”',
    '‘’',
    '「」',
    '『』',
    '()',
    '（）',
    '[]',
  ])
    pair.codeUnitAt(0): pair.codeUnitAt(1),
};
final _technicalName = RegExp(r'[0-9_]|[a-z][A-Z]');
final _nameEnd = RegExp(r'[\p{Script=Latin}\p{Nd}\p{M}]$', unicode: true);

/// Resolves the base direction of chat prose. Hosts can supply their existing
/// name catalog so an ordinary Latin word is never assumed to be a model name.
class ProseDirectionResolver {
  const ProseDirectionResolver({this.isKnownName});
  final bool Function(String word)? isKnownName;

  /// Neutral text inherits its surroundings. A single Latin name can introduce
  /// an RTL sentence; other text follows its first Unicode L, R or AL character.
  TextDirection? forText(String text) => _resolveParts([text]);

  TextDirection? _resolveParts(Iterable<String> pieces) {
    final parts = pieces.iterator;
    while (parts.moveNext()) {
      final text = parts.current;
      final first = _strong.firstMatch(text);
      if (first == null) continue;
      if (first.group(1) != null) return TextDirection.rtl;
      if (_latin.matchAsPrefix(text, first.start) != null &&
          _latinNameBeforeRtl(parts, first.start))
        return TextDirection.rtl;
      return TextDirection.ltr;
    }
    return null;
  }

  bool _latinNameBeforeRtl(Iterator<String> parts, int offset) {
    final name = StringBuffer();
    var separated = false;
    do {
      final text = parts.current;
      if (!separated) {
        final token = _identifier.matchAsPrefix(text, offset);
        if (token != null) {
          name.write(token.group(0));
          if (name.length > 64) return false;
          offset = token.end;
        }
      }
      final space = _space.matchAsPrefix(text, offset);
      if (space != null) {
        separated = true;
        offset = space.end;
      }
      if (offset < text.length) {
        // A second Latin word, a URL, a quote or a parenthesis rules out the
        // fallback before scanning the rest of a normal LTR paragraph.
        if (!separated || _rtlLetter.matchAsPrefix(text, offset) == null)
          return false;
        final word = name.toString();
        return _nameEnd.hasMatch(word) &&
            (isKnownName?.call(word) == true ||
                _technicalName.hasMatch(word)) &&
            _rtlClause(parts, offset, _strong.allMatches(word).length);
      }
      offset = 0;
    } while (parts.moveNext());
    return false;
  }

  /// Look through emphasis and link labels, skipping isolated inline widgets
  /// and syntax such as link destinations, code fences and list markers.
  TextDirection? forNodes(Iterable<MarkdownNode> nodes) =>
      _resolveParts(_visibleProse(nodes));

  /// Only paragraphs and containers with an RTL start need a shared width.
  /// A Latin paragraph that quotes Persian, or a code block containing Persian,
  /// must retain its normal layout and streaming path.
  bool hasRtlBlock(MarkdownNode node) {
    if (_isolated(node)) return false;
    if (node is ParagraphNode ||
        node is HeadingNode ||
        node is TaskItemNode ||
        node is TableCellNode ||
        node is DetailsSummaryNode ||
        node is DirectiveLabelNode) {
      return forNodes(node.children) == TextDirection.rtl;
    }
    if (node is HtmlBlockNode && node.fullDocument) return false;
    if (node is HtmlElementNode || node is HtmlBlockNode) {
      if (forNodes(node.children) == TextDirection.rtl) return true;
    }
    return node.children.any(hasRtlBlock);
  }
}

bool _rtlClause(Iterator<String> parts, int offset, int nameStrong) {
  final buffer = StringBuffer();
  do {
    final text = parts.current;
    final end = _paragraphBreak.allMatches(text, offset).firstOrNull?.start;
    buffer.write(text.substring(offset, end));
    if (end != null) break;
    offset = 0;
  } while (parts.moveNext());
  final body = _unquotedRtl(buffer.toString());
  if (body == null) return false;
  // The only LTR letters left belong to the opening name. To exceed 30%
  // RTL we need more than 3/7 of that count; never tally a whole long draft.
  final needed = 3 * nameStrong ~/ 7 + 1;
  return _rtl.allMatches(body).take(needed).length == needed;
}

// Inspect only the sentence outside inline literals, in plaintext as well as
// Markdown. Any other LTR prose is evidence of an LTR frame. Do not guess
// from an unfinished quotation while streaming or typing.
String? _unquotedRtl(String text) {
  StringBuffer? outside;
  var visibleStart = 0;
  final nonLtr = <int>{};
  final runes = text.runes.iterator;
  while (runes.moveNext()) {
    final rune = runes.current;
    if (rune == 0x20) continue;
    final start = runes.rawIndex;
    if (rune == 0x60 || _closing.containsKey(rune)) {
      final end = _literalEnd(text, start);
      if (end == null) return null;
      (outside ??= StringBuffer())
        ..write(text.substring(visibleStart, start))
        ..write(' ');
      visibleStart = end;
      runes.reset(visibleStart);
    } else if (nonLtr.add(rune) && _ltr.matchAsPrefix(text, start) != null) {
      // Repeated letters in a long draft need one Unicode lookup per distinct
      // scalar. The first unquoted LTR letter settles an English frame.
      return null;
    }
  }
  if (outside == null) return text;
  outside.write(text.substring(visibleStart));
  return outside.toString();
}

/// Paired brackets may nest. Code spans close only at a run of the same
/// length, so a backtick inside a code sample cannot expose its Latin text.
int? _literalEnd(String text, int offset) {
  final ends = <int>[];
  do {
    if (offset >= text.length) return null;
    final unit = text.codeUnitAt(offset);
    if (ends.isNotEmpty && unit == ends.last) {
      ends.removeLast();
      offset++;
    } else if (unit == 0x60) {
      final open = _backticks.matchAsPrefix(text, offset)!;
      final length = open.end - offset;
      final close = _backticks
          .allMatches(text, open.end)
          .where((run) => run.end - run.start == length)
          .firstOrNull;
      if (close == null) return null;
      offset = close.end;
    } else if (_closing[unit] case final close?) {
      if (unit == close) {
        final end = text.indexOf(String.fromCharCode(close), offset + 1);
        if (end < 0) return null;
        offset = end + 1;
      } else {
        ends.add(close);
        offset++;
      }
    } else {
      offset++;
    }
  } while (ends.isNotEmpty);
  return offset;
}

/// Whether a left-to-right-only line renderer can encounter strong RTL text.
bool containsStrongRtl(String text) => _rtl.hasMatch(text);

Iterable<String> _visibleProse(Iterable<MarkdownNode> nodes) sync* {
  for (final node in nodes) {
    if (_isolated(node)) {
      yield '\uFFFC';
    } else if (node is TextNode) {
      yield node.text;
    } else if (node is LineBreakNode) {
      yield node.hard ? '\n' : ' ';
    } else if (node is HtmlElementNode && node.tag == 'br') {
      yield '\n';
    } else {
      final block =
          node is BlockNode ||
          node is TableCellNode ||
          (node is HtmlElementNode && htmlBlockTags.contains(node.tag));
      if (block) yield '\n';
      yield* _visibleProse(node.children);
      if (block) yield '\n';
    }
  }
}

bool _isolated(MarkdownNode node) =>
    node is CodeSpanNode ||
    node is CodeBlockNode ||
    node is ImageNode ||
    node is MathInlineNode ||
    node is MathBlockNode ||
    (node is NamedInlineNode && node.syntax == NamedInlineSyntax.extension) ||
    (node is HtmlElementNode &&
        const {'code', 'kbd', 'pre', 'img'}.contains(node.tag));
