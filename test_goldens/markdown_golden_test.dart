import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/widgets/export_capture_scope.dart';
import 'package:Kelivo/shared/markdown/markdown_with_code_highlight.dart';
import 'package:Kelivo/theme/theme_factory.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../test/support/business_test_harness.dart';

const _fonts = {
  'golden-latin': String.fromEnvironment(
    'MARKSTREAM_LATIN_FONT',
    defaultValue: '/System/Library/Fonts/Supplemental/Arial.ttf',
  ),
  'golden-cjk': String.fromEnvironment(
    'MARKSTREAM_CJK_FONT',
    defaultValue: '/System/Library/Fonts/Hiragino Sans GB.ttc',
  ),
  'golden-code': 'test/fixtures/fonts/JetBrainsMono-Regular.ttf',
  'golden-emoji': String.fromEnvironment(
    'MARKSTREAM_EMOJI_FONT',
    defaultValue: '/System/Library/Fonts/Apple Color Emoji.ttc',
  ),
};

void main() {
  final fixtures =
      Directory('test_goldens/fixtures')
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.md'))
          .where((file) => !file.path.endsWith('/README.md'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));
  const captureSet = String.fromEnvironment(
    'MARKSTREAM_GOLDEN_SET',
    defaultValue: 'current',
  );
  const filter = String.fromEnvironment('MARKSTREAM_GOLDEN_FILTER');
  final output = Directory('test_goldens/out/$captureSet');
  final manifest = <String, Object?>{};

  setUpAll(() async {
    if (!RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(captureSet)) {
      throw ArgumentError.value(captureSet, 'MARKSTREAM_GOLDEN_SET');
    }
    output.createSync(recursive: true);
    final assetFonts =
        jsonDecode(await rootBundle.loadString('FontManifest.json')) as List;
    for (final font in assetFonts.cast<Map<String, dynamic>>()) {
      final loader = FontLoader(font['family'] as String);
      for (final asset
          in (font['fonts'] as List).cast<Map<String, dynamic>>()) {
        loader.addFont(rootBundle.load(asset['asset'] as String));
      }
      await loader.load();
    }
    for (final entry in _fonts.entries) {
      final file = File(entry.value);
      if (!file.existsSync()) {
        throw StateError('Missing ${entry.key} font: ${entry.value}');
      }
      final bytes = file.readAsBytesSync();
      await (FontLoader(
        entry.key,
      )..addFont(Future.value(ByteData.sublistView(bytes)))).load();
    }
  });

  tearDownAll(() {
    File('${output.path}/manifest.json').writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert({
        'fonts': {
          for (final entry in _fonts.entries)
            entry.key: {
              'path': entry.value,
              'bytes': File(entry.value).lengthSync(),
            },
        },
        'pixelRatio': 1,
        'locale': 'zh_CN',
        'captures': manifest,
      }),
    );
  });

  test('synthetic corpus covers at least forty distinct cases', () {
    expect(
      fixtures.where((file) => file.path.contains('/synthetic/')).length,
      greaterThanOrEqualTo(40),
    );
  });

  for (final fixture in fixtures) {
    final id = fixture.path
        .replaceFirst('test_goldens/fixtures/', '')
        .replaceAll('/', '_')
        .replaceFirst(RegExp(r'\.md$'), '');
    if (filter.isNotEmpty && !id.contains(filter)) continue;
    for (final width in [720.0, 390.0]) {
      for (final brightness in Brightness.values) {
        for (final scale in [1.0, 1.3]) {
          final name = '${id}_${width.toInt()}_${brightness.name}_$scale';
          testWidgets(name, (tester) async {
            debugDefaultTargetPlatformOverride = width == 720
                ? TargetPlatform.macOS
                : TargetPlatform.android;
            addTearDown(() => debugDefaultTargetPlatformOverride = null);
            tester.view.physicalSize = Size(width, 900);
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.reset);
            final settings = SettingsProvider(createBusinessTestPreferences());
            await settings.loaded;
            await settings.setChatFontScale(scale);
            await settings.setCodeFontSystemFamily('golden-code');
            addTearDown(settings.dispose);
            final key = GlobalKey();
            final theme = brightness == Brightness.light
                ? buildLightTheme(null)
                : buildDarkTheme(null);
            final source = fixture.readAsStringSync();
            await tester.pumpWidget(
              ChangeNotifierProvider<SettingsProvider>.value(
                value: settings,
                child: MaterialApp(
                  theme: theme.copyWith(
                    textTheme: theme.textTheme.apply(fontFamily: 'golden-cjk'),
                  ),
                  locale: const Locale('zh', 'CN'),
                  localizationsDelegates:
                      AppLocalizations.localizationsDelegates,
                  supportedLocales: AppLocalizations.supportedLocales,
                  home: Scaffold(
                    body: SingleChildScrollView(
                      child: RepaintBoundary(
                        key: key,
                        child: Container(
                          width: width,
                          color: theme.colorScheme.surface,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: MediaQuery(
                              data: MediaQueryData(
                                size: Size(width, 900),
                                textScaler: TextScaler.linear(scale),
                              ),
                              child: ExportCaptureScope(
                                enabled: true,
                                child: SelectionArea(
                                  child: MarkdownWithCodeHighlight(
                                    text: source,
                                    streaming: id.contains('_open_'),
                                    baseStyle: const TextStyle(
                                      fontFamily: 'golden-latin',
                                      fontFamilyFallback: [
                                        'golden-cjk',
                                        'golden-emoji',
                                      ],
                                      fontSize: 15.5,
                                      height: 1.55,
                                    ),
                                    citationIndexResolver: (id) =>
                                        id == 'alpha' ? '1' : '2',
                                    onCitationTap: (_) {},
                                  ),
                                ),
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
            expect(tester.takeException(), isNull);
            final boundary =
                key.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary;
            expect(boundary.size.isFinite, isTrue);
            expect(boundary.size.height, greaterThan(0));
            final image = boundary.toImageSync();
            try {
              expect(image.width, width.toInt());
              final data = await tester.runAsync(
                () => image.toByteData(format: ui.ImageByteFormat.png),
              );
              expect(data, isNotNull);
              expect(data!.lengthInBytes, greaterThan(0));
              File('${output.path}/$name.png').writeAsBytesSync(
                data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
              );
              manifest[name] = {
                'fixture': fixture.path,
                'width': image.width,
                'height': image.height,
                'streaming': id.contains('_open_'),
              };
            } finally {
              image.dispose();
            }
            await tester.pumpWidget(const SizedBox.shrink());
            debugDefaultTargetPlatformOverride = null;
          });
        }
      }
    }
  }
}
