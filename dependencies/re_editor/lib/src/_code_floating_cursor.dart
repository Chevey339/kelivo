part of 're_editor.dart';

// The time the animation of the floating cursor snapping to the final cursor position will take.
const Duration floatingCursorSnapDuration = Duration(milliseconds: 300);

// Class containing the floating cursor control logic.
class _CodeFloatingCursorController
    extends ValueNotifier<_FloatingCursorState> {
  late final _CodeCursorBlinkController _blinkController;
  late final AnimationController _animationController;

  _CodeFloatingCursorController() : super(const _FloatingCursorState());

  /// Sets the [Offset] and [CodeLineSelection] of the cursors. Setting either one of these offsets
  /// to null is equivalent to turning off the corresponding cursor.
  void setFloatingCursorPositions(
      {Offset? floatingCursorOffset,
      Offset? previewCursorOffset,
      Offset? finalCursorOffset,
      CodeLineSelection? finalCursorSelection}) {
    if (value.floatingCursorOffset != null && floatingCursorOffset == null) {
      // Starting the floating cursor, stop blinking of the normal cursor
      _blinkController.startBlink();
    } else if (value.floatingCursorOffset == null &&
        floatingCursorOffset != null) {
      // Stopping the floating cursor, resume blinking of the normal cursor
      _blinkController.stopBlink();
    }

    value = _FloatingCursorState(
      floatingCursorOffset: floatingCursorOffset,
      previewCursorOffset: previewCursorOffset,
      finalCursorOffset: finalCursorOffset,
      finalCursorSelection: finalCursorSelection,
    );
  }

  /// Turns off the floating cursor by setting all the offsets to null.
  void disableFloatingCursor() {
    setFloatingCursorPositions();
  }

  /// Update the [Offset] value of preview cursor.
  void updatePreviewCursorOffset(Offset? previewCursorOffset) {
    value = value.copyWith(previewCursorOffset: previewCursorOffset);
  }

  void _onFloatingCursorResetAnimationTick() {
    if (_animationController.isCompleted) {
      // Once animation is complete, turn off the floating cursor off
      disableFloatingCursor();
    } else {
      final double lerpValue = _animationController.value;
      final double lerpX = ui.lerpDouble(value.floatingCursorOffset!.dx,
          value.finalCursorOffset!.dx, lerpValue)!;
      final double lerpY = ui.lerpDouble(value.floatingCursorOffset!.dy,
          value.finalCursorOffset!.dy, lerpValue)!;

      setFloatingCursorPositions(
          floatingCursorOffset: Offset(lerpX, lerpY),
          previewCursorOffset: value.previewCursorOffset,
          finalCursorOffset: value.finalCursorOffset,
          finalCursorSelection: value.finalCursorSelection);
    }
  }

  /// Performs the "snapping" animation and turns of the floating cursor.
  void animateDisableFloatingCursor() {
    _animationController.value = 0.0;
    _animationController.animateTo(1,
        duration: floatingCursorSnapDuration, curve: Curves.decelerate);
  }

  @override
  void dispose() {
    disableFloatingCursor();
    super.dispose();
  }

  /// The two methods below are meant to only be used for property injection. Both [_blinkController] and [_animationController]
  /// have to be set before calling any of the other methods for the [_CodeFloatingCursorController] to work properly.

  set blinkController(_CodeCursorBlinkController value) {
    _blinkController = value;
  }

  set animationController(AnimationController value) {
    value.addListener(_onFloatingCursorResetAnimationTick);
    _animationController = value;
  }

  Offset? get previewCursorOffset => value.previewCursorOffset;

  Offset? get floatingCursorOffset => value.floatingCursorOffset;
}

class _FloatingCursorState {
  /// The offset of the floating cursor.
  final Offset? floatingCursorOffset;

  /// The offset of the preview cursor. The preview cursor is only visible when the floating cursor is hovering to the right of
  /// the end of the line, where no text is present. It shows where the actual cursor would end up if the floating cursor would
  /// be stoped in that moment.
  final Offset? previewCursorOffset;

  /// The offset where the actual cursor would be placed if floating cursor would be stopped.
  final Offset? finalCursorOffset;

  final CodeLineSelection? finalCursorSelection;

  const _FloatingCursorState(
      {this.floatingCursorOffset,
      this.previewCursorOffset,
      this.finalCursorOffset,
      this.finalCursorSelection});

  /// Creates a copy of this instance with the specified values overridden.
  _FloatingCursorState copyWith({
    Offset? floatingCursorOffset,
    Offset? previewCursorOffset,
    Offset? finalCursorOffset,
    CodeLineSelection? finalCursorSelection,
  }) {
    return _FloatingCursorState(
      floatingCursorOffset: floatingCursorOffset ?? this.floatingCursorOffset,
      previewCursorOffset: previewCursorOffset ?? this.previewCursorOffset,
      finalCursorOffset: finalCursorOffset ?? this.finalCursorOffset,
      finalCursorSelection: finalCursorSelection ?? this.finalCursorSelection,
    );
  }

  bool isActive() {
    // Floating cursor is active only if its offset is not null.
    return floatingCursorOffset != null;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is _FloatingCursorState &&
          floatingCursorOffset == other.floatingCursorOffset &&
          previewCursorOffset == other.previewCursorOffset &&
          finalCursorOffset == other.finalCursorOffset &&
          finalCursorSelection == other.finalCursorSelection);

  @override
  int get hashCode => Object.hash(floatingCursorOffset, previewCursorOffset,
      finalCursorOffset, finalCursorSelection);
}
