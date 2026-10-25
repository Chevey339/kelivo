import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:markstream/markstream.dart';
import 'package:provider/provider.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/features/chat/widgets/chat_surface.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/markdown/markdown_with_code_highlight.dart';
import 'package:Kelivo/shared/widgets/plantuml_block.dart';
import 'package:Kelivo/theme/chat_bubble_style.dart';
import 'package:Kelivo/theme/palettes.dart';

import '../../support/business_test_harness.dart';
import '../../support/markdown_backdrop_host.dart';

Widget _host(
  SettingsProvider settings,
  ColorScheme scheme,
  String source,
  GlobalKey key,
) => ChangeNotifierProvider.value(
  value: settings,
  child: MaterialApp(
    theme: ThemeData(colorScheme: scheme, brightness: scheme.brightness),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: MarkdownWallpaperTestHost(
        child: SingleChildScrollView(
          child: RepaintBoundary(
            key: key,
            child: Builder(
              builder: (context) => buildSharedChatSurface(
                context,
                borderRadius: BorderRadius.circular(16),
                padding: const EdgeInsets.all(12),
                child: MarkdownWithCodeHighlight(
                  text: '```plantuml\n$source\n```',
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  ),
);

Future<SettingsProvider> _settings() async {
  final settings = SettingsProvider(createBusinessTestPreferences());
  await settings.loaded;
  await settings.setChatMessageBackgroundStyle(
    ChatMessageBackgroundStyle.solid,
  );
  await settings.setChatBubbleStyleOverrides(
    const ChatBubbleStyleOverrides(
      backgroundArgbLight: 0xff000000,
      textArgbLight: 0xffffffff,
      backgroundArgbDark: 0xffffffff,
      textArgbDark: 0xff000000,
    ),
  );
  return settings;
}

void main() {
  for (final dark in [false, true]) {
    final scheme = dark
        ? ThemePalettes.defaultPalette.dark
        : ThemePalettes.defaultPalette.light;
    final original = MarkstreamTheme.fromColorScheme(scheme);
    testWidgets(
      'transparent PlantUML keeps its canvas; code keeps local colors, dark=$dark',
      (tester) async {
        final settings = await _settings();
        addTearDown(settings.dispose);
        final key = GlobalKey();
        final ink = dark ? 'white' : 'black';
        final source =
            '@startuml\nskinparam backgroundColor transparent\n'
            'skinparam ArrowColor $ink\nAlice -> Bob: hello\n@enduml';
        final svg =
            '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">'
            '<rect x="0" y="0" width="45" height="100" fill="$ink" /></svg>';
        await http.runWithClient(
          () async {
            await tester.pumpWidget(_host(settings, scheme, source, key));
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
            final svgRect = tester.getRect(find.byType(SvgPicture));
            final rootRect = tester.getRect(find.byKey(key));
            final side = math.min(svgRect.width, svgRect.height);
            final points = [
              svgRect.center.translate(-side / 4, 0) - rootRect.topLeft,
              svgRect.center.translate(side / 4, 0) - rootRect.topLeft,
            ];
            final boundary =
                key.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary;
            await tester.runAsync(() async {
              final image = await boundary.toImage(pixelRatio: 1);
              final pixels = (await image.toByteData(
                format: ui.ImageByteFormat.rawRgba,
              ))!;
              final sampled = [
                for (final point in points)
                  [
                    for (var channel = 0; channel < 4; channel++)
                      pixels.getUint8(
                        (point.dy.floor() * image.width + point.dx.floor()) *
                                4 +
                            channel,
                      ),
                  ],
              ];
              final canvas = original.colors.fillBlockOpaque;
              expect(sampled[0], [
                for (var c = 0; c < 3; c++) dark ? 255 : 0,
                255,
              ]);
              expect(sampled[1], [
                (canvas.r * 255).round(),
                (canvas.g * 255).round(),
                (canvas.b * 255).round(),
                255,
              ]);
              image.dispose();
            });
            final labels = AppLocalizations.of(
              tester.element(find.byType(PlantUMLBlock)),
            )!;
            await tester.tap(find.text(labels.mermaidCodeTab));
            await tester.pumpAndSettle();
            expect(find.byType(SvgPicture), findsNothing);
            final code = tester.widget<MarkstreamCodeContent>(
              find.byType(MarkstreamCodeContent),
            );
            expect(
              code.theme.code.text.color,
              dark ? Colors.black : Colors.white,
            );
            final preview = tester.widget<ColoredBox>(
              find
                  .descendant(
                    of: find.byKey(const ValueKey('plantuml-preview-body')),
                    matching: find.byType(ColoredBox),
                  )
                  .first,
            );
            expect(preview.color, Colors.transparent);
          },
          () => MockClient((request) async {
            expect(request.url.path, startsWith('/plantuml/svg/'));
            return http.Response(
              svg,
              200,
              headers: {'content-type': 'image/svg+xml'},
            );
          }),
        );
      },
    );

    testWidgets(
      'PlantUML loading and error colors match the preserved canvas, dark=$dark',
      (tester) async {
        final settings = await _settings();
        addTearDown(settings.dispose);
        final response = Completer<http.Response>();
        await http.runWithClient(() async {
          await tester.pumpWidget(
            _host(
              settings,
              scheme,
              '@startuml\nAlice -> Bob: pending $dark\n@enduml',
              GlobalKey(),
            ),
          );
          await tester.pump();
          final loading = tester.widget<CircularProgressIndicator>(
            find.byType(CircularProgressIndicator),
          );
          expect(loading.color, original.colors.ink2);
          final picture = tester.widget<SvgPicture>(find.byType(SvgPicture));
          final errorView = picture.errorBuilder!(
            tester.element(find.byType(SvgPicture)),
            StateError('fixture error'),
            StackTrace.current,
          );
          // Finish the loader normally; this test exercises our error widget's
          // colors, not the SVG package's error-reporting policy.
          response.complete(
            http.Response(
              '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 10 10" />',
              200,
            ),
          );
          await tester.pumpAndSettle();
          await tester.pumpWidget(MaterialApp(home: errorView));
          final error = tester.widget<Icon>(find.byType(Icon));
          expect(error.color, original.colors.ink3);
          expect(tester.takeException(), isNull);
        }, () => MockClient((_) => response.future));
      },
    );
  }
}
