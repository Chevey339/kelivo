import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../core/ast/nodes.dart';
import '../core/ast/source_span.dart';
import 'render/source_highlights.dart';
import '../core/html/html_fragment.dart' show htmlBlockTags;
import '../core/parser/dialect.dart';
import '../core/parser/incremental_document.dart';
import '../core/parser/markdown_parser.dart';
import 'extensions/registry.dart';
import 'interfaces/renderers.dart';
import 'render/block_builder.dart';
import 'render/block_list.dart';
import 'render/chrome.dart';
import 'performance_limits.dart';
import 'render/paragraph_run.dart';
import 'selection/document_selection.dart';
import 'selection/selection_controller.dart';
import 'theme/markstream_theme.dart';

/// Renders source or a parsed snapshot inside the caller's SelectionArea.
class MarkstreamView extends StatefulWidget {
  const MarkstreamView({
    super.key,
    this.source,
    this.document,
    this.options = const ParserOptions(),
    this.streamingOptions = const StreamingOptions(),
    this.streaming = false,
    this.theme,
    this.extensions = const MarkstreamExtensions.empty(),
    this.codeHighlighter,
    this.mathRenderer,
    this.imageBuilder,
    this.linkHandler,
    this.cullToViewport = true,
    this.codeOptions = const CodeBlockOptions(),
    this.labels = const MarkstreamLabels(),
    this.exporting = false,
    this.selectionController,
    this.highlightRanges = const [],
    this.highlightColor,
  }) : assert((source == null) != (document == null));

  final String? source;
  final DocumentNode? document;
  final ParserOptions options;
  final StreamingOptions streamingOptions;
  final bool streaming;
  final MarkstreamTheme? theme;
  final MarkstreamExtensions extensions;
  final CodeHighlighter? codeHighlighter;
  final MathRenderer? mathRenderer;
  final ImageBuilder? imageBuilder;
  final LinkHandler? linkHandler;
  final bool cullToViewport;
  final CodeBlockOptions codeOptions;
  final MarkstreamLabels labels;
  final bool exporting;
  final MarkstreamSelectionController? selectionController;

  /// Original UTF-16 source intervals for search/TTS paint. Inline atoms are
  /// highlighted whole; decoded entities/escapes keep their source mapping.
  /// Supply a new list when changing ranges. This does not reparse the source.
  final List<SourceSpan> highlightRanges;
  final Color? highlightColor;

  @override
  State<MarkstreamView> createState() => _MarkstreamViewState();
}

class _MarkstreamViewState extends State<MarkstreamView> {
  static final _cjk = RegExp(r'[\u4E00-\u9FFF]');
  late IncrementalDocument _incremental;
  late DocumentNode _document;
  late final MarkstreamRenderer _renderer = MarkstreamRenderer(_recognizerFor);
  final _recognizers = <(int, int, String), TapGestureRecognizer>{};
  List<_BlockEntry> _entries = const [];
  bool? _entriesBatched;
  DocumentSelectionBinding? _binding;
  Timer? _pendingUpdate;
  Widget? _cachedView;
  DocumentNode? _cachedDocument;
  Object? _cachedSignature;

  @override
  void initState() {
    super.initState();
    _resetParser();
    _syncDocument();
  }

  void _resetParser() {
    _entries = const [];
    _incremental = IncrementalDocument(
      parser: MarkdownParser(
        options: widget.options,
        blockSyntaxes: widget.extensions.blockSyntaxes,
        inlineSyntaxes: widget.extensions.inlineSyntaxes,
      ),
      streamingOptions: widget.streamingOptions,
    );
  }

  @override
  void didUpdateWidget(MarkstreamView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final parserChanged =
        oldWidget.options != widget.options ||
        oldWidget.streamingOptions != widget.streamingOptions ||
        oldWidget.extensions != widget.extensions;
    if (parserChanged) _resetParser();
    if (oldWidget.linkHandler != widget.linkHandler) {
      for (final recognizer in _recognizers.values) {
        recognizer.dispose();
      }
      _recognizers.clear();
    }
    final source = widget.source;
    final previous = oldWidget.source;
    if (!parserChanged &&
        !widget.exporting &&
        widget.streaming &&
        source != null &&
        previous != null &&
        source.length >= PerformanceLimits.coalescingCharacters &&
        (source == previous || source.startsWith(previous)) &&
        oldWidget.streaming) {
      if (source == _document.source && _pendingUpdate == null) return;
      _pendingUpdate ??= Timer(PerformanceLimits.coalescingInterval, () {
        _pendingUpdate = null;
        if (mounted) setState(_syncDocument);
      });
      return;
    }
    _pendingUpdate?.cancel();
    _pendingUpdate = null;
    _syncDocument();
  }

  void _syncDocument() {
    _document =
        widget.document ??
        _incremental.update(widget.source!, streaming: widget.streaming);
    if (identical(_cachedDocument, _document) || _recognizers.isEmpty) return;
    // Cached prefix spans keep their recognizers. Remove only links that no
    // longer exist, rather than disposing recognizers on every streaming frame.
    final links = <(int, int, String)>{};
    final pending = <MarkdownNode>[_document];
    while (pending.isNotEmpty) {
      final node = pending.removeLast();
      if (node is LinkNode)
        links.add((node.span.start, node.span.end, node.destination));
      if (node is HtmlElementNode && node.tag == 'a') {
        final href = node.attributes['href'];
        if (href != null) links.add((node.span.start, node.span.end, href));
      }
      pending.addAll(node.children);
    }
    for (final key in _recognizers.keys.toList()) {
      if (!links.contains(key)) _recognizers.remove(key)!.dispose();
    }
  }

  TapGestureRecognizer _recognizerFor(LinkNode node, VoidCallback onTap) {
    final key = (node.span.start, node.span.end, node.destination);
    return (_recognizers[key] ??= TapGestureRecognizer())..onTap = onTap;
  }

  @override
  void dispose() {
    _pendingUpdate?.cancel();
    if (_binding case final binding?) binding.controller.detach(binding);
    for (final recognizer in _recognizers.values) {
      recognizer.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme =
        widget.theme ??
        MarkstreamTheme.fromColorScheme(
          Theme.of(context).colorScheme,
          bodyStyle: TextStyle(color: DefaultTextStyle.of(context).style.color),
          cjk: _cjk.hasMatch(_document.source),
        );
    final controller =
        widget.selectionController ?? MarkstreamSelectionScope.maybeOf(context);
    if (_binding?.controller != controller) {
      if (_binding case final binding?) binding.controller.detach(binding);
      _binding = controller == null
          ? null
          : DocumentSelectionBinding(
              _document,
              controller,
              () => context.findRenderObject() as RenderBox?,
            );
      if (_binding case final binding?) controller!.attach(binding);
    }
    _binding?.document = _document;
    final highlights = SourceHighlights(
      widget.highlightRanges,
      widget.highlightColor ??
          Theme.of(context).colorScheme.primary.withValues(alpha: .22),
    );
    final defaults = DefaultTextStyle.of(context);
    final batching =
        MediaQuery.textScalerOf(context) == TextScaler.noScaling &&
        Directionality.of(context) == TextDirection.ltr &&
        !MediaQuery.boldTextOf(context) &&
        MediaQuery.maybeLineHeightScaleFactorOverrideOf(context) == null &&
        MediaQuery.maybeLetterSpacingOverrideOf(context) == null &&
        MediaQuery.maybeWordSpacingOverrideOf(context) == null &&
        defaults.textHeightBehavior == null &&
        DefaultTextHeightBehavior.maybeOf(context) == null &&
        defaults.maxLines == null &&
        defaults.softWrap;
    final visualSignature = (
      theme,
      widget.extensions,
      widget.codeHighlighter,
      widget.mathRenderer,
      widget.imageBuilder,
      widget.linkHandler,
      widget.codeOptions,
      widget.labels,
      widget.exporting,
      widget.cullToViewport,
      _binding,
      widget.streaming,
      batching,
      highlights,
    );
    if (identical(_cachedDocument, _document) &&
        _cachedSignature == visualSignature)
      return _cachedView!;
    _cachedDocument = _document;
    _cachedSignature = visualSignature;
    _renderer.update(
      document: _document,
      theme: theme,
      extensions: widget.extensions,
      codeHighlighter: widget.codeHighlighter,
      mathRenderer: widget.mathRenderer,
      imageBuilder: widget.imageBuilder,
      linkHandler: widget.linkHandler,
      codeOptions: widget.codeOptions,
      labels: widget.labels,
      exporting: widget.exporting,
      trackSelection: _binding != null,
      highlights: highlights,
    );
    final nodes = _document.children
        .where((node) => node is! ReferenceDefinitionNode)
        .toList();
    bool batchable(BlockNode node) =>
        node is ParagraphNode &&
        widget.extensions.blockBuilderFor(node) == null &&
        !node.children.any(
          (child) =>
              child is HtmlElementNode && htmlBlockTags.contains(child.tag),
        );
    final entries = <_BlockEntry>[];
    var nextNode = 0;
    if (_entriesBatched == batching) {
      // Keep completed groups without allocating their node lists again. The
      // following node must also be unchanged: editing that boundary can merge
      // a paragraph into the previous run. Always regroup the growing tail.
      for (var index = 0; index + 1 < _entries.length; index++) {
        final entry = _entries[index];
        final end = nextNode + entry.nodes.length;
        if (end >= nodes.length ||
            (batching &&
                batchable(entry.node) &&
                !identical(nodes[end], _entries[index + 1].node)))
          break;
        var matches = true;
        for (var offset = 0; offset < entry.nodes.length; offset++) {
          if (!identical(nodes[nextNode + offset], entry.nodes[offset])) {
            matches = false;
            break;
          }
        }
        if (!matches) break;
        entries.add(entry);
        nextNode = end;
      }
    }
    for (var i = nextNode; i < nodes.length;) {
      final node = nodes[i];
      final group = <BlockNode>[];
      if (!batching || !batchable(node)) {
        group.add(node);
        i++;
      } else {
        var characters = 0;
        while (i < nodes.length &&
            batchable(nodes[i]) &&
            (group.isEmpty ||
                characters + nodes[i].span.length <=
                    PerformanceLimits.paragraphRunCharacters)) {
          group.add(nodes[i]);
          characters += nodes[i].span.length;
          i++;
        }
      }
      entries.add(
        _BlockEntry(
          group,
          widget.streaming && identical(group.last, _document.children.last),
        ),
      );
    }
    _entriesBatched = batching;
    _entries = entries;
    return _cachedView = SourceHighlightScope(
      highlights: highlights,
      child: DocumentSelectionScope(
        binding: _binding,
        child: DocumentSelectionGroup(
          node: _document,
          root: true,
          child: BlockList(
            blocks: entries,
            selectionSeparator: '\n\n',
            cullToViewport: widget.cullToViewport && !widget.exporting,
            signature: (
              theme,
              widget.extensions,
              widget.codeHighlighter,
              widget.mathRenderer,
              widget.imageBuilder,
              widget.linkHandler,
              widget.codeOptions,
              widget.labels,
              widget.exporting,
              _binding != null,
              batching,
              highlights,
            ),
            itemBuilder: (context, index) => Padding(
              key: ValueKey(entries[index].node.span.start),
              padding: EdgeInsets.only(
                top: index == 0
                    ? 0
                    : entries[index - 1].nodes.last is HeadingNode
                    ? theme.blockSpacing.clamp(0, 8)
                    : theme.blockSpacing,
              ),
              child: batching && batchable(entries[index].node)
                  ? ParagraphRun(
                      nodes: entries[index].nodes.cast<ParagraphNode>(),
                      renderer: _renderer,
                      streaming: entries[index].streaming,
                    )
                  : _renderer.build(
                      context,
                      entries[index].node,
                      streaming: entries[index].streaming,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BlockEntry {
  const _BlockEntry(this.nodes, this.streaming);
  final List<BlockNode> nodes;
  BlockNode get node => nodes.first;
  final bool streaming;
}
