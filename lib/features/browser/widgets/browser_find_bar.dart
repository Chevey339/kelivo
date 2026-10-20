import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../l10n/app_localizations.dart';
import 'browser_glass.dart';
import 'browser_surface_controls.dart';

/// A bounded-width find dock with independent Done, search and traversal areas.
/// The parent positions it above the keyboard; no extra mobile surface is needed.
class BrowserFindBar extends StatelessWidget {
  const BrowserFindBar({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.onSubmitted,
    required this.onPrevious,
    required this.onNext,
    required this.onDone,
    this.compact = false,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged, onSubmitted;
  final VoidCallback onPrevious, onNext, onDone;

  /// Desktop's existing floating panel supplies the material around this bar.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final targetSize = compact ? 34.0 : 48.0;
    final gap = compact ? 6.0 : 8.0;
    final fontSize = compact ? 13.0 : 16.0;
    final done = BrowserSurfaceIconButton(
      key: const ValueKey('browserFindDone'),
      label: l.browserDone,
      icon: LucideIcons.check,
      size: targetSize,
      iconSize: compact ? 19 : 23,
      backgroundColor: const Color(0xff007aff),
      foregroundColor: Colors.white,
      onPressed: onDone,
    );
    final field = ConstrainedBox(
      constraints: BoxConstraints(minHeight: targetSize),
      child: CupertinoTextField(
        key: const ValueKey('browserFindField'),
        controller: controller,
        focusNode: focusNode,
        autofocus: true,
        placeholder: l.browserFindHint,
        style: TextStyle(
          fontSize: fontSize,
          height: 1.2,
          color: colors.onSurface,
        ),
        placeholderStyle: TextStyle(
          fontSize: fontSize,
          height: 1.2,
          color: colors.onSurfaceVariant,
        ),
        cursorColor: colors.primary,
        decoration: null,
        padding: EdgeInsetsDirectional.only(
          top: compact ? 7 : 12,
          bottom: compact ? 7 : 12,
          end: compact ? 10 : 14,
        ),
        prefix: Padding(
          padding: EdgeInsetsDirectional.only(
            start: compact ? 10 : 14,
            end: compact ? 6 : 8,
          ),
          child: Icon(
            LucideIcons.search,
            size: compact ? 16 : 19,
            color: colors.onSurfaceVariant,
          ),
        ),
        textAlignVertical: TextAlignVertical.center,
        textInputAction: TextInputAction.search,
        autocorrect: false,
        enableSuggestions: false,
        smartDashesType: SmartDashesType.disabled,
        smartQuotesType: SmartQuotesType.disabled,
        onChanged: onChanged,
        onSubmitted: onSubmitted,
      ),
    );
    final search = compact
        ? DecoratedBox(
            key: const ValueKey('browserFindSearch'),
            decoration: BoxDecoration(
              color: colors.onSurface.withValues(alpha: .055),
              borderRadius: BorderRadius.circular(1000),
            ),
            child: field,
          )
        : BrowserGlass(
            key: const ValueKey('browserFindSearch'),
            radius: 1000,
            child: field,
          );
    final arrows = ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        final enabled = value.text.trim().isNotEmpty;
        final children = [
          BrowserSurfaceIconButton(
            key: const ValueKey('browserFindPrevious'),
            label: l.browserBack,
            icon: LucideIcons.chevronUp,
            size: targetSize,
            iconSize: compact ? 18 : 22,
            useParentFeedback: !compact,
            foregroundColor: colors.onSurface.withValues(
              alpha: enabled ? 1 : .28,
            ),
            onPressed: enabled ? onPrevious : null,
          ),
          BrowserSurfaceIconButton(
            key: const ValueKey('browserFindNext'),
            label: l.browserForward,
            icon: LucideIcons.chevronDown,
            size: targetSize,
            iconSize: compact ? 18 : 22,
            useParentFeedback: !compact,
            foregroundColor: colors.onSurface.withValues(
              alpha: enabled ? 1 : .28,
            ),
            onPressed: enabled ? onNext : null,
          ),
        ];
        return compact
            ? Row(
                key: const ValueKey('browserFindArrows'),
                mainAxisSize: MainAxisSize.min,
                children: children,
              )
            : BrowserSurfaceIconGroup(
                key: const ValueKey('browserFindArrows'),
                children: children,
              );
      },
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final minimumSearchWidth = math.max(
          compact ? 100.0 : 112.0,
          MediaQuery.textScalerOf(context).scale(fontSize) * 4 + 40,
        );
        final wrap =
            constraints.maxWidth - targetSize * 3 - gap * 2 <
            minimumSearchWidth;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                done,
                SizedBox(width: gap),
                Expanded(child: search),
                if (!wrap) ...[SizedBox(width: gap), arrows],
              ],
            ),
            if (wrap) ...[
              SizedBox(height: gap),
              Align(alignment: AlignmentDirectional.centerEnd, child: arrows),
            ],
          ],
        );
      },
    );
  }
}
