part of 're_editor.dart';

const int _kDefaultMinNumberCount = 3;
const Size _kDefaultChunkIndicatorSize = Size(7, 7);

typedef CodeIndicatorValueNotifier = ValueNotifier<CodeIndicatorValue?>;
typedef CodeIndicatorBuilder = Widget Function(
  BuildContext context,
  CodeLineEditingController editingController,
  CodeChunkController chunkController,
  CodeIndicatorValueNotifier notifier,
);

class CodeIndicatorValue {

  final List<CodeLineRenderParagraph> paragraphs;
  final int focusedIndex;

  CodeIndicatorValue({
    required this.paragraphs,
    this.focusedIndex = -1,
  });

  @override
  int get hashCode => Object.hashAll([paragraphs, focusedIndex]);

  @override
  bool operator ==(Object other) {
    if (other is! CodeIndicatorValue) {
      return false;
    }
    return listEquals(other.paragraphs, paragraphs) &&
        other.focusedIndex == focusedIndex;
  }

  CodeIndicatorValue copyWith({
    List<CodeLineRenderParagraph>? paragraphs,
    int? focusedIndex,
  }) {
    return CodeIndicatorValue(
      paragraphs: paragraphs ?? this.paragraphs,
      focusedIndex: focusedIndex ?? this.focusedIndex,
    );
  }

}

class DefaultCodeLineNumber extends LeafRenderObjectWidget {

  final CodeLineEditingController controller;
  final CodeIndicatorValueNotifier notifier;
  final TextStyle? textStyle;
  final TextStyle? focusedTextStyle;
  final int? minNumberCount;
  final String Function(int lineIndex)? customLineIndex2Text;

  const DefaultCodeLineNumber({
    super.key,
    required this.notifier,
    required this.controller,
    this.textStyle,
    this.focusedTextStyle,
    this.minNumberCount,
    this.customLineIndex2Text,
  });

  @override
  RenderObject createRenderObject(BuildContext context) => CodeLineNumberRenderObject(
    controller: controller,
    notifier: notifier,
    textStyle: textStyle ?? _useCodeTextStyle(context, false),
    focusedTextStyle: focusedTextStyle ?? _useCodeTextStyle(context, true),
    minNumberCount: minNumberCount ?? _kDefaultMinNumberCount,
    custonLineIndex2Text: customLineIndex2Text,
  );

  @override
  void updateRenderObject(BuildContext context, covariant CodeLineNumberRenderObject renderObject) {
    renderObject
      ..controller = controller
      ..notifier = notifier
      ..textStyle = textStyle ?? _useCodeTextStyle(context, false)
      ..focusedTextStyle = focusedTextStyle ?? _useCodeTextStyle(context, true)
      ..minNumberCount = minNumberCount ?? _kDefaultMinNumberCount;
    super.updateRenderObject(context, renderObject);
  }

  TextStyle _useCodeTextStyle(BuildContext context, bool focused) {
    final _CodeEditable? editor = context.findAncestorWidgetOfExactType<_CodeEditable>();
    assert(editor != null);
    return editor!.textStyle.copyWith(
      color: focused ? null :  editor.textStyle.color?.withAlpha(128)
    );
  }

}

class DefaultCodeChunkIndicator extends LeafRenderObjectWidget {

  final double width;
  final CodeChunkController controller;
  final CodeIndicatorValueNotifier notifier;
  final CodeChunkIndicatorPainter? painter;
  final bool collapseIndicatorVisible;
  final bool expandIndicatorVisible;

  const DefaultCodeChunkIndicator({
    super.key,
    required this.width,
    required this.controller,
    required this.notifier,
    this.painter,
    this.collapseIndicatorVisible = true,
    this.expandIndicatorVisible = true,
  });

  @override
  RenderObject createRenderObject(BuildContext context) => CodeChunkIndicatorRenderObject(
    width: width,
    controller: controller,
    notifier: notifier,
    painter: painter ?? DefaultCodeChunkIndicatorPainter(
      color: _useCodeTextColor(context),
    ),
    collapseIndicatorVisible: collapseIndicatorVisible,
    expandIndicatorVisible: expandIndicatorVisible,
  );

  @override
  void updateRenderObject(BuildContext context, covariant CodeChunkIndicatorRenderObject renderObject) {
    renderObject
      ..width = width
      ..controller = controller
      ..notifier = notifier
      ..painter = painter ?? DefaultCodeChunkIndicatorPainter(
        color: _useCodeTextColor(context),
      )
      ..collapseIndicatorVisible = collapseIndicatorVisible
      ..expandIndicatorVisible = expandIndicatorVisible;
    super.updateRenderObject(context, renderObject);
  }

  Color? _useCodeTextColor(BuildContext context) {
    final _CodeEditable? editor = context.findAncestorWidgetOfExactType<_CodeEditable>();
    assert(editor != null);
    return editor!.textStyle.color?.withAlpha(128);
  }

}

abstract class CodeChunkIndicatorPainter {

  void paintCollapseIndicator(Canvas canvas, Size container);

  void paintExpandIndicator(Canvas canvas, Size container);

}

class DefaultCodeChunkIndicatorPainter implements CodeChunkIndicatorPainter {

  final Color? color;
  final Size size;

  late final Paint _paint;

  DefaultCodeChunkIndicatorPainter({
    this.color,
    this.size = _kDefaultChunkIndicatorSize
  }) {
    _paint = Paint();
    if (color != null) {
      _paint.color = color!;
    }
  }

  @override
  void paintCollapseIndicator(Canvas canvas, Size container) {
    if (color == null || color == Colors.transparent || container.isEmpty) {
      return;
    }
    final Path path = Path();
    path.moveTo((container.width - size.width) / 2, (container.height - size.height) / 2);
    path.lineTo((container.width + size.width) / 2, (container.height - size.height) / 2);
    path.lineTo(container.width / 2, (container.height + size.height) / 2);
    path.lineTo((container.width - size.width) / 2, (container.height - size.height) / 2);
    canvas.drawPath(path, _paint);
  }

  @override
  void paintExpandIndicator(Canvas canvas, Size container) {
    if (color == null || color == Colors.transparent || container.isEmpty) {
      return;
    }
    final Path path = Path();
    path.moveTo((container.width - size.width) / 2, (container.height - size.height) / 2);
    path.lineTo((container.width + size.width) / 2, container.height / 2);
    path.lineTo((container.width - size.width) / 2, (container.height + size.height) / 2);
    path.lineTo((container.width - size.width) / 2, (container.height - size.height) / 2);
    canvas.drawPath(path, _paint);
  }

}
