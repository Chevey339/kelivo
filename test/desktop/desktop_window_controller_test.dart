import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';

import 'package:Kelivo/desktop/desktop_window_controller.dart';
import 'package:Kelivo/desktop/windows_window_geometry.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const windowChannel = MethodChannel('window_manager');
  const geometryChannel = MethodChannel('app.desktop_window');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const primary = WindowsDisplay(
    bounds: Rect.fromLTWH(0, 0, 1920, 1080),
    workArea: Rect.fromLTWH(0, 0, 1920, 1040),
    scale: 1,
    isPrimary: true,
  );
  const left = WindowsDisplay(
    bounds: Rect.fromLTWH(-3840, 0, 3840, 2160),
    workArea: Rect.fromLTWH(-3840, 0, 3840, 2080),
    scale: 2,
  );
  late DesktopWindowController controller;
  late _NativeWindow window;
  late List<WindowsDisplay> displays;
  AsyncCallback? ready;
  bool screenFailure = false;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    window = _NativeWindow(() => displays);
    displays = [primary, left];
    ready = null;
    screenFailure = false;
    controller = DesktopWindowController.forTesting(
      (callback) => ready = callback,
    );
    messenger.setMockMethodCallHandler(windowChannel, window.handle);
    messenger.setMockMethodCallHandler(geometryChannel, (call) async {
      if (screenFailure) throw PlatformException(code: 'no_displays');
      return switch (call.method) {
        'getDisplays' => displays.map(_displayMap).toList(),
        'restoreBounds' => await window.restoreBounds(call),
        _ => throw UnsupportedError(call.method),
      };
    });
  });
  tearDown(() {
    windowManager.removeListener(controller);
    messenger.setMockMethodCallHandler(windowChannel, null);
    messenger.setMockMethodCallHandler(geometryChannel, null);
  });

  Future<void> initialize() async {
    await controller.initializeAndShow();
    expect(ready, isNotNull);
    await ready!();
  }

  void windowsTest(String description, WidgetTesterCallback body) {
    testWidgets(description, (tester) async {
      try {
        await body(tester);
      } finally {
        controller.onWindowMinimize();
      }
    }, variant: TargetPlatformVariant.only(TargetPlatform.windows));
  }

  windowsTest('obsolete right-screen position is safely restored', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'window_physical_pos_x_v1': 2100.0,
      'window_physical_pos_y_v1': 100.0,
    });
    await initialize();
    expect(window.bounds, const Rect.fromLTWH(320, 90, 1280, 860));
  });

  windowsTest('physical position round-trips after the display scale changes', (
    tester,
  ) async {
    // window_manager reads dart:ui's window DPI, not the test view override.
    final originalScale = windowManager.getDevicePixelRatio();
    window.bounds = Rect.fromLTWH(
      -3600,
      200,
      1280 * originalScale,
      860 * originalScale,
    );
    controller.onWindowMove();
    await tester.pump(const Duration(milliseconds: 400));
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getDouble('window_physical_pos_x_v1'), -3600);
    expect(prefs.getDouble('window_width_v1'), 1280);

    window.bounds = const Rect.fromLTWH(10, 10, 1280, 720);
    await initialize();
    expect(window.bounds, const Rect.fromLTWH(-3600, 200, 2560, 1720));
  });

  for (final y in [100.0, 300.0]) {
    windowsTest(
      'a scaled secondary does not move or enlarge a primary window at y=$y',
      (tester) async {
        displays = [
          primary,
          const WindowsDisplay(
            bounds: Rect.fromLTWH(1920, 0, 3840, 2160),
            workArea: Rect.fromLTWH(1920, 0, 3840, 2080),
            scale: 2,
          ),
        ];
        SharedPreferences.setMockInitialValues({
          'window_physical_pos_x_v1': 100.0,
          'window_physical_pos_y_v1': y,
          'window_width_v1': 1280.0,
          'window_height_v1': 860.0,
        });
        await initialize();
        expect(window.bounds, Rect.fromLTWH(100, y, 1280, 860));
      },
    );
  }

  windowsTest(
    'bounds restore finishes before maximizing on the saved monitor',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        'window_physical_pos_x_v1': -3600.0,
        'window_physical_pos_y_v1': 200.0,
        'window_maximized_v1': true,
      });
      window.onRestoreBounds = () {
        // Transient native notifications must not overwrite the saved frame.
        controller.onWindowMove();
        controller.onWindowResize();
      };
      window.restoreGate = Completer<void>();
      await controller.initializeAndShow();
      final restoring = ready!();
      await tester.pump();
      expect(window.calls, contains('restoreBounds'));
      expect(window.calls, isNot(contains('maximize')));
      window.restoreGate!.complete();
      await restoring;
      expect(
        window.boundsAtMaximize,
        const Rect.fromLTWH(-3600, 200, 2560, 1720),
      );
      expect(window.calls.last, 'maximize');
      await tester.pump(const Duration(milliseconds: 500));
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getDouble('window_physical_pos_x_v1'), -3600);
      expect(prefs.getBool('window_maximized_v1'), isTrue);
    },
  );

  windowsTest('a large high-DPI initial frame restores onto a low-DPI screen', (
    tester,
  ) async {
    displays = const [
      WindowsDisplay(
        bounds: Rect.fromLTWH(0, 0, 2560, 1440),
        workArea: Rect.fromLTWH(0, 0, 2560, 1360),
        scale: 2,
        isPrimary: true,
      ),
      WindowsDisplay(
        bounds: Rect.fromLTWH(-1920, 0, 1920, 1080),
        workArea: Rect.fromLTWH(-1920, 0, 1920, 1040),
        scale: 1,
      ),
    ];
    window.bounds = const Rect.fromLTWH(20, 20, 2560, 1440);
    window.nativeScale = 2;
    window.simulateDpiChanges = true;
    SharedPreferences.setMockInitialValues({
      'window_physical_pos_x_v1': -1400.0,
      'window_physical_pos_y_v1': 100.0,
      'window_width_v1': 1280.0,
      'window_height_v1': 860.0,
    });
    await initialize();
    expect(window.nativeScale, 1);
    expect(window.bounds, const Rect.fromLTWH(-1400, 100, 1280, 860));
    expect(window.calls.where((call) => call == 'restoreBounds'), hasLength(1));
  });

  windowsTest('failed screen discovery keeps the runner initial position', (
    tester,
  ) async {
    screenFailure = true;
    SharedPreferences.setMockInitialValues({
      'window_physical_pos_x_v1': 8000.0,
      'window_physical_pos_y_v1': 100.0,
    });
    await initialize();
    expect(window.bounds.topLeft, const Offset(10, 10));
    expect(
      window.bounds.size,
      const Size(1280, 860) * windowManager.getDevicePixelRatio(),
    );
  });

  windowsTest(
    'maximized, minimized and fullscreen geometry never overwrites normal bounds',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        'window_physical_pos_x_v1': -3600.0,
        'window_physical_pos_y_v1': 200.0,
        'window_width_v1': 1280.0,
        'window_height_v1': 860.0,
      });
      window.bounds = const Rect.fromLTWH(-32000, -32000, 160, 40);
      for (final state in ['maximized', 'minimized', 'fullscreen']) {
        window.maximized = state == 'maximized';
        window.minimized = state == 'minimized';
        window.fullscreen = state == 'fullscreen';
        if (window.maximized) controller.onWindowMaximize();
        if (window.fullscreen) controller.onWindowEnterFullScreen();
        controller.onWindowMove();
        controller.onWindowResize();
        await tester.pump(const Duration(milliseconds: 400));
        final prefs = await SharedPreferences.getInstance();
        expect(
          prefs.getDouble('window_physical_pos_x_v1'),
          -3600,
          reason: state,
        );
        expect(prefs.getDouble('window_width_v1'), 1280, reason: state);
      }
    },
  );

  windowsTest('maximize invalidates a bounds read already in flight', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'window_physical_pos_x_v1': -3600.0,
      'window_physical_pos_y_v1': 200.0,
    });
    final reply = Completer<Map<String, double>>();
    window.boundsReply = reply.future;
    controller.onWindowMove();
    await tester.pump(const Duration(milliseconds: 400));
    expect(window.calls, contains('getBounds'));
    controller.onWindowMaximize();
    reply.complete({'x': -8, 'y': -8, 'width': 1936, 'height': 1056});
    await tester.pump();
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getDouble('window_physical_pos_x_v1'), -3600);
  });

  windowsTest('unmaximizing resumes saving physical normal bounds', (
    tester,
  ) async {
    final scale = windowManager.getDevicePixelRatio();
    window.bounds = Rect.fromLTWH(300, 150, 1280 * scale, 860 * scale);
    controller.onWindowUnmaximize();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getDouble('window_physical_pos_x_v1'), 300);
    expect(prefs.getDouble('window_physical_pos_y_v1'), 150);
    expect(prefs.getDouble('window_width_v1'), 1280);
    expect(prefs.getBool('window_maximized_v1'), isFalse);
  });
}

/// Emulates the plugin's documented logical/physical conversion at the channel
/// boundary. Tests assert physical native bounds, not just outgoing arguments.
class _NativeWindow {
  _NativeWindow(this.displays);

  final List<WindowsDisplay> Function() displays;
  Rect bounds = const Rect.fromLTWH(10, 10, 1280, 720);
  bool maximized = false;
  bool minimized = false;
  bool fullscreen = false;
  Rect? boundsAtMaximize;
  VoidCallback? onRestoreBounds;
  Completer<void>? restoreGate;
  bool simulateDpiChanges = false;
  double nativeScale = 1;
  Future<Map<String, double>>? boundsReply;
  final calls = <String>[];

  void applyBounds(Rect pending, {bool restoring = false}) {
    var nextScale = nativeScale;
    if (simulateDpiChanges) {
      var largest = 0.0;
      for (final display in displays()) {
        final intersection = pending.intersect(display.bounds);
        final area = intersection.isEmpty
            ? 0.0
            : intersection.width * intersection.height;
        if (area > largest) {
          largest = area;
          nextScale = display.scale;
        }
      }
    }
    // Ordinary SetWindowPos follows default WM_GETDPISCALEDSIZE scaling.
    // The physical restore operation explicitly keeps the requested bounds.
    bounds = restoring
        ? pending
        : pending.topLeft & (pending.size * (nextScale / nativeScale));
    nativeScale = nextScale;
  }

  Future<Object?> restoreBounds(MethodCall call) async {
    calls.add(call.method);
    await restoreGate?.future;
    final args = call.arguments as Map;
    applyBounds(
      Rect.fromLTRB(args['left'], args['top'], args['right'], args['bottom']),
      restoring: true,
    );
    onRestoreBounds?.call();
    return null;
  }

  Future<Object?> handle(MethodCall call) async {
    calls.add(call.method);
    final args = (call.arguments as Map?) ?? const {};
    switch (call.method) {
      case 'isMaximized':
        return maximized;
      case 'isMinimized':
        return minimized;
      case 'isFullScreen':
        return fullscreen;
      case 'getBounds':
        if (boundsReply != null) return boundsReply;
        final scale = args['devicePixelRatio'] as double;
        return {
          'x': bounds.left / scale,
          'y': bounds.top / scale,
          'width': bounds.width / scale,
          'height': bounds.height / scale,
        };
      case 'setBounds':
        final scale = args['devicePixelRatio'] as double;
        applyBounds(
          Rect.fromLTWH(
            args['x'] == null ? bounds.left : args['x'] * scale,
            args['y'] == null ? bounds.top : args['y'] * scale,
            args['width'] == null ? bounds.width : args['width'] * scale,
            args['height'] == null ? bounds.height : args['height'] * scale,
          ),
        );
        return null;
      case 'maximize':
        boundsAtMaximize = bounds;
        maximized = true;
        return null;
      case 'ensureInitialized':
      case 'setTitleBarStyle':
        return null;
      default:
        throw UnsupportedError(call.method);
    }
  }
}

Map<String, Object> _displayMap(WindowsDisplay display) {
  Map<String, double> rect(Rect bounds) => {
    'left': bounds.left,
    'top': bounds.top,
    'right': bounds.right,
    'bottom': bounds.bottom,
  };
  return {
    'bounds': rect(display.bounds),
    'workArea': rect(display.workArea),
    'scale': display.scale,
    'isPrimary': display.isPrimary,
  };
}
