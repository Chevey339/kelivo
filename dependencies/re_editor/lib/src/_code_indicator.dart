part of 're_editor.dart';

class CodeLineNumberRenderObject extends RenderBox {

  CodeLineEditingController _controller;
  CodeIndicatorValueNotifier _notifier;
  TextStyle _textStyle;
  TextStyle _focusedTextStyle;
  int _minNumberCount;
  int _allLineCount;

  final String Function(int lineIndex)? _customLineIndex2Text;
  final TextPainter _textPainter;

  CodeLineNumberRenderObject({
    required CodeLineEditingController controller,
    required CodeIndicatorValueNotifier notifier,
    required TextStyle textStyle,
    required TextStyle focusedTextStyle,
    required int minNumberCount,
    String Function(int lineIndex)? custonLineIndex2Text,
  }) : _controller = controller,
    _notifier = notifier,
    _textStyle = textStyle,
    _focusedTextStyle = focusedTextStyle,
    _minNumberCount = minNumberCount,
    _allLineCount = controller.lineCount,
    _customLineIndex2Text = custonLineIndex2Text,
    _textPainter = TextPainter(
      textDirection: TextDirection.ltr,
    );

  set controller(CodeLineEditingController value) {
    if (_controller == value) {
      return;
    }
    if (attached) {
      _controller.removeListener(_onCodeLineChanged);
    }
    _controller = value;
    if (attached) {
      _controller.addListener(_onCodeLineChanged);
    }
    _onCodeLineChanged();
  }

  set notifier(CodeIndicatorValueNotifier value) {
    if (_notifier == value) {
      return;
    }
    if (attached) {
      _notifier.removeListener(markNeedsPaint);
    }
    _notifier = value;
    if (attached) {
      _notifier.addListener(markNeedsPaint);
    }
    markNeedsPaint();
  }

  set textStyle(TextStyle value) {
    if (_textStyle == value) {
      return;
    }
    _textStyle = value;
    markNeedsLayout();
  }

  set focusedTextStyle(TextStyle value) {
    if (_focusedTextStyle == value) {
      return;
    }
    _focusedTextStyle = value;
    markNeedsLayout();
  }

  set minNumberCount(int value) {
    if (_minNumberCount == value) {
      return;
    }
    _minNumberCount = value;
    markNeedsLayout();
  }

  @override
  bool hitTestSelf(Offset position) => true;

  @override
  void handleEvent(PointerEvent event, BoxHitTestEntry entry) {
    if (event is PointerDownEvent) {
      final Offset position = globalToLocal(event.position);
      final CodeLineRenderParagraph? paragraph = _findParagraphByPosition(position);
      if (paragraph != null) {
        _controller.selectLine(paragraph.index);
      }
    }
    super.handleEvent(event, entry);
  }

  @override
  void attach(covariant PipelineOwner owner) {
    _controller.addListener(_onCodeLineChanged);
    _notifier.addListener(markNeedsPaint);
    super.attach(owner);
  }

  @override
  void detach() {
    _controller.removeListener(_onCodeLineChanged);
    _notifier.removeListener(markNeedsPaint);
    super.detach();
  }

  @override
  void performLayout() {
    assert(constraints.maxHeight > 0 && constraints.maxHeight != double.infinity,
      'CodeLineNumber should have an explicit height.');
    _textPainter.text = TextSpan(
      text: '0' * max(_minNumberCount, _allLineCount.toString().length),
      style: _textStyle,
    );
    _textPainter.layout();
    size = Size(_textPainter.width, constraints.maxHeight);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final Canvas canvas = context.canvas;
    final CodeIndicatorValue? value = _notifier.value;
    if (value == null || value.paragraphs.isEmpty) {
      // line offsets are not determined.
      return;
    }
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(offset.dx, offset.dy, size.width, size.height));
    int firstLineIndex = _controller.index2lineIndex(value.paragraphs.first.index);
    for (final CodeLineRenderParagraph paragraph in value.paragraphs) {
      final lineIndexText = _customLineIndex2Text?.call(firstLineIndex) ?? (firstLineIndex + 1).toString();
      _textPainter.text = TextSpan(
        text: lineIndexText,
        style: paragraph.index == value.focusedIndex ? _focusedTextStyle : _textStyle
      );
      _textPainter.layout();
      _textPainter.paint(canvas, Offset(offset.dx + size.width - _textPainter.width, offset.dy + paragraph.offset.dy));
      firstLineIndex += _controller.codeLines[paragraph.index].lineCount;
    }
    canvas.restore();
  }

  void _onCodeLineChanged() {
    if (!attached) {
      return;
    }
    final int newAllLineCount = _controller.lineCount;
    if (max(_minNumberCount, newAllLineCount.toString().length) !=
      max(_minNumberCount, _allLineCount.toString().length)) {
      _allLineCount = newAllLineCount;
      markNeedsLayout();
    } else {
      _allLineCount = newAllLineCount;
      markNeedsPaint();
    }
  }

  CodeLineRenderParagraph? _findParagraphByPosition(Offset position) {
    final int? index = _notifier.value?.paragraphs.indexWhere((e) => position.dy > e.top
      && position.dy < e.bottom);
    if (index == null || index < 0) {
      return null;
    }
    return _notifier.value?.paragraphs[index];
  }

}

class CodeChunkIndicatorRenderObject extends RenderBox implements MouseTrackerAnnotation {

  double _width;
  CodeChunkController _controller;
  CodeIndicatorValueNotifier _notifier;
  CodeChunkIndicatorPainter _painter;
  bool _collapseIndicatorVisible;
  bool _expandIndicatorVisible;
  MouseCursor _cursor;

  CodeChunkIndicatorRenderObject({
    required double width,
    required CodeChunkController controller,
    required CodeIndicatorValueNotifier notifier,
    required CodeChunkIndicatorPainter painter,
    required bool collapseIndicatorVisible,
    required bool expandIndicatorVisible,
  }) : _width = width,
    _controller = controller,
    _notifier = notifier,
    _painter = painter,
    _collapseIndicatorVisible = collapseIndicatorVisible,
    _expandIndicatorVisible = expandIndicatorVisible,
    _cursor = MouseCursor.defer;

  set width(double value) {
    if (_width == value) {
      return;
    }
    _width = value;
    markNeedsLayout();
  }

  set controller(CodeChunkController value) {
    if (_controller == value) {
      return;
    }
    if (attached) {
      _controller.removeListener(markNeedsPaint);
    }
    _controller = value;
    if (attached) {
      _controller.addListener(markNeedsPaint);
    }
    markNeedsPaint();
  }

  set notifier(CodeIndicatorValueNotifier value) {
    if (_notifier == value) {
      return;
    }
    if (attached) {
      _notifier.removeListener(markNeedsPaint);
    }
    _notifier = value;
    if (attached) {
      _notifier.addListener(markNeedsPaint);
    }
    markNeedsPaint();
  }

  set painter(CodeChunkIndicatorPainter value) {
    if (_painter == value) {
      return;
    }
    _painter = value;
    markNeedsPaint();
  }

  set collapseIndicatorVisible(bool value) {
    if (_collapseIndicatorVisible == value) {
      return;
    }
    _collapseIndicatorVisible = value;
    markNeedsPaint();
  }

  set expandIndicatorVisible(bool value) {
    if (_expandIndicatorVisible == value) {
      return;
    }
    _expandIndicatorVisible = value;
    markNeedsPaint();
  }

  @override
  MouseCursor get cursor => _cursor;

  @override
  PointerEnterEventListener? get onEnter => null;

  @override
  PointerExitEventListener? get onExit => null;

  @override
  bool get validForMouseTracker => true;

  @override
  bool hitTest(BoxHitTestResult result, {required ui.Offset position}) {
    bool hitTarget = false;
    if (size.contains(position)) {
      result.add(BoxHitTestEntry(this, position));
      if (_findParagraphByPosition(position) != null) {
        _cursor = SystemMouseCursors.click;
      } else {
        _cursor = MouseCursor.defer;
      }
      hitTarget = true;
    }
    return hitTarget;
  }

  @override
  void handleEvent(PointerEvent event, BoxHitTestEntry entry) {
    if (event is PointerDownEvent) {
      final Offset position = globalToLocal(event.position);
      final CodeLineRenderParagraph? paragraph = _findParagraphByPosition(position);
      if (paragraph != null) {
        _controller.toggle(paragraph.index);
      }
    }
    super.handleEvent(event, entry);
  }

  @override
  void attach(covariant PipelineOwner owner) {
    _controller.addListener(markNeedsPaint);
    _notifier.addListener(markNeedsPaint);
    super.attach(owner);
  }

  @override
  void detach() {
    _controller.removeListener(markNeedsPaint);
    _notifier.removeListener(markNeedsPaint);
    super.detach();
  }

  @override
  void performLayout() {
    assert(_width > 0 && _width != double.infinity &&
      constraints.maxHeight > 0 && constraints.maxHeight != double.infinity,
      'CodeChunkIndicator should have an explicit width and height.');
    size = Size(_width, constraints.maxHeight);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final Canvas canvas = context.canvas;
    final CodeIndicatorValue? value = _notifier.value;
    if (value == null) {
      // line offsets are not determined.
      return;
    }
    if (!_expandIndicatorVisible && !_collapseIndicatorVisible) {
      return;
    }
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(offset.dx, offset.dy, size.width, size.height));
    for (final CodeLineRenderParagraph paragraph in value.paragraphs) {
      final Offset newOffset = offset + Offset(0, paragraph.offset.dy);
      final Size container = Size(_width, paragraph.preferredLineHeight);
      if (paragraph.chunkParent) {
        if (_expandIndicatorVisible) {
          canvas.save();
          canvas.translate(newOffset.dx, newOffset.dy);
          _painter.paintExpandIndicator(canvas, container);
          canvas.restore();
        }
      } else if (_controller.canCollapse(paragraph.index)) {
        if (_collapseIndicatorVisible) {
          canvas.save();
          canvas.translate(newOffset.dx, newOffset.dy);
          _painter.paintCollapseIndicator(canvas, container);
          canvas.restore();
        }
      }
    }
    canvas.restore();
  }

  CodeLineRenderParagraph? _findParagraphByPosition(Offset position) {
    final int? index = _notifier.value?.paragraphs.indexWhere((e) => position.dy > e.top
      && position.dy < e.top + e.preferredLineHeight);
    if (index == null || index < 0) {
      return null;
    }
    final CodeLineRenderParagraph? paragraph = _notifier.value?.paragraphs[index];
    if (paragraph == null) {
      return null;
    }
    if (paragraph.chunkParent || _controller.findByIndex(paragraph.index) != null) {
      return paragraph;
    }
    return null;
  }

}
