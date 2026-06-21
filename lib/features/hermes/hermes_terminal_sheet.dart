import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:xterm/xterm.dart';
import '../../l10n/app_localizations.dart';

/// Terminal theme options.
enum HermesTerminalThemeMode { system, dark, light }

/// Default light theme for terminal.
const _lightTerminalTheme = TerminalTheme(
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
);

/// Bottom sheet that embeds an xterm terminal connected to the Hermes backend.
///
/// Supports keyboard shortcuts:
/// - Ctrl+L: Clear screen
/// - Ctrl+Shift+V / Ctrl+V: Paste from clipboard
/// - Ctrl+Shift+C: Copy selection to clipboard
class HermesTerminalSheet extends StatefulWidget {
  final Terminal terminal;
  final VoidCallback? onClose;

  const HermesTerminalSheet({super.key, required this.terminal, this.onClose});

  @override
  State<HermesTerminalSheet> createState() => _HermesTerminalSheetState();
}

class _HermesTerminalSheetState extends State<HermesTerminalSheet> {
  late final TerminalController _terminalController;

  // Settings state
  HermesTerminalThemeMode _themeMode = HermesTerminalThemeMode.system;
  double _fontSize = 13;

  @override
  void initState() {
    super.initState();
    _terminalController = TerminalController();
  }

  @override
  void dispose() {
    _terminalController.dispose();
    super.dispose();
  }

  /// Clear the terminal screen by writing ANSI escape sequences.
  void _clearScreen() {
    widget.terminal.write('\x1b[2J\x1b[H');
  }

  /// Paste text from system clipboard into the terminal.
  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData('text/plain');
    if (data?.text != null && data!.text!.isNotEmpty) {
      widget.terminal.paste(data.text!);
    }
  }

  /// Copy selected terminal text to clipboard.
  Future<void> _copySelection() async {
    final selection = _terminalController.selection;
    if (selection != null) {
      final text = widget.terminal.buffer.getText(selection);
      await Clipboard.setData(ClipboardData(text: text));
      _terminalController.clearSelection();
    }
  }

  /// Show the settings bottom sheet.
  void _showSettings() {
    final l10n = AppLocalizations.of(context)!;

    showModalBottomSheet(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          return Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.hermesTerminalSettings,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 24),

                // Font size
                Text(
                  l10n.hermesTerminalFontSize,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove),
                      onPressed: _fontSize > 8
                          ? () => setSheetState(() => _fontSize--)
                          : null,
                    ),
                    Text(
                      '${_fontSize.toInt()}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    IconButton(
                      icon: const Icon(Icons.add),
                      onPressed: _fontSize < 32
                          ? () => setSheetState(() => _fontSize++)
                          : null,
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Theme
                Text(
                  l10n.hermesTerminalTheme,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                SegmentedButton<HermesTerminalThemeMode>(
                  segments: [
                    ButtonSegment(
                      value: HermesTerminalThemeMode.system,
                      label: Text(l10n.hermesTerminalThemeSystem),
                      icon: const Icon(Icons.settings_brightness),
                    ),
                    ButtonSegment(
                      value: HermesTerminalThemeMode.dark,
                      label: Text(l10n.hermesTerminalThemeDark),
                      icon: const Icon(Icons.dark_mode),
                    ),
                    ButtonSegment(
                      value: HermesTerminalThemeMode.light,
                      label: Text(l10n.hermesTerminalThemeLight),
                      icon: const Icon(Icons.light_mode),
                    ),
                  ],
                  selected: {_themeMode},
                  onSelectionChanged: (selection) {
                    setSheetState(() => _themeMode = selection.first);
                  },
                ),

                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }

  /// Get the effective terminal theme based on current settings.
  TerminalTheme _getEffectiveTheme() {
    switch (_themeMode) {
      case HermesTerminalThemeMode.system:
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return isDark ? TerminalThemes.defaultTheme : _lightTerminalTheme;
      case HermesTerminalThemeMode.dark:
        return TerminalThemes.defaultTheme;
      case HermesTerminalThemeMode.light:
        return _lightTerminalTheme;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return CallbackShortcuts(
      bindings: {
        // Ctrl+L: Clear screen
        const SingleActivator(LogicalKeyboardKey.keyL, control: true):
            _clearScreen,
        // Ctrl+Shift+V: Paste (macOS convention)
        const SingleActivator(
          LogicalKeyboardKey.keyV,
          shift: true,
          control: true,
        ): _pasteFromClipboard,
        // Ctrl+Shift+C: Copy selection (macOS convention)
        const SingleActivator(
          LogicalKeyboardKey.keyC,
          shift: true,
          control: true,
        ): _copySelection,
      },
      child: Focus(
        autofocus: true,
        child: Container(
          height: MediaQuery.of(context).size.height * 0.55,
          decoration: BoxDecoration(
            color: _themeMode == HermesTerminalThemeMode.light
                ? const Color(0xFFFAFAFA)
                : _themeMode == HermesTerminalThemeMode.dark
                ? const Color(0xFF1E1E1E)
                : Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF1E1E1E)
                : const Color(0xFFFAFAFA),
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
                    // Settings button
                    IconButton(
                      icon: const Icon(Icons.settings, size: 18),
                      tooltip: l10n.hermesTerminalSettings,
                      onPressed: _showSettings,
                    ),
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
                        Clipboard.setData(ClipboardData(text: buf.toString()));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(l10n.hermesTerminalCopy),
                            duration: const Duration(seconds: 1),
                          ),
                        );
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
              // Terminal view with keyboard shortcut handling
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: TerminalView(
                    widget.terminal,
                    controller: _terminalController,
                    theme: _getEffectiveTheme(),
                    textStyle: TerminalStyle(
                      fontSize: _fontSize,
                      fontFamily: 'Menlo',
                    ),
                    autofocus: false,
                    backgroundOpacity: 0,
                    // Handle right-click for context menu (copy/paste)
                    onSecondaryTapDown: (details, offset) async {
                      final selection = _terminalController.selection;
                      if (selection != null) {
                        // Copy selected text
                        final text = widget.terminal.buffer.getText(selection);
                        await Clipboard.setData(ClipboardData(text: text));
                        _terminalController.clearSelection();
                      } else {
                        // Paste from clipboard
                        final data = await Clipboard.getData('text/plain');
                        if (data?.text != null && data!.text!.isNotEmpty) {
                          widget.terminal.paste(data.text!);
                        }
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
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
