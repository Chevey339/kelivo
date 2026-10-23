import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'browser_text_field.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../l10n/app_localizations.dart';
import 'browser_glass.dart';
import 'browser_surface_controls.dart';

/// Touch uses separate glass controls; desktop uses a compact keyboard-first row.
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
    final appTextStyle = Theme.of(context).textTheme.bodyMedium!;
    final targetSize = compact ? 28.0 : 48.0;
    const gap = 8.0;
    final fontSize = compact ? 13.0 : 16.0;
    final field = ConstrainedBox(
      constraints: BoxConstraints(minHeight: targetSize),
      child: BrowserTextField(
        key: const ValueKey('browserFindField'),
        controller: controller,
        focusNode: focusNode,
        autofocus: true,
        placeholder: l.browserFindHint,
        style: TextStyle(
          fontFamily: appTextStyle.fontFamily,
          fontFamilyFallback: appTextStyle.fontFamilyFallback,
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
        padding: EdgeInsetsDirectional.only(
          top: compact ? 6 : 12,
          bottom: compact ? 6 : 12,
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
        textInputAction: TextInputAction.search,
        autocorrect: false,
        enableSuggestions: false,
        onChanged: onChanged,
        onSubmitted: onSubmitted,
      ),
    );
    if (compact) return _desktopBar(context, field);
    final done = BrowserSurfaceIconButton(
      key: const ValueKey('browserFindDone'),
      label: l.browserDone,
      icon: LucideIcons.check,
      size: targetSize,
      iconSize: 23,
      backgroundColor: Theme.of(context).colorScheme.primary,
      foregroundColor: Theme.of(context).colorScheme.onPrimary,
      onPressed: onDone,
    );
    final search = BrowserGlass(
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
            iconSize: 22,
            useParentFeedback: true,
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
            iconSize: 22,
            useParentFeedback: true,
            foregroundColor: colors.onSurface.withValues(
              alpha: enabled ? 1 : .28,
            ),
            onPressed: enabled ? onNext : null,
          ),
        ];
        return BrowserSurfaceIconGroup(
          key: const ValueKey('browserFindArrows'),
          children: children,
        );
      },
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final minimumSearchWidth = math.max(
          112.0,
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

  Widget _desktopBar(BuildContext context, Widget field) {
    final l = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    void submit() {
      if (controller.text.trim().isNotEmpty) onSubmitted(controller.text);
    }

    void previous() {
      if (controller.text.trim().isNotEmpty) onPrevious();
    }

    Widget action(
      String key,
      String label,
      IconData icon,
      VoidCallback? onTap,
    ) => Tooltip(
      message: label,
      child: BrowserSurfaceButton(
        key: ValueKey(key),
        semanticLabel: label,
        radius: 6,
        onPressed: onTap,
        child: SizedBox.square(
          dimension: 28,
          child: Icon(
            icon,
            size: 15,
            color: colors.onSurface.withValues(alpha: onTap == null ? .28 : 1),
          ),
        ),
      ),
    );
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onKeyEvent: (_, event) {
        if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
          return KeyEventResult.ignored;
        }
        final enter =
            event.logicalKey == LogicalKeyboardKey.enter ||
            event.logicalKey == LogicalKeyboardKey.numpadEnter;
        final escape = event.logicalKey == LogicalKeyboardKey.escape;
        if (!enter && !escape) return KeyEventResult.ignored;
        final composing = controller.value.composing;
        if (focusNode.hasFocus && composing.isValid && !composing.isCollapsed) {
          // Leave candidate confirmation/cancellation to the platform IME,
          // without allowing the page's ancestor Escape shortcut to close us.
          return KeyEventResult.skipRemainingHandlers;
        }
        final keyboard = HardwareKeyboard.instance;
        if (keyboard.isAltPressed ||
            keyboard.isControlPressed ||
            keyboard.isMetaPressed) {
          return KeyEventResult.ignored;
        }
        if (escape && !keyboard.isShiftPressed) {
          onDone();
          return KeyEventResult.handled;
        }
        if (enter && focusNode.hasFocus) {
          keyboard.isShiftPressed ? previous() : submit();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Row(
          children: [
            Expanded(
              child: ListenableBuilder(
                listenable: focusNode,
                builder: (context, child) => DecoratedBox(
                  key: const ValueKey('browserFindSearch'),
                  decoration: BoxDecoration(
                    color: colors.onSurface.withValues(alpha: .055),
                    borderRadius: BorderRadius.circular(7),
                    border: Border.all(
                      color: focusNode.hasFocus
                          ? colors.primary.withValues(alpha: .7)
                          : colors.onSurface.withValues(alpha: .12),
                    ),
                  ),
                  child: child,
                ),
                child: field,
              ),
            ),
            const SizedBox(width: 4),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: controller,
              builder: (context, value, _) {
                final enabled = value.text.trim().isNotEmpty;
                return Row(
                  key: const ValueKey('browserFindArrows'),
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    action(
                      'browserFindPrevious',
                      l.browserFindPreviousMatch,
                      LucideIcons.chevronUp,
                      enabled ? onPrevious : null,
                    ),
                    action(
                      'browserFindNext',
                      l.browserFindNextMatch,
                      LucideIcons.chevronDown,
                      enabled ? onNext : null,
                    ),
                  ],
                );
              },
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: SizedBox(
                height: 16,
                width: 1,
                child: ColoredBox(
                  color: colors.onSurface.withValues(alpha: .12),
                ),
              ),
            ),
            action('browserFindDone', l.commonClose, LucideIcons.x, onDone),
          ],
        ),
      ),
    );
  }
}
