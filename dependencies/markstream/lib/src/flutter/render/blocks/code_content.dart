import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/ast/nodes.dart';
import '../../../core/ast/source_span.dart';
import '../../../core/text_index/text_index.dart';
import '../../../core/serialize/to_plain_text.dart';
import '../../interfaces/renderers.dart';
import '../../extensions/registry.dart' show LiteralSpanBuilder;
import '../../selection/source_text_selection.dart';
import '../../selection/selection_controller.dart';
import '../../theme/markstream_theme.dart';
import '../streaming_text.dart';
import '../source_highlights.dart';
import '../../performance_limits.dart';

String codePrefix(String source, int? lines) {
  if (lines == null) return source;
  var offset = 0;
  for (var i = 0; i < lines; i++) {
    final end = source.indexOf('\n', offset);
    if (end < 0) return source;
    if (i == lines - 1) return source.substring(0, end);
    offset = end + 1;
  }
  return source;
}

int codeLineCount(String source) =>
    source.isEmpty ? 0 : '\n'.allMatches(source).length + 1;

/// Code body usable by both built-in chrome and application diagram sources.
class MarkstreamCodeContent extends StatefulWidget {
  const MarkstreamCodeContent({
    super.key,
    required this.node,
    required this.theme,
    this.highlighter,
    this.streaming = false,
    this.exporting = false,
    this.wrap = true,
    this.highlight = true,
    this.maxLines,
    this.literalSpanBuilder,
  });
  final CodeBlockNode node;
  final MarkstreamTheme theme;
  final CodeHighlighter? highlighter;
  final bool streaming, exporting, wrap, highlight;
  final int? maxLines;
  final LiteralSpanBuilder? literalSpanBuilder;
  @override
  State<MarkstreamCodeContent> createState() => _MarkstreamCodeContentState();
}

class _MarkstreamCodeContentState extends State<MarkstreamCodeContent> {
  final _selection = SourceTextSelectionDelegate();
  final _chunks = <(int, String)>[];
  String _source = '';
  int _lastChunkStart = 0;
  TextIndex? _literalIndex;

  @override
  void initState() {
    super.initState();
    _update();
  }

  @override
  void didUpdateWidget(MarkstreamCodeContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.node != widget.node) _literalIndex = null;
    _update();
  }

  void _update() {
    final next = codePrefix(toPlainText(widget.node), widget.maxLines);
    if (next == _source && _chunks.isNotEmpty) return;
    var start = 0;
    if (_chunks.isNotEmpty && next.startsWith(_source)) {
      start = _lastChunkStart;
      _chunks.removeLast();
    } else {
      _chunks.clear();
    }
    var lines = 0;
    var cursor = start;
    while (true) {
      final newline = next.indexOf('\n', cursor);
      if (newline < 0) break;
      if (++lines == PerformanceLimits.codeChunkLines) {
        _chunks.add((start, next.substring(start, newline)));
        start = newline + 1;
        lines = 0;
      }
      cursor = newline + 1;
    }
    _chunks.add((start, next.substring(start)));
    _lastChunkStart = start;
    _source = next;
    _selection.source = next;
  }

  @override
  void dispose() {
    _selection.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final language = widget.node.info
        .trim()
        .split(RegExp(r'\s+'))
        .first
        .toLowerCase();
    final highlight =
        widget.highlight &&
        !(widget.streaming &&
            !widget.exporting &&
            (_source.length > PerformanceLimits.highlightCharacters ||
                codeLineCount(_source) > PerformanceLimits.highlightLines));
    final highlights = SourceHighlightScope.of(context);
    final ranges = highlights.isEmpty
        ? const <SourceSpan>[]
        : highlights.textRanges([
            for (final part in widget.node.children)
              TextSegment(text: part.text, sourceSpan: part.span, node: part),
          ]);
    Widget fragment(String text, int offset) {
      final literal = widget.literalSpanBuilder;
      if (literal != null) {
        _literalIndex ??= TextIndex.fromSegments([
          for (final part in widget.node.children)
            TextSegment(text: part.text, sourceSpan: part.span, node: part),
        ]);
      }
      Widget child = _CodeTextFragment(
        key: ValueKey(offset),
        source: text,
        offset: offset,
        owner: _selection,
        language: language,
        theme: widget.theme,
        highlighter: highlight ? widget.highlighter : null,
        cullToViewport: !widget.exporting,
        highlightRanges: [
          for (final range in ranges)
            if (range.start < offset + text.length && range.end > offset)
              SourceSpan(
                (range.start - offset).clamp(0, text.length),
                (range.end - offset).clamp(0, text.length),
              ),
        ],
        highlightColor: highlights.color,
        literalSpanBuilder: literal,
        sourceSegments: literal == null
            ? const []
            : _literalIndex!.segmentsForRange(offset, offset + text.length),
      );
      if (!widget.wrap && !widget.exporting)
        child = SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          primary: false,
          child: child,
        );
      return child;
    }

    final Widget content;
    if (!widget.exporting &&
        codeLineCount(_source) > PerformanceLimits.virtualCodeLines) {
      content = SizedBox(
        key: const ValueKey('markstream-virtualized-code'),
        height: widget.theme.code.virtualizedHeight,
        child: ListView.builder(
          primary: false,
          itemCount: _chunks.length,
          itemBuilder: (context, index) {
            // Skip the list's per-row selection keep-alive proxy. The source
            // owner retains only endpoints; keep the Scrollable's registrar
            // here so drag selection can still scroll the code viewport.
            final registrar = SelectionContainer.maybeOf(context);
            final child = fragment(_chunks[index].$2, _chunks[index].$1);
            return registrar == null
                ? child
                : SelectionRegistrarScope(registrar: registrar, child: child);
          },
        ),
      );
    } else {
      content = fragment(_source, 0);
    }
    final body = Directionality(
      textDirection: TextDirection.ltr,
      child: content,
    );
    _selection.selectionEnabled = SelectionContainer.maybeOf(context) != null;
    final selected = !_selection.selectionEnabled
        ? body
        : LayoutBuilder(
            builder: (context, constraints) {
              _selection.updateTextLayout(
                context,
                DefaultTextStyle.of(
                  context,
                ).style.merge(widget.theme.code.text),
                widget.wrap || widget.exporting
                    ? constraints.maxWidth
                    : double.infinity,
                textDirection: TextDirection.ltr,
              );
              return SelectionContainer(delegate: _selection, child: body);
            },
          );
    if (DocumentSelectionScope.maybeOf(context) == null) return selected;
    var remaining = _source.length;
    final segments = <TextSegment>[];
    for (final part in widget.node.children) {
      if (remaining <= 0) break;
      final length = math.min(remaining, part.text.length);
      segments.add(
        TextSegment(
          text: part.text.substring(0, length),
          node: part,
          sourceSpan: part.span.length == part.text.length
              ? SourceSpan(part.span.start, part.span.start + length)
              : part.span,
        ),
      );
      remaining -= length;
    }
    return MarkstreamSelectionFragment(
      node: widget.node,
      segments: segments,
      child: selected,
    );
  }
}

class _CodeTextFragment extends StatefulWidget {
  const _CodeTextFragment({
    super.key,
    required this.source,
    required this.offset,
    required this.owner,
    required this.language,
    required this.theme,
    this.highlighter,
    this.cullToViewport = true,
    this.highlightRanges = const [],
    this.highlightColor = const Color(0x00000000),
    this.literalSpanBuilder,
    this.sourceSegments = const [],
  });
  final bool cullToViewport;
  final List<SourceSpan> highlightRanges;
  final Color highlightColor;
  final String source, language;
  final int offset;
  final SourceTextSelectionDelegate owner;
  final MarkstreamTheme theme;
  final CodeHighlighter? highlighter;
  final LiteralSpanBuilder? literalSpanBuilder;
  final List<TextSegment> sourceSegments;
  @override
  State<_CodeTextFragment> createState() => _CodeTextFragmentState();
}

class _CodeTextFragmentState extends State<_CodeTextFragment> {
  late TextSpan _span;
  Object? _request;
  int _generation = 0;
  @override
  void initState() {
    super.initState();
    _updateHighlight();
  }

  @override
  void didUpdateWidget(_CodeTextFragment oldWidget) {
    super.didUpdateWidget(oldWidget);
    _updateHighlight();
  }

  TextSpan _checked(TextSpan span) =>
      span.toPlainText(includeSemanticsLabels: false) == widget.source
      ? span
      : TextSpan(text: widget.source, style: widget.theme.code.text);
  void _updateHighlight() {
    final key = (
      widget.source,
      widget.language,
      widget.theme.code.text,
      widget.theme.brightness,
      widget.highlighter,
    );
    if (key == _request) return;
    _request = key;
    final generation = ++_generation;
    _span = TextSpan(text: widget.source, style: widget.theme.code.text);
    final highlighter = widget.highlighter;
    if (highlighter == null) return;
    try {
      final result = highlighter.highlight(
        widget.source,
        language: widget.language,
        style: widget.theme.code.text,
        brightness: widget.theme.brightness,
      );
      if (result is TextSpan) {
        _span = _checked(result);
      } else {
        unawaited(
          result.then<void>(
            (span) {
              if (mounted && generation == _generation)
                setState(() => _span = _checked(span));
            },
            onError: (Object error, StackTrace stack) {
              // The current plain source is already visible if highlighting fails.
            },
          ),
        );
      }
    } catch (_) {
      // Syntax decoration must not remove or corrupt readable source text.
    }
  }

  @override
  void dispose() {
    _generation++;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final inherited = DefaultTextStyle.of(
      context,
    ).style.merge(widget.theme.code.text);
    final body = Padding(
      padding: const EdgeInsets.only(right: 3),
      child: StreamingText(
        streaming: false,
        cullToViewport: widget.cullToViewport,
        text: Text.rich(
          paintTextHighlights(
            widget.literalSpanBuilder?.call(
                  context,
                  _span,
                  widget.sourceSegments,
                ) ??
                _span,
            widget.highlightRanges,
            widget.highlightColor,
          ),
          style: widget.theme.code.text,
          strutStyle:
              widget.source.length <= PerformanceLimits.staticNativeCharacters
              ? StrutStyle.fromTextStyle(inherited)
              : null,
        ),
      ),
    );
    return SourceTextSelectionFragment(
      source: widget.source,
      offset: widget.offset,
      owner: widget.owner,
      child: body,
    );
  }
}
