import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_math_fork/flutter_math.dart';

/// Horizontally scrollable inline math that preserves baseline alignment.
///
/// [SingleChildScrollView] breaks baseline forwarding because its internal
/// [RenderViewport] does not implement [computeDistanceToActualBaseline].
/// This widget uses a custom [RenderObject] that lays out the child
/// unconstrained in width, reports correct baseline, and paints with a
/// horizontal scroll offset driven by a [GestureDetector].
class InlineMathScrollable extends StatefulWidget {
  const InlineMathScrollable({required this.child, super.key});
  final Widget child;

  @override
  State<InlineMathScrollable> createState() => _InlineMathScrollableState();
}

class _InlineMathScrollableState extends State<InlineMathScrollable> {
  double _scrollOffset = 0.0;
  double _maxScroll = 0.0;

  void _onHorizontalDragUpdate(DragUpdateDetails d) {
    setState(() {
      _scrollOffset = (_scrollOffset - d.delta.dx).clamp(0.0, _maxScroll);
    });
  }

  void _updateMaxScroll(double childWidth, double viewportWidth) {
    _maxScroll = (childWidth - viewportWidth).clamp(0.0, double.infinity);
    if (_scrollOffset > _maxScroll) {
      _scrollOffset = _maxScroll;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragUpdate: _onHorizontalDragUpdate,
      child: _InlineMathScrollableRenderWidget(
        scrollOffset: _scrollOffset,
        onMetrics: _updateMaxScroll,
        child: widget.child,
      ),
    );
  }
}

class _InlineMathScrollableRenderWidget extends SingleChildRenderObjectWidget {
  const _InlineMathScrollableRenderWidget({
    required this.scrollOffset,
    required this.onMetrics,
    required Widget child,
  }) : super(child: child);

  final double scrollOffset;
  final void Function(double childWidth, double viewportWidth) onMetrics;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderInlineMathScrollable(
        initialScrollOffset: scrollOffset,
        onMetrics: onMetrics,
      );

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderInlineMathScrollable renderObject,
  ) {
    renderObject
      ..scrollOffset = scrollOffset
      ..onMetrics = onMetrics;
  }
}

class _RenderInlineMathScrollable extends RenderProxyBox {
  _RenderInlineMathScrollable({
    required double initialScrollOffset,
    required this.onMetrics,
  }) : _scrollOffset = initialScrollOffset;

  double _scrollOffset;
  set scrollOffset(double value) {
    if (_scrollOffset == value) return;
    _scrollOffset = value;
    markNeedsPaint();
  }

  void Function(double childWidth, double viewportWidth) onMetrics;

  @override
  void performLayout() {
    final child = this.child;
    if (child == null) {
      size = constraints.smallest;
      return;
    }
    child.layout(
      constraints.copyWith(maxWidth: double.infinity),
      parentUsesSize: true,
    );
    size = constraints.constrain(child.size);
    if (child.size.width > size.width) {
      onMetrics(child.size.width, size.width);
    }
  }

  @override
  double? computeDistanceToActualBaseline(TextBaseline baseline) {
    return child?.getDistanceToActualBaseline(baseline);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final child = this.child;
    if (child == null) return;
    if (child.size.width <= size.width) {
      context.paintChild(child, offset);
      return;
    }
    context.pushClipRect(needsCompositing, offset, Offset.zero & size, (
      context,
      clipOffset,
    ) {
      context.paintChild(child, clipOffset - Offset(_scrollOffset, 0));
    });
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    final child = this.child;
    if (child == null) return false;
    return result.addWithPaintOffset(
      offset: Offset(-_scrollOffset, 0),
      position: position,
      hitTest: (result, transformed) =>
          child.hitTest(result, position: transformed),
    );
  }
}

/// Safe math renderer that falls back to plain text when parsing fails.
Widget renderMath(String tex, {TextStyle? style, bool displayMode = false}) {
  final resolved = style ?? TextStyle();
  final normalizedTex = _normalizeMathTex(tex);
  try {
    return Math.tex(
      normalizedTex,
      mathStyle: displayMode ? MathStyle.display : MathStyle.text,
      textStyle: resolved,
      onErrorFallback: (_) => Text(normalizedTex, style: resolved),
    );
  } catch (_) {
    return Text(normalizedTex, style: resolved);
  }
}

TextStyle inlineMathTextStyle(TextStyle? style) {
  final base = style ?? TextStyle();
  final baseSize = base.fontSize ?? 15.5;
  return base.copyWith(fontSize: baseSize * 1.2);
}

WidgetSpan inlineMathSpan(Widget math) {
  return WidgetSpan(
    alignment: PlaceholderAlignment.baseline,
    baseline: TextBaseline.alphabetic,
    child: SelectionContainer.disabled(
      child: InlineMathScrollable(child: math),
    ),
  );
}

String _normalizeMathTex(String tex) {
  final escapedSpecials = _escapeInlineMathSpecials(tex);
  final normalizedBraces = _escapeLikelyLiteralMathBraces(escapedSpecials);
  return normalizedBraces.replaceAllMapped(RegExp(r'\\\|([\s\S]*?)\\\|'), (
    match,
  ) {
    final body = match.group(1) ?? '';
    return '\\lVert $body \\rVert';
  });
}

String _escapeInlineMathSpecials(String tex) {
  final buf = StringBuffer();
  for (var i = 0; i < tex.length; i++) {
    final ch = tex.codeUnitAt(i);
    if (ch == 0x23 &&
        !_isEscaped(tex, i) &&
        !_isTexColorHexArgumentPrefix(tex, i)) {
      buf.write(r'\#');
    } else {
      buf.writeCharCode(ch);
    }
  }
  return buf.toString();
}

bool _isEscaped(String text, int index) {
  var backslashCount = 0;
  for (var j = index - 1; j >= 0 && text[j] == '\\'; j--) {
    backslashCount++;
  }
  return backslashCount.isOdd;
}

bool _isTexColorHexArgumentPrefix(String tex, int index) {
  final open = _findContainingBraceOpen(tex, index);
  if (open == -1) return false;
  final close = _findMatchingCloseBrace(tex, open);
  if (close == -1 || index >= close) return false;
  if (!_isExactHexColorArgument(tex, open, index, close)) return false;
  return _isTexColorArgumentGroup(tex, open);
}

int _findContainingBraceOpen(String tex, int index) {
  var depth = 0;
  for (var i = index; i >= 0; i--) {
    if (tex[i] == '}') {
      depth++;
    } else if (tex[i] == '{') {
      if (depth == 0) return i;
      depth--;
    }
  }
  return -1;
}

int _findMatchingCloseBrace(String tex, int open) {
  var depth = 0;
  for (var i = open; i < tex.length; i++) {
    if (tex[i] == '{') {
      depth++;
    } else if (tex[i] == '}') {
      depth--;
      if (depth == 0) return i;
    }
  }
  return -1;
}

bool _isExactHexColorArgument(String tex, int open, int hash, int close) {
  final inner = tex.substring(open + 1, close);
  if (hash - open - 1 != 0) {
    if (hash - open - 1 > 6) return false;
    for (var j = open + 1; j < hash; j++) {
      if (tex[j] != ' ' && tex[j] != ',') return false;
    }
  }
  final hex = inner.substring(hash - open - 1);
  if (hex.length < 2) return false;
  if (hex.length > 8) return false;
  for (var j = 0; j < hex.length; j++) {
    final c = hex.codeUnitAt(j);
    if (!((c >= 0x30 && c <= 0x39) ||
        (c >= 0x41 && c <= 0x46) ||
        (c >= 0x61 && c <= 0x66))) {
      return false;
    }
  }
  return true;
}

bool _isTexColorArgumentGroup(String tex, int open) {
  if (open < 3) return false;
  return tex.substring(open - 3, open) == 'lor';
}

String _escapeLikelyLiteralMathBraces(String tex) {
  final buf = StringBuffer();
  var i = 0;
  while (i < tex.length) {
    if (tex[i] == '{' && _isLikelyLiteralBraceOpen(tex, i)) {
      buf.write(r'\{');
      i++;
      continue;
    }
    buf.writeCharCode(tex.codeUnitAt(i));
    i++;
  }
  return buf.toString();
}

bool _isLikelyLiteralBraceOpen(String tex, int index) {
  if (index == 0) return false;
  final prev = tex[index - 1];
  if (prev == '{' || prev == ' ') return false;
  if (_isEscaped(tex, index)) return false;
  if (prev == '_' || prev == '^') return false;
  return true;
}
