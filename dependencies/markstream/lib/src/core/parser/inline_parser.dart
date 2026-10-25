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
import 'syntax/directive.dart';
import 'syntax/inline_html.dart';
import 'syntax/inline_syntax.dart';
import 'syntax/math_inline.dart';

String normalizeReferenceLabel(String label) =>
    label.trim().replaceAll(RegExp(r'\s+'), ' ').toUpperCase().toLowerCase();

/// Parses inline syntax with delimiter and bracket stacks, without source edits.
final class InlineParser {
  const InlineParser({
    this.options = const ParserOptions(),
    this.syntaxes = const [],
  });
  final ParserOptions options;
  final List<InlineSyntax> syntaxes;

  List<InlineNode> parse(
    String source, {
    Map<String, ReferenceDefinitionNode> references = const {},
    bool optimistic = false,
  }) {
    final fragments = <TextNode>[];
    for (final line in SourceLine.scan(
      source,
      unicodeLineBreaks: options.unicodeLineBreaks,
    )) {
      fragments.addAll(LineCursor(line).textFragments());
      if (line.next > line.end)
        fragments.add(
          TextNode(span: SourceSpan(line.end, line.next), text: '\n'),
        );
    }
    return parseFragments(
      fragments,
      references: references,
      optimistic: optimistic,
    );
  }

  List<InlineNode> parseFragments(
    List<TextNode> fragments, {
    Map<String, ReferenceDefinitionNode> references = const {},
    bool optimistic = false,
  }) {
    final session = _InlineSession(
      MappedText(fragments),
      options,
      references,
      syntaxes,
      optimistic: optimistic,
    );
    final nodes = session.parse();
    return _directiveLabels(nodes, references, session.pendingLabels);
  }

  List<InlineNode> _directiveLabels(
    List<InlineNode> roots,
    Map<String, ReferenceDefinitionNode> references,
    Map<NamedInlineNode, List<TextNode>> pendingLabels,
  ) {
    final parsed = <InlineNode, List<InlineNode>>{};
    final converted = <InlineNode, InlineNode>{};
    final pending = <(InlineNode, bool)>[
      for (final node in roots.reversed) (node, false),
    ];
    while (pending.isNotEmpty) {
      final (node, visited) = pending.removeLast();
      final container =
          node is EmphasisNode ||
          node is StrikethroughNode ||
          node is LinkNode ||
          node is ImageNode ||
          node is NamedInlineNode;
      if (!container) {
        converted[node] = node;
        continue;
      }
      if (!visited) {
        final List<InlineNode> children;
        if (node is NamedInlineNode && pendingLabels.containsKey(node)) {
          final session = _InlineSession(
            MappedText(pendingLabels[node]!),
            options,
            references,
            syntaxes,
          );
          children = session.parse();
          pendingLabels.addAll(session.pendingLabels);
        } else {
          children = node.children.cast<InlineNode>();
        }
        parsed[node] = children;
        pending.add((node, true));
        for (final child in children.reversed) pending.add((child, false));
      } else {
        converted[node] = replaceChildren(node, [
          for (final child in parsed[node]!) converted[child]!,
        ]) as InlineNode;
      }
    }
    return List.unmodifiable([for (final root in roots) converted[root]!]);
  }
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
  _InlineSession(
    this.input,
    this.options,
    this.references,
    this.syntaxes, {
    this.optimistic = false,
  }) : text = input.text {
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
  final List<InlineSyntax> syntaxes;
  final bool optimistic;
  final head = _Part(null, 0, 0);
  late _Part tail;
  _Delimiter? firstDelimiter;
  _Delimiter? lastDelimiter;
  _Bracket? bracket;
  final backticks = <int, int>{};
  var delimiterIndex = 0;
  final pendingLabels = <NamedInlineNode, List<TextNode>>{};

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
      if (!const {
            92,
            96,
            42,
            95,
            91,
            93,
            33,
            60,
            38,
            10,
            36,
            58,
            126,
          }.contains(c) &&
          !syntaxes.any((syntax) => syntax.startCharacters.contains(c))) {
        i++;
        continue;
      }
      if (i > run) _text(run, i);
      var consumed = false;
      for (final syntax in syntaxes) {
        if (!syntax.startCharacters.contains(c)) continue;
        final match = syntax.match(InlineSyntaxContext(input, options), i);
        if (match == null) continue;
        if (match.end <= i || match.end > text.length)
          throw ArgumentError(
            'InlineSyntax must consume a nonempty source interval',
          );
        final span = input.span(i, match.end);
        if (match.node.span.start < span.start ||
            match.node.span.end > span.end)
          throw ArgumentError(
            'InlineSyntax node must stay inside its consumed source interval',
          );
        _add(match.node, i, match.end);
        i = match.end;
        consumed = true;
        break;
      }
      if (!consumed &&
          options.inlineMath &&
          ((c == 36 && options.dollarInlineMath) || c == 92)) {
        final math = readInlineMath(
          text,
          i,
          maxLength: options.maxInlineMathLength,
          allowOpen: optimistic,
          adjacent: tail.node is MathInlineNode && tail.end == i,
        );
        if (math != null) {
          _add(
            MathInlineNode(
              span: input.span(i, math.end),
              children: input.slice(math.bodyStart, math.bodyEnd),
              delimiter: math.delimiter,
              closed: math.closed,
            ),
            i,
            math.end,
          );
          i = math.end;
          consumed = true;
        }
      }
      if (!consumed &&
          options.directives &&
          c == 58 &&
          i + 1 < text.length &&
          text.codeUnitAt(i + 1) == 58) {
        final start = i;
        while (i < text.length && text.codeUnitAt(i) == 58) i++;
        _literal(start, i);
        consumed = true;
      }
      if (!consumed &&
          options.directives &&
          c == 58 &&
          (isSpace(runeBefore(text, i)) ||
              isPunctuation(runeBefore(text, i)))) {
        final directive = readDirective(text, i, text.length);
        if (directive != null && directive.colons == 1) {
          final label = directive.label;
          final labelText = label == null
              ? <TextNode>[]
              : input.slice(label.start, label.end);
          final node = NamedInlineNode(
            span: input.span(i, directive.end),
            name: directive.name,
            syntax: NamedInlineSyntax.directive,
            children: labelText,
            attributes: {
              for (final entry in directive.attributes.entries)
                entry.key: decodeMarkdownString(
                  entry.value,
                  entities: options.entities,
                ),
            },
          );
          pendingLabels[node] = labelText;
          _add(node, i, directive.end);
          i = directive.end;
          consumed = true;
        }
      }
      if (consumed) {
        run = i;
        continue;
      }
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
        final actualClose = backticks[start];
        final close =
            actualClose ?? (optimistic && i < text.length ? text.length : null);
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
          final end = actualClose == null ? close : close + length;
          _add(
            CodeSpanNode(
              span: input.span(start, end),
              closed: actualClose != null,
              children: body,
              delimiterLength: length,
            ),
            start,
            end,
          );
          i = end;
        } else {
          _literal(start, i);
        }
        consumed = true;
      } else if (c == 42 ||
          c == 95 && options.underscoreEmphasis ||
          c == 126 && options.strikethrough) {
        final start = i;
        while (i < text.length && text.codeUnitAt(i) == c) i++;
        if (c == 126 && i - start != 2) {
          _literal(start, i);
          run = i;
          continue;
        }
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
        if (!consumed && options.inlineHtml) {
          final html = readInlineHtml(input, i, entities: options.entities);
          if (html != null) {
            for (final node in html.nodes) _add(node, i, html.end);
            i = html.end;
            consumed = true;
          }
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
    _emphasis(null, closeOpen: optimistic);
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
      } else if (node is EmphasisNode || node is StrikethroughNode) {
        if (!visited) {
          pending.add((node, true));
          for (final child in node.children.cast<InlineNode>().reversed)
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

  void _emphasis(_Delimiter? bottom, {bool closeOpen = false}) {
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
            closer.character != 126 &&
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
        closer.character == 126
            ? StrikethroughNode(span: input.span(a, b), children: children)
            : EmphasisNode(
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
    if (closeOpen) {
      var opener = lastDelimiter;
      while (opener != null && opener != bottom) {
        final previous = opener.previous;
        if (opener.canOpen && opener.part.next != null) {
          while (opener.length > 0) {
            final used = opener.length >= 2 ? 2 : 1;
            final children = _nodes(opener.part.next, null);
            final start = opener.part.end - used;
            final node = opener.character == 126
                ? StrikethroughNode(
                    span: input.span(start, text.length),
                    children: children,
                    closed: false,
                  )
                : EmphasisNode(
                    span: input.span(start, text.length),
                    children: children,
                    strong: used == 2,
                    marker: String.fromCharCode(opener.character),
                    closed: false,
                  );
            opener.part.end -= used;
            opener.length -= used;
            opener.part.node = TextNode(
              span: input.span(opener.part.start, opener.part.end),
              text: text.substring(opener.part.start, opener.part.end),
            );
            tail = opener.part;
            tail.next = null;
            _add(node, start, text.length);
          }
          _removePart(opener.part);
        }
        _removeDelimiter(opener);
        opener = previous;
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
