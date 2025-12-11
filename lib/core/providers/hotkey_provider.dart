import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;

import '../../desktop/hotkeys/hotkey_event_bus.dart';

/// A single hotkey item definition and state.
class AppHotkey {
  AppHotkey({
    required this.id,
    required this.l10nLabelKey,
    this.defaultWinLinux,
    this.defaultMac,
    this.enabledByDefault = true,
  });

  final String id;
  final String l10nLabelKey; // key in AppLocalizations
  final String? defaultWinLinux; // e.g., 'ctrl+comma'
  final String? defaultMac; // e.g., 'cmd+comma'
  final bool enabledByDefault;

  // runtime state
  String? command; // normalized key string, platform-independent
  bool enabled = true;
}

/// Provider that stores hotkey assignments and registers them via hotkey_manager.
class HotkeyProvider extends ChangeNotifier {
  static const _prefsKeyCommands = 'desktop_hotkeys_commands_v1'; // id -> command
  static const _prefsKeyEnabled = 'desktop_hotkeys_enabled_v1'; // id -> bool

  final Map<String, AppHotkey> _items = {
    // Toggle app visibility (no default)
    'toggle_app_visibility': AppHotkey(
      id: 'toggle_app_visibility',
      l10nLabelKey: 'hotkeyToggleAppVisibility',
      defaultWinLinux: '',
      defaultMac: '',
      enabledByDefault: true,
    ),
    // Close window (in-app scope)
    'close_window': AppHotkey(
      id: 'close_window',
      l10nLabelKey: 'hotkeyCloseWindow',
      defaultWinLinux: 'ctrl+w',
      defaultMac: 'cmd+w',
      enabledByDefault: true,
    ),
    // Open settings
    'open_settings': AppHotkey(
      id: 'open_settings',
      l10nLabelKey: 'hotkeyOpenSettings',
      defaultWinLinux: 'ctrl+comma',
      defaultMac: 'cmd+comma',
      enabledByDefault: true,
    ),
    // New topic (chat)
    'new_topic': AppHotkey(
      id: 'new_topic',
      l10nLabelKey: 'hotkeyNewTopic',
      defaultWinLinux: 'ctrl+n',
      defaultMac: 'cmd+n',
      enabledByDefault: true,
    ),
    // Switch model (chat; no default)
    'switch_model': AppHotkey(
      id: 'switch_model',
      l10nLabelKey: 'hotkeySwitchModel',
      defaultWinLinux: '',
      defaultMac: '',
      enabledByDefault: true,
    ),
    // Toggle assistants panel (left topics layout only)
    'toggle_assistants': AppHotkey(
      id: 'toggle_assistants',
      l10nLabelKey: 'hotkeyToggleAssistantPanel',
      defaultWinLinux: 'ctrl+bracketleft',
      defaultMac: 'cmd+bracketleft',
      enabledByDefault: true,
    ),
    // Toggle topics panel (left topics layout only)
    'toggle_topics': AppHotkey(
      id: 'toggle_topics',
      l10nLabelKey: 'hotkeyToggleTopicPanel',
      defaultWinLinux: 'ctrl+bracketright',
      defaultMac: 'cmd+bracketright',
      enabledByDefault: true,
    ),
  };

  final Map<String, HotKey> _registered = <String, HotKey>{};

  bool _initialized = false;
  bool get initialized => _initialized;

  List<AppHotkey> get items => _items.values.toList(growable: false);
  AppHotkey getById(String id) => _items[id]!;

  Future<void> initialize() async {
    if (_initialized) return;
    final prefs = await SharedPreferences.getInstance();
    // Load enabled map
    final enabledMap = (prefs.getStringList(_prefsKeyEnabled) ?? [])
        .map((e) => e.split('=')).where((p) => p.length == 2)
        .map((p) => MapEntry(p[0], p[1] == '1'))
        .toList();
    final enabled = <String, bool>{ for (final e in enabledMap) e.key: e.value };
    // Load commands map
    final cmdList = (prefs.getStringList(_prefsKeyCommands) ?? [])
        .map((e) => e.split('=')).where((p) => p.length == 2)
        .map((p) => MapEntry(p[0], p[1]))
        .toList();
    final commands = <String, String>{ for (final e in cmdList) e.key: e.value };

    // Seed defaults
    final isMac = Platform.isMacOS;
    for (final e in _items.values) {
      e.enabled = enabled[e.id] ?? e.enabledByDefault;
      final def = (isMac ? e.defaultMac : e.defaultWinLinux) ?? '';
      final raw = commands[e.id] ?? def;
      e.command = (raw.trim().isEmpty) ? null : raw.trim();
    }

    _initialized = true;
    await _rebindAll();
    notifyListeners();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    final enabledList = _items.values.map((e) => '${e.id}=${e.enabled ? '1' : '0'}').toList();
    final cmdList = _items.values.map((e) => '${e.id}=${e.command ?? ''}').toList();
    await prefs.setStringList(_prefsKeyEnabled, enabledList);
    await prefs.setStringList(_prefsKeyCommands, cmdList);
  }

  Future<void> resetAllToDefaults() async {
    final isMac = Platform.isMacOS;
    for (final e in _items.values) {
      final def = (isMac ? e.defaultMac : e.defaultWinLinux) ?? '';
      e.command = def.isEmpty ? null : def;
      e.enabled = e.enabledByDefault;
    }
    await _persist();
    await _rebindAll();
    notifyListeners();
  }

  Future<void> resetToDefault(String id) async {
    final item = _items[id]!;
    final def = (Platform.isMacOS ? item.defaultMac : item.defaultWinLinux) ?? '';
    item.command = def.isEmpty ? null : def;
    await _persist();
    await _rebindAll();
    notifyListeners();
  }

  Future<void> clearCommand(String id) async {
    final item = _items[id]!;
    item.command = null;
    await _persist();
    await _rebindAll();
    notifyListeners();
  }

  Future<void> setCommand(String id, String command) async {
    final item = _items[id]!;
    item.command = command.trim().isEmpty ? null : command.trim();
    await _persist();
    await _rebindAll();
    notifyListeners();
  }

  Future<void> setEnabled(String id, bool value) async {
    final item = _items[id]!;
    item.enabled = value;
    await _persist();
    await _rebindAll();
    notifyListeners();
  }

  // ===== Registration via hotkey_manager =====

  Future<void> _rebindAll() async {
    // Hard reset: ensure no stale registrations (especially system scope)
    try {
      await HotKeyManager.instance.unregisterAll();
    } catch (_) {
      // Fallback to unregister known ones if needed
      for (final hk in _registered.values) {
        try { await HotKeyManager.instance.unregister(hk); } catch (_) {}
      }
    }
    _registered.clear();

    // Register each enabled item with valid command
    for (final e in _items.values) {
      if (!e.enabled) continue;
      final cmd = e.command;
      if (cmd == null || cmd.trim().isEmpty) continue;
      final scope = (e.id == 'toggle_app_visibility') ? HotKeyScope.system : HotKeyScope.inapp;
      final hk = _parseCommandToHotKey(cmd, scope: scope);
      if (hk == null) continue;

      try {
        await HotKeyManager.instance.register(
          hk,
          keyDownHandler: (_) => _invoke(e.id),
        );
        _registered[e.id] = hk;
      } catch (_) {
        // Ignore registration error (e.g., duplicate)
      }
    }
  }

  void _invoke(String id) {
    switch (id) {
      case 'toggle_app_visibility':
        HotkeyEventBus.instance.fire(HotkeyAction.toggleAppVisibility);
        break;
      case 'close_window':
        HotkeyEventBus.instance.fire(HotkeyAction.closeWindow);
        break;
      case 'open_settings':
        HotkeyEventBus.instance.fire(HotkeyAction.openSettings);
        break;
      case 'new_topic':
        HotkeyEventBus.instance.fire(HotkeyAction.newTopic);
        break;
      case 'switch_model':
        HotkeyEventBus.instance.fire(HotkeyAction.switchModel);
        break;
      case 'toggle_assistants':
        HotkeyEventBus.instance.fire(HotkeyAction.toggleLeftPanelAssistants);
        break;
      case 'toggle_topics':
        HotkeyEventBus.instance.fire(HotkeyAction.toggleLeftPanelTopics);
        break;
    }
  }

  // ===== Helpers for parsing/displaying hotkey strings =====

  // Supported commands format: 'ctrl+shift+n', 'cmd+comma', 'ctrl+bracketleft'
  HotKey? _parseCommandToHotKey(String command, {HotKeyScope scope = HotKeyScope.inapp}) {
    final raw = command.trim().toLowerCase();
    if (raw.isEmpty) return null;
    final parts = raw.split('+').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    final modifiers = <HotKeyModifier>[];
    LogicalKeyboardKey? keyboardKey;
    for (final p in parts) {
      switch (p) {
        case 'ctrl':
        case 'control':
          modifiers.add(HotKeyModifier.control);
          break;
        case 'cmd':
        case 'meta':
          modifiers.add(HotKeyModifier.meta);
          break;
        case 'alt':
        case 'option':
          modifiers.add(HotKeyModifier.alt);
          break;
        case 'shift':
          modifiers.add(HotKeyModifier.shift);
          break;
        case ',':
        case 'comma':
          keyboardKey = LogicalKeyboardKey.comma;
          break;
        case '[':
        case 'bracketleft':
          keyboardKey = LogicalKeyboardKey.bracketLeft;
          break;
        case ']':
        case 'bracketright':
          keyboardKey = LogicalKeyboardKey.bracketRight;
          break;
        default:
          if (p.length == 1) {
            final ch = p[0];
            if (ch.codeUnitAt(0) >= 97 && ch.codeUnitAt(0) <= 122) {
              // a-z -> keyA ... keyZ
              keyboardKey = _letterToLogicalKey(ch);
            }
          } else if (p.startsWith('key') && p.length == 4) {
            keyboardKey = _letterToLogicalKey(p.substring(3));
          }
      }
    }
    if (keyboardKey == null) return null;
    // Require at least one modifier (avoid single-key capture)
    if (modifiers.isEmpty) return null;
    return HotKey(key: keyboardKey!, modifiers: modifiers, scope: scope);
  }

  LogicalKeyboardKey? _letterToLogicalKey(String ch) {
    switch (ch.toLowerCase()) {
      case 'a': return LogicalKeyboardKey.keyA;
      case 'b': return LogicalKeyboardKey.keyB;
      case 'c': return LogicalKeyboardKey.keyC;
      case 'd': return LogicalKeyboardKey.keyD;
      case 'e': return LogicalKeyboardKey.keyE;
      case 'f': return LogicalKeyboardKey.keyF;
      case 'g': return LogicalKeyboardKey.keyG;
      case 'h': return LogicalKeyboardKey.keyH;
      case 'i': return LogicalKeyboardKey.keyI;
      case 'j': return LogicalKeyboardKey.keyJ;
      case 'k': return LogicalKeyboardKey.keyK;
      case 'l': return LogicalKeyboardKey.keyL;
      case 'm': return LogicalKeyboardKey.keyM;
      case 'n': return LogicalKeyboardKey.keyN;
      case 'o': return LogicalKeyboardKey.keyO;
      case 'p': return LogicalKeyboardKey.keyP;
      case 'q': return LogicalKeyboardKey.keyQ;
      case 'r': return LogicalKeyboardKey.keyR;
      case 's': return LogicalKeyboardKey.keyS;
      case 't': return LogicalKeyboardKey.keyT;
      case 'u': return LogicalKeyboardKey.keyU;
      case 'v': return LogicalKeyboardKey.keyV;
      case 'w': return LogicalKeyboardKey.keyW;
      case 'x': return LogicalKeyboardKey.keyX;
      case 'y': return LogicalKeyboardKey.keyY;
      case 'z': return LogicalKeyboardKey.keyZ;
    }
    return null;
  }

  static String formatCommandForDisplay(String? cmd) {
    if (cmd == null || cmd.trim().isEmpty) return '';
    final parts = cmd.toLowerCase().split('+').map((e) => e.trim()).toList();
    String nice(String p) {
      switch (p) {
        case 'ctrl':
        case 'control':
          return 'Ctrl';
        case 'cmd':
        case 'meta':
          return 'Cmd';
        case 'alt':
        case 'option':
          return 'Alt';
        case 'shift':
          return 'Shift';
        case ',':
        case 'comma':
          return ',';
        case '[':
        case 'bracketleft':
          return '[';
        case ']':
        case 'bracketright':
          return ']';
        default:
          if (p.startsWith('key') && p.length == 4) {
            return p.substring(3).toUpperCase();
          }
          return p.toUpperCase();
      }
    }

    return parts.map(nice).join(' + ');
  }
}
