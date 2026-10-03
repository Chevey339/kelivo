part of 're_editor.dart';

typedef CodeScrollbarBuilder = Widget Function(BuildContext context, Widget child, ScrollableDetails details);

class CodeScrollController {

  final ScrollController verticalScroller;
  final ScrollController horizontalScroller;

  GlobalKey? _editorKey;

  CodeScrollController({
    ScrollController? verticalScroller,
    ScrollController? horizontalScroller,
  }) : verticalScroller = verticalScroller ?? ScrollController(),
    horizontalScroller = horizontalScroller ?? ScrollController();

  void makeCenterIfInvisible(CodeLinePosition position) {
    _render?.makePositionCenterIfInvisible(position);
  }

  void makeVisible(CodeLinePosition position) {
    _render?.makePositionVisible(position);
  }

  void bindEditor(GlobalKey key) {
    _editorKey = key;
  }

  _CodeFieldRender? get _render => _editorKey?.currentContext?.findRenderObject() as _CodeFieldRender?;

  void dispose() {
    _editorKey = null;
  }

}