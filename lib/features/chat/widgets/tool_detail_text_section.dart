import 'package:flutter/material.dart';

import '../../../utils/utf16_safe_cut.dart';
import '../../../utils/unicode_sanitizer.dart';

import 'package:Kelivo/theme/app_semantic_colors.dart';

/// Labeled text block for the tool detail view, rendered as a sliver.
///
/// Small payloads render as a single [Text]. Large payloads are split into
/// line-bounded chunks built on demand, so opening the detail view never lays
/// out an entire multi-megabyte tool result at once.
class ToolDetailTextSection extends StatefulWidget {
  const ToolDetailTextSection({
    super.key,
    required this.label,
    required this.text,
    this.textStyle = const TextStyle(fontSize: 12),
    this.trailing,
    this.belowLabel,
  });

  /// Above this many lines (or characters) the text is chunked and built lazily.
  static const int lazyLineThreshold = 120;
  static const int lazyCharThreshold = 8000;
  static const int chunkLines = 40;
  static const int chunkCharacters = 4000;

  static const ValueKey<String> lazyListKey = ValueKey(
    'tool-detail-text-lazy-list',
  );

  final String label;
  final String text;
  final TextStyle textStyle;

  /// Optional control aligned to the right of [label] (e.g. a copy button).
  final Widget? trailing;

  /// Optional content rendered between the label row and the text box.
  final Widget? belowLabel;

  static bool shouldChunk(String text) {
    if (text.length > lazyCharThreshold) return true;
    var lines = 1;
    for (var i = 0; i < text.length; i++) {
      if (text.codeUnitAt(i) == 0x0A) {
        lines++;
        if (lines > lazyLineThreshold) return true;
      }
    }
    return false;
  }

  /// Contiguous UTF-16 ranges preserve the source, including line endings.
  /// Only the visible ranges become strings during layout.
  static List<TextRange> chunkRangesOf(String text) {
    final ranges = <TextRange>[];
    var start = 0;
    while (start < text.length) {
      var end = utf16SafeHeadEnd(
        text,
        (start + chunkCharacters).clamp(0, text.length),
      );
      // Keep CRLF together, just like a surrogate pair.
      if (end < text.length &&
          text.codeUnitAt(end - 1) == 0x0D &&
          text.codeUnitAt(end) == 0x0A) {
        end--;
      }
      var lines = 0;
      for (var i = start; i < end; i++) {
        if (text.codeUnitAt(i) == 0x0A && ++lines == chunkLines) {
          end = i + 1;
          break;
        }
      }
      ranges.add(TextRange(start: start, end: end));
      start = end;
    }
    return ranges;
  }

  @override
  State<ToolDetailTextSection> createState() => _ToolDetailTextSectionState();
}

class _ToolDetailTextSectionState extends State<ToolDetailTextSection> {
  List<TextRange>? _ranges;
  late String _text;

  @override
  void initState() {
    super.initState();
    _indexText();
  }

  @override
  void didUpdateWidget(ToolDetailTextSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) _indexText();
  }

  void _indexText() {
    _text = UnicodeSanitizer.sanitize(widget.text);
    _ranges = ToolDetailTextSection.shouldChunk(_text)
        ? ToolDetailTextSection.chunkRangesOf(_text)
        : null;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final decoration = BoxDecoration(
      color: context.appColors.surfaceFill,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.2)),
    );

    final labelStyle = TextStyle(
      fontSize: 12,
      color: cs.onSurface.withValues(alpha: 0.6),
    );
    final labelText = Text(widget.label, style: labelStyle);
    final header = SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: widget.trailing == null
            ? labelText
            : Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(child: labelText),
                  widget.trailing!,
                ],
              ),
      ),
    );
    final below = widget.belowLabel == null
        ? null
        : SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: widget.belowLabel,
            ),
          );

    if (_ranges == null) {
      return SliverMainAxisGroup(
        slivers: [
          header,
          if (below != null) below,
          SliverToBoxAdapter(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: decoration,
              child: Text(_text, style: widget.textStyle),
            ),
          ),
        ],
      );
    }

    final ranges = _ranges!;
    return SliverMainAxisGroup(
      slivers: [
        header,
        if (below != null) below,
        DecoratedSliver(
          decoration: decoration,
          sliver: SliverPadding(
            padding: const EdgeInsets.all(10),
            sliver: SliverList.builder(
              key: ToolDetailTextSection.lazyListKey,
              itemCount: ranges.length,
              itemBuilder: (context, index) => Text(
                ranges[index].textInside(_text),
                key: ValueKey('tool-detail-text-chunk-$index'),
                style: widget.textStyle,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
