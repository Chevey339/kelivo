import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../desktop/widgets/desktop_menu.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/ios_tactile.dart';
import '../../../theme/app_semantic_colors.dart';
import '../../../theme/design_tokens.dart';
import '../../browser/widgets/browser_text_field.dart';
import '../controllers/conversation_find_controller.dart';

class ConversationFindBar extends StatelessWidget {
  const ConversationFindBar({
    super.key,
    required this.find,
    required this.field,
    required this.focusNode,
    required this.onClose,
    required this.compact,
  });
  final ConversationFindController find;
  final TextEditingController field;
  final FocusNode focusNode;
  final VoidCallback onClose;
  final bool compact;

  bool get _composing =>
      field.value.composing.isValid && !field.value.composing.isCollapsed;

  KeyEventResult _key(FocusNode _, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final enter =
        event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.numpadEnter;
    final escape = event.logicalKey == LogicalKeyboardKey.escape;
    if (!enter && !escape) return KeyEventResult.ignored;
    if (_composing) return KeyEventResult.skipRemainingHandlers;
    final keyboard = HardwareKeyboard.instance;
    if (keyboard.isAltPressed ||
        keyboard.isMetaPressed ||
        keyboard.isControlPressed) {
      return KeyEventResult.ignored;
    }
    if (escape && !keyboard.isShiftPressed) {
      onClose();
    } else if (enter && focusNode.hasFocus) {
      find.move(keyboard.isShiftPressed ? -1 : 1);
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) => Focus(
    canRequestFocus: false,
    skipTraversal: true,
    onKeyEvent: _key,
    child: ListenableBuilder(
      listenable: find,
      builder: (context, _) => _toolbar(context),
    ),
  );

  Widget _toolbar(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final fg = cs.onSurface;
    final muted = fg.withValues(alpha: .56);
    final search = LayoutBuilder(
      builder: (context, constraints) => DecoratedBox(
        decoration: BoxDecoration(
          color: context.appColors.surfaceFill,
          borderRadius: BorderRadius.circular(compact ? 8 : 14),
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: compact ? 30 : 40),
          child: Row(
            children: [
              Expanded(
                child: BrowserTextField(
                  key: const ValueKey('conversationFindField'),
                  controller: field,
                  focusNode: focusNode,
                  autofocus: true,
                  placeholder: l.conversationFindHint,
                  textInputAction: TextInputAction.search,
                  prefix: Padding(
                    padding: EdgeInsetsDirectional.only(
                      start: compact ? 8 : 12,
                      end: compact ? 6 : 8,
                    ),
                    child: Icon(
                      LucideIcons.search,
                      size: compact ? 14 : 17,
                      color: muted,
                    ),
                  ),
                  style: TextStyle(fontSize: compact ? 13 : 16, color: fg),
                  placeholderStyle: TextStyle(color: muted),
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  onChanged: find.setQuery,
                  onSubmitted: (_) {
                    if (!_composing) {
                      find.move(1);
                      focusNode.requestFocus();
                    }
                  },
                ),
              ),
              if (find.query.trim().isNotEmpty)
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: constraints.maxWidth * .44,
                  ),
                  child: Padding(
                    padding: EdgeInsetsDirectional.only(
                      start: 4,
                      end: compact ? 8 : 10,
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        l.conversationFindMatchPosition(
                          find.index + 1,
                          find.hits.length,
                        ),
                        maxLines: 1,
                        style: TextStyle(
                          fontSize: compact ? 11 : 12,
                          color: muted,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
    final arrows = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _button(
          LucideIcons.chevronUp,
          l.conversationFindPrevious,
          find.canNavigate ? () => find.move(-1) : null,
          fg,
        ),
        _button(
          LucideIcons.chevronDown,
          l.conversationFindNext,
          find.canNavigate ? () => find.move(1) : null,
          fg,
        ),
      ],
    );
    final menu = _optionsMenu(context, l);
    if (compact) {
      return DecoratedBox(
        decoration: BoxDecoration(
          color: context.overlaySurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.appColors.hairline),
          boxShadow: AppShadows.soft,
        ),
        child: Padding(
          padding: const EdgeInsets.all(5),
          child: Row(
            children: [
              Expanded(child: search),
              const SizedBox(width: 4),
              arrows,
              menu,
              _button(LucideIcons.x, l.commonClose, onClose, muted),
            ],
          ),
        ),
      );
    }
    return Semantics(
      container: true,
      child: Padding(
        padding: const EdgeInsetsDirectional.only(start: 4, end: 8),
        child: Row(
          children: [
            _button(LucideIcons.chevronLeft, l.commonClose, onClose, fg),
            Expanded(child: search),
            const SizedBox(width: 4),
            arrows,
            menu,
          ],
        ),
      ),
    );
  }

  Widget _button(
    IconData icon,
    String label,
    VoidCallback? action,
    Color color,
  ) => IosIconButton(
    icon: icon,
    size: compact ? 15 : 19,
    minSize: compact ? 30 : 44,
    visualSize: compact ? 28 : 36,
    padding: EdgeInsets.zero,
    color: color,
    tooltip: label,
    onTap: action,
    enabled: action != null,
    mouseCursor: compact ? SystemMouseCursors.basic : SystemMouseCursors.click,
  );

  Widget _optionsMenu(BuildContext context, AppLocalizations l) {
    final cs = Theme.of(context).colorScheme;
    final options = find.options;
    final muted = cs.onSurfaceVariant;
    Widget row(
      IconData icon,
      String label,
      bool checked,
      VoidCallback toggle, {
      String? hint,
    }) {
      final check = checked
          ? Icon(LucideIcons.check, size: compact ? 15 : 17, color: cs.primary)
          : null;
      final leading = Icon(icon, size: compact ? 15 : 18, color: muted);
      return Semantics(
        checked: checked,
        button: true,
        child: compact
            ? DesktopMenuRow(
                label: label,
                tooltip: hint,
                leading: leading,
                trailing: check,
                onTap: toggle,
              )
            : IosCardPress(
                haptics: false,
                focusable: true,
                onTap: toggle,
                baseColor: Colors.transparent,
                borderRadius: BorderRadius.circular(10),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 44),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: [
                        leading,
                        const SizedBox(width: 10),
                        Expanded(
                          child: Tooltip(
                            message: hint ?? '',
                            child: Text(
                              label,
                              style: TextStyle(
                                fontSize: 15,
                                color: cs.onSurface,
                              ),
                            ),
                          ),
                        ),
                        if (check != null) check,
                      ],
                    ),
                  ),
                ),
              ),
      );
    }

    final items = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        row(
          LucideIcons.caseSensitive,
          l.conversationFindCaseSensitive,
          options.matchCase,
          () => find.setOptions((
            matchCase: !options.matchCase,
            wholeWord: options.wholeWord,
            thinking: options.thinking,
          )),
        ),
        row(
          LucideIcons.wholeWord,
          l.conversationFindWholeWord,
          options.wholeWord,
          () => find.setOptions((
            matchCase: options.matchCase,
            wholeWord: !options.wholeWord,
            thinking: options.thinking,
          )),
          hint: l.conversationFindWholeWordTooltip,
        ),
        row(
          LucideIcons.brain,
          l.conversationFindIncludeThinking,
          options.thinking,
          () => find.setOptions((
            matchCase: options.matchCase,
            wholeWord: options.wholeWord,
            thinking: !options.thinking,
          )),
        ),
      ],
    );
    final width = math.min(
      compact ? 208.0 : 228.0,
      MediaQuery.sizeOf(context).width - 16,
    );
    return MenuAnchor(
      onClose: () {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted && find.opened) {
            focusNode.requestFocus();
          }
        });
      },
      clipBehavior: Clip.none,
      // Align the menu's trailing edge with the trigger, including when a
      // browser pane occupies the rest of the window.
      alignmentOffset: Offset(-width, 6),
      style: const MenuStyle(
        alignment: AlignmentDirectional.bottomEnd,
        padding: WidgetStatePropertyAll(EdgeInsets.zero),
        backgroundColor: WidgetStatePropertyAll(Colors.transparent),
        surfaceTintColor: WidgetStatePropertyAll(Colors.transparent),
        elevation: WidgetStatePropertyAll(0),
      ),
      menuChildren: [
        SizedBox(
          width: width,
          child: compact
              ? DesktopMenuSurface(child: items)
              : DecoratedBox(
                  decoration: BoxDecoration(
                    color: context.overlaySurface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: context.appColors.hairline),
                    boxShadow: AppShadows.soft,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: items,
                  ),
                ),
        ),
      ],
      builder: (_, menu, _) => _button(
        compact ? LucideIcons.ellipsis : LucideIcons.slidersHorizontal,
        l.conversationFindOptions,
        () => menu.isOpen ? menu.close() : menu.open(),
        menu.isOpen ||
                options.matchCase ||
                options.wholeWord ||
                options.thinking
            ? cs.primary
            : cs.onSurfaceVariant,
      ),
    );
  }
}
