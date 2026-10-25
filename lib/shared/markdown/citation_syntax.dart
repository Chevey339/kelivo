import 'package:flutter/material.dart';
import 'package:markstream/markstream.dart';

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
                      _label(ref, scope),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
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

  String _label(CitationRef ref, CitationScope? scope) {
    final resolved = scope?.resolve?.call(ref.id);
    if (resolved != null && resolved.isNotEmpty) return resolved;
    if (ref.index != ref.id || int.tryParse(ref.index) != null) {
      return ref.index;
    }
    return '?';
  }
}
