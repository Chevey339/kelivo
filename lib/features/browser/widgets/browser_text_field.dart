import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../shared/widgets/app_text_selection_toolbar.dart';

/// Keeps browser field decoration shared while selection, handles, magnifiers
/// and editing menus follow the host platform.
class BrowserTextField extends StatelessWidget {
  const BrowserTextField({
    super.key,
    required this.controller,
    this.focusNode,
    this.placeholder,
    this.style,
    this.placeholderStyle,
    this.cursorColor,
    this.padding = EdgeInsets.zero,
    this.prefix,
    this.autofocus = false,
    this.autocorrect = false,
    this.enableSuggestions = false,
    this.keyboardType = TextInputType.text,
    this.textInputAction = TextInputAction.done,
    this.maxLines = 1,
    this.onChanged,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final FocusNode? focusNode;
  final String? placeholder;
  final TextStyle? style, placeholderStyle;
  final Color? cursorColor;
  final EdgeInsetsGeometry padding;
  final Widget? prefix;
  final bool autofocus, autocorrect, enableSuggestions;
  final TextInputType keyboardType;
  final TextInputAction textInputAction;
  final int maxLines;
  final ValueChanged<String>? onChanged, onSubmitted;

  static Widget _buildDesktopContextMenu(
    BuildContext context,
    EditableTextState state,
  ) {
    return AppTextSelectionToolbar(
      anchors: state.contextMenuAnchors,
      buttonItems: state.contextMenuButtonItems,
      selectionContext: state.context,
      onDismiss: () => state.hideToolbar(false),
    );
  }

  @override
  Widget build(BuildContext context) {
    final platform = Theme.of(context).platform;
    final desktop =
        platform == TargetPlatform.macOS ||
        platform == TargetPlatform.windows ||
        platform == TargetPlatform.linux;
    final textStyle = Theme.of(context).textTheme.bodyMedium!.merge(style);
    final hintStyle = textStyle.merge(placeholderStyle);
    if (platform == TargetPlatform.iOS || platform == TargetPlatform.macOS) {
      return CupertinoTextField(
        controller: controller,
        focusNode: focusNode,
        placeholder: placeholder,
        // Cupertino aligns placeholder/input baselines, but RenderParagraph
        // reports alphabetic even when a CJK theme requests ideographic.
        style: textStyle.copyWith(textBaseline: TextBaseline.alphabetic),
        placeholderStyle: hintStyle.copyWith(
          textBaseline: TextBaseline.alphabetic,
        ),
        cursorColor: cursorColor,
        padding: padding,
        prefix: prefix,
        decoration: null,
        autofocus: autofocus,
        autocorrect: autocorrect,
        enableSuggestions: enableSuggestions,
        keyboardType: keyboardType,
        textInputAction: textInputAction,
        smartDashesType: SmartDashesType.disabled,
        smartQuotesType: SmartQuotesType.disabled,
        textAlignVertical: TextAlignVertical.center,
        maxLines: maxLines,
        onChanged: onChanged,
        onSubmitted: onSubmitted,
        contextMenuBuilder: desktop
            ? _buildDesktopContextMenu
            : const CupertinoTextField().contextMenuBuilder,
      );
    }
    return Material(
      type: MaterialType.transparency,
      child: Row(
        children: [
          if (prefix != null) prefix!,
          Expanded(
            child: Padding(
              padding: padding,
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                style: textStyle,
                cursorColor: cursorColor,
                autofocus: autofocus,
                autocorrect: autocorrect,
                enableSuggestions: enableSuggestions,
                keyboardType: keyboardType,
                textInputAction: textInputAction,
                smartDashesType: SmartDashesType.disabled,
                smartQuotesType: SmartQuotesType.disabled,
                textAlignVertical: TextAlignVertical.center,
                maxLines: maxLines,
                onChanged: onChanged,
                onSubmitted: onSubmitted,
                contextMenuBuilder: desktop
                    ? _buildDesktopContextMenu
                    : const TextField().contextMenuBuilder,
                decoration: InputDecoration(
                  hintText: placeholder,
                  hintStyle: hintStyle,
                  isCollapsed: true,
                  isDense: true,
                  // The browser already owns the field's padding. Compact
                  // desktop density otherwise offsets its placeholder.
                  visualDensity: VisualDensity.standard,
                  filled: false,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
