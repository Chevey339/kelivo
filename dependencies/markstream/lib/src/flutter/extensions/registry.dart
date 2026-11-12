import 'dart:typed_data';

import 'package:flutter/widgets.dart';

import '../../core/ast/nodes.dart';
import '../../core/text_index/text_index.dart';
import '../../core/parser/syntax/block_syntax.dart';
import '../../core/parser/syntax/inline_syntax.dart';
import '../theme/markstream_theme.dart';
import '../render/chrome.dart';

/// Rendering callbacks use the same document, style and selection owner as
/// built-in nodes. Extensions must not create their own SelectionArea.
final class MarkstreamRenderContext {
  const MarkstreamRenderContext({
    required this.document,
    required this.theme,
    required this.streaming,
    required this.buildBlock,
    required this.buildInline,
  });
  final DocumentNode document;
  final MarkstreamTheme theme;
  final bool streaming;
  final Widget Function(BlockNode) buildBlock;
  final InlineSpan Function(InlineNode, TextStyle) buildInline;
}

typedef BlockNodeBuilder =
    Widget Function(
      BuildContext context,
      BlockNode node,
      MarkstreamRenderContext rendering,
    );

/// The selectable projection is explicit: WidgetSpan's object replacement
/// character is not the source text of a citation or other custom inline atom.
class RenderedInline {
  RenderedInline({required this.span, required List<TextSegment> segments})
    : segments = List.unmodifiable(segments);
  final InlineSpan span;
  final List<TextSegment> segments;
}

typedef InlineNodeBuilder =
    RenderedInline Function(
      BuildContext context,
      InlineNode node,
      MarkstreamRenderContext rendering,
    );
typedef CodeBlockBuilder =
    Widget Function(
      BuildContext context,
      CodeBlockNode node,
      MarkstreamRenderContext rendering,
    );

final class NodeBuilderRegistry {
  const NodeBuilderRegistry.empty() : blocks = const {}, inlines = const {};
  NodeBuilderRegistry({
    Map<Type, BlockNodeBuilder> blocks = const {},
    Map<Type, InlineNodeBuilder> inlines = const {},
  }) : blocks = Map.unmodifiable(blocks),
       inlines = Map.unmodifiable(inlines);
  final Map<Type, BlockNodeBuilder> blocks;
  final Map<Type, InlineNodeBuilder> inlines;
}

/// The application owns saving/sharing; the table supplies a full PNG capture.
final class TableActionContext {
  const TableActionContext({
    required this.table,
    required this.theme,
    required this.capturePng,
  });
  final TableNode table;
  final MarkstreamTheme theme;
  final Future<Uint8List> Function(double pixelRatio) capturePng;
}

final class CodeActionContext {
  const CodeActionContext({
    required this.code,
    required this.theme,
    required this.streaming,
  });
  final CodeBlockNode code;
  final MarkstreamTheme theme;
  final bool streaming;
}

typedef TableExtraActions =
    List<Widget> Function(BuildContext, TableActionContext);
typedef CodeExtraActions =
    List<Widget> Function(BuildContext, CodeActionContext);

/// Decorates literal code without changing its UTF-16 selectable projection.
/// Widget spans must each represent one source character and provide a
/// selectable adapter when their surrounding code is not already an atom.
typedef LiteralSpanBuilder =
    TextSpan Function(
      BuildContext context,
      TextSpan span,
      List<TextSegment> source,
    );

/// Immutable registration snapshot. Keep its identity across streaming updates.
final class MarkstreamExtensions {
  const MarkstreamExtensions.empty()
    : blockSyntaxes = const [],
      inlineSyntaxes = const [],
      nodeBuilders = const NodeBuilderRegistry.empty(),
      codeBlockBuilders = const {},
      directiveBuilders = const {},
      namedInlineBuilders = const {},
      tableExtraActions = null,
      mobileTableToolbarBuilder = null,
      codeExtraActions = null,
      actionButtonBuilder = null,
      literalSpanBuilder = null;

  MarkstreamExtensions({
    List<BlockSyntax> blockSyntaxes = const [],
    List<InlineSyntax> inlineSyntaxes = const [],
    this.nodeBuilders = const NodeBuilderRegistry.empty(),
    Map<String, CodeBlockBuilder> codeBlockBuilders = const {},
    Map<String, BlockNodeBuilder> directiveBuilders = const {},
    Map<String, InlineNodeBuilder> namedInlineBuilders = const {},
    this.tableExtraActions,
    this.mobileTableToolbarBuilder,
    this.codeExtraActions,
    this.actionButtonBuilder,
    this.literalSpanBuilder,
  }) : blockSyntaxes = List.unmodifiable(blockSyntaxes),
       inlineSyntaxes = List.unmodifiable(inlineSyntaxes),
       codeBlockBuilders = _normalized(codeBlockBuilders),
       directiveBuilders = _normalized(directiveBuilders),
       namedInlineBuilders = _normalized(namedInlineBuilders);

  final List<BlockSyntax> blockSyntaxes;
  final List<InlineSyntax> inlineSyntaxes;
  final NodeBuilderRegistry nodeBuilders;
  final Map<String, CodeBlockBuilder> codeBlockBuilders;
  final Map<String, BlockNodeBuilder> directiveBuilders;
  final Map<String, InlineNodeBuilder> namedInlineBuilders;
  final TableExtraActions? tableExtraActions;
  final Widget Function(BuildContext, TableActionContext)?
  mobileTableToolbarBuilder;
  final CodeExtraActions? codeExtraActions;
  final MarkstreamActionButtonBuilder? actionButtonBuilder;
  final LiteralSpanBuilder? literalSpanBuilder;

  static Map<String, T> _normalized<T>(Map<String, T> values) =>
      Map.unmodifiable({
        for (final entry in values.entries)
          entry.key.trim().toLowerCase(): entry.value,
      });

  BlockNodeBuilder? blockBuilderFor(BlockNode node) {
    if (node is CodeBlockNode) {
      final language = node.info
          .trim()
          .split(RegExp(r'\s+'))
          .first
          .toLowerCase();
      final builder = codeBlockBuilders[language];
      if (builder != null)
        return (context, _, rendering) => builder(context, node, rendering);
    }
    if (node is NamedBlockNode) {
      final builder = directiveBuilders[node.name.toLowerCase()];
      if (builder != null) return builder;
    }
    return nodeBuilders.blocks[node.runtimeType];
  }

  InlineNodeBuilder? inlineBuilderFor(InlineNode node) {
    if (node is NamedInlineNode) {
      final builder = namedInlineBuilders[node.name.toLowerCase()];
      if (builder != null) return builder;
    }
    return nodeBuilders.inlines[node.runtimeType];
  }

  Widget? buildBlock(
    BuildContext context,
    BlockNode node,
    MarkstreamRenderContext rendering,
  ) => blockBuilderFor(node)?.call(context, node, rendering);
  RenderedInline? buildInline(
    BuildContext context,
    InlineNode node,
    MarkstreamRenderContext rendering,
  ) => inlineBuilderFor(node)?.call(context, node, rendering);
}
