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
    expect(find.byType(BackdropFilter), findsNothing);
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

    expect(find.byType(BackdropFilter), findsOneWidget);
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
