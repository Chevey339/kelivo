import 'package:flutter/material.dart';

import 'package:Kelivo/theme/app_semantic_colors.dart';

/// Labeled text block for the tool detail view, rendered as a sliver.
///
/// Small payloads render as a single [Text]. Large payloads are split into
/// line-bounded chunks built on demand, so opening the detail view never lays
/// out an entire multi-megabyte tool result at once.
class ToolDetailTextSection extends StatelessWidget {
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

  static List<String> chunksOf(String text) {
    final lines = text.split('\n');
    final chunks = <String>[];
    for (var start = 0; start < lines.length; start += chunkLines) {
      final end = (start + chunkLines).clamp(0, lines.length);
      chunks.add(lines.sublist(start, end).join('\n'));
    }
    return chunks.isEmpty ? <String>[text] : chunks;
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
    final labelText = Text(label, style: labelStyle);
    final header = SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: trailing == null
            ? labelText
            : Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(child: labelText),
                  trailing!,
                ],
              ),
      ),
    );
    final below = belowLabel == null
        ? null
        : SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: belowLabel,
            ),
          );

    if (!shouldChunk(text)) {
      return SliverMainAxisGroup(
        slivers: [
          header,
          if (below != null) below,
          SliverToBoxAdapter(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: decoration,
              child: Text(text, style: textStyle),
            ),
          ),
        ],
      );
    }

    final chunks = chunksOf(text);
    return SliverMainAxisGroup(
      slivers: [
        header,
        if (below != null) below,
        DecoratedSliver(
          decoration: decoration,
          sliver: SliverPadding(
            padding: const EdgeInsets.all(10),
            sliver: SliverList.builder(
              key: lazyListKey,
              itemCount: chunks.length,
              itemBuilder: (context, index) => Text(
                chunks[index],
                key: ValueKey('tool-detail-text-chunk-$index'),
                style: textStyle,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
