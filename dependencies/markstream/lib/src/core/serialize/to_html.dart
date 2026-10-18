import '../ast/nodes.dart';
import '../html/html_fragment.dart';
import 'common.dart';

String escapeHtml(String value) => value
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');

// Preserve URI delimiters and existing percent escapes; encode Unicode and
// characters that cannot appear literally in an HTML link destination.
final _urlCharactersToEscape = RegExp(
  r"[^a-zA-Z0-9:/?#\[\]@!$&'()*+,;=%.~_\-]+",
  unicode: true,
);
String _htmlUrl(String value) => escapeHtml(
  value.replaceAllMapped(
    _urlCharactersToEscape,
    (match) => Uri.encodeComponent(match[0]!),
  ),
);

bool isSafeHtmlUrl(String value, {bool image = false}) {
  final normalized = value.replaceAll(RegExp(r'[\x00-\x20\x7F]'), '');
  final uri = Uri.tryParse(normalized);
  if (uri == null) return false;
  if (!uri.hasScheme) return true;
  if (const {
    'http',
    'https',
    'mailto',
    'tel',
    'file',
  }.contains(uri.scheme.toLowerCase()))
    return true;
  return image &&
      RegExp(
        r'^data:image/(?:png|jpeg|gif|webp);base64,[a-z0-9+/=]+$',
        caseSensitive: false,
      ).hasMatch(normalized);
}

String _safeStyle(String value) => value
    .split(';')
    .map((entry) {
      final colon = entry.indexOf(':');
      if (colon < 0) return '';
      final name = entry.substring(0, colon).trim().toLowerCase();
      final content = entry.substring(colon + 1).trim();
      if (!const {
        'color',
        'background-color',
        'font-weight',
        'font-style',
        'text-decoration',
        'font-size',
        'vertical-align',
        'text-align',
      }.contains(name))
        return '';
      if (!RegExp(
            r'^[a-z0-9#.,()% +\-]+$',
            caseSensitive: false,
          ).hasMatch(content) ||
          RegExp(
            r'url|expression|import|var\s*\(',
            caseSensitive: false,
          ).hasMatch(content))
        return '';
      return '$name:$content';
    })
    .where((entry) => entry.isNotEmpty)
    .join(';');

String _attributes(String tag, Map<String, String> attributes) {
  final safe = <String, String>{};
  for (final entry in attributes.entries) {
    final key = entry.key.toLowerCase();
    final value = entry.value;
    if (const {'title', 'id', 'class', 'alt'}.contains(key)) safe[key] = value;
    if (tag == 'a' && key == 'href' && isSafeHtmlUrl(value)) safe[key] = value;
    if (tag == 'img' && key == 'src' && isSafeHtmlUrl(value, image: true))
      safe[key] = value;
    if (tag == 'ol' && key == 'start') {
      final start = int.tryParse(value);
      if (start != null) safe[key] = '$start';
    }
    if (const {'colspan', 'rowspan', 'width', 'height'}.contains(key) &&
        RegExp(r'^[0-9]{1,5}$').hasMatch(value))
      safe[key] = value;
    if (key == 'align' && const {'left', 'center', 'right'}.contains(value))
      safe[key] = value;
    if (tag == 'details' && key == 'open') safe[key] = '';
    if (tag == 'span' && key == 'style') {
      final style = _safeStyle(value);
      if (style.isNotEmpty) safe[key] = style;
    }
    if (tag == 'font' &&
        key == 'color' &&
        RegExp(r'^[a-z0-9#]+$', caseSensitive: false).hasMatch(value))
      safe[key] = value;
  }
  return safe.entries.map((e) => ' ${e.key}="${escapeHtml(e.value)}"').join();
}

/// Portable HTML for export and clipboard use; active tags and URL schemes are excluded.
String toHtml(MarkdownNode root) => serializeNodes(root, (node, output) {
  final body = joinChildren(node, output);
  if (node is TextNode) return escapeHtml(node.text);
  if (node is LineBreakNode) return node.hard ? '<br />\n' : '\n';
  if (node is ReferenceDefinitionNode) return '';
  if (node is ParagraphNode) return '<p>$body</p>\n';
  if (node is HeadingNode) return '<h${node.level}>$body</h${node.level}>\n';
  if (node is EmphasisNode) {
    final tag = node.strong ? 'strong' : 'em';
    return '<$tag>$body</$tag>';
  }
  if (node is StrikethroughNode) return '<del>$body</del>';
  if (node is CodeSpanNode) return '<code>${escapeHtml(node.code)}</code>';
  if (node is CodeBlockNode || node is HtmlBlockNode && node.fullDocument) {
    final raw = node is CodeBlockNode ? node.code : (node as HtmlBlockNode).raw;
    final code = node is CodeBlockNode || raw.isEmpty || raw.endsWith('\n')
        ? raw
        : '$raw\n';
    final language = node is CodeBlockNode
        ? node.info.split(RegExp(r'\s+')).first
        : 'html';
    return '<pre><code${language.isEmpty ? '' : ' class="language-${escapeHtml(language)}"'}>${escapeHtml(code)}</code></pre>\n';
  }
  if (node is MathInlineNode)
    return '<span class="math">${escapeHtml(mathSource(node.tex, node.delimiter, block: false, closed: node.closed))}</span>';
  if (node is MathBlockNode)
    return '<div class="math">${escapeHtml(mathSource(node.tex, node.delimiter, block: true, closed: node.closed))}</div>\n';
  if (node is ThematicBreakNode) return '<hr />\n';
  if (node is LinkNode)
    return '<a${isSafeHtmlUrl(node.destination) ? ' href="${_htmlUrl(node.destination)}"' : ''}${node.title == null ? '' : ' title="${escapeHtml(node.title!)}"'}>$body</a>';
  if (node is ImageNode) {
    final text = StringBuffer();
    final pending = <MarkdownNode>[...node.children.reversed];
    while (pending.isNotEmpty) {
      final current = pending.removeLast();
      if (current is TextNode) {
        text.write(current.text);
      } else if (current is LineBreakNode) {
        text.write('\n');
      } else {
        pending.addAll(current.children.reversed);
      }
    }
    return '<img${isSafeHtmlUrl(node.destination, image: true) ? ' src="${_htmlUrl(node.destination)}"' : ''} alt="${escapeHtml(text.toString())}"${node.title == null ? '' : ' title="${escapeHtml(node.title!)}"'} />';
  }
  if (node is BlockQuoteNode) return '<blockquote>\n$body</blockquote>\n';
  if (node is ListNode) {
    final tag = node.ordered ? 'ol' : 'ul';
    final rows = StringBuffer();
    for (final item in node.children) {
      final contents = StringBuffer();
      final task = item.checked == null
          ? ''
          : '<input type="${item.radio ? 'radio' : 'checkbox'}" disabled=""${item.checked! ? ' checked=""' : ''} /> ';
      if (item.children.isEmpty || item.children.first is! ParagraphNode)
        contents.write(task);
      for (var i = 0; i < item.children.length; i++) {
        final child = item.children[i];
        if (child is ParagraphNode) {
          final paragraph =
              '${i == 0 ? task : ''}${joinChildren(child, output)}';
          contents.write(node.tight ? paragraph : '<p>$paragraph</p>\n');
          if (node.tight && i + 1 < item.children.length) contents.write('\n');
        } else {
          contents.write(output[child]);
        }
      }
      final startsWithBlock =
          item.children.isNotEmpty && item.children.first is! ParagraphNode;
      rows.write(
        '<li>${!node.tight || startsWithBlock ? '\n' : ''}$contents</li>\n',
      );
    }
    return '<$tag${node.ordered && node.start != 1 ? ' start="${node.start}"' : ''}>\n$rows</$tag>\n';
  }
  if (node is ListItemNode) return '<li>\n$body</li>\n';
  if (node is TaskItemNode)
    return '<p><input type="${node.radio ? 'radio' : 'checkbox'}" disabled=""${node.checked ? ' checked=""' : ''} /> $body</p>\n';
  if (node is TableNode) {
    String row(TableRowNode row) {
      final cells = [
        for (var i = 0; i < row.children.length; i++)
          '<${row.header ? 'th' : 'td'}${i < node.alignments.length && node.alignments[i] != TableAlignment.none ? ' align="${node.alignments[i].name}"' : ''}>${output[row.children[i]]}</${row.header ? 'th' : 'td'}>\n',
      ].join();
      return '<tr>\n$cells</tr>\n';
    }

    if (node.children.isEmpty) return '<table></table>\n';
    return '<table>\n<thead>\n${row(node.children.first)}</thead>\n${node.children.length <= 1 ? '' : '<tbody>\n${node.children.skip(1).map(row).join()}</tbody>\n'}</table>\n';
  }
  if (node is DetailsSummaryNode) return '<summary>$body</summary>\n';
  if (node is DetailsNode)
    return '<details${node.open ? ' open=""' : ''}>\n$body</details>\n';
  if (node is NamedBlockNode)
    return '<aside data-${node.syntax == NamedBlockSyntax.alert ? 'alert' : 'directive'}="${escapeHtml(node.name)}"${_attributes('aside', node.attributes)}>\n$body</aside>\n';
  if (node is NamedInlineNode)
    return '<span data-${node.syntax == NamedInlineSyntax.directive ? 'directive' : 'extension'}="${escapeHtml(node.name)}"${_attributes('span', node.attributes)}>$body</span>';
  if (node is HtmlElementNode) {
    if (discardedHtmlTags.contains(node.tag)) return '';
    if (!htmlBlockTags.contains(node.tag) && !htmlInlineTags.contains(node.tag))
      return body;
    final attrs = _attributes(node.tag, node.attributes);
    if (const {'br', 'img', 'hr'}.contains(node.tag))
      return '<${node.tag}$attrs />';
    return '<${node.tag}$attrs>$body</${node.tag}>${htmlBlockTags.contains(node.tag) ? '\n' : ''}';
  }
  return body;
})[root]!;
