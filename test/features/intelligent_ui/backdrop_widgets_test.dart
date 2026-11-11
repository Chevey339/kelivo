import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markstream/markstream.dart';
import 'package:provider/provider.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/desktop/widgets/desktop_select_dropdown.dart';
import 'package:Kelivo/features/intelligent_ui/host/gallery/web_gallery.dart';
import 'package:Kelivo/features/intelligent_ui/host/ui_web_document.dart';
import 'package:Kelivo/features/intelligent_ui/runtime/ui_surface_controller.dart';
import 'package:Kelivo/features/intelligent_ui/runtime/ui_surface_state.dart';
import 'package:Kelivo/features/intelligent_ui/widgets/genui_content.dart';
import 'package:Kelivo/features/intelligent_ui/widgets/genui_expansion.dart';
import 'package:Kelivo/features/intelligent_ui/widgets/genui_expansion_snapshot.dart';
import 'package:Kelivo/features/intelligent_ui/widgets/genui_layout.dart';
import 'package:Kelivo/features/intelligent_ui/widgets/genui_surface.dart';
import 'package:Kelivo/features/intelligent_ui/widgets/genui_theme.dart';
import 'package:Kelivo/features/intelligent_ui/widgets/genui_web_card.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/markdown/markdown_surface_scope.dart';
import 'package:Kelivo/shared/markdown/markdown_theme_mapper.dart';
import 'package:Kelivo/shared/widgets/ios_text_button.dart';
import 'package:Kelivo/theme/theme_factory.dart';
import '../../support/business_test_harness.dart';
import '../../support/markdown_backdrop_host.dart';

const _source = r'''ui 1 catalog "kelivo.native/1"
$name: string = "initial"
root = Column(children=[label,nameField,table])
label = Text(text="Native content")
nameField = TextField(label="Name",bind=$name)
table = DataTable(columns=[{"key":"name","label":"Name"}],data=[{"name":"One"}],rowKey="name",filterable=false)
''';

double _contrast(Color foreground, Color background) {
  final a = Color.alphaBlend(foreground, background).computeLuminance();
  final b = background.computeLuminance();
  return a >= b ? (a + .05) / (b + .05) : (b + .05) / (a + .05);
}

void main() {
  late SettingsProvider settings;
  late UiSurfaceController controller;
  setUp(() async {
    settings = SettingsProvider(createBusinessTestPreferences());
    await settings.loaded;
    controller =
        UiSurfaceController(
          owner: const UiSurfaceOwner(
            revisionId: 'backdrop',
            surfaceKey: '0:0',
          ),
        )..updateSource(
          _source,
          closed: true,
          generation: UiGenerationStatus.complete,
        );
  });
  tearDown(() {
    controller.dispose();
    settings.dispose();
  });

  Widget app(
    Widget Function(MarkstreamTheme) child, {
    bool dark = false,
    MarkdownSurfaceKind kind = MarkdownSurfaceKind.tinted,
    Color? customBackground,
    Color? customInk,
  }) => ChangeNotifierProvider.value(
    value: settings,
    child: MaterialApp(
      theme: dark ? buildDarkTheme(null) : buildLightTheme(null),
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: MarkdownWallpaperTestHost(
          child: MarkdownSurfaceScope(
            kind: kind,
            customBackground: customBackground,
            child: DefaultTextStyle(
              style: TextStyle(
                color: customInk ?? (dark ? Colors.white : Colors.black),
              ),
              child: SingleChildScrollView(
                child: Builder(
                  builder: (context) =>
                      child(mapMarkdownTheme(context, settings, null)),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );

  GenUiTheme palette(WidgetTester tester) =>
      GenUiTheme.of(tester.element(find.byType(GenUiText).first));

  testWidgets('translucent expansion snapshots include the wallpaper pixels', (
    tester,
  ) async {
    final anchor = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          backgroundColor: Colors.blue,
          body: Center(
            child: RepaintBoundary(
              child: GenUiExpansionAnchor(
                key: anchor,
                child: const SizedBox(
                  width: 100,
                  height: 80,
                  child: ColoredBox(color: Color(0x80ffffff)),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    final context = anchor.currentContext!;
    final render = context.findRenderObject()! as RenderGenUiExpansionAnchor;
    final snapshot = render.capture(
      MediaQuery.of(context),
      includeBackdrop: true,
    )!;
    final pixels = await tester.runAsync(
      () => snapshot.image.toByteData(format: ui.ImageByteFormat.rawRgba),
    );
    expect(
      pixels!.getUint8(3),
      255,
      reason:
          'The return overlay must not double-composite a translucent card.',
    );
    final expected = Color.alphaBlend(const Color(0x80ffffff), Colors.blue);
    expect(pixels.getUint8(0), closeTo((expected.r * 255).round(), 1));
    expect(pixels.getUint8(1), closeTo((expected.g * 255).round(), 1));
    expect(pixels.getUint8(2), closeTo((expected.b * 255).round(), 1));
    snapshot.dispose();
  });

  for (final dark in [false, true]) {
    testWidgets(
      'semantic content remains readable on inverted bubbles, dark=$dark',
      (tester) async {
        final background = dark ? Colors.white : Colors.black;
        final ink = dark ? Colors.black : Colors.white;
        late GenUiTheme theme;
        const tones = ['info', 'primary', 'success', 'tip', 'warning', 'error'];
        await tester.pumpWidget(
          app(
            (markdown) => GenUiThemeScope(
              markdownTheme: markdown,
              child: Builder(
                builder: (context) {
                  theme = GenUiTheme.of(context);
                  return Column(
                    children: [
                      for (final tone in tones) ...[
                        GenUiCallout(
                          title: 'Callout $tone',
                          text: 'Example',
                          tone: tone,
                        ),
                        GenUiBadge(text: 'Badge $tone', tone: tone),
                        GenUiSection(
                          title: 'Section $tone',
                          tone: tone,
                          children: const [],
                        ),
                      ],
                      const GenUiMetric(label: 'Metric', value: 42, trend: 2),
                    ],
                  );
                },
              ),
            ),
            dark: dark,
            customBackground: background,
            customInk: ink,
          ),
        );
        await tester.pumpAndSettle();
        for (final wallpaper in [Colors.black, Colors.grey, Colors.white]) {
          final surface = Color.alphaBlend(theme.surface, wallpaper);
          for (final tone in tones) {
            final callout = find.byWidgetPredicate(
              (w) => w is GenUiCallout && w.tone == tone,
            );
            final panel = tester.widget<Container>(
              find
                  .descendant(of: callout, matching: find.byType(Container))
                  .first,
            );
            final fill = (panel.decoration! as BoxDecoration).color!;
            final foreground = tester
                .widget<Text>(find.text('Callout $tone'))
                .style!
                .color!;
            expect(
              _contrast(foreground, Color.alphaBlend(fill, surface)),
              greaterThanOrEqualTo(4.5),
              reason: 'Callout $tone on $wallpaper',
            );
            final badge = find.byWidgetPredicate(
              (w) => w is GenUiBadge && w.tone == tone,
            );
            final capsule = tester.widget<Container>(
              find
                  .descendant(of: badge, matching: find.byType(Container))
                  .first,
            );
            final badgeInk = tester
                .widget<Text>(find.text('Badge $tone'))
                .style!
                .color!;
            expect(
              _contrast(
                badgeInk,
                (capsule.decoration! as BoxDecoration).color!,
              ),
              greaterThanOrEqualTo(4.5),
              reason: 'Badge $tone',
            );
            final section = find.byWidgetPredicate(
              (w) => w is GenUiSection && w.tone == tone,
            );
            for (final icon in tester.widgetList<Icon>(
              find.descendant(of: section, matching: find.byType(Icon)),
            )) {
              expect(
                _contrast(icon.color!, surface),
                greaterThanOrEqualTo(3),
                reason: 'Section $tone',
              );
            }
          }
          final metric = find.byType(GenUiMetric);
          final panel = tester.widget<Container>(
            find.descendant(of: metric, matching: find.byType(Container)).first,
          );
          final metricBackground = Color.alphaBlend(
            (panel.decoration! as BoxDecoration).color!,
            surface,
          );
          final trend = tester.widget<Text>(find.text('+2')).style!.color!;
          expect(_contrast(trend, metricBackground), greaterThanOrEqualTo(4.5));
        }
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'custom bubble controls and dialogs use their own ink, dark=$dark',
      (tester) async {
        final background = dark ? Colors.white : Colors.black;
        final ink = dark ? Colors.black : Colors.white;
        controller.updateSource(
          r'''ui 1 catalog "kelivo.native/1"
$plan: string = "a"
root = Column(children=[label,planField])
label = Text(text="Native content")
planField = Select(label="Plan",bind=$plan,options=[{"value":"a","label":"Plan A"},{"value":"b","label":"Plan B"}])
''',
          closed: true,
          generation: UiGenerationStatus.complete,
        );
        expect(
          controller.phase,
          SurfacePhase.complete,
          reason: controller.parsed.program.diagnostics.toString(),
        );
        await tester.pumpWidget(
          app(
            (theme) => GenUiSurface(
              controller: controller,
              markdownTheme: theme,
              onExport: () async {},
            ),
            dark: dark,
            customBackground: background,
            customInk: ink,
          ),
        );
        await tester.pumpAndSettle();
        expect(
          tester.widget<Text>(find.text('Plan A')).style!.color,
          ink.withValues(alpha: .88),
        );
        final menu = tester.widget<DesktopSelectDropdown<Object?>>(
          find.byType(DesktopSelectDropdown<Object?>),
        );
        expect(menu.menuBackgroundColor!.a, 1);
        final appInk = (dark ? buildDarkTheme(null) : buildLightTheme(null))
            .colorScheme
            .onSurface;
        await tester.tap(find.byTooltip('More'));
        await tester.pumpAndSettle();
        final export = tester.widget<IosTextButton>(
          find.byWidgetPredicate(
            (widget) =>
                widget is IosTextButton &&
                widget.label == 'Export read-only snapshot',
          ),
        );
        expect(export.color, appInk);
        await tester.tap(find.byTooltip('Close'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Plan A'));
        await tester.pumpAndSettle();
        expect(
          tester.widget<Text>(find.text('Plan B')).style!.color,
          appInk.withValues(alpha: .88),
        );
        expect(tester.takeException(), isNull);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.macOS),
    );

    testWidgets('native and Web cards share Markdown backdrop, dark=$dark', (
      tester,
    ) async {
      for (final kind in MarkdownSurfaceKind.values) {
        for (final mask in [0.0, 1.0, 2.0]) {
          await tester.runAsync(
            () => settings.setChatBackgroundMaskStrength(mask),
          );
          late MarkstreamTheme markdown;
          await tester.pumpWidget(
            app(
              (theme) {
                markdown = theme;
                return Column(
                  children: [
                    GenUiSurface(controller: controller, markdownTheme: theme),
                    GenUiThemeScope(
                      markdownTheme: theme,
                      child: GenUiWebCard(
                        document: UiWebDocument.parse(
                          genUiWebGallerySource,
                          closed: true,
                          generation: UiGenerationStatus.complete,
                        ),
                        supported: true,
                      ),
                    ),
                  ],
                );
              },
              dark: dark,
              kind: kind,
            ),
          );
          await tester.pumpAndSettle();
          final native = palette(tester);
          expect(native.surface, markdown.table.bodyBackgroundColor);
          expect(native.surface.a, lessThan(1));
          expect(native.ink, markdown.colors.ink);
          expect(native.headerFill, markdown.chrome.background);
          expect(native.markdown.backdrop, markdown.backdrop);
          expect(native.contentBackground.a, 0);
          expect(native.fill.a, lessThan(1));
          final table = tester.widget<Container>(
            find.byKey(const ValueKey('genui-table-viewport-table')),
          );
          expect((table.decoration! as BoxDecoration).color!.a, 0);
          final web = find
              .descendant(
                of: find.byType(GenUiWebCard),
                matching: find.byType(DecoratedBox),
              )
              .first;
          expect(
            (tester.widget<DecoratedBox>(web).decoration as BoxDecoration)
                .color,
            native.surface,
          );
          expect(tester.takeException(), isNull);
        }
      }
    });

    testWidgets(
      'custom bubble ink survives inline; export uses app colors, dark=$dark',
      (tester) async {
        final background = dark ? Colors.white : Colors.black;
        final ink = dark ? Colors.black : Colors.white;
        await tester.pumpWidget(
          app(
            (theme) =>
                GenUiSurface(controller: controller, markdownTheme: theme),
            dark: dark,
            customBackground: background,
            customInk: ink,
          ),
        );
        await tester.pumpAndSettle();
        expect(palette(tester).ink, ink);
        expect(palette(tester).surface.withValues(alpha: 1), background);
        await tester.pumpWidget(
          app(
            (theme) => GenUiSurface(
              controller: controller,
              markdownTheme: theme,
              exporting: true,
            ),
            dark: dark,
            customBackground: background,
            customInk: ink,
          ),
        );
        await tester.pumpAndSettle();
        expect(palette(tester).surface.a, 1);
        expect(palette(tester).markdown.backdrop, MarkstreamBackdrop.plain);
        expect(
          palette(tester).ink,
          (dark ? buildDarkTheme(null) : buildLightTheme(null))
              .colorScheme
              .onSurface,
        );
      },
    );
  }

  testWidgets(
    'expansion uses page colors and returns to wallpaper without losing input',
    (tester) async {
      await tester.pumpWidget(
        app(
          (theme) => GenUiExpansion(
            surfaceBuilder: (expand, focus, expanded) => GenUiSurface(
              controller: controller,
              markdownTheme: theme,
              onExpand: expand,
              expandFocusNode: focus,
              expanded: expanded,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'preserved');
      final editable = find.descendant(
        of: find.byType(TextField),
        matching: find.byType(EditableText),
      );
      final editor = tester.state<EditableTextState>(editable);
      final inline = palette(tester).surface;
      await tester.tap(find.byTooltip('Expand'));
      await tester.pumpAndSettle();
      expect(palette(tester).surface.a, 1);
      expect(palette(tester).markdown.backdrop, MarkstreamBackdrop.plain);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(palette(tester).surface, inline);
      expect(tester.state<EditableTextState>(editable), same(editor));
      expect(find.text('preserved'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
