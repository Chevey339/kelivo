import 'package:Kelivo/theme/app_semantic_colors.dart';
import 'dart:ui' as ui;

import 'package:Kelivo/features/browser/models/browser_models.dart';
import 'package:Kelivo/features/browser/widgets/browser_controls.dart';
import 'package:Kelivo/features/browser/widgets/browser_glass.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderRepaintBoundary;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

void main() {
  for (final brightness in Brightness.values) {
    testWidgets('solid glass uses app surface tokens: $brightness', (
      tester,
    ) async {
      final colors = ColorScheme.fromSeed(
        seedColor: const Color(0xff94622a),
        brightness: brightness,
      );
      final tokens =
          (brightness == Brightness.dark
                  ? AppSemanticColors.dark(colors)
                  : AppSemanticColors.light(colors))
              .copyWith(
                surfaceCard: const Color(0xff345c68),
                hairline: const Color(0x665c789a),
              );
      for (final clear in [false, true]) {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(colorScheme: colors, extensions: [tokens]),
            home: Center(
              child: BrowserGlass(
                clear: clear,
                child: const SizedBox(width: 200, height: 48),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final cover =
            tester
                    .widget<DecoratedBox>(
                      find.byKey(const ValueKey('browserMaterialCover')),
                    )
                    .decoration
                as BoxDecoration;
        expect(cover.color, clear ? colors.surface : tokens.surfaceCard);
        expect((cover.border! as Border).top.color, tokens.hairline);
        expect(find.byType(BackdropFilter), findsNothing);
      }
    });
  }

  Future<void> mount(
    WidgetTester tester, {
    VoidCallback? onTap,
    VoidCallback? onLongPress,
    void Function(int pointer, LongPressStartDetails details)? onLongPressStart,
    bool enabled = true,
    bool reducedMotion = false,
    Size size = const Size(140, 48),
  }) => tester.pumpWidget(
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: reducedMotion),
        child: Scaffold(
          body: Center(
            child: BrowserPress(
              semanticLabel: 'Browser action',
              enabled: enabled,
              draggable: true,
              onTap: onTap,
              onLongPress: onLongPress,
              onLongPressStart: onLongPressStart,
              child: BrowserGlass(
                child: SizedBox(
                  width: size.width,
                  height: size.height,
                  child: const Text('Action'),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );

  Transform scale(WidgetTester tester) => tester
      .widgetList<Transform>(
        find.descendant(
          of: find.byType(BrowserPress),
          matching: find.byType(Transform),
        ),
      )
      .last;

  testWidgets('glass grows on press and cancels without activating or ink', (
    tester,
  ) async {
    var taps = 0;
    await mount(tester, onTap: () => taps++);
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(BrowserPress)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));
    expect(scale(tester).transform.storage[0], greaterThan(1.02));
    expect(find.byType(InkWell), findsNothing);
    expect(find.byType(InkResponse), findsNothing);
    await gesture.cancel();
    await tester.pumpAndSettle();
    expect(scale(tester).transform.storage[0], closeTo(1, .001));
    expect(taps, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('drag is bounded and settles without activating tap', (
    tester,
  ) async {
    var taps = 0;
    await mount(tester, onTap: () => taps++);
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(BrowserPress)),
    );
    await gesture.moveBy(const Offset(240, 50));
    await tester.pump(const Duration(milliseconds: 100));
    final transform = tester.widget<Transform>(
      find.byKey(const ValueKey('browserSpringTransform')),
    );
    expect(transform.transform.storage[12], greaterThan(0));
    expect(transform.transform.storage[12], lessThan(24));
    await gesture.up();
    await tester.pumpAndSettle();
    final settled = tester.widget<Transform>(
      find.byKey(const ValueKey('browserSpringTransform')),
    );
    expect(settled.transform.storage[12], closeTo(0, .05));
    expect(taps, 0);
  });

  testWidgets('reduced motion retains actions without scaling or dragging', (
    tester,
  ) async {
    var taps = 0;
    await mount(tester, onTap: () => taps++, reducedMotion: true);
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(BrowserPress)),
    );
    await tester.pump(const Duration(milliseconds: 200));
    expect(scale(tester).transform.storage[0], 1);
    await gesture.up();
    await tester.pumpAndSettle();
    expect(taps, 1);
    await tester.drag(find.byType(BrowserPress), const Offset(100, 0));
    await tester.pumpAndSettle();
    final transform = tester.widget<Transform>(
      find.byKey(const ValueKey('browserSpringTransform')),
    );
    expect(transform.transform.storage[12], 0);
  });

  testWidgets('keyboard activation and disabled state use the same action', (
    tester,
  ) async {
    var taps = 0;
    await mount(tester, onTap: () => taps++);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(taps, 1);
    await mount(tester, onTap: () => taps++, enabled: false);
    await tester.tap(find.byType(BrowserPress));
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pumpAndSettle();
    expect(taps, 1);
  });

  testWidgets('long press has no Material overlay or duplicate tap', (
    tester,
  ) async {
    var taps = 0;
    var longPresses = 0;
    await mount(tester, onTap: () => taps++, onLongPress: () => longPresses++);
    await tester.longPress(find.byType(BrowserPress));
    await tester.pumpAndSettle();
    expect(longPresses, 1);
    expect(taps, 0);
    expect(find.byType(InkResponse), findsNothing);
  });

  testWidgets(
    '320ms menu long press transfers the held pointer through overlay insertion',
    (tester) async {
      var taps = 0;
      var legacyLongPresses = 0;
      int? heldPointer;
      LongPressStartDetails? start;
      OverlayEntry? entry;
      final routed = <PointerEvent>[];
      void route(PointerEvent event) => routed.add(event);
      addTearDown(() {
        if (heldPointer != null) {
          GestureBinding.instance.pointerRouter.removeRoute(
            heldPointer!,
            route,
          );
        }
        entry?.remove();
        entry?.dispose();
      });
      await mount(
        tester,
        onTap: () => taps++,
        onLongPress: () => legacyLongPresses++,
        onLongPressStart: (pointer, details) {
          expect(heldPointer, isNull);
          heldPointer = pointer;
          start = details;
          GestureBinding.instance.pointerRouter.addRoute(pointer, route);
          entry = OverlayEntry(
            builder: (_) => const Positioned.fill(
              child: IgnorePointer(child: ColoredBox(color: Color(0x01000000))),
            ),
          );
          Overlay.of(tester.element(find.byType(BrowserPress))).insert(entry!);
        },
      );
      final origin = tester.getCenter(find.byType(BrowserPress));
      final gesture = await tester.startGesture(origin, pointer: 42);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 319));
      expect(heldPointer, isNull);
      await tester.pump(const Duration(milliseconds: 1));
      expect(heldPointer, 42);
      expect(start!.globalPosition, origin);
      expect(start!.localPosition, const Offset(70, 24));
      expect(scale(tester).transform.storage[0], greaterThan(1.05));
      await gesture.moveBy(const Offset(85, -100));
      await tester.pump(const Duration(milliseconds: 30));
      expect(routed.whereType<PointerMoveEvent>(), isNotEmpty);
      expect(routed.every((event) => event.pointer == 42), isTrue);
      expect(routed.whereType<PointerCancelEvent>(), isEmpty);
      expect(scale(tester).transform.storage[0], greaterThan(1.05));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(routed.whereType<PointerUpEvent>(), hasLength(1));
      expect(legacyLongPresses, 0);
      expect(taps, 0);
      expect(scale(tester).transform.storage[0], closeTo(1, .001));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('releasing before the menu deadline preserves an ordinary tap', (
    tester,
  ) async {
    var taps = 0;
    var transfers = 0;
    await mount(
      tester,
      onTap: () => taps++,
      onLongPressStart: (_, _) => transfers++,
    );
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(BrowserPress)),
    );
    await tester.pump(const Duration(milliseconds: 250));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(taps, 1);
    expect(transfers, 0);
    expect(scale(tester).transform.storage[0], closeTo(1, .001));
  });

  testWidgets('disabled controls do not transfer a long-press pointer', (
    tester,
  ) async {
    var starts = 0;
    await mount(tester, enabled: false, onLongPressStart: (_, _) => starts++);
    await tester.longPress(find.byType(BrowserPress));
    await tester.pumpAndSettle();
    expect(starts, 0);
  });

  testWidgets('accessibility tap and long press work without pointer events', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    var taps = 0;
    var longPresses = 0;
    var pointerStarts = 0;
    await mount(
      tester,
      onTap: () => taps++,
      onLongPress: () => longPresses++,
      onLongPressStart: (_, _) => pointerStarts++,
    );
    final node = tester.getSemantics(find.byType(BrowserPress));
    final owner = node.owner!;
    expect(node.getSemanticsData().hasAction(ui.SemanticsAction.tap), isTrue);
    expect(
      node.getSemanticsData().hasAction(ui.SemanticsAction.longPress),
      isTrue,
    );
    owner.performAction(node.id, ui.SemanticsAction.tap);
    owner.performAction(node.id, ui.SemanticsAction.longPress);
    await tester.pump();
    expect(taps, 1);
    expect(longPresses, 1);
    expect(pointerStarts, 0);
    expect(scale(tester).transform.storage[0], 1);
    await mount(
      tester,
      enabled: false,
      onTap: () => taps++,
      onLongPress: () => longPresses++,
    );
    final disabled = tester.getSemantics(find.byType(BrowserPress));
    expect(
      disabled.getSemanticsData().hasAction(ui.SemanticsAction.tap),
      isFalse,
    );
    expect(
      disabled.getSemanticsData().hasAction(ui.SemanticsAction.longPress),
      isFalse,
    );
    owner.performAction(disabled.id, ui.SemanticsAction.tap);
    owner.performAction(disabled.id, ui.SemanticsAction.longPress);
    await tester.pump();
    expect(taps, 1);
    expect(longPresses, 1);
    semantics.dispose();
  });

  testWidgets('desktop mouse hover and press never scale or drag', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    try {
      var taps = 0;
      await mount(tester, onTap: () => taps++);
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      final center = tester.getCenter(find.byType(BrowserPress));
      await mouse.addPointer(location: center);
      await tester.pump();
      await mouse.down(center);
      await tester.pump(const Duration(milliseconds: 150));
      expect(scale(tester).transform.storage[0], 1);
      expect(
        find.byKey(const ValueKey('browserGlassTouchLight')),
        findsOneWidget,
      );
      await mouse.moveBy(const Offset(90, 12));
      await tester.pump(const Duration(milliseconds: 150));
      final translation = tester.widget<Transform>(
        find.byKey(const ValueKey('browserSpringTransform')),
      );
      expect(translation.transform.storage[12], 0);
      expect(scale(tester).transform.storage[0], 1);
      await mouse.up();
      await mouse.removePointer();
      await tester.pumpAndSettle();
      expect(taps, 0);
      expect(tester.takeException(), isNull);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('mouse on a mobile target also avoids touch deformation', (
    tester,
  ) async {
    await mount(tester, onTap: () {});
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.down(tester.getCenter(find.byType(BrowserPress)));
    await tester.pump(const Duration(milliseconds: 150));
    expect(scale(tester).transform.storage[0], 1);
    await mouse.moveBy(const Offset(60, 0));
    await tester.pump();
    expect(
      tester
          .widget<Transform>(
            find.byKey(const ValueKey('browserSpringTransform')),
          )
          .transform
          .storage[12],
      0,
    );
    await mouse.up();
    await mouse.removePointer();
  });

  testWidgets('nested touch animates only the deepest control', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: BrowserPress(
              key: const ValueKey('outer'),
              draggable: true,
              child: BrowserGlass(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: BrowserPress(
                    key: const ValueKey('inner'),
                    onTap: () {},
                    draggable: true,
                    child: const BrowserGlass(
                      child: SizedBox(width: 80, height: 48),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const ValueKey('inner'))),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));
    final transforms = tester
        .widgetList<Transform>(
          find.descendant(
            of: find.byKey(const ValueKey('outer')),
            matching: find.byType(Transform),
          ),
        )
        .toList();
    expect(transforms[1].transform.storage[0], 1);
    expect(transforms.last.transform.storage[0], greaterThan(1.03));
    await gesture.moveBy(const Offset(70, 0));
    await tester.pump();
    final translations = tester
        .widgetList<Transform>(
          find.byKey(const ValueKey('browserSpringTransform')),
        )
        .toList();
    expect(translations.first.transform.storage[12], 0);
    expect(translations.last.transform.storage[12], greaterThan(0));
    await gesture.cancel();
    await tester.pumpAndSettle();
  });

  testWidgets('parent scrolling cancels the 320ms menu and glass response', (
    tester,
  ) async {
    var taps = 0;
    var transfers = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            children: [
              BrowserPress(
                key: const ValueKey('row'),
                onTap: () => taps++,
                onLongPressStart: (_, _) => transfers++,
                child: const BrowserGlass(
                  child: SizedBox(height: 80, child: Text('Row')),
                ),
              ),
              const SizedBox(height: 1600),
            ],
          ),
        ),
      ),
    );
    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const ValueKey('row'))),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));
    // List presses wait for tap-down arbitration, then animate the light.
    await tester.pump(const Duration(milliseconds: 80));
    expect(
      find.byKey(const ValueKey('browserGlassTouchLight')),
      findsOneWidget,
    );
    await gesture.moveBy(const Offset(0, -28));
    await gesture.moveBy(const Offset(0, -25));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('browserGlassTouchLight')), findsNothing);
    expect(taps, 0);
    expect(transfers, 0);
    await gesture.up();
    await tester.pumpAndSettle();
  });

  testWidgets('press size and drag deformation follow the shared glass law', (
    tester,
  ) async {
    for (final size in [const Size(48, 48), const Size(240, 48)]) {
      await mount(tester, onTap: () {}, size: size);
      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(BrowserPress)),
      );
      await tester.pumpAndSettle();
      final lifted = scale(tester).transform;
      expect(lifted.storage[0] * size.width - size.width, closeTo(20, .05));
      expect(lifted.storage[0], closeTo(lifted.storage[5], .001));
      await gesture.moveBy(const Offset(240, 0));
      await tester.pump();
      final stretched = scale(tester).transform;
      expect(stretched.storage[0], greaterThan(lifted.storage[0]));
      expect(stretched.storage[5], lessThan(lifted.storage[5]));
      expect(
        stretched.storage[0] * stretched.storage[5],
        closeTo(lifted.storage[0] * lifted.storage[5], .001),
      );
      await gesture.cancel();
      await tester.pumpAndSettle();
      expect(scale(tester).transform.storage[0], closeTo(1, .001));
      expect(scale(tester).transform.storage[5], closeTo(1, .001));
    }
  });

  testWidgets(
    'touch light is a clipped low-alpha radial field that follows the contact',
    (tester) async {
      const size = Size(340, 60);
      await mount(tester, onTap: () {}, size: size);
      final box = tester.getRect(find.byType(BrowserPress));
      final gesture = await tester.startGesture(
        box.topLeft + const Offset(70, 30),
      );
      await tester.pumpAndSettle();
      Future<Uint8List> pixels() async {
        final paint = tester.widget<CustomPaint>(
          find.byKey(const ValueKey('browserGlassTouchLight')),
        );
        return (await tester.runAsync(() async {
          final recorder = ui.PictureRecorder();
          final canvas = ui.Canvas(recorder);
          paint.painter!.paint(canvas, size);
          final picture = recorder.endRecording();
          final image = await picture.toImage(340, 60);
          final data = await image.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          );
          image.dispose();
          picture.dispose();
          return data!.buffer.asUint8List();
        }))!;
      }

      int alpha(Uint8List bytes, int x, int y) => bytes[(y * 340 + x) * 4 + 3];
      int peak(Uint8List bytes) {
        var result = 0;
        for (var index = 3; index < bytes.length; index += 4) {
          if (bytes[index] > result) result = bytes[index];
        }
        return result;
      }

      final first = await pixels();
      expect(alpha(first, 70, 30), inInclusiveRange(22, 26));
      expect(alpha(first, 140, 30), inInclusiveRange(10, 17));
      expect(alpha(first, 300, 30), 0);
      expect(peak(first), lessThanOrEqualTo(26));
      expect(alpha(first, 0, 0), 0);
      await gesture.moveBy(const Offset(180, 0));
      await tester.pump();
      final moved = await pixels();
      expect(alpha(moved, 245, 30), greaterThan(20));
      expect(alpha(moved, 70, 30), lessThan(10));
      expect(peak(moved), lessThanOrEqualTo(26));
      expect(alpha(moved, 0, 0), 0);
      await gesture.cancel();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));
      final fading = await pixels();
      expect(peak(fading), inExclusiveRange(0, peak(moved)));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('browserGlassTouchLight')),
        findsNothing,
      );
    },
  );

  testWidgets(
    'embedded controls paint mouse feedback and keyboard focus without glass',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      try {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: BrowserPress(
                  onTap: () {},
                  draggable: true,
                  child: const BrowserControlFeedback(
                    radius: 20,
                    child: SizedBox(width: 40, height: 40, child: Text('Go')),
                  ),
                ),
              ),
            ),
          ),
        );
        expect(find.byType(BrowserGlass), findsNothing);
        final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
        final center = tester.getCenter(find.byType(BrowserPress));
        await mouse.addPointer(location: center);
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('browserControlFeedbackPaint')),
          findsOneWidget,
        );
        await mouse.down(center);
        await tester.pump();
        expect(
          find.byKey(const ValueKey('browserControlFeedbackPaint')),
          findsOneWidget,
        );
        expect(scale(tester).transform.storage[0], 1);
        await mouse.up();
        await mouse.removePointer();
        await tester.pumpAndSettle();
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('browserControlFeedbackFocus')),
          findsOneWidget,
        );
        expect(find.byType(BackdropFilter), findsNothing);
        expect(tester.takeException(), isNull);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    },
  );

  for (final platform in [
    TargetPlatform.macOS,
    TargetPlatform.windows,
    TargetPlatform.linux,
    TargetPlatform.iOS,
    TargetPlatform.android,
  ]) {
    testWidgets(
      'compact control has bounded idle paint only on desktop: $platform',
      (tester) async {
        debugDefaultTargetPlatformOverride = platform;
        final desktop =
            platform != TargetPlatform.android &&
            platform != TargetPlatform.iOS;
        try {
          var taps = 0;
          final captureKey = GlobalKey();
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: Center(
                  child: RepaintBoundary(
                    key: captureKey,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: BrowserActionButton(
                        compact: true,
                        iconSize: 15,
                        label: 'Expand',
                        icon: LucideIcons.expand,
                        onPressed: () => taps++,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final boundary = tester.renderObject<RenderRepaintBoundary>(
            find.byKey(captureKey),
          );
          final pixels = (await tester.runAsync(() async {
            final image = await boundary.toImage(pixelRatio: 1);
            try {
              return (await image.toByteData(
                format: ui.ImageByteFormat.rawRgba,
              ))!.buffer.asUint8List();
            } finally {
              image.dispose();
            }
          }))!;
          expect(boundary.size, const Size(62, 62));
          int alpha(int x, int y) => pixels[(y * 62 + x) * 4 + 3];
          // Well outside the 15px icon, but inside the original 38px control.
          expect(alpha(14, 31), desktop ? 1 : 0);
          expect(alpha(47, 31), desktop ? 1 : 0);
          expect(alpha(12, 12), 0); // Circular corners remain transparent.
          for (var y = 0; y < 62; y++) {
            for (var x = 0; x < 62; x++) {
              if (x < 12 || x >= 50 || y < 12 || y >= 50) {
                expect(
                  alpha(x, y),
                  0,
                  reason: 'paint outside control at $x,$y',
                );
              }
            }
          }
          final footprint = find.byKey(
            const ValueKey('browserControlHitFootprint'),
          );
          expect(footprint, desktop ? findsOneWidget : findsNothing);
          if (desktop) {
            final identity = tester.element(footprint);
            final control = tester.getRect(find.byType(BrowserPress));
            final point = control.centerLeft + const Offset(2, 0);
            final mouse = await tester.createGesture(
              kind: PointerDeviceKind.mouse,
            );
            await mouse.down(point);
            await tester.pump(const Duration(milliseconds: 150));
            expect(identical(tester.element(footprint), identity), isTrue);
            expect(tester.getRect(find.byType(BrowserPress)), control);
            expect(scale(tester).transform.storage[0], 1);
            expect(
              find.byKey(const ValueKey('browserControlFeedbackPaint')),
              findsOneWidget,
            );
            expect(taps, 0);
            await mouse.up();
            await tester.pumpAndSettle();
            expect(taps, 1);
            await mouse.down(point);
            await mouse.cancel();
            await mouse.removePointer();
            await tester.pumpAndSettle();
            expect(taps, 1);
            await tester.tapAt(control.centerLeft - const Offset(2, 0));
            await tester.pumpAndSettle();
            expect(taps, 1);
          }
          expect(find.byType(InkResponse), findsNothing);
          expect(tester.takeException(), isNull);
        } finally {
          await tester.pumpWidget(const SizedBox.shrink());
          debugDefaultTargetPlatformOverride = null;
        }
      },
    );
  }

  testWidgets('browser material survives captured overlay themes', (
    tester,
  ) async {
    late Widget overlay;
    await tester.pumpWidget(
      MaterialApp(
        home: BrowserGlassScope(
          style: BrowserSurfaceStyle.frosted,
          child: Builder(
            builder: (context) {
              overlay = InheritedTheme.captureAll(
                context,
                Builder(
                  builder: (context) {
                    return Text(BrowserGlassScope.of(context).name);
                  },
                ),
              );
              return const SizedBox();
            },
          ),
        ),
      ),
    );
    await tester.pumpWidget(MaterialApp(home: overlay));
    expect(find.text('frosted'), findsOneWidget);
  });
}
