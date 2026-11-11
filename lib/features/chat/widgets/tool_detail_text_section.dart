import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:markstream/markstream.dart';

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
      final cut = CharacterRange.at(
        text,
        (start + chunkCharacters).clamp(0, text.length),
      );
      var end = cut.stringBeforeLength;
      // A single grapheme can exceed the usual budget (e.g. many combining
      // marks). Keep it whole and always make progress.
      if (end == start) end = text.length - cut.stringAfterLength;
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
  final _selection = _ToolTextSelectionDelegate();

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
    _selection.source = _text;
    _ranges = ToolDetailTextSection.shouldChunk(_text)
        ? ToolDetailTextSection.chunkRangesOf(_text)
        : null;
  }

  @override
  void dispose() {
    _selection.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selectable = SelectionContainer.maybeOf(context) != null;
    _selection.selectionEnabled = _ranges != null && selectable;
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
    Widget body = DecoratedSliver(
      decoration: decoration,
      sliver: SliverPadding(
        padding: const EdgeInsets.all(10),
        sliver: SliverList.builder(
          key: ToolDetailTextSection.lazyListKey,
          itemCount: ranges.length,
          itemBuilder: (context, index) {
            final range = ranges[index];
            var end = range.end;
            // The next Text starts a new visual line already. The source-based
            // selection owner restores this separator when copying across it.
            if (index + 1 < ranges.length &&
                _text.codeUnitAt(end - 1) == 0x0A) {
              end--;
              if (end > range.start && _text.codeUnitAt(end - 1) == 0x0D) end--;
            }
            final text = _text.substring(range.start, end);
            final child = Text(
              text,
              key: ValueKey('tool-detail-text-chunk-$index'),
              style: widget.textStyle,
            );
            return selectable
                ? SelectionRegistrarScope(
                    // SliverList normally keeps every selected row alive via
                    // its registrar proxy. Register directly with the logical
                    // owner so its fragment policy can release Select All rows.
                    registrar: _selection,
                    child: SourceTextSelectionFragment(
                      key: ValueKey(range.start),
                      source: text,
                      offset: range.start,
                      owner: _selection,
                      child: child,
                    ),
                  )
                : child;
          },
        ),
      ),
    );
    if (selectable) {
      final content = body;
      body = _SelectableToolTextSliver(
        selection: _selection,
        registrar: SelectionContainer.maybeOf(context)!,
        child: SliverLayoutBuilder(
          builder: (context, constraints) {
            _selection.updateTextLayout(
              context,
              DefaultTextStyle.of(context).style.merge(widget.textStyle),
              constraints.crossAxisExtent,
            );
            return SelectionRegistrarScope(
              registrar: _selection,
              child: content,
            );
          },
        ),
      );
    }
    return SliverMainAxisGroup(
      slivers: [header, if (below != null) below, body],
    );
  }
}

// SelectionContainer assumes a RenderBox. A sliver registers the same shared
// source delegate directly, using logical (unscrolled) section coordinates.
class _ToolTextSelectionDelegate extends SourceTextSelectionDelegate {
  _RenderSelectableToolTextSliver? sliver;

  @override
  bool get hasSize => selectionEnabled && sliver?.geometry != null;

  @override
  Size get containerSize =>
      Size(sliver!.constraints.crossAxisExtent, sliver!.geometry!.scrollExtent);

  @override
  Matrix4 getTransformTo(RenderObject? ancestor) =>
      sliver!.getTransformTo(ancestor)..multiply(
        Matrix4.translationValues(0, -sliver!.constraints.scrollOffset, 0),
      );
}

class _SelectableToolTextSliver extends SingleChildRenderObjectWidget {
  const _SelectableToolTextSliver({
    required this.selection,
    required this.registrar,
    required super.child,
  });
  final _ToolTextSelectionDelegate selection;
  final SelectionRegistrar registrar;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderSelectableToolTextSliver(selection, registrar);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderSelectableToolTextSliver renderObject,
  ) {
    renderObject.selection.registrar = registrar;
  }
}

class _RenderSelectableToolTextSliver extends RenderProxySliver {
  _RenderSelectableToolTextSliver(
    this.selection,
    SelectionRegistrar registrar,
  ) {
    selection.sliver = this;
    selection.selectionEnabled = true;
    selection.registrar = registrar;
  }
  final _ToolTextSelectionDelegate selection;
  bool _scheduled = false;

  @override
  void performLayout() {
    assert(
      constraints.axisDirection == AxisDirection.down &&
          constraints.growthDirection == GrowthDirection.forward,
    );
    super.performLayout();
    if (_scheduled) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (attached) selection.layoutDidChange();
    });
  }

  @override
  void dispose() {
    if (identical(selection.sliver, this)) {
      selection.registrar = null;
      selection.selectionEnabled = false;
      selection.sliver = null;
    }
    super.dispose();
  }
}
