import 'package:Kelivo/features/intelligent_ui/widgets/genui_surface.dart';
import 'package:Kelivo/features/intelligent_ui/runtime/ui_surface_controller.dart';
import 'package:provider/provider.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import '../support/business_test_harness.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:Kelivo/features/intelligent_ui/widgets/gallery/expansion_gallery.dart';
import 'package:Kelivo/features/intelligent_ui/widgets/genui_expansion.dart';
import 'package:Kelivo/features/intelligent_ui/widgets/genui_theme.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/widgets/ios_tactile.dart';
import 'package:Kelivo/theme/theme_factory.dart';
import '../support/genui_golden_fonts.dart';
import '../support/markdown_backdrop_host.dart';

void main() {
  setUpAll(loadGenUiGoldenFonts);
  for (final dark in [false, true]) {
    for (final variant in [
      'stub',
      'readonly',
      'readonly-rtl',
      'readonly-large',
      'mobile',
      'desktop',
    ]) {
      testWidgets('Expansion ${dark ? 'dark' : 'light'} $variant', (
        tester,
      ) async {
        final width = variant == 'desktop' ? 1200.0 : 390.0;
        tester.view.physicalSize = Size(width, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final theme = dark ? buildDarkTheme(null) : buildLightTheme(null);
        final settings = SettingsProvider(createBusinessTestPreferences());
        await settings.loaded;
        addTearDown(settings.dispose);
        const key = ValueKey('expansion-golden');
        await tester.pumpWidget(
          ChangeNotifierProvider.value(
            value: settings,
            child: RepaintBoundary(
              key: key,
              child: MaterialApp(
                debugShowCheckedModeBanner: false,
                theme: theme.copyWith(
                  textTheme: theme.textTheme.apply(fontFamily: 'genui-golden'),
                  appBarTheme: theme.appBarTheme.copyWith(
                    titleTextStyle: theme.textTheme.titleLarge?.copyWith(
                      fontFamily: 'genui-golden',
                    ),
                  ),
                ),
                locale: const Locale('en'),
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    disableAnimations: true,
                    textScaler: TextScaler.linear(
                      variant.endsWith('large') ? 1.3 : 1,
                    ),
                  ),
                  child: Directionality(
                    textDirection: variant.endsWith('rtl')
                        ? TextDirection.rtl
                        : TextDirection.ltr,
                    child: child!,
                  ),
                ),
                home: Scaffold(
                  body: MarkdownWallpaperTestHost(
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: GenUiThemeScope(
                          child: variant == 'stub'
                              ? const GenUiExpandedStub()
                              : GenUiExpansionGallery(
                                  exporting: variant.startsWith('readonly'),
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
        await tester.pumpAndSettle();
        if (variant == 'mobile' || variant == 'desktop') {
          await tester.tap(
            find.byWidgetPredicate(
              (w) => w is IosIconButton && w.tooltip == 'Expand',
            ),
          );
          await tester.pumpAndSettle();
        }
        expect(tester.takeException(), isNull);
        for (final surface in tester.widgetList<GenUiSurface>(
          find.byType(GenUiSurface),
        )) {
          expect(surface.controller.phase, SurfacePhase.complete);
        }
        await expectLater(
          find.byKey(key),
          matchesGoldenFile(
            'baselines/genui/expansion_${dark ? 'dark' : 'light'}_$variant.png',
          ),
        );
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
      });
    }
  }
}
