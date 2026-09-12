import 'dart:collection';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'incremental_markdown_document.dart';
import 'markdown_block_list.dart';

/// Shapes long text in bounded windows, committing only complete visual lines.
/// Markdown still supplies the styled spans; embedded widgets and bidi text
/// keep Flutter's single-paragraph layout, where their context is significant.
class StreamingRichText extends StatefulWidget {
  const StreamingRichText({super.key, required this.text});

  final Text text;

  @override
  State<StreamingRichText> createState() => _StreamingRichTextState();
}

class _StreamingRichTextState extends State<StreamingRichText> {
  static final _contextualText = RegExp(
    '[\u0590-\u08ff\u200e\u200f\u202a-\u202e\u2066-\u2069]',
  );
  List<_TextRun> _runs = const [];
  final _spanCache = Expando<_FlattenedSpan>();
  final _chunks = <_TextChunk>[];
  Object? _layout;
  TextStyle? _baseStyle;
  int _runsVersion = 0;

  @override
  Widget build(BuildContext context) {
    final text = widget.text;
    final defaults = DefaultTextStyle.of(context);
    final computedStyle = text.style == null || text.style!.inherit
        ? defaults.style.merge(text.style)
        : text.style!;
    if (_baseStyle != computedStyle) _baseStyle = computedStyle;
    final style = _baseStyle!;
    final scale = text.textScaler ?? MediaQuery.textScalerOf(context);
    final direction = text.textDirection ?? Directionality.of(context);
    final align = text.textAlign ?? defaults.textAlign ?? TextAlign.start;
    final locale = text.locale ?? Localizations.maybeLocaleOf(context);
    final heightBehavior =
        text.textHeightBehavior ??
        defaults.textHeightBehavior ??
        DefaultTextHeightBehavior.maybeOf(context);
    final runs = _TextRunList();
    final previousRuns = _runs;
    final rootSpan = text.textSpan ?? TextSpan(text: text.data);
    final visitedSpans = <_FlattenedSpan>[];
    var unchangedPrefix = 0;
    var length = 0;
    bool flatten(InlineSpan span, TextStyle inherited) {
      if (span is! TextSpan ||
          span.recognizer != null ||
          span.semanticsLabel != null ||
          span.semanticsIdentifier != null ||
          span.spellOut != null ||
          span.locale != null ||
          span.onEnter != null ||
          span.onExit != null) {
        return false;
      }
      final cached = _spanCache[span];
      if (cached != null &&
          cached.start == length &&
          cached.style == inherited) {
        if (cached.lastRunsVersion == _runsVersion &&
            length == unchangedPrefix) {
          unchangedPrefix += cached.length;
        }
        visitedSpans.add(cached);
        runs.addAll(cached.runs);
        length += cached.length;
        return true;
      }
      final start = length;
      final firstRun = runs.length;
      final merged = inherited.merge(span.style);
      final effective = merged == inherited ? inherited : merged;
      final content = span.text;
      if (content != null && content.isNotEmpty) {
        var prefixLength = 0;
        final previousIndex = _runAt(length);
        if (previousIndex < previousRuns.length) {
          final previous = previousRuns[previousIndex];
          if (previous.start == length && content.startsWith(previous.text)) {
            prefixLength = previous.text.length;
          }
        }
        if (_contextualText.hasMatch(content.substring(prefixLength))) {
          return false;
        }
        runs.add(
          _TextRun(length, content, effective, prefixLength, _runsVersion),
        );
        length += content.length;
      }
      for (final child in span.children ?? const <InlineSpan>[]) {
        if (!flatten(child, effective)) return false;
      }
      final flattened = _FlattenedSpan(
        start,
        length - start,
        inherited,
        identical(span, rootSpan) ? runs : runs.sublist(firstRun),
      );
      _spanCache[span] = flattened;
      visitedSpans.add(flattened);
      return true;
    }

    final supported =
        !MediaQuery.boldTextOf(context) &&
        MediaQuery.maybeLineHeightScaleFactorOverrideOf(context) == null &&
        MediaQuery.maybeLetterSpacingOverrideOf(context) == null &&
        MediaQuery.maybeWordSpacingOverrideOf(context) == null &&
        direction == TextDirection.ltr &&
        (align == TextAlign.start || align == TextAlign.left) &&
        text.maxLines == null &&
        defaults.maxLines == null &&
        text.softWrap != false &&
        defaults.softWrap &&
        text.strutStyle == null &&
        text.semanticsLabel == null &&
        text.semanticsIdentifier == null &&
        heightBehavior == null &&
        flatten(rootSpan, style);
    return LayoutBuilder(
      builder: (context, constraints) {
        final layout = (
          constraints.maxWidth,
          style,
          scale,
          direction,
          align,
          locale,
          supported,
          text.textWidthBasis,
          text.overflow,
          text.selectionColor,
        );
        var common = 0;
        if (_layout == layout && supported) {
          common = unchangedPrefix;
          for (
            var i = _runAt(common);
            i < math.min(runs.length, _runs.length);
            i++
          ) {
            final before = _runs[i];
            final after = runs[i];
            if (identical(before, after)) {
              common = after.end;
              continue;
            }
            if (before.style != after.style || before.start != after.start) {
              break;
            }
            if (before.text == after.text) {
              common = after.end;
            } else {
              var j =
                  identical(_runs, previousRuns) &&
                      after.prefixVersion == _runsVersion
                  ? after.unchangedPrefix
                  : 0;
              while (j < math.min(before.text.length, after.text.length) &&
                  before.text.codeUnitAt(j) == after.text.codeUnitAt(j)) {
                j++;
              }
              common = after.start + j;
              break;
            }
          }
        }
        _layout = layout;
        if (!identical(_runs, runs)) {
          _runsVersion++;
          // Mark only spans that reached the committed layout. A discarded
          // build or a restored cached span must not claim an unchanged prefix.
          for (final span in visitedSpans) {
            span.lastRunsVersion = _runsVersion;
          }
        }
        _runs = runs;
        while (_chunks.isNotEmpty &&
            (!_chunks.last.block.stable || _chunks.last.end >= common)) {
          _chunks.removeLast();
        }
        if (!supported ||
            // A short paragraph is already bounded. Let RenderParagraph shape
            // it once instead of doing an extra TextPainter layout per block.
            length <= 512 ||
            constraints.maxWidth <= 0) {
          _chunks.clear();
          _chunks.add(
            _TextChunk(
              IncrementalMarkdownBlock(start: 0, text: '', stable: false),
              0,
              constraints.minWidth > 0 ||
                      constraints.minHeight > 0 ||
                      constraints.hasBoundedHeight
                  ? ConstrainedBox(constraints: constraints, child: text)
                  : text,
            ),
          );
        } else {
          var start = _chunks.isEmpty ? 0 : _chunks.last.end;
          final painter = TextPainter(
            textDirection: direction,
            textScaler: scale,
            locale: locale,
          );
          try {
            while (start < length) {
              var end = math.min(start + 2048, length);
              if (end < length) {
                final unit = _codeUnitAt(end - 1);
                if (unit >= 0xd800 && unit <= 0xdbff) end--;
              }
              final span = _slice(start, end, style);
              painter.text = span;
              painter.layout(maxWidth: constraints.maxWidth);
              final metrics = painter.computeLineMetrics();
              final freezeLines = math.min(16, metrics.length - 2);
              int? lines;
              if (freezeLines > 0) {
                final next = metrics[freezeLines];
                final position = painter.getPositionForOffset(
                  Offset(next.left, next.baseline),
                );
                final boundary = painter.getLineBoundary(position).start;
                if (boundary > 0) {
                  end = start + boundary;
                  lines = freezeLines;
                }
              }
              // Very wide views can hold the whole window on one line. Keep that
              // paragraph intact rather than inventing a visible line break.
              if (lines == null) end = length;
              final content = _slice(start, end, style);
              final block = IncrementalMarkdownBlock(
                start: start,
                text: '',
                stable: lines != null,
              );
              _chunks.add(
                _TextChunk(
                  block,
                  end,
                  Text.rich(
                    content,
                    textDirection: direction,
                    textAlign: align,
                    textScaler: scale,
                    locale: locale,
                    maxLines: lines,
                    overflow: text.overflow,
                    selectionColor: text.selectionColor,
                    textWidthBasis: text.textWidthBasis,
                  ),
                ),
              );
              start = end;
            }
          } finally {
            painter.dispose();
          }
        }
        return MarkdownBlockList(
          blocks: [for (final chunk in _chunks) chunk.block],
          signature: layout,
          itemBuilder: (_, i) => KeyedSubtree(
            key: ValueKey(_chunks[i].block.start),
            child: _chunks[i].widget,
          ),
        );
      },
    );
  }

  int _runAt(int offset) {
    var low = 0;
    var high = _runs.length;
    while (low < high) {
      final mid = (low + high) ~/ 2;
      if (_runs[mid].end <= offset) {
        low = mid + 1;
      } else {
        high = mid;
      }
    }
    return low;
  }

  int _codeUnitAt(int offset) {
    final run = _runs[_runAt(offset)];
    return run.text.codeUnitAt(offset - run.start);
  }

  TextSpan _slice(int start, int end, TextStyle style) {
    final spans = <InlineSpan>[];
    for (var i = _runAt(start); i < _runs.length && _runs[i].start < end; i++) {
      final run = _runs[i];
      spans.add(
        TextSpan(
          text: run.text.substring(
            math.max(0, start - run.start),
            math.min(run.text.length, end - run.start),
          ),
          style: run.style,
        ),
      );
    }
    return TextSpan(style: style, children: spans);
  }
}

class _TextRun {
  const _TextRun(
    this.start,
    this.text,
    this.style,
    this.unchangedPrefix,
    this.prefixVersion,
  );
  final int start;
  final String text;
  final TextStyle style;
  final int unchangedPrefix;
  final int prefixVersion;
  int get end => start + text.length;
}

/// Completed span groups contribute immutable run lists. Keep their lists by
/// reference instead of copying every historical token into a flat array on
/// each frame; binary lookup still supports slicing the visible line window.
class _TextRunList extends ListBase<_TextRun> {
  final _segments = <(int, List<_TextRun>)>[];
  List<_TextRun>? _appendBuffer;
  int _length = 0;

  @override
  int get length => _length;

  @override
  set length(int value) => throw UnsupportedError('Append-only text runs');

  @override
  _TextRun operator [](int index) {
    RangeError.checkValidIndex(index, this);
    var low = 0;
    var high = _segments.length;
    while (low + 1 < high) {
      final middle = (low + high) ~/ 2;
      if (_segments[middle].$1 <= index) {
        low = middle;
      } else {
        high = middle;
      }
    }
    final segment = _segments[low];
    return segment.$2[index - segment.$1];
  }

  @override
  void operator []=(int index, _TextRun value) =>
      throw UnsupportedError('Append-only text runs');

  @override
  void add(_TextRun value) {
    if (_appendBuffer == null) {
      _appendBuffer = [];
      _segments.add((_length, _appendBuffer!));
    }
    _appendBuffer!.add(value);
    _length++;
  }

  @override
  void addAll(Iterable<_TextRun> iterable) {
    final values = iterable is List<_TextRun> ? iterable : iterable.toList();
    if (values.isEmpty) return;
    _appendBuffer = null;
    _segments.add((_length, values));
    _length += values.length;
  }
}

class _FlattenedSpan {
  _FlattenedSpan(this.start, this.length, this.style, this.runs);
  final int start;
  final int length;
  final TextStyle style;
  final List<_TextRun> runs;
  int lastRunsVersion = -1;
}

class _TextChunk {
  const _TextChunk(this.block, this.end, this.widget);
  final IncrementalMarkdownBlock block;
  final int end;
  final Widget widget;
}
