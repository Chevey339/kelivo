import 'package:flutter/material.dart';
import 'package:xterm/xterm.dart';
import '../../l10n/app_localizations.dart';

/// Bottom sheet that embeds an xterm terminal connected to the Hermes backend.
///
/// Can be used as a draggable sheet (persistent mini terminal) or a full modal.
class HermesTerminalSheet extends StatefulWidget {
  final Terminal terminal;
  final VoidCallback? onClose;

  const HermesTerminalSheet({
    super.key,
    required this.terminal,
    this.onClose,
  });

  @override
  State<HermesTerminalSheet> createState() => _HermesTerminalSheetState();
}

class _HermesTerminalSheetState extends State<HermesTerminalSheet> {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: MediaQuery.of(context).size.height * 0.55,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFFAFAFA),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withAlpha(50),
        ),
      ),
      child: Column(
        children: [
          // Handle
          const SizedBox(height: 8),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.outline.withAlpha(100),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 8),
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Icon(
                  Icons.terminal,
                  size: 18,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  l10n.hermesTerminalTitle,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                // Copy button
                IconButton(
                  icon: const Icon(Icons.copy, size: 18),
                  tooltip: l10n.hermesTerminalCopy,
                  onPressed: () {
                    final lines = widget.terminal.buffer.lines;
                    final buf = StringBuffer();
                    for (int i = 0; i < lines.length; i++) {
                      buf.writeln(lines[i].getText());
                    }
                    // TODO: wire to clipboard
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  tooltip: l10n.hermesTerminalClose,
                  onPressed: () {
                    widget.onClose?.call();
                    Navigator.of(context).pop();
                  },
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Terminal view
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: TerminalView(
                widget.terminal,
                theme: isDark
                    ? TerminalThemes.defaultTheme
                    : const TerminalTheme(
                        cursor: Color(0xFF333333),
                        selection: Color(0x80333333),
                        foreground: Color(0xFF333333),
                        background: Color(0xFFFFFFFF),
                        black: Color(0xFF000000),
                        red: Color(0xFFCD3131),
                        green: Color(0xFF0DBC79),
                        yellow: Color(0xFFE5E510),
                        blue: Color(0xFF2472C8),
                        magenta: Color(0xFFBC3FBC),
                        cyan: Color(0xFF11A8CD),
                        white: Color(0xFFE5E5E5),
                        brightBlack: Color(0xFF666666),
                        brightRed: Color(0xFFF14C4C),
                        brightGreen: Color(0xFF23D18B),
                        brightYellow: Color(0xFFF5F543),
                        brightBlue: Color(0xFF3B8EEA),
                        brightMagenta: Color(0xFFD670D6),
                        brightCyan: Color(0xFF29B8DB),
                        brightWhite: Color(0xFFFFFFFF),
                        searchHitBackground: Color(0xFFFFFF2B),
                        searchHitBackgroundCurrent: Color(0xFF31FF26),
                        searchHitForeground: Color(0xFF000000),
                      ),
                textStyle: const TerminalStyle(
                  fontSize: 13,
                  fontFamily: 'Menlo',
                ),
                autofocus: true,
                backgroundOpacity: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Floating terminal button that can be shown in the chat area.
class HermesTerminalFab extends StatelessWidget {
  final VoidCallback onTap;

  const HermesTerminalFab({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return FloatingActionButton.small(
      heroTag: 'hermes_terminal',
      onPressed: onTap,
      tooltip: l10n.hermesTerminalOpen,
      child: const Icon(Icons.terminal, size: 20),
    );
  }
}
