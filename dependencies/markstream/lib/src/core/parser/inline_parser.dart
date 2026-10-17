import '../ast/nodes.dart';
import '../ast/source_span.dart';
import '../ast/transform.dart';
import '../html/entities.dart';
import 'dialect.dart';
import 'mapped_text.dart';
import 'source_line.dart';
import 'syntax/autolink.dart';
import 'syntax/characters.dart';
import 'syntax/link_destination.dart';

String normalizeReferenceLabel(String label) =>
    label.trim().replaceAll(RegExp(r'\s+'), ' ').toUpperCase().toLowerCase();

/// Parses inline syntax with delimiter and bracket stacks, without source edits.
final class InlineParser {
  const InlineParser({this.options = const ParserOptions()});
  final ParserOptions options;

  List<InlineNode> parse(
    String source, {
    Map<String, ReferenceDefinitionNode> references = const {},
  }) {
    final fragments = <TextNode>[];
    for (final line in SourceLine.scan(source)) {
      fragments.addAll(LineCursor(line).textFragments());
      if (line.next > line.end)
        fragments.add(
          TextNode(span: SourceSpan(line.end, line.next), text: '\n'),
        );
    }
    return parseFragments(fragments, references: references);
  }

  List<InlineNode> parseFragments(
    List<TextNode> fragments, {
    Map<String, ReferenceDefinitionNode> references = const {},
  }) => _InlineSession(MappedText(fragments), options, references).parse();
}

final class _Part {
  _Part(this.node, this.start, this.end);
  InlineNode? node;
  int start;
  int end;
  _Part? previous;
  _Part? next;
}

final class _Delimiter {
  _Delimiter(
    this.part,
    this.character,
    this.length,
    this.canOpen,
    this.canClose,
    this.index,
  );
  final _Part part;
  final int character;
  int length;
  final bool canOpen;
  final bool canClose;
  final int index;
  _Delimiter? previous;
  _Delimiter? next;
}

final class _Bracket {
  _Bracket(this.part, this.image, this.bottom, this.previous);
  final _Part part;
  final bool image;
  final _Delimiter? bottom;
  final _Bracket? previous;
  bool active = true;
}

final class _InlineSession {
  _InlineSession(this.input, this.options, this.references)
    : text = input.text {
    tail = head;
    // Pair equal-length backtick runs once. Failed openers then cost O(1).
    final runs = <int, int>{};
    final positions = <(int, int)>[];
    for (var i = 0; i < text.length; i++) {
      if (text.codeUnitAt(i) != 96) continue;
      final start = i;
      while (i < text.length && text.codeUnitAt(i) == 96) i++;
      positions.add((start, i - start));
      i--;
    }
    for (final (start, length) in positions.reversed) {
      if (runs[length] case final next?) backticks[start] = next;
      if (length > 1) {
        var escapes = 0;
        for (var i = start - 1; i >= 0 && text.codeUnitAt(i) == 92; i--)
          escapes++;
        if (escapes.isOdd && runs[length - 1] != null)
          backticks[start + 1] = runs[length - 1]!;
      }
      runs[length] = start;
    }
  }
  final MappedText input;
  final String text;
  final ParserOptions options;
  final Map<String, ReferenceDefinitionNode> references;
  final head = _Part(null, 0, 0);
  late _Part tail;
  _Delimiter? firstDelimiter;
  _Delimiter? lastDelimiter;
  _Bracket? bracket;
  final backticks = <int, int>{};
  var delimiterIndex = 0;

  _Part _add(InlineNode node, int start, int end) {
    final part = _Part(node, start, end)..previous = tail;
    tail.next = part;
    tail = part;
    return part;
  }

  _Part _literal(int start, int end) => _add(
    TextNode(span: input.span(start, end), text: text.substring(start, end)),
    start,
    end,
  );
  void _text(int start, int end) {
    var offset = start;
    for (final fragment in input.slice(start, end)) {
      _add(fragment, offset, offset + fragment.text.length);
      offset += fragment.text.length;
    }
  }

  void _removePart(_Part part) {
    part.previous!.next = part.next;
    part.next?.previous = part.previous;
    if (tail == part) tail = part.previous!;
  }

  void _removeDelimiter(_Delimiter delimiter) {
    delimiter.previous?.next = delimiter.next;
    delimiter.next?.previous = delimiter.previous;
    if (firstDelimiter == delimiter) firstDelimiter = delimiter.next;
    if (lastDelimiter == delimiter) lastDelimiter = delimiter.previous;
  }

  List<InlineNode> parse() {
    var i = 0;
    var run = 0;
    while (i < text.length) {
      final c = text.codeUnitAt(i);
      if (!const {92, 96, 42, 95, 91, 93, 33, 60, 38, 10}.contains(c)) {
        i++;
        continue;
      }
      if (i > run) _text(run, i);
      var consumed = false;
      if (c == 92 && i + 1 < text.length) {
        final next = text.codeUnitAt(i + 1);
        if (isAsciiPunctuation(next)) {
          _add(
            TextNode(span: input.span(i, i + 2), text: text[i + 1]),
            i,
            i + 2,
          );
          i += 2;
          consumed = true;
        } else if (next == 10) {
          _add(LineBreakNode(span: input.span(i, i + 2), hard: true), i, i + 2);
          i += 2;
          while (i < text.length &&
              (text.codeUnitAt(i) == 32 || text.codeUnitAt(i) == 9))
            i++;
          consumed = true;
        }
      } else if (c == 96) {
        final start = i;
        while (i < text.length && text.codeUnitAt(i) == 96) i++;
        final length = i - start;
        final close = backticks[start];
        if (close != null) {
          var a = i;
          var b = close;
          final value = text.substring(a, b).replaceAll('\n', ' ');
          if (value.startsWith(' ') &&
              value.endsWith(' ') &&
              value.trim().isNotEmpty) {
            a++;
            b--;
          }
          final body = [
            for (final node in input.slice(a, b))
              TextNode(span: node.span, text: node.text.replaceAll('\n', ' ')),
          ];
          _add(
            CodeSpanNode(
              span: input.span(start, close + length),
              children: body,
              delimiterLength: length,
            ),
            start,
            close + length,
          );
          i = close + length;
        } else {
          _literal(start, i);
        }
        consumed = true;
      } else if (c == 42 || c == 95 && options.underscoreEmphasis) {
        final start = i;
        while (i < text.length && text.codeUnitAt(i) == c) i++;
        final before = runeBefore(text, start);
        final after = runeAt(text, i);
        final left =
            !isSpace(after) &&
            (!isPunctuation(after) || isSpace(before) || isPunctuation(before));
        final right =
            !isSpace(before) &&
            (!isPunctuation(before) || isSpace(after) || isPunctuation(after));
        final relaxed =
            options.cjkFlankingRelax && (isCjk(before) || isCjk(after));
        final open = relaxed
            ? !isSpace(after)
            : left && (c != 95 || !right || isPunctuation(before));
        final close = relaxed
            ? !isSpace(before)
            : right && (c != 95 || !left || isPunctuation(after));
        final delimiter = _Delimiter(
          _literal(start, i),
          c,
          i - start,
          open,
          close,
          delimiterIndex++,
        )..previous = lastDelimiter;
        lastDelimiter?.next = delimiter;
        firstDelimiter ??= delimiter;
        lastDelimiter = delimiter;
        consumed = true;
      } else if (c == 91 ||
          c == 33 && i + 1 < text.length && text.codeUnitAt(i + 1) == 91) {
        final image = c == 33;
        final end = i + (image ? 2 : 1);
        bracket = _Bracket(_literal(i, end), image, lastDelimiter, bracket);
        i = end;
        consumed = true;
      } else if (c == 93) {
        final end = _closeBracket(i);
        if (end != null) {
          i = end;
          consumed = true;
        }
      } else if (c == 38 && options.entities) {
        final entity = readEntity(text, i);
        if (entity != null) {
          _add(
            TextNode(span: input.span(i, entity.end), text: entity.text),
            i,
            entity.end,
          );
          i = entity.end;
          consumed = true;
        }
      } else if (c == 60) {
        final link = readAngleAutolink(text, i);
        if (link != null) {
          _add(
            LinkNode(
              span: input.span(i, link.end),
              children: input.slice(link.labelStart, link.labelEnd),
              destination: link.destination,
              autolink: true,
            ),
            i,
            link.end,
          );
          for (
            var previous = bracket;
            previous != null;
            previous = previous.previous
          ) {
            if (!previous.image) previous.active = false;
          }
          i = link.end;
          consumed = true;
        }
      } else if (c == 10) {
        var spaces = 0;
        var start = i;
        while (start > 0 && text.codeUnitAt(start - 1) == 32) {
          spaces++;
          start--;
        }
        if (spaces > 0) _trimTrailing(start);
        _add(
          LineBreakNode(
            span: input.span(start, i + 1),
            hard: options.softBreakAsHardBreak || spaces >= 2,
          ),
          start,
          i + 1,
        );
        i++;
        while (i < text.length &&
            (text.codeUnitAt(i) == 32 || text.codeUnitAt(i) == 9))
          i++;
        consumed = true;
      }
      if (!consumed) _literal(i, ++i);
      run = i;
    }
    if (run < text.length) _text(run, text.length);
    _emphasis(null);
    final nodes = _nodes(head.next, null);
    return List.unmodifiable(options.autolinks ? _linkify(nodes) : nodes);
  }

  List<InlineNode> _linkify(List<InlineNode> roots) {
    final converted = <InlineNode, List<InlineNode>>{};
    final pending = <(InlineNode, bool)>[
      for (final node in roots.reversed) (node, false),
    ];
    while (pending.isNotEmpty) {
      final (node, visited) = pending.removeLast();
      if (node is TextNode) {
        final mapped = MappedText([node]);
        final result = <InlineNode>[];
        var cursor = 0;
        for (final link in bareAutolinks(node.text)) {
          result.addAll(mapped.slice(cursor, link.start));
          result.add(
            LinkNode(
              span: mapped.span(link.start, link.end),
              children: mapped.slice(link.start, link.end),
              destination: link.destination,
              autolink: true,
            ),
          );
          cursor = link.end;
        }
        result.addAll(mapped.slice(cursor, node.text.length));
        converted[node] = result;
      } else if (node is EmphasisNode) {
        if (!visited) {
          pending.add((node, true));
          for (final child in node.children.reversed)
            pending.add((child, false));
        } else {
          converted[node] = [
            replaceChildren(node, [
              for (final child in node.children) ...converted[child]!,
            ]) as InlineNode,
          ];
        }
      } else {
        converted[node] = [node];
      }
    }
    return [for (final node in roots) ...converted[node]!];
  }

  void _trimTrailing(int end) {
    while (tail != head && tail.node is TextNode && tail.start >= end)
      _removePart(tail);
    if (tail != head && tail.node is TextNode && tail.end > end) {
      tail.end = end;
      tail.node = TextNode(
        span: input.span(tail.start, end),
        text: text.substring(tail.start, end),
      );
    }
  }

  List<InlineNode> _nodes(_Part? start, _Part? end) {
    final result = <InlineNode>[];
    StringBuffer? textRun;
    var runStart = 0;
    var runEnd = 0;
    void flush() {
      if (textRun == null) return;
      result.add(
        TextNode(span: SourceSpan(runStart, runEnd), text: textRun.toString()),
      );
      textRun = null;
    }

    for (var part = start; part != null && part != end; part = part.next) {
      final node = part.node!;
      if (node is TextNode && node.text.isEmpty) continue;
      if (node is TextNode && node.span.length == node.text.length) {
        if (textRun != null && runEnd != node.span.start) flush();
        if (textRun == null) {
          textRun = StringBuffer();
          runStart = node.span.start;
        }
        textRun!.write(node.text);
        runEnd = node.span.end;
      } else {
        flush();
        result.add(node);
      }
    }
    flush();
    return result;
  }

  int? _closeBracket(int offset) {
    final opener = bracket;
    if (opener == null) return null;
    bracket = opener.previous;
    if (!opener.active) return null;
    var link = readInlineLink(text, offset + 1, entities: options.entities);
    if (link == null && references.isNotEmpty) {
      var end = offset + 1;
      String? label;
      if (end < text.length && text.codeUnitAt(end) == 91) {
        var close = end + 1;
        for (; close < text.length && close - end <= 1000; close++) {
          if (text.codeUnitAt(close) == 92) {
            close++;
            continue;
          }
          if (text.codeUnitAt(close) == 91) break;
          if (text.codeUnitAt(close) == 93) {
            label = text.substring(end + 1, close);
            end = close + 1;
            break;
          }
        }
      }
      if ((label == null || label.isEmpty) && offset - opener.part.end > 999)
        return null;
      label = label == null || label.isEmpty
          ? text.substring(opener.part.end, offset)
          : label;
      final reference = references[normalizeReferenceLabel(label)];
      if (reference != null)
        link = (
          end: end,
          destination: reference.destination,
          title: reference.title,
        );
    }
    if (link == null) return null;
    _emphasis(opener.bottom);
    final children = _nodes(opener.part.next, null);
    final start = opener.part.start;
    tail = opener.part.previous!;
    tail.next = null;
    _add(
      opener.image
          ? ImageNode(
              span: input.span(start, link.end),
              children: children,
              destination: link.destination,
              title: link.title,
            )
          : LinkNode(
              span: input.span(start, link.end),
              children: children,
              destination: link.destination,
              title: link.title,
            ),
      start,
      link.end,
    );
    if (!opener.image) {
      for (
        var previous = bracket;
        previous != null;
        previous = previous.previous
      ) {
        if (!previous.image) previous.active = false;
      }
    }
    return link.end;
  }

  void _emphasis(_Delimiter? bottom) {
    final lowerBounds = <(int, bool, int), int>{};
    var closer = bottom == null ? firstDelimiter : bottom.next;
    while (closer != null) {
      if (!closer.canClose) {
        closer = closer.next;
        continue;
      }
      final key = (closer.character, closer.canOpen, closer.length % 3);
      final minimum = lowerBounds[key] ?? bottom?.index ?? -1;
      var opener = closer.previous;
      while (opener != null && opener.index > minimum) {
        final odd =
            (opener.canClose || closer.canOpen) &&
            (opener.length + closer.length) % 3 == 0 &&
            (opener.length % 3 != 0 || closer.length % 3 != 0);
        if (opener.character == closer.character && opener.canOpen && !odd)
          break;
        opener = opener.previous;
      }
      if (opener == null || opener.index <= minimum) {
        lowerBounds[key] = closer.previous?.index ?? bottom?.index ?? -1;
        final next = closer.next;
        if (!closer.canOpen) _removeDelimiter(closer);
        closer = next;
        continue;
      }
      final used = opener.length >= 2 && closer.length >= 2 ? 2 : 1;
      final a = opener.part.end - used;
      final b = closer.part.start + used;
      final children = _nodes(opener.part.next, closer.part);
      final wrapped = _Part(
        EmphasisNode(
          span: input.span(a, b),
          children: children,
          strong: used == 2,
          marker: String.fromCharCode(closer.character),
        ),
        a,
        b,
      );
      opener.part.next = wrapped;
      wrapped.previous = opener.part;
      wrapped.next = closer.part;
      closer.part.previous = wrapped;
      opener.part.end -= used;
      closer.part.start += used;
      opener.length -= used;
      closer.length -= used;
      opener.part.node = TextNode(
        span: input.span(opener.part.start, opener.part.end),
        text: text.substring(opener.part.start, opener.part.end),
      );
      closer.part.node = TextNode(
        span: input.span(closer.part.start, closer.part.end),
        text: text.substring(closer.part.start, closer.part.end),
      );
      var inside = opener.next;
      while (inside != null && inside != closer) {
        final next = inside.next;
        _removeDelimiter(inside);
        inside = next;
      }
      if (opener.length == 0) {
        _removePart(opener.part);
        _removeDelimiter(opener);
      }
      if (closer.length == 0) {
        final next = closer.next;
        _removePart(closer.part);
        _removeDelimiter(closer);
        closer = next;
      }
    }
    var leftover = bottom == null ? firstDelimiter : bottom.next;
    while (leftover != null) {
      final next = leftover.next;
      _removeDelimiter(leftover);
      leftover = next;
    }
  }
}
