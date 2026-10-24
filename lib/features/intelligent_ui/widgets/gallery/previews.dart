import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/theme/theme_factory.dart';
import '../genui_theme.dart';
import '../genui_chart_canvas.dart';
import '../../runtime/ui_chart_data.dart';
import 'content_gallery.dart';

@Preview(name: 'Content · light', group: 'IntelligentUI', size: Size(390, 800))
Widget genUiLightPreview() => _preview(false);

@Preview(name: 'Content · dark', group: 'IntelligentUI', size: Size(390, 800))
Widget genUiDarkPreview() => _preview(true);

@Preview(name: 'Charts · light', group: 'IntelligentUI', size: Size(390, 800))
Widget genUiChartLightPreview() => _chartPreview(false);

@Preview(name: 'Charts · dark', group: 'IntelligentUI', size: Size(390, 800))
Widget genUiChartDarkPreview() => _chartPreview(true);

void genUiPreviewChartTouch(FlTouchEvent event, GenUiChartPoint? point) {}

// Canvas-only: this preview graph stays web-safe; the interactive native
// Surface/controller gallery has its own development entry point.
Widget _chartPreview(bool dark) => MaterialApp(
  theme: dark ? buildDarkTheme(null) : buildLightTheme(null),
  locale: const Locale('en'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(
    body: GenUiThemeScope(
      child: Builder(
        builder: (context) {
          final theme = GenUiTheme.of(context);
          return ColoredBox(
            color: theme.card,
            child: ListView(
              padding: EdgeInsets.all(theme.md),
              children: [
                for (final kind in [
                  'line',
                  'area',
                  'bar',
                  'scatter',
                  'pie',
                ]) ...[
                  Text(kind, style: theme.sectionTitle),
                  SizedBox(
                    height: 220,
                    child: GenUiChartCanvas(
                      data: UiChartData.read({
                        'kind': kind,
                        'x': 'x',
                        'y': ['y'],
                        'data': [
                          {'x': 0, 'y': 2},
                          {'x': 1, 'y': 4},
                          {'x': 2, 'y': kind == 'pie' ? 1 : null},
                          {'x': 4, 'y': 3},
                        ],
                      }),
                      properties: const {'donut': true},
                      hidden: const {},
                      active: null,
                      highlightedSeries: null,
                      interactive: false,
                      onTouch: genUiPreviewChartTouch,
                      gapLabel: AppLocalizations.of(
                        context,
                      )!.genuiChartDomainGap,
                    ),
                  ),
                  SizedBox(height: theme.md),
                ],
              ],
            ),
          );
        },
      ),
    ),
  ),
);

Widget _preview(bool dark) => MaterialApp(
  theme: dark ? buildDarkTheme(null) : buildLightTheme(null),
  locale: const Locale('en'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: const Scaffold(
    body: SingleChildScrollView(
      child: SelectionArea(
        child: GenUiThemeScope(child: GenUiContentGallery()),
      ),
    ),
  ),
);
