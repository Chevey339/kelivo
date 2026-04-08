import 'package:flutter/foundation.dart' show TargetPlatform;
import 'package:flutter/services.dart' show LogicalKeyboardKey;

bool supportsDesktopVoiceInputPlatform(TargetPlatform platform) {
  return platform == TargetPlatform.macOS ||
      platform == TargetPlatform.windows ||
      platform == TargetPlatform.linux;
}

Set<LogicalKeyboardKey> desktopVoiceHotkeyTrackedKeys(TargetPlatform platform) {
  return switch (platform) {
    TargetPlatform.macOS => <LogicalKeyboardKey>{
      LogicalKeyboardKey.keyR,
      LogicalKeyboardKey.metaLeft,
      LogicalKeyboardKey.metaRight,
      LogicalKeyboardKey.shiftLeft,
      LogicalKeyboardKey.shiftRight,
    },
    TargetPlatform.windows => <LogicalKeyboardKey>{
      LogicalKeyboardKey.keyR,
      LogicalKeyboardKey.controlLeft,
      LogicalKeyboardKey.controlRight,
      LogicalKeyboardKey.shiftLeft,
      LogicalKeyboardKey.shiftRight,
    },
    TargetPlatform.linux => <LogicalKeyboardKey>{
      LogicalKeyboardKey.keyR,
      LogicalKeyboardKey.controlLeft,
      LogicalKeyboardKey.controlRight,
      LogicalKeyboardKey.shiftLeft,
      LogicalKeyboardKey.shiftRight,
    },
    _ => <LogicalKeyboardKey>{},
  };
}

String desktopVoiceShortcutLabelForPlatform(TargetPlatform platform) {
  return switch (platform) {
    TargetPlatform.macOS => '⌘ + Shift + R',
    TargetPlatform.windows => 'Ctrl + Shift + R',
    TargetPlatform.linux => 'Ctrl + Shift + R',
    _ => '',
  };
}

bool isDesktopVoiceHotkeyDown({
  required TargetPlatform platform,
  required LogicalKeyboardKey eventKey,
  required Set<LogicalKeyboardKey> pressedKeys,
  required bool isDown,
}) {
  if (!supportsDesktopVoiceInputPlatform(platform) || !isDown) return false;

  final shift =
      pressedKeys.contains(LogicalKeyboardKey.shiftLeft) ||
      pressedKeys.contains(LogicalKeyboardKey.shiftRight);
  final modifierPressed = switch (platform) {
    TargetPlatform.macOS =>
      pressedKeys.contains(LogicalKeyboardKey.metaLeft) ||
          pressedKeys.contains(LogicalKeyboardKey.metaRight),
    TargetPlatform.windows =>
      pressedKeys.contains(LogicalKeyboardKey.controlLeft) ||
          pressedKeys.contains(LogicalKeyboardKey.controlRight),
    TargetPlatform.linux =>
      pressedKeys.contains(LogicalKeyboardKey.controlLeft) ||
          pressedKeys.contains(LogicalKeyboardKey.controlRight),
    _ => false,
  };

  return eventKey == LogicalKeyboardKey.keyR && shift && modifierPressed;
}
