import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:Kelivo/core/providers/assistant_provider.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/features/chat/widgets/chat_assistant_background.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../../../support/business_test_harness.dart';

const _wallpaperColor = Color(0xFF4080C0);

void main() {
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

          await tester.pumpWidget(const SizedBox());
          await tester.runAsync(
            () => precacheImage(
              FileImage(file),
              tester.element(find.byType(SizedBox)),
            ),
          );

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
          await tester.runAsync(() async {
            await precacheImage(FileImage(file), boundaryKey.currentContext!);
          });
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
