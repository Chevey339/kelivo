import '../ast/nodes.dart';
import '../ast/source_span.dart';
import 'dialect.dart';
import 'source_line.dart';
import 'mapped_text.dart';
import 'syntax/math_block.dart';
import 'syntax/task_item.dart';
import 'syntax/table.dart';
import 'syntax/html_tag.dart';
import 'syntax/directive.dart';
import 'syntax/alert.dart';
import 'syntax/html_block.dart';
import '../html/html_fragment.dart';
import '../html/entities.dart';

/// Builds block structure before inline interpretation, using original offsets.
final class BlockParser {
  const BlockParser({this.options = const ParserOptions()});
  final ParserOptions options;

  /// [start] is an original-source line boundary for incremental reparsing.
  DocumentNode parse(String source, {bool streaming = false, int start = 0}) {
    if (start < 0 || start > source.length)
      throw RangeError.range(start, 0, source.length, 'start');
    return _BlockSession(source, options, streaming, start).parse();
  }
}

enum _Kind {
  root,
  quote,
  list,
  item,
  paragraph,
  heading,
  rule,
  code,
  math,
  task,
  table,
  details,
  summary,
  named,
  label,
  html,
}

final class _Block {
  _Block(this.kind, this.start, {this.parent}) : end = start;
  _Kind kind;
  final int start;
  int end;
  final _Block? parent;
  final children = <_Block>[];
  final text = <InlineNode>[];
  final code = <({bool blank, List<TextNode> text})>[];
  SourceLine? lastLine;
  int level = 0;
  int indent = 0;
  int number = 1;
  String marker = '-';
  String delimiter = '.';
  bool ordered = false;
  bool loose = false;
  bool pendingBlank = false;
  bool fenced = false;
  bool closed = true;
  int fenceLength = 0;
  String info = '';
  bool? checked;
  bool radio = false;
  SourceSpan? markerSpan;
  final rows = <TableRowNode>[];
  List<TableAlignment> alignments = const [];
  bool open = false;
  bool provisional = false;
  String name = '';
  Map<String, String> attributes = const {};
  NamedBlockSyntax? syntax;
  HtmlBlockTracker? html;
}

final class _ListMarker {
  const _ListMarker(
    this.marker,
    this.delimiter,
    this.number,
    this.width,
    this.padding,
    this.indent,
  );
  final String marker;
  final String delimiter;
  final int? number;
  final int width;
  final int padding;
  final int indent;
  bool matches(_Block list) =>
      list.ordered == (number != null) &&
      (number != null ? list.delimiter == delimiter : list.marker == marker);
}

final class _BlockSession {
  _BlockSession(this.source, this.options, this.streaming, this.start) {
    root = _Block(_Kind.root, 0)..end = source.length;
    stack.add(root);
  }
  final String source;
  final ParserOptions options;
  final bool streaming;
  final int start;
  late final _Block root;
  final stack = <_Block>[];
  _Block? leaf;
  final _remaining = <LineCursor>[];
  final _lastMathClose = <String, int>{};

  // Lookahead is only needed for an opener with body text on its first line.
  // Cache the last unescaped closer so malformed openers do not rescan the
  // whole remaining document for every source line.
  bool _hasLaterMathClose(int after, String closer) =>
      (_lastMathClose[closer] ??= findLastMathBlockClose(source, closer)) >=
      after;

  static final _listStart = RegExp(r'^([-+*]|[0-9]{1,9}[.)])(?=\s|$)');
  static final _fenceStart = RegExp(r'^(`{3,}|~{3,})(.*)$');
  static final _heading = RegExp(r'^(#{1,6})(?:[ \t]+|$)(.*)$');
  static final _rule = RegExp(
    r'^(?:(?:\*[ \t]*){3,}|(?:-[ \t]*){3,}|(?:_[ \t]*){3,})$',
  );
  static final _setext = RegExp(r'^(=+|-+)[ \t]*$');

  DocumentNode parse() {
    for (final line in SourceLine.scan(
      source,
      start: start,
      unicodeLineBreaks: options.unicodeLineBreaks,
    )) {
      _line(line);
    }
    if (streaming) _provisionalTable();
    return DocumentNode(source: source, children: _freeze());
  }

  void _provisionalTable() {
    final block = leaf;
    if (!options.tables || block == null || block.kind != _Kind.paragraph)
      return;
    final mapped = MappedText(block.text.cast<TextNode>());
    final firstBreak = mapped.text.indexOf('\n');
    if (firstBreak >= 0) {
      final rest = mapped.text.substring(firstBreak + 1);
      if (!RegExp(r'^[|:\- \t]+$').hasMatch(rest)) return;
    }
    final firstEnd = firstBreak < 0 ? mapped.text.length : firstBreak;
    if (!mapped.text.substring(0, firstEnd).trimLeft().startsWith('|')) return;
    final span = mapped.span(0, firstEnd);
    final header = splitTableLine(
      source,
      span.start,
      span.end,
      math: options.inlineMath,
      dollarMath: options.dollarInlineMath,
      maxMathLength: options.maxInlineMathLength,
    );
    if (header.cells.isEmpty ||
        !options.tablePipesOptional && !header.outerPipes)
      return;
    block
      ..kind = _Kind.table
      ..provisional = true
      ..alignments = List.filled(header.cells.length, TableAlignment.none);
    block.rows.add(
      TableRowNode(span: span, children: header.cells, header: true),
    );
    block.text.clear();
  }

  _ListMarker? _marker(LineCursor cursor) {
    final indentation = cursor.indentation;
    if (indentation.width > 3) return null;
    final rest = source.substring(indentation.end, cursor.line.end);
    final match = _listStart.firstMatch(rest);
    if (match == null) return null;
    final marker = match[1]!;
    if (marker == '+' && !options.plusListMarker ||
        marker.endsWith(')') && !options.orderedParenthesis)
      return null;
    final number = marker.length > 1
        ? int.parse(marker.substring(0, marker.length - 1))
        : null;
    var column = cursor.column + indentation.width + marker.length;
    var index = indentation.end + marker.length;
    var padding = 0;
    while (index < cursor.line.end) {
      final c = source.codeUnitAt(index);
      if (c != 32 && c != 9) break;
      final width = c == 9 ? 4 - column % 4 : 1;
      column += width;
      padding += width;
      index++;
    }
    if (padding == 0 && index != cursor.line.end) return null;
    if (padding == 0 || padding > 4 || index == cursor.line.end) padding = 1;
    return _ListMarker(
      marker,
      marker.substring(marker.length - 1),
      number,
      marker.length,
      padding,
      indentation.width,
    );
  }

  String _trimmed(LineCursor cursor) =>
      source.substring(cursor.indentation.end, cursor.line.end);

  bool _interrupts(LineCursor cursor) {
    if (cursor.indentation.width > 3) return false;
    if (options.directives &&
        readBlockDirective(source, cursor.indentation.end, cursor.line.end) !=
            null)
      return true;
    if (options.directives && _directiveCloser(cursor) >= 0) return true;
    if (options.htmlBlocks &&
        matchHtmlBlock(
              source,
              cursor.indentation.end,
              cursor.line.end,
            )?.interrupts ==
            true)
      return true;
    if (options.details) {
      final tag = readHtmlTag(source, cursor.indentation.end, cursor.line.end);
      if (tag?.name == 'details') return true;
    }
    if (options.mathBlocks) {
      final math = findMathBlockStart(
        source,
        cursor.offset,
        cursor.line.end,
        streaming: streaming,
        hasLaterClose: _hasLaterMathClose,
      );
      if (math != null && math.start == cursor.indentation.end) return true;
    }
    if ((options.standaloneTaskLine && options.taskItems ||
            options.radioItems) &&
        matchTaskMarker(
              source,
              cursor.indentation.end,
              cursor.line.end,
              radioItems: options.radioItems,
              checkboxItems: options.taskItems && options.standaloneTaskLine,
            ) !=
            null)
      return true;
    final text = _trimmed(cursor);
    if (text.startsWith('>') || _heading.hasMatch(text) || _rule.hasMatch(text))
      return true;
    final fence = _fenceStart.firstMatch(text);
    if (fence != null &&
        (!fence[1]!.startsWith('`') || !fence[2]!.contains('`')))
      return true;
    final marker = _marker(cursor);
    return marker != null &&
        (marker.number == null || marker.number == 1) &&
        text.substring(marker.width).trim().isNotEmpty;
  }

  _Block _add(_Kind kind, int start) {
    final parent = stack.last;
    if (parent.kind == _Kind.item &&
        parent.pendingBlank &&
        parent.children.isNotEmpty) {
      parent.parent!.loose = true;
      parent.pendingBlank = false;
    }
    final node = _Block(kind, start, parent: parent);
    parent.children.add(node);
    return node;
  }

  void _touch(SourceLine line) {
    for (final node in stack.skip(1)) {
      node.end = line.next;
    }
  }

  void _paragraph(LineCursor cursor) {
    if (stack.any((node) => node.kind == _Kind.details)) {
      final tag = findHtmlTag(
        source,
        cursor.offset,
        cursor.line.end,
        'details',
      );
      if (tag != null) {
        _remaining.add(
          LineCursor(
            SourceLine(source, tag.start, cursor.line.end, cursor.line.next),
          ),
        );
        if (source.substring(cursor.offset, tag.start).trim().isNotEmpty)
          _paragraphContent(
            LineCursor(SourceLine(source, cursor.offset, tag.start, tag.start)),
          );
        return;
      }
    }
    _paragraphContent(cursor);
  }

  void _paragraphContent(LineCursor cursor) {
    final math = options.mathBlocks
        ? findMathBlockStart(
            source,
            cursor.offset,
            cursor.line.end,
            streaming: streaming,
            hasLaterClose: _hasLaterMathClose,
          )
        : null;
    if (math != null) {
      if (source.substring(cursor.offset, math.start).trim().isNotEmpty) {
        _appendParagraph(
          LineCursor(SourceLine(source, cursor.offset, math.start, math.start)),
        );
      }
      leaf = _add(_Kind.math, math.start)
        ..marker = math.closer
        ..info = math.delimiter
        ..closed = false
        ..end = cursor.line.end;
      _math(
        LineCursor(
          SourceLine(source, math.bodyStart, cursor.line.end, cursor.line.next),
        ),
      );
      return;
    }
    _appendParagraph(cursor);
  }

  void _math(LineCursor cursor) {
    final block = leaf!;
    final close = findMathBlockClose(
      source,
      cursor.offset,
      cursor.line.end,
      block.marker,
    );
    if (close < 0) {
      block.text.addAll(cursor.textFragments());
      if (cursor.line.next > cursor.line.end) {
        block.text.add(
          TextNode(
            span: SourceSpan(cursor.line.end, cursor.line.next),
            text: '\n',
          ),
        );
      }
      block.end = cursor.line.next;
      _touch(cursor.line);
      return;
    }
    block.text.addAll(
      LineCursor(SourceLine(source, cursor.offset, close, close))
          .textFragments(),
    );
    block
      ..closed = true
      ..end = close + block.marker.length;
    _touch(cursor.line);
    leaf = null;
    _queueSuffix(block.end, cursor.line);
  }

  void _appendParagraph(LineCursor cursor) {
    cursor.indent(cursor.indentation.width);
    if (leaf == null &&
        stack.last.kind == _Kind.item &&
        stack.last.children.isEmpty &&
        (options.taskItems || options.radioItems)) {
      final marker = matchTaskMarker(
        source,
        cursor.offset,
        cursor.line.end,
        radioItems: options.radioItems,
        checkboxItems: options.taskItems,
      );
      if (marker != null) {
        stack.last
          ..checked = marker.checked
          ..radio = marker.radio
          ..markerSpan = SourceSpan(marker.start, marker.end);
        cursor.advance(marker.end - marker.start);
      }
    }
    final current = leaf ??= _add(_Kind.paragraph, cursor.sourceOffset);
    if (current.lastLine case final previous?) {
      current.text.add(
        TextNode(span: SourceSpan(previous.end, previous.next), text: '\n'),
      );
    }
    current.text.addAll(cursor.textFragments());
    current.lastLine = cursor.line;
    current.end = cursor.line.end;
    _touch(cursor.line);
  }

  void _appendCode(_Block block, LineCursor cursor) {
    block.end = cursor.line.next;
    block.code.add((
      blank: cursor.blank,
      text: [
        ...cursor.textFragments(),
        TextNode(
          span: SourceSpan(cursor.line.end, cursor.line.next),
          text: '\n',
        ),
      ],
    ));
  }

  void _queueSuffix(int start, SourceLine line) {
    if (source.substring(start, line.end).trim().isNotEmpty)
      _remaining.add(
        LineCursor(SourceLine(source, start, line.end, line.next)),
      );
  }

  void _closeDetails(HtmlTag tag, SourceLine line) {
    final index = stack.lastIndexWhere((node) => node.kind == _Kind.details);
    if (index < 0) return;
    for (var i = 1; i < stack.length; i++) {
      stack[i].end = i < index ? line.next : tag.start;
    }
    stack[index]
      ..end = tag.end
      ..closed = true;
    stack.removeRange(index, stack.length);
    leaf = null;
    _queueSuffix(tag.end, line);
  }

  bool _detailsBoundary(LineCursor cursor) {
    if (!options.details || cursor.indentation.width > 3) return false;
    final tag = readHtmlTag(source, cursor.indentation.end, cursor.line.end);
    if (tag == null) return false;
    if (tag.name == 'details') {
      if (tag.closing) {
        if (!stack.any((n) => n.kind == _Kind.details)) return false;
        _closeDetails(tag, cursor.line);
      } else {
        leaf = null;
        if (stack.last.kind == _Kind.list) stack.removeLast();
        final block = _add(_Kind.details, tag.start)
          ..end = cursor.line.end
          ..open = tag.attributes.containsKey('open')
          ..closed = tag.selfClosing;
        if (!tag.selfClosing) stack.add(block);
        _touch(cursor.line);
        _queueSuffix(tag.end, cursor.line);
      }
      return true;
    }
    if (tag.name == 'summary' &&
        !tag.closing &&
        stack.last.kind == _Kind.details &&
        stack.last.children.isEmpty) {
      leaf = _add(_Kind.summary, tag.start)..end = tag.end;
      _summary(
        LineCursor(
          SourceLine(source, tag.end, cursor.line.end, cursor.line.next),
        ),
      );
      return true;
    }
    return false;
  }

  void _summary(LineCursor cursor) {
    final block = leaf!;
    final close = findHtmlTag(
      source,
      cursor.offset,
      cursor.line.end,
      'summary',
      closing: true,
    );
    final end = close?.start ?? cursor.line.end;
    if (block.lastLine case final previous?)
      block.text.add(
        TextNode(span: SourceSpan(previous.end, previous.next), text: '\n'),
      );
    block.text.addAll(
      LineCursor(SourceLine(source, cursor.offset, end, end)).textFragments(),
    );
    block.lastLine = cursor.line;
    block.end = close?.end ?? cursor.line.end;
    _touch(cursor.line);
    if (close != null) {
      leaf = null;
      _queueSuffix(close.end, cursor.line);
    }
  }

  bool _tableStart(LineCursor cursor) {
    final block = leaf!;
    if (!options.tables ||
        block.lastLine == null ||
        block.text.any((n) => n is TextNode && n.text.contains('\n')))
      return false;
    if (!source.substring(block.start, cursor.line.end).contains('|'))
      return false;
    final delimiter = splitTableLine(
      source,
      cursor.offset,
      cursor.line.end,
      math: options.inlineMath,
      dollarMath: options.dollarInlineMath,
      maxMathLength: options.maxInlineMathLength,
    );
    final alignments = tableDelimiter(delimiter, source);
    if (alignments == null) return false;
    final header = splitTableLine(
      source,
      block.start,
      block.end,
      math: options.inlineMath,
      dollarMath: options.dollarInlineMath,
      maxMathLength: options.maxInlineMathLength,
    );
    if (!options.tablePipesOptional &&
        (!header.outerPipes || !delimiter.outerPipes))
      return false;
    if (header.cells.length != alignments.length ||
        !(header.hasPipe || delimiter.hasPipe))
      return false;
    block
      ..kind = _Kind.table
      ..alignments = alignments
      ..end = cursor.line.end;
    block.rows.add(
      TableRowNode(
        span: SourceSpan(block.start, block.lastLine!.end),
        children: header.cells,
        header: true,
      ),
    );
    block.text.clear();
    _touch(cursor.line);
    return true;
  }

  bool _tableRow(LineCursor cursor) {
    final block = leaf!;
    final row = splitTableLine(
      source,
      cursor.offset,
      cursor.line.end,
      math: options.inlineMath,
      dollarMath: options.dollarInlineMath,
      maxMathLength: options.maxInlineMathLength,
    );
    if (!options.tablePipesOptional && !row.outerPipes) return false;
    final cells = row.cells;
    final count = block.alignments.length;
    block.rows.add(
      TableRowNode(
        span: SourceSpan(cursor.sourceOffset, cursor.line.end),
        children: [
          ...cells.take(count),
          for (var i = cells.length; i < count; i++)
            TableCellNode(
              span: SourceSpan(cursor.line.end, cursor.line.end),
              children: const [],
            ),
        ],
      ),
    );
    block.end = cursor.line.end;
    _touch(cursor.line);
    return true;
  }

  int _directiveCloser(LineCursor cursor) {
    if (cursor.indentation.width > 3) return -1;
    final text = _trimmed(cursor);
    final closer = RegExp(r'^(:{3,})[ \t]*$').firstMatch(text);
    if (closer == null) return -1;
    return stack.lastIndexWhere(
      (block) =>
          block.syntax == NamedBlockSyntax.containerDirective &&
          closer[1]!.length >= block.fenceLength,
    );
  }

  bool _closeDirective(LineCursor cursor) {
    if (!options.directives) return false;
    final index = _directiveCloser(cursor);
    if (index < 0) return false;
    for (var i = 1; i < stack.length; i++) {
      stack[i].end = i < index ? cursor.line.next : cursor.line.start;
    }
    stack[index]
      ..end = cursor.line.end
      ..closed = true;
    stack.removeRange(index, stack.length);
    leaf = null;
    return true;
  }

  void _htmlLine(LineCursor cursor) {
    final block = leaf!;
    block.text.addAll(cursor.textFragments());
    if (cursor.line.next > cursor.line.end)
      block.text.add(
        TextNode(
          span: SourceSpan(cursor.line.end, cursor.line.next),
          text: '\n',
        ),
      );
    block.end = cursor.line.next;
    _touch(cursor.line);
    if (block.html!.feed(source, cursor.offset, cursor.line.end)) {
      block.closed = true;
      leaf = null;
    }
  }

  void _line(SourceLine line) {
    final cursor = LineCursor(line);
    var matched = 0;
    for (var i = 1; i < stack.length; i++) {
      final block = stack[i];
      if (block.kind == _Kind.quote || block.syntax == NamedBlockSyntax.alert) {
        final indent = cursor.indentation;
        if (indent.width > 3 ||
            indent.end == line.end ||
            source.codeUnitAt(indent.end) != 62)
          break;
        cursor.indent(indent.width);
        cursor.advance(1);
        cursor.indent(1);
      } else if (block.kind == _Kind.item) {
        if (!cursor.blank) {
          final width = cursor.indentation.width;
          if (width >= block.indent) {
            cursor.indent(block.indent);
          } else if (options.relaxedListIndentation &&
              width >= 2 &&
              _listStart.hasMatch(_trimmed(cursor))) {
            cursor.indent(width);
          } else {
            break;
          }
        }
      }
      matched = i;
    }

    if (matched < stack.length - 1) {
      final startsItem =
          stack[matched].kind == _Kind.list && _marker(cursor) != null;
      if (leaf?.kind == _Kind.paragraph &&
          !startsItem &&
          !cursor.blank &&
          !_interrupts(cursor)) {
        _paragraph(cursor);
        _drain();
        return;
      }
      leaf = null;
      stack.removeRange(matched + 1, stack.length);
    }

    _content(cursor);
    _drain();
  }

  void _drain() {
    while (_remaining.isNotEmpty) _content(_remaining.removeLast());
  }

  void _content(LineCursor cursor) {
    final line = cursor.line;
    if (leaf?.kind == _Kind.html) {
      if (leaf!.html!.start.rootTag == null &&
          leaf!.html!.start.terminator == null &&
          cursor.blank) {
        leaf = null;
      } else {
        _htmlLine(cursor);
        return;
      }
    }
    if (leaf?.kind == _Kind.math) {
      _math(cursor);
      return;
    }
    if (leaf?.kind == _Kind.code && leaf!.fenced) {
      final block = leaf!;
      final indentation = cursor.indentation.width;
      final text = _trimmed(cursor);
      final closer = RegExp(
        '^${RegExp.escape(block.marker)}{${block.fenceLength},}[ \\t]*\$',
      );
      if (indentation <= 3 && closer.hasMatch(text)) {
        block.closed = true;
        block.end = line.end;
        _touch(line);
        leaf = null;
      } else {
        cursor.indent(block.indent);
        _appendCode(block, cursor);
        _touch(line);
      }
      return;
    }

    if (leaf?.kind == _Kind.code && !leaf!.fenced) {
      if (cursor.blank || cursor.indentation.width >= 4) {
        cursor.indent(4);
        _appendCode(leaf!, cursor);
        leaf!.pendingBlank = cursor.blank;
        _touch(line);
        return;
      }
      if (leaf!.pendingBlank && stack.last.kind == _Kind.item)
        stack.last.pendingBlank = true;
      leaf = null;
    }

    if (leaf?.kind == _Kind.summary) {
      _summary(cursor);
      return;
    }
    if (_detailsBoundary(cursor)) return;
    if (_closeDirective(cursor)) return;
    if (leaf?.kind == _Kind.table) {
      if (!cursor.blank && !_interrupts(cursor)) {
        if (_tableRow(cursor)) return;
      }
      leaf = null;
    }

    if (cursor.blank) {
      leaf = null;
      if (stack.last.kind == _Kind.item) stack.last.pendingBlank = true;
      return;
    }

    if (leaf?.kind == _Kind.paragraph) {
      if (_tableStart(cursor)) return;
      if (options.setextHeadings &&
          cursor.indentation.width <= 3 &&
          _setext.hasMatch(_trimmed(cursor))) {
        leaf!
          ..kind = _Kind.heading
          ..level = _trimmed(cursor).startsWith('=') ? 1 : 2
          ..end = line.end;
        _touch(line);
        leaf = null;
        return;
      }
      if (!_interrupts(cursor)) {
        _paragraph(cursor);
        return;
      }
      leaf = null;
    }

    while (true) {
      final indentation = cursor.indentation.width;
      final text = _trimmed(cursor);
      final marker = _marker(cursor);
      if (stack.last.kind == _Kind.list &&
          (marker == null || !marker.matches(stack.last)))
        stack.removeLast();

      if (indentation <= 3 && text.startsWith('>')) {
        final quote = _add(_Kind.quote, cursor.sourceOffset)..end = line.end;
        stack.add(quote);
        cursor.indent(indentation);
        cursor.advance(1);
        cursor.indent(1);
        if (options.alerts) {
          final name = alertName(cursor.rest);
          if (name != null) {
            quote
              ..kind = _Kind.named
              ..name = name
              ..syntax = NamedBlockSyntax.alert;
            _touch(line);
            return;
          }
        }
        continue;
      }
      if (indentation <= 3 && _rule.hasMatch(text)) {
        if (stack.last.kind == _Kind.list) stack.removeLast();
        _add(_Kind.rule, cursor.sourceOffset).end = line.end;
        _touch(line);
        return;
      }
      if (marker != null) {
        _Block list;
        if (stack.last.kind == _Kind.list && marker.matches(stack.last)) {
          list = stack.last;
          if (list.children.last.pendingBlank) list.loose = true;
        } else {
          list = _add(_Kind.list, cursor.sourceOffset)
            ..ordered = marker.number != null
            ..number = marker.number ?? 1
            ..marker = marker.marker
            ..delimiter = marker.delimiter;
          stack.add(list);
        }
        final item = _add(_Kind.item, cursor.sourceOffset)
          ..indent = marker.indent + marker.width + marker.padding
          ..end = line.end;
        stack.add(item);
        cursor.indent(marker.indent);
        cursor.advance(marker.width);
        cursor.indent(marker.padding);
        if (cursor.blank) {
          _touch(line);
          return;
        }
        continue;
      }
      if (indentation <= 3 &&
          (options.standaloneTaskLine && options.taskItems ||
              options.radioItems) &&
          !(stack.last.kind == _Kind.item && stack.last.children.isEmpty)) {
        final task = matchTaskMarker(
          source,
          cursor.indentation.end,
          line.end,
          radioItems: options.radioItems,
          checkboxItems: options.taskItems && options.standaloneTaskLine,
        );
        if (task != null) {
          final node = _add(_Kind.task, task.start)
            ..checked = task.checked
            ..radio = task.radio
            ..markerSpan = SourceSpan(task.start, task.end)
            ..end = line.end;
          node.text.addAll(
            LineCursor(SourceLine(source, task.end, line.end, line.next))
                .textFragments(),
          );
          _touch(line);
          return;
        }
      }
      if (indentation <= 3) {
        final heading = _heading.firstMatch(text);
        if (heading != null) {
          cursor.indent(indentation);
          final node = _add(_Kind.heading, cursor.sourceOffset)
            ..level = heading[1]!.length
            ..end = line.end;
          cursor.advance(heading[1]!.length);
          cursor.indent(cursor.indentation.width);
          final content = cursor.rest
              .replaceFirst(RegExp(r'(?:^|[ \t]+)#+[ \t]*$'), '')
              .replaceFirst(RegExp(r'[ \t]+$'), '')
              .replaceAll('\u0000', '\uFFFD');
          if (content.isNotEmpty)
            node.text.add(
              TextNode(
                span: SourceSpan(
                  cursor.sourceOffset,
                  cursor.sourceOffset + content.length,
                ),
                text: content,
              ),
            );
          _touch(line);
          return;
        }
        final fence = _fenceStart.firstMatch(text);
        if (fence != null &&
            (!fence[1]!.startsWith('`') || !fence[2]!.contains('`'))) {
          final node = _add(_Kind.code, cursor.sourceOffset)
            ..fenced = true
            ..closed = false
            ..marker = fence[1]![0]
            ..fenceLength = fence[1]!.length
            ..indent = indentation
            ..info = fence[2]!.trim()
            ..end = line.end;
          leaf = node;
          _touch(line);
          return;
        }
      }
      if (options.indentedCode && indentation >= 4) {
        leaf = _add(_Kind.code, cursor.sourceOffset)..end = line.end;
        cursor.indent(4);
        _appendCode(leaf!, cursor);
        _touch(line);
        return;
      }
      if (cursor.blank) {
        _touch(line);
        return;
      }
      if (_detailsBoundary(cursor)) return;
      if (indentation <= 3 && options.directives) {
        final directive = readBlockDirective(
          source,
          cursor.indentation.end,
          line.end,
        );
        if (directive != null) {
          final block = _add(_Kind.named, directive.start)
            ..end = line.end
            ..name = directive.name
            ..attributes = directive.attributes
            ..syntax = directive.colons == 2
                ? NamedBlockSyntax.leafDirective
                : NamedBlockSyntax.containerDirective
            ..fenceLength = directive.colons
            ..closed = directive.colons == 2;
          if (directive.label case final label?) {
            final child = _Block(_Kind.label, label.start, parent: block)
              ..end = label.end;
            child.text.add(TextNode(span: label, text: label.slice(source)));
            block.children.add(child);
          }
          if (directive.colons >= 3) stack.add(block);
          _touch(line);
          return;
        }
      }
      if (indentation <= 3 && options.htmlBlocks) {
        final html = matchHtmlBlock(source, cursor.indentation.end, line.end);
        if (html != null) {
          cursor.indent(indentation);
          leaf = _add(_Kind.html, cursor.sourceOffset)
            ..html = HtmlBlockTracker(html)
            ..closed = false;
          _htmlLine(cursor);
          return;
        }
      }
      _paragraph(cursor);
      return;
    }
  }

  List<BlockNode> _freeze() {
    final frozen = <_Block, BlockNode>{};
    final pending = <(_Block, bool)>[(root, false)];
    while (pending.isNotEmpty) {
      final (block, visited) = pending.removeLast();
      if (!visited) {
        pending.add((block, true));
        for (final child in block.children.reversed)
          pending.add((child, false));
        continue;
      }
      if (block.kind == _Kind.root) break;
      final span = SourceSpan(block.start, block.end);
      final children = [for (final child in block.children) frozen[child]!];
      if (block.kind == _Kind.code && !block.fenced) {
        while (block.code.isNotEmpty && block.code.last.blank)
          block.code.removeLast();
      }
      frozen[block] = switch (block.kind) {
        _Kind.paragraph => ParagraphNode(span: span, children: block.text),
        _Kind.heading => HeadingNode(
          span: span,
          level: block.level,
          children: block.text,
        ),
        _Kind.rule => ThematicBreakNode(span),
        _Kind.quote => BlockQuoteNode(span: span, children: children),
        _Kind.list => ListNode(
          span: span,
          children: children.cast<ListItemNode>(),
          ordered: block.ordered,
          start: block.number,
          marker: block.marker,
          delimiter: block.delimiter,
          tight: !block.loose,
        ),
        _Kind.item => ListItemNode(
          span: span,
          children: children,
          checked: block.checked,
          radio: block.radio,
          markerSpan: block.markerSpan,
        ),
        _Kind.task => TaskItemNode(
          span: span,
          children: block.text,
          markerSpan: block.markerSpan!,
          checked: block.checked!,
          radio: block.radio,
        ),
        _Kind.table => TableNode(
          span: span,
          provisional: block.provisional,
          children: block.rows,
          alignments: block.alignments,
        ),
        _Kind.details => DetailsNode(
          span: span,
          children: children,
          open: block.open,
          closed: block.closed,
        ),
        _Kind.summary => DetailsSummaryNode(span: span, children: block.text),
        _Kind.named => NamedBlockNode(
          span: span,
          name: block.name,
          syntax: block.syntax!,
          attributes: {
            for (final entry in block.attributes.entries)
              entry.key: decodeMarkdownString(
                entry.value,
                entities: options.entities,
              ),
          },
          children: children,
          closed: block.closed,
        ),
        _Kind.label => DirectiveLabelNode(span: span, children: block.text),
        _Kind.html => HtmlBlockNode(
          span: span,
          children: block.html!.start.fullDocument
              ? const []
              : parseHtmlFragment(
                  block.text.cast<TextNode>(),
                  block: true,
                  entities: options.entities,
                ),
          rawFragments: block.text.cast<TextNode>(),
          fullDocument: block.html!.start.fullDocument,
          closed: block.closed,
        ),
        _Kind.math => MathBlockNode(
          span: span,
          children: block.text.cast<TextNode>(),
          delimiter: block.info,
          closed: block.closed,
        ),
        _Kind.code => CodeBlockNode(
          span: span,
          children: [for (final line in block.code) ...line.text],
          info: block.info,
          fenced: block.fenced,
          closed: block.closed,
          fenceCharacter: block.marker,
          fenceLength: block.fenceLength,
        ),
        _Kind.root => throw StateError('Root is not a block'),
      };
    }
    return [for (final block in root.children) frozen[block]!];
  }
}
