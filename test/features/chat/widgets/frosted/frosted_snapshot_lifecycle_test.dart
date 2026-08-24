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

ResolvedBubbleStyle _style(double sigma) => ResolvedBubbleStyle(
  background: const Color(0xA8FFFFFF),
  border: const Color(0x24FFFFFF),
  text: const Color(0xFF111111),
  borderWidth: 0.8,
  radius: 16,
  blurSigma: sigma,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    debugFrostedForceLiveBackdropFilter = false;
    debugFrostedForceSnapshotFailure = false;
  });

  testWidgets('sigma changes keep acquired buckets at in-use count', (
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
        background: 'https://example.com/wallpaper-a.png',
      ),
    );
    final settings = SettingsProvider(createBusinessTestPreferences());
    await settings.loaded;

    Future<void> pumpSigma(double sigma) async {
      await tester.pumpWidget(
        _app(
          assistants: assistants,
          settings: settings,
          child: Column(
            children: [
              FrostedSurface(
                style: _style(sigma),
                borderRadius: BorderRadius.circular(16),
                child: const SizedBox(height: 40, child: Text('user')),
              ),
              FrostedSurface(
                style: _style(sigma),
                borderRadius: BorderRadius.circular(16),
                isUser: false,
                child: const SizedBox(height: 40, child: Text('assistant')),
              ),
            ],
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
    }

    for (var sigma = 0.0; sigma <= 30; sigma += 1) {
      await pumpSigma(sigma);
      final controller = tester
          .widget<ChatFrostedBackdropScope>(
            find.byType(ChatFrostedBackdropScope),
          )
          .controller;
      if (sigma <= 0) {
        expect(controller.debugAcquiredSigmaCount, 0);
        expect(_countLayers<BackdropFilterLayer>(tester), 0);
        continue;
      }
      expect(
        controller.debugAcquiredSigmaCount,
        1,
        reason: 'sigma=$sigma acquired=${controller.debugAcquiredSigmaCount}',
      );
      expect(controller.debugBucketCount, lessThanOrEqualTo(2));
      expect(_countLayers<BackdropFilterLayer>(tester), 0);
    }
  });

  testWidgets('wallpaper A to B never keeps the previous snapshot on screen', (
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
        background: 'https://example.com/wallpaper-a.png',
      ),
    );
    final settings = SettingsProvider(createBusinessTestPreferences());
    await settings.loaded;

    await tester.pumpWidget(
      _app(
        assistants: assistants,
        settings: settings,
        child: FrostedSurface(
          style: _style(14),
          borderRadius: BorderRadius.circular(16),
          child: const SizedBox(height: 40, child: Text('card')),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    final controller = tester
        .widget<ChatFrostedBackdropScope>(find.byType(ChatFrostedBackdropScope))
        .controller;
    final generationA = controller.generation;
    expect(find.byType(RawImage), findsOneWidget);

    await assistants.updateAssistant(
      assistants.currentAssistant!.copyWith(
        background: 'https://example.com/wallpaper-b.png',
      ),
    );
    await tester.pump();

    expect(controller.generation, greaterThan(generationA));
    expect(find.byType(RawImage), findsNothing);
    expect(find.byType(BackdropFilter), findsNothing);
    expect(_countLayers<BackdropFilterLayer>(tester), 0);

    await tester.pump();
    expect(find.byType(BackdropFilter), findsNothing);
  });

  testWidgets(
    'capture failure uses a shared BackdropGroup then returns to tint',
    (tester) async {
      debugFrostedForceSnapshotFailure = true;
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
          background: 'https://example.com/wallpaper-a.png',
        ),
      );
      final settings = SettingsProvider(createBusinessTestPreferences());
      await settings.loaded;

      await tester.pumpWidget(
        _app(
          assistants: assistants,
          settings: settings,
          child: const Column(
            children: [
              FrostedSurface(
                style: ResolvedBubbleStyle(
                  background: Color(0xA8FFFFFF),
                  border: Color(0x24FFFFFF),
                  text: Color(0xFF111111),
                  borderWidth: 0.8,
                  radius: 16,
                  blurSigma: 12,
                ),
                borderRadius: BorderRadius.all(Radius.circular(16)),
                child: SizedBox(height: 40, child: Text('one')),
              ),
              FrostedSurface(
                style: ResolvedBubbleStyle(
                  background: Color(0xA8FFFFFF),
                  border: Color(0x24FFFFFF),
                  text: Color(0xFF111111),
                  borderWidth: 0.8,
                  radius: 16,
                  blurSigma: 18,
                ),
                borderRadius: BorderRadius.all(Radius.circular(16)),
                child: SizedBox(height: 40, child: Text('two')),
              ),
            ],
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byType(BackdropFilter), findsNWidgets(2));
      final filters = tester.renderObjectList<RenderBackdropFilter>(
        find.byType(BackdropFilter),
      );
      expect(filters, hasLength(2));
      expect(filters.first.backdropKey, isNotNull);
      expect(filters.first.backdropKey, same(filters.last.backdropKey));

      final controller = tester
          .widget<ChatFrostedBackdropScope>(
            find.byType(ChatFrostedBackdropScope),
          )
          .controller;
      expect(controller.snapshotUnsupported, isTrue);
      expect(controller.mode, FrostedRenderMode.liveBackdropFilter);

      // A missing local file is "no wallpaper" without hitting
      // AssistantProvider's path_provider cleanup (hangs in this VM).
      await assistants.updateAssistant(
        assistants.currentAssistant!.copyWith(
          background: 'missing-local-wallpaper.png',
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(controller.mode, FrostedRenderMode.uniform);
      expect(controller.snapshotUnsupported, isTrue);
      expect(find.byType(BackdropFilter), findsNothing);
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
