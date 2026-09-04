import 'package:flutter/material.dart';
import 'package:terminal_view/core.dart';

import 'package:Kelivo/core/services/haptics.dart';
import 'package:Kelivo/features/workspace/terminal/terminal_session_manager.dart';
import 'package:Kelivo/icons/lucide_adapter.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/widgets/ios_tactile.dart';
import 'package:Kelivo/theme/app_font_weights.dart';
import 'package:Kelivo/theme/app_semantic_colors.dart';

/// Extra keys shown above the soft keyboard.
class TerminalKeyBar extends StatelessWidget {
  const TerminalKeyBar({
    super.key,
    required this.session,
    required this.onCopy,
    required this.onPaste,
  });

  static const barKey = ValueKey<String>('terminal-key-bar');
  static const escKey = ValueKey<String>('terminal-key-esc');
  static const tabKey = ValueKey<String>('terminal-key-tab');
  static const ctrlKey = ValueKey<String>('terminal-key-ctrl');
  static const altKey = ValueKey<String>('terminal-key-alt');
  static const copyKey = ValueKey<String>('terminal-key-copy');
  static const pasteKey = ValueKey<String>('terminal-key-paste');

  final TerminalSession session;
  final VoidCallback onCopy;
  final VoidCallback onPaste;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final keyboardOpen =
        MediaQueryData.fromView(View.of(context)).viewInsets.bottom > 0;
    return ColoredBox(
      key: barKey,
      color: cs.surface,
      child: SafeArea(
        top: false,
        left: false,
        right: false,
        bottom: !keyboardOpen,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
          child: SizedBox(
            height: 36,
            child: Row(
              children: [
                Expanded(
                  child: Stack(
                    clipBehavior: Clip.hardEdge,
                    children: [
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children:
                              [
                                    _KeyChip(
                                      chipKey: escKey,
                                      label: 'Esc',
                                      onTap: () => session.sendKey(
                                        TerminalKey.escape,
                                        applyModifiers: false,
                                      ),
                                    ),
                                    _KeyChip(
                                      chipKey: tabKey,
                                      label: 'Tab',
                                      onTap: () =>
                                          session.sendKey(TerminalKey.tab),
                                    ),
                                    _KeyChip(
                                      chipKey: ctrlKey,
                                      label: 'Ctrl',
                                      active: session.ctrlModifier,
                                      onTap: session.toggleCtrl,
                                    ),
                                    _KeyChip(
                                      chipKey: altKey,
                                      label: 'Alt',
                                      active: session.altModifier,
                                      onTap: session.toggleAlt,
                                    ),
                                    _KeyChip(
                                      label: '←',
                                      onTap: () => session.sendKey(
                                        TerminalKey.arrowLeft,
                                      ),
                                    ),
                                    _KeyChip(
                                      label: '↑',
                                      onTap: () =>
                                          session.sendKey(TerminalKey.arrowUp),
                                    ),
                                    _KeyChip(
                                      label: '↓',
                                      onTap: () => session.sendKey(
                                        TerminalKey.arrowDown,
                                      ),
                                    ),
                                    _KeyChip(
                                      label: '→',
                                      onTap: () => session.sendKey(
                                        TerminalKey.arrowRight,
                                      ),
                                    ),
                                    _KeyChip(
                                      label: 'Home',
                                      onTap: () =>
                                          session.sendKey(TerminalKey.home),
                                    ),
                                    _KeyChip(
                                      label: 'End',
                                      onTap: () =>
                                          session.sendKey(TerminalKey.end),
                                    ),
                                    _KeyChip(
                                      label: 'PgUp',
                                      onTap: () =>
                                          session.sendKey(TerminalKey.pageUp),
                                    ),
                                    _KeyChip(
                                      label: 'PgDn',
                                      onTap: () =>
                                          session.sendKey(TerminalKey.pageDown),
                                    ),
                                    _KeyChip(
                                      label: '-',
                                      onTap: () => session.sendText('-'),
                                    ),
                                    _KeyChip(
                                      label: '/',
                                      onTap: () => session.sendText('/'),
                                    ),
                                    _KeyChip(
                                      label: '|',
                                      onTap: () => session.sendText('|'),
                                    ),
                                    _KeyChip(
                                      label: '~',
                                      onTap: () => session.sendText('~'),
                                    ),
                                  ]
                                  .expand(
                                    (chip) => [chip, const SizedBox(width: 8)],
                                  )
                                  .toList()
                                ..removeLast(),
                        ),
                      ),
                      Positioned(
                        right: 0,
                        top: 0,
                        bottom: 0,
                        width: 24,
                        child: IgnorePointer(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  cs.surface.withValues(alpha: 0),
                                  cs.surface,
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Tooltip(
                  message: l10n.terminalCopy,
                  child: _KeyChip(
                    chipKey: copyKey,
                    icon: Lucide.Copy,
                    label: l10n.terminalCopy,
                    onTap: onCopy,
                  ),
                ),
                const SizedBox(width: 8),
                Tooltip(
                  message: l10n.terminalPaste,
                  child: _KeyChip(
                    chipKey: pasteKey,
                    icon: Lucide.ClipboardPaste,
                    label: l10n.terminalPaste,
                    onTap: onPaste,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _KeyChip extends StatelessWidget {
  const _KeyChip({
    required this.label,
    required this.onTap,
    this.chipKey,
    this.icon,
    this.active = false,
  });

  final Key? chipKey;
  final IconData? icon;
  final String label;
  final VoidCallback onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bg = active
        ? cs.primary.withValues(alpha: 0.14)
        : context.appColors.surfaceFill;
    final fg = active ? cs.primary : cs.onSurface.withValues(alpha: 0.88);
    final style = TextStyle(
      fontSize: 13,
      fontWeight: AppFontWeights.medium,
      color: fg,
    );
    return KeyedSubtree(
      key: chipKey,
      child: UnconstrainedBox(
        constrainedAxis: Axis.vertical,
        alignment: Alignment.center,
        child: IosCardPress(
          haptics: false,
          baseColor: bg,
          borderRadius: BorderRadius.circular(10),
          border: active
              ? Border.all(color: cs.primary.withValues(alpha: 0.45))
              : null,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          pressedScale: 0.98,
          onTap: () {
            Haptics.light();
            onTap();
          },
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 28, minHeight: 36),
            child: Center(
              widthFactor: 1,
              heightFactor: 1,
              child: icon == null
                  ? Text(label, style: style)
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(icon, size: 14, color: fg),
                        const SizedBox(width: 4),
                        Text(label, style: style),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
