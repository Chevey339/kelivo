part of 're_editor.dart';

/// An immutable style describing how to format and paint editor content.
class CodeEditorStyle {

  /// Creates a code editor style.
  const CodeEditorStyle({
    this.fontSize,
    this.fontFamily,
    this.fontFamilyFallback,
    this.fontHeight,
    this.textColor,
    this.hintTextColor,
    this.backgroundColor,
    this.selectionColor,
    this.highlightColor,
    this.cursorColor,
    this.cursorWidth,
    this.cursorLineColor,
    this.chunkIndicatorColor,
    this.codeTheme,
  }) : assert(fontSize == null || fontSize > 0),
    assert(fontHeight == null || fontHeight >= 1.0),
    assert(cursorWidth == null || cursorWidth > 0);

  /// The size of fonts (in logical pixels) to use when painting the text.
  ///
  /// The value specified matches the dimension of the
  /// [em square](https://fonts.google.com/knowledge/glossary/em) of the
  /// underlying font, and more often then not isn't exactly the height or the
  /// width of glyphs in the font.
  ///
  /// Default value is 13.0 pixels.
  final double? fontSize;

  /// The name of the font to use when painting the text (e.g., Roboto).
  ///
  /// If the font is defined in a package, this will be prefixed with
  /// 'packages/package_name/' (e.g. 'packages/cool_fonts/Roboto'). The
  /// prefixing is done by the constructor when the `package` argument is
  /// provided.
  ///
  /// The value provided in [fontFamily] will act as the preferred/first font
  /// family that glyphs are looked for in, followed in order by the font families
  /// in [fontFamilyFallback]. When [fontFamily] is null or not provided, the
  /// first value in [fontFamilyFallback] acts as the preferred/first font
  /// family. When neither is provided, then the default platform font will
  /// be used.
  final String? fontFamily;

  /// The ordered list of font families to fall back on when a glyph cannot be
  /// found in a higher priority font family.
  ///
  /// The value provided in [fontFamily] will act as the preferred/first font
  /// family that glyphs are looked for in, followed in order by the font families
  /// in [fontFamilyFallback]. If all font families are exhausted and no match
  /// was found, the default platform font family will be used instead.
  ///
  /// When [fontFamily] is null or not provided, the first value in [fontFamilyFallback]
  /// acts as the preferred/first font family. When neither is provided, then
  /// the default platform font will be used. Providing an empty list or null
  /// for this property is the same as omitting it.
  ///
  /// For example, if a glyph is not found in [fontFamily], then each font family
  /// in [fontFamilyFallback] will be searched in order until it is found. If it
  /// is not found, then a box will be drawn in its place.
  ///
  /// If the font is defined in a package, each font family in the list will be
  /// prefixed with 'packages/package_name/' (e.g. 'packages/cool_fonts/Roboto').
  /// The package name should be provided by the `package` argument in the
  /// constructor.
  final List<String>? fontFamilyFallback;

  /// The height of this text span, as a multiple of the font size.
  ///
  /// When [fontHeight] is null or omitted, the line height will be determined
  /// by the font's metrics directly, which may differ from the fontSize.
  /// When [fontHeight] is non-null, the line height of the span of text will be a
  /// multiple of [fontSize] and be exactly `fontSize * height` logical pixels
  /// tall.
  ///
  /// For most fonts, setting [fontHeight] to 1.0 is not the same as omitting or
  /// setting height to null because the [fontSize] sets the height of the EM-square,
  /// which is different than the font provided metrics for line height. The
  /// following diagram illustrates the difference between the font-metrics
  /// defined line height and the line height produced with `height: 1.0`
  /// (which forms the upper and lower edges of the EM-square):
  ///
  /// See [StrutStyle] and [TextHeightBehavior] for further control of line
  /// height at the paragraph level.
  final double? fontHeight;

  /// The color to use when painting the text.
  ///
  /// The [textColor] property is shorthand for `Paint()..color = color`.
  final Color? textColor;

  /// The color to use when painting the hint text.
  ///
  /// The [hintTextColor] property is shorthand for `Paint()..color = color`.
  final Color? hintTextColor;

  /// The color to use as the background for the editor.
  ///
  /// Note, this is not the text background color.
  final Color? backgroundColor;

  /// The color to use as the background for the selected text.
  ///
  /// The paint layer is under [highlightColor].
  final Color? selectionColor;

  /// The color to use as the background for the highlighted text, such as
  /// the search matched text.
  ///
  /// The paint layer is above [selectionColor].
  final Color? highlightColor;

  /// The color of the cursor.
  ///
  /// The cursor indicates the current location of text insertion point in
  /// the field.
  ///
  /// If this is null it will default to the ambient
  /// [DefaultSelectionStyle.cursorColor]. If that is null, and the
  /// [ThemeData.platform] is [TargetPlatform.iOS] or [TargetPlatform.macOS]
  /// it will use [CupertinoThemeData.primaryColor]. Otherwise it will use
  /// the value of [ColorScheme.primary] of [ThemeData.colorScheme].
  final Color? cursorColor;

  /// How thick the cursor will be.
  ///
  /// Defaults to 2.0.
  ///
  /// The cursor will draw under the text. The cursor width will extend
  /// to the right of the boundary between characters for left-to-right text
  /// and to the left for right-to-left text. This corresponds to extending
  /// downstream relative to the selected position. Negative values may be used
  /// to reverse this behavior.
  final double? cursorWidth;

  /// The color to use as the border for the focused line.
  final Color? cursorLineColor;

  /// The color of the chunked indicator at the end of the line.
  final Color? chunkIndicatorColor;

  /// The code syntax highlighting rules and styles.
  final CodeHighlightTheme? codeTheme;

}

/// Creates a code editor.
///
/// You can freely define the styles of the editor, such as text style,
/// line number view, search view, scroll bar, etc.
///
/// Similar to [TextField], editor uses [CodeLineEditingController] as the content controller.
/// You can create a controller using the following code.
///
/// ```dart
/// final controller = CodeLineEditingController.fromText('Hello World');
/// ```
/// or
/// ```dart
/// final controller = CodeLineEditingController.fromFile('/Users/megatronking/hello.py');
/// ```
///
/// If [wordWrap] mode is turned off, the editor will support both horizontal and vertical scrolling,
/// and you can use [CodeScrollController] to control the scrolling.
///
/// You can use [CodeFindBuilder] to create search widget and use [CodeFindController] to control the widget and
/// search actions.
///
/// The editor has many built-in shortcut key actions. If you need to customize shortcut keys, you can use
/// [shortcutsActivatorsBuilder] or [shortcutOverrideActions]. By default, the editor will use [DefaultCodeShortcutsActivatorsBuilder].
///
/// Regarding code folding, you can write a custom code folding analyzer with [chunkAnalyzer].
/// By default, the editor will use [DefaultCodeChunkAnalyzer]. This works for some commonly used languages,
/// but may not work for some languages (such as python).
class CodeEditor extends StatefulWidget {

  const CodeEditor({
    super.key,
    this.controller,
    this.scrollController,
    this.findController,
    this.toolbarController,
    this.onChanged,
    this.onSubmitted,
    this.onKeyEvent,
    this.textInputAction = TextInputAction.newline,
    this.contentInsertionConfiguration,
    this.style,
    this.hint,
    this.padding,
    this.margin,
    this.indicatorBuilder,
    this.scrollbarBuilder,
    this.verticalScrollbarWidth,
    this.horizontalScrollbarHeight,
    this.findBuilder,
    this.shortcutsActivatorsBuilder,
    this.shortcutOverrideActions,
    this.leadingDivider,
    this.border,
    this.borderRadius,
    this.clipBehavior = Clip.none,
    this.readOnly,
    this.showCursorWhenReadOnly,
    this.wordWrap,
    this.autocompleteSymbols,
    this.autofocus,
    this.focusNode,
    this.maxLengthSingleLineRendering,
    this.chunkAnalyzer,
    this.commentFormatter,
  }) : assert(indicatorBuilder != null || (indicatorBuilder == null && leadingDivider == null));

  /// Similar to [TextField], editor uses [CodeLineEditingController] as the content controller.
  final CodeLineEditingController? controller;

  /// Controls horizontal and vertical scrolling.
  final CodeScrollController? scrollController;

  /// Controls the search widget and actions.
  final CodeFindController? findController;

  /// Controls the selection toolbar.
  final SelectionToolbarController? toolbarController;

  /// Called when the user initiates a change to the editor's
  /// value was changed, such as insertion or deletion.
  ///
  /// Same as [CodeLineEditingController.addListener].
  final ValueChanged<CodeLineEditingValue>? onChanged;

  /// Plain message input may submit, handle app shortcuts or accept IME media.
  final ValueChanged<String>? onSubmitted;
  final FocusOnKeyEventCallback? onKeyEvent;
  final TextInputAction textInputAction;
  final ContentInsertionConfiguration? contentInsertionConfiguration;

  /// The style to use for the editor.
  final CodeEditorStyle? style;

  /// Text that suggests what sort of input the field accepts.
  final String? hint;

  /// The padding of the editor field, excludes the addtional wdigets like line number widget.
  final EdgeInsetsGeometry? padding;

  /// The margin value of the whole editor, includes the addtional wdigets like line number widget.
  final EdgeInsetsGeometry? margin;

  /// Use this to build your own indicator widget like line number widget.
  /// See [DefaultCodeLineNumber] and [DefaultCodeChunkIndicator].
  final CodeIndicatorBuilder? indicatorBuilder;

  /// Use this to build your own scroll bar widget.
  final CodeScrollbarBuilder? scrollbarBuilder;

  /// The width of the vertical scrollbar.
  final double? verticalScrollbarWidth;

  /// The height of the horizontal scrollbar.
  final double? horizontalScrollbarHeight;

  /// Use this to build your own search widget.
  /// The search widget will appear on the top of editor field.
  final CodeFindBuilder? findBuilder;

  /// Customize your shortcut keys.
  final CodeShortcutsActivatorsBuilder? shortcutsActivatorsBuilder;

  /// Override built-in shortcut key actions.
  final Map<Type, Action<Intent>>? shortcutOverrideActions;

  /// A leadingDivider widget between indicator and editor field.
  final Widget? leadingDivider;

  /// The border of the editor.
  final Border? border;

  /// The radius of the editor's border corners.
  ///
  /// This defines how rounded the corners of the editor's border will appear.
  ///
  /// If null, the corners will not be rounded.
  final BorderRadius? borderRadius;


  /// How the content should be clipped if it overflows the editor's bounds.
  final Clip clipBehavior;

  /// Whether the text can be changed.
  ///
  /// When this is set to true, the text cannot be modified
  /// by any shortcut or keyboard operation. The text is still selectable.
  ///
  /// Defaults to false.
  final bool? readOnly;

  /// Whether to show cursor when in readonly mode.
  ///
  /// The cursor refers to the blinking caret when the editor is focused.
  final bool? showCursorWhenReadOnly;

  /// Should wrap the word.
  final bool? wordWrap;

  /// When entering a closed symbol, should the other half be automatically completed.
  /// For example, when entering a double quote, the other half will be automatically added.
  /// Defaults to true.
  final bool? autocompleteSymbols;

  /// Whether this editor field should focus itself if nothing else is already
  /// focused.
  ///
  /// If true, the keyboard will open as soon as this text field obtains focus.
  /// Otherwise, the keyboard is only shown after the user taps the editor field.
  ///
  /// Defaults to false.
  final bool? autofocus;

  /// Controls whether this widget has keyboard focus.
  final FocusNode? focusNode;

  /// The maximum number of characters per line to render.
  ///
  /// Due to the performance limitations of the Skia text engine,
  /// setting a reasonable length can improve the performance of the editor.
  ///
  /// If null, there is no limit.
  final int? maxLengthSingleLineRendering;

  /// Decide which parts of code can be folded.
  ///
  /// Defaults to [DefaultCodeChunkAnalyzer].
  ///
  /// If you wish to turn off code folding, you can use [NonCodeChunkAnalyzer].
  final CodeChunkAnalyzer? chunkAnalyzer;

  /// Control how one or more lines of code are commented.
  final CodeCommentFormatter? commentFormatter;

  @override
  State<StatefulWidget> createState() => _CodeEditorState();

}

class _CodeEditorState extends State<CodeEditor> {

  late final GlobalKey _editorKey;
  late FocusNode _focusNode;
  late _CodeLineEditingControllerDelegate _editingController;
  late final _CodeInputController _inputController;
  late final _CodeFloatingCursorController _floatingCursorController;
  late CodeScrollController _scrollController;
  late CodeFindController _findController;
  late CodeChunkController _chunkController;

  final LayerLink _startHandleLayerLink = LayerLink();
  final LayerLink _endHandleLayerLink = LayerLink();
  final LayerLink _toolbarLayerLink = LayerLink();
  final ValueNotifier<bool> _effectiveToolbarVisibility = ValueNotifier<bool>(true);

  late _SelectionOverlayController _selectionOverlayController;

  @override
  void initState() {
    super.initState();
    _editorKey = GlobalKey();
    _focusNode = widget.focusNode ?? FocusNode();
    _editingController = _CodeLineEditingControllerDelegate();
    _editingController.delegate =  widget.controller ?? CodeLineEditingController();
    _editingController.bindEditor(_editorKey);

    _floatingCursorController = _CodeFloatingCursorController();

    _inputController = _CodeInputController(
      controller: _editingController,
      floatingCursorController: _floatingCursorController,
      focusNode: _focusNode,
      readOnly: widget.readOnly ?? false,
      autocompleteSymbols: widget.autocompleteSymbols ?? true,
      inputAction: widget.textInputAction,
      onSubmitted: widget.onSubmitted,
      contentInsertionConfiguration: widget.contentInsertionConfiguration,
    );
    _inputController.bindEditor(_editorKey);
    // A message editor can replace a TextField while reusing its focused node.
    // In that case no new focus event arrives to attach the input connection.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _focusNode.hasFocus) _inputController.ensureInput();
    });

    _findController = widget.findController ?? CodeFindController(_editingController);
    _findController.addListener(_updateWidget);
    _scrollController = widget.scrollController ?? CodeScrollController();
    _scrollController.bindEditor(_editorKey);
    _chunkController = CodeChunkController(_editingController, widget.chunkAnalyzer ?? const DefaultCodeChunkAnalyzer());

    _selectionOverlayController = kIsAndroid || kIsIOS ? _MobileSelectionOverlayController(
      context: context,
      controller: _editingController,
      editorKey: _editorKey,
      startHandleLayerLink: _startHandleLayerLink,
      endHandleLayerLink: _endHandleLayerLink,
      toolbarVisibility: _effectiveToolbarVisibility,
      focusNode: _focusNode,
      onShowToolbar: (context, anchors, renderRect) {
        widget.toolbarController?.show(
          context: _editorKey.currentContext ?? context,
          controller: _editingController,
          anchors: anchors,
          renderRect: renderRect,
          layerLink: _toolbarLayerLink,
          visibility: _effectiveToolbarVisibility,
        );
      },
      onHideToolbar: () {
        widget.toolbarController?.hide(context);
      },
    ) : _DesktopSelectionOverlayController(
      onShowToolbar: (context, anchors, renderRect) {
        widget.toolbarController?.show(
          context: context,
          controller: _editingController,
          anchors: anchors,
          renderRect: renderRect,
          layerLink: _toolbarLayerLink,
          visibility: _effectiveToolbarVisibility,
        );
      },
      onHideToolbar: () {
        widget.toolbarController?.hide(context);
      },
    );
  }

  @override
  void dispose() {
    _findController.removeListener(_updateWidget);
    if (widget.focusNode == null) {
      _focusNode.dispose();
    }
    if (widget.controller == null) {
      _editingController.dispose();
    }
    _inputController.dispose();
    if (widget.findController == null) {
      _findController.dispose();
    }
    if (widget.scrollController== null) {
      _scrollController.dispose();
    }
    _chunkController.dispose();
    _selectionOverlayController.dispose();
    _floatingCursorController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant CodeEditor oldWidget) {
    if (oldWidget.focusNode != widget.focusNode) {
      if (oldWidget.focusNode == null) {
        _focusNode.dispose();
      }
      _focusNode = widget.focusNode ?? FocusNode();
      _inputController.focusNode = _focusNode;
    }
    if (oldWidget.controller != widget.controller) {
      if (oldWidget.controller == null) {
        _editingController.dispose();
      }
      _editingController.delegate = widget.controller ?? CodeLineEditingController();
      _editingController.bindEditor(_editorKey);
    }
    if (oldWidget.findController != widget.findController || oldWidget.controller != widget.controller) {
      final CodeFindController oldFindController = _findController;
      if (oldWidget.findController == null) {
        oldFindController.dispose();
      } else {
        oldFindController.removeListener(_updateWidget);
      }
      _findController = widget.findController ?? CodeFindController(_editingController);
      _findController.addListener(_updateWidget);
    }
    if (oldWidget.scrollController != widget.scrollController) {
      if (oldWidget.scrollController == null) {
        _scrollController.dispose();
      }
      _scrollController = widget.scrollController ?? CodeScrollController();
      _scrollController.bindEditor(_editorKey);
    }
    if (oldWidget.chunkAnalyzer != widget.chunkAnalyzer || oldWidget.controller != widget.controller) {
      _chunkController.dispose();
      _chunkController = CodeChunkController(_editingController, widget.chunkAnalyzer ?? const DefaultCodeChunkAnalyzer());
    }
    if (oldWidget.readOnly != widget.readOnly) {
      _inputController.readOnly = widget.readOnly ?? false;
    }
    if (oldWidget.autocompleteSymbols != widget.autocompleteSymbols) {
      _inputController.autocompleteSymbols = widget.autocompleteSymbols ?? true;
    }
    _inputController.updateConfiguration(
      inputAction: widget.textInputAction,
      onSubmitted: widget.onSubmitted,
      contentInsertionConfiguration: widget.contentInsertionConfiguration,
    );
    super.didUpdateWidget(oldWidget);
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final TextSelectionThemeData selectionTheme = TextSelectionTheme.of(context);
    final TextStyle baseStyle = TextStyle(
      fontSize: widget.style?.fontSize ?? _kDefaultTextSize,
      fontFamily: widget.style?.fontFamily,
      fontFamilyFallback: widget.style?.fontFamilyFallback,
      height: widget.style?.fontHeight ?? _kDefaultFontHeight,
    );
    final bool readOnly = widget.readOnly ?? false;
    final bool autofocus = widget.autofocus ?? true;
    final bool wordWrap = widget.wordWrap ?? true;
    final PreferredSizeWidget? find = widget.findBuilder?.call(context, _findController, readOnly);
    final Widget editable = _CodeEditable(
      editorKey: _editorKey,
      hint: widget.hint,
      indicatorBuilder: widget.indicatorBuilder,
      scrollbarBuilder: widget.scrollbarBuilder,
      verticalScrollbarWidth: widget.verticalScrollbarWidth,
      horizontalScrollbarHeight: widget.horizontalScrollbarHeight,
      textStyle: baseStyle.copyWith(
        color: widget.style?.textColor ?? theme.textTheme.bodyLarge?.color,
      ),
      hintTextColor: widget.style?.hintTextColor,
      backgroundColor: widget.style?.backgroundColor,
      selectionColor: widget.style?.selectionColor ?? selectionTheme.selectionColor ?? theme.colorScheme.primary.withAlpha(102),
      highlightColor: widget.style?.highlightColor ?? selectionTheme.selectionColor ?? theme.colorScheme.primary.withAlpha(102),
      cursorColor:  widget.style?.cursorColor ?? selectionTheme.cursorColor ?? theme.colorScheme.primary,
      cursorLineColor: widget.style?.cursorLineColor,
      chunkIndicatorColor: widget.style?.chunkIndicatorColor,
      cursorWidth: widget.style?.cursorWidth ?? _kDefaultCaretWidth,
      showCursorWhenReadOnly: widget.showCursorWhenReadOnly ?? true,
      leadingDivider: widget.leadingDivider,
      border: widget.border,
      borderRadius: widget.borderRadius,
      clipBehavior: widget.clipBehavior,
      onChanged: widget.onChanged,
      focusNode: _focusNode,
      padding: (widget.padding ?? _kDefaultPadding).add(EdgeInsets.only(
        top: find == null ? 0 : find.preferredSize.height
      )),
      margin:  widget.margin ?? EdgeInsets.zero,
      controller: _editingController,
      inputController: _inputController,
      codeTheme: widget.style?.codeTheme,
      readOnly: readOnly,
      autofocus: autofocus,
      wordWrap: wordWrap,
      maxLengthSingleLineRendering: widget.maxLengthSingleLineRendering,
      findController: _findController,
      scrollController: _scrollController,
      chunkController: _chunkController,
      floatingCursorController: _floatingCursorController,
      startHandleLayerLink: _startHandleLayerLink,
      endHandleLayerLink: _endHandleLayerLink,
      toolbarLayerLink: _toolbarLayerLink,
      selectionOverlayController: _selectionOverlayController,
    );
    final Widget detector = _CodeSelectionGestureDetector(
      controller: _editingController,
      inputController: _inputController,
      chunkController: _chunkController,
      selectionOverlayController: _selectionOverlayController,
      behavior: HitTestBehavior.translucent,
      editorKey: _editorKey,
      child: editable
    );
    final Widget child;
    if (kIsAndroid || kIsIOS) {
      child = Focus(
        autofocus: autofocus,
        focusNode: _focusNode,
        onKeyEvent: (node, event) {
          final KeyEventResult appResult = widget.onKeyEvent?.call(node, event) ?? KeyEventResult.ignored;
          if (appResult != KeyEventResult.ignored) return appResult;
          if (readOnly || (event is! KeyDownEvent && event is! KeyRepeatEvent)) {
            return KeyEventResult.ignored;
          }
          if (event.logicalKey == LogicalKeyboardKey.backspace) {
            _editingController.deleteBackward();
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.enter) {
            _editingController.applyNewLine();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        includeSemantics: false,
        debugLabel: 'CodeEditor',
        child: detector
      );
    } else {
      child = _CodeShortcuts(
        builder: widget.shortcutsActivatorsBuilder ?? const DefaultCodeShortcutsActivatorsBuilder(),
        child: _CodeShortcutActions(
          editingController: _editingController,
          inputController: _inputController,
          findController: find != null ? _findController : null,
          commentFormatter: widget.commentFormatter,
          overrideActions: widget.shortcutOverrideActions,
          readOnly: readOnly,
          child: Focus(
            autofocus: autofocus,
            focusNode: _focusNode,
            onKeyEvent: widget.onKeyEvent,
            includeSemantics: false,
            debugLabel: 'CodeEditor',
            child: detector
          )
        ),
      );
    }
    return Stack(
      children: [
        child,
        if (find != null)
          find,
      ],
    );
  }

  void _updateWidget() {
    setState(() {
    });
  }

}

/// A [TapRegion] that adds its children to the tap region group for widgets
/// based on the [CodeEditor] widget.
///
/// Widgets that are wrapped with a [CodeEditorTapRegion] are considered to be
/// part of the editor for purposes of unfocus behavior. So, when the user
/// taps on them, the currently focused editor won't be unfocused by
/// default.
///
/// See also:
///
///  * [TapRegion], the widget that this widget uses to add widgets to the group
///    of text fields.
class CodeEditorTapRegion extends TapRegion {

  /// Creates a const [CodeEditorTapRegion].
  ///
  /// The [child] field is required.
  const CodeEditorTapRegion({
    super.key,
    required super.child,
    super.enabled = true,
    super.behavior = HitTestBehavior.deferToChild,
    super.onTapOutside,
    super.onTapInside,
  }) : super(groupId: CodeEditor);

}
