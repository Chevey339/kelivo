import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Theme;

/// System text editing and selection with only the chrome supplied by the parent.
class PlainTextInput extends StatelessWidget {
  const PlainTextInput({
    super.key,
    this.controller,
    this.focusNode,
    this.placeholder,
    this.style,
    this.placeholderStyle,
    this.padding = EdgeInsets.zero,
    this.autofocus = false,
    this.enabled = true,
    this.minLines,
    this.maxLines = 1,
    this.onChanged,
    this.onSubmitted,
    this.textInputAction,
    this.keyboardType,
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
  final int? minLines, maxLines;
  final ValueChanged<String>? onChanged, onSubmitted;
  final TextInputAction? textInputAction;
  final TextInputType? keyboardType;
  final Widget? prefix, suffix;
  final BoxDecoration? decoration;
  final Color? cursorColor;
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textStyle = TextStyle(
      color: scheme.onSurface,
      fontSize: 14,
      height: 1.35,
      decoration: TextDecoration.none,
    ).merge(style);
    return CupertinoTextField(
      controller: controller,
      focusNode: focusNode,
      autofocus: autofocus,
      enabled: enabled,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      minLines: minLines,
      maxLines: maxLines,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      style: textStyle,
      placeholder: placeholder,
      placeholderStyle: textStyle
          .copyWith(color: scheme.onSurface.withValues(alpha: .42))
          .merge(placeholderStyle),
      cursorColor: cursorColor ?? scheme.primary,
      decoration: decoration,
      padding: padding,
      prefix: prefix,
      suffix: suffix,
      textAlign: textAlign,
      textAlignVertical: TextAlignVertical.center,
    );
  }
}
