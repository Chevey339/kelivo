import 'dart:async';
import 'dart:ui' as ui;

import 'package:Kelivo/features/browser/browser_panel_controller.dart';
import 'package:Kelivo/features/browser/widgets/browser_window_chrome.dart';
import 'package:Kelivo/features/home/pages/home_desktop_layout.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'panel requests need a live host and detach clears stale conversation',
    () {
      final controller = BrowserPanelController();
      expect(controller.open(conversationId: 'one'), isFalse);
      controller.attachHost();
      expect(controller.open(conversationId: 'one'), isTrue);
      expect(controller.conversationId, 'one');
      controller.close();
      expect(controller.isOpen, isFalse);
      controller.open(conversationId: 'two');
      controller.detachHost();
      expect(controller.isOpen, isFalse);
      expect(controller.conversationId, isNull);
      expect(controller.hasHost, isFalse);
      controller.dispose();
    },
  );

  test(
    'tab handoff survives open but never leaks into ordinary chat entry',
    () {
      final controller = BrowserPanelController();
      expect(
        controller.open(conversationId: 'chat-a', initialTabId: 'foreign-tab'),
        isFalse,
      );
      expect(controller.initialTabId, isNull);
      controller.attachHost();
      controller.open(conversationId: 'chat-a', initialTabId: 'foreign-tab');
      expect(controller.conversationId, 'chat-a');
      expect(controller.initialTabId, 'foreign-tab');
      controller.open(conversationId: 'chat-a');
      expect(controller.initialTabId, isNull);
      controller.open(conversationId: 'chat-a', initialTabId: 'unowned-tab');
      controller.close();
      expect(controller.initialTabId, isNull);
      controller.open(conversationId: 'chat-a', initialTabId: 'last-tab');
      controller.detachHost();
      expect(controller.initialTabId, isNull);
      expect(controller.conversationId, isNull);
      controller.dispose();
    },
  );

  testWidgets(
    'pane resizes beside mounted chat and only activates inside clicks',
    (tester) async {
      tester.view.physicalSize = const Size(1100, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final controller = BrowserPanelController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Row(
            children: [
              const SizedBox(
                width: 100,
                height: double.infinity,
                child: ColoredBox(
                  key: ValueKey('otherPane'),
                  color: Colors.grey,
                ),
              ),
              Expanded(
                child: BrowserSidePanelHost(
                  controller: controller,
                  child: const ColoredBox(
                    key: ValueKey('chatPane'),
                    color: Colors.white,
                    child: SizedBox.expand(),
                  ),
                  panelBuilder: (context, id, active, close) => ColoredBox(
                    key: const ValueKey('browserPane'),
                    color: Colors.blue,
                    child: Center(
                      child: Text('$id:${active ? 'active' : 'inactive'}'),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
      final chat = find.byKey(const ValueKey('chatPane'));
      final chatElement = tester.element(chat);
      controller.open(conversationId: 'one');
      await tester.pump();
      final panel = find.byKey(const ValueKey('browserPane'));
      expect(tester.getSize(panel).width, 520);
      expect(find.text('one:inactive'), findsOneWidget);
      await tester.tap(chat);
      await tester.pump();
      expect(find.text('one:inactive'), findsOneWidget);
      await tester.tap(panel);
      await tester.pump();
      expect(find.text('one:active'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('otherPane')));
      await tester.pump();
      expect(find.text('one:inactive'), findsOneWidget);
      await tester.drag(
        find.byKey(const ValueKey('browserPanelResizeHandle')),
        const Offset(-80, 0),
      );
      await tester.pump();
      expect(tester.getSize(panel).width, greaterThan(520));
      expect(tester.getSize(chat).width, greaterThanOrEqualTo(280));
      expect(tester.element(chat), same(chatElement));
      controller.close();
      await tester.pump();
      expect(panel, findsNothing);
      expect(tester.getSize(chat).width, 1000);
      expect(tester.element(chat), same(chatElement));
      controller.open(conversationId: 'two');
      await tester.pump();
      expect(find.text('two:inactive'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      expect(controller.hasHost, isFalse);
      expect(controller.isOpen, isFalse);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'divider retains every pointer delta received before the next frame',
    (tester) async {
      tester.view.physicalSize = const Size(1100, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final controller = BrowserPanelController();
      await tester.pumpWidget(
        MaterialApp(
          home: BrowserSidePanelHost(
            controller: controller,
            child: const SizedBox.expand(),
            panelBuilder: (_, id, active, close) =>
                const SizedBox.expand(key: ValueKey('resizePane')),
          ),
        ),
      );
      controller.open();
      await tester.pump();
      final pane = find.byKey(const ValueKey('resizePane'));
      final gesture = await tester.startGesture(
        tester.getCenter(
          find.byKey(const ValueKey('browserPanelResizeHandle')),
        ),
      );
      await gesture.moveBy(const Offset(-30, 0));
      await tester.pump();
      final before = tester.getSize(pane).width;
      await gesture.moveBy(const Offset(-10, 0));
      await gesture.moveBy(const Offset(-10, 0));
      await gesture.moveBy(const Offset(-10, 0));
      await gesture.up();
      await tester.pump();
      expect(tester.getSize(pane).width, before + 30);
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'pane clips overflowing material after divider resize while keeping input live',
    (tester) async {
      tester.view.physicalSize = const Size(1100, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final controller = BrowserPanelController();
      final boundaryKey = GlobalKey();
      var presses = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: RepaintBoundary(
            key: boundaryKey,
            child: BrowserSidePanelHost(
              controller: controller,
              child: const ColoredBox(
                color: Colors.white,
                child: SizedBox.expand(),
              ),
              panelBuilder: (_, id, active, close) => GestureDetector(
                key: const ValueKey('overflowPane'),
                behavior: HitTestBehavior.opaque,
                onTap: () => presses++,
                child: const CustomPaint(
                  painter: _OverflowingMaterial(),
                  child: SizedBox.expand(),
                ),
              ),
            ),
          ),
        ),
      );
      controller.open();
      await tester.pump();
      final pane = find.byKey(const ValueKey('overflowPane'));
      final element = tester.element(pane);
      Future<void> expectContainedPaint() async {
        final bounds = tester.getRect(pane);
        await tester.runAsync(() async {
          final boundary =
              boundaryKey.currentContext!.findRenderObject()
                  as RenderRepaintBoundary;
          final image = await boundary.toImage(pixelRatio: 1);
          try {
            final pixels = (await image.toByteData(
              format: ui.ImageByteFormat.rawRgba,
            ))!;
            Color pixel(double x) {
              final offset = (100 * image.width + x.round()) * 4;
              return Color.fromARGB(
                pixels.getUint8(offset + 3),
                pixels.getUint8(offset),
                pixels.getUint8(offset + 1),
                pixels.getUint8(offset + 2),
              );
            }

            // The probe paints 64 pixels outside its layout, like the native
            // shadow allowance. That black paint must not bleed into chat.
            expect(pixel(bounds.left - 20), Colors.white);
            expect(pixel(bounds.left + 20), Colors.black);
          } finally {
            image.dispose();
          }
        });
      }

      await expectContainedPaint();
      for (final dx in [-120.0, 180.0, -80.0]) {
        await tester.drag(
          find.byKey(const ValueKey('browserPanelResizeHandle')),
          Offset(dx, 0),
        );
        await tester.pump();
        expect(tester.element(pane), same(element));
        await expectContainedPaint();
        await tester.tap(pane);
        await tester.pump();
      }
      expect(presses, 3);
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'opening beside focused chat leaves native browser shortcuts inactive',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      const channel = MethodChannel('app.browser_window');
      final calls = <MethodCall>[];
      final shortcuts = <String>[];
      final controller = BrowserPanelController();
      final chatFocus = FocusNode();
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
        call,
      ) async {
        calls.add(call);
        return null;
      });
      Future<void> shortcut() {
        final done = Completer<void>();
        tester.binding.channelBuffers.push(
          channel.name,
          channel.codec.encodeMethodCall(const MethodCall('shortcut', 'f')),
          (_) => done.complete(),
        );
        return done.future;
      }

      try {
        await tester.pumpWidget(
          MaterialApp(
            home: BrowserSidePanelHost(
              controller: controller,
              child: Material(child: TextField(focusNode: chatFocus)),
              panelBuilder: (_, id, active, close) => BrowserWindowChrome(
                windowSpacing: false,
                shortcutsEnabled: active,
                onShortcut: shortcuts.add,
                child: const Focus(
                  autofocus: true,
                  child: SizedBox.expand(
                    child: ColoredBox(
                      key: ValueKey('shortcutPane'),
                      color: Colors.blue,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        chatFocus.requestFocus();
        await tester.pump();
        expect(chatFocus.hasPrimaryFocus, isTrue);
        controller.open(conversationId: 'chat');
        await tester.pumpAndSettle();
        expect(chatFocus.hasPrimaryFocus, isTrue);
        await shortcut();
        expect(shortcuts, isEmpty);
        expect(
          calls.where(
            (call) =>
                call.method == 'setBrowserShortcuts' && call.arguments == true,
          ),
          isEmpty,
        );
        await tester.tap(find.byKey(const ValueKey('shortcutPane')));
        await tester.pump();
        await shortcut();
        expect(shortcuts, ['f']);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          null,
        );
        chatFocus.dispose();
        controller.dispose();
        debugDefaultTargetPlatformOverride = null;
      }
    },
  );

  testWidgets(
    'hidden IndexedStack pane cannot claim clicks over its old rectangle',
    (tester) async {
      final controller = BrowserPanelController();
      var index = 0;
      var active = false;
      late StateSetter update;
      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (_, setState) {
              update = setState;
              return IndexedStack(
                index: index,
                children: [
                  BrowserSidePanelHost(
                    controller: controller,
                    child: const SizedBox.expand(),
                    panelBuilder: (_, id, value, close) {
                      active = value;
                      return ColoredBox(
                        key: const ValueKey('visibleBrowserPane'),
                        color: Colors.blue,
                        child: Text(value ? 'active' : 'inactive'),
                      );
                    },
                  ),
                  const ColoredBox(
                    color: Colors.grey,
                    child: SizedBox.expand(),
                  ),
                ],
              );
            },
          ),
        ),
      );
      controller.open(conversationId: 'chat');
      await tester.pump();
      final pane = find.byKey(const ValueKey('visibleBrowserPane'));
      final oldCenter = tester.getCenter(pane);
      await tester.tapAt(oldCenter);
      await tester.pump();
      expect(active, isTrue);
      update(() => index = 1);
      await tester.pump();
      expect(active, isFalse);
      await tester.tapAt(oldCenter);
      await tester.pump();
      expect(active, isFalse);
      expect(controller.isOpen, isTrue);
      update(() => index = 0);
      await tester.pump();
      expect(active, isFalse);
      await tester.tapAt(oldCenter);
      await tester.pump();
      expect(active, isTrue);
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
      expect(tester.takeException(), isNull);
    },
  );
}

class _OverflowingMaterial extends CustomPainter {
  const _OverflowingMaterial();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Rect.fromLTWH(-64, 0, size.width + 128, size.height),
      Paint()..color = Colors.black,
    );
  }

  @override
  bool shouldRepaint(_OverflowingMaterial oldDelegate) => false;
}
