import 'dart:convert';
import 'dart:io';

import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/markdown/markdown_with_code_highlight.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;
import 'package:provider/provider.dart';

import '../../support/business_test_harness.dart';

Widget _host(SettingsProvider settings, String source, {bool ticking = true}) =>
    ChangeNotifierProvider.value(
      value: settings,
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: TickerMode(
            enabled: ticking,
            child: SizedBox(
              width: 360,
              child: MarkdownWithCodeHighlight(text: '![test]($source)'),
            ),
          ),
        ),
      ),
    );

Future<void> _decodeFirstFrame(WidgetTester tester) async {
  for (var i = 0; i < 20; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump(const Duration(milliseconds: 50));
    if (tester.widget<RawImage>(find.byType(RawImage)).image != null) break;
  }
  expect(tester.widget<RawImage>(find.byType(RawImage)).image, isNotNull);
  await tester.pump();
}

void main() {
  testWidgets('measuring a data image reuses its decoded image', (
    tester,
  ) async {
    final harness = await createBusinessTestHarness();
    final settings = SettingsProvider(harness.preferences);
    await settings.loaded;
    addTearDown(settings.dispose);
    final bytes = image.encodePng(image.Image(width: 480, height: 240));
    final cache = PaintingBinding.instance.imageCache
      ..clear()
      ..clearLiveImages();
    await tester.pumpWidget(
      _host(settings, 'data:image/png;base64,${base64Encode(bytes)}'),
    );
    final before =
        tester.widget<Image>(find.byType(Image)).image as ResizeImage;
    await _decodeFirstFrame(tester);
    final after = tester.widget<Image>(find.byType(Image)).image as ResizeImage;
    expect(after.imageProvider, same(before.imageProvider));
    expect(cache.currentSize, 1);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('measuring a paused GIF releases its image listener', (
    tester,
  ) async {
    final root = Directory.systemTemp.createTempSync('kelivo_paused_image_');
    addTearDown(() => root.deleteSync(recursive: true));
    final frames = image.Image(width: 8, height: 4)..frameDuration = 50;
    frames.addFrame(image.Image(width: 8, height: 4)..frameDuration = 50);
    final file = File('${root.path}/animation.gif')
      ..writeAsBytesSync(image.encodeGif(frames));
    final harness = await createBusinessTestHarness();
    final settings = SettingsProvider(harness.preferences);
    await settings.loaded;
    addTearDown(settings.dispose);
    await tester.pumpWidget(_host(settings, file.path, ticking: false));
    await _decodeFirstFrame(tester);
    final widget = tester.widget<Image>(find.byType(Image));
    final stream = widget.image.resolve(
      createLocalImageConfiguration(tester.element(find.byType(Image))),
    );
    expect(stream.completer!.hasListeners, isFalse);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
