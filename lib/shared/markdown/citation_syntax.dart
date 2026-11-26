import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:markstream/markstream.dart';
import 'package:Kelivo/theme/app_font_weights.dart';

/// Recognizes only explicit citation markers; ordinary [1] remains text.
class CitationSyntax extends InlineSyntax {
  const CitationSyntax();
  static final _cite = RegExp(
    r'\[cite:[ \t]*([A-Za-z0-9_-]+(?:[ \t]*,[ \t]*[A-Za-z0-9_-]+)*)[ \t]*\]',
    caseSensitive: false,
  );
  static final _metadata = RegExp(
    r'\[citation:([^\]\r\n]+)\]',
    caseSensitive: false,
  );
  static final _link = RegExp(
    r'\[citation\]\(([^)\r\n]+)\)',
    caseSensitive: false,
  );
  static final _nestedLink = RegExp(r'\[\[(\d+)\]\]\(([^\s)]+)\)');
  @override
  Set<int> get startCharacters => const {91};
  @override
  InlineSyntaxMatch? match(InlineSyntaxContext context, int offset) {
    final nested = _nestedLink.matchAsPrefix(context.text, offset);
    if (nested != null) {
      return InlineSyntaxMatch(
        end: nested.end,
        node: LinkNode(
          span: context.span(offset, nested.end),
          destination: nested[2]!,
          children: context.textNodes(
            offset + 2,
            offset + 2 + nested[1]!.length,
          ),
        ),
      );
    }
    final match =
        _cite.matchAsPrefix(context.text, offset) ??
        _metadata.matchAsPrefix(context.text, offset) ??
        _link.matchAsPrefix(context.text, offset);
    if (match == null || parseCitationRefs(match[1]!).isEmpty) return null;
    return InlineSyntaxMatch(
      end: match.end,
      node: NamedInlineNode(
        span: context.span(offset, match.end),
        name: 'kelivo-citation',
        attributes: {'refs': match[1]!},
        children: context.textNodes(offset, match.end),
      ),
    );
  }
}

class CitationRef {
  const CitationRef(this.index, this.id);
  final String index, id;

  String label(String? Function(String)? resolve) {
    final resolved = resolve?.call(id);
    if (resolved != null && resolved.isNotEmpty) return resolved;
    return index != id || int.tryParse(index) != null ? index : '?';
  }
}

/// Latest search results win when several tools return the same citation.
List<Map<String, dynamic>> citationSearchItems(
  Iterable<({String name, String? content})> newestFirst,
) {
  final items = <Map<String, dynamic>>[];
  final seen = <String>{};
  for (final tool in newestFirst) {
    if (tool.name != 'search_web' && tool.name != 'builtin_search') continue;
    final content = tool.content;
    if (content == null || content.isEmpty) continue;
    try {
      final result = jsonDecode(content);
      if (result is! Map || result['items'] is! List) continue;
      for (final item in result['items'] as List) {
        if (item is! Map<String, dynamic>) continue;
        final key = (item['id'] ?? item['url'] ?? '').toString();
        if (key.isEmpty || seen.add(key)) items.add(item);
      }
    } on FormatException {
      // An unfinished or malformed tool result contributes no citations.
    }
  }
  return items;
}

Map<String, String> citationIndexLookup(List<Map<String, dynamic>> items) {
  final lookup = <String, String>{};
  for (final item in items) {
    final id = item['id']?.toString() ?? '';
    final index = item['index']?.toString() ?? '';
    if (id.isNotEmpty && index.isNotEmpty) lookup[id] ??= index;
  }
  for (final item in items) {
    final index = item['index']?.toString() ?? '';
    if (index.isNotEmpty) lookup[index] ??= index;
  }
  return lookup;
}

String? resolveCitationIndex(Map<String, String> lookup, String id) {
  final key = id.trim();
  if (lookup[key] case final String value) return value;
  final number = int.tryParse(key);
  return number == null ? null : lookup[number.toString()];
}

final _citationIndex = RegExp(r'^[A-Za-z0-9_-]+$');
List<CitationRef> parseCitationRefs(String source) {
  final result = <CitationRef>[];
  for (var part in source.split(',')) {
    part = part.trim();
    if (part.toLowerCase().startsWith('citation:')) {
      part = part.substring(9).trim();
    }
    final separator = part.indexOf(':');
    final index = (separator < 0 ? part : part.substring(0, separator)).trim();
    final id = (separator < 0 ? part : part.substring(separator + 1)).trim();
    if (!_citationIndex.hasMatch(index) ||
        (separator >= 0 && !RegExp(r'\d').hasMatch(index)) ||
        id.isEmpty ||
        RegExp(r'[\s)\]]').hasMatch(id)) {
      return const [];
    }
    result.add(CitationRef(index, id));
  }
  return result;
}

/// Cached citation widgets still respond to changed search-result indices.
class CitationScope extends InheritedWidget {
  const CitationScope({
    super.key,
    required super.child,
    this.onTap,
    this.resolve,
  });
  final void Function(String id)? onTap;
  final String? Function(String id)? resolve;
  static CitationScope? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<CitationScope>();
  @override
  bool updateShouldNotify(CitationScope oldWidget) =>
      oldWidget.onTap != onTap || oldWidget.resolve != resolve;
}

RenderedInline buildCitation(
  BuildContext context,
  InlineNode node,
  MarkstreamRenderContext rendering,
) {
  final citation = node as NamedInlineNode;
  // A comma-separated marker is one source atom. Copying it retains the exact
  // original marker, even if its displayed indices change with search results.
  final source = toPlainText(citation);
  return RenderedInline(
    segments: [TextSegment(text: source, sourceSpan: node.span, node: node)],
    span: WidgetSpan(
      alignment: PlaceholderAlignment.baseline,
      baseline: TextBaseline.alphabetic,
      child: SelectableSpanAdapter(
        selectedText: source,
        mouseCursor: SystemMouseCursors.click,
        child: MediaQuery.withNoTextScaling(
          child: OpticalBaseline(
            center: rendering.theme.inlineCode.opticalCenter,
            child: _CitationChips(
              refs: parseCitationRefs(citation.attributes['refs']!),
            ),
          ),
        ),
      ),
    ),
  );
}

class _CitationChips extends StatelessWidget {
  const _CitationChips({required this.refs});
  final List<CitationRef> refs;
  @override
  Widget build(BuildContext context) {
    final scope = CitationScope.of(context),
        scheme = Theme.of(context).colorScheme;
    return Wrap(
      runSpacing: 3,
      children: [
        for (final ref in refs)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 1.5),
            child: Semantics(
              button: scope?.onTap != null,
              child: GestureDetector(
                onTap: scope?.onTap == null
                    ? null
                    : () => scope!.onTap!(ref.id),
                child: Container(
                  constraints: const BoxConstraints(minWidth: 18),
                  height: 18,
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(
                      alpha: scheme.brightness == Brightness.dark ? .22 : .12,
                    ),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Center(
                    widthFactor: 1,
                    child: Text(
                      ref.label(scope?.resolve),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: AppFontWeights.semibold,
                        fontFeatures: const [FontFeature.tabularFigures()],
                        height: 1,
                        color: scheme.primary,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
