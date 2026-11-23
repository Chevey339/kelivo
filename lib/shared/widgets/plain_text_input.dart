import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart' show TextInputFormatter;
import 'package:flutter/material.dart' show Theme;

import 'app_text_selection_toolbar.dart';

/// System text editing and selection with only the chrome supplied by the parent.
class PlainTextInput extends StatelessWidget {
  const PlainTextInput({
    super.key,
    this.controller,
    this.focusNode,
    this.placeholder,
    this.style,
    this.placeholderStyle,
    this.singleLinePlaceholder = false,
    this.padding = EdgeInsets.zero,
    this.autofocus = false,
    this.enabled = true,
    this.minLines,
    this.maxLines = 1,
    this.onChanged,
    this.onSubmitted,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.keyboardType,
    this.inputFormatters,
    this.prefix,
    this.suffix,
    this.decoration,
    this.cursorColor,
    this.textAlign = TextAlign.start,
  });

  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String? placeholder;
  final TextStyle? style, placeholderStyle;
  final EdgeInsetsGeometry padding;
  final bool autofocus, enabled;

  /// Keep a growing prompt field at one line until the user enters text.
  final bool singleLinePlaceholder;
  final int? minLines, maxLines;
  final ValueChanged<String>? onChanged, onSubmitted;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final Widget? prefix, suffix;
  final BoxDecoration? decoration;
  final Color? cursorColor;
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final textStyle = theme.textTheme.bodyMedium!
        .copyWith(
          color: scheme.onSurface,
          fontSize: 14,
          height: 1.35,
          letterSpacing: 0,
          decoration: TextDecoration.none,
          leadingDistribution: TextLeadingDistribution.even,
        )
        .merge(style)
        .copyWith(textBaseline: TextBaseline.alphabetic);
    final hintStyle = textStyle
        .copyWith(color: scheme.onSurface.withValues(alpha: .42))
        .merge(placeholderStyle);
    final overlayHint =
        singleLinePlaceholder && placeholder != null && controller != null;
    final field = CupertinoTextField(
      controller: controller,
      focusNode: focusNode,
      autofocus: autofocus,
      enabled: enabled,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      minLines: minLines,
      maxLines: maxLines,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      textInputAction: textInputAction,
      textCapitalization: textCapitalization,
      style: textStyle,
      placeholder: overlayHint ? null : placeholder,
      placeholderStyle: hintStyle,
      cursorColor: cursorColor ?? scheme.primary,
      decoration: decoration ?? const BoxDecoration(),
      padding: padding,
      prefix: prefix,
      suffix: suffix,
      textAlign: textAlign,
      textAlignVertical: TextAlignVertical.center,
      contextMenuBuilder: (context, state) => AppTextSelectionToolbar(
        anchors: state.contextMenuAnchors,
        buttonItems: state.contextMenuButtonItems,
        selectionContext: state.context,
        onDismiss: () => state.hideToolbar(false),
      ),
    );
    if (!overlayHint) return field;
    // A textarea placeholder is paint-only: its translation must never size
    // the editable row or move the send button when the user starts typing.
    return Semantics(
      hint: placeholder,
      child: Stack(
        children: [
          field,
          Positioned.fill(
            child: IgnorePointer(
              child: ExcludeSemantics(
                child: ValueListenableBuilder<TextEditingValue>(
                  valueListenable: controller!,
                  builder: (context, value, child) =>
                      value.text.isEmpty ? child! : const SizedBox.shrink(),
                  child: Padding(
                    padding: padding,
                    child: Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: Text(
                        placeholder!,
                        style: hintStyle,
                        textAlign: textAlign,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
