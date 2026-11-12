import 'dart:ui' as ui;

import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/desktop/desktop_context_menu.dart';
import 'package:Kelivo/desktop/desktop_glass_popover.dart';
import 'package:Kelivo/desktop/desktop_overlay_backdrop.dart';
import 'package:Kelivo/features/browser/browser_panel_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../support/business_test_harness.dart';

void main() {
  final panel = BrowserPanelController.instance;
  const macOS = TargetPlatformVariant({TargetPlatform.macOS});
  setUp(() {
    panel.attachHost();
    panel.close();
  });
  tearDown(() {
    panel.close();
    panel.detachHost();
  });

  for (final brightness in Brightness.values) {
    testWidgets('Mac $brightness overlay is opaque only with browser pane', (
      tester,
    ) async {
      final theme = ThemeData(
        colorScheme:
            ColorScheme.fromSeed(
              seedColor: Colors.purple,
              brightness: brightness,
            ).copyWith(
              surface: brightness == Brightness.dark
                  ? const Color(0xff243047)
                  : const Color(0xffe0dfef),
            ),
      );
      final boundary = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: Scaffold(
            body: Center(
              child: RepaintBoundary(
                key: boundary,
                child: SizedBox(
                  width: 100,
                  height: 100,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      const ColoredBox(color: Colors.red),
                      DesktopOverlayBackdrop(
                        sigma: 14,
                        child: ColoredBox(
                          color: theme.colorScheme.surface.withValues(
                            alpha: .66,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      final backdrop = find.byType(BackdropFilter);
      expect(tester.widget<BackdropFilter>(backdrop).enabled, true);
      final element = tester.element(find.byType(DesktopOverlayBackdrop));
      panel.open();
      await tester.pump();
      expect(tester.widget<BackdropFilter>(backdrop).enabled, false);
      expect(
        tester.layers.whereType<BackdropFilterLayer>(),
        isEmpty,
        reason: 'Opaque mode must not retain an active blur pass',
      );
      expect(
        find.byType(AppKitView),
        findsNothing,
        reason: 'No extra native view is added for the fallback',
      );
      final image =
          (boundary.currentContext!.findRenderObject() as RenderRepaintBoundary)
              .toImageSync();
      final bytes = (await tester.runAsync(
        () => image.toByteData(format: ui.ImageByteFormat.rawRgba),
      ))!;
      final color = theme.colorScheme.surface;
      expect(bytes.getUint8(0), (color.r * 255).round());
      expect(bytes.getUint8(1), (color.g * 255).round());
      expect(bytes.getUint8(2), (color.b * 255).round());
      expect(bytes.getUint8(3), 255);
      image.dispose();
      panel.close();
      await tester.pump();
      expect(tester.widget<BackdropFilter>(backdrop).enabled, true);
      expect(
        tester.element(find.byType(DesktopOverlayBackdrop)),
        same(element),
      );
      await tester.pumpWidget(const SizedBox.shrink());
    }, variant: macOS);
  }

  for (final platform in [
    TargetPlatform.windows,
    TargetPlatform.linux,
    TargetPlatform.iOS,
    TargetPlatform.android,
  ]) {
    testWidgets('$platform retains existing Flutter blur with browser open', (
      tester,
    ) async {
      panel.open();
      await tester.pumpWidget(
        const MaterialApp(
          home: DesktopOverlayBackdrop(
            sigma: 20,
            child: SizedBox(width: 80, height: 80),
          ),
        ),
      );
      expect(
        tester.widget<BackdropFilter>(find.byType(BackdropFilter)).enabled,
        true,
      );
      expect(find.byType(AppKitView), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    }, variant: TargetPlatformVariant({platform}));
  }

  testWidgets(
    'pane and theme changes retain input state and use latest theme',
    (tester) async {
      final focus = FocusNode();
      addTearDown(focus.dispose);
      Widget app(Color surface) => MaterialApp(
        theme: ThemeData(colorScheme: ColorScheme.light(surface: surface)),
        home: Scaffold(
          body: DesktopGlassPanel(child: TextField(focusNode: focus)),
        ),
      );
      await tester.pumpWidget(app(Colors.white));
      await tester.enterText(find.byType(TextField), 'keep draft');
      final input = tester.element(find.byType(TextField));
      panel.open();
      await tester.pump();
      await tester.pumpWidget(app(const Color(0xffeeccaa)));
      await tester.pumpAndSettle();
      expect(tester.element(find.byType(TextField)), same(input));
      expect(find.text('keep draft'), findsOneWidget);
      expect(focus.hasFocus, true);
      final fill = find
          .descendant(
            of: find.byType(DesktopOverlayBackdrop),
            matching: find.byType(ColoredBox),
          )
          .first;
      expect(tester.widget<ColoredBox>(fill).color, const Color(0xffeeccaa));
      panel.close();
      await tester.pump();
      expect(tester.element(find.byType(TextField)), same(input));
      await tester.pumpWidget(const SizedBox.shrink());
    },
    variant: macOS,
  );

  testWidgets('real context menu restores blur without being recreated', (
    tester,
  ) async {
    final settings = SettingsProvider(createBusinessTestPreferences());
    await settings.loaded;
    addTearDown(settings.dispose);
    late BuildContext context;
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: settings,
        child: MaterialApp(
          home: Builder(
            builder: (c) {
              context = c;
              return const SizedBox.expand();
            },
          ),
        ),
      ),
    );
    panel.open();
    var tapped = false;
    final closed = showDesktopContextMenuAt(
      context,
      globalPosition: const Offset(40, 40),
      items: [
        DesktopContextMenuItem(label: 'Action', onTap: () => tapped = true),
      ],
    );
    await tester.pumpAndSettle();
    final menu = tester.element(find.text('Action'));
    expect(
      tester.widget<BackdropFilter>(find.byType(BackdropFilter)).enabled,
      false,
    );
    panel.close();
    await tester.pump();
    expect(tester.element(find.text('Action')), same(menu));
    expect(
      tester.widget<BackdropFilter>(find.byType(BackdropFilter)).enabled,
      true,
    );
    await tester.tap(find.text('Action'));
    await tester.pumpAndSettle();
    expect(tapped, true);
    expect(find.text('Action'), findsNothing);
    await closed;
    await tester.pumpWidget(const SizedBox.shrink());
  }, variant: macOS);
}
