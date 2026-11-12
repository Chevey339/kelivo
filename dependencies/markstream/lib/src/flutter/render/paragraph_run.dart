import 'package:flutter/material.dart';

import '../../core/ast/nodes.dart';
import '../../core/text_index/text_index.dart';
import '../extensions/registry.dart';
import '../selection/document_selection.dart';
import '../selection/selection_controller.dart';
import 'block_builder.dart';
import 'streaming_text.dart';
import '../performance_limits.dart';
import 'native_paragraph_run.dart';
import '../selection/selectable_rich_text.dart';

/// Retains native paragraphs and their exact fractional block spacing while
/// sharing one selection projection. Completed paragraph widgets stay cached.
class ParagraphRun extends StatefulWidget {
  const ParagraphRun({
    super.key,
    required this.nodes,
    required this.renderer,
    required this.streaming,
  });
  final List<ParagraphNode> nodes;
  final MarkstreamRenderer renderer;
  final bool streaming;
  @override
  State<ParagraphRun> createState() => _ParagraphRunState();
}

class _ParagraphRunState extends State<ParagraphRun> {
  final _cached = <(ParagraphNode, bool, RenderedInline, Widget)>[];
  Object? _signature;
  final _selection = DocumentSelectionDelegate();
  @override
  void dispose() {
    _selection.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final renderer = widget.renderer;
    final defaults = DefaultTextStyle.of(context);
    final base = defaults.style.merge(renderer.theme.body);
    final locale = Localizations.maybeLocaleOf(context);
    final color = DefaultSelectionStyle.of(context).selectionColor;
    final selectable = SelectionContainer.maybeOf(context) != null;
    final signature = (
      renderer.theme,
      renderer.extensions,
      renderer.mathRenderer,
      renderer.imageBuilder,
      renderer.linkHandler,
      renderer.trackSelection,
      renderer.highlights,
      base,
      locale,
      color,
      selectable,
      defaults.textAlign,
      defaults.overflow,
      defaults.textWidthBasis,
    );
    if (signature != _signature) {
      _cached.clear();
      _signature = signature;
    }
    final children = <Widget>[];
    final segments = <TextSegment>[];
    var reuse = true;
    for (var i = 0; i < widget.nodes.length; i++) {
      final node = widget.nodes[i];
      final active = widget.streaming && i == widget.nodes.length - 1;
      if (reuse &&
          i < _cached.length &&
          identical(_cached[i].$1, node) &&
          _cached[i].$2 == active) {
        // Native paragraphs do not build or layout again during a tail append.
      } else {
        if (reuse) {
          _cached.removeRange(i, _cached.length);
          reuse = false;
        }
        final inline = renderer.inlineContent(
          context,
          node.children,
          renderer.theme.body,
          streaming: active,
        );
        var embedded = false;
        inline.span.visitChildren((span) {
          if (span is WidgetSpan) embedded = true;
          return !embedded;
        });
        final Widget body;
        if (!embedded &&
            node.span.length <=
                (active
                    ? PerformanceLimits.streamingNativeCharacters
                    : PerformanceLimits.staticNativeCharacters)) {
          body = RichText(
            key: ValueKey(node.span.start),
            text: TextSpan(style: base, children: [inline.span]),
            textAlign: defaults.textAlign ?? TextAlign.start,
            locale: locale,
            textDirection: Directionality.of(context),
            textScaler: MediaQuery.textScalerOf(context),
            softWrap: defaults.softWrap,
            overflow: defaults.overflow,
            textWidthBasis: defaults.textWidthBasis,
            selectionColor: color,
            selectionRegistrar: selectable ? _selection : null,
          );
        } else {
          final text = Text.rich(inline.span, style: renderer.theme.body);
          body = KeyedSubtree(
            key: ValueKey(node.span.start),
            child:
                node.span.length <=
                    (active
                        ? PerformanceLimits.streamingNativeCharacters
                        : PerformanceLimits.staticNativeCharacters)
                ? buildSelectableText(text)
                : StreamingText(streaming: active, text: text),
          );
        }
        _cached.add((node, active, inline, body));
      }
      children.add(_cached[i].$4);
      segments.addAll(_cached[i].$3.segments);
    }
    if (_cached.length > widget.nodes.length)
      _cached.removeRange(widget.nodes.length, _cached.length);
    final compressed = <Widget>[];
    for (var i = 0; i < children.length;) {
      if (children[i] is! RichText) {
        compressed.add(children[i++]);
        continue;
      }
      final native = <RichText>[];
      final start = i;
      // Fixed boundaries keep paragraph render objects in place as the tail
      // grows, while completed chunks retain their paint independently.
      while (i < children.length &&
          children[i] is RichText &&
          native.length < PerformanceLimits.nativeParagraphPaintCount)
        native.add(children[i++] as RichText);
      compressed.add(
        RepaintBoundary(
          key: ValueKey(widget.nodes[start].span.start),
          child: NativeParagraphRun(
            paragraphs: native,
            spacing: renderer.theme.blockSpacing,
          ),
        ),
      );
    }
    Widget body = Column(
      spacing: renderer.theme.blockSpacing,
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: compressed,
    );
    if (selectable)
      body = MouseRegion(
        cursor: SystemMouseCursors.text,
        child: SelectionContainer(delegate: _selection, child: body),
      );
    body = RepaintBoundary(child: body);
    if (renderer.trackSelection)
      body = MarkstreamSelectionFragment(
        node: widget.nodes.first,
        segments: segments,
        child: body,
      );
    return body;
  }
}
