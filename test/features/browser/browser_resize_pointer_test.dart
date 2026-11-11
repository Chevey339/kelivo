import 'dart:async';
import 'dart:ui' as ui;

import 'package:Kelivo/desktop/sidebar_resize_handle.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const channel = MethodChannel('app.sidebar_resize');

  Future<void> nativeEvent(
    WidgetTester tester,
    String method,
    Map<String, Object> args,
  ) {
    final result = Completer<void>();
    tester.binding.channelBuffers.push(
      channel.name,
      channel.codec.encodeMethodCall(MethodCall(method, args)),
      (_) => result.complete(),
    );
    return result.future;
  }

  Future<void> mountGrip(
    WidgetTester tester, {
    required ValueChanged<double> onDrag,
    required VoidCallback onEnd,
  }) => tester.pumpWidget(
    MaterialApp(
      home: Center(
        child: SizedBox(
          height: 400,
          child: SidebarResizeHandle(
            key: const ValueKey('grip'),
            visible: true,
            onDrag: onDrag,
            onDragEnd: onEnd,
          ),
        ),
      ),
    ),
  );

  testWidgets('entire grip has painted native hit coverage without overflow', (
    tester,
  ) async {
    final boundary = GlobalKey();
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Theme(
          data: ThemeData(),
          child: Center(
            child: RepaintBoundary(
              key: boundary,
              child: SizedBox(
                width: 20,
                height: 100,
                child: Center(
                  child: SidebarResizeHandle(visible: true, onDrag: (_) {}),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.runAsync(() async {
      final image =
          await (boundary.currentContext!.findRenderObject()
                  as RenderRepaintBoundary)
              .toImage(pixelRatio: 1);
      try {
        final pixels = (await image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        ))!;
        int alpha(int x) => pixels.getUint8((50 * image.width + x) * 4 + 3);
        for (var x = 7; x < 13; x++) {
          expect(alpha(x), greaterThan(0), reason: 'native hit coverage at $x');
        }
        expect(alpha(6), 0);
        expect(alpha(13), 0);
      } finally {
        image.dispose();
      }
    });
  });

  testWidgets(
    'mouse resize follows both directions outside grip until release',
    (tester) async {
      var total = 0.0;
      var ends = 0;
      await mountGrip(tester, onDrag: (dx) => total += dx, onEnd: () => ends++);
      final origin = tester.getCenter(find.byKey(const ValueKey('grip')));
      final mouse = await tester.createGesture(
        kind: PointerDeviceKind.mouse,
        pointer: 7,
      );
      await mouse.addPointer(location: origin);
      await mouse.down(origin);
      await mouse.moveTo(origin + const Offset(-150, -240));
      expect(total, -150);
      await mouse.moveTo(origin + const Offset(80, 240));
      expect(total, 80);
      await mouse.up();
      expect(ends, 1);
      await mouse.moveTo(origin + const Offset(-300, 0));
      await mouse.moveTo(origin);
      expect(total, 80);
      expect(ends, 1);
      await mouse.removePointer();
    },
  );

  testWidgets(
    'cancel and missing primary button end a resize without hover drift',
    (tester) async {
      var total = 0.0;
      var ends = 0;
      await mountGrip(tester, onDrag: (dx) => total += dx, onEnd: () => ends++);
      final origin = tester.getCenter(find.byKey(const ValueKey('grip')));
      final mouse = await tester.createGesture(
        kind: PointerDeviceKind.mouse,
        pointer: 7,
      );
      await mouse.addPointer(location: origin);
      await mouse.down(origin);
      await mouse.moveBy(const Offset(-30, 0));
      await mouse.cancel();
      expect(total, -30);
      expect(ends, 1);
      await mouse.moveTo(origin);
      expect(total, -30);
      await mouse.down(origin);
      await mouse.moveBy(const Offset(15, 0));
      // AppKit can lose the up while replacing a native overlay. The next
      // no-button event must terminate rather than applying its large delta.
      await tester.sendEventToBinding(
        PointerMoveEvent(
          pointer: 7,
          kind: PointerDeviceKind.mouse,
          position: origin + const Offset(200, 0),
          buttons: 0,
        ),
      );
      expect(total, -15);
      expect(ends, 2);
      await mouse.up();
      await mouse.moveTo(origin);
      expect(total, -15);
      expect(ends, 2);
      await mouse.removePointer();
    },
  );

  testWidgets(
    'native hover bounds follow the grip while a press keeps its timestamp',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      final calls = <MethodCall>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
        call,
      ) async {
        calls.add(call);
        return call.method == 'begin' ? true : null;
      });
      var left = 300.0;
      late StateSetter update;
      try {
        await tester.pumpWidget(
          MaterialApp(
            home: StatefulBuilder(
              builder: (_, setState) {
                update = setState;
                return Stack(
                  children: [
                    Positioned(
                      left: left,
                      top: 100,
                      width: 6,
                      height: 400,
                      child: SidebarResizeHandle(
                        key: const ValueKey('cursorGrip'),
                        visible: true,
                        onDrag: (_) {},
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        );
        final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
        await mouse.addPointer(location: const Offset(20, 20));
        await mouse.moveTo(const Offset(303, 200));
        await tester.pump();
        Map cursorArgs() =>
            calls.where((call) => call.method == 'cursor').last.arguments
                as Map;
        expect(cursorArgs()['bounds'], [300.0, 100.0, 6.0, 400.0]);
        await mouse.down(
          const Offset(303, 200),
          timeStamp: const Duration(seconds: 42),
        );
        final begin =
            calls.where((call) => call.method == 'begin').last.arguments as Map;
        expect(begin['timestampMicros'], 42000000);
        update(() => left = 360);
        await tester.pump();
        expect(cursorArgs()['bounds'], [360.0, 100.0, 6.0, 400.0]);
        await mouse.up();
        await mouse.moveTo(const Offset(20, 20));
        await tester.pump();
        expect(cursorArgs()['bounds'], isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        expect(cursorArgs()['bounds'], isNull);
        await mouse.removePointer();
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          null,
        );
        debugDefaultTargetPlatformOverride = null;
      }
    },
  );

  for (final accepted in [false, true]) {
    testWidgets(
      'drag completes before delayed native ${accepted ? 'accept' : 'reject'} without losing motion',
      (tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
        final reply = Completer<bool>();
        int? session;
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          (call) async {
            if (call.method == 'begin') {
              session = (call.arguments as Map)['session'] as int;
              return reply.future;
            }
            return null;
          },
        );
        var total = 0.0;
        var ends = 0;
        try {
          await mountGrip(
            tester,
            onDrag: (dx) => total += dx,
            onEnd: () => ends++,
          );
          final origin = tester.getCenter(find.byKey(const ValueKey('grip')));
          final mouse = await tester.createGesture(
            kind: PointerDeviceKind.mouse,
          );
          await mouse.addPointer(location: origin);
          await mouse.down(origin);
          await mouse.moveBy(const Offset(-40, 0));
          expect(
            total,
            -40,
            reason: 'pending native call must not freeze Flutter',
          );
          await mouse.moveBy(const Offset(25, 0));
          await mouse.up();
          expect(total, -15);
          expect(ends, 1);
          reply.complete(accepted);
          await tester.pump();
          await nativeEvent(tester, 'position', {'session': session!, 'x': 0});
          await nativeEvent(tester, 'end', {'session': session!});
          await mouse.moveTo(origin);
          expect(total, -15);
          expect(ends, 1);
          await mouse.removePointer();
        } finally {
          if (!reply.isCompleted) reply.complete(false);
          await tester.pumpWidget(const SizedBox.shrink());
          tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            channel,
            null,
          );
          debugDefaultTargetPlatformOverride = null;
        }
      },
    );
  }

  testWidgets(
    'native capture keeps one pointer stream across consecutive drags',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      final calls = <MethodCall>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
        call,
      ) async {
        calls.add(call);
        return call.method == 'begin' ? true : null;
      });
      var total = 0.0;
      var ends = 0;
      int latestSession() =>
          (calls.where((call) => call.method == 'begin').last.arguments
                  as Map)['session']
              as int;
      try {
        await mountGrip(
          tester,
          onDrag: (dx) => total += dx,
          onEnd: () => ends++,
        );
        final origin = tester.getCenter(find.byKey(const ValueKey('grip')));
        final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
        await mouse.addPointer(location: origin);
        await mouse.down(origin);
        final first = latestSession();
        await mouse.moveBy(const Offset(-80, 0));
        await mouse.moveBy(const Offset(120, 0));
        expect(total, 40);
        await mouse.up();
        expect(ends, 1);
        await mouse.moveTo(origin);
        await mouse.down(origin);
        final second = latestSession();
        expect(second, isNot(first));
        await nativeEvent(tester, 'end', {'session': first});
        expect(ends, 1, reason: 'old session cannot release the next drag');
        await mouse.moveBy(const Offset(-12, 0));
        expect(total, 28);
        await nativeEvent(tester, 'end', {'session': second});
        expect(ends, 2);
        await mouse.moveBy(const Offset(90, 0));
        expect(
          total,
          28,
          reason: 'native cancellation also ends Dart dragging',
        );
        await mouse.up();
        expect(ends, 2);
        await mouse.moveTo(origin);
        await mouse.down(origin);
        final third = latestSession();
        await tester.pumpWidget(const SizedBox.shrink());
        expect(
          calls.any((call) => call.method == 'end' && call.arguments == third),
          isTrue,
        );
        await mouse.up();
        await mouse.removePointer();
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          null,
        );
        debugDefaultTargetPlatformOverride = null;
      }
    },
  );

  testWidgets(
    'focus loss ends capture and no delayed update can restart resize',
    (tester) async {
      var total = 0.0;
      var ends = 0;
      await mountGrip(tester, onDrag: (dx) => total += dx, onEnd: () => ends++);
      final mouse = await tester.createGesture(
        kind: PointerDeviceKind.mouse,
        pointer: 7,
      );
      final origin = tester.getCenter(find.byKey(const ValueKey('grip')));
      await mouse.down(origin);
      await mouse.moveBy(const Offset(20, 0));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      expect(ends, 1);
      await mouse.moveBy(const Offset(60, 0));
      expect(total, 20);
      await mouse.up();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      expect(ends, 1);
    },
  );
}
