import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/features/intelligent_ui/widgets/gallery/table_gallery.dart';
import 'package:Kelivo/features/intelligent_ui/widgets/gallery/chart_gallery.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/theme/theme_factory.dart';
import '../support/business_test_harness.dart';
import '../support/genui_golden_fonts.dart';
import '../support/markdown_backdrop_host.dart';

void main() {
  setUpAll(loadGenUiGoldenFonts);
  for (final dark in [false, true]) {
    for (final variant in [
      'mobile',
      'desktop',
      'rtl',
      'large',
      'filtered',
      'empty',
      'invalid',
      'export',
      'chart-data',
      'wallpaper',
    ]) {
      testWidgets('Table ${dark ? 'dark' : 'light'} $variant', (tester) async {
        final width = variant == 'desktop' ? 900.0 : 390.0;
        final height = variant == 'large' ? 1500.0 : 1200.0;
        tester.view.physicalSize = Size(width, height);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final theme = dark ? buildDarkTheme(null) : buildLightTheme(null);
        final settings = SettingsProvider(createBusinessTestPreferences());
        await settings.loaded;
        addTearDown(settings.dispose);
        const key = ValueKey('table-golden');
        final content = SizedBox(
          width: width,
          height: height,
          child: SingleChildScrollView(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: variant == 'chart-data'
                      ? const GenUiChartGallery(kind: 'line', dataView: true)
                      : GenUiTableGallery(
                          kind: variant == 'empty'
                              ? 'table-empty'
                              : variant == 'invalid'
                              ? 'table-invalid'
                              : 'table',
                          filtered:
                              variant == 'filtered' || variant == 'export',
                          exporting: variant == 'export',
                        ),
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
                  textScaler: TextScaler.linear(variant == 'large' ? 1.3 : 1),
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
                  child: variant == 'wallpaper'
                      ? MarkdownWallpaperTestHost(child: content)
                      : ColoredBox(
                          color: theme.colorScheme.surface,
                          child: content,
                        ),
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
          matchesGoldenFile(
            'baselines/genui/table_${dark ? 'dark' : 'light'}_$variant.png',
          ),
        );
      });
    }
  }
}
