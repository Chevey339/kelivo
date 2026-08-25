import 'dart:async';
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
    expect(controller.liveTransition, isTrue);
    expect(find.byType(BackdropFilter), findsWidgets);

    await tester.pump();
    await tester.pump();
    if (controller.liveTransition) {
      expect(find.byType(RawImage), findsNothing);
    } else {
      expect(controller.mode, FrostedRenderMode.cached);
    }
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

  testWidgets('backdrop pixel change recaptures without flipping to live', (
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

    final backdropKey = GlobalKey<_TwoToneBackdropState>();
    await tester.pumpWidget(
      _app(
        assistants: assistants,
        settings: settings,
        backdrop: _TwoToneBackdrop(key: backdropKey),
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
    final generationAfterFirst = controller.generation;
    final pixelsAfterFirst = controller.pixelVersion;
    expect(controller.hasCurrentSnapshot(14), isTrue);
    expect(find.byType(RawImage), findsOneWidget);
    expect(find.byType(BackdropFilter), findsNothing);

    backdropKey.currentState!.paintSecondTone();
    await tester.pump();
    await tester.pump();

    expect(controller.generation, greaterThan(generationAfterFirst));
    expect(controller.pixelVersion, greaterThan(pixelsAfterFirst));
    expect(controller.hasCurrentSnapshot(14), isTrue);
    expect(find.byType(RawImage), findsOneWidget);
    expect(find.byType(BackdropFilter), findsNothing);
    expect(_countLayers<BackdropFilterLayer>(tester), 0);
    expect(controller.mode, FrostedRenderMode.cached);
  });

  testWidgets('first frame captures once per sigma; later paint adds one', (
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

    final backdropKey = GlobalKey<_TwoToneBackdropState>();
    await tester.pumpWidget(
      _app(
        assistants: assistants,
        settings: settings,
        backdrop: _TwoToneBackdrop(key: backdropKey),
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
    expect(controller.debugCaptureCount, 1);
    expect(controller.hasCurrentSnapshot(14), isTrue);
    expect(find.byType(BackdropFilter), findsNothing);

    backdropKey.currentState!.paintSecondTone();
    await tester.pump();
    await tester.pump();

    expect(controller.debugCaptureCount, 2);
    expect(controller.hasCurrentSnapshot(14), isTrue);
    expect(find.byType(BackdropFilter), findsNothing);
  });

  testWidgets('delayed wallpaper decode recaptures after first placeholder', (
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

    final completer = Completer<ImageInfo>();
    final provider = _DelayedImageProvider(completer);
    await tester.pumpWidget(
      _app(
        assistants: assistants,
        settings: settings,
        backdrop: ColoredBox(
          color: const Color(0xFF4D5C92),
          child: Image(image: provider, fit: BoxFit.cover),
        ),
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
    final generationAfterPlaceholder = controller.generation;
    final pixelsAfterPlaceholder = controller.pixelVersion;
    final capturesAfterPlaceholder = controller.debugCaptureCount;
    expect(capturesAfterPlaceholder, greaterThanOrEqualTo(1));
    expect(controller.hasCurrentSnapshot(14), isTrue);
    expect(find.byType(BackdropFilter), findsNothing);

    completer.complete(ImageInfo(image: _solidImage(const Color(0xFF00C853))));
    await tester.pump();
    await tester.pump();

    expect(controller.generation, greaterThan(generationAfterPlaceholder));
    expect(controller.pixelVersion, greaterThan(pixelsAfterPlaceholder));
    expect(controller.debugCaptureCount, greaterThan(capturesAfterPlaceholder));
    expect(controller.hasCurrentSnapshot(14), isTrue);
    expect(
      find.descendant(
        of: find.byType(FrostedSurface),
        matching: find.byType(RawImage),
      ),
      findsOneWidget,
    );
    expect(find.byType(BackdropFilter), findsNothing);
    expect(controller.mode, FrostedRenderMode.cached);
  });

  testWidgets('AnimatedTheme intermediate frames keep live grouped glass', (
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

    var dark = false;
    late void Function(void Function()) rebuild;
    await tester.pumpWidget(
      StatefulBuilder(
        builder: (context, setState) {
          rebuild = setState;
          return MultiProvider(
            providers: [
              ChangeNotifierProvider<AssistantProvider>.value(
                value: assistants,
              ),
              ChangeNotifierProvider<SettingsProvider>.value(value: settings),
            ],
            child: MaterialApp(
              theme: dark ? ThemeData.dark() : ThemeData.light(),
              themeAnimationDuration: const Duration(milliseconds: 200),
              home: ChatFrostedBackdrop(
                backdrop: const ColoredBox(color: Color(0xFF4D5C92)),
                child: FrostedSurface(
                  style: _style(14),
                  borderRadius: BorderRadius.circular(16),
                  child: const SizedBox(height: 40, child: Text('card')),
                ),
              ),
            ),
          );
        },
      ),
    );
    await tester.pump();
    await tester.pump();

    final controller = tester
        .widget<ChatFrostedBackdropScope>(find.byType(ChatFrostedBackdropScope))
        .controller;
    expect(controller.mode, FrostedRenderMode.cached);
    expect(find.byType(BackdropFilter), findsNothing);

    dark = true;
    rebuild(() {});
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(controller.liveTransition, isTrue);
    expect(find.byType(BackdropFilter), findsWidgets);
    expect(find.byType(RawImage), findsNothing);
  });

  testWidgets('dynamic backdrop capture count is bounded', (tester) async {
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

    final flicker = GlobalKey<_FlickerBackdropState>();
    await tester.pumpWidget(
      _app(
        assistants: assistants,
        settings: settings,
        backdrop: _FlickerBackdrop(key: flicker),
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
    final baseline = controller.debugCaptureCount;
    expect(baseline, greaterThanOrEqualTo(1));

    for (var i = 0; i < 12; i++) {
      flicker.currentState!.tick();
      await tester.pump(const Duration(milliseconds: 16));
    }

    expect(controller.debugCaptureCount, lessThanOrEqualTo(baseline + 2));
    expect(controller.liveTransition, isTrue);
    expect(find.byType(BackdropFilter), findsWidgets);
  });
}

class _FlickerBackdrop extends StatefulWidget {
  const _FlickerBackdrop({super.key});

  @override
  State<_FlickerBackdrop> createState() => _FlickerBackdropState();
}

class _FlickerBackdropState extends State<_FlickerBackdrop> {
  var _frame = 0;

  void tick() => setState(() => _frame++);

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _FlickerPainter(frame: _frame),
      child: const SizedBox.expand(),
    );
  }
}

class _FlickerPainter extends CustomPainter {
  const _FlickerPainter({required this.frame});

  final int frame;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..color = frame.isEven
            ? const Color(0xFFB71C1C)
            : const Color(0xFF1B5E20),
    );
  }

  @override
  bool shouldRepaint(covariant _FlickerPainter oldDelegate) =>
      oldDelegate.frame != frame;
}

Widget _app({
  required AssistantProvider assistants,
  required SettingsProvider settings,
  required Widget child,
  Widget backdrop = const ColoredBox(color: Color(0xFF4D5C92)),
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

class _TwoToneBackdrop extends StatefulWidget {
  const _TwoToneBackdrop({super.key});

  @override
  State<_TwoToneBackdrop> createState() => _TwoToneBackdropState();
}

class _TwoToneBackdropState extends State<_TwoToneBackdrop> {
  var _second = false;

  void paintSecondTone() => setState(() => _second = true);

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _TwoTonePainter(second: _second),
      child: const SizedBox.expand(),
    );
  }
}

class _TwoTonePainter extends CustomPainter {
  const _TwoTonePainter({required this.second});

  final bool second;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..color = second ? const Color(0xFF1B5E20) : const Color(0xFFB71C1C),
    );
  }

  @override
  bool shouldRepaint(covariant _TwoTonePainter oldDelegate) =>
      oldDelegate.second != second;
}

ui.Image _solidImage(Color color) {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(const Rect.fromLTWH(0, 0, 8, 8), Paint()..color = color);
  final picture = recorder.endRecording();
  try {
    return picture.toImageSync(8, 8);
  } finally {
    picture.dispose();
  }
}

class _DelayedImageProvider extends ImageProvider<_DelayedImageProvider> {
  _DelayedImageProvider(this.completer);

  final Completer<ImageInfo> completer;

  @override
  Future<_DelayedImageProvider> obtainKey(ImageConfiguration configuration) {
    return SynchronousFuture<_DelayedImageProvider>(this);
  }

  @override
  ImageStreamCompleter loadImage(
    _DelayedImageProvider key,
    ImageDecoderCallback decode,
  ) {
    return OneFrameImageStreamCompleter(completer.future);
  }
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
