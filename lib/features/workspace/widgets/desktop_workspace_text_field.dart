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
    this.autofocus = false,
    this.enabled = true,
    this.onChanged,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String label;
  final String? hintText;
  final IconData? leadingIcon;
  final bool autofocus;
  final bool enabled;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

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
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide.none,
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
          height: 36,
          child: TextField(
            controller: controller,
            autofocus: autofocus,
            enabled: enabled,
            maxLines: 1,
            textAlignVertical: TextAlignVertical.center,
            style: style,
            onChanged: onChanged,
            onSubmitted: onSubmitted,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              isDense: false,
              isCollapsed: false,
              filled: true,
              fillColor: context.appColors.surfaceFill,
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
              contentPadding: const EdgeInsets.symmetric(horizontal: 10),
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
