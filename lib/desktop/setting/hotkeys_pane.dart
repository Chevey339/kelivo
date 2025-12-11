import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../icons/lucide_adapter.dart' as lucide;
import '../../l10n/app_localizations.dart';
import '../../shared/widgets/ios_switch.dart';
import '../../core/providers/hotkey_provider.dart';

class DesktopHotkeysPane extends StatefulWidget {
  const DesktopHotkeysPane({super.key});
  @override
  State<DesktopHotkeysPane> createState() => _DesktopHotkeysPaneState();
}

class _DesktopHotkeysPaneState extends State<DesktopHotkeysPane> {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final hk = context.watch<HotkeyProvider>();

    return Container(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 960),
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 36,
                  child: Row(
                    children: [
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            l10n.settingsPageHotkeys,
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w400, color: cs.onSurface.withOpacity(0.9)),
                          ),
                        ),
                      ),
                      Tooltip(
                        message: l10n.hotkeysResetAll,
                        child: _SmallIconBtn(
                          icon: lucide.Lucide.RefreshCw,
                          onTap: () async {
                            await context.read<HotkeyProvider>().resetAllToDefaults();
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 6)),
              SliverToBoxAdapter(
                child: _sectionCard(
                  children: [
                    for (int i = 0; i < hk.items.length; i++) ...[
                      _HotkeyRow(item: hk.items[i]),
                      if (i != hk.items.length - 1) _rowDivider(context),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionCard({required List<Widget> children}) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        // Match TTS card's lighter border when unselected
        border: Border.all(color: cs.outlineVariant.withOpacity(isDark ? 0.12 : 0.08), width: 0.6),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        child: Column(children: children),
      ),
    );
  }

  Widget _rowDivider(BuildContext context) => Divider(
        height: 1,
        thickness: 0.5,
        color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.25),
      );
}

class _HotkeyRow extends StatefulWidget {
  const _HotkeyRow({required this.item});
  final AppHotkey item;

  @override
  State<_HotkeyRow> createState() => _HotkeyRowState();
}

class _HotkeyRowState extends State<_HotkeyRow> {
  bool _recording = false;
  final FocusNode _focusNode = FocusNode(debugLabel: 'hotkey_recorder');

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final hk = context.watch<HotkeyProvider>();
    final item = widget.item;

    String displayLabel() {
      // Use l10n by key
      final loc = AppLocalizations.of(context)!;
      switch (item.l10nLabelKey) {
        case 'hotkeyToggleAppVisibility':
          return loc.hotkeyToggleAppVisibility;
        case 'hotkeyCloseWindow':
          return loc.hotkeyCloseWindow;
        case 'hotkeyOpenSettings':
          return loc.hotkeyOpenSettings;
        case 'hotkeyNewTopic':
          return loc.hotkeyNewTopic;
        case 'hotkeySwitchModel':
          return loc.hotkeySwitchModel;
        case 'hotkeyToggleAssistantPanel':
          return loc.hotkeyToggleAssistantPanel;
        case 'hotkeyToggleTopicPanel':
          return loc.hotkeyToggleTopicPanel;
        default:
          return item.l10nLabelKey;
      }
    }

    final current = HotkeyProvider.formatCommandForDisplay(item.command);
    final placeholder = l10n.hotkeysPressShortcut;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Row(
        children: [
          // Left: label
          Expanded(
            child: Text(
              displayLabel(),
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: cs.onSurface.withOpacity(0.92)),
            ),
          ),
          const SizedBox(width: 12),
          // Middle: shortcut editor
          SizedBox(
            width: 240,
            child: Stack(
              children: [
                _ShortcutEditor(
                  focusNode: _focusNode,
                  recording: _recording,
                  displayText: current.isEmpty ? placeholder : current,
                  onTap: () {
                    setState(() => _recording = true);
                    _focusNode.requestFocus();
                  },
                  onCancel: () => setState(() => _recording = false),
                  onSubmit: (cmd) async {
                    // Require at least one modifier; _ShortcutEditor guarantees
                    await context.read<HotkeyProvider>().setCommand(item.id, cmd);
                    if (mounted) setState(() => _recording = false);
                  },
                ),
                if (_recording)
                  // Tap outside cancel overlay
                  Positioned.fill(
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onTap: () => setState(() => _recording = false),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Right actions: reset, clear, enable
          Tooltip(
            message: l10n.hotkeysResetDefault,
            child: _SmallIconBtn(
              icon: lucide.Lucide.RotateCcw,
              onTap: () async => context.read<HotkeyProvider>().resetToDefault(item.id),
            ),
          ),
          const SizedBox(width: 8),
          Tooltip(
            message: l10n.hotkeysClearShortcut,
            child: _SmallIconBtn(
              icon: lucide.Lucide.Eraser,
              onTap: () async => context.read<HotkeyProvider>().clearCommand(item.id),
            ),
          ),
          const SizedBox(width: 12),
          IosSwitch(
            value: item.enabled,
            onChanged: (v) => context.read<HotkeyProvider>().setEnabled(item.id, v),
          ),
        ],
      ),
    );
  }
}

class _ShortcutEditor extends StatefulWidget {
  const _ShortcutEditor({
    required this.focusNode,
    required this.recording,
    required this.displayText,
    required this.onTap,
    required this.onCancel,
    required this.onSubmit,
  });
  final FocusNode focusNode;
  final bool recording;
  final String displayText;
  final VoidCallback onTap;
  final VoidCallback onCancel;
  final ValueChanged<String> onSubmit;

  @override
  State<_ShortcutEditor> createState() => _ShortcutEditorState();
}

class _ShortcutEditorState extends State<_ShortcutEditor> {
  // Track modifiers during capture
  bool _ctrl = false, _meta = false, _alt = false, _shift = false;
  String? _key;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final border = cs.outlineVariant.withOpacity(0.35);
    final bg = isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.03);
    return RawKeyboardListener(
      focusNode: widget.focusNode,
        onKey: (RawKeyEvent e) {
          if (!widget.recording) return;
        final isDown = e is RawKeyDownEvent;
        final data = e.data;
        // Logical modifiers cross-platform
        _ctrl = e.isControlPressed;
        _meta = e.isMetaPressed; // Cmd on macOS
        _alt = e.isAltPressed;
        _shift = e.isShiftPressed;

        // Identify non-modifier key on key down
        if (isDown) {
          final key = e.logicalKey;
          // Ignore pure modifier keys
          if (key == LogicalKeyboardKey.controlLeft ||
              key == LogicalKeyboardKey.controlRight ||
              key == LogicalKeyboardKey.metaLeft ||
              key == LogicalKeyboardKey.metaRight ||
              key == LogicalKeyboardKey.altLeft ||
              key == LogicalKeyboardKey.altRight ||
              key == LogicalKeyboardKey.shiftLeft ||
              key == LogicalKeyboardKey.shiftRight) {
            setState(() {});
            return;
          }

          // Map some punctuation/letters
          String? keyToken;
          if (key == LogicalKeyboardKey.comma) keyToken = 'comma';
          else if (key == LogicalKeyboardKey.bracketLeft) keyToken = 'bracketleft';
          else if (key == LogicalKeyboardKey.bracketRight) keyToken = 'bracketright';
          else if (key.keyLabel.length == 1) {
            final ch = key.keyLabel.toLowerCase();
            if (RegExp(r'^[a-z0-9]$').hasMatch(ch)) {
              if (RegExp(r'^[a-z]$').hasMatch(ch)) {
                keyToken = 'key$ch';
              } else {
                // digits: use raw label
                keyToken = ch;
              }
            }
          }
          _key = keyToken;

          // Save only when contains at least one modifier
          if ((_ctrl || _meta || _alt || _shift) && _key != null) {
            final mods = <String>[];
            if (_ctrl) mods.add('ctrl');
            if (_meta) mods.add('cmd');
            if (_alt) mods.add('alt');
            if (_shift) mods.add('shift');
            final cmd = [...mods, _key!].join('+');
            widget.onSubmit(cmd);
          }
        }
        setState(() {});
      },
      child: GestureDetector(
          onTap: widget.onTap,
          behavior: HitTestBehavior.opaque,
          child: Container(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: widget.recording ? cs.primary.withOpacity(0.5) : border),
            ),
            alignment: Alignment.centerLeft,
            child: Text(
              widget.recording ? (_liveDisplay()) : widget.displayText,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
                color: cs.onSurface.withOpacity(0.9),
              ),
            ),
          ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_onFocusChange);
    super.dispose();
  }

  void _onFocusChange() {
    if (!widget.focusNode.hasFocus && widget.recording) {
      widget.onCancel();
    }
  }

  String _liveDisplay() {
    final mods = <String>[];
    if (_ctrl) mods.add('Ctrl');
    if (_meta) mods.add('Cmd');
    if (_alt) mods.add('Alt');
    if (_shift) mods.add('Shift');
    final key = _key == null
        ? ''
        : () {
            switch (_key) {
              case 'comma':
                return ',';
              case 'bracketleft':
                return '[';
              case 'bracketright':
                return ']';
              default:
                if (_key!.startsWith('key') && _key!.length == 4) return _key!.substring(3).toUpperCase();
                return _key!.toUpperCase();
            }
          }();
    final parts = [...mods, if (key.isNotEmpty) key];
    return parts.isEmpty ? AppLocalizations.of(context)!.hotkeysPressShortcut : parts.join(' + ');
  }
}

class _SmallIconBtn extends StatefulWidget {
  const _SmallIconBtn({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;
  @override
  State<_SmallIconBtn> createState() => _SmallIconBtnState();
}

class _SmallIconBtnState extends State<_SmallIconBtn> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = _hover ? (isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.05)) : Colors.transparent;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
          alignment: Alignment.center,
          child: Icon(widget.icon, size: 16, color: cs.onSurface.withOpacity(0.9)),
        ),
      ),
    );
  }
}
