import 'dart:io';
import 'dart:ui' as ui;

import 'package:Kelivo/features/settings/search/settings_search_index.dart';
import 'package:Kelivo/features/settings/widgets/settings_search_view.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/theme/palettes.dart';
import 'package:Kelivo/theme/theme_factory.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'
    show debugDefaultTargetPlatformOverride;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

// Optional native Flutter previews. Output stays outside the repository:
// KELIVO_SEARCH_QA_DIR=/tmp/settings-search KELIVO_SEARCH_QA_FONT=/path/font.ttf
// flutter test test/features/settings/search/settings_search_visual_test.dart
void main() {
  final output = Platform.environment['KELIVO_SEARCH_QA_DIR'];
  final fontPath = Platform.environment['KELIVO_SEARCH_QA_FONT'];
  setUpAll(() async {
    if (fontPath != null) {
      final loader = FontLoader('SettingsSearchQA');
      loader.addFont(
        Future.value(ByteData.sublistView(await File(fontPath).readAsBytes())),
      );
      await loader.load();
    }
    if (output != null) {
      final loader = FontLoader('packages/lucide_icons_flutter/Lucide');
      loader.addFont(
        rootBundle.load('packages/lucide_icons_flutter/assets/lucide.ttf'),
      );
      await loader.load();
    }
  });

  for (final brightness in Brightness.values) {
    for (final scenario in [
      (
        name: 'mobile',
        size: const Size(390, 844),
        scale: 1.0,
        query: '字体',
        keyboard: 0.0,
        insets: EdgeInsets.zero,
      ),
      (
        name: 'small-keyboard',
        size: const Size(320, 568),
        scale: 1.5,
        query: '代码',
        keyboard: 240.0,
        insets: EdgeInsets.zero,
      ),
      (
        name: 'landscape',
        size: const Size(844, 390),
        scale: 1.0,
        query: '字体',
        keyboard: 0.0,
        insets: const EdgeInsets.only(left: 47, right: 47, bottom: 21),
      ),
      (
        name: 'desktop',
        size: const Size(640, 640),
        scale: 1.0,
        query: '',
        keyboard: 0.0,
        insets: EdgeInsets.zero,
      ),
      (
        name: 'empty',
        size: const Size(390, 500),
        scale: 1.0,
        query: 'zzzzzz',
        keyboard: 0.0,
        insets: EdgeInsets.zero,
      ),
    ]) {
      testWidgets('${scenario.name} ${brightness.name} fits and renders', (
        tester,
      ) async {
        debugDefaultTargetPlatformOverride = scenario.name == 'desktop'
            ? TargetPlatform.macOS
            : TargetPlatform.iOS;
        addTearDown(() => debugDefaultTargetPlatformOverride = null);
        tester.view.physicalSize = scenario.size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final boundaryKey = GlobalKey();
        final theme = brightness == Brightness.light
            ? buildLightThemeForScheme(ThemePalettes.defaultPalette.light)
            : buildDarkThemeForScheme(ThemePalettes.defaultPalette.dark);
        await tester.pumpWidget(
          MaterialApp(
            locale: const Locale('zh'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: fontPath == null
                ? theme
                : theme.copyWith(
                    textTheme: theme.textTheme.apply(
                      fontFamily: 'SettingsSearchQA',
                    ),
                  ),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(scenario.scale),
                viewInsets: EdgeInsets.only(bottom: scenario.keyboard),
              ),
              child: child!,
            ),
            home: Builder(
              builder: (context) => RepaintBoundary(
                key: boundaryKey,
                child: Scaffold(
                  body: SettingsSearchView(
                    index: SettingsSearchIndex(
                      AppLocalizations.of(context)!,
                      platform: scenario.name == 'desktop'
                          ? TargetPlatform.macOS
                          : TargetPlatform.iOS,
                    ),
                    autofocus: false,
                    safeAreaInsets: scenario.insets,
                    onSelected: (_) {},
                    onClose: () {},
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        if (scenario.query.isNotEmpty) {
          await tester.enterText(find.byType(TextField), scenario.query);
          await tester.pumpAndSettle();
        }
        expect(tester.takeException(), isNull);
        final field = tester.getRect(find.byType(TextField));
        expect(field.left, greaterThanOrEqualTo(scenario.insets.left));
        expect(
          field.right,
          lessThanOrEqualTo(scenario.size.width - scenario.insets.right),
        );
        final surface = tester.getRect(
          find.byKey(const ValueKey('settings-search-field-surface')),
        );
        expect(
          tester.getRect(find.byType(EditableText)).center.dy,
          closeTo(surface.center.dy, 0.5),
          reason: 'Input text must stay vertically centered on every platform',
        );
        if (output != null) {
          await tester.runAsync(() async {
            final boundary =
                boundaryKey.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary;
            final image = await boundary.toImage(pixelRatio: 2);
            final data = await image.toByteData(format: ui.ImageByteFormat.png);
            final directory = Directory(output)..createSync(recursive: true);
            await File(
              '${directory.path}/${scenario.name}-${brightness.name}.png',
            ).writeAsBytes(data!.buffer.asUint8List());
            image.dispose();
          });
        }
        debugDefaultTargetPlatformOverride = null;
      });
    }
  }
}
