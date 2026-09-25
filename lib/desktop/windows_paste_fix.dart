import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Normalizes the Windows clipboard history's malformed Ctrl+V events.
/// See https://github.com/flutter/flutter/issues/143997.
class WindowsPasteFix with WidgetsBindingObserver {
  WindowsPasteFix._();

  static final WindowsPasteFix instance = WindowsPasteFix._();

  // Windows reports a zero scan code for every key in this sequence.
  static const _unmappedPhysical = 0x1600000000;
  static const _sequence = [
    (ui.KeyEventType.down, LogicalKeyboardKey.controlLeft, false),
    (ui.KeyEventType.up, LogicalKeyboardKey.controlLeft, true),
    (ui.KeyEventType.down, LogicalKeyboardKey.keyV, false),
    (ui.KeyEventType.up, LogicalKeyboardKey.keyV, false),
    (ui.KeyEventType.down, LogicalKeyboardKey.controlLeft, true),
    (ui.KeyEventType.up, LogicalKeyboardKey.controlLeft, true),
  ];

  ui.KeyDataCallback? _original;
  bool _installRequested = false;
  int _step = 0;
  Timer? _timeout;
  final Map<int, ui.KeyData> _pressed = {};

  void install() {
    if (kIsWeb ||
        defaultTargetPlatform != TargetPlatform.windows ||
        _installRequested) {
      return;
    }
    _installRequested = true;
    WidgetsBinding.instance.addObserver(this);
    _attach();
  }

  void _attach() {
    if (!_installRequested || _original != null) return;
    final dispatcher = WidgetsBinding.instance.platformDispatcher;
    final original = dispatcher.onKeyData;
    if (original == null) {
      // ServicesBinding installs this callback after syncKeyboardState returns.
      WidgetsBinding.instance.addPostFrameCallback((_) => _attach());
      return;
    }
    _original = original;
    dispatcher.onKeyData = _handleKeyData;
  }

  bool _matches(ui.KeyData data) {
    final expected = _sequence[_step];
    return data.physical == _unmappedPhysical &&
        data.type == expected.$1 &&
        data.logical == expected.$2.keyId &&
        data.synthesized == expected.$3;
  }

  bool _handleKeyData(ui.KeyData data) {
    // These probes select Flutter's keyboard transit mode. Swallowing one can
    // disable all subsequent input; it must also leave our sequence intact.
    if (data.physical == 0 && data.logical == 0) return _original!(data);

    if (!_matches(data)) {
      _reset(next: data);
      if (!_matches(data)) return _original!(data);
    }

    if (_step == 0) {
      final held = HardwareKeyboard.instance.physicalKeysPressed;
      if (held.contains(PhysicalKeyboardKey.controlLeft) ||
          held.contains(PhysicalKeyboardKey.keyV)) {
        // Never take ownership of a key the user is already holding.
        return _original!(data);
      }
      // One automatic chord should finish immediately. Lost events must not
      // leave a modifier held until the user presses another key.
      _timeout = Timer(const Duration(seconds: 1), _reset);
    }

    switch (_step++) {
      case 0:
        return _press(data, PhysicalKeyboardKey.controlLeft);
      case 1:
        return true; // Keep Ctrl held across the premature synthesized Ctrl up.
      case 2:
        return _press(data, PhysicalKeyboardKey.keyV);
      case 3:
        final up = _copy(data, PhysicalKeyboardKey.keyV.usbHidUsage);
        _pressed.remove(up.physical);
        final handled = _original!(up);
        // Release Ctrl with V, without depending on the trailing repair events.
        _releasePressed(next: data);
        return handled;
      case 4:
        return true; // Suppress the engine's duplicate Ctrl down.
      case 5:
        _reset();
        return true; // Ctrl is already released.
      default:
        throw StateError('Invalid Windows paste sequence');
    }
  }

  bool _press(ui.KeyData data, PhysicalKeyboardKey physical) {
    final down = _copy(data, physical.usbHidUsage);
    _pressed[down.physical] = down;
    return _original!(down);
  }

  ui.KeyData _copy(ui.KeyData data, int physical) => ui.KeyData(
    timeStamp: data.timeStamp,
    type: data.type,
    physical: physical,
    logical: data.logical,
    character: data.character,
    synthesized: data.synthesized,
    deviceType: data.deviceType,
  );

  void _releasePressed({ui.KeyData? next}) {
    final pressed = _pressed.values.toList().reversed;
    _pressed.clear();
    for (final down in pressed) {
      // A real key up can release our key itself; do not deliver two key ups.
      if (next?.type == ui.KeyEventType.up && next?.physical == down.physical) {
        continue;
      }
      _original!(
        ui.KeyData(
          timeStamp: next?.timeStamp ?? down.timeStamp,
          type: ui.KeyEventType.up,
          physical: down.physical,
          logical: down.logical,
          character: null,
          // Standalone releases have no following raw key message. Flutter
          // dispatches them immediately only when marked synthesized.
          synthesized: true,
          deviceType: down.deviceType,
        ),
      );
    }
  }

  void _reset({ui.KeyData? next}) {
    _step = 0;
    _timeout?.cancel();
    _timeout = null;
    _releasePressed(next: next);
  }

  @override
  void didChangeViewFocus(ui.ViewFocusEvent event) {
    if (event.state == ui.ViewFocusState.unfocused) _reset();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _reset();
  }

  @visibleForTesting
  void uninstall() {
    _reset();
    _installRequested = false;
    WidgetsBinding.instance.removeObserver(this);
    final dispatcher = WidgetsBinding.instance.platformDispatcher;
    if (dispatcher.onKeyData == _handleKeyData) {
      dispatcher.onKeyData = _original;
    }
    _original = null;
  }
}
