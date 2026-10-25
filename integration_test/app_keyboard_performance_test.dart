import 'dart:io';
import 'dart:ui';

import 'package:Kelivo/features/home/widgets/chat_input_bar.dart';
import 'package:Kelivo/main.dart' as app;
import 'package:Kelivo/shared/widgets/long_message_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

// Explicit profile benchmark on a test phone. This boots the real application
// and its installed data/providers. The original draft is restored afterwards.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  testWidgets(
    'profiles the real home composer and Android IME',
    (tester) async {
      await app.main();
      await tester.pump(const Duration(seconds: 8));
      expect(find.byType(ChatInputBar), findsOneWidget);
      final editorFinder = find.descendant(
        of: find.byType(ChatInputBar),
        matching: find.byType(LongMessageEditor),
      );
      final field = tester.widget<LongMessageEditor>(editorFinder);
      final controller = field.controller;
      final original = controller.value;
      final focus = field.focusNode!;
      final results = <String, Object>{'realApplication': true};

      Future<void> measure(String name, Future<void> Function() action) async {
        await tester.pump(const Duration(milliseconds: 600));
        final frames = <FrameTiming>[];
        void collect(List<FrameTiming> batch) => frames.addAll(batch);
        SchedulerBinding.instance.addTimingsCallback(collect);
        try {
          await action();
          await tester.pump(const Duration(milliseconds: 600));
        } finally {
          SchedulerBinding.instance.removeTimingsCallback(collect);
        }
        expect(frames, isNotEmpty);
        final timings = _summarize(frames)
          ..['rssBytes'] = ProcessInfo.currentRss;
        results[name] = timings;
        // ignore: avoid_print
        print('HOME_DEVICE $name $timings');
      }

      try {
        for (final characters in [1800, 3800, 64000]) {
          final source = StringBuffer();
          while (source.length < characters) {
            source.writeln('中文 English mixed content **Markdown** 1234567890.');
          }
          final text = source.toString().substring(0, characters);
          controller.value = TextEditingValue(
            text: text,
            selection: TextSelection.collapsed(offset: text.length),
          );
          await tester.pump(const Duration(seconds: 2));
          focus.unfocus();
          await tester.pump(const Duration(seconds: 1));
          await measure('home.$characters.type', () async {
            for (var index = 0; index < 40; index++) {
              controller.value = TextEditingValue(
                text: '${controller.text}测',
                selection: TextSelection.collapsed(
                  offset: controller.text.length + 1,
                ),
              );
              tester
                  .widget<LongMessageEditor>(editorFinder)
                  .onChanged
                  ?.call(controller.text);
              await tester.pump(const Duration(milliseconds: 50));
            }
          });
          expect(controller.text, '$text${'测' * 40}');
          var maximumInset = 0.0;
          await measure('home.$characters.keyboard', () async {
            for (var pass = 0; pass < 4; pass++) {
              focus.requestFocus();
              await SystemChannels.textInput.invokeMethod<void>(
                'TextInput.show',
              );
              await tester.pump(const Duration(seconds: 1));
              final inset = View.of(
                tester.element(editorFinder),
              ).viewInsets.bottom;
              if (inset > maximumInset) maximumInset = inset;
              focus.unfocus();
              await tester.pump(const Duration(seconds: 1));
            }
          });
          expect(maximumInset, greaterThan(0));
          results['home.$characters.maximumImeInsetPx'] = maximumInset;
        }
      } finally {
        focus.unfocus();
        controller.value = original;
        await tester.pump(const Duration(seconds: 1));
      }
      expect(tester.takeException(), isNull);
      binding.reportData = results;
    },
    semanticsEnabled: false,
    timeout: const Timeout(Duration(minutes: 5)),
  );
}

Map<String, Object> _summarize(List<FrameTiming> frames) {
  int percentile(Iterable<int> values, double fraction) {
    final sorted = values.toList()..sort();
    return sorted[((sorted.length - 1) * fraction).ceil()];
  }

  final starts =
      frames
          .map((frame) => frame.timestampInMicroseconds(FramePhase.vsyncStart))
          .toList()
        ..sort();
  return {
    'frames': frames.length,
    'vsyncIntervalP50Us': percentile([
      for (var index = 1; index < starts.length; index++)
        starts[index] - starts[index - 1],
    ], .5),
    'buildP95Us': percentile(
      frames.map((frame) => frame.buildDuration.inMicroseconds),
      .95,
    ),
    'rasterP95Us': percentile(
      frames.map((frame) => frame.rasterDuration.inMicroseconds),
      .95,
    ),
    'overBudget120Hz': frames
        .where(
          (frame) =>
              frame.buildDuration.inMicroseconds > 8333 ||
              frame.rasterDuration.inMicroseconds > 8333,
        )
        .length,
    'overBudget60Hz': frames
        .where(
          (frame) =>
              frame.buildDuration.inMicroseconds > 16667 ||
              frame.rasterDuration.inMicroseconds > 16667,
        )
        .length,
  };
}
