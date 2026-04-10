import 'package:Kelivo/features/home/services/voice_input_service.dart';
import 'package:Kelivo/features/home/utils/desktop_voice_input_utils.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('desktop voice input platform support', () {
    test('supports macOS, Windows, and Linux desktop voice input', () {
      expect(supportsDesktopVoiceInputPlatform(TargetPlatform.macOS), isTrue);
      expect(supportsDesktopVoiceInputPlatform(TargetPlatform.windows), isTrue);
      expect(supportsDesktopVoiceInputPlatform(TargetPlatform.linux), isTrue);
    });

    test('keeps mobile platforms out of desktop voice input support', () {
      expect(
        supportsDesktopVoiceInputPlatform(TargetPlatform.android),
        isFalse,
      );
      expect(supportsDesktopVoiceInputPlatform(TargetPlatform.iOS), isFalse);
    });

    test('returns platform-specific desktop voice shortcut labels', () {
      expect(
        desktopVoiceShortcutLabelForPlatform(TargetPlatform.macOS),
        '⌘ + Shift + R',
      );
      expect(
        desktopVoiceShortcutLabelForPlatform(TargetPlatform.windows),
        'Ctrl + Shift + R',
      );
      expect(
        desktopVoiceShortcutLabelForPlatform(TargetPlatform.linux),
        'Ctrl + Shift + R',
      );
    });

    test('matches desktop voice hotkeys per platform', () {
      expect(
        isDesktopVoiceHotkeyDown(
          platform: TargetPlatform.macOS,
          eventKey: LogicalKeyboardKey.keyR,
          pressedKeys: <LogicalKeyboardKey>{
            LogicalKeyboardKey.keyR,
            LogicalKeyboardKey.metaLeft,
            LogicalKeyboardKey.shiftLeft,
          },
          isDown: true,
        ),
        isTrue,
      );

      expect(
        isDesktopVoiceHotkeyDown(
          platform: TargetPlatform.windows,
          eventKey: LogicalKeyboardKey.keyR,
          pressedKeys: <LogicalKeyboardKey>{
            LogicalKeyboardKey.keyR,
            LogicalKeyboardKey.controlLeft,
            LogicalKeyboardKey.shiftLeft,
          },
          isDown: true,
        ),
        isTrue,
      );

      expect(
        isDesktopVoiceHotkeyDown(
          platform: TargetPlatform.linux,
          eventKey: LogicalKeyboardKey.keyR,
          pressedKeys: <LogicalKeyboardKey>{
            LogicalKeyboardKey.keyR,
            LogicalKeyboardKey.controlLeft,
            LogicalKeyboardKey.shiftLeft,
          },
          isDown: true,
        ),
        isTrue,
      );

      expect(
        isDesktopVoiceHotkeyDown(
          platform: TargetPlatform.windows,
          eventKey: LogicalKeyboardKey.keyR,
          pressedKeys: <LogicalKeyboardKey>{
            LogicalKeyboardKey.keyR,
            LogicalKeyboardKey.metaLeft,
            LogicalKeyboardKey.shiftLeft,
          },
          isDown: true,
        ),
        isFalse,
      );

      expect(
        isDesktopVoiceHotkeyDown(
          platform: TargetPlatform.linux,
          eventKey: LogicalKeyboardKey.keyR,
          pressedKeys: <LogicalKeyboardKey>{
            LogicalKeyboardKey.keyR,
            LogicalKeyboardKey.metaLeft,
            LogicalKeyboardKey.shiftLeft,
          },
          isDown: true,
        ),
        isFalse,
      );
    });
  });

  group('linux voice input dependency checks', () {
    test('reports no missing dependencies when all commands exist', () {
      expect(
        missingLinuxVoiceInputDependencies(<String, bool>{
          'parecord': true,
          'ffmpeg': true,
        }),
        isEmpty,
      );
    });

    test('reports missing Linux recording commands', () {
      expect(
        missingLinuxVoiceInputDependencies(<String, bool>{
          'parecord': false,
          'ffmpeg': true,
        }),
        <String>['parecord'],
      );

      expect(
        missingLinuxVoiceInputDependencies(<String, bool>{
          'parecord': false,
          'ffmpeg': false,
        }),
        <String>['parecord', 'ffmpeg'],
      );
    });
  });
}
