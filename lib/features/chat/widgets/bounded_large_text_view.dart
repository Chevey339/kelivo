import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';

/// Collapses large text by default and virtualizes the expanded representation
/// into independently selectable chunks.
class BoundedLargeTextView extends StatefulWidget {
  const BoundedLargeTextView(
    this.text, {
    super.key,
    this.style,
    this.maxExpandedHeight = 320,
  });

  final String text;
  final TextStyle? style;
  final double maxExpandedHeight;

  @override
  State<BoundedLargeTextView> createState() => _BoundedLargeTextViewState();
}

class _BoundedLargeTextViewState extends State<BoundedLargeTextView> {
  static const int previewLines = 40;
  static const int previewChars = 12000;
  static const int chunkLines = 40;
  static const int chunkChars = 16000;

  bool _expanded = false;
  late _LargeTextProjection _projection;

  @override
  void initState() {
    super.initState();
    _projection = _LargeTextProjection.fromText(widget.text);
  }

  @override
  void didUpdateWidget(covariant BoundedLargeTextView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      _projection = _LargeTextProjection.fromText(widget.text);
      _expanded = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_projection.isLarge) {
      return SelectableText(widget.text, style: widget.style);
    }
    final l10n = AppLocalizations.of(context)!;
    return Column(
      key: const ValueKey('bounded-large-text-view'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_expanded)
          SizedBox(
            height: widget.maxExpandedHeight,
            child: SelectionArea(
              child: ListView.builder(
                key: const ValueKey('virtualized-large-text-list'),
                primary: false,
                itemCount: _projection.chunks.length,
                itemBuilder: (context, index) =>
                    Text(_projection.chunks[index], style: widget.style),
              ),
            ),
          )
        else
          SelectableText(
            _projection.preview,
            key: const ValueKey('bounded-large-text-preview'),
            style: widget.style,
          ),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: Semantics(
            key: const ValueKey('bounded-large-text-semantics'),
            button: true,
            expanded: _expanded,
            child: TextButton.icon(
              key: const ValueKey('bounded-large-text-toggle'),
              onPressed: () => setState(() => _expanded = !_expanded),
              icon: Icon(
                _expanded ? Icons.expand_less : Icons.expand_more,
                size: 18,
              ),
              label: Text(
                _expanded
                    ? l10n.largeContentCollapse
                    : l10n.largeContentShowMore(_projection.hiddenLines),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

final class _LargeTextProjection {
  const _LargeTextProjection({
    required this.preview,
    required this.chunks,
    required this.hiddenLines,
    required this.isLarge,
  });

  final String preview;
  final List<String> chunks;
  final int hiddenLines;
  final bool isLarge;

  factory _LargeTextProjection.fromText(String text) {
    final lines = text.split(RegExp(r'\r\n|\r|\n'));
    final isLarge =
        lines.length > _BoundedLargeTextViewState.previewLines ||
        text.length > _BoundedLargeTextViewState.previewChars;
    if (!isLarge) {
      return _LargeTextProjection(
        preview: text,
        chunks: [text],
        hiddenLines: 0,
        isLarge: false,
      );
    }
    final preview = _takeBounded(
      lines,
      maxLines: _BoundedLargeTextViewState.previewLines,
      maxChars: _BoundedLargeTextViewState.previewChars,
    );
    final chunks = <String>[];
    var current = <String>[];
    var chars = 0;
    for (final line in lines) {
      final nextChars = chars + line.length + (current.isEmpty ? 0 : 1);
      if (current.isNotEmpty &&
          (current.length >= _BoundedLargeTextViewState.chunkLines ||
              nextChars > _BoundedLargeTextViewState.chunkChars)) {
        chunks.add(current.join('\n'));
        current = <String>[];
        chars = 0;
      }
      if (line.length > _BoundedLargeTextViewState.chunkChars) {
        if (current.isNotEmpty) {
          chunks.add(current.join('\n'));
          current = <String>[];
          chars = 0;
        }
        for (
          var start = 0;
          start < line.length;
          start += _BoundedLargeTextViewState.chunkChars
        ) {
          chunks.add(
            line.substring(
              start,
              (start + _BoundedLargeTextViewState.chunkChars).clamp(
                0,
                line.length,
              ),
            ),
          );
        }
        continue;
      }
      current.add(line);
      chars += line.length + (current.length == 1 ? 0 : 1);
    }
    if (current.isNotEmpty) chunks.add(current.join('\n'));
    return _LargeTextProjection(
      preview: '$preview\n…',
      chunks: List.unmodifiable(chunks),
      hiddenLines: (lines.length - _BoundedLargeTextViewState.previewLines)
          .clamp(1, lines.length),
      isLarge: true,
    );
  }

  static String _takeBounded(
    List<String> lines, {
    required int maxLines,
    required int maxChars,
  }) {
    final buffer = StringBuffer();
    for (final line in lines.take(maxLines)) {
      final remaining = maxChars - buffer.length;
      if (remaining <= 0) break;
      if (buffer.isNotEmpty) buffer.writeln();
      buffer.write(
        line.length <= remaining ? line : line.substring(0, remaining),
      );
    }
    return buffer.toString();
  }
}
