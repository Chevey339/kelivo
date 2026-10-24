import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import '../support/business_test_harness.dart';
import 'package:Kelivo/features/intelligent_ui/catalog/ui_catalog.dart';
import 'package:Kelivo/features/intelligent_ui/runtime/ui_surface_controller.dart';
import 'package:Kelivo/features/intelligent_ui/runtime/ui_surface_state.dart';
import 'package:Kelivo/features/intelligent_ui/widgets/gallery/content_gallery.dart';
import 'package:Kelivo/features/intelligent_ui/widgets/gallery/input_gallery.dart';
import 'package:Kelivo/features/intelligent_ui/widgets/genui_layout.dart';
import 'package:Kelivo/features/intelligent_ui/widgets/genui_surface.dart';
import 'package:Kelivo/features/intelligent_ui/widgets/genui_theme.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/theme/theme_factory.dart';
import '../support/markdown_backdrop_host.dart';
import '../support/genui_golden_fonts.dart';

void main() {
  setUpAll(loadGenUiGoldenFonts);
  for (final dark in [false, true]) {
    for (final variant in [
      'mobile',
      'rtl',
      'large',
      'wallpaper',
      'desktop',
      'stream',
      'shell',
      'shell-wallpaper',
      'inputs',
      'inputs-rtl',
      'inputs-large',
      'inputs-errors',
      'inputs-disabled',
      'inputs-readonly',
    ]) {
      testWidgets('GenUI ${dark ? 'dark' : 'light'} $variant', (tester) async {
        final shell = variant.startsWith('shell') || variant == 'stream';
        final inputs = variant.startsWith('inputs');
        final wallpaper = variant.contains('wallpaper');
        final rtl = variant.endsWith('rtl') || variant == 'shell-wallpaper';
        final large = variant.endsWith('large') || variant == 'shell-wallpaper';
        final width = variant == 'desktop' || variant == 'shell-wallpaper'
            ? 900.0
            : 390.0;
        final height = inputs
            ? (large ? 1500.0 : 1350.0)
            : shell
            ? 2100.0
            : large
            ? 2200.0
            : width > 390
            ? 1500.0
            : 1800.0;
        tester.view.physicalSize = Size(width, height);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final theme = (dark ? buildDarkTheme(null) : buildLightTheme(null));
        final themed = theme.copyWith(
          textTheme: theme.textTheme.apply(fontFamily: 'genui-golden'),
        );
        final controllers = <UiSurfaceController>[];
        if (shell) {
          for (var i = 0; i < 6; i++) {
            final c = UiSurfaceController(
              owner: UiSurfaceOwner(revisionId: 'golden', surfaceKey: '0:$i'),
              readOnly: i == 5,
            );
            c.updateSource(
              i == 3
                  ? 'ui 9 catalog "kelivo.native/1"\n'
                  : '${UiCatalog.header}\n${i == 1 ? 'root = Column(children=[good,bad])\ngood = Metric(label="Valid result", value=42)\nbad = Gauge(value=3)\n' : 'root = Metric(label="Local result", value=42, unit="km")\n'}',
              closed: i != 0 && i != 2,
              generation: i == 0
                  ? UiGenerationStatus.generating
                  : i == 2
                  ? UiGenerationStatus.interrupted
                  : UiGenerationStatus.complete,
            );
            if (i == 4) {
              c.setSaveFailed(true, token: c.token, sequence: c.sequence);
            }
            controllers.add(c);
            addTearDown(c.dispose);
          }
        }
        if (variant == 'stream') {
          const prefix =
              '${UiCatalog.header}\nroot = Column(children=[metric,chart])\n';
          for (var i = 0; i < controllers.length; i++) {
            controllers[i].updateSource(
              i == 0
                  ? '${UiCatalog.header}\n'
                  : '$prefix${i >= 2 ? 'metric = Metric(label="Local result", value=42)\n' : ''}${i >= 3 && i != 5 ? 'chart = Text(text="All declarations arrived")\n' : ''}',
              closed: i == 3 || i == 4,
              generation: i == 4
                  ? UiGenerationStatus.complete
                  : i == 5
                  ? UiGenerationStatus.interrupted
                  : UiGenerationStatus.generating,
            );
            controllers[i].setReadOnly(false);
            controllers[i].setSaveFailed(
              false,
              token: controllers[i].token,
              sequence: controllers[i].sequence,
            );
          }
        }
        final settings = SettingsProvider(createBusinessTestPreferences());
        await settings.loaded;
        addTearDown(settings.dispose);
        const key = ValueKey('genui-golden');
        final content = SizedBox(
          width: width,
          height: height,
          child: SingleChildScrollView(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: SelectionArea(
                    child: GenUiThemeScope(
                      child: inputs
                          ? GenUiInputGallery(
                              validation: variant == 'inputs-errors',
                              enabled: variant != 'inputs-disabled',
                              readOnly: variant == 'inputs-readonly',
                              showIntent: false,
                            )
                          : shell
                          ? GenUiColumn(
                              children: [
                                for (var i = 0; i < controllers.length; i++)
                                  GenUiSurface(
                                    controller: controllers[i],
                                    title: variant == 'stream'
                                        ? 'Streaming step ${i + 1}'
                                        : const [
                                            'Streaming',
                                            'Node errors',
                                            'Interrupted',
                                            'Invalid',
                                            'Not saved',
                                            'Read-only snapshot',
                                          ][i],
                                    exporting: i == 5 && variant != 'stream',
                                    onRetrySave: i == 4 ? () {} : null,
                                  ),
                              ],
                            )
                          : const GenUiContentGallery(),
                    ),
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
              theme: themed,
              locale: const Locale('en'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: TextScaler.linear(large ? 1.3 : 1),
                  disableAnimations: true,
                ),
                child: Directionality(
                  textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
                  child: child!,
                ),
              ),
              home: Scaffold(
                body: RepaintBoundary(
                  key: key,
                  child: wallpaper
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
        // The fixture must fit: a scroll viewport is used only to match the
        // message host's layout constraints, never to conceal a clipped sample.
        final scroll = tester.state<ScrollableState>(
          find.byType(Scrollable).first,
        );
        expect(scroll.position.maxScrollExtent, 0);
        await expectLater(
          find.byKey(key),
          matchesGoldenFile(
            'baselines/genui/${dark ? 'dark' : 'light'}_$variant.png',
          ),
        );
      });
    }
  }
}
