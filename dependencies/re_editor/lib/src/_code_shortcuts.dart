part of 're_editor.dart';

class _CodeShortcuts extends StatefulWidget {
  final CodeShortcutsActivatorsBuilder builder;
  final Widget child;

  const _CodeShortcuts({required this.builder, required this.child});

  @override
  State<StatefulWidget> createState() => _CodeShortcutsState();
}

class _CodeShortcutsState extends State<_CodeShortcuts> {
  late final Map<ShortcutActivator, Intent> _shortcuts;

  @override
  void initState() {
    super.initState();
    _shortcuts = {};
    _buildShortcuts();
  }

  @override
  void didUpdateWidget(_CodeShortcuts oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.builder != widget.builder) {
      _buildShortcuts();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Shortcuts(shortcuts: _shortcuts, child: widget.child);
  }

  void _buildShortcuts() {
    _shortcuts.clear();
    for (final CodeShortcutType type in CodeShortcutType.values) {
      if (type == CodeShortcutType.backspace) {
        if (kIsAndroid || kIsIOS) {
          continue;
        }
      }
      final List<ShortcutActivator>? activators = widget.builder.build(type);
      if (activators == null || activators.isEmpty) {
        continue;
      }
      for (final ShortcutActivator activator in activators) {
        _shortcuts[activator] = kCodeShortcutIntents[type]!;
      }
    }
    // Protect space key go to the IME.
    _shortcuts.addAll({
      const SingleActivator(LogicalKeyboardKey.space):
          const DoNothingAndStopPropagationTextIntent(),
    });
  }
}

class _CodeShortcutActions extends StatelessWidget {
  final CodeLineEditingController editingController;
  final _CodeInputController inputController;
  final CodeFindController? findController;
  final CodeCommentFormatter? commentFormatter;
  final Map<Type, Action<Intent>>? overrideActions;
  final bool readOnly;
  final Widget child;

  const _CodeShortcutActions({
    required this.editingController,
    required this.inputController,
    this.findController,
    this.commentFormatter,
    required this.overrideActions,
    required this.readOnly,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final Map<Type, Action<Intent>> actions = {};
    for (final Intent intent in kCodeShortcutIntents.values) {
      // Do not add editable actions when read only.
      if (intent is CodeShortcutEditableIntent && readOnly) {
        continue;
      }
      if (intent is CodeShortcutEscIntent) {
        // Do not enable ESC key when nothing the eidtor can do.
        actions[intent.runtimeType] = _EscCallbackAction(
          controller: editingController,
          findController: findController,
          onInvoke: (intent) {
            return _onAction(context, intent);
          },
        );
        continue;
      }
      actions[intent.runtimeType] = _CompoDoNothingCallbackAction(
        controller: editingController,
        onInvoke: (intent) {
          return _onAction(context, intent);
        },
      );
    }
    return Actions(actions: {
      ...actions,
      ...{
        DoNothingAndStopPropagationTextIntent:
            DoNothingAction(consumesKey: false),
      },
      if (overrideActions != null) ...overrideActions!
    }, child: child);
  }

  static final Map<Type,
      void Function(Intent intent, _CodeShortcutActions actions)> actions = {
    CodeShortcutSelectAllIntent: (intent, actions) {
      actions.editingController.selectAll();
    },
    CodeShortcutLineSelectIntent: (intent, actions) {
      actions.editingController.selectLines(
          actions.editingController.selection.baseIndex,
          actions.editingController.selection.extentIndex);
    },
    CodeShortcutCutIntent: (intent, actions) {
      actions.editingController.cut();
    },
    CodeShortcutCopyIntent: (intent, actions) {
      actions.editingController.copy();
    },
    CodeShortcutPasteIntent: (intent, actions) {
      actions.editingController.paste();
    },
    CodeShortcutUndoIntent: (intent, actions) {
      actions.editingController.undo();
    },
    CodeShortcutRedoIntent: (intent, actions) {
      actions.editingController.redo();
    },
    ShortcutLineDeleteIntent: (intent, actions) {
      actions.editingController.deleteSelectionLines(true);
    },
    ShortcutLineDeleteDirectionIntent: (intent, actions) {
      if ((intent as ShortcutLineDeleteDirectionIntent).forward) {
        actions.editingController.deleteLineForward();
      } else {
        actions.editingController.deleteLineBackward();
      }
    },
    ShortcutLineMoveIntent: (intent, actions) {
      if ((intent as ShortcutLineMoveIntent).direction ==
          VerticalDirection.up) {
        actions.editingController.moveSelectionLinesUp();
      } else {
        actions.editingController.moveSelectionLinesDown();
      }
    },
    CodeShortcutIndentIntent: (intent, actions) {
      actions.editingController.applyIndent();
    },
    CodeShortcutOutdentIntent: (intent, actions) {
      actions.editingController.applyOutdent();
    },
    CodeShortcutCommentIntent: (intent, actions) {
      final CodeLineEditingValue? value = actions.commentFormatter?.format(
          actions.editingController.value,
          actions.editingController.options.indent,
          (intent as CodeShortcutCommentIntent).single);
      if (value != null) {
        actions.editingController.runRevocableOp(() {
          actions.editingController.value = value;
        });
      }
    },
    CodeShortcutCursorMoveIntent: (intent, actions) {
      actions.editingController
          .moveCursor((intent as CodeShortcutCursorMoveIntent).direction);
    },
    CodeShortcutCursorMoveLineEdgeIntent: (intent, actions) {
      if ((intent as CodeShortcutCursorMoveLineEdgeIntent).forward) {
        actions.editingController.moveCursorToLineEnd();
      } else {
        actions.editingController.moveCursorToLineStart();
      }
    },
    CodeShortcutCursorMoveDocEdgeIntent: (intent, actions) {
      if ((intent as CodeShortcutCursorMoveDocEdgeIntent).forward) {
        actions.editingController.moveCursorToPageEnd();
      } else {
        actions.editingController.moveCursorToPageStart();
      }
    },
    CodeShortcutCursorMovePageIntent: (intent, actions) {
      if ((intent as CodeShortcutCursorMovePageIntent).forward) {
        actions.editingController.moveCursorToPageDown();
      } else {
        actions.editingController.moveCursorToPageUp();
      }
    },
    CodeShortcutCursorMoveWordBoundaryIntent: (intent, actions) {
      if ((intent as CodeShortcutCursorMoveWordBoundaryIntent).forward) {
        actions.editingController.moveCursorToWordBoundaryForward();
      } else {
        actions.editingController.moveCursorToWordBoundaryBackward();
      }
    },
    CodeShortcutSelectionExtendIntent: (intent, actions) {
      actions.editingController.extendSelection(
          (intent as CodeShortcutSelectionExtendIntent).direction);
    },
    CodeShortcutSelectionExtendLineEdgeIntent: (intent, actions) {
      if ((intent as CodeShortcutSelectionExtendLineEdgeIntent).forward) {
        actions.editingController.extendSelectionToLineEnd();
      } else {
        actions.editingController.extendSelectionToLineStart();
      }
    },
    CodeShortcutSelectionExtendPageEdgeIntent: (intent, actions) {
      if ((intent as CodeShortcutSelectionExtendPageEdgeIntent).forward) {
        actions.editingController.extendSelectionToPageEnd();
      } else {
        actions.editingController.extendSelectionToPageStart();
      }
    },
    CodeShortcutSelectionExtendWordBoundaryIntent: (intent, actions) {
      if ((intent as CodeShortcutSelectionExtendWordBoundaryIntent).forward) {
        actions.editingController.extendSelectionToWordBoundaryForward();
      } else {
        actions.editingController.extendSelectionToWordBoundaryBackward();
      }
    },
    ShortcutWordDeleteDirectionIntent: (intent, actions) {
      if ((intent as ShortcutWordDeleteDirectionIntent).forward) {
        actions.editingController.deleteWordForward();
      } else {
        actions.editingController.deleteWordBackward();
      }
    },
    CodeShortcutDeleteIntent: (intent, actions) {
      if ((intent as CodeShortcutDeleteIntent).forward) {
        actions.editingController.deleteForward();
      } else {
        actions.editingController.deleteBackward();
      }
      actions.inputController.notifyListeners();
    },
    CodeShortcutNewLineIntent: (intent, actions) {
      actions.editingController.applyNewLine();
    },
    CodeShortcutTransposeCharactersIntent: (intent, actions) {
      actions.editingController.transposeCharacters();
    },
    CodeShortcutFindIntent: (intent, actions) {
      actions.findController?.findMode();
    },
    CodeShortcutFindToggleMatchCaseIntent: (intent, actions) {
      actions.findController?.toggleCaseSensitive();
    },
    CodeShortcutFindToggleRegexIntent: (intent, actions) {
      actions.findController?.toggleRegex();
    },
    CodeShortcutReplaceIntent: (intent, actions) {
      actions.findController?.replaceMode();
    },
    CodeShortcutEscIntent: (intent, actions) {
      if (actions.findController?.value != null) {
        actions.findController?.close();
      } else {
        actions.editingController.cancelSelection();
      }
    }
  };

  Object? _onAction(BuildContext context, Intent intent) {
    final Action<Intent>? action = Actions.maybeFind(context, intent: intent);
    if (action != null &&
        action.isActionEnabled &&
        action.consumesKey(intent)) {
      if (action is CallbackAction) {
        action.invoke(intent);
      }
      return null;
    }
    if (intent is CodeShortcutEditableIntent && readOnly) {
      return null;
    }
    if (editingController.isComposing) {
      return null;
    }
    bool keepAutoCompleteState = intent is CodeShortcutDeleteIntent;
    final handler = actions[intent.runtimeType];
    if (handler != null) {
      handler(intent, this);
    }
    if (!keepAutoCompleteState) {
      final _CodeAutocompleteState? autocompleteState =
          context.findAncestorStateOfType<_CodeAutocompleteState>();
      autocompleteState?.dismiss();
    }
    return intent;
  }
}

class _CompoDoNothingCallbackAction<T extends Intent>
    extends CallbackAction<T> {
  final CodeLineEditingController controller;

  _CompoDoNothingCallbackAction({
    required this.controller,
    required super.onInvoke,
  });

  @override
  bool consumesKey(T intent) {
    return !controller.isComposing;
  }
}

class _EscCallbackAction<T extends Intent> extends CallbackAction<T> {
  final CodeLineEditingController controller;
  final CodeFindController? findController;

  _EscCallbackAction({
    required this.controller,
    required this.findController,
    required super.onInvoke,
  });

  @override
  bool isEnabled(T intent) {
    return !controller.isComposing &&
        (findController?.value != null || !controller.selection.isCollapsed);
  }
}
