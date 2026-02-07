import 'package:flutter/material.dart';
import 'package:re_editor/re_editor.dart';

/// Build a common [CodeEditorStyle] for plain-text editors.
///
/// This centralizes the typical style values used after migrating from
/// `TextField/TextEditingController` to `re_editor`'s `CodeEditor`.
CodeEditorStyle buildPlainTextCodeEditorStyle(
  BuildContext context, {
  double fontSize = 14,
  double fontHeight = 1.4,
  String? fontFamily,
  List<String>? fontFamilyFallback,
  Color? textColor,
  double hintAlpha = 0.5,
  Color? hintTextColor,
  Color? cursorColor,
  double selectionAlpha = 0.3,
  Color? selectionColor,
  Color backgroundColor = Colors.transparent,
}) {
  final cs = Theme.of(context).colorScheme;
  final effectiveTextColor = textColor ?? cs.onSurface;
  final effectiveHintColor =
      hintTextColor ?? effectiveTextColor.withValues(alpha: hintAlpha);
  final effectiveCursorColor = cursorColor ?? cs.primary;
  final effectiveSelectionColor =
      selectionColor ?? cs.primary.withValues(alpha: selectionAlpha);

  return CodeEditorStyle(
    fontSize: fontSize,
    fontFamily: fontFamily,
    fontFamilyFallback: fontFamilyFallback,
    fontHeight: fontHeight,
    textColor: effectiveTextColor,
    hintTextColor: effectiveHintColor,
    cursorColor: effectiveCursorColor,
    backgroundColor: backgroundColor,
    selectionColor: effectiveSelectionColor,
  );
}

/// A thin wrapper around [CodeEditor] for plain-text editing.
///
/// - Hides line numbers/chunk indicators via `indicatorBuilder: null`
/// - Disables code folding/highlighting via [NonCodeChunkAnalyzer]
/// - Applies a consistent theme-based [CodeEditorStyle] (customizable)
class PlainTextCodeEditor extends StatelessWidget {
  const PlainTextCodeEditor({
    super.key,
    required this.controller,
    this.focusNode,
    this.readOnly = false,
    this.autofocus = false,
    this.wordWrap = true,
    this.hint,
    this.padding = const EdgeInsets.all(12),
    this.onChanged,
    this.shortcutsActivatorsBuilder,
    this.shortcutOverrideActions,
    this.chunkAnalyzer = const NonCodeChunkAnalyzer(),
    this.style,
    this.fontSize = 14,
    this.fontHeight = 1.4,
    this.fontFamily,
    this.fontFamilyFallback,
    this.textColor,
    this.hintAlpha = 0.5,
    this.hintTextColor,
    this.cursorColor,
    this.selectionAlpha = 0.3,
    this.selectionColor,
    this.backgroundColor = Colors.transparent,
  });

  final CodeLineEditingController controller;
  final FocusNode? focusNode;
  final bool readOnly;
  final bool autofocus;
  final bool wordWrap;
  final String? hint;
  final EdgeInsets padding;
  final ValueChanged<CodeLineEditingValue>? onChanged;

  final CodeShortcutsActivatorsBuilder? shortcutsActivatorsBuilder;
  final Map<Type, Action<Intent>>? shortcutOverrideActions;
  final CodeChunkAnalyzer chunkAnalyzer;

  /// Provide a fully custom style; overrides all style-related params below.
  final CodeEditorStyle? style;

  // Common style params (used when [style] is null).
  final double fontSize;
  final double fontHeight;
  final String? fontFamily;
  final List<String>? fontFamilyFallback;
  final Color? textColor;
  final double hintAlpha;
  final Color? hintTextColor;
  final Color? cursorColor;
  final double selectionAlpha;
  final Color? selectionColor;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    final resolvedStyle = style ??
        buildPlainTextCodeEditorStyle(
          context,
          fontSize: fontSize,
          fontHeight: fontHeight,
          fontFamily: fontFamily,
          fontFamilyFallback: fontFamilyFallback,
          textColor: textColor,
          hintAlpha: hintAlpha,
          hintTextColor: hintTextColor,
          cursorColor: cursorColor,
          selectionAlpha: selectionAlpha,
          selectionColor: selectionColor,
          backgroundColor: backgroundColor,
        );

    return CodeEditor(
      controller: controller,
      focusNode: focusNode,
      readOnly: readOnly,
      autofocus: autofocus,
      wordWrap: wordWrap,
      shortcutsActivatorsBuilder: shortcutsActivatorsBuilder,
      shortcutOverrideActions: shortcutOverrideActions,
      indicatorBuilder: null,
      chunkAnalyzer: chunkAnalyzer,
      hint: hint,
      padding: padding,
      style: resolvedStyle,
      onChanged: onChanged,
    );
  }
}

