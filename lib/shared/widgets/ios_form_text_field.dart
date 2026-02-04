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

    final field = TextField(
      controller: controller,
      maxLines: maxLines,
      minLines: minLines,
      autofocus: autofocus,
      enabled: enabled,
      keyboardType: keyboardType,
      textAlign: textAlign ?? _defaultTextAlign(),
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
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Expanded(
              flex: 5,
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: labelColor,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 6,
              child: Container(
                decoration: BoxDecoration(
                  color: enabled ? fieldBg : fieldBg.withOpacity(0.55),
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 7,
                ),
                child: field,
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
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
            decoration: BoxDecoration(
              color: enabled ? fieldBg : fieldBg.withOpacity(0.55),
              borderRadius: BorderRadius.circular(12),
            ),
            padding: EdgeInsets.symmetric(
              horizontal: 10,
              vertical: maxLines > 1 ? 10 : 8,
            ),
            child: field,
          ),
        ],
      ),
    );
  }
}
