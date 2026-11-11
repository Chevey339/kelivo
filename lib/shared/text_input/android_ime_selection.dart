// The original Android key packet is the only Flutter API that retains an
// IME's metaState. KeyEvent can lose Shift when the engine synthesizes its up.
// ignore_for_file: deprecated_member_use

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Dispatches IME selection commands using their Android modifier state.
/// Flutter's existing actions still own grapheme, bidi and visual-line motion.
class AndroidImeSelection {
  static final instance = AndroidImeSelection();

  bool _installed = false;
  RawKeyEvent? _rawEvent;

  void install() {
    if (_installed ||
        kIsWeb ||
        defaultTargetPlatform != TargetPlatform.android) {
      return;
    }
    _installed = true;
    RawKeyboard.instance.addListener(_recordEvent);
    FocusManager.instance.addEarlyKeyEventHandler(_handleEvent);
  }

  void dispose() {
    if (!_installed) return;
    RawKeyboard.instance.removeListener(_recordEvent);
    FocusManager.instance.removeEarlyKeyEventHandler(_handleEvent);
    _rawEvent = null;
    _installed = false;
  }

  void _recordEvent(RawKeyEvent event) => _rawEvent = event;

  KeyEventResult _handleEvent(KeyEvent event) {
    final raw = _rawEvent;
    if (event.synthesized ||
        (event is! KeyDownEvent && event is! KeyRepeatEvent) ||
        raw is! RawKeyDownEvent ||
        raw.logicalKey != event.logicalKey ||
        HardwareKeyboard.instance.isShiftPressed) {
      return KeyEventResult.ignored;
    }
    final data = raw.data;
    // Virtual IMEs can supply real scan codes (Gboard does). Device identity,
    // rather than a zero scan code, distinguishes them from physical keyboards.
    if (data is! RawKeyEventDataAndroid ||
        data.deviceId != -1 ||
        !data.isShiftPressed ||
        data.isControlPressed ||
        data.isAltPressed ||
        data.isMetaPressed) {
      return KeyEventResult.ignored;
    }

    final context = FocusManager.instance.primaryFocus?.context;
    final editor = context?.findAncestorWidgetOfExactType<EditableText>();
    if (context == null || editor == null || !editor.selectionEnabled) {
      return KeyEventResult.ignored;
    }
    final Intent intent;
    switch (event.logicalKey) {
      case LogicalKeyboardKey.arrowLeft:
      case LogicalKeyboardKey.arrowRight:
        intent = ExtendSelectionByCharacterIntent(
          forward: event.logicalKey == LogicalKeyboardKey.arrowRight,
          collapseSelection: false,
        );
      case LogicalKeyboardKey.arrowUp:
      case LogicalKeyboardKey.arrowDown:
        intent = ExtendSelectionVerticallyToAdjacentLineIntent(
          forward: event.logicalKey == LogicalKeyboardKey.arrowDown,
          collapseSelection: false,
        );
      default:
        return KeyEventResult.ignored;
    }
    final handler = Actions.handler(context, intent);
    if (handler == null) return KeyEventResult.ignored;
    handler();
    return KeyEventResult.handled;
  }
}
