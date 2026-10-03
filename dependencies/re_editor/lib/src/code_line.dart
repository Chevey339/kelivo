part of 're_editor.dart';

typedef CodeLineSpanBuilder = TextSpan Function({
  required BuildContext context,
  required int index,
  required CodeLine codeLine,
  required TextSpan textSpan,
  required TextStyle style,
});

/// A controller for an editor field.
///
/// Whenever the user modifies a editor field with an associated
/// [CodeLineEditingController], the editor field updates [value] and the controller
/// notifies its listeners. Listeners can then read the [codeLines] and [selection]
/// properties to learn what the user has typed or how the selection has been
/// updated.
///
/// Similarly, if you modify the [codeLines] or [selection] properties, the editor
/// field will be notified and will update itself appropriately.
///
/// A [CodeLineEditingController] can also be used to provide an initial value for a
/// editor field. If you build a editor field with a controller that already has
/// [codeLines], the editor field will use that text as its initial value.
///
/// The [value] (as well as [codeLines] and [selection]) of this controller can be
/// updated from within a listener added to this controller. Be aware of
/// infinite loops since the listener will also be notified of the changes made
/// from within itself. Modifying the composing region from within a listener
/// can also have a bad interaction with some input methods. Gboard, for
/// example, will try to restore the composing region of the text if it was
/// modified programmatically, creating an infinite loop of communications
/// between the framework and the input method.
///
/// If both the [codeLines] or [selection] properties need to be changed, set the
/// controller's [value] instead.
///
/// Remember to [dispose] of the [CodeLineEditingController] when it is no longer
/// needed. This will ensure we discard any resources used by the object.
///
abstract class CodeLineEditingController extends ValueNotifier<CodeLineEditingValue> {

  /// Creates a controller for an editor field.
  ///
  /// This constructor treats an empty [codeLines] argument as if it were the empty
  /// string.
  ///
  /// Use [options] to define the linebreak and indent.
  ///
  /// Also, you can use [spanBuilder] to customize and override the code line style.
  ///
  factory CodeLineEditingController({
    CodeLines codeLines = _kInitialCodeLines,
    CodeLineOptions options = const CodeLineOptions(),
    CodeLineSpanBuilder? spanBuilder,
  }) => _CodeLineEditingControllerImpl(
    codeLines: codeLines,
    options: options,
    spanBuilder: spanBuilder,
  );

  /// Creates a controller for a given text.
  factory CodeLineEditingController.fromText(String? text, [
    CodeLineOptions options = const CodeLineOptions()
  ]) => _CodeLineEditingControllerImpl.fromText(text, options);

  /// Creates a controller for a given file path. The file content will read async.
  factory CodeLineEditingController.fromTextAsync(String? text, [
    CodeLineOptions options = const CodeLineOptions()
  ]) => _CodeLineEditingControllerImpl.fromTextAsync(text, options);

  /// Set the current editor codes.
  ///
  /// Setting this will notify all the listeners of this [CodeLineEditingController]
  /// that they need to update (it calls [notifyListeners]). For this reason,
  /// this value should only be set between frames, e.g. in response to user
  /// actions, not during the build, layout, or paint phases.
  set codeLines(CodeLines newCodeLines);

  /// Set the current editor code selections.
  ///
  /// Setting this will notify all the listeners of this [CodeLineEditingController]
  /// that they need to update (it calls [notifyListeners]). For this reason,
  /// this value should only be set between frames, e.g. in response to user
  /// actions, not during the build, layout, or paint phases.
  ///
  /// This property can be set from a listener added to this
  /// [CodeLineEditingController]; however, one should not also set [codeLines]
  /// in a separate statement. To change both the [codeLines] and the [selection]
  /// change the controller's [value].
  ///
  /// If the new selection is of non-zero length, or is outside the composing
  /// range, the composing range is cleared.
  set selection(CodeLineSelection newSelection);

  /// Set the current editor code composing.
  ///
  /// Setting this will notify all the listeners of this [CodeLineEditingController]
  /// that they need to update (it calls [notifyListeners]). For this reason,
  /// this value should only be set between frames, e.g. in response to user
  /// actions, not during the build, layout, or paint phases.
  set composing(TextRange newComposing);

  /// Get the previous editing value.
  CodeLineEditingValue? get preValue;

  /// Get the code line options.
  CodeLineOptions get options;

  /// The current codes the user is editing.
  CodeLines get codeLines;

  /// Get the current editor code selections.
  CodeLineSelection get selection;

  /// Get the range of code that is still being composed.
  TextRange get composing;

  /// The code line at which the selection originates.
  CodeLine get baseLine;

  /// The code line at which the selection terminates.
  CodeLine get extentLine;

  /// The code line at which the selection starts.
  CodeLine get startLine;

  /// The code line at which the selection ends.
  CodeLine get endLine;

  /// Whether the code that is still being composed.
  bool get isComposing;

  /// The current text being edited.
  ///
  /// This Will convert all the code lines into a whole text.
  String get text;

  /// The current text being selected.
  String get selectedText;

  /// How many lines in the editor.
  int get lineCount;

  /// Expanded code selections.
  CodeLineSelection get unfoldLineSelection;

  /// Whether the code is empty.
  bool get isEmpty;

  /// Whether all the codes  are selected.
  bool get isAllSelected;

  /// Whether the undo action can be performed.
  bool get canUndo;

  /// Whether the redo action can be performed.
  bool get canRedo;

  /// Set the current editor text.
  ///
  /// Setting this will notify all the listeners of this [CodeLineEditingController]
  /// that they need to update (it calls [notifyListeners]). For this reason,
  /// this value should only be set between frames, e.g. in response to user
  /// actions, not during the build, layout, or paint phases.
  set text(String value);

  /// Set the current editor text async.
  ///
  /// Setting this will notify all the listeners of this [CodeLineEditingController]
  /// that they need to update (it calls [notifyListeners]). For this reason,
  /// this value should only be set between frames, e.g. in response to user
  /// actions, not during the build, layout, or paint phases.
  set textAsync(String value);

  /// Only used in internal.
  void bindEditor(GlobalKey key);

  /// Set the current editor value.
  /// In plain-text mode, [newValue] contains the complete physical-line range
  /// touched by the selection, including unselected text at either end.
  ///
  /// Setting this will notify all the listeners of this [CodeLineEditingController]
  /// that they need to update (it calls [notifyListeners]). For this reason,
  /// this value should only be set between frames, e.g. in response to user
  /// actions, not during the build, layout, or paint phases.
  void edit(TextEditingValue newValue);

  /// Select a code line at the given index.
  void selectLine(int index);

  /// Select some code lines at the given start and end index.
  void selectLines(int base, int extent);

  /// Select all the codes.
  void selectAll();

  /// The selection will be collaposed at the terminate position.
  void cancelSelection();

  /// Move up the selected code lines.
  void moveSelectionLinesUp();

  /// Move down the selected code lines.
  void moveSelectionLinesDown();

  /// Move the cursor to a direction.
  void moveCursor(AxisDirection direction);

  /// Move the cursor to the start of current line.
  void moveCursorToLineStart();

  /// Move the cursor to the end of current line.
  void moveCursorToLineEnd();

  /// Move the cursor to the start of document.
  void moveCursorToPageStart();

  /// Move the cursor to the end of document.
  void moveCursorToPageEnd();

  /// TODO
  void moveCursorToPageUp();

  /// TODO
  void moveCursorToPageDown();

  /// Move the cursor to the start of the word.
  void moveCursorToWordBoundaryForward();

  /// Move the cursor to the end of the word.
  void moveCursorToWordBoundaryBackward();

  /// Extend the selection to a direction.
  void extendSelection(AxisDirection direction);

  /// Extend the selection to the start of current line.
  void extendSelectionToLineStart();

  /// Extend the selection to the end of current line.
  void extendSelectionToLineEnd();

  /// Extend the selection to the start of document.
  void extendSelectionToPageStart();

  /// Extend the selection to the end of document.
  void extendSelectionToPageEnd();

  /// Extend the selection to the start of the word.
  void extendSelectionToWordBoundaryForward();

  /// Extend the selection to the end of the word.
  void extendSelectionToWordBoundaryBackward();

  /// Delete the selected lines.
  void deleteSelectionLines([bool keepExtentOffset = true]);

  /// Delete content before the cursor at the current line.
  void deleteLineForward();

  /// Delete content after the cursor at the current line.
  void deleteLineBackward();

  /// Delete the selected codes.
  ///
  /// Note that this operation will have no effect if the selection is collapsed.
  void deleteSelection();

  /// If the selection is currently collapsed, the character behind the cursor will be deleted.
  /// Otherwise, will delete the selection, same as [deleteSelection].
  ///
  /// Note that if the cursor is between closing symbols, such as braces,
  /// the left and right brace will be deleted together.
  void deleteBackward();

  /// If the selection is currently collapsed, the character in front of the cursor will be deleted.
  /// Otherwise, will delete the selection, same as [deleteSelection].
  ///
  /// Note that if the cursor is between closing symbols, such as braces,
  /// the left and right brace will be deleted together.
  void deleteForward();

  /// Delete the word behind the cursor.
  void deleteWordBackward();

  /// Delete the word in front of the cursor.
  void deleteWordForward();

  /// Insert a newline character.
  void applyNewLine();

  /// Insert a indent.
  void applyIndent();

  /// Delete a indent.
  void applyOutdent();

  /// Transpose characters.
  void transposeCharacters();

  /// Replace the selected code with a new string [replacement].
  void replaceSelection(String replacement, [CodeLineSelection? selection]);

  /// Replaces all substrings that match [pattern] with [replacement].
  void replaceAll(Pattern pattern, String replacement);

  /// Reverts the value on the stack to the previous value.
  void undo();

  /// Updates the value on the stack to the next value.
  void redo();

  /// If the selection is currently collapsed, the whole line will be copied.
  /// Otherwise, copy the selected codes.
  Future<void> copy();

  /// If the selection is currently collapsed, the whole line will be cut.
  /// Otherwise, cut the selected codes.
  void cut();

  /// Paste text from [Clipboard].
  void paste();

  /// Set the composing region to an empty range.
  ///
  /// The composing region is the range of text that is still being composed.
  /// Calling this function indicates that the user is done composing that
  /// region.
  ///
  /// Calling this will notify all the listeners of this [CodeLineEditingController]
  /// that they need to update (it calls [notifyListeners]). For this reason,
  /// this method should only be called between frames, e.g. in response to user
  /// actions, not during the build, layout, or paint phases.
  void clearComposing();

  /// Clear the undo and redo history.
  void clearHistory();

  /// Collapse codes form [start] to [end].
  void collapseChunk(int start, int end);

  /// Expand the codes at [index] of lines.
  void expandChunk(int index);

  /// Convert the [index] to the unfold line index.
  int index2lineIndex(int index);

  /// Get code line information at [lineIndex].
  CodeLineIndex lineIndex2Index(int lineIndex);

  /// Scroll the editor to make sure the cursor is visible at center.
  void makeCursorCenterIfInvisible();

  /// Scroll the editor to make sure the cursor is visible.
  void makeCursorVisible();

  /// Scroll the editor to make sure the given position is visible at center.
  void makePositionCenterIfInvisible(CodeLinePosition position);

  /// Scroll the editor to make sure the given position is visible.
  void makePositionVisible(CodeLinePosition position);

  /// Force the render to repaint.
  void forceRepaint();

  /// Perform an operation. If the editor content changes, it will
  /// be recorded in the undo history.
  void runRevocableOp(VoidCallback op);

  /// Builds [TextSpan] from current editing value.
  /// This can override the code syntax highlighting styles.
  TextSpan buildTextSpan({
    required BuildContext context,
    required int index,
    required TextSpan textSpan,
    required TextStyle style,
  });
}

/// A delegate controller for an editor field.
///
/// We can override some default behaviors of the controller.
class CodeLineEditingControllerDelegate extends _CodeLineEditingControllerDelegate {

  CodeLineEditingControllerDelegate({
    required CodeLineEditingController delegate,
  }) {
    super.delegate = delegate;
  }

}

class CodeLine {

  static const CodeLine empty = CodeLine('');

  final String text;
  final List<CodeLine> chunks;

  const CodeLine(this.text, [this.chunks = const[]]);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is CodeLine
        && other.text == text
        && listEquals(other.chunks, chunks);
  }

  @override
  int get hashCode => Object.hash(text, chunks);

  int get length => text.length;

  int get characterLength => text.characters.length;

  bool get chunkParent => chunks.isNotEmpty;

  int get lineCount {
    int count = 1;
    for (final CodeLine codeLine in chunks) {
      count += codeLine.lineCount;
    }
    return count;
  }

  int get charCount {
    int count = length;
    for (final CodeLine codeLine in chunks) {
      count += codeLine.charCount;
    }
    return count;
  }

  @override
  String toString() {
    return text;
  }

  String substring(int start, [int? end]) {
    if (end != null) {
      if (end < start) {
        end = start;
      } else if (end > length) {
        end = length;
      }
    }
    return start >= length ? '' : text.substring(start, end);
  }

  String takeCharacter(int count) {
    return text.characters.take(count).string;
  }

  String takeLastCharacter(int count) {
    return text.characters.takeLast(count).string;
  }

  String takeCharacterAtLastIndex(int index) {
    return text.characters.elementAt(text.characters.length - 1 - index);
  }

  String takeCharacterAt(int index) {
    return text.characters.elementAt(index);
  }

  String skipCharacter(int count) {
    return text.characters.skip(count).string;
  }

  String skipLastCharacter(int count) {
    return text.characters.skipLast(count).string;
  }

  int codeUnitAt(int index) => text.codeUnitAt(index);

  CodeLine copyWith({
    String? text,
    List<CodeLine>? chunks
  }) {
    return CodeLine(
      text ?? this.text,
      chunks ?? this.chunks
    );
  }

  String asString(int start, TextLineBreak lineBreak) {
    return [substring(start), ...chunks.map((e) => e.asString(0, lineBreak))].join(lineBreak.value);
  }

  List<String> flat() {
    final List<String> codeLines = [text];
    for (final CodeLine child in chunks) {
      codeLines.addAll(child.flat());
    }
    return codeLines;
  }

}

/// The current codes, selection, and composing state for editing a run of text.
class CodeLineEditingValue {

  /// Creates information for editing a run of codes.
  ///
  /// The selection and composing range must be within the codes. This is not
  /// checked during construction, and must be guaranteed by the caller.
  ///
  /// The default value of [selection] is `CodeLineSelection.zero()`.
  /// This indicates that there is no selection at all.
  const CodeLineEditingValue({
    required this.codeLines,
    this.selection = const CodeLineSelection.zero(),
    this.composing = TextRange.empty,
  });

  const CodeLineEditingValue.empty() : this(
    codeLines: _kInitialCodeLines
  );

  /// The current codes being edited.
  final CodeLines codeLines;

  /// The range of codes that is currently selected.
  ///
  /// When [selection] is a [CodeLineSelection] that has the same
  /// `base` and `extent` position, the [selection] property represents the
  /// caret position.
  final CodeLineSelection selection;

  /// The range of text that is still being composed.
  ///
  /// Composing regions are created by input methods (IMEs) to indicate the text
  /// within a certain range is provisional. For instance, the Android Gboard
  /// app's English keyboard puts the current word under the caret into a
  /// composing region to indicate the word is subject to autocorrect or
  /// prediction changes.
  ///
  /// Composing regions can also be used for performing multistage input, which
  /// is typically used by IMEs designed for phonetic keyboard to enter
  /// ideographic symbols. As an example, many CJK keyboards require the user to
  /// enter a Latin alphabet sequence and then convert it to CJK characters. On
  /// iOS, the default software keyboards do not have a dedicated view to show
  /// the unfinished Latin sequence, so it's displayed directly in the text
  /// field, inside of a composing region.
  ///
  /// The composing region should typically only be changed by the IME, or the
  /// user via interacting with the IME.
  ///
  /// If the range represented by this property is [TextRange.empty], then the
  /// text is not currently being composed.
  final TextRange composing;

  CodeLineEditingValue copyWith({
    CodeLines? codeLines,
    CodeLineSelection? selection,
    TextRange? composing,
  }) {
    return CodeLineEditingValue(
      codeLines: codeLines ?? this.codeLines,
      selection: selection ?? this.selection,
      composing: composing ?? this.composing
    );
  }

  bool get isInitial => codeLines == _kInitialCodeLines;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is CodeLineEditingValue
        && other.codeLines.equals(codeLines)
        && other.selection == selection
        && other.composing == composing;
  }

  @override
  int get hashCode => Object.hash(codeLines, selection, composing);

  @override
  String toString() {
    return 'codeLines: $codeLines, selection: $selection, composing: $composing';
  }

}

/// A range of code lines that represents a selection.
class CodeLineSelection {

  /// The line index at which the selection originates.
  final int baseIndex;

  /// The line index at which the selection terminates.
  final int extentIndex;

  /// The offset at which the selection originates.
  ///
  /// Might be larger than, smaller than, or equal to extent.
  final int baseOffset;

  /// The offset at which the selection terminates.
  ///
  /// When the user uses the arrow keys to adjust the selection, this is the
  /// value that changes. Similarly, if the current theme paints a caret on one
  /// side of the selection, this is the location at which to paint the caret.
  ///
  /// Might be larger than, smaller than, or equal to base.
  final int extentOffset;

  /// If the code range is collapsed and has more than one visual location
  /// (e.g., occurs at a line break), which of the two locations to use when
  /// painting the caret.
  final TextAffinity baseAffinity;

  /// If the code range is collapsed and has more than one visual location
  /// (e.g., occurs at a line break), which of the two locations to use when
  /// painting the caret.
  final TextAffinity extentAffinity;

  /// Creates a code selection.
  const CodeLineSelection({
    required this.baseIndex,
    required this.baseOffset,
    required this.extentIndex,
    required this.extentOffset,
    this.baseAffinity = TextAffinity.downstream,
    this.extentAffinity = TextAffinity.downstream,
  });

  /// Creates a collapsed selection at the given line index and offset.
  ///
  /// A collapsed selection starts and ends at the same offset, which means it
  /// contains zero characters but instead serves as an insertion point in the
  /// text.
  const CodeLineSelection.collapsed({
    required int index,
    required int offset,
    TextAffinity affinity = TextAffinity.downstream,
  }) : this(
      baseIndex: index,
      baseOffset: offset,
      extentIndex: index,
      extentOffset: offset,
      baseAffinity: affinity,
      extentAffinity: affinity
  );

  /// Creates a collapsed selection at the given code position.
  ///
  /// A collapsed selection starts and ends at the same offset, which means it
  /// contains zero characters but instead serves as an insertion point in the
  /// text.
  CodeLineSelection.fromPosition({
    required CodeLinePosition position
  }) : this.collapsed(
      index: position.index,
      offset: position.offset,
      affinity: position.affinity,
  );

  /// Creates a selection at the given line index and range.
  CodeLineSelection.fromRange({
    required CodeLineRange range
  }) : this(
    baseIndex: range.index,
    baseOffset: range.start,
    extentIndex: range.index,
    extentOffset: range.end,
  );

  /// Creates a selection at the given line index and selection.
  CodeLineSelection.fromTextSelection({
    required int index,
    required TextSelection selection
  }) : this(
    baseIndex: index,
    baseOffset: selection.baseOffset,
    baseAffinity: selection.affinity,
    extentIndex: index,
    extentOffset: selection.extentOffset,
    extentAffinity: selection.affinity,
  );

  /// Creates a collapsed selection at the beginning.
  const CodeLineSelection.zero() : this(
    baseIndex: 0,
    baseOffset: 0,
    extentIndex: 0,
    extentOffset: 0,
  );

  /// The position at which the selection originates.
  CodeLinePosition get base {
    return CodeLinePosition(
      index: baseIndex,
      offset: baseOffset,
      affinity: baseAffinity
    );
  }

  /// The position at which the selection terminates.
  CodeLinePosition get extent {
    return CodeLinePosition(
      index: extentIndex,
      offset: extentOffset,
      affinity: extentAffinity
    );
  }

  /// The position at which the selection starts.
  CodeLinePosition get start {
    if (baseIndex < extentIndex) {
      return base;
    } else if (baseIndex > extentIndex) {
      return extent;
    } else {
      if (baseOffset < extentOffset) {
        return base;
      } else {
        return extent;
      }
    }
  }

  /// The position at which the selection ends.
  CodeLinePosition get end {
    if (baseIndex < extentIndex) {
      return extent;
    } else if (baseIndex > extentIndex) {
      return base;
    } else {
      if (baseOffset < extentOffset) {
        return extent;
      } else {
        return base;
      }
    }
  }

  /// The line index at which the selection starts.
  int get startIndex => start.index;

  /// The offset at which the selection starts.
  int get startOffset => start.offset;

  /// The line index at which the selection ends.
  int get endIndex => end.index;

  /// The offset at which the selection ends.
  int get endOffset => end.offset;

  /// Whether this range is empty (but still potentially placed inside the text).
  bool get isCollapsed => isSameLine && baseOffset == extentOffset;

  /// Whether this selection is in a same line.
  bool get isSameLine => baseIndex == extentIndex;

  /// Whether this selection contains another selection.
  bool contains(CodeLineSelection selection) {
    if (startIndex < selection.startIndex && endIndex > selection.endIndex) {
      return true;
    }
    if (startIndex > selection.startIndex || endIndex < selection.endIndex) {
      return false;
    }
    final bool startInside;
    if (startIndex == selection.startIndex) {
      startInside = startOffset <= selection.startOffset;
    } else {
      startInside = true;
    }
    final bool endInside;
    if (endIndex == selection.endIndex) {
      endInside = endOffset >= selection.endOffset;
    } else {
      endInside = true;
    }
    return startInside && endInside;
  }

  CodeLineSelection copyWith({
    int? baseIndex,
    int? extentIndex,
    int? baseOffset,
    int? extentOffset,
    TextAffinity? baseAffinity,
    TextAffinity? extentAffinity,
  }) {
    return CodeLineSelection(
      baseIndex: baseIndex ?? this.baseIndex,
      baseOffset: baseOffset ?? this.baseOffset,
      baseAffinity: baseAffinity ?? this.baseAffinity,
      extentIndex: extentIndex ?? this.extentIndex,
      extentOffset: extentOffset ?? this.extentOffset,
      extentAffinity: extentAffinity ?? this.extentAffinity,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other is! CodeLineSelection) {
      return false;
    }
    return other.baseIndex == baseIndex
        && other.extentIndex == extentIndex
        && other.baseOffset == baseOffset
        && other.extentOffset == extentOffset
        && other.baseAffinity == baseAffinity
        && other.extentAffinity == extentAffinity;
  }

  @override
  int get hashCode {
    return Object.hash(baseIndex, extentIndex, baseOffset, extentOffset, baseAffinity, extentAffinity);
  }

  @override
  String toString() {
    return 'CodeLineSelection(baseIndex: $baseIndex, baseOffset: $baseOffset, baseAffinity: $baseAffinity, '
        'extentIndex: $extentIndex, extentOffset: $extentOffset, extentAffinity: $extentAffinity)';
  }

}

/// A position in a string of code.
///
/// A CodeLinePosition can be used to describe a caret position in between
/// characters. The [index] points to the line index and the [offset] points
/// to the position between `offset - 1` and `offset` characters of the string,
/// and the [affinity] is used to describe which character this position affiliates
/// with.
class CodeLinePosition extends TextPosition {

  /// Creates an object representing a particular position in a code.
  const CodeLinePosition({
    required this.index,
    required super.offset,
    super.affinity = TextAffinity.downstream,
  });

  /// Line index in the codes.
  final int index;

  /// Creates the CodeLinePosition with the line index and text position.
  CodeLinePosition.from({
    required int index,
    required TextPosition position
  }) : this(
    index: index,
    offset: position.offset,
    affinity: position.affinity
  );

  CodeLinePosition copyWith({
    int? index,
    int? offset,
    TextAffinity? affinity
  }) {
    return CodeLinePosition(
      index: index ?? this.index,
      offset: offset ?? this.offset,
      affinity: affinity ?? this.affinity,
    );
  }

  /// Get the text position withou line index.
  TextPosition get textPosition => TextPosition(offset: offset, affinity: affinity);

  /// Whether the current code position is before the given position.
  bool isBefore(CodeLinePosition position) {
    if (index < position.index) {
      return true;
    }
    if (index > position.index) {
      return false;
    }
    return offset < position.offset;
  }

  /// Whether the current code position is after the given position.
  bool isAfter(CodeLinePosition position) {
    if (index > position.index) {
      return true;
    }
    if (index < position.index) {
      return false;
    }
    return offset > position.offset;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is CodeLinePosition
        && other.index == index
        && other.offset == offset
        && other.affinity == affinity;
  }

  @override
  int get hashCode => Object.hash(index, offset, affinity);

  @override
  String toString() {
    return 'CodeLinePosition(index: $index, offset: $offset, affinity: $affinity)';
  }

}

/// A range of code that represents a selection.
class CodeLineRange extends TextRange {

  /// Creates a code range.
  const CodeLineRange({
    required this.index,
    required super.start,
    required super.end,
  });

  /// Line index in the codes.
  final int index;

  /// Creates a code range at the given line index and text range.
  factory CodeLineRange.from({
    required int index,
    required TextRange range
  }) {
    return CodeLineRange(
      index: index,
      start: range.start,
      end: range.end
    );
  }

  /// Creates a collapsed range at the given offset.
  ///
  /// A collapsed range starts and ends at the same offset, which means it
  /// contains zero characters but instead serves as an insertion point in the
  /// text.
  const CodeLineRange.collapsed({
    required int index,
    required int offset
  }) : this(
    index: index,
    start: offset,
    end: offset
  );

  /// Creates a collapsed range with negative offset.
  const CodeLineRange.empty() : this(
    index: 0,
    start: -1,
    end: -1
  );

  /// Creates a new [CodeLineRange] based on the current selection, with the
  /// provided parameters overridden.
  CodeLineRange copyWith({
    int? index,
    int? start,
    int? end
  }) {
    return CodeLineRange(
      index: index ?? this.index,
      start: start ?? this.start,
      end: end ?? this.end,
    );
  }

  @override
  int get hashCode => Object.hash(index, start, end);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is CodeLineRange
        && other.index == index
        && other.start == start
        && other.end == end;
  }

  @override
  String toString() => 'CodeLineRange(index: $index start: $start, end: $end)';

}

/// Some options of the code lines.
class CodeLineOptions {

  static const int _defaultIndentSize = 2;

  const CodeLineOptions({
    this.lineBreak = TextLineBreak.lf,
    this.indentSize = _defaultIndentSize,
    this.plainText = false,
  });

  /// Line break symbols, like LF, CRLF.
  ///
  /// Defaults to [TextLineBreak.lf].
  final TextLineBreak lineBreak;

  /// Indent length, default value is 2.
  final int indentSize;

  /// Literal message editing without code indentation or paired deletion.
  final bool plainText;

  CodeLineOptions copyWith({
    TextLineBreak? lineBreak,
    int? indentSize,
    bool? plainText,
  }) {
    return CodeLineOptions(
      lineBreak: lineBreak ?? this.lineBreak,
      indentSize: indentSize ?? this.indentSize,
      plainText: plainText ?? this.plainText,
    );
  }

  @override
  int get hashCode => Object.hash(lineBreak, indentSize, plainText);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is CodeLineOptions
        && other.lineBreak == lineBreak
        && other.indentSize == indentSize
        && other.plainText == plainText;
  }

  String get indent => ' ' * indentSize;

}

class CodeLineIndex {

  final int index;
  final int chunkIndex;

  const CodeLineIndex(this.index, this.chunkIndex);

  @override
  int get hashCode => Object.hash(index, chunkIndex);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is CodeLineIndex
        && other.index == index
        && other.chunkIndex == chunkIndex;
  }

  @override
  String toString() => 'CodeLineIndex(index: $index chunkIndex: $chunkIndex)';
}

class CodeLineRenderParagraph {

  static const double _chunkIndicatorWidth = 15;

  final int index;
  final IParagraph paragraph;
  final Offset offset;
  final bool chunkParent;
  final bool chunkLongText;

  const CodeLineRenderParagraph({
    required this.index,
    required this.paragraph,
    required this.offset,
    required this.chunkParent,
    required this.chunkLongText,
  });

  double get preferredLineHeight => paragraph.preferredLineHeight;

  double get top => offset.dy;

  double get bottom => offset.dy + height;

  double get width => paragraph.width + (chunkParent ? _chunkIndicatorWidth : 0);

  double get height => paragraph.height;

  int get length => paragraph.length;

  bool inVerticalRange(Offset coordinate) => coordinate.dy >= top && coordinate.dy < bottom;

  CodeLinePosition getPosition(Offset offset) => CodeLinePosition.from(
    index: index,
    position: paragraph.getPosition(offset)
  );

  CodeLineRange getWord(Offset offset) => CodeLineRange.from(
    index: index,
    range: paragraph.getWord(offset)
  );

  InlineSpan? getSpanForPosition(Offset offset) => paragraph.getSpanForPosition(getPosition(offset));

  TextRange getRangeForSpan(InlineSpan span) => paragraph.getRangeForSpan(span);

  Offset? getOffset(TextPosition position) => paragraph.getOffset(position);

  List<Rect> getRangeRects(TextRange range) => paragraph.getRangeRects(range);

  void draw(Canvas canvas, Offset offset) {
    paragraph.draw(canvas, offset);
  }

  @override
  int get hashCode => Object.hash(index, paragraph, offset, chunkParent);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is CodeLineRenderParagraph
        && other.index == index
        && other.paragraph == paragraph
        && other.offset == offset
        && other.chunkParent == chunkParent;
  }

  CodeLineRenderParagraph copyWith({
    int? index,
    IParagraph? paragraph,
    Offset? offset,
    bool? chunkParent,
    bool? chunkLongText,
  }) {
    return CodeLineRenderParagraph(
      index: index ?? this.index,
      paragraph: paragraph ?? this.paragraph,
      offset: offset ?? this.offset,
      chunkParent: chunkParent ?? this.chunkParent,
      chunkLongText: chunkLongText ?? this.chunkLongText,
    );
  }

}

enum TextLineBreak {

  crlf,

  cr,

  lf,

}

extension TextLineBreakExtension on TextLineBreak {

  String get value => const ['\r\n', '\r', '\n'][index];

}

extension CodeLineExtension on String {

  bool get isMultiline {
    return contains('\n') || contains('\r');
  }

  List<String> get textLines {
    return replaceAll('\r\n', '\n').replaceAll('\r', '\n').split('\n');
  }

  CodeLines get codeLines {
    if (isEmpty) {
      return _kInitialCodeLines;
    }
    return CodeLines.of(textLines.map(CodeLine.new));
  }

  Future<CodeLines> get codeLinesAsync async {
    if (isEmpty) {
      return _kInitialCodeLines;
    }
    return compute<String, CodeLines>((message) => message.codeLines, this);
  }

}
