import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:re_editor/re_editor.dart';

typedef LongMessageContextMenuBuilder =
    Widget Function(
      BuildContext context,
      TextSelectionToolbarAnchors anchors,
      List<ContextMenuButtonItem> items,
      VoidCallback onDismiss,
    );

/// Keeps long message edits local to visible lines instead of reshaping one
/// paragraph containing the whole document after every keystroke.
class LongMessageEditor extends StatefulWidget {
  const LongMessageEditor({
    super.key,
    required this.controller,
    required this.decoration,
    this.scrollController,
    this.autofocus = false,
    this.focusNode,
    this.style,
    this.cursorColor,
    this.minLines = 8,
    this.maxLines,
    this.expands = false,
    this.readOnly = false,
    this.onChanged,
    this.onSubmitted,
    this.onKeyEvent,
    this.textInputAction = TextInputAction.newline,
    this.contentInsertionConfiguration,
    this.contextMenuBuilder,
  });

  final TextEditingController controller;
  final InputDecoration decoration;
  final ScrollController? scrollController;
  final bool autofocus;
  final FocusNode? focusNode;
  final TextStyle? style;
  final Color? cursorColor;
  final int? minLines;
  final int? maxLines;
  final bool expands;
  final bool readOnly;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final FocusOnKeyEventCallback? onKeyEvent;
  final TextInputAction textInputAction;
  final ContentInsertionConfiguration? contentInsertionConfiguration;
  final LongMessageContextMenuBuilder? contextMenuBuilder;

  @override
  State<LongMessageEditor> createState() => LongMessageEditorState();
}

class LongMessageEditorState extends State<LongMessageEditor>
    with UndoManagerClient {
  // Leave headroom for the rest of the real home screen at 120 Hz: even a
  // 3,800-character paragraph approached its frame budget on the test phone.
  static const _threshold = 2048;
  // The line editor lays out LTR lines. Keep Flutter's bidi and accessibility
  // editing paths, and preserve documents with non-LF line separators verbatim.
  static final _requiresParagraph = RegExp(
    r'[\r\u0590-\u08ff\u200e-\u200f\u2028-\u202e\u2066-\u2069\ufb1d-\ufdff\ufe70-\ufeff\ud802-\ud803\ud83b]',
  );

  late FocusNode _focus;
  final _vertical = ScrollController();
  final _horizontal = ScrollController();
  CodeLineEditingController? _lineController;
  late CodeScrollController _scroll;
  bool _mirroring = false;
  late String _text;
  List<int>? _lineStarts;
  CodeLines? _lastLines;
  bool _long = false;
  bool? _renderingLines;
  final _undoController = UndoHistoryController();
  BuildContext? _undoContext;
  late final _toolbar = _MessageSelectionToolbarController(
    builder: _buildSelectionToolbar,
  );

  @override
  void initState() {
    super.initState();
    _text = widget.controller.text;
    _long = _supportsLineEditing(_text);
    _focus = widget.focusNode ?? FocusNode();
    _scroll = _makeScrollController();
    widget.controller.addListener(_copyFromTextController);
    _focus.addListener(_onFocusChanged);
    _undoController.addListener(_updatePlatformUndoState);
  }

  CodeLineEditingController get _lines => _lineController ??= _createLines();

  CodeLineEditingController _createLines() {
    final lines = CodeLineEditingController(
      options: const CodeLineOptions(plainText: true),
      codeLines: CodeLines.fromText(_text),
      spanBuilder:
          ({
            required context,
            required index,
            required codeLine,
            required textSpan,
            required style,
          }) {
            final composing = _lineController?.composing ?? TextRange.empty;
            if (index == _lineController?.selection.extentIndex &&
                composing.isValid &&
                !composing.isCollapsed &&
                composing.end <= codeLine.text.length) {
              return TextSpan(
                style: _scaledStyle(context),
                children: [
                  TextSpan(text: codeLine.text.substring(0, composing.start)),
                  TextSpan(
                    text: codeLine.text.substring(
                      composing.start,
                      composing.end,
                    ),
                    style: const TextStyle(
                      decoration: TextDecoration.underline,
                    ),
                  ),
                  TextSpan(text: codeLine.text.substring(composing.end)),
                ],
              );
            }
            return TextSpan(
              text: textSpan.text,
              children: textSpan.children,
              style: _scaledStyle(context),
            );
          },
    );
    final current = widget.controller.selection;
    final selection = current.isValid
        ? current
        : TextSelection.collapsed(offset: _text.length);
    final base = _linePosition(selection.baseOffset);
    final extent = _linePosition(selection.extentOffset);
    lines.selection = CodeLineSelection(
      baseIndex: base.index,
      baseOffset: base.offset,
      extentIndex: extent.index,
      extentOffset: extent.offset,
      baseAffinity: selection.affinity,
      extentAffinity: selection.affinity,
    );
    lines.composing = _lineComposing(widget.controller.value);
    _lastLines = lines.codeLines;
    lines.addListener(_copyToTextController);
    return lines;
  }

  bool _supportsLineEditing(String text) =>
      text.length >= _threshold && !_requiresParagraph.hasMatch(text);

  bool _supportsChangedLines(CodeLines previous, CodeLines next) {
    // Each untouched line is already known to be LTR/LF. The library uses
    // copy-on-write segments, so checking a keystroke need not scan the history.
    for (var index = 0; index < next.segments.length; index++) {
      final lines = next.segments[index].codeLines;
      final old = index < previous.segments.length
          ? previous.segments[index].codeLines
          : null;
      if (identical(lines, old)) continue;
      for (var line = 0; line < lines.length; line++) {
        if (old != null &&
            line < old.length &&
            identical(lines[line], old[line])) {
          continue;
        }
        if (_requiresParagraph.hasMatch(lines[line].text)) return false;
      }
    }
    return true;
  }

  bool get usesLineEditor => _renderingLines == true;

  TextStyle _scaledStyle(BuildContext context) {
    final style = Theme.of(context).textTheme.bodyLarge!.merge(widget.style);
    return style.copyWith(
      fontSize: MediaQuery.textScalerOf(context).scale(style.fontSize!),
    );
  }

  double get preferredLineHeight {
    final painter = TextPainter(
      text: TextSpan(text: ' ', style: _scaledStyle(context)),
      textDirection: TextDirection.ltr,
    )..layout();
    final height = painter.preferredLineHeight;
    painter.dispose();
    return height;
  }

  void ensureCaretVisible() {
    if (usesLineEditor) _lineController?.makeCursorVisible();
  }

  void hideToolbar() => _toolbar.hide(context);

  CodeScrollController _makeScrollController() => CodeScrollController(
    verticalScroller: widget.scrollController ?? _vertical,
    horizontalScroller: _horizontal,
  );

  @override
  void didUpdateWidget(LongMessageEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      _focus.removeListener(_onFocusChanged);
      if (oldWidget.focusNode == null) _focus.dispose();
      _focus = widget.focusNode ?? FocusNode();
      _focus.addListener(_onFocusChanged);
    }
    if (oldWidget.controller != widget.controller) {
      _undoController.value = UndoHistoryValue.empty;
      oldWidget.controller.removeListener(_copyFromTextController);
      widget.controller.addListener(_copyFromTextController);
      _copyFromTextController();
    }
    if (oldWidget.scrollController != widget.scrollController) {
      _scroll.dispose();
      _scroll = _makeScrollController();
    }
    if (oldWidget.readOnly != widget.readOnly) _updatePlatformUndoState();
  }

  void _onFocusChanged() {
    if (_focus.hasFocus && !widget.controller.selection.isValid) {
      // Match EditableText's initial focus behavior for an unset selection.
      widget.controller.selection = TextSelection.collapsed(
        offset: _text.length,
      );
    }
    if (mounted) setState(() {});
    _schedulePlatformUndoClient();
  }

  // Both renderers share Flutter's undo coalescing and the same document
  // history. The history widget stays mounted across a size/bidi transition.
  @override
  bool get canUndo => !widget.readOnly && _undoController.value.canUndo;

  @override
  bool get canRedo => !widget.readOnly && _undoController.value.canRedo;

  @override
  void undo() {
    if (!widget.readOnly && _undoContext != null) {
      Actions.invoke(
        _undoContext!,
        const UndoTextIntent(SelectionChangedCause.keyboard),
      );
    }
  }

  @override
  void redo() {
    if (!widget.readOnly && _undoContext != null) {
      Actions.invoke(
        _undoContext!,
        const RedoTextIntent(SelectionChangedCause.keyboard),
      );
    }
  }

  @override
  void handlePlatformUndo(UndoDirection direction) {
    switch (direction) {
      case UndoDirection.undo:
        undo();
      case UndoDirection.redo:
        redo();
    }
  }

  void _updatePlatformUndoState() {
    if (defaultTargetPlatform == TargetPlatform.iOS &&
        UndoManager.client == this) {
      UndoManager.setUndoState(canUndo: canUndo, canRedo: canRedo);
    }
  }

  void _schedulePlatformUndoClient() {
    if (defaultTargetPlatform != TargetPlatform.iOS) return;
    // EditableText installs its own platform client when mounted/focused.
    // Route native iOS gestures to the persistent history after that happens.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_focus.hasFocus) {
        UndoManager.client = this;
        _updatePlatformUndoState();
      } else if (UndoManager.client == this) {
        UndoManager.client = null;
      }
    });
  }

  void _replaceText(String text) {
    if (identical(_text, text)) return;
    _text = text;
    _lineStarts = null;
  }

  List<int> get _starts => _lineStarts ??= () {
    final starts = <int>[0];
    var next = _text.indexOf('\n');
    while (next >= 0) {
      starts.add(next + 1);
      next = _text.indexOf('\n', next + 1);
    }
    return starts;
  }();

  CodeLinePosition _linePosition(int offset) {
    offset = offset.clamp(0, _text.length);
    final starts = _starts;
    var low = 0;
    var high = starts.length;
    while (low + 1 < high) {
      final middle = (low + high) ~/ 2;
      if (starts[middle] <= offset) {
        low = middle;
      } else {
        high = middle;
      }
    }
    return CodeLinePosition(index: low, offset: offset - starts[low]);
  }

  int _textOffset(CodeLinePosition position) =>
      _starts[position.index] + position.offset;

  TextRange _lineComposing(TextEditingValue value) {
    if (!value.composing.isValid) return TextRange.empty;
    final start = _linePosition(value.composing.start);
    final end = _linePosition(value.composing.end);
    return start.index == end.index
        ? TextRange(start: start.offset, end: end.offset)
        : TextRange.empty;
  }

  void _copyFromTextController() {
    if (_mirroring) return;
    final value = widget.controller.value;
    final textChanged = !identical(_text, value.text);
    _replaceText(value.text);
    final nextLong = textChanged ? _supportsLineEditing(value.text) : _long;
    final changedMode = _long != nextLong;
    _long = nextLong;
    if (_lineController == null) {
      if (changedMode && mounted) setState(() {});
      return;
    }
    _mirroring = true;
    try {
      final selection = value.selection.isValid
          ? value.selection
          : TextSelection.collapsed(offset: value.text.length);
      if (!value.selection.isValid && _focus.hasFocus) {
        widget.controller.selection = selection;
      }
      final base = _linePosition(selection.baseOffset);
      final extent = _linePosition(selection.extentOffset);
      _lines.value = CodeLineEditingValue(
        codeLines: textChanged
            ? CodeLines.fromText(value.text)
            : _lines.codeLines,
        selection: CodeLineSelection(
          baseIndex: base.index,
          baseOffset: base.offset,
          extentIndex: extent.index,
          extentOffset: extent.offset,
          baseAffinity: selection.affinity,
          extentAffinity: selection.affinity,
        ),
        composing: _lineComposing(value),
      );
      _lastLines = _lines.codeLines;
    } finally {
      _mirroring = false;
    }
    if (changedMode && mounted) setState(() {});
  }

  void _copyToTextController() {
    if (_mirroring) return;
    var textChanged = false;
    var nextLong = _long;
    _mirroring = true;
    try {
      if (!identical(_lastLines, _lines.codeLines)) {
        final previous = _lastLines;
        final nextText = _lines.codeLines.asString(TextLineBreak.lf, false);
        textChanged = _text != nextText;
        _replaceText(nextText);
        nextLong =
            _text.length >= _threshold &&
            (_long && previous != null
                ? _supportsChangedLines(previous, _lines.codeLines)
                : !_requiresParagraph.hasMatch(_text));
        _lastLines = _lines.codeLines;
      }
      final selection = _lines.selection;
      final composing = _lines.composing;
      widget.controller.value = TextEditingValue(
        text: _text,
        composing: composing.isValid
            ? TextRange(
                start: _textOffset(
                  CodeLinePosition(
                    index: selection.extentIndex,
                    offset: composing.start,
                  ),
                ),
                end: _textOffset(
                  CodeLinePosition(
                    index: selection.extentIndex,
                    offset: composing.end,
                  ),
                ),
              )
            : TextRange.empty,
        selection: TextSelection(
          baseOffset: _textOffset(
            CodeLinePosition(
              index: selection.baseIndex,
              offset: selection.baseOffset,
            ),
          ),
          extentOffset: _textOffset(
            CodeLinePosition(
              index: selection.extentIndex,
              offset: selection.extentOffset,
            ),
          ),
          affinity: selection.extentAffinity,
        ),
      );
    } finally {
      _mirroring = false;
    }
    if (_long != nextLong && mounted) setState(() => _long = nextLong);
    if (textChanged) widget.onChanged?.call(_text);
  }

  @override
  void dispose() {
    _toolbar.hide(context);
    if (UndoManager.client == this) UndoManager.client = null;
    _undoController.dispose();
    widget.controller.removeListener(_copyFromTextController);
    _lineController?.removeListener(_copyToTextController);
    _lineController?.dispose();
    _scroll.dispose();
    _vertical.dispose();
    _horizontal.dispose();
    _focus.removeListener(_onFocusChanged);
    if (widget.focusNode == null) _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return UndoHistory<TextEditingValue>(
      key: ValueKey(widget.controller),
      value: widget.controller,
      focusNode: _focus,
      controller: _undoController,
      shouldChangeUndoStack: (previous, next) {
        if (!next.selection.isValid) return false;
        if (previous == null) return true;
        if (defaultTargetPlatform != TargetPlatform.android &&
            !next.composing.isCollapsed) {
          return false;
        }
        return previous.text != next.text ||
            previous.composing != next.composing;
      },
      undoStackModifier: (value) => value.copyWith(composing: TextRange.empty),
      onTriggered: (value) {
        final changed = widget.controller.text != value.text;
        widget.controller.value = value;
        if (changed) widget.onChanged?.call(value.text);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) ensureCaretVisible();
        });
      },
      child: Builder(
        builder: (context) {
          _undoContext = context;
          return Actions(
            actions: {
              UndoTextIntent: CallbackAction<UndoTextIntent>(
                onInvoke: (_) => undo(),
              ),
              RedoTextIntent: CallbackAction<RedoTextIntent>(
                onInvoke: (_) => redo(),
              ),
            },
            child: _buildEditor(context),
          );
        },
      ),
    );
  }

  Widget _buildSelectionToolbar({
    required BuildContext context,
    required TextSelectionToolbarAnchors anchors,
    required CodeLineEditingController controller,
    required VoidCallback onDismiss,
    required VoidCallback onRefresh,
  }) {
    final selected = !controller.selection.isCollapsed;
    final items = <ContextMenuButtonItem>[
      if (selected && !widget.readOnly)
        ContextMenuButtonItem(
          type: ContextMenuButtonType.cut,
          onPressed: () {
            controller.cut();
            onDismiss();
          },
        ),
      if (selected)
        ContextMenuButtonItem(
          type: ContextMenuButtonType.copy,
          onPressed: () {
            controller.copy();
            onDismiss();
          },
        ),
      if (!widget.readOnly)
        ContextMenuButtonItem(
          type: ContextMenuButtonType.paste,
          onPressed: () {
            controller.paste();
            onDismiss();
          },
        ),
      ContextMenuButtonItem(
        type: ContextMenuButtonType.selectAll,
        onPressed: () {
          controller.selectAll();
          onRefresh();
        },
      ),
    ];
    return widget.contextMenuBuilder?.call(
          context,
          anchors,
          items,
          onDismiss,
        ) ??
        AdaptiveTextSelectionToolbar.buttonItems(
          anchors: anchors,
          buttonItems: items,
        );
  }

  Widget _buildEditor(BuildContext context) {
    final renderingLines =
        _long &&
        !MediaQuery.accessibleNavigationOf(context) &&
        Directionality.of(context) != TextDirection.rtl;
    if (_renderingLines != null &&
        _renderingLines != renderingLines &&
        _focus.hasFocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final primary = FocusManager.instance.primaryFocus;
        if (_focus.hasFocus || primary == null || primary is FocusScopeNode) {
          _focus.requestFocus();
          if (_renderingLines == true) _lineController?.makeCursorVisible();
        }
      });
    }
    if (_renderingLines != renderingLines) _schedulePlatformUndoClient();
    _renderingLines = renderingLines;
    if (!renderingLines) {
      return RepaintBoundary(
        child: TextField(
          controller: widget.controller,
          focusNode: _focus,
          scrollController: widget.scrollController,
          autofocus: widget.autofocus,
          keyboardType: TextInputType.multiline,
          minLines: widget.minLines,
          maxLines: widget.maxLines,
          expands: widget.expands,
          readOnly: widget.readOnly,
          onChanged: widget.onChanged,
          onSubmitted: widget.onSubmitted,
          style: widget.style,
          cursorColor: widget.cursorColor,
          textInputAction: widget.textInputAction,
          contentInsertionConfiguration: widget.contentInsertionConfiguration,
          contextMenuBuilder: (context, state) =>
              widget.contextMenuBuilder?.call(
                context,
                state.contextMenuAnchors,
                state.contextMenuButtonItems,
                state.hideToolbar,
              ) ??
              AdaptiveTextSelectionToolbar.editableText(
                editableTextState: state,
              ),
          decoration: widget.decoration,
        ),
      );
    }
    final theme = Theme.of(context);
    final style = _scaledStyle(context);
    final editor = NotificationListener<ScrollNotification>(
      // An editor's internal scrolling must not tint the surrounding AppBar.
      onNotification: (_) => true,
      child: InputDecorator(
        decoration: widget.decoration,
        isFocused: _focus.hasFocus,
        child: RepaintBoundary(
          child: CodeEditor(
            controller: _lines,
            focusNode: _focus,
            autofocus: widget.autofocus,
            readOnly: widget.readOnly,
            showCursorWhenReadOnly: false,
            onSubmitted: widget.onSubmitted,
            onKeyEvent: widget.onKeyEvent,
            textInputAction: widget.textInputAction,
            contentInsertionConfiguration: widget.contentInsertionConfiguration,
            scrollController: _scroll,
            wordWrap: true,
            autocompleteSymbols: false,
            shortcutsActivatorsBuilder: const _PlainMessageShortcuts(),
            chunkAnalyzer: const NonCodeChunkAnalyzer(),
            maxLengthSingleLineRendering: 1 << 30,
            padding: EdgeInsets.zero,
            margin: EdgeInsets.zero,
            scrollbarBuilder: (_, child, _) => child,
            style: CodeEditorStyle(
              fontSize: style.fontSize,
              fontFamily: style.fontFamily,
              fontFamilyFallback: style.fontFamilyFallback,
              fontHeight: style.height,
              textColor: style.color,
              cursorColor: widget.cursorColor ?? theme.colorScheme.primary,
              selectionColor: theme.textSelectionTheme.selectionColor,
              cursorLineColor: Colors.transparent,
            ),
            toolbarController: _toolbar,
          ),
        ),
      ),
    );
    // Keep the editor mounted when the composer expands or collapses, retaining
    // its native input connection, selection and render-controller bindings.
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: widget.maxLines == null
            ? double.infinity
            : preferredLineHeight * widget.maxLines! +
                  (widget.decoration.contentPadding?.vertical ?? 0),
      ),
      child: editor,
    );
  }
}

class _PlainMessageShortcuts extends DefaultCodeShortcutsActivatorsBuilder {
  const _PlainMessageShortcuts();

  @override
  List<ShortcutActivator>? build(CodeShortcutType type) => switch (type) {
    CodeShortcutType.undo ||
    CodeShortcutType.redo ||
    CodeShortcutType.indent ||
    CodeShortcutType.outdent ||
    CodeShortcutType.lineMoveUp ||
    CodeShortcutType.lineMoveDown ||
    CodeShortcutType.singleLineComment ||
    CodeShortcutType.multiLineComment => const [],
    _ => super.build(type),
  };
}

// Mobile anchors follow the render layer; desktop secondary-click anchors are
// already in screen coordinates and have no renderRect.
class _MessageSelectionToolbarController implements SelectionToolbarController {
  _MessageSelectionToolbarController({required this.builder});

  final ToolbarMenuBuilder builder;
  final _desktop = ContextMenuController();
  late final _mobile = MobileSelectionToolbarController(builder: builder);

  @override
  void hide(BuildContext context) {
    _desktop.remove();
    _mobile.hide(context);
  }

  @override
  void show({
    required BuildContext context,
    required CodeLineEditingController controller,
    required TextSelectionToolbarAnchors anchors,
    Rect? renderRect,
    required LayerLink layerLink,
    required ValueNotifier<bool> visibility,
  }) {
    hide(context);
    if (renderRect != null) {
      _mobile.show(
        context: context,
        controller: controller,
        anchors: anchors,
        renderRect: renderRect,
        layerLink: layerLink,
        visibility: visibility,
      );
      return;
    }
    _desktop.show(
      context: context,
      contextMenuBuilder: (_) => CodeEditorTapRegion(
        child: builder(
          context: context,
          anchors: anchors,
          controller: controller,
          onDismiss: () => hide(context),
          onRefresh: () => show(
            context: context,
            controller: controller,
            anchors: anchors,
            layerLink: layerLink,
            visibility: visibility,
          ),
        ),
      ),
    );
  }
}
