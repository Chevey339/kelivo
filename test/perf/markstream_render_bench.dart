import 'dart:convert';
import 'dart:io';

import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/markdown/markdown_with_code_highlight.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'
    show AggregatedTimings, FlutterTimeline;
import 'package:Kelivo/shared/widgets/app_selection_area.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../fixtures/markdown/markstream_documents.dart';
import '../support/business_test_harness.dart';

// Explicit diagnostic benchmark. Unit tests validate the fixtures separately.
// Run in five fresh processes, setting MARKSTREAM_RUN=1..5, so each cold
// measurement starts before this isolate has rendered any Markdown.
void main() {
  const profilePhases = bool.fromEnvironment('MARKSTREAM_PROFILE_PHASES');
  const cycles = int.fromEnvironment(
    'MARKSTREAM_BENCH_CYCLES',
    defaultValue: 1,
  );
  assert(cycles > 0);
  setUpAll(() async {
    final bytes = File(
      'test/fixtures/fonts/JetBrainsMono-Regular.ttf',
    ).readAsBytesSync();
    await (FontLoader(
      'markstream-bench',
    )..addFont(Future.value(ByteData.sublistView(bytes)))).load();
  });

  final run = int.parse(Platform.environment['MARKSTREAM_RUN'] ?? '1');
  testWidgets('fixed fixtures round $run', (tester) async {
    tester.view.physicalSize = const Size(720, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final settings = SettingsProvider(createBusinessTestPreferences());
    await settings.loaded;
    await settings.setCodeFontSystemFamily('markstream-bench');
    addTearDown(settings.dispose);
    final scroll = ScrollController();
    addTearDown(scroll.dispose);
    final source = ValueNotifier(markstreamColdFixture);
    addTearDown(source.dispose);

    Widget host({required bool streaming, bool renderMarkdown = true}) =>
        ChangeNotifierProvider<SettingsProvider>.value(
          value: settings,
          child: MaterialApp(
            theme: ThemeData(fontFamily: 'markstream-bench'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: AppSelectionArea(
                child: SingleChildScrollView(
                  controller: scroll,
                  child: ValueListenableBuilder<String>(
                    valueListenable: source,
                    builder: (_, value, _) => renderMarkdown
                        ? MarkdownWithCodeHighlight(
                            text: value,
                            streaming: streaming,
                            useBlockRendering: true,
                            baseStyle: const TextStyle(
                              fontFamily: 'markstream-bench',
                              fontSize: 15.5,
                              height: 1.55,
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                ),
              ),
            ),
          ),
        );

    // Initialize the host without invoking the Markdown parser or renderer.
    // The measured frame is the document's first render, not app startup.
    await tester.pumpWidget(host(streaming: false, renderMarkdown: false));
    await tester.pumpAndSettle();
    if (profilePhases) {
      FlutterTimeline.debugCollectionEnabled = true;
      addTearDown(() => FlutterTimeline.debugCollectionEnabled = false);
    }
    final cold = Stopwatch()..start();
    await tester.pumpWidget(host(streaming: false));
    cold.stop();
    final coldPhases = profilePhases
        ? _phaseDurations(FlutterTimeline.debugCollect())
        : null;
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox.shrink());
    source.value = markstreamAppendFixture.substring(0, 29936);
    await tester.pumpWidget(host(streaming: true));
    await tester.pump(const Duration(milliseconds: 100));
    scroll.jumpTo(scroll.position.maxScrollExtent);
    await tester.pump();
    final firstPumps = <int>[];
    final contentPumps = <int>[];
    final phaseSamples = <String, List<double>>{
      if (profilePhases)
        for (final phase in ['build', 'layout', 'paint']) phase: [],
    };
    for (var cycle = 0; cycle < cycles; cycle++) {
      if (cycle > 0) {
        // Rewind outside the measured window; each cycle warms up eight tokens.
        source.value = markstreamAppendFixture.substring(0, 29936);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        scroll.jumpTo(scroll.position.maxScrollExtent);
        await tester.pump();
      }
      for (var token = 0; token < 64; token++) {
        source.value = markstreamAppendFixture.substring(0, 29937 + token);
        final first = Stopwatch()..start();
        await tester.pump();
        first.stop();
        // The current renderer schedules its 50 ms coalescing timer in
        // didUpdateWidget. Its first pump therefore does not render the token.
        // Record that frame separately from the frame that actually paints it.
        if (profilePhases) FlutterTimeline.debugReset();
        final content = Stopwatch()..start();
        await tester.pump(const Duration(milliseconds: 50));
        content.stop();
        final phases = profilePhases
            ? _phaseDurations(FlutterTimeline.debugCollect())
            : null;
        if (token >= 8) {
          firstPumps.add(first.elapsedMicroseconds);
          contentPumps.add(content.elapsedMicroseconds);
          if (phases != null) {
            for (final entry in phases.entries) {
              phaseSamples[entry.key]!.add(entry.value);
            }
          }
        }
        scroll.jumpTo(scroll.position.maxScrollExtent);
        await tester.pump();
      }
    }
    firstPumps.sort();
    contentPumps.sort();
    for (final samples in phaseSamples.values) {
      samples.sort();
    }
    final results = {
      'run': run,
      'renderer': 'markstream',
      'appAdapters': true,
      'selectionController': true,
      'appendChars': markstreamAppendFixture.length,
      'coldChars': markstreamColdFixture.length,
      'samples': firstPumps.length,
      if (cycles != 1) 'cycles': cycles,
      'firstPumpMedianUs': firstPumps[firstPumps.length ~/ 2],
      'firstPumpP95Us': firstPumps[(firstPumps.length * .95).ceil() - 1],
      'contentPumpMedianUs': contentPumps[contentPumps.length ~/ 2],
      'contentPumpP95Us': contentPumps[(contentPumps.length * .95).ceil() - 1],
      'coldFirstFrameUs': cold.elapsedMicroseconds,
      if (profilePhases) ...{
        'coldPhaseUs': coldPhases,
        'contentPhaseMedianUs': {
          for (final entry in phaseSamples.entries)
            entry.key: entry.value[entry.value.length ~/ 2],
        },
        'contentPhaseP95Us': {
          for (final entry in phaseSamples.entries)
            entry.key: entry.value[(entry.value.length * .95).ceil() - 1],
        },
      },
    };
    // ignore: avoid_print
    print('MARKSTREAM_RENDER ${jsonEncode(results)}');
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

// Root layout/paint timings already include descendant pipeline owners. Adding
// their child events would double-count work. BUILD can include layout-time
// builders, so these diagnostics are not additive and exclude raster time.
Map<String, double> _phaseDurations(AggregatedTimings timings) => {
  'build': timings.getAggregated('BUILD').duration,
  'layout': timings.getAggregated('LAYOUT (root)').duration,
  'paint': timings.getAggregated('PAINT (root)').duration,
};
