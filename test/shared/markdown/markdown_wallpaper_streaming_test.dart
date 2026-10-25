import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markstream/markstream.dart';
import 'package:provider/provider.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/markdown/markdown_with_code_highlight.dart';
import '../../support/business_test_harness.dart';
import '../../support/markdown_backdrop_host.dart';

void main() {
  testWidgets('wallpaper streaming retains prefix widgets and layer topology', (
    tester,
  ) async {
    final settings = SettingsProvider(createBusinessTestPreferences());
    await settings.loaded;
    addTearDown(settings.dispose);
    final source = ValueNotifier(
      '```dart\n// fixed prefix\nfinal x = 1;\n```\n\nTail ',
    );
    addTearDown(source.dispose);
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: settings,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: MarkdownWallpaperTestHost(
              child: SingleChildScrollView(
                child: ValueListenableBuilder<String>(
                  valueListenable: source,
                  builder: (_, value, _) =>
                      MarkdownWithCodeHighlight(text: value, streaming: true),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    final prefix = tester.widget<MarkstreamCodeBlock>(
      find.byType(MarkstreamCodeBlock),
    );
    final theme = tester
        .widget<MarkstreamView>(find.byType(MarkstreamView))
        .theme;
    Map<Type, int> layers() {
      final result = <Type, int>{};
      void visit(Layer layer) {
        result.update(
          layer.runtimeType,
          (count) => count + 1,
          ifAbsent: () => 1,
        );
        if (layer is ContainerLayer) {
          for (
            var child = layer.firstChild;
            child != null;
            child = child.nextSibling
          ) {
            visit(child);
          }
        }
      }

      visit(tester.binding.renderViews.first.debugLayer!);
      return result;
    }

    final originalLayers = layers();
    for (var i = 0; i < 20; i++) {
      source.value += 'word ';
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      expect(
        identical(
          tester.widget<MarkstreamCodeBlock>(find.byType(MarkstreamCodeBlock)),
          prefix,
        ),
        isTrue,
      );
      final nextTheme = tester
          .widget<MarkstreamView>(find.byType(MarkstreamView))
          .theme;
      expect(nextTheme, theme);
      expect(nextTheme.hashCode, theme.hashCode);
    }
    expect(layers(), originalLayers);
    expect(find.byType(BackdropFilter), findsNothing);
    expect(find.byType(CompositedTransformFollower), findsNothing);
  });
}
