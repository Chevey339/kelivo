import 'dart:io';

import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/widgets/markdown_with_highlight.dart';
import 'package:Kelivo/shared/widgets/section_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../support/business_test_harness.dart';

String _document(int sections) => [
  '# Skill instructions',
  for (var i = 0; i < sections; i++) ...[
    '## Step $i',
    'Read the current implementation before editing. '
        'Keep **formatting**, preserve `code` and inspect the resulting output. '
        '这是技能的说明文本，需要完整显示原有的格式。',
    '- Inspect the source\n- Run the relevant checks\n- Report the result',
    if (i % 5 == 0) '```dart\nfinal step = $i;\nprint(step);\n```',
    if (i % 10 == 0) '| Input | Output |\n| --- | --- |\n| Source | Preview |',
  ],
].join('\n\n');

void main() {
  setUpAll(() async {
    final bytes = File(
      'dependencies/gpt_markdown/lib/fonts/JetBrainsMono-Regular.ttf',
    ).readAsBytesSync();
    await (FontLoader(
      'skill-bench',
    )..addFont(Future.value(ByteData.view(bytes.buffer)))).load();
  });

  for (final sections in [100, 250]) {
    for (final blocks in [false, true]) {
      testWidgets('skill preview: $sections sections, blocks=$blocks', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(400, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final settings = SettingsProvider(createBusinessTestPreferences());
        await settings.loaded;
        addTearDown(settings.dispose);
        final controller = ScrollController();
        addTearDown(controller.dispose);
        final source = _document(sections);
        final loads = <int>[];
        final scrolls = <int>[];
        for (var run = 0; run < 4; run++) {
          await tester.pumpWidget(const SizedBox.shrink());
          final load = Stopwatch()..start();
          await tester.pumpWidget(
            ChangeNotifierProvider<SettingsProvider>.value(
              value: settings,
              child: MaterialApp(
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                home: Scaffold(
                  body: ListView(
                    controller: controller,
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                    children: [
                      const Padding(
                        padding: EdgeInsets.fromLTRB(4, 0, 4, 16),
                        child: Text('Skill instructions'),
                      ),
                      SectionCard(
                        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                        child: MarkdownWithCodeHighlight(
                          text: source,
                          useBlockRendering: blocks,
                          baseStyle: const TextStyle(
                            fontFamily: 'skill-bench',
                            fontSize: 15,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
          load.stop();
          await tester.pumpAndSettle();
          if (run > 0) loads.add(load.elapsedMicroseconds);
          for (var frame = 0; frame < 40; frame++) {
            final scroll = Stopwatch()..start();
            controller.jumpTo(controller.position.maxScrollExtent * frame / 39);
            await tester.pump();
            scroll.stop();
            if (run > 0) scrolls.add(scroll.elapsedMicroseconds);
          }
        }
        loads.sort();
        scrolls.sort();
        // ignore: avoid_print
        print(
          'RESULT sections=$sections blocks=$blocks chars=${source.length} '
          'loadMedianMs=${(loads[loads.length ~/ 2] / 1000).toStringAsFixed(2)} '
          'scrollMedianMs=${(scrolls[scrolls.length ~/ 2] / 1000).toStringAsFixed(2)} '
          'scrollP90Ms=${(scrolls[(scrolls.length * .9).floor()] / 1000).toStringAsFixed(2)}',
        );
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  }
}
