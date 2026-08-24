import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:Kelivo/core/providers/assistant_provider.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/features/chat/widgets/frosted/chat_frosted_backdrop.dart';
import 'package:Kelivo/features/chat/widgets/frosted/frosted_surface.dart';
import 'package:Kelivo/theme/chat_bubble_style.dart';

import '../support/business_test_harness.dart';

/// Pixel goldens that call [ui.Image.toByteData] hang in this test VM.
/// These cases lock the layer/widget contract the goldens were meant to guard:
/// Tier 0 is a tinted box, Tier 1 is a pinned follower, live is opt-in only.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    debugFrostedForceLiveBackdropFilter = false;
  });

  const style = ResolvedBubbleStyle(
    background: Color(0xA8FFFFFF),
    border: Color(0x24111111),
    text: Color(0xFF111111),
    borderWidth: 0.8,
    radius: 16,
    blurSigma: 14,
  );

  testWidgets('tier 0 goldens: uniform backdrop never inserts BackdropFilter', (
    tester,
  ) async {
    final assistants = AssistantProvider(
      preferences: createBusinessTestPreferences(),
    );
    await assistants.loaded;
    final settings = SettingsProvider(createBusinessTestPreferences());
    await settings.loaded;

    await tester.pumpWidget(
      _app(
        assistants: assistants,
        settings: settings,
        child: const Center(
          child: FrostedSurface(
            style: style,
            borderRadius: BorderRadius.all(Radius.circular(16)),
            child: SizedBox(width: 160, height: 64, child: Text('Aa')),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(BackdropFilter), findsNothing);
    expect(_countLayers<BackdropFilterLayer>(tester), 0);
    expect(find.byType(CompositedTransformFollower), findsNothing);
  });

  testWidgets(
    'tier 1 goldens: cached crop stays pinned across a 200px scroll',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);

      final assistants = AssistantProvider(
        preferences: createBusinessTestPreferences(),
      );
      await assistants.loaded;
      final id = await assistants.addAssistant(name: 'Wallpaper');
      await assistants.setCurrentAssistant(id);
      await assistants.updateAssistant(
        assistants.currentAssistant!.copyWith(
          background: 'https://example.com/wallpaper.png',
        ),
      );
      final settings = SettingsProvider(createBusinessTestPreferences());
      await settings.loaded;

      await tester.pumpWidget(
        _app(
          assistants: assistants,
          settings: settings,
          child: ListView(
            children: const [
              SizedBox(height: 300),
              FrostedSurface(
                style: style,
                borderRadius: BorderRadius.all(Radius.circular(16)),
                child: SizedBox(height: 80, child: Text('card')),
              ),
              SizedBox(height: 800),
            ],
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byType(CompositedTransformFollower), findsOneWidget);
      expect(_countLayers<BackdropFilterLayer>(tester), 0);

      final card = tester.getTopLeft(find.text('card'));
      tester
          .state<ScrollableState>(find.byType(Scrollable))
          .position
          .jumpTo(200);
      await tester.pump();

      expect(
        tester.getTopLeft(find.text('card')).dy,
        closeTo(card.dy - 200, 0.5),
      );
      expect(find.byType(CompositedTransformFollower), findsOneWidget);
      expect(_countLayers<BackdropFilterLayer>(tester), 0);
    },
  );
}

Widget _app({
  required AssistantProvider assistants,
  required SettingsProvider settings,
  required Widget child,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<AssistantProvider>.value(value: assistants),
      ChangeNotifierProvider<SettingsProvider>.value(value: settings),
    ],
    child: MaterialApp(
      home: ChatFrostedBackdrop(
        backdrop: const ColoredBox(color: Color(0xFF4D5C92)),
        child: child,
      ),
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
