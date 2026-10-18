import 'dart:convert';
import 'dart:io';

import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/markdown/markdown_with_code_highlight.dart';
import 'package:flutter/material.dart';
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
    final cold = Stopwatch()..start();
    await tester.pumpWidget(host(streaming: false));
    cold.stop();
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox.shrink());
    source.value = markstreamAppendFixture.substring(0, 29936);
    await tester.pumpWidget(host(streaming: true));
    await tester.pump(const Duration(milliseconds: 100));
    scroll.jumpTo(scroll.position.maxScrollExtent);
    await tester.pump();
    final firstPumps = <int>[];
    final contentPumps = <int>[];
    for (var token = 0; token < 64; token++) {
      source.value = markstreamAppendFixture.substring(0, 29937 + token);
      final first = Stopwatch()..start();
      await tester.pump();
      first.stop();
      // The current renderer schedules its 50 ms coalescing timer in
      // didUpdateWidget. Its first pump therefore does not render the token.
      // Record that frame separately from the frame that actually paints it.
      final content = Stopwatch()..start();
      await tester.pump(const Duration(milliseconds: 50));
      content.stop();
      if (token >= 8) {
        firstPumps.add(first.elapsedMicroseconds);
        contentPumps.add(content.elapsedMicroseconds);
      }
      scroll.jumpTo(scroll.position.maxScrollExtent);
      await tester.pump();
    }
    firstPumps.sort();
    contentPumps.sort();
    final results = {
      'run': run,
      'renderer': 'markstream',
      'appAdapters': true,
      'selectionController': true,
      'appendChars': markstreamAppendFixture.length,
      'coldChars': markstreamColdFixture.length,
      'samples': firstPumps.length,
      'firstPumpMedianUs': firstPumps[firstPumps.length ~/ 2],
      'firstPumpP95Us': firstPumps[(firstPumps.length * .95).ceil() - 1],
      'contentPumpMedianUs': contentPumps[contentPumps.length ~/ 2],
      'contentPumpP95Us': contentPumps[(contentPumps.length * .95).ceil() - 1],
      'coldFirstFrameUs': cold.elapsedMicroseconds,
    };
    // ignore: avoid_print
    print('MARKSTREAM_RENDER ${jsonEncode(results)}');
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
