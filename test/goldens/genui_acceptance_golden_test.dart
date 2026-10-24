import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/features/intelligent_ui/catalog/ui_catalog.dart';
import 'package:Kelivo/features/intelligent_ui/runtime/ui_surface_controller.dart';
import 'package:Kelivo/features/intelligent_ui/runtime/ui_surface_state.dart';
import 'package:Kelivo/features/intelligent_ui/widgets/gallery/scenario_sources.dart';
import 'package:Kelivo/features/intelligent_ui/widgets/genui_layout.dart';
import 'package:Kelivo/features/intelligent_ui/widgets/genui_surface.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/theme/theme_factory.dart';
import '../support/business_test_harness.dart';
import '../support/genui_golden_fonts.dart';
import '../support/markdown_backdrop_host.dart';

void main() {
  setUpAll(loadGenUiGoldenFonts);
  for (final scene in ['S1', 'S6', 'shell']) {
    for (final dark in [false, true]) {
      for (final wallpaper in [false, true]) {
        for (final rtl in [false, true]) {
          for (final large in [false, true]) {
            for (final desktop in [false, true]) {
              _golden(scene, dark, wallpaper, rtl, large, desktop);
            }
          }
        }
      }
    }
  }
  // The other four composed scenes receive the requested mobile light and
  // desktop dark examples; their components have separate state matrices.
  for (final scene in ['S2', 'S3', 'S4', 'S5']) {
    _golden(scene, false, false, false, false, false);
    _golden(scene, true, false, false, false, true);
  }
}

void _golden(
  String scene,
  bool dark,
  bool wallpaper,
  bool rtl,
  bool large,
  bool desktop,
) {
  final name = [
    scene,
    dark ? 'dark' : 'light',
    wallpaper ? 'frosted' : 'solid',
    rtl ? 'rtl' : 'ltr',
    large ? '1.3' : '1.0',
    desktop ? '900' : '390',
  ].join('_');
  testWidgets(name, (tester) async {
    final width = desktop ? 900.0 : 390.0;
    final height = scene == 'shell'
        ? 2500.0
        : scene == 'S6'
        ? 2000.0
        : scene == 'S2'
        ? 1700.0
        : 1200.0;
    tester.view.physicalSize = Size(width, height);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final settings = SettingsProvider(createBusinessTestPreferences());
    await settings.loaded;
    addTearDown(settings.dispose);
    final theme = dark ? buildDarkTheme(null) : buildLightTheme(null);
    final controllers = <UiSurfaceController>[];
    UiSurfaceController controller(
      String source, {
      bool closed = true,
      UiGenerationStatus generation = UiGenerationStatus.complete,
    }) {
      final c = UiSurfaceController(
        owner: UiSurfaceOwner(
          revisionId: name,
          surfaceKey: '0:${controllers.length}',
        ),
      )..updateSource(source, closed: closed, generation: generation);
      controllers.add(c);
      addTearDown(c.dispose);
      return c;
    }

    final cards = <Widget>[];
    if (scene == 'shell') {
      final streaming = controller(
        '${UiCatalog.header}\nroot = Column(children=[result,pending])\nresult = Metric(label="Local result", value=42)\n',
        closed: false,
        generation: UiGenerationStatus.generating,
      );
      final errors = controller(
        '${UiCatalog.header}\nroot = Column(children=[result,bad])\nresult = Metric(label="Local result", value=42)\nbad = Gauge(value=3)\n',
      );
      final interrupted = controller(
        '${UiCatalog.header}\nroot = Column(children=[result,pending])\nresult = Metric(label="Local result", value=42)\n',
        closed: false,
        generation: UiGenerationStatus.interrupted,
      );
      final invalid = controller(
        'ui 9 catalog "kelivo.native/1"\nroot = Text(text="Unsupported version")\n',
      );
      final unsaved = controller(
        '${UiCatalog.header}\nroot = Metric(label="Local result", value=42)\n',
      );
      unsaved.setSaveFailed(
        true,
        token: unsaved.token,
        sequence: unsaved.sequence,
      );
      for (final (title, c) in [
        ('Generating', streaming),
        ('Node errors', errors),
        ('Interrupted', interrupted),
        ('Invalid', invalid),
        ('Not saved', unsaved),
      ]) {
        cards.add(
          GenUiSurface(
            controller: c,
            title: title,
            onRepair: () {},
            onRetrySave: c == unsaved ? () {} : null,
          ),
        );
      }
    } else {
      cards.add(
        GenUiSurface(
          controller: controller(genUiScenarioSources[scene]!),
          title: '$scene · Example data',
          onAsk: (_) async {},
        ),
      );
    }
    const capture = ValueKey('acceptance-golden');
    final content = SizedBox(
      width: width,
      height: height,
      child: SingleChildScrollView(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SelectionArea(child: GenUiColumn(children: cards)),
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
              textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
              child: child!,
            ),
          ),
          home: Scaffold(
            body: RepaintBoundary(
              key: capture,
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
    final outer = tester.state<ScrollableState>(find.byType(Scrollable).first);
    expect(
      outer.position.maxScrollExtent,
      0,
      reason: 'The entire fixture must fit',
    );
    await expectLater(
      find.byKey(capture),
      matchesGoldenFile('baselines/genui/acceptance/$name.png'),
    );
    await tester.pumpWidget(const SizedBox());
  });
}
