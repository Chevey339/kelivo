import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/desktop/windows_window_geometry.dart';
import 'package:Kelivo/desktop/windows_window_placement.dart';

WindowsDisplay display(
  Rect workArea, {
  Rect? bounds,
  double scale = 1,
  bool isPrimary = false,
}) => WindowsDisplay(
  bounds: bounds ?? workArea,
  workArea: workArea,
  scale: scale,
  isPrimary: isPrimary,
);

void main() {
  final primary = display(
    const Rect.fromLTWH(0, 0, 1920, 1040),
    isPrimary: true,
  );
  final left = display(const Rect.fromLTWH(-1920, 0, 1920, 1040));
  const size = Size(1280, 860);

  Rect? resolve(Offset? position, {List<WindowsDisplay>? displays}) =>
      resolveWindowsWindowBounds(
        size: size,
        savedPosition: position,
        displays: displays ?? [primary, left],
      );

  test('right monitor moved left: obsolete position returns to primary', () {
    expect(
      resolve(const Offset(2100, 100)),
      const Rect.fromLTWH(320, 90, 1280, 860),
    );
  });

  test('disconnected secondary display falls back to primary', () {
    expect(
      resolve(const Offset(-1800, 100), displays: [primary]),
      const Rect.fromLTWH(320, 90, 1280, 860),
    );
  });

  test('valid negative position on left display is preserved', () {
    expect(
      resolve(const Offset(-1800, 100))!.topLeft,
      const Offset(-1800, 100),
    );
  });

  test('valid negative position on upper display is preserved', () {
    final upper = display(const Rect.fromLTWH(0, -1080, 1920, 1040));
    expect(
      resolve(const Offset(100, -1000), displays: [primary, upper])!.topLeft,
      const Offset(100, -1000),
    );
  });

  test('a gap inside the combined desktop is not a connected display', () {
    final upperLeft = display(const Rect.fromLTWH(-1920, -1080, 1920, 1040));
    expect(
      resolve(
        const Offset(-1800, 100),
        displays: [primary, upperLeft],
      )!.topLeft,
      const Offset(320, 90),
    );
  });

  test('partially off-screen window with reachable drag area is preserved', () {
    expect(
      resolve(const Offset(-100, 100), displays: [primary])!.topLeft,
      const Offset(-100, 100),
    );
  });

  test('content intersection does not permit a hidden title bar', () {
    expect(
      resolve(const Offset(100, -200), displays: [primary])!.topLeft,
      const Offset(100, 0),
    );
  });

  test('exposing only the caption buttons is not a reachable drag area', () {
    expect(
      resolve(const Offset(-1200, 100), displays: [primary])!.topLeft,
      const Offset(0, 100),
    );
  });

  test('one-pixel intersection is corrected rather than retained', () {
    expect(
      resolve(const Offset(1919, 100), displays: [primary])!.topLeft,
      const Offset(640, 100),
    );
  });

  test('mixed-DPI monitors use physical origins and target logical size', () {
    final scaledLeft = display(
      const Rect.fromLTWH(-3840, 0, 3840, 2080),
      scale: 2,
    );
    expect(
      resolve(const Offset(-3600, 200), displays: [primary, scaledLeft]),
      const Rect.fromLTWH(-3600, 200, 2560, 1720),
    );
  });

  for (final primaryFirst in [true, false]) {
    for (final (position, expected) in const [
      (Offset(100, 100), Offset(100, 100)),
      (Offset(100, 300), Offset(100, 300)),
      (Offset(-100, 300), Offset(-100, 300)),
      (Offset(100, -100), Offset(100, 0)),
    ]) {
      test(
        'primary window at $position keeps its DPI with primaryFirst=$primaryFirst',
        () {
          final scaledRight = display(
            const Rect.fromLTWH(1920, 0, 3840, 2080),
            scale: 2,
          );
          expect(
            resolve(
              position,
              displays: primaryFirst
                  ? [primary, scaledRight]
                  : [scaledRight, primary],
            ),
            expected & size,
          );
        },
      );
    }
  }

  test(
    'mixed-DPI spanning window is moved into the screen used for sizing',
    () {
      final scaledLeft = display(
        const Rect.fromLTWH(-3840, 0, 3840, 2080),
        scale: 2,
      );
      // At x=-800, sizing for the left screen would instead put most of the
      // resulting physical window on the 100% primary screen.
      expect(
        resolve(const Offset(-800, 100), displays: [primary, scaledLeft]),
        const Rect.fromLTWH(-2560, 100, 2560, 1720),
      );
    },
  );

  test(
    'mixed-DPI spanning window keeps a position with consistent ownership',
    () {
      final scaledLeft = display(
        const Rect.fromLTWH(-3840, 0, 3840, 2080),
        scale: 2,
      );
      expect(
        resolve(const Offset(-1100, 100), displays: [primary, scaledLeft]),
        const Rect.fromLTWH(-1100, 100, 2560, 1720),
      );
    },
  );

  for (final (taskbar, workArea, position) in const [
    ('bottom', Rect.fromLTWH(0, 0, 1920, 1040), Offset(-920, 100)),
    ('left', Rect.fromLTWH(40, 0, 1880, 1080), Offset(-920, 100)),
    ('top', Rect.fromLTWH(0, 40, 1920, 1040), Offset(-970, 20)),
  ]) {
    test('DPI ownership includes the primary $taskbar taskbar', () {
      final primaryWithTaskbar = display(
        workArea,
        bounds: const Rect.fromLTWH(0, 0, 1920, 1080),
        isPrimary: true,
      );
      final scaledLeft = display(
        const Rect.fromLTWH(-3840, 0, 3840, 2080),
        bounds: const Rect.fromLTWH(-3840, 0, 3840, 2160),
        scale: 2,
      );
      // Work-area intersections favour the left screen, but the primary owns
      // more of the full physical frame. Restore inside the sizing monitor.
      expect(
        resolve(position, displays: [primaryWithTaskbar, scaledLeft]),
        Rect.fromLTWH(-2560, position.dy, 2560, 1720),
      );
    });
  }

  for (final x in [-800.0, -50.0]) {
    test('same-DPI spanning window at x=$x retains its position', () {
      expect(resolve(Offset(x, 100)), Rect.fromLTWH(x, 100, 1280, 860));
    });
  }

  test('mixed-DPI work areas cannot falsely overlap a removed monitor', () {
    final scaledRight = display(
      const Rect.fromLTWH(3840, 0, 3840, 2080),
      scale: 2,
    );
    expect(
      resolveWindowsWindowBounds(
        size: const Size(960, 640),
        savedPosition: const Offset(1920, 100),
        displays: [primary, scaledRight],
      ),
      const Rect.fromLTWH(480, 200, 960, 640),
    );
  });

  test('fallback is centered within a scaled primary work area', () {
    final scaledPrimary = display(
      const Rect.fromLTWH(60, 30, 2880, 1560),
      scale: 1.5,
    );
    expect(
      resolveWindowsWindowBounds(
        size: size,
        savedPosition: null,
        displays: [scaledPrimary],
      ),
      const Rect.fromLTWH(540, 165, 1920, 1290),
    );
  });

  test('oversized saved window fits the work area excluding taskbars', () {
    final screen = display(const Rect.fromLTWH(48, 32, 1552, 828));
    expect(
      resolveWindowsWindowBounds(
        size: const Size(2400, 1600),
        savedPosition: const Offset(100, 100),
        displays: [screen],
      ),
      const Rect.fromLTWH(48, 32, 1552, 828),
    );
  });

  test('tiny work area keeps the UI minimum and its title bar at the top', () {
    final screen = display(const Rect.fromLTWH(0, 30, 800, 570));
    expect(
      resolveWindowsWindowBounds(
        size: size,
        savedPosition: null,
        displays: [screen],
      ),
      const Rect.fromLTWH(0, 30, 960, 640),
    );
  });

  test('invalid display metadata leaves restoration to the initial window', () {
    expect(
      resolveWindowsWindowBounds(
        size: size,
        savedPosition: const Offset(2100, 100),
        displays: [
          const WindowsDisplay(
            bounds: Rect.zero,
            workArea: Rect.zero,
            scale: 1,
          ),
          WindowsDisplay(
            bounds: Offset.zero & size,
            workArea: Offset.zero & size,
            scale: 0,
          ),
        ],
      ),
      isNull,
    );
  });
}
