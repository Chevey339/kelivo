import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:super_sliver_list/super_sliver_list.dart';

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

  /// Wait for syntax already requested by a mounted subtree before measuring
  /// or capturing it. Each block keeps its plain source visible while pending.
  static Future<void> waitForHighlighting(BuildContext subtree) async {
    final pending = <Future<void>>[];
    void visit(BuildContext context) {
      if (context is StatefulElement &&
          context.state is _MarkstreamCodeContentState) {
        final work =
            (context.state as _MarkstreamCodeContentState)._highlightWork;
        if (work != null) pending.add(work);
      }
      context.visitChildElements(visit);
    }

    visit(subtree);
    await Future.wait(pending);
  }

  @override
  State<MarkstreamCodeContent> createState() => _MarkstreamCodeContentState();
}

class _MarkstreamCodeContentState extends State<MarkstreamCodeContent> {
  final _selection = SourceTextSelectionDelegate();
  final _scroll = ScrollController();
  final _list = ListController();
  final _chunks = <(int, String)>[];
  String _source = '';
  int _lastChunkStart = 0;
  TextIndex? _literalIndex;
  late TextSpan _span;
  List<TextSpan>? _chunkSpans;
  Object? _highlightRequest;
  int _generation = 0;
  Future<void>? _highlightWork;

  @override
  void initState() {
    super.initState();
    _update();
    _updateHighlight();
  }

  @override
  void didUpdateWidget(MarkstreamCodeContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.node != widget.node) _literalIndex = null;
    _update();
    _updateHighlight();
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
    _generation++;
    _scroll.dispose();
    _list.dispose();
    _selection.dispose();
    super.dispose();
  }

  void _setSpan(TextSpan span) {
    _span = span.toPlainText(includeSemanticsLabels: false) == _source
        ? span
        : TextSpan(text: _source, style: widget.theme.code.text);
    _chunkSpans = null;
  }

  void _updateHighlight() {
    final language = widget.node.info
        .trim()
        .split(RegExp(r'\s+'))
        .first
        .toLowerCase();
    final enabled =
        widget.highlight &&
        !(widget.streaming &&
            !widget.exporting &&
            (_source.length > PerformanceLimits.highlightCharacters ||
                codeLineCount(_source) > PerformanceLimits.highlightLines));
    final highlighter = enabled ? widget.highlighter : null;
    final key = (
      _source,
      language,
      widget.theme.code.text,
      widget.theme.brightness,
      highlighter,
    );
    if (key == _highlightRequest) return;
    _highlightRequest = key;
    final generation = ++_generation;
    _highlightWork = null;
    _setSpan(TextSpan(text: _source, style: widget.theme.code.text));
    if (highlighter == null) return;
    try {
      final result = highlighter.highlight(
        _source,
        language: language,
        style: widget.theme.code.text,
        brightness: widget.theme.brightness,
      );
      if (result is TextSpan) {
        _setSpan(result);
      } else {
        _highlightWork = result.then<void>(
          (span) {
            if (mounted && generation == _generation) {
              setState(() => _setSpan(span));
            }
          },
          onError: (Object error, StackTrace stack) {
            // The current plain source stays visible if highlighting fails.
          },
        );
        unawaited(_highlightWork);
      }
    } catch (_) {
      // Syntax decoration must not remove or corrupt readable source text.
    }
  }

  bool _prepareRange(TextRange range) {
    if (_selection.rectForRange(range) != null) {
      return _selection.prepareRange(range, boundary: context);
    }
    if (_list.isAttached && _scroll.hasClients) {
      final index = _chunks.lastIndexWhere((chunk) => chunk.$1 <= range.start);
      if (index >= 0) {
        _list.jumpToItem(index: index, scrollController: _scroll, alignment: 0);
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final highlights = SourceHighlightScope.of(context);
    final ranges = highlights.isEmpty
        ? const <SourceSpan>[]
        : highlights.textRanges([
            for (final part in widget.node.children)
              TextSegment(text: part.text, sourceSpan: part.span, node: part),
          ]);
    Widget fragment(String text, int offset, TextSpan span) {
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
        span: span,
        theme: widget.theme,
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
      // Only layout is chunked. Syntax is parsed once with the complete source
      // so strings, comments and embedded languages can span chunk boundaries.
      final spans = _chunkSpans ??= _splitCodeSpan(_span, _chunks);
      final painter = TextPainter(
        text: TextSpan(
          text: 'M',
          style: DefaultTextStyle.of(
            context,
          ).style.merge(widget.theme.code.text),
        ),
        textDirection: TextDirection.ltr,
        textScaler: MediaQuery.textScalerOf(context),
      )..layout();
      final lineHeight = painter.height;
      painter.dispose();
      content = SizedBox(
        key: const ValueKey('markstream-virtualized-code'),
        height: widget.theme.code.virtualizedHeight,
        child: SuperListView.builder(
          primary: false,
          controller: _scroll,
          listController: _list,
          delayPopulatingCacheArea: false,
          extentEstimation: (index, _) =>
              lineHeight *
              (index == null
                  ? PerformanceLimits.codeChunkLines
                  : codeLineCount(_chunks[index].$2)),
          itemCount: _chunks.length,
          itemBuilder: (context, index) {
            // Skip the list's per-row selection keep-alive proxy. The source
            // owner retains only endpoints; keep the Scrollable's registrar
            // here so drag selection can still scroll the code viewport.
            final registrar = SelectionContainer.maybeOf(context);
            final child = fragment(
              _chunks[index].$2,
              _chunks[index].$1,
              spans[index],
            );
            return registrar == null
                ? child
                : SelectionRegistrarScope(registrar: registrar, child: child);
          },
        ),
      );
    } else {
      content = fragment(_source, 0, _span);
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
      rangeRect: _selection.rectForRange,
      prepareRange: _prepareRange,
      child: selected,
    );
  }
}

/// Split styled text in one pass, inheriting syntax styles across line chunks.
/// The separating newline is owned by the layout, not either text fragment.
List<TextSpan> _splitCodeSpan(TextSpan root, List<(int, String)> chunks) {
  final spans = List.generate(chunks.length, (_) => <InlineSpan>[]);
  var offset = 0;
  var index = 0;
  void visit(TextSpan span, TextStyle? inherited) {
    final style = inherited?.merge(span.style) ?? span.style;
    final text = span.text;
    if (text != null) {
      final end = offset + text.length;
      while (index < chunks.length && chunks[index].$1 < end) {
        final (start, source) = chunks[index];
        final chunkEnd = start + source.length;
        final from = math.max(offset, start);
        final to = math.min(end, chunkEnd);
        if (from < to) {
          spans[index].add(
            TextSpan(
              text: text.substring(from - offset, to - offset),
              style: style,
            ),
          );
        }
        if (end < chunkEnd) break;
        index++;
      }
      offset = end;
    }
    for (final child in span.children ?? const <InlineSpan>[]) {
      if (child is TextSpan) visit(child, style);
    }
  }

  visit(root, null);
  return [
    for (final children in spans)
      TextSpan(style: root.style, children: children),
  ];
}

class _CodeTextFragment extends StatelessWidget {
  const _CodeTextFragment({
    super.key,
    required this.source,
    required this.offset,
    required this.owner,
    required this.span,
    required this.theme,
    this.cullToViewport = true,
    this.highlightRanges = const [],
    this.highlightColor = const Color(0x00000000),
    this.literalSpanBuilder,
    this.sourceSegments = const [],
  });
  final bool cullToViewport;
  final List<SourceSpan> highlightRanges;
  final Color highlightColor;
  final String source;
  final TextSpan span;
  final int offset;
  final SourceTextSelectionDelegate owner;
  final MarkstreamTheme theme;
  final LiteralSpanBuilder? literalSpanBuilder;
  final List<TextSegment> sourceSegments;
  @override
  Widget build(BuildContext context) {
    final inherited = DefaultTextStyle.of(context).style.merge(theme.code.text);
    final body = Padding(
      padding: const EdgeInsets.only(right: 3),
      child: StreamingText(
        streaming: false,
        cullToViewport: cullToViewport,
        text: Text.rich(
          paintTextHighlights(
            literalSpanBuilder?.call(context, span, sourceSegments) ?? span,
            highlightRanges,
            highlightColor,
          ),
          style: theme.code.text,
          strutStyle: source.length <= PerformanceLimits.staticNativeCharacters
              ? StrutStyle.fromTextStyle(inherited)
              : null,
        ),
      ),
    );
    return SourceTextSelectionFragment(
      source: source,
      offset: offset,
      owner: owner,
      child: body,
    );
  }
}
