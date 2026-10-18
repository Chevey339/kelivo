import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../core/ast/nodes.dart';
import '../core/parser/dialect.dart';
import '../core/parser/incremental_document.dart';
import '../core/parser/markdown_parser.dart';
import 'extensions/registry.dart';
import 'interfaces/renderers.dart';
import 'render/block_builder.dart';
import 'render/block_list.dart';
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

  @override
  void initState() {
    super.initState();
    _resetParser();
    _syncDocument();
  }

  void _resetParser() {
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
    if (oldWidget.options != widget.options ||
        oldWidget.streamingOptions != widget.streamingOptions ||
        oldWidget.extensions != widget.extensions)
      _resetParser();
    if (oldWidget.linkHandler != widget.linkHandler) {
      for (final recognizer in _recognizers.values) {
        recognizer.dispose();
      }
      _recognizers.clear();
    }
    _syncDocument();
  }

  void _syncDocument() {
    _document =
        widget.document ??
        _incremental.update(widget.source!, streaming: widget.streaming);
    // Cached prefix spans keep their recognizers. Remove only links that no
    // longer exist, rather than disposing recognizers on every streaming frame.
    final links = <(int, int, String)>{};
    final pending = <MarkdownNode>[_document];
    while (pending.isNotEmpty) {
      final node = pending.removeLast();
      if (node is LinkNode)
        links.add((node.span.start, node.span.end, node.destination));
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
    _renderer.update(
      document: _document,
      theme: theme,
      extensions: widget.extensions,
      codeHighlighter: widget.codeHighlighter,
      mathRenderer: widget.mathRenderer,
      imageBuilder: widget.imageBuilder,
      linkHandler: widget.linkHandler,
    );
    final nodes = _document.children
        .where((node) => node is! ReferenceDefinitionNode)
        .toList();
    final entries = <_BlockEntry>[];
    var reuse = true;
    for (var i = 0; i < nodes.length; i++) {
      final active =
          widget.streaming && identical(nodes[i], _document.children.last);
      if (reuse &&
          i < _entries.length &&
          identical(nodes[i], _entries[i].node) &&
          active == _entries[i].streaming) {
        entries.add(_entries[i]);
      } else {
        reuse = false;
        entries.add(_BlockEntry(nodes[i], active));
      }
    }
    _entries = entries;
    return BlockList(
      blocks: entries,
      cullToViewport: widget.cullToViewport,
      signature: (
        theme,
        widget.extensions,
        widget.codeHighlighter,
        widget.mathRenderer,
        widget.imageBuilder,
        widget.linkHandler,
      ),
      itemBuilder: (context, index) => Padding(
        key: ValueKey(entries[index].node.span.start),
        padding: EdgeInsets.only(top: index == 0 ? 0 : theme.blockSpacing),
        child: _renderer.build(
          context,
          entries[index].node,
          streaming: entries[index].streaming,
        ),
      ),
    );
  }
}

class _BlockEntry {
  const _BlockEntry(this.node, this.streaming);
  final BlockNode node;
  final bool streaming;
}
