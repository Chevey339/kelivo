import 'package:flutter/material.dart';

class IosFormTextField extends StatelessWidget {
  const IosFormTextField({
    super.key,
    required this.label,
    required this.controller,
    this.hintText,
    this.maxLines = 1,
    this.minLines,
    this.inlineLabel,
    this.outerPadding,
    this.fieldWidth,
    this.keyboardType,
    this.textAlign,
    this.autofocus = false,
    this.enabled = true,
    this.onChanged,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
  });

  final String label;
  final TextEditingController controller;
  final String? hintText;
  final int maxLines;
  final int? minLines;
  final bool? inlineLabel;
  final EdgeInsetsGeometry? outerPadding;
  final double? fieldWidth;
  final TextInputType? keyboardType;
  final TextAlign? textAlign;
  final bool autofocus;
  final bool enabled;
  final ValueChanged<String>? onChanged;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;

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
    final fieldBg = isDark ? Colors.white12 : const Color(0xFFF2F3F5);
    final labelColor = cs.onSurface.withOpacity(0.85);
    final valueColor = cs.onSurface.withOpacity(enabled ? 0.92 : 0.55);
    final hintColor = cs.onSurface.withOpacity(isDark ? 0.42 : 0.46);
    final resolvedOuterPadding =
        outerPadding ??
        const EdgeInsets.symmetric(horizontal: 12, vertical: 10);

    final field = TextField(
      controller: controller,
      maxLines: maxLines,
      minLines: minLines,
      autofocus: autofocus,
      enabled: enabled,
      keyboardType: keyboardType,
      textAlign: textAlign ?? _defaultTextAlign(),
      textAlignVertical: maxLines == 1
          ? TextAlignVertical.center
          : TextAlignVertical.top,
      textInputAction: textInputAction,
      textCapitalization: textCapitalization,
      onChanged: onChanged,
      style: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w500,
        color: valueColor,
        height: maxLines > 1 ? 1.25 : 1.15,
      ),
      decoration: InputDecoration(
        isDense: true,
        isCollapsed: true,
        hintText: hintText,
        hintStyle: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: hintColor,
        ),
        border: InputBorder.none,
        contentPadding: EdgeInsets.zero,
      ),
    );

    if (_useInlineLabel) {
      final labelWidget = Text(
        label,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: labelColor,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
      final fieldWidget = Container(
        constraints: const BoxConstraints(minHeight: 40),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: enabled ? fieldBg : fieldBg.withOpacity(0.55),
          borderRadius: BorderRadius.circular(10),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
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

    return Padding(
      padding: resolvedOuterPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: labelColor,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            constraints: maxLines == 1
                ? const BoxConstraints(minHeight: 40)
                : null,
            alignment: maxLines == 1 ? Alignment.centerLeft : Alignment.topLeft,
            decoration: BoxDecoration(
              color: enabled ? fieldBg : fieldBg.withOpacity(0.55),
              borderRadius: BorderRadius.circular(12),
            ),
            padding: EdgeInsets.symmetric(
              horizontal: 12,
              vertical: maxLines > 1 ? 12 : 9,
            ),
            child: field,
          ),
        ],
      ),
    );
  }
}
