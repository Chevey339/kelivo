import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:Kelivo/theme/app_font_weights.dart';
import 'package:Kelivo/theme/app_semantic_colors.dart';

class IosFormTextField extends StatelessWidget {
  const IosFormTextField({
    super.key,
    required this.label,
    required this.controller,
    this.hintText,
    this.suffix,
    this.prefix,
    this.maxLines = 1,
    this.minLines,
    this.inlineLabel,
    this.outerPadding,
    this.fieldWidth,
    this.keyboardType,
    this.textAlign,
    this.autofocus = false,
    this.obscureText = false,
    this.enabled = true,
    this.onChanged,
    this.onSubmitted,
    this.selectAllOnFocus = false,
    this.cursorToEndOnFocus = false,
    this.cursorToEndOnTap = false,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.autocorrect = true,
    this.enableSuggestions = true,
    this.focusNode,
    this.readOnly = false,
    this.textStyle,
    this.textDirection,
    this.fieldDecoration,
    this.suffixIconConstraints,
    this.inputFormatters,
    this.compact = false,
  });

  /// Compact painted field with an unchanged 44 dp interaction area.
  final bool compact;
  final String label;
  final TextEditingController controller;
  final String? hintText;
  final Widget? suffix, prefix;
  final int maxLines;
  final int? minLines;
  final bool? inlineLabel;
  final EdgeInsetsGeometry? outerPadding;
  final double? fieldWidth;
  final TextInputType? keyboardType;
  final TextAlign? textAlign;
  final bool autofocus;
  final bool obscureText;
  final bool enabled;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool selectAllOnFocus;
  final bool cursorToEndOnFocus;
  final bool cursorToEndOnTap;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;
  final bool autocorrect;
  final bool enableSuggestions;
  final FocusNode? focusNode;
  final bool readOnly;
  final TextStyle? textStyle;
  final TextDirection? textDirection;
  final BoxDecoration? fieldDecoration;
  final BoxConstraints? suffixIconConstraints;
  final List<TextInputFormatter>? inputFormatters;

  bool get _useInlineLabel => inlineLabel ?? (maxLines == 1);

  TextAlign _defaultTextAlign() {
    final kt = keyboardType;
    if (kt == TextInputType.number || kt == TextInputType.numberWithOptions()) {
      return TextAlign.end;
    }
    return TextAlign.start;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fieldBg = context.appColors.surfaceCardFill;
    final labelColor = cs.onSurface.withValues(alpha: 0.85);
    final valueColor = cs.onSurface.withValues(alpha: enabled ? 0.92 : 0.55);
    final hintColor = cs.onSurface.withValues(alpha: isDark ? 0.42 : 0.46);
    final resolvedOuterPadding =
        outerPadding ??
        const EdgeInsets.symmetric(horizontal: 12, vertical: 10);
    final fieldHorizontalPadding = (fieldWidth != null && fieldWidth! <= 60)
        ? 10.0
        : 12.0;

    void selectAll() {
      final len = controller.text.length;
      controller.selection = TextSelection(baseOffset: 0, extentOffset: len);
    }

    void moveCursorToEnd() {
      final len = controller.text.length;
      controller.selection = TextSelection.collapsed(offset: len);
    }

    Widget field = TextField(
      controller: controller,
      focusNode: focusNode,
      readOnly: readOnly,
      inputFormatters: inputFormatters,
      maxLines: maxLines,
      minLines: minLines,
      autofocus: autofocus,
      obscureText: obscureText,
      enabled: enabled,
      keyboardType: keyboardType,
      textAlign: textAlign ?? _defaultTextAlign(),
      textDirection: textDirection,
      textAlignVertical: maxLines == 1
          ? TextAlignVertical.center
          : TextAlignVertical.top,
      textInputAction: textInputAction,
      textCapitalization: textCapitalization,
      autocorrect: autocorrect,
      smartDashesType: autocorrect ? null : SmartDashesType.disabled,
      smartQuotesType: autocorrect ? null : SmartQuotesType.disabled,
      enableSuggestions: enableSuggestions,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      onTap: cursorToEndOnTap
          ? () {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                try {
                  moveCursorToEnd();
                } catch (_) {}
              });
            }
          : null,
      style:
          textStyle ??
          TextStyle(
            fontSize: 15,
            fontWeight: AppFontWeights.medium,
            color: valueColor,
            height: maxLines > 1 ? 1.25 : 1.0,
          ),
      strutStyle: maxLines == 1 && textStyle == null
          ? const StrutStyle(
              fontSize: 15,
              height: 1.0,
              leading: 0,
              forceStrutHeight: true,
            )
          : null,
      decoration: InputDecoration(
        isDense: true,
        constraints: compact && maxLines == 1
            ? const BoxConstraints(minHeight: 44)
            : null,
        isCollapsed: maxLines > 1,
        hintText: hintText,
        // InputDecorator's dense layout ignores a minimum height when placing
        // text. A zero-width accessory strut centers the line in the full tap
        // area, including fields without a visible prefix or suffix.
        prefixIcon:
            prefix ??
            (compact && maxLines == 1 ? const SizedBox.shrink() : null),
        prefixIconConstraints: prefix == null && !(compact && maxLines == 1)
            ? null
            : BoxConstraints(
                minWidth: prefix == null ? 0 : 28,
                minHeight: compact ? 44 : 36,
              ),
        suffixIcon: suffix,
        suffixIconConstraints: suffix == null
            ? null
            : suffixIconConstraints ??
                  const BoxConstraints.tightFor(width: 36, height: 36),
        hintStyle:
            textStyle?.copyWith(color: hintColor) ??
            TextStyle(
              fontSize: 15,
              fontWeight: AppFontWeights.medium,
              color: hintColor,
              height: maxLines > 1 ? 1.25 : 1.0,
            ),
        border: InputBorder.none,
        contentPadding: maxLines == 1
            ? EdgeInsets.symmetric(vertical: compact ? 0 : 10)
            : EdgeInsets.zero,
      ),
    );

    if (selectAllOnFocus || cursorToEndOnFocus) {
      field = Focus(
        onFocusChange: (hasFocus) {
          if (!hasFocus) return;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            try {
              if (selectAllOnFocus) {
                selectAll();
              } else if (cursorToEndOnFocus) {
                moveCursorToEnd();
              }
            } catch (_) {}
          });
        },
        child: field,
      );
    }

    if (_useInlineLabel) {
      final labelWidget = Text(
        label,
        style: TextStyle(
          fontSize: 15,
          fontWeight: AppFontWeights.medium,
          color: labelColor,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
      final fieldWidget = Container(
        constraints: const BoxConstraints(minHeight: 40),
        alignment: Alignment.center,
        decoration:
            fieldDecoration ??
            BoxDecoration(
              color: enabled ? fieldBg : fieldBg.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(10),
            ),
        padding: EdgeInsets.symmetric(horizontal: fieldHorizontalPadding),
        child: field,
      );
      return Padding(
        padding: resolvedOuterPadding,
        child: Row(
          children: [
            if (fieldWidth == null)
              Expanded(flex: 3, child: labelWidget)
            else
              Expanded(child: labelWidget),
            const SizedBox(width: 8),
            if (fieldWidth == null)
              Expanded(flex: 8, child: fieldWidget)
            else
              SizedBox(width: fieldWidth, child: fieldWidget),
          ],
        ),
      );
    }

    final decoration =
        fieldDecoration ??
        BoxDecoration(
          color: enabled ? fieldBg : fieldBg.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(12),
        );
    final fieldBox = compact
        ? Stack(
            alignment: Alignment.center,
            children: [
              Positioned.fill(
                top: maxLines == 1 ? 4 : 0,
                bottom: maxLines == 1 ? 4 : 0,
                child: DecoratedBox(decoration: decoration),
              ),
              ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 44),
                child: Padding(
                  padding: EdgeInsetsDirectional.fromSTEB(
                    prefix == null ? 12 : 6,
                    maxLines > 1 ? 8 : 0,
                    12,
                    maxLines > 1 ? 8 : 0,
                  ),
                  child: field,
                ),
              ),
            ],
          )
        : Container(
            constraints: maxLines == 1
                ? const BoxConstraints(minHeight: 40)
                : null,
            alignment: maxLines == 1 ? Alignment.centerLeft : Alignment.topLeft,
            decoration: decoration,
            padding: EdgeInsets.symmetric(
              horizontal: 12,
              vertical: maxLines > 1 ? 12 : 0,
            ),
            child: field,
          );

    return Padding(
      padding: resolvedOuterPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (label.isNotEmpty) ...[
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: AppFontWeights.semibold,
                color: labelColor,
              ),
            ),
            const SizedBox(height: 6),
          ],
          fieldBox,
        ],
      ),
    );
  }
}
