import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/features/intelligent_ui/widgets/gallery/chart_gallery.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/theme/theme_factory.dart';
import '../support/business_test_harness.dart';
import '../support/genui_golden_fonts.dart';
import '../support/markdown_backdrop_host.dart';

void main() {
  setUpAll(loadGenUiGoldenFonts);
  for (final kind in genUiChartGallerySources.keys) {
    for (final variant in ['light', 'dark', 'rtl', 'large']) {
      testWidgets('Chart $kind $variant', (tester) async {
        await _capture(tester, kind: kind, variant: variant);
      });
    }
  }
  for (final variant in ['wallpaper-light', 'wallpaper-dark', 'desktop']) {
    testWidgets('Chart gaps $variant', (tester) async {
      await _capture(tester, kind: 'gaps', variant: variant);
    });
  }
}

Future<void> _capture(
  WidgetTester tester, {
  required String kind,
  required String variant,
}) async {
  final dark = variant.contains('dark') || variant == 'large';
  final large = variant == 'large';
  final wallpaper = variant.startsWith('wallpaper');
  final width = variant == 'desktop' ? 900.0 : 390.0;
  final height = kind == 'gaps' ? 950.0 : 700.0;
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final theme = dark ? buildDarkTheme(null) : buildLightTheme(null);
  final settings = SettingsProvider(createBusinessTestPreferences());
  await settings.loaded;
  addTearDown(settings.dispose);
  const key = ValueKey('chart-golden');
  final content = SizedBox(
    width: width,
    height: height,
    child: SingleChildScrollView(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: GenUiChartGallery(kind: kind),
          ),
        ),
      ),
    ),
  );
  await tester.pumpWidget(
    ChangeNotifierProvider.value(
      value: settings,
      child: MaterialApp(
        theme: theme.copyWith(
          textTheme: theme.textTheme.apply(fontFamily: 'genui-golden'),
        ),
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            disableAnimations: true,
            textScaler: TextScaler.linear(large ? 1.3 : 1),
          ),
          child: Directionality(
            textDirection: variant == 'rtl'
                ? TextDirection.rtl
                : TextDirection.ltr,
            child: child!,
          ),
        ),
        home: Scaffold(
          body: RepaintBoundary(
            key: key,
            child: wallpaper
                ? MarkdownWallpaperTestHost(child: content)
                : ColoredBox(color: theme.colorScheme.surface, child: content),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
  expect(
    tester
        .state<ScrollableState>(find.byType(Scrollable).first)
        .position
        .maxScrollExtent,
    0,
  );
  await expectLater(
    find.byKey(key),
    matchesGoldenFile('baselines/genui/chart_${kind}_$variant.png'),
  );
}
