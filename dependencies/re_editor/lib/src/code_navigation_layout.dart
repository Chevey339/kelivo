part of 're_editor.dart';

/// The layout settings needed to resolve native navigation after the widget
/// detaches. It owns at most the current and adjacent paragraph layouts, never
/// a RenderObject or BuildContext. Native accepted work can therefore drain.
class CodeNavigationLayout {
  CodeNavigationLayout(this.style, this.maxWidth, this.textStyle);
  final TextStyle style;
  final TextStyle textStyle;
  final double maxWidth;
  _CodeParagraphProvider? _provider;
  String? _text;
  TextSelection? _lastTarget;
  double? _horizontal;

  bool sameConfiguration(CodeNavigationLayout other) =>
      style == other.style &&
      textStyle == other.textStyle &&
      maxWidth == other.maxWidth;

  void invalidate() {
    _provider?.dispose();
    _text = null;
    _lastTarget = null;
    _horizontal = null;
  }

  void dispose() => invalidate();

  TextSelection resolve(TextEditingValue value, bool up, bool extend, {bool lineEdge = false}) {
    if (!identical(value.text, _text)) {
      invalidate();
      _text = value.text;
    }
    final selected = value.selection;
    if (selected.baseOffset != _lastTarget?.baseOffset ||
        selected.extentOffset != _lastTarget?.extentOffset) {
      _horizontal = null;
      _lastTarget = null;
    }
    if (!lineEdge && !extend && !selected.isCollapsed) {
      _horizontal = null;
      _lastTarget = null;
      return TextSelection.collapsed(
          offset: up ? selected.start : selected.end);
    }
    final provider =
        _provider ??= _CodeParagraphProvider()..updateBaseStyle(style);
    final text = value.text;
    final caret = selected.extentOffset.clamp(0, text.length);
    final start = caret == 0 ? 0 : text.lastIndexOf('\n', caret - 1) + 1;
    final newline = text.indexOf('\n', caret);
    final end = newline < 0 ? text.length : newline;
    final retained = <IParagraph>[];
    IParagraph paragraph(int left, int right) {
      final p = provider.build(
          TextSpan(text: text.substring(left, right), style: textStyle),
          maxWidth);
      retained.add(p);
      return p;
    }

    final current = paragraph(start, end);
    if (lineEdge) {
      // Paragraph.getLineBoundary ignores affinity. Resolve from the visible
      // caret row so End followed by Home stays on the same soft-wrapped row.
      final offset = current.getOffset(TextPosition(
          offset: caret - start, affinity: selected.affinity)) ?? Offset.zero;
      final first = current.getPosition(Offset(0, offset.dy));
      // longestLine excludes trailing spaces. Resolve the row's actual text
      // boundary from its first position, after affinity selected the row.
      final position = up ? first : TextPosition(
        offset: current.getLineBoundary(first).end,
        affinity: TextAffinity.upstream,
      );
      final target = start + position.offset;
      provider.retainParagraphs(retained);
      _horizontal = null;
      _lastTarget = null;
      return TextSelection(
          baseOffset: extend ? selected.baseOffset : target,
          extentOffset: target,
          affinity: position.affinity);
    }
    final offset = current.getOffset(TextPosition(
            offset: caret - start,
            affinity: _lastTarget?.affinity ?? selected.affinity)) ??
        Offset.zero;
    _horizontal ??= offset.dx;
    int targetStart = start;
    TextPosition target;
    if (up && offset.dy > 0) {
      target = current.getPosition(
          Offset(_horizontal!, offset.dy - current.preferredLineHeight));
    } else if (!up &&
        offset.dy < current.height - current.preferredLineHeight) {
      target = current.getPosition(
          Offset(_horizontal!, offset.dy + current.preferredLineHeight));
    } else if (up && start > 0) {
      final previousEnd = start - 1;
      targetStart =
          previousEnd == 0 ? 0 : text.lastIndexOf('\n', previousEnd - 1) + 1;
      final previous = paragraph(targetStart, previousEnd);
      target = previous.getPosition(
          Offset(_horizontal!, previous.height - previous.preferredLineHeight));
    } else if (!up && end < text.length) {
      targetStart = end + 1;
      final nextEnd = text.indexOf('\n', targetStart);
      final next = paragraph(targetStart, nextEnd < 0 ? text.length : nextEnd);
      target = next.getPosition(Offset(_horizontal!, 0));
    } else {
      targetStart = 0;
      target = TextPosition(offset: up ? 0 : text.length);
    }
    provider.retainParagraphs(retained);
    final result = TextSelection(
        baseOffset: extend ? selected.baseOffset : targetStart + target.offset,
        extentOffset: targetStart + target.offset,
        affinity: target.affinity);
    _lastTarget = result;
    return result;
  }
}
