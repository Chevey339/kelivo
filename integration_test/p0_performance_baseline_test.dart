import 'dart:io';
import 'dart:ui';

import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/widgets/markdown_with_highlight.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('records D4/D5 macOS profile frame and RSS baseline', (
    tester,
  ) async {
    if (!Platform.isMacOS) throw UnsupportedError('p0_baseline_macos_only');
    SharedPreferences.setMockInitialValues(const {});
    final timings = <FrameTiming>[];
    void collect(List<FrameTiming> values) => timings.addAll(values);
    SchedulerBinding.instance.addTimingsCallback(collect);
    var peakRss = ProcessInfo.currentRss;
    final rssBefore = peakRss;
    try {
      final markdown = ValueNotifier<String>('');
      await tester.pumpWidget(_markdownSurface(markdown));
      await tester.pumpAndSettle();
      timings.clear();
      const block =
          '# Stream\n```dart\nvoid main() {}\n```\n'
          '|列|value|\n|-|-|\n|中文|English|\n'
          '```mermaid\ngraph TD; A-->B;\n```\n';
      final target = StringBuffer(block);
      while (target.length < 1 << 20) {
        target.writeln('Streaming plain text 中文 English seed=20260711.');
      }
      final content = target.toString().substring(0, 1 << 20);
      const chunks = 32;
      for (var index = 1; index <= chunks; index++) {
        markdown.value = content.substring(0, content.length * index ~/ chunks);
        await tester.pump(const Duration(milliseconds: 130));
        peakRss = peakRss < ProcessInfo.currentRss
            ? ProcessInfo.currentRss
            : peakRss;
      }
      await tester.pump(const Duration(milliseconds: 250));
      final d4Timings = List<FrameTiming>.from(timings);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 100));

      final bitmap = image.Image(width: 3840, height: 2160);
      image.fill(bitmap, color: image.ColorRgb8(24, 96, 180));
      final png = Uint8List.fromList(image.encodePng(bitmap, level: 1));
      timings.clear();
      await tester.pumpWidget(_rendererStressSurface(png));
      await tester.pump(const Duration(seconds: 1));
      final scrollable = find.byKey(const ValueKey('p0-d5-scroll'));
      for (var index = 0; index < 12; index++) {
        await tester.drag(scrollable, const Offset(0, -900));
        await tester.pump(const Duration(milliseconds: 16));
        peakRss = peakRss < ProcessInfo.currentRss
            ? ProcessInfo.currentRss
            : peakRss;
      }
      await tester.pump(const Duration(milliseconds: 250));
      final d5Timings = List<FrameTiming>.from(timings);

      binding.reportData = {
        'format': 'kelivo-p0-ui-profile-v1',
        'rssBeforeBytes': rssBefore,
        'rssPeakBytes': peakRss,
        'rssAfterBytes': ProcessInfo.currentRss,
        'd4': _summarize(d4Timings),
        'd5': _summarize(d5Timings),
      };
      expect(d4Timings, isNotEmpty);
      expect(d5Timings, isNotEmpty);
    } finally {
      SchedulerBinding.instance.removeTimingsCallback(collect);
    }
  });
}

Widget _markdownSurface(ValueListenable<String> markdown) {
  return ChangeNotifierProvider(
    create: (_) => SettingsProvider(),
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: SingleChildScrollView(
          child: ValueListenableBuilder<String>(
            valueListenable: markdown,
            builder: (_, value, __) =>
                MarkdownWithCodeHighlight(text: value, streaming: true),
          ),
        ),
      ),
    ),
  );
}

Widget _rendererStressSurface(Uint8List png) {
  final table = StringBuffer('|index|中文|value|\n|-:|:-|:-|\n');
  for (var index = 0; index < 1000; index++) {
    table.writeln('|$index|行|value-$index|');
  }
  final code = StringBuffer('```dart\n');
  for (var index = 0; index < 10000; index++) {
    code.writeln('final value$index = $index;');
  }
  code.writeln('```');
  return ChangeNotifierProvider(
    create: (_) => SettingsProvider(),
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: ListView(
          key: const ValueKey('p0-d5-scroll'),
          children: [
            for (var index = 0; index < 100; index++)
              Image.memory(png, width: 384, height: 216, cacheWidth: 384),
            MarkdownWithCodeHighlight(text: table.toString()),
            MarkdownWithCodeHighlight(text: code.toString()),
          ],
        ),
      ),
    ),
  );
}

Map<String, Object> _summarize(List<FrameTiming> timings) {
  int percentile(List<int> values, double fraction) {
    final sorted = [...values]..sort();
    return sorted[((sorted.length - 1) * fraction).ceil()];
  }

  final builds = timings
      .map((timing) => timing.buildDuration.inMicroseconds)
      .toList();
  final rasters = timings
      .map((timing) => timing.rasterDuration.inMicroseconds)
      .toList();
  final totals = [
    for (var index = 0; index < timings.length; index++)
      builds[index] + rasters[index],
  ];
  return {
    'frames': timings.length,
    'buildP95Micros': percentile(builds, 0.95),
    'rasterP95Micros': percentile(rasters, 0.95),
    'buildRasterP95Micros': percentile(totals, 0.95),
    'over16_7ms': totals.where((value) => value > 16700).length,
    'over100ms': totals.where((value) => value > 100000).length,
  };
}
