import 'package:flutter/material.dart';

import 'package:Kelivo/theme/app_font_weights.dart';
import 'package:Kelivo/theme/app_semantic_colors.dart';

/// Compact desktop field with one shared line metric for its hint and value.
class DesktopWorkspaceTextField extends StatelessWidget {
  const DesktopWorkspaceTextField({
    super.key,
    required this.controller,
    this.label = '',
    this.hintText,
    this.leadingIcon,
    this.borderRadius = 8,
    this.autofocus = false,
    this.enabled = true,
    this.onChanged,
    this.onSubmitted,
    this.minLines,
    this.maxLines = 1,
    this.fillColor,
    this.borderColor,
  });

  final TextEditingController controller;
  final String label;
  final String? hintText;
  final IconData? leadingIcon;
  final double borderRadius;
  final bool autofocus;
  final bool enabled;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final int? minLines;
  final int maxLines;
  final Color? fillColor;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final style = Theme.of(context).textTheme.bodyMedium!.copyWith(
      fontSize: 13,
      height: 1.25,
      fontWeight: AppFontWeights.regular,
      color: cs.onSurface.withValues(alpha: enabled ? 0.9 : 0.45),
    );
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(borderRadius),
      borderSide: borderColor == null
          ? BorderSide.none
          : BorderSide(color: borderColor!),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label.isNotEmpty) ...[
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: AppFontWeights.medium,
              color: cs.onSurface.withValues(alpha: 0.72),
            ),
          ),
          const SizedBox(height: 8),
        ],
        SizedBox(
          height: maxLines == 1 ? 36 : null,
          child: TextField(
            controller: controller,
            autofocus: autofocus,
            enabled: enabled,
            minLines: minLines,
            maxLines: maxLines,
            textAlignVertical: maxLines == 1
                ? TextAlignVertical.center
                : TextAlignVertical.top,
            style: style,
            onChanged: onChanged,
            onSubmitted: onSubmitted,
            textInputAction: maxLines == 1
                ? TextInputAction.done
                : TextInputAction.newline,
            decoration: InputDecoration(
              isDense: false,
              isCollapsed: false,
              filled: true,
              fillColor: fillColor ?? context.appColors.surfaceFill,
              hintText: hintText,
              hintStyle: style.copyWith(
                color: cs.onSurface.withValues(alpha: 0.4),
              ),
              prefixIcon: leadingIcon == null
                  ? null
                  : Icon(
                      leadingIcon,
                      size: 15,
                      color: cs.onSurface.withValues(alpha: 0.42),
                    ),
              prefixIconConstraints: const BoxConstraints(minWidth: 34),
              contentPadding: EdgeInsets.symmetric(
                horizontal: 10,
                vertical: maxLines == 1 ? 0 : 10,
              ),
              border: border,
              enabledBorder: border,
              disabledBorder: border,
              focusedBorder: border.copyWith(
                borderSide: BorderSide(
                  color: cs.primary.withValues(alpha: 0.35),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
