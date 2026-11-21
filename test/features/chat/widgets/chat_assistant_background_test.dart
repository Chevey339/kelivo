import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:Kelivo/core/providers/assistant_provider.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/features/chat/widgets/chat_assistant_background.dart';
import 'package:Kelivo/features/chat/widgets/chat_wallpaper_image.dart';
import 'package:Kelivo/features/chat/widgets/frosted/chat_frosted_backdrop.dart';
import 'package:Kelivo/features/home/widgets/chat_input_overlay_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image/image.dart' as img;
import 'package:provider/provider.dart';

import '../../../support/business_test_harness.dart';

const _wallpaperColor = Color(0xFF4080C0);

void main() {
  testWidgets(
    'remount shares a pending wallpaper download and a repaint retries a failure',
    (tester) async {
      final firstResponse = Completer<http.Response>();
      var requests = 0;
      Widget host({Color? tint}) => MaterialApp(
        home: ChatWallpaperImage(
          source: const NetworkImage('https://wallpaper.test/recover.png'),
          tint: tint,
        ),
      );
      await http.runWithClient(
        () async {
          await tester.pumpWidget(host());
          expect(requests, 1);
          await tester.pumpWidget(const SizedBox());
          await tester.pumpWidget(host());
          expect(requests, 1);
          firstResponse.complete(http.Response('offline', 503));
          await tester.pumpAndSettle();
          expect(find.byType(RawImage), findsNothing);
          await tester.pumpWidget(host(tint: Colors.transparent));
          for (var i = 0; i < 100; i++) {
            await tester.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 5)),
            );
            await tester.pump();
            if (tester
                .widgetList<RawImage>(find.byType(RawImage))
                .any((raw) => raw.image?.width == 7)) {
              break;
            }
          }
          expect(
            tester.widget<RawImage>(find.byType(RawImage)).image?.width,
            7,
          );
          expect(requests, 2);
          await tester.pumpWidget(const SizedBox());
        },
        () => MockClient(
          (_) async => ++requests == 1
              ? firstResponse.future
              : http.Response.bytes(
                  img.encodePng(img.Image(width: 7, height: 7)),
                  200,
                ),
        ),
      );
    },
  );

  for (final remote in [false, true]) {
    testWidgets(
      'wallpaper resizes from its source and reuses identical frames (remote=$remote)',
      (tester) async {
        final original = remote
            ? const Size(3840, 2160)
            : const Size(1600, 1000);
        final bytes = img.encodePng(
          img.Image(
            width: original.width.toInt(),
            height: original.height.toInt(),
          ),
        );
        var requests = 0;
        var source = 'https://wallpaper.test/wall.png';
        if (!remote) {
          final directory = Directory.systemTemp.createTempSync('chat-resize-');
          addTearDown(() => directory.deleteSync(recursive: true));
          final file = File('${directory.path}/wallpaper.png')
            ..writeAsBytesSync(bytes);
          source = file.path;
        }
        final prefs = createBusinessTestPreferences();
        await prefs.load();
        await prefs.setString(
          'assistants_v1',
          jsonEncode([
            {'id': 'wall', 'name': 'Wall', 'background': source},
          ]),
        );
        final assistants = AssistantProvider(preferences: prefs);
        await assistants.loaded;
        final settings = SettingsProvider(createBusinessTestPreferences());
        await settings.loaded;
        addTearDown(assistants.dispose);
        addTearDown(settings.dispose);
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(640, 400);
        tester.view.display.size = const Size(5120, 2880);
        addTearDown(tester.view.reset);
        addTearDown(tester.view.display.reset);
        final cache = PaintingBinding.instance.imageCache
          ..clear()
          ..clearLiveImages();
        final raw = find.descendant(
          of: find.byType(ChatAssistantBackground),
          matching: find.byType(RawImage),
        );
        void expectBothFrames(ui.Image frame) {
          final layers = tester.widgetList<RawImage>(raw).toList();
          expect(layers, hasLength(2));
          expect(
            layers.map((w) => w.image?.isCloneOf(frame)),
            everyElement(true),
          );
        }

        await http.runWithClient(
          () async {
            await tester.pumpWidget(
              MultiProvider(
                providers: [
                  ChangeNotifierProvider.value(value: assistants),
                  ChangeNotifierProvider.value(value: settings),
                ],
                child: const MaterialApp(
                  home: ChatFrostedBackdrop(
                    backdrop: ChatAssistantBackground(
                      desktop: true,
                      includeSurfaceFill: true,
                    ),
                    child: ChatAssistantBackground(
                      desktop: true,
                      includeSurfaceFill: true,
                      pinnedToBackdrop: true,
                    ),
                  ),
                ),
              ),
            );
            final firstSize = await _waitForWallpaper(tester);
            expect(firstSize.width, inInclusiveRange(640, 1024));
            await tester.pump();
            final first = tester.widget<RawImage>(raw.first).image!.clone();
            addTearDown(first.dispose);
            expectBothFrames(first);

            // Enlarge the same wallpaper on another display after the first download.
            tester.view.display.size = const Size(3840, 2160);
            tester.view.devicePixelRatio = 2;
            tester.view.physicalSize = original;
            await tester.pump();
            expectBothFrames(first);
            expect(await _waitForWallpaper(tester), original);
            await tester.pump();
            final full = tester.widget<RawImage>(raw.first).image!.clone();
            addTearDown(full.dispose);
            for (final delta in [140, 280, 420, 560, 700, 840]) {
              tester.view.physicalSize = Size(
                original.width + delta,
                original.height,
              );
              await tester.pump();
              expectBothFrames(full);
            }
            expect(cache.currentSize, 1);
            expect(
              cache.currentSizeBytes,
              (original.width * original.height * 4).toInt(),
            );
            expect(requests, remote ? 1 : 0);
            await tester.pumpWidget(const SizedBox());
            await tester.pump();
            expect(cache.currentSize, 0);
          },
          () => MockClient((_) async {
            if (++requests > 1) return http.Response('offline', 503);
            return http.Response.bytes(bytes, 200);
          }),
        );
      },
    );
  }

  for (final desktop in [true, false]) {
    testWidgets(
      'wallpaper overlays stay aligned while sidebars and keyboard move: desktop=$desktop',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(840, 540);
        addTearDown(tester.view.reset);

        final directory = Directory.systemTemp.createTempSync('chat-pinned-');
        addTearDown(() => directory.deleteSync(recursive: true));
        final file = File('${directory.path}/wallpaper.png');
        final recorder = ui.PictureRecorder();
        const rect = Rect.fromLTWH(0, 0, 1680, 1080);
        Canvas(recorder).drawRect(
          rect,
          Paint()
            ..shader = const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.red, Colors.green, Colors.blue],
            ).createShader(rect),
        );
        final picture = recorder.endRecording();
        final image = picture.toImageSync(
          rect.width.toInt(),
          rect.height.toInt(),
        );
        final png = await tester.runAsync(
          () => image.toByteData(format: ui.ImageByteFormat.png),
        );
        file.writeAsBytesSync(png!.buffer.asUint8List());
        image.dispose();
        picture.dispose();

        final preferences = createBusinessTestPreferences();
        await preferences.load();
        await preferences.setString(
          'assistants_v1',
          jsonEncode([
            {'id': 'wallpaper', 'name': 'Wallpaper', 'background': file.path},
          ]),
        );
        final assistants = AssistantProvider(preferences: preferences);
        await assistants.loaded;
        final settings = SettingsProvider(createBusinessTestPreferences());
        await settings.loaded;
        await settings.setChatBackgroundMaskStrength(0);
        addTearDown(assistants.dispose);
        addTearDown(settings.dispose);
        final root = GlobalKey();
        final base = GlobalKey();
        final panelInsets = ValueNotifier(EdgeInsets.zero);
        addTearDown(panelInsets.dispose);
        final background = ChatAssistantBackground(
          desktop: desktop,
          includeSurfaceFill: desktop,
        );

        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider.value(value: assistants),
              ChangeNotifierProvider.value(value: settings),
            ],
            child: MaterialApp(
              home: Padding(
                // The backdrop can be smaller than MediaQuery's window size.
                padding: const EdgeInsets.all(20),
                child: RepaintBoundary(
                  key: root,
                  child: ChatFrostedBackdrop(
                    backdrop: RepaintBoundary(key: base, child: background),
                    child: ValueListenableBuilder<EdgeInsets>(
                      valueListenable: panelInsets,
                      builder: (context, insets, child) => AnimatedPadding(
                        duration: const Duration(milliseconds: 260),
                        padding: insets,
                        child: child,
                      ),
                      child: Scaffold(
                        backgroundColor: Colors.transparent,
                        body: ChatInputOverlayLayout(
                          topInset: 56,
                          backgroundImageActive: true,
                          topBackground: ChatAssistantBackground(
                            desktop: desktop,
                            includeSurfaceFill: desktop,
                            pinnedToBackdrop: true,
                            expand: desktop,
                          ),
                          content: const SizedBox.expand(),
                          bottomOverlay: const SizedBox.shrink(),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        final decoded = await _waitForWallpaper(tester);
        expect(decoded.width, inInclusiveRange(840, 1679));
        expect(decoded.height, inInclusiveRange(540, 1079));
        await tester.pumpAndSettle();

        Future<void> expectAligned(String state) async {
          final expected = await _pixels(tester, base);
          final actual = await _pixels(tester, root);
          expect(actual.length, expected.length);
          var maxDifference = 0;
          for (var i = 0; i < expected.length; i++) {
            final delta = (expected[i] - actual[i]).abs();
            if (delta > maxDifference) maxDifference = delta;
          }
          expect(maxDifference, lessThanOrEqualTo(2), reason: state);
        }

        await expectAligned('closed');
        for (final insets in [
          const EdgeInsets.only(left: 240),
          const EdgeInsets.only(left: 240, right: 120),
          EdgeInsets.zero,
        ]) {
          panelInsets.value = insets;
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 130));
          await expectAligned('animating to $insets');
          await tester.pumpAndSettle();
          await expectAligned('settled at $insets');
        }

        panelInsets.value = const EdgeInsets.only(left: 240);
        await tester.pumpAndSettle();
        await settings.setChatBackgroundMaskStrength(1);
        await tester.pumpAndSettle();
        await expectAligned('masked wallpaper with sidebar open');
        tester.view.viewInsets = const FakeViewPadding(bottom: 180);
        await tester.pumpAndSettle();
        await expectAligned('keyboard open');
        tester.view.viewInsets = FakeViewPadding.zero;
        tester.view.physicalSize = const Size(540, 840);
        await tester.pump();
        await _waitForWallpaper(tester);
        await tester.pumpAndSettle();
        await expectAligned('rotated');

        await tester.pumpWidget(const SizedBox.shrink());
        PaintingBinding.instance.imageCache.clear();
        PaintingBinding.instance.imageCache.clearLiveImages();
      },
    );
  }

  for (final config in [
    (TargetPlatform.iOS, const Size(1024, 768), true),
    (TargetPlatform.android, const Size(1280, 800), true),
    (TargetPlatform.iOS, const Size(390, 844), false),
    (TargetPlatform.windows, const Size(1440, 900), true),
  ]) {
    for (final brightness in Brightness.values) {
      testWidgets(
        '${config.$1} ${config.$2} $brightness mask updates all wallpaper layers',
        (tester) async {
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = config.$2;
          addTearDown(tester.view.reset);

          final directory = Directory.systemTemp.createTempSync('chat-mask-');
          addTearDown(() => directory.deleteSync(recursive: true));
          final file = File('${directory.path}/wallpaper.png');
          final recorder = ui.PictureRecorder();
          Canvas(recorder).drawColor(_wallpaperColor, BlendMode.src);
          final picture = recorder.endRecording();
          final image = picture.toImageSync(2, 2);
          final png = await tester.runAsync(
            () => image.toByteData(format: ui.ImageByteFormat.png),
          );
          file.writeAsBytesSync(png!.buffer.asUint8List());
          image.dispose();
          picture.dispose();

          final preferences = createBusinessTestPreferences();
          await preferences.load();
          await preferences.setString(
            'assistants_v1',
            jsonEncode([
              {'id': 'wallpaper', 'name': 'Wallpaper', 'background': file.path},
            ]),
          );
          final assistants = AssistantProvider(preferences: preferences);
          await assistants.loaded;
          final settings = SettingsProvider(createBusinessTestPreferences());
          await settings.loaded;
          addTearDown(assistants.dispose);
          addTearDown(settings.dispose);
          final boundaryKey = GlobalKey();

          await tester.pumpWidget(
            MultiProvider(
              providers: [
                ChangeNotifierProvider.value(value: assistants),
                ChangeNotifierProvider.value(value: settings),
              ],
              child: MaterialApp(
                theme: ThemeData(brightness: brightness),
                home: RepaintBoundary(
                  key: boundaryKey,
                  child: ChatAssistantBackground(
                    desktop: config.$3,
                    includeSurfaceFill: config.$3,
                  ),
                ),
              ),
            ),
          );
          await _waitForWallpaper(tester);
          await tester.pumpAndSettle();

          Future<List<Color>> sample() async {
            final boundary =
                boundaryKey.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary;
            final rendered = boundary.toImageSync();
            final bytes = await tester.runAsync(() => rendered.toByteData());
            final pixels = bytes!.buffer.asUint8List();
            final colors = [
              for (final y in [10, rendered.height ~/ 2, rendered.height - 10])
                Color.fromARGB(
                  pixels[(y * rendered.width + rendered.width ~/ 2) * 4 + 3],
                  pixels[(y * rendered.width + rendered.width ~/ 2) * 4],
                  pixels[(y * rendered.width + rendered.width ~/ 2) * 4 + 1],
                  pixels[(y * rendered.width + rendered.width ~/ 2) * 4 + 2],
                ),
            ];
            rendered.dispose();
            return colors;
          }

          final defaultColors = await sample();
          await settings.setChatBackgroundMaskStrength(0);
          await tester.pumpAndSettle();
          expect(await sample(), everyElement(_wallpaperColor));

          await settings.setChatBackgroundMaskStrength(0.5);
          await tester.pumpAndSettle();
          final halfwayColors = await sample();
          for (var i = 0; i < halfwayColors.length; i++) {
            final actual = halfwayColors[i].r;
            final original = _wallpaperColor.r;
            final masked = defaultColors[i].r;
            expect(actual, greaterThan(original < masked ? original : masked));
            expect(actual, lessThan(original > masked ? original : masked));
          }

          await settings.setChatBackgroundMaskStrength(1);
          await tester.pumpAndSettle();
          expect(await sample(), defaultColors);
          await tester.pumpWidget(const SizedBox.shrink());
          PaintingBinding.instance.imageCache.clear();
          PaintingBinding.instance.imageCache.clearLiveImages();
        },
        variant: TargetPlatformVariant({config.$1}),
      );
    }
  }
}

Future<Size> _waitForWallpaper(WidgetTester tester) async {
  final backgrounds = find.byType(ChatAssistantBackground);
  final layers = find.descendant(of: backgrounds, matching: find.byType(Image));
  for (var i = 0; i < 100 && layers.evaluate().isEmpty; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 5)),
    );
    await tester.pump();
  }
  final providers = tester
      .widgetList<Image>(layers)
      .map((w) => w.image)
      .toSet();
  // The pinned copies and base must resolve the same decoded image.
  final context = tester.element(backgrounds.first);
  final stream = providers.single.resolve(
    createLocalImageConfiguration(context),
  );
  Size? decoded;
  final listener = ImageStreamListener((info, _) {
    decoded = Size(info.image.width.toDouble(), info.image.height.toDouble());
    info.dispose();
  });
  stream.addListener(listener);
  try {
    for (var i = 0; i < 100 && decoded == null; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 5)),
      );
      await tester.pump();
    }
    expect(decoded, isNotNull);
    return decoded!;
  } finally {
    stream.removeListener(listener);
  }
}

Future<Uint8List> _pixels(WidgetTester tester, GlobalKey key) async {
  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final image = boundary.toImageSync();
  try {
    final bytes = await tester.runAsync(() => image.toByteData());
    return Uint8List.fromList(bytes!.buffer.asUint8List());
  } finally {
    image.dispose();
  }
}
