import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:Kelivo/core/providers/assistant_provider.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/features/chat/widgets/frosted/chat_frosted_backdrop.dart';
import 'package:Kelivo/features/chat/widgets/frosted/frosted_surface.dart';
import 'package:Kelivo/theme/chat_bubble_style.dart';

import '../../../../support/business_test_harness.dart';

const _style = ResolvedBubbleStyle(
  background: Color(0xA8FFFFFF),
  border: Color(0x24FFFFFF),
  text: Color(0xFF111111),
  borderWidth: 0.8,
  radius: 16,
  blurSigma: 14,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    debugFrostedForceLiveBackdropFilter = false;
  });

  testWidgets('glass mode changes retain content state without remounting', (
    tester,
  ) async {
    final controller = ChatFrostedBackdropController();
    var mounts = 0, disposals = 0;
    final content = _StateProbe(
      onMount: () => mounts++,
      onDispose: () => disposals++,
    );
    Widget host({double sigma = 14}) {
      Widget surface = FrostedSurface(
        style: ResolvedBubbleStyle(
          background: _style.background,
          border: _style.border,
          text: _style.text,
          borderWidth: _style.borderWidth,
          radius: _style.radius,
          blurSigma: sigma,
        ),
        borderRadius: BorderRadius.circular(16),
        child: content,
      );
      // Keep the scope element in place while testing the uniform mode.
      surface = ChatFrostedBackdropScope(
        controller: controller,
        backgroundActive: true,
        size: const Size(800, 600),
        child: surface,
      );
      return MaterialApp(home: Scaffold(body: surface));
    }

    controller.applyBackdropState(wallpaperActive: true);
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextField),
      'state survives glass changes',
    );
    final field = tester.state<EditableTextState>(find.byType(EditableText));
    field.widget.controller.selection = const TextSelection(
      baseOffset: 6,
      extentOffset: 14,
    );
    for (final change in <VoidCallback>[
      () =>
          controller.applyBackdropState(wallpaperActive: true, enterLive: true),
      controller.endLiveTransition,
      () => controller.applyBackdropState(wallpaperActive: false),
      () => controller.applyBackdropState(wallpaperActive: true),
    ]) {
      change();
      await tester.pumpAndSettle();
      expect(mounts, 1);
      expect(disposals, 0);
      expect(tester.state(find.byType(EditableText)), same(field));
      expect(
        field.widget.controller.selection,
        const TextSelection(baseOffset: 6, extentOffset: 14),
      );
    }
    for (final sigma in [0.0, -1.0]) {
      await tester.pumpWidget(host(sigma: sigma));
      await tester.pumpAndSettle();
      expect(mounts, 1);
      expect(disposals, 0);
      expect(controller.debugAcquiredSigmaCount, 0);
      expect(_activeFilters, findsNothing);
      expect(tester.takeException(), isNull);
    }
    await tester.pumpWidget(const SizedBox.shrink());
    expect(disposals, 1);
    controller.dispose();
  });

  testWidgets(
    'live background and retained foreground match the original composite',
    (tester) async {
      debugFrostedForceLiveBackdropFilter = true;
      final keys = [GlobalKey(), GlobalKey()];
      const radius = BorderRadius.all(Radius.circular(16));
      const content = SizedBox(
        width: 144,
        height: 96,
        child: Center(child: Text('Aa 文')),
      );
      final pixels = <List<int>>[];
      for (var i = 0; i < 2; i++) {
        // Render each at the same screen position: blur samples outside the
        // card, so adjacent references would have different backdrop inputs.
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: RepaintBoundary(
                key: keys[i],
                child: SizedBox(
                  width: 180,
                  height: 140,
                  child: Stack(
                    children: [
                      const Positioned.fill(
                        child: CustomPaint(painter: _CheckerboardPainter()),
                      ),
                      Center(
                        child: i == 0
                            ? const FrostedSurface(
                                style: _style,
                                borderRadius: radius,
                                child: content,
                              )
                            : ClipRRect(
                                borderRadius: radius,
                                child: BackdropFilter.grouped(
                                  filter: ui.ImageFilter.blur(
                                    sigmaX: _style.blurSigma,
                                    sigmaY: _style.blurSigma,
                                  ),
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      color: _style.background,
                                      borderRadius: radius,
                                      border: Border.all(
                                        color: _style.border,
                                        width: _style.borderWidth,
                                      ),
                                    ),
                                    child: content,
                                  ),
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final image =
            (keys[i].currentContext!.findRenderObject()!
                    as RenderRepaintBoundary)
                .toImageSync();
        try {
          final bytes = await tester.runAsync(
            () => image.toByteData(format: ui.ImageByteFormat.rawRgba),
          );
          pixels.add(bytes!.buffer.asUint8List());
        } finally {
          image.dispose();
        }
      }
      expect(listEquals(pixels[0], pixels[1]), isTrue);
    },
  );

  testWidgets('cached frosted surfaces add no BackdropFilterLayer', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    final assistants = AssistantProvider(
      preferences: createBusinessTestPreferences(),
    );
    await assistants.loaded;
    final id = await assistants.addAssistant(name: 'Frosted');
    await assistants.setCurrentAssistant(id);
    await assistants.updateAssistant(
      assistants.currentAssistant!.copyWith(
        background: 'https://example.com/wallpaper.png',
      ),
    );

    final settings = SettingsProvider(createBusinessTestPreferences());
    await settings.loaded;

    await tester.pumpWidget(
      _frostedApp(
        assistants: assistants,
        settings: settings,
        child: ListView(
          children: [
            for (var i = 0; i < 6; i++)
              const Padding(
                padding: EdgeInsets.all(12),
                child: FrostedSurface(
                  style: _style,
                  borderRadius: BorderRadius.all(Radius.circular(16)),
                  child: SizedBox(height: 80, child: Text('card')),
                ),
              ),
          ],
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byType(FrostedSurface), findsNWidgets(6));
    expect(find.byType(CompositedTransformFollower), findsWidgets);
    expect(_countLayers<BackdropFilterLayer>(tester), 0);

    final firstElement = tester.element(find.byType(FrostedSurface).first);
    RenderRepaintBoundary? boundary;
    firstElement.visitAncestorElements((element) {
      final ro = element.renderObject;
      if (ro is RenderRepaintBoundary) {
        boundary = ro;
        return false;
      }
      return true;
    });

    final list = tester.state<ScrollableState>(find.byType(Scrollable));
    list.position.jumpTo(200);
    await tester.pump();

    expect(_countLayers<BackdropFilterLayer>(tester), 0);
    if (boundary != null) {
      expect(boundary!.debugNeedsPaint, isFalse);
    }
  });

  testWidgets('tier 0 frosted is a tinted DecoratedBox', (tester) async {
    tester.view.physicalSize = const Size(300, 200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final assistants = AssistantProvider(
      preferences: createBusinessTestPreferences(),
    );
    await assistants.loaded;
    final settings = SettingsProvider(createBusinessTestPreferences());
    await settings.loaded;

    await tester.pumpWidget(
      _frostedApp(
        assistants: assistants,
        settings: settings,
        backdrop: const ColoredBox(color: Color(0xFF4D5C92)),
        child: const Center(
          child: FrostedSurface(
            style: _style,
            borderRadius: BorderRadius.all(Radius.circular(16)),
            child: SizedBox(
              width: 160,
              height: 64,
              child: Center(child: Text('Aa')),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(FrostedSurface), findsOneWidget);
    expect(_activeFilters, findsNothing);
    expect(find.byType(CompositedTransformFollower), findsNothing);
    final box = tester.widget<DecoratedBox>(
      find
          .descendant(
            of: find.byType(FrostedSurface),
            matching: find.byType(DecoratedBox),
          )
          .first,
    );
    final decoration = box.decoration as BoxDecoration;
    expect(decoration.color, _style.background);
    expect(decoration.borderRadius, BorderRadius.circular(16));
  });

  testWidgets('debug live flag uses BackdropFilter even without wallpaper', (
    tester,
  ) async {
    debugFrostedForceLiveBackdropFilter = true;
    final assistants = AssistantProvider(
      preferences: createBusinessTestPreferences(),
    );
    await assistants.loaded;
    final settings = SettingsProvider(createBusinessTestPreferences());
    await settings.loaded;

    await tester.pumpWidget(
      _frostedApp(
        assistants: assistants,
        settings: settings,
        child: const FrostedSurface(
          style: _style,
          borderRadius: BorderRadius.all(Radius.circular(16)),
          child: SizedBox(height: 40, child: Text('live')),
        ),
      ),
    );
    await tester.pump();

    expect(_activeFilters, findsOneWidget);
  });

  testWidgets('frosted whole-surface rounded clip', (tester) async {
    tester.view.physicalSize = const Size(300, 200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final assistants = AssistantProvider(
      preferences: createBusinessTestPreferences(),
    );
    await assistants.loaded;
    final settings = SettingsProvider(createBusinessTestPreferences());
    await settings.loaded;

    await tester.pumpWidget(
      _frostedApp(
        assistants: assistants,
        settings: settings,
        child: const FrostedSurface(
          style: _style,
          borderRadius: BorderRadius.all(Radius.circular(16)),
          child: SizedBox(width: 160, height: 80, child: Text('clip')),
        ),
      ),
    );
    await tester.pump();

    final clips = find.descendant(
      of: find.byType(FrostedSurface),
      matching: find.byType(ClipRRect),
    );
    expect(clips, findsOneWidget);
    final clip = tester.widget<ClipRRect>(clips);
    expect(clip.borderRadius, const BorderRadius.all(Radius.circular(16)));
    expect(tester.getSize(clips), tester.getSize(find.byType(FrostedSurface)));
  });
}

Widget _frostedApp({
  required AssistantProvider assistants,
  required SettingsProvider settings,
  required Widget child,
  Widget backdrop = const CustomPaint(
    painter: _CheckerboardPainter(),
    child: SizedBox.expand(),
  ),
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<AssistantProvider>.value(value: assistants),
      ChangeNotifierProvider<SettingsProvider>.value(value: settings),
    ],
    child: MaterialApp(
      home: ChatFrostedBackdrop(backdrop: backdrop, child: child),
    ),
  );
}

int _countLayers<T extends Layer>(WidgetTester tester) {
  var count = 0;
  void walk(Layer layer) {
    if (layer is T) count++;
    if (layer is ContainerLayer) {
      var child = layer.firstChild;
      while (child != null) {
        walk(child);
        child = child.nextSibling;
      }
    }
  }

  walk(tester.binding.renderViews.first.debugLayer!);
  return count;
}

class _CheckerboardPainter extends CustomPainter {
  const _CheckerboardPainter();

  @override
  void paint(Canvas canvas, Size size) {
    const cell = 24.0;
    final light = Paint()..color = const Color(0xFFE0E0E0);
    final dark = Paint()..color = const Color(0xFF9E9E9E);
    for (var y = 0.0; y < size.height; y += cell) {
      for (var x = 0.0; x < size.width; x += cell) {
        final odd = ((x / cell).floor() + (y / cell).floor()).isOdd;
        canvas.drawRect(Rect.fromLTWH(x, y, cell, cell), odd ? dark : light);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _StateProbe extends StatefulWidget {
  const _StateProbe({required this.onMount, required this.onDispose});
  final VoidCallback onMount, onDispose;
  @override
  State<_StateProbe> createState() => _StateProbeState();
}

class _StateProbeState extends State<_StateProbe> {
  @override
  void initState() {
    super.initState();
    widget.onMount();
  }

  @override
  void dispose() {
    widget.onDispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      const SizedBox(width: 250, child: TextField());
}

Finder get _activeFilters => find.byWidgetPredicate(
  (widget) => widget is BackdropFilter && widget.enabled,
);
