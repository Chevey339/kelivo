part of 're_editor.dart';

enum CodeShortcutType {
  selectAll,
  cut,
  copy,
  paste,
  delete,
  backspace,
  undo,
  redo,
  lineSelect,
  lineDelete,
  lineDeleteForward,
  lineDeleteBackward,
  lineMoveUp,
  lineMoveDown,
  cursorMoveUp,
  cursorMoveDown,
  cursorMoveForward,
  cursorMoveBackward,
  cursorMoveLineStart,
  cursorMoveLineEnd,
  cursorMovePageStart,
  cursorMovePageEnd,
  cursorMovePageUp,
  cursorMovePageDown,
  cursorMoveWordBoundaryForward,
  cursorMoveWordBoundaryBackward,
  selectionExtendUp,
  selectionExtendDown,
  selectionExtendForward,
  selectionExtendBackward,
  selectionExtendLineStart,
  selectionExtendLineEnd,
  selectionExtendPageStart,
  selectionExtendPageEnd,
  selectionExtendWordBoundaryForward,
  selectionExtendWordBoundaryBackward,
  wordDeleteForward,
  wordDeleteBackward,
  indent,
  outdent,
  newLine,
  transposeCharacters,
  singleLineComment,
  multiLineComment,
  find,
  findToggleMatchCase,
  findToggleRegex,
  replace,
  save,
  esc,
}

abstract class CodeShortcutsActivatorsBuilder {

  const CodeShortcutsActivatorsBuilder();

  List<ShortcutActivator>? build(CodeShortcutType type);

}

class DefaultCodeShortcutsActivatorsBuilder extends CodeShortcutsActivatorsBuilder {

  const DefaultCodeShortcutsActivatorsBuilder();

  @override
  List<ShortcutActivator>? build(CodeShortcutType type) {
    return kIsMacOS ? _kDefaultMacCodeShortcutsActivators[type] :
      _kDefaultCommonCodeShortcutsActivators[type];
  }

}

abstract class CodeShortcutEditableIntent extends Intent {
  const CodeShortcutEditableIntent();
}

class CodeShortcutSelectAllIntent extends Intent {
  const CodeShortcutSelectAllIntent();
}

class CodeShortcutCopyIntent extends Intent {
  const CodeShortcutCopyIntent();
}

class CodeShortcutCutIntent extends CodeShortcutEditableIntent {
  const CodeShortcutCutIntent();
}

class CodeShortcutPasteIntent extends CodeShortcutEditableIntent {
  const CodeShortcutPasteIntent();
}

class CodeShortcutUndoIntent extends CodeShortcutEditableIntent {
  const CodeShortcutUndoIntent();
}

class CodeShortcutRedoIntent extends CodeShortcutEditableIntent {
  const CodeShortcutRedoIntent();
}

class CodeShortcutLineSelectIntent extends Intent {
  const CodeShortcutLineSelectIntent();
}

class ShortcutLineDeleteIntent extends CodeShortcutEditableIntent {
  const ShortcutLineDeleteIntent();
}

class ShortcutLineMoveIntent extends CodeShortcutEditableIntent {
  final VerticalDirection direction;
  const ShortcutLineMoveIntent(this.direction);
}

class ShortcutLineDeleteDirectionIntent extends CodeShortcutEditableIntent {
  final bool forward;
  const ShortcutLineDeleteDirectionIntent(this.forward);
}

class CodeShortcutIndentIntent extends CodeShortcutEditableIntent {
  const CodeShortcutIndentIntent();
}

class CodeShortcutOutdentIntent extends CodeShortcutEditableIntent {
  const CodeShortcutOutdentIntent();
}

class CodeShortcutCommentIntent extends CodeShortcutEditableIntent {
  final bool single;
  const CodeShortcutCommentIntent(this.single);
}

class CodeShortcutCursorMoveIntent extends Intent {
  final AxisDirection direction;
  const CodeShortcutCursorMoveIntent(this.direction);
}

class CodeShortcutCursorMoveLineEdgeIntent extends Intent {
  final bool forward;
  const CodeShortcutCursorMoveLineEdgeIntent(this.forward);
}

class CodeShortcutCursorMoveDocEdgeIntent extends Intent {
  final bool forward;
  const CodeShortcutCursorMoveDocEdgeIntent(this.forward);
}

class CodeShortcutCursorMovePageIntent extends Intent {
  final bool forward;
  const CodeShortcutCursorMovePageIntent(this.forward);
}

class CodeShortcutCursorMoveWordBoundaryIntent extends Intent {
  final bool forward;
  const CodeShortcutCursorMoveWordBoundaryIntent(this.forward);
}

class CodeShortcutSelectionExtendIntent extends Intent {
  final AxisDirection direction;
  const CodeShortcutSelectionExtendIntent(this.direction);
}

class CodeShortcutSelectionExtendLineEdgeIntent extends Intent {
  final bool forward;
  const CodeShortcutSelectionExtendLineEdgeIntent(this.forward);
}

class CodeShortcutSelectionExtendPageEdgeIntent extends Intent {
  final bool forward;
  const CodeShortcutSelectionExtendPageEdgeIntent(this.forward);
}

class CodeShortcutSelectionExtendWordBoundaryIntent extends Intent {
  final bool forward;
  const CodeShortcutSelectionExtendWordBoundaryIntent(this.forward);
}

class ShortcutWordDeleteDirectionIntent extends CodeShortcutEditableIntent {
  final bool forward;
  const ShortcutWordDeleteDirectionIntent(this.forward);
}

class CodeShortcutDeleteIntent extends CodeShortcutEditableIntent {
  final bool forward;
  const CodeShortcutDeleteIntent(this.forward);
}

class CodeShortcutNewLineIntent extends CodeShortcutEditableIntent {
  const CodeShortcutNewLineIntent();
}

class CodeShortcutTransposeCharactersIntent extends CodeShortcutEditableIntent {
  const CodeShortcutTransposeCharactersIntent();
}

class CodeShortcutFindIntent extends Intent {
  const CodeShortcutFindIntent();
}

class CodeShortcutFindToggleMatchCaseIntent extends Intent {
  const CodeShortcutFindToggleMatchCaseIntent();
}

class CodeShortcutFindToggleRegexIntent extends Intent {
  const CodeShortcutFindToggleRegexIntent();
}

class CodeShortcutReplaceIntent extends CodeShortcutEditableIntent {
  const CodeShortcutReplaceIntent();
}

class CodeShortcutSaveIntent extends Intent {
  const CodeShortcutSaveIntent();
}

class CodeShortcutEscIntent extends Intent {
  const CodeShortcutEscIntent();
}

const Map<CodeShortcutType, Intent> kCodeShortcutIntents = {
  CodeShortcutType.selectAll: CodeShortcutSelectAllIntent(),
  CodeShortcutType.cut: CodeShortcutCutIntent(),
  CodeShortcutType.copy: CodeShortcutCopyIntent(),
  CodeShortcutType.paste: CodeShortcutPasteIntent(),
  CodeShortcutType.delete: CodeShortcutDeleteIntent(true),
  CodeShortcutType.backspace: CodeShortcutDeleteIntent(false),
  CodeShortcutType.undo: CodeShortcutUndoIntent(),
  CodeShortcutType.redo: CodeShortcutRedoIntent(),
  CodeShortcutType.lineSelect: CodeShortcutLineSelectIntent(),
  CodeShortcutType.lineDelete: ShortcutLineDeleteIntent(),
  CodeShortcutType.lineDeleteForward: ShortcutLineDeleteDirectionIntent(true),
  CodeShortcutType.lineDeleteBackward: ShortcutLineDeleteDirectionIntent(false),
  CodeShortcutType.lineMoveUp: ShortcutLineMoveIntent(VerticalDirection.up),
  CodeShortcutType.lineMoveDown: ShortcutLineMoveIntent(VerticalDirection.down),
  CodeShortcutType.cursorMoveUp: CodeShortcutCursorMoveIntent(AxisDirection.up),
  CodeShortcutType.cursorMoveDown: CodeShortcutCursorMoveIntent(AxisDirection.down),
  CodeShortcutType.cursorMoveForward: CodeShortcutCursorMoveIntent(AxisDirection.right),
  CodeShortcutType.cursorMoveBackward: CodeShortcutCursorMoveIntent(AxisDirection.left),
  CodeShortcutType.cursorMoveLineStart: CodeShortcutCursorMoveLineEdgeIntent(false),
  CodeShortcutType.cursorMoveLineEnd: CodeShortcutCursorMoveLineEdgeIntent(true),
  CodeShortcutType.cursorMovePageStart: CodeShortcutCursorMoveDocEdgeIntent(false),
  CodeShortcutType.cursorMovePageEnd: CodeShortcutCursorMoveDocEdgeIntent(true),
  CodeShortcutType.cursorMovePageUp: CodeShortcutCursorMovePageIntent(false),
  CodeShortcutType.cursorMovePageDown: CodeShortcutCursorMovePageIntent(true),
  CodeShortcutType.cursorMoveWordBoundaryForward: CodeShortcutCursorMoveWordBoundaryIntent(true),
  CodeShortcutType.cursorMoveWordBoundaryBackward: CodeShortcutCursorMoveWordBoundaryIntent(false),
  CodeShortcutType.selectionExtendUp: CodeShortcutSelectionExtendIntent(AxisDirection.up),
  CodeShortcutType.selectionExtendDown: CodeShortcutSelectionExtendIntent(AxisDirection.down),
  CodeShortcutType.selectionExtendForward: CodeShortcutSelectionExtendIntent(AxisDirection.right),
  CodeShortcutType.selectionExtendBackward: CodeShortcutSelectionExtendIntent(AxisDirection.left),
  CodeShortcutType.selectionExtendLineStart: CodeShortcutSelectionExtendLineEdgeIntent(false),
  CodeShortcutType.selectionExtendLineEnd: CodeShortcutSelectionExtendLineEdgeIntent(true),
  CodeShortcutType.selectionExtendPageStart: CodeShortcutSelectionExtendPageEdgeIntent(false),
  CodeShortcutType.selectionExtendPageEnd: CodeShortcutSelectionExtendPageEdgeIntent(true),
  CodeShortcutType.selectionExtendWordBoundaryForward: CodeShortcutSelectionExtendWordBoundaryIntent(true),
  CodeShortcutType.selectionExtendWordBoundaryBackward: CodeShortcutSelectionExtendWordBoundaryIntent(false),
  CodeShortcutType.wordDeleteForward: ShortcutWordDeleteDirectionIntent(true),
  CodeShortcutType.wordDeleteBackward: ShortcutWordDeleteDirectionIntent(false),
  CodeShortcutType.indent: CodeShortcutIndentIntent(),
  CodeShortcutType.outdent: CodeShortcutOutdentIntent(),
  CodeShortcutType.newLine: CodeShortcutNewLineIntent(),
  CodeShortcutType.transposeCharacters: CodeShortcutTransposeCharactersIntent(),
  CodeShortcutType.singleLineComment: CodeShortcutCommentIntent(true),
  CodeShortcutType.multiLineComment: CodeShortcutCommentIntent(false),
  CodeShortcutType.find: CodeShortcutFindIntent(),
  CodeShortcutType.findToggleMatchCase: CodeShortcutFindToggleMatchCaseIntent(),
  CodeShortcutType.findToggleRegex: CodeShortcutFindToggleRegexIntent(),
  CodeShortcutType.replace: CodeShortcutReplaceIntent(),
  CodeShortcutType.save: CodeShortcutSaveIntent(),
  CodeShortcutType.esc: CodeShortcutEscIntent(),
};

const Map<CodeShortcutType, List<ShortcutActivator>> _kDefaultMacCodeShortcutsActivators = {
  CodeShortcutType.selectAll: [
    SingleActivator(LogicalKeyboardKey.keyA, meta: true)
  ],
  CodeShortcutType.cut: [
    SingleActivator(LogicalKeyboardKey.keyX, meta: true)
  ],
  CodeShortcutType.copy: [
    SingleActivator(LogicalKeyboardKey.keyC, meta: true)
  ],
  CodeShortcutType.paste: [
    SingleActivator(LogicalKeyboardKey.keyV, meta: true)
  ],
  CodeShortcutType.delete: [
    SingleActivator(LogicalKeyboardKey.delete,),
    SingleActivator(LogicalKeyboardKey.delete, shift: true),
  ],
  CodeShortcutType.backspace: [
    SingleActivator(LogicalKeyboardKey.backspace,),
    SingleActivator(LogicalKeyboardKey.backspace, shift: true),
  ],
  CodeShortcutType.undo: [
    SingleActivator(LogicalKeyboardKey.keyZ, meta: true)
  ],
  CodeShortcutType.redo: [
    SingleActivator(LogicalKeyboardKey.keyZ, meta: true, shift: true)
  ],
  CodeShortcutType.lineSelect: [
    SingleActivator(LogicalKeyboardKey.keyL, meta: true)
  ],
  CodeShortcutType.lineDelete: [
    SingleActivator(LogicalKeyboardKey.keyD, meta: true)
  ],
  CodeShortcutType.lineDeleteForward: [
    SingleActivator(LogicalKeyboardKey.delete, meta: true)
  ],
  CodeShortcutType.lineDeleteBackward: [
    SingleActivator(LogicalKeyboardKey.backspace, meta: true)
  ],
  CodeShortcutType.lineMoveUp: [
    SingleActivator(LogicalKeyboardKey.arrowUp, alt: true)
  ],
  CodeShortcutType.lineMoveDown: [
    SingleActivator(LogicalKeyboardKey.arrowDown, alt: true)
  ],
  CodeShortcutType.cursorMoveUp: [
    SingleActivator(LogicalKeyboardKey.arrowUp)
  ],
  CodeShortcutType.cursorMoveDown: [
    SingleActivator(LogicalKeyboardKey.arrowDown)
  ],
  CodeShortcutType.cursorMoveForward: [
    SingleActivator(LogicalKeyboardKey.arrowRight)
  ],
  CodeShortcutType.cursorMoveBackward: [
    SingleActivator(LogicalKeyboardKey.arrowLeft)
  ],
  CodeShortcutType.cursorMoveLineStart: [
    SingleActivator(LogicalKeyboardKey.arrowLeft, meta: true),
    SingleActivator(LogicalKeyboardKey.home)
  ],
  CodeShortcutType.cursorMoveLineEnd: [
    SingleActivator(LogicalKeyboardKey.arrowRight, meta: true),
    SingleActivator(LogicalKeyboardKey.end),
  ],
  CodeShortcutType.cursorMovePageStart: [
    SingleActivator(LogicalKeyboardKey.arrowUp, meta: true),
    SingleActivator(LogicalKeyboardKey.home, control: true)
  ],
  CodeShortcutType.cursorMovePageEnd: [
    SingleActivator(LogicalKeyboardKey.arrowDown, meta: true),
    SingleActivator(LogicalKeyboardKey.end, control: true)
  ],
  CodeShortcutType.cursorMoveWordBoundaryBackward: [
    SingleActivator(LogicalKeyboardKey.arrowLeft, alt: true)
  ],
  CodeShortcutType.cursorMoveWordBoundaryForward: [
    SingleActivator(LogicalKeyboardKey.arrowRight, alt: true)
  ],
  CodeShortcutType.selectionExtendUp: [
    SingleActivator(LogicalKeyboardKey.arrowUp, shift: true)
  ],
  CodeShortcutType.selectionExtendDown: [
    SingleActivator(LogicalKeyboardKey.arrowDown, shift: true)
  ],
  CodeShortcutType.selectionExtendForward: [
    SingleActivator(LogicalKeyboardKey.arrowRight, shift: true)
  ],
  CodeShortcutType.selectionExtendBackward: [
    SingleActivator(LogicalKeyboardKey.arrowLeft, shift: true)
  ],
  CodeShortcutType.selectionExtendPageStart: [
    SingleActivator(LogicalKeyboardKey.arrowUp, shift: true, meta: true),
    SingleActivator(LogicalKeyboardKey.home, shift: true, meta: true)
  ],
  CodeShortcutType.selectionExtendPageEnd: [
    SingleActivator(LogicalKeyboardKey.arrowDown, shift: true, meta: true),
    SingleActivator(LogicalKeyboardKey.end, shift: true, meta: true)
  ],
  CodeShortcutType.selectionExtendLineStart: [
    SingleActivator(LogicalKeyboardKey.arrowLeft, shift: true, meta: true),
    SingleActivator(LogicalKeyboardKey.home, shift: true)
  ],
  CodeShortcutType.selectionExtendLineEnd: [
    SingleActivator(LogicalKeyboardKey.arrowRight, shift: true, meta: true),
    SingleActivator(LogicalKeyboardKey.end, shift: true)
  ],
  CodeShortcutType.selectionExtendWordBoundaryForward: [
    SingleActivator(LogicalKeyboardKey.arrowLeft, shift: true, alt: true)
  ],
  CodeShortcutType.selectionExtendWordBoundaryBackward: [
    SingleActivator(LogicalKeyboardKey.arrowRight, shift: true, alt: true)
  ],
  CodeShortcutType.wordDeleteForward: [
    SingleActivator(LogicalKeyboardKey.delete, alt: true),
    SingleActivator(LogicalKeyboardKey.delete, alt: true, shift: true),
    SingleActivator(LogicalKeyboardKey.delete, meta: true, shift: true)
  ],
  CodeShortcutType.wordDeleteBackward: [
    SingleActivator(LogicalKeyboardKey.backspace, alt: true),
    SingleActivator(LogicalKeyboardKey.backspace, alt: true, shift: true),
    SingleActivator(LogicalKeyboardKey.backspace, meta: true, shift: true)
  ],
  CodeShortcutType.indent: [
    SingleActivator(LogicalKeyboardKey.tab)
  ],
  CodeShortcutType.outdent: [
    SingleActivator(LogicalKeyboardKey.tab, shift: true)
  ],
  CodeShortcutType.newLine: [
    SingleActivator(LogicalKeyboardKey.enter),
    SingleActivator(LogicalKeyboardKey.enter, shift: true),
    SingleActivator(LogicalKeyboardKey.enter, meta: true),
    SingleActivator(LogicalKeyboardKey.enter, meta: true, shift: true),
    SingleActivator(LogicalKeyboardKey.numpadEnter),
    SingleActivator(LogicalKeyboardKey.numpadEnter, shift: true),
    SingleActivator(LogicalKeyboardKey.numpadEnter, meta: true),
    SingleActivator(LogicalKeyboardKey.numpadEnter, meta: true, shift: true)
  ],
  CodeShortcutType.transposeCharacters: [
    SingleActivator(LogicalKeyboardKey.keyT, control: true)
  ],
  CodeShortcutType.singleLineComment: [
    SingleActivator(LogicalKeyboardKey.slash, meta: true)
  ],
  CodeShortcutType.multiLineComment: [
    SingleActivator(LogicalKeyboardKey.slash, meta: true, shift: true)
  ],
  CodeShortcutType.find: [
    SingleActivator(LogicalKeyboardKey.keyF, meta: true)
  ],
  CodeShortcutType.findToggleMatchCase: [
    SingleActivator(LogicalKeyboardKey.keyC, meta: true, alt: true)
  ],
  CodeShortcutType.findToggleRegex: [
    SingleActivator(LogicalKeyboardKey.keyR, meta: true, alt: true)
  ],
  CodeShortcutType.replace: [
    SingleActivator(LogicalKeyboardKey.keyF, meta: true, alt: true)
  ],
  CodeShortcutType.save: [
    SingleActivator(LogicalKeyboardKey.keyS, meta: true)
  ],
  CodeShortcutType.esc: [
    SingleActivator(LogicalKeyboardKey.escape)
  ],
};

const Map<CodeShortcutType, List<ShortcutActivator>> _kDefaultCommonCodeShortcutsActivators = {
  CodeShortcutType.selectAll: [
    SingleActivator(LogicalKeyboardKey.keyA, control: true)
  ],
  CodeShortcutType.cut: [
    SingleActivator(LogicalKeyboardKey.keyX, control: true)
  ],
  CodeShortcutType.copy: [
    SingleActivator(LogicalKeyboardKey.keyC, control: true)
  ],
  CodeShortcutType.paste: [
    SingleActivator(LogicalKeyboardKey.keyV, control: true)
  ],
  CodeShortcutType.delete: [
    SingleActivator(LogicalKeyboardKey.delete,),
    SingleActivator(LogicalKeyboardKey.delete, shift: true),
  ],
  CodeShortcutType.backspace: [
    SingleActivator(LogicalKeyboardKey.backspace,),
    SingleActivator(LogicalKeyboardKey.backspace, shift: true),
  ],
  CodeShortcutType.undo: [
    SingleActivator(LogicalKeyboardKey.keyZ, control: true)
  ],
  CodeShortcutType.redo: [
    SingleActivator(LogicalKeyboardKey.keyZ, control: true, shift: true)
  ],
  CodeShortcutType.lineSelect: [
    SingleActivator(LogicalKeyboardKey.keyL, control: true)
  ],
  CodeShortcutType.lineDelete: [
    SingleActivator(LogicalKeyboardKey.keyD, control: true)
  ],
  CodeShortcutType.lineDeleteForward: [
    SingleActivator(LogicalKeyboardKey.delete, control: true)
  ],
  CodeShortcutType.lineDeleteBackward: [
    SingleActivator(LogicalKeyboardKey.backspace, control: true)
  ],
  CodeShortcutType.lineMoveUp: [
    SingleActivator(LogicalKeyboardKey.arrowUp, alt: true)
  ],
  CodeShortcutType.lineMoveDown: [
    SingleActivator(LogicalKeyboardKey.arrowDown, alt: true)
  ],
  CodeShortcutType.cursorMoveUp: [
    SingleActivator(LogicalKeyboardKey.arrowUp)
  ],
  CodeShortcutType.cursorMoveDown: [
    SingleActivator(LogicalKeyboardKey.arrowDown)
  ],
  CodeShortcutType.cursorMoveForward: [
    SingleActivator(LogicalKeyboardKey.arrowRight)
  ],
  CodeShortcutType.cursorMoveBackward: [
    SingleActivator(LogicalKeyboardKey.arrowLeft)
  ],
  CodeShortcutType.cursorMoveLineStart: [
    SingleActivator(LogicalKeyboardKey.arrowLeft, control: true),
    SingleActivator(LogicalKeyboardKey.home)
  ],
  CodeShortcutType.cursorMoveLineEnd: [
    SingleActivator(LogicalKeyboardKey.arrowRight, control: true),
    SingleActivator(LogicalKeyboardKey.end)
  ],
  CodeShortcutType.cursorMovePageStart: [
    SingleActivator(LogicalKeyboardKey.arrowUp, control: true),
    SingleActivator(LogicalKeyboardKey.home, control: true)
  ],
  CodeShortcutType.cursorMovePageEnd: [
    SingleActivator(LogicalKeyboardKey.arrowDown, control: true),
    SingleActivator(LogicalKeyboardKey.end, control: true)
  ],
  CodeShortcutType.cursorMoveWordBoundaryBackward: [
    SingleActivator(LogicalKeyboardKey.arrowLeft, alt: true)
  ],
  CodeShortcutType.cursorMoveWordBoundaryForward: [
    SingleActivator(LogicalKeyboardKey.arrowRight, alt: true)
  ],
  CodeShortcutType.selectionExtendUp: [
    SingleActivator(LogicalKeyboardKey.arrowUp, shift: true)
  ],
  CodeShortcutType.selectionExtendDown: [
    SingleActivator(LogicalKeyboardKey.arrowDown, shift: true)
  ],
  CodeShortcutType.selectionExtendForward: [
    SingleActivator(LogicalKeyboardKey.arrowRight, shift: true)
  ],
  CodeShortcutType.selectionExtendBackward: [
    SingleActivator(LogicalKeyboardKey.arrowLeft, shift: true)
  ],
  CodeShortcutType.selectionExtendPageStart: [
    SingleActivator(LogicalKeyboardKey.home, shift: true, control: true)
  ],
  CodeShortcutType.selectionExtendPageEnd: [
    SingleActivator(LogicalKeyboardKey.end, shift: true, control: true)
  ],
  CodeShortcutType.selectionExtendLineStart: [
    SingleActivator(LogicalKeyboardKey.home, shift: true)
  ],
  CodeShortcutType.selectionExtendLineEnd: [
    SingleActivator(LogicalKeyboardKey.end, shift: true)
  ],
  CodeShortcutType.selectionExtendWordBoundaryForward: [
    SingleActivator(LogicalKeyboardKey.arrowLeft, shift: true, alt: true)
  ],
  CodeShortcutType.selectionExtendWordBoundaryBackward: [
    SingleActivator(LogicalKeyboardKey.arrowRight, shift: true, alt: true)
  ],
  CodeShortcutType.wordDeleteForward: [
    SingleActivator(LogicalKeyboardKey.delete, alt: true),
    SingleActivator(LogicalKeyboardKey.delete, alt: true, shift: true),
    SingleActivator(LogicalKeyboardKey.delete, control: true),
  ],
  CodeShortcutType.wordDeleteBackward: [
    SingleActivator(LogicalKeyboardKey.backspace, alt: true),
    SingleActivator(LogicalKeyboardKey.backspace, alt: true, shift: true),
    SingleActivator(LogicalKeyboardKey.backspace, control: true),
  ],
  CodeShortcutType.indent: [
    SingleActivator(LogicalKeyboardKey.tab)
  ],
  CodeShortcutType.outdent: [
    SingleActivator(LogicalKeyboardKey.tab, shift: true)
  ],
  CodeShortcutType.newLine: [
    SingleActivator(LogicalKeyboardKey.enter),
    SingleActivator(LogicalKeyboardKey.enter, shift: true),
    SingleActivator(LogicalKeyboardKey.enter, control: true),
    SingleActivator(LogicalKeyboardKey.enter, control: true, shift: true),
    SingleActivator(LogicalKeyboardKey.numpadEnter),
    SingleActivator(LogicalKeyboardKey.numpadEnter, shift: true),
    SingleActivator(LogicalKeyboardKey.numpadEnter, control: true),
    SingleActivator(LogicalKeyboardKey.numpadEnter, control: true, shift: true)
  ],
  CodeShortcutType.transposeCharacters: [
    SingleActivator(LogicalKeyboardKey.keyT, control: true)
  ],
  CodeShortcutType.singleLineComment: [
    SingleActivator(LogicalKeyboardKey.slash, control: true)
  ],
  CodeShortcutType.multiLineComment: [
    SingleActivator(LogicalKeyboardKey.slash, control: true, shift: true)
  ],
  CodeShortcutType.find: [
    SingleActivator(LogicalKeyboardKey.keyF, control: true)
  ],
  CodeShortcutType.findToggleMatchCase: [
    SingleActivator(LogicalKeyboardKey.keyC, control: true, alt: true)
  ],
  CodeShortcutType.findToggleRegex: [
    SingleActivator(LogicalKeyboardKey.keyR, control: true, alt: true)
  ],
  CodeShortcutType.replace: [
    SingleActivator(LogicalKeyboardKey.keyF, control: true, alt: true)
  ],
  CodeShortcutType.save: [
    SingleActivator(LogicalKeyboardKey.keyS, control: true)
  ],
  CodeShortcutType.esc: [
    SingleActivator(LogicalKeyboardKey.escape)
  ],
};