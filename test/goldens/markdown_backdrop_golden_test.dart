import 'dart:io';
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/markdown/diagram_code_blocks.dart';
import 'package:Kelivo/shared/markdown/markdown_with_code_highlight.dart';
import 'package:Kelivo/shared/widgets/mermaid_image_cache.dart';
import 'package:Kelivo/theme/theme_factory.dart';
import '../support/business_test_harness.dart';
import '../support/markdown_backdrop_host.dart';

void main() {
  late Uint8List wallpaper;
  final diagrams = <bool, Uint8List>{};
  setUpAll(() async {
    final fonts =
        jsonDecode(await rootBundle.loadString('FontManifest.json')) as List;
    for (final font in fonts.cast<Map<String, dynamic>>()) {
      final loader = FontLoader(font['family'] as String);
      for (final asset
          in (font['fonts'] as List).cast<Map<String, dynamic>>()) {
        loader.addFont(rootBundle.load(asset['asset'] as String));
      }
      await loader.load();
    }
    wallpaper = File(
      'test/fixtures/images/markdown_wallpaper.jpg',
    ).readAsBytesSync();
    final font = File(
      'test/fixtures/fonts/JetBrainsMono-Regular.ttf',
    ).readAsBytesSync();
    await (FontLoader(
      'wallpaper-golden',
    )..addFont(Future.value(ByteData.sublistView(font)))).load();
  });
  setUpAll(() async {
    for (final dark in [false, true]) {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      final ink = dark ? Colors.white : Colors.black;
      for (var i = 0; i < 3; i++) {
        final rect = Rect.fromLTWH(4 + i * 114, 16, 92, 42);
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(6)),
          Paint()..color = ink.withValues(alpha: .08),
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(6)),
          Paint()
            ..color = ink.withValues(alpha: .4)
            ..style = PaintingStyle.stroke,
        );
        final text = TextPainter(
          text: TextSpan(
            text: ['Source', 'Build', 'IPA'][i],
            style: TextStyle(
              fontFamily: 'wallpaper-golden',
              color: ink,
              fontSize: 12,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        text.paint(
          canvas,
          Offset(
            rect.center.dx - text.width / 2,
            rect.center.dy - text.height / 2,
          ),
        );
        text.dispose();
        if (i < 2) {
          canvas.drawLine(
            Offset(rect.right + 2, 37),
            Offset(rect.right + 20, 37),
            Paint()..color = ink,
          );
        }
      }
      final picture = recorder.endRecording();
      final image = await picture.toImage(336, 74);
      final data = (await image.toByteData(format: ui.ImageByteFormat.png))!;
      diagrams[dark] = data.buffer.asUint8List(
        data.offsetInBytes,
        data.lengthInBytes,
      );
      image.dispose();
      picture.dispose();
    }
  });
  const fixtures = {
    'code':
        '```dart\n// Export at full resolution\nfinal size = measure("app.ipa");\nif (size > 48.5) {\n  warn("Budget exceeded");\n}\n```',
    'table':
        '| Platform | Size | Change |\n| --- | --- | --- |\n| arm64 | 41.2 MB | -3.1% |\n| x86_64 | 44.8 MB | +0.4% |',
    'details':
        '<details open>\n<summary>Build log</summary>\n\nBuild completed in 38 seconds. Press <kbd>K</kbd> to continue.\n\n</details>',
    'diagram': '```mermaid\ngraph LR\nSource --> Build --> IPA\n```',
  };
  for (final dark in [false, true]) {
    for (final entry in fixtures.entries) {
      testWidgets('wallpaper ${dark ? "dark" : "light"} ${entry.key}', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(390, 480);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final settings = SettingsProvider(createBusinessTestPreferences());
        await settings.loaded;
        await settings.setCodeFontSystemFamily('wallpaper-golden');
        addTearDown(settings.dispose);
        // Exercise the actual diagram surface/chrome without an external webview.
        debugMermaidBitmapRenderOverride = (_, __, ___) async =>
            MermaidBitmapRenderResult.success(diagrams[dark]!);
        MermaidImageCache.clear();
        addTearDown(() {
          debugMermaidBitmapRenderOverride = null;
          MermaidImageCache.clear();
        });
        final theme = dark ? buildDarkTheme(null) : buildLightTheme(null);
        const key = ValueKey('wallpaper-golden');
        await tester.pumpWidget(
          ChangeNotifierProvider.value(
            value: settings,
            child: MaterialApp(
              theme: theme,
              locale: const Locale('en'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: MarkdownWallpaperTestHost(
                  child: RepaintBoundary(
                    key: key,
                    child: Container(
                      width: 390,
                      height: 480,
                      decoration: BoxDecoration(
                        image: DecorationImage(
                          image: MemoryImage(wallpaper),
                          fit: BoxFit.cover,
                        ),
                      ),
                      child: ColoredBox(
                        color: theme.colorScheme.surface.withValues(alpha: .2),
                        child: SingleChildScrollView(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: MarkdownWithCodeHighlight(
                              text: entry.value,
                              baseStyle: const TextStyle(
                                fontFamily: 'wallpaper-golden',
                                fontSize: 15.5,
                                height: 1.55,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.runAsync(
          () => precacheImage(
            MemoryImage(wallpaper),
            tester.element(find.byKey(key)),
          ),
        );
        await tester.runAsync(
          () => precacheImage(
            MemoryImage(diagrams[dark]!),
            tester.element(find.byKey(key)),
          ),
        );
        await tester.pump(const Duration(milliseconds: 250));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await expectLater(
          find.byKey(key),
          matchesGoldenFile(
            'baselines/markdown_backdrop/${dark ? "dark" : "light"}_${entry.key}.png',
          ),
        );
      });
    }
  }
}
