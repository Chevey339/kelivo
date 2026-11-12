import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/features/intelligent_ui/widgets/genui_theme.dart';
import 'package:Kelivo/shared/markdown/markdown_surface_scope.dart';
import 'package:Kelivo/theme/theme_factory.dart';
import '../../support/markdown_backdrop_host.dart';
import '../../support/business_test_harness.dart';

double _contrast(Color foreground, Color background) {
  final a = Color.alphaBlend(foreground, background).computeLuminance();
  final b = background.computeLuminance();
  return (math.max(a, b) + .05) / (math.min(a, b) + .05);
}

void main() {
  for (final dark in [false, true]) {
    for (final material in MarkdownSurfaceKind.values) {
      testWidgets(
        'opaque GenUI contrast ${dark ? 'dark' : 'light'} ${material.name}',
        (tester) async {
          final settings = SettingsProvider(createBusinessTestPreferences());
          await settings.loaded;
          addTearDown(settings.dispose);
          late GenUiTheme palette;
          final content = MarkdownSurfaceScope(
            kind: material,
            child: GenUiThemeScope(
              child: Builder(
                builder: (context) {
                  palette = GenUiTheme.of(context);
                  return const SizedBox();
                },
              ),
            ),
          );
          await tester.pumpWidget(
            ChangeNotifierProvider.value(
              value: settings,
              child: MaterialApp(
                theme: dark ? buildDarkTheme(null) : buildLightTheme(null),
                home: material == MarkdownSurfaceKind.solid
                    ? content
                    : MarkdownWallpaperTestHost(child: content),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(palette.card.a, 1);
          expect(
            _contrast(palette.ink, palette.card),
            greaterThanOrEqualTo(4.5),
          );
          expect(
            _contrast(palette.onSuccessContainer, palette.successContainer),
            greaterThanOrEqualTo(4.5),
          );
          for (var i = 0; i < palette.chartColors.length; i++) {
            expect(
              _contrast(palette.chartColors[i], palette.card),
              greaterThanOrEqualTo(i == 5 ? 3 : 4.5),
              reason: 'Series ${i + 1}',
            );
          }
          await tester.pumpWidget(const SizedBox());
        },
      );
    }
  }
}
