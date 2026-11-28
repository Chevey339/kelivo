import 'package:markstream/markstream_core.dart';

import '../../../shared/markdown/markdown_image_sources.dart';

/// The prefix identifying the owning session in a qualified link or host path.
/// Only this prefix changes. Labels, titles, escapes and reference-link syntax
/// retain their original source positions when a UUID is replaced by a UUID.
typedef SessionLinkEdit = ({String from, String to});
typedef SessionTextShift = ({int at, int before, int after});

String rewriteSessionFileLinks(
  String text,
  SessionLinkEdit? Function(String) visitFile, {
  bool toolOutput = false,
  List<SessionTextShift>? lengthChanges,
  Set<SourceSpan>? sections,
}) {
  final edits = <int, SessionLinkEdit>{};
  for (final range in sections ?? [SourceSpan(0, text.length)]) {
    final local = _collect(
      text.substring(range.start, range.end),
      visitFile,
      toolOutput,
    );
    for (final entry in local.entries) {
      edits[range.start + entry.key] = entry.value;
    }
  }
  if (edits.isEmpty) return text;
  final result = StringBuffer();
  var cursor = 0;
  for (final at in edits.keys.toList()..sort()) {
    final edit = edits[at]!;
    result
      ..write(text.substring(cursor, at))
      ..write(edit.to);
    if (edit.from.length != edit.to.length) {
      lengthChanges?.add((
        at: at,
        before: edit.from.length,
        after: edit.to.length,
      ));
    }
    cursor = at + edit.from.length;
  }
  return (result..write(text.substring(cursor))).toString();
}

Map<int, SessionLinkEdit> _collect(
  String text,
  SessionLinkEdit? Function(String) visitFile,
  bool toolOutput,
) {
  final document = MarkdownParser(
    inlineSyntaxes: const [LocalImagePathSyntax()],
  ).parse(text);
  final edits = <int, SessionLinkEdit>{};
  final referenced = <String>{};
  void visit(String uri, int start, int end) {
    referenced.add(uri);
    final edit = visitFile(uri);
    if (edit == null || start < 0 || start >= end) return;
    final raw = text.substring(start, end);
    // Keep all original source spelling except the changed owner characters.
    var left = 0, right = 0;
    while (left < edit.from.length &&
        left < edit.to.length &&
        edit.from[left] == edit.to[left]) {
      left++;
    }
    while (right < edit.from.length - left &&
        right < edit.to.length - left &&
        edit.from[edit.from.length - right - 1] ==
            edit.to[edit.to.length - right - 1]) {
      right++;
    }
    final found = raw.indexOf(edit.from);
    late final SourceSpan range;
    if (found >= 0) {
      range = SourceSpan(found + left, found + edit.from.length - right);
    } else {
      if (!raw.contains(r'\') && !raw.contains('&')) return;
      final mapped = decodeMappedMarkdownString(raw);
      final at = mapped.text.indexOf(edit.from);
      if (at < 0) return;
      range = mapped.span(at + left, at + edit.from.length - right);
    }
    edits[start + range.start] = (
      from: raw.substring(range.start, range.end),
      to: edit.to.substring(left, edit.to.length - right),
    );
  }

  final pending = <MarkdownNode>[document];
  while (pending.isNotEmpty) {
    final node = pending.removeLast();
    final span = node.span;
    if (node is CodeBlockNode ||
        node is CodeSpanNode ||
        node is HtmlElementNode && (node.tag == 'code' || node.tag == 'pre')) {
      continue;
    }
    if (node is LinkNode || node is ImageNode) {
      final uri = node is LinkNode
          ? node.destination
          : (node as ImageNode).destination;
      // A reference-style occurrence gets its raw destination from its definition.
      final afterLabel = node.children.lastOrNull?.span.end ?? span.start;
      final delimiter = text.substring(afterLabel, span.end).indexOf('](');
      final start = node is LinkNode && node.autolink
          ? span.start
          : delimiter < 0
          ? -1
          : afterLabel + delimiter + 2;
      visit(uri, start, span.end);
      // Nested images can have a separate file, but the visible label of a
      // tool-result link is not another bare file address.
      pending.addAll(node.children.where((child) => child is! TextNode));
      continue;
    }
    if (node is HtmlElementNode && (node.tag == 'a' || node.tag == 'img')) {
      final key = node.tag == 'a' ? 'href' : 'src';
      final uri = node.attributes[key];
      if (uri != null && isSafeHtmlUrl(uri, image: node.tag == 'img')) {
        final open = text.substring(
          span.start,
          node.children.firstOrNull?.span.start ?? span.end,
        );
        final attr = RegExp(
          '\\s$key\\s*=',
          caseSensitive: false,
        ).firstMatch(open);
        visit(
          uri,
          attr == null ? -1 : span.start + attr.end,
          span.start + open.length,
        );
      }
    } else if (toolOutput && node is TextNode) {
      final raw = text.substring(span.start, span.end);
      for (final match in _barePath.allMatches(raw)) {
        final quoted = match[1] ?? match[2];
        if (quoted != null) {
          visit(
            quoted,
            span.start + match.start + 1,
            span.start + match.end - 1,
          );
          continue;
        }
        var uri = match[0]!;
        // Surrounding sentence punctuation is outside a bare destination.
        // Structured fields and Markdown destinations already supplied exact names.
        uri = uri.replaceFirst(_trailingPunctuation, '');
        for (final pair in const [('(', ')'), ('[', ']'), ('{', '}')]) {
          var excess =
              pair.$2.allMatches(uri).length - pair.$1.allMatches(uri).length;
          var end = uri.length;
          while (excess > 0 && end > 0 && uri[end - 1] == pair.$2) {
            excess--;
            end--;
          }
          uri = uri.substring(0, end);
        }
        visit(
          uri,
          span.start + match.start,
          span.start + match.start + uri.length,
        );
      }
    }
    pending.addAll(node.children.reversed);
  }
  for (final definition in document.references.values) {
    if (referenced.contains(definition.destination)) {
      visit(
        definition.destination,
        text.indexOf(']:', definition.span.start),
        definition.span.end,
      );
    }
  }
  return edits;
}

// Consume whole URI tokens, including foreign ones. A /chat/ segment inside
// a workspace URL or host path must never be rediscovered as a guest root.
const _addressStart = r'(?:[a-zA-Z][a-zA-Z0-9+.-]*://|[a-zA-Z]:[/\\]|/)';
final _barePath = RegExp(
  r'(?<![a-zA-Z0-9_./\\-])'
  '(?:"($_addressStart[^"\\n]+)"|'
  "'($_addressStart[^'\\n]+)'|"
  "$_addressStart"
  r'''[^\s<>"'`]+)''',
);
final _trailingPunctuation = RegExp(r'[.,;!?，。；！？]+$');
