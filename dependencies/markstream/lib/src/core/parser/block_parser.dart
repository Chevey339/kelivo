import '../ast/nodes.dart';
import '../ast/source_span.dart';
import 'dialect.dart';
import 'source_line.dart';

/// Builds block structure before inline interpretation, using original offsets.
final class BlockParser {
  const BlockParser({this.options = const ParserOptions()});
  final ParserOptions options;

  DocumentNode parse(String source) => _BlockSession(source, options).parse();
}

enum _Kind { root, quote, list, item, paragraph, heading, rule, code }

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
  _BlockSession(this.source, this.options) {
    root = _Block(_Kind.root, 0)..end = source.length;
    stack.add(root);
  }
  final String source;
  final ParserOptions options;
  late final _Block root;
  final stack = <_Block>[];
  _Block? leaf;

  static final _listStart = RegExp(r'^([-+*]|[0-9]{1,9}[.)])(?=\s|$)');
  static final _fenceStart = RegExp(r'^(`{3,}|~{3,})(.*)$');
  static final _heading = RegExp(r'^(#{1,6})(?:[ \t]+|$)(.*)$');
  static final _rule = RegExp(
    r'^(?:(?:\*[ \t]*){3,}|(?:-[ \t]*){3,}|(?:_[ \t]*){3,})$',
  );
  static final _setext = RegExp(r'^(=+|-+)[ \t]*$');

  DocumentNode parse() {
    for (final line in SourceLine.scan(source)) {
      _line(line);
    }
    return DocumentNode(source: source, children: _freeze());
  }

  _ListMarker? _marker(LineCursor cursor) {
    final indentation = cursor.indentation;
    if (indentation.width > 3) return null;
    final rest = source.substring(indentation.end, cursor.line.end);
    final match = _listStart.firstMatch(rest);
    if (match == null) return null;
    final marker = match[1]!;
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
    cursor.indent(cursor.indentation.width);
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

  void _line(SourceLine line) {
    final cursor = LineCursor(line);
    var matched = 0;
    for (var i = 1; i < stack.length; i++) {
      final block = stack[i];
      if (block.kind == _Kind.quote) {
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
        return;
      }
      leaf = null;
      stack.removeRange(matched + 1, stack.length);
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

    if (cursor.blank) {
      leaf = null;
      if (stack.last.kind == _Kind.item) stack.last.pendingBlank = true;
      return;
    }

    if (leaf?.kind == _Kind.paragraph) {
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
              .replaceFirst(RegExp(r'[ \t]+#+[ \t]*$'), '')
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
        _Kind.item => ListItemNode(span: span, children: children),
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
