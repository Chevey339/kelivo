part of 're_editor.dart';

@immutable
class _MouseTrackerAnnotationTextSpan extends TextSpan {

  final int id;
  final MouseTrackerAnnotationTextSpan span;
  final List<Rect> rects;

  const _MouseTrackerAnnotationTextSpan({
    required this.id,
    required this.rects,
    required this.span,
  });

  @override
  PointerEnterEventListener? get onEnter => (event) {
    span.onEnterWithRect(event, id, rects);
  };

  @override
  PointerExitEventListener? get onExit => (event) {
    span.onExitWithRect(event, id, rects);
  };

  @override
  int get hashCode => span.hashCode;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is _MouseTrackerAnnotationTextSpan && span == other.span &&
      id == other.id;
  }

}