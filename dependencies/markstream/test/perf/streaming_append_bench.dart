import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markstream/markstream.dart';

import '../../../../test/fixtures/markdown/markstream_documents.dart';
import '../../../../lib/theme/app_font_weights.dart';

void main() {
  final run = int.parse(Platform.environment['MARKSTREAM_RUN'] ?? '1');
  testWidgets('fixed-fixture streaming append and cold rendering', (
    tester,
  ) async {
    final bytes = File('../../test/fixtures/fonts/JetBrainsMono-Regular.ttf')
        .readAsBytesSync();
    await (FontLoader(
      'markstream-bench',
    )..addFont(Future.value(ByteData.sublistView(bytes)))).load();
    tester.view.physicalSize = const Size(720, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final selection = MarkstreamSelectionController();
    addTearDown(selection.dispose);
    final source = ValueNotifier(markstreamColdFixture);
    final scroll = ScrollController();
    addTearDown(source.dispose);
    addTearDown(scroll.dispose);
    Widget host({bool enabled = true, bool streaming = false}) => MaterialApp(
      theme: ThemeData(fontFamily: 'markstream-bench'),
      home: Scaffold(
        body: SelectionArea(
          child: SingleChildScrollView(
            controller: scroll,
            child: ValueListenableBuilder<String>(
              valueListenable: source,
              builder: (context, value, _) => enabled
                  ? MarkstreamView(
                      source: value,
                      selectionController: selection,
                      streaming: streaming,
                      theme: MarkstreamTheme.fromColorScheme(
                        Theme.of(context).colorScheme,
                        bodyStyle: const TextStyle(
                          fontFamily: 'markstream-bench',
                        ),
                        codeFontFamily: 'markstream-bench',
                        medium: AppFontWeights.medium,
                        semibold: AppFontWeights.semibold,
                        strong: AppFontWeights.strong,
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpWidget(host(enabled: false));
    await tester.pumpAndSettle();
    final cold = Stopwatch()..start();
    await tester.pumpWidget(host());
    cold.stop();
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox.shrink());
    source.value = markstreamAppendFixture.substring(0, 29936);
    await tester.pumpWidget(host(streaming: true));
    await tester.pumpAndSettle();
    scroll.jumpTo(scroll.position.maxScrollExtent);
    await tester.pump();
    final samples = <int>[];
    final requests = <int>[];
    for (var i = 0; i < 64; i++) {
      source.value = markstreamAppendFixture.substring(0, 29937 + i);
      final watch = Stopwatch()..start();
      await tester.pump();
      watch.stop();
      if (i >= 8) requests.add(watch.elapsedMicroseconds);
      watch
        ..reset()
        ..start();
      await tester.pump(PerformanceLimits.coalescingInterval);
      watch.stop();
      if (i >= 8) samples.add(watch.elapsedMicroseconds);
      scroll.jumpTo(scroll.position.maxScrollExtent);
      await tester.pump();
    }
    samples.sort();
    requests.sort();
    final result = {
      'run': run,
      'appendChars': markstreamAppendFixture.length,
      'coldChars': markstreamColdFixture.length,
      'samples': samples.length,
      'firstPumpMedianUs': requests[requests.length ~/ 2],
      'firstPumpP95Us': requests[(requests.length * .95).ceil() - 1],
      'contentPumpMedianUs': samples[samples.length ~/ 2],
      'contentPumpP95Us': samples[(samples.length * .95).ceil() - 1],
      'coldFirstFrameUs': cold.elapsedMicroseconds,
      'themePlatform': defaultTargetPlatform.name,
      'hostOS': Platform.operatingSystem,
      'selectionController': true,
      'appAdapters': false,
    };
    // ignore: avoid_print
    print('MARKSTREAM_RENDER ${jsonEncode(result)}');
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
