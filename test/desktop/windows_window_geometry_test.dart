import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/desktop/windows_window_geometry.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('app.desktop_window');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test(
    'reads full physical bounds separately from a top-left taskbar',
    () async {
      messenger.setMockMethodCallHandler(channel, (call) async {
        expect(call.method, 'getDisplays');
        return [
          {
            'bounds': {
              'left': -3840.0,
              'top': -2160.0,
              'right': 0.0,
              'bottom': 0.0,
            },
            'workArea': {
              'left': -3760.0,
              'top': -2080.0,
              'right': 0.0,
              'bottom': 0.0,
            },
            'scale': 2.0,
            'isPrimary': false,
          },
        ];
      });
      final display = (await getWindowsDisplays()).single;
      expect(display.bounds, const Rect.fromLTWH(-3840, -2160, 3840, 2160));
      expect(display.workArea, const Rect.fromLTWH(-3760, -2080, 3760, 2080));
      expect(display.scale, 2);
      expect(display.isPrimary, isFalse);
      expect(display.isValid, isTrue);
    },
  );

  test(
    'restores physical coordinates without the current Flutter DPI',
    () async {
      messenger.setMockMethodCallHandler(channel, (call) async {
        expect(call.method, 'restoreBounds');
        expect(call.arguments, {
          'left': -1400.0,
          'top': 100.0,
          'right': -120.0,
          'bottom': 960.0,
        });
        return null;
      });
      await restoreWindowsWindowBounds(
        const Rect.fromLTWH(-1400, 100, 1280, 860),
      );
    },
  );

  test('native restore failure is returned to the caller', () async {
    messenger.setMockMethodCallHandler(channel, (_) async {
      throw PlatformException(code: 'restore_bounds_failed');
    });
    await expectLater(
      restoreWindowsWindowBounds(const Rect.fromLTWH(100, 100, 1280, 860)),
      throwsA(isA<PlatformException>()),
    );
  });
}
