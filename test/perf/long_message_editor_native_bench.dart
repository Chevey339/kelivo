import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../shared/text_input/mirror_harness.dart';
import 'package:Kelivo/shared/text_input/message_editing_controller.dart';
import 'package:re_editor/re_editor.dart';

// Desktop widget harness, same fixture/operations as the original Kelivo
// benchmark. Includes channel decoding, external controller mirroring and layout.
// Native edits and codec encoding are measured separately, outside this clock.
void main() {
  const samples = int.fromEnvironment('IME_BENCH_SAMPLES', defaultValue: 30);
  const requestedSize = int.fromEnvironment('IME_BENCH_SIZE');
  const requestedShape = String.fromEnvironment('IME_BENCH_SHAPE');
  const warmup = int.fromEnvironment('IME_BENCH_WARMUP', defaultValue: 8);
  int percentile(List<int> values, double fraction) {
    final sorted = [...values]..sort();
    return sorted[((sorted.length - 1) * fraction).round()];
  }

  for (final shape in ['multiline', 'single']) {
    if (requestedShape.isNotEmpty && shape != requestedShape) continue;
    for (final size
        in shape == 'multiline' ? [10000, 100000, 1000000] : [100000]) {
      if (requestedSize > 0 && size != requestedSize) continue;
      final line = '${'中文 mixed text 0123456789 ' * 9}\n';
      final seed = (line * (size ~/ line.length + 1)).substring(0, size);
      final source = shape == 'single' ? seed.replaceAll('\n', ' ') : seed;
      final caret = shape == 'single'
          ? size ~/ 2
          : (size ~/ 2 ~/ line.length) * line.length + 100;
      final paste = ('粘贴内容 pasted text\n' * 300).substring(0, 4096);
      for (final operation in [
        'type',
        'delete',
        'paste_replace_4k',
        'app_paste_replace_4k',
        'native_selection',
        'app_range_selection',
        'app_select_all',
      ]) {
        testWidgets('compact $shape $size $operation', (tester) async {
          var harness = MirrorHarness(tester);
          await harness.mount(
            source,
            caret,
            document: MessageEditingController(nativeInputEnabled: true),
          );
          final durations = <int>[], dispatch = <int>[], bytes = <int>[];
          final encoding = <int>[], outgoing = <int>[];
          var correct = true, selectionCorrect = true;
          final notices = <int>[], changes = <int>[];
          var notificationCount = 0;
          void observeController() => tester
              .widget<CodeEditor>(find.byType(CodeEditor))
              .controller!
              .addListener(() => notificationCount++);
          observeController();
          for (var i = 0; i < samples + warmup; i++) {
            if (operation.endsWith('paste_replace_4k')) {
              // Both variants remount for paste, avoiding unequal undo/reset
              // histories and retaining large reset payloads between samples.
              if (i > 0) {
                await harness.dispose();
                harness = MirrorHarness(tester);
                await harness.mount(
                  source,
                  caret,
                  document: MessageEditingController(nativeInputEnabled: true),
                );
                observeController();
              }
              harness.text.selection = TextSelection(
                baseOffset: caret,
                extentOffset: caret + 5,
              );
              await tester.pump();
            } else if (operation.startsWith('app_')) {
              harness.text.selection = TextSelection.collapsed(offset: caret);
              await tester.pump();
            }
            harness.commands.clear();
            tester.testTextInput.log.clear();
            notificationCount = 0;
            final previousChanges = harness.changes;
            final previousBytes = harness.incomingBytes;
            final before = harness.native;
            final oldDocument = harness.text.text;
            final oldSelection = harness.text.selection;
            final patches = <List<Object>>[];
            var next = before;
            if (operation == 'type') {
              patches.add([before.selection.start, before.selection.end, 'x']);
              next = before.replaced(before.selection, 'x');
            } else if (operation == 'delete') {
              final range = TextRange(
                start: before.selection.start - 1,
                end: before.selection.start,
              );
              patches.add([range.start, range.end, '']);
              next = before.replaced(range, '');
            } else if (operation == 'paste_replace_4k') {
              patches.add([before.selection.start, before.selection.end, '']);
              patches.add([
                before.selection.start,
                before.selection.start,
                paste,
              ]);
              next = before
                  .replaced(before.selection, paste)
                  .copyWith(
                    selection: TextSelection.collapsed(
                      offset: before.selection.start + paste.length,
                    ),
                  );
            } else if (operation == 'native_selection') {
              next = before.copyWith(
                selection: TextSelection(
                  baseOffset: caret,
                  extentOffset: caret + (i.isEven ? 5 : 12),
                ),
              );
            }
            final encodeWatch = Stopwatch()..start();
            final message = operation.startsWith('app_')
                ? null
                : harness.prepare(next, patches);
            final encodeUs = encodeWatch.elapsedMicroseconds;
            final watch = Stopwatch()..start();
            if (operation == 'app_paste_replace_4k') {
              harness.text.value = harness.text.value
                  .replaced(harness.text.selection, paste)
                  .copyWith(
                    selection: TextSelection.collapsed(
                      offset: caret + paste.length,
                    ),
                  );
            } else if (operation == 'app_select_all') {
              harness.text.selection = TextSelection(
                baseOffset: 0,
                extentOffset: source.length,
              );
            } else if (operation == 'app_range_selection') {
              harness.text.selection = TextSelection(
                baseOffset: caret,
                extentOffset: caret + 500,
              );
            } else {
              await harness.dispatch(message!);
            }
            final dispatchUs = watch.elapsedMicroseconds;
            await tester.pump();
            final totalUs = watch.elapsedMicroseconds;
            final sentText = tester.testTextInput.log
                .where((call) => call.method == 'TextInput.setEditingState')
                .fold<int>(
                  0,
                  (sum, call) =>
                      sum + ((call.arguments as Map)['text'] as String).length,
                );
            String expectedText = source;
            TextSelection expectedSelection;
            if (operation == 'type') {
              expectedText = oldDocument.replaceRange(
                oldSelection.start,
                oldSelection.end,
                'x',
              );
              expectedSelection = TextSelection.collapsed(
                offset: oldSelection.start + 1,
              );
            } else if (operation == 'delete') {
              expectedText = oldDocument.replaceRange(
                oldSelection.start - 1,
                oldSelection.start,
                '',
              );
              expectedSelection = TextSelection.collapsed(
                offset: oldSelection.start - 1,
              );
            } else if (operation.endsWith('paste_replace_4k')) {
              expectedText = source.replaceRange(caret, caret + 5, paste);
              expectedSelection = TextSelection.collapsed(
                offset: caret + paste.length,
              );
            } else if (operation == 'native_selection') {
              expectedSelection = TextSelection(
                baseOffset: caret,
                extentOffset: caret + (i.isEven ? 5 : 12),
              );
            } else if (operation == 'app_select_all') {
              expectedSelection = TextSelection(
                baseOffset: 0,
                extentOffset: source.length,
              );
            } else {
              expectedSelection = TextSelection(
                baseOffset: caret,
                extentOffset: caret + 500,
              );
            }
            correct &= harness.text.text == expectedText;
            selectionCorrect &= harness.text.selection == expectedSelection;
            if (i >= warmup) {
              durations.add(totalUs);
              dispatch.add(dispatchUs);
              bytes.add(harness.incomingBytes - previousBytes);
              notices.add(notificationCount);
              changes.add(harness.changes - previousChanges);
              encoding.add(encodeUs);
              outgoing.add(sentText);
            }
          }
          // Fail if any native/app edit or close barrier did not converge.
          await (harness.text as MessageEditingController).flushInput();
          // ignore: avoid_print
          print(
            'IME_BENCH ${jsonEncode({
              'label': 'kelivo_native',
              'shape': shape,
              'chars': size,
              'operation': operation,
              'samples': samples,
              'correct_text': correct,
              'correct_selection': selectionCorrect,
              'onChanged': harness.changes,
              'median_us': percentile(durations, .5),
              'p95_us': percentile(durations, .95),
              'dispatch_median_us': percentile(dispatch, .5),
              'simulated_native_encode_median_us': percentile(encoding, .5),
              'incoming_bytes_median': percentile(bytes, .5),
              'outgoing_text_units_median': percentile(outgoing, .5),
              'sample_total_us': durations,
              'sample_dispatch_us': dispatch,
              'sample_pump_us': [for (var n = 0; n < durations.length; n++) durations[n] - dispatch[n]],
              'sample_notifications': notices,
              'sample_onChanged': changes,
              'paste_reset': 'fresh_mount',
              'app_reply_encoding_in_timed_scope': true,
            })}',
          );
          await harness.dispose();
        }, variant: TargetPlatformVariant.only(TargetPlatform.android));
      }
    }
  }
}
