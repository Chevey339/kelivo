import 'dart:convert';

import 'package:Kelivo/shared/widgets/long_message_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:re_editor/re_editor.dart';

// Run explicitly. These timings are desktop widget-harness observations, not
// Android frame times. Correctness is checked separately by widget tests.
void main() {
  const label = String.fromEnvironment(
    'IME_BENCH_LABEL',
    defaultValue: 'local',
  );
  const requestedSize = int.fromEnvironment('IME_BENCH_SIZE');
  const requestedShape = String.fromEnvironment('IME_BENCH_SHAPE');
  const samples = int.fromEnvironment('IME_BENCH_SAMPLES', defaultValue: 30);
  const warmup = int.fromEnvironment('IME_BENCH_WARMUP', defaultValue: 8);
  const codec = JSONMethodCodec();

  TextEditingValue? sentState(WidgetTester tester) {
    for (final call in tester.testTextInput.log.reversed) {
      if (call.method == 'TextInput.setEditingState') {
        return TextEditingValue.fromJSON(
          Map<String, dynamic>.from(call.arguments as Map),
        );
      }
    }
    return null;
  }

  int percentile(List<int> values, double fraction) {
    final sorted = [...values]..sort();
    return sorted[((sorted.length - 1) * fraction).round()];
  }

  for (final shape in ['multiline', 'single']) {
    if (requestedShape.isNotEmpty && requestedShape != shape) continue;
    for (final size
        in requestedSize > 0
            ? [requestedSize]
            : shape == 'multiline'
            ? [10000, 100000, 1000000]
            : [100000]) {
      final line = '${'中文 mixed text 0123456789 ' * 9}\n';
      final seed = (line * (size ~/ line.length + 1)).substring(0, size);
      final source = shape == 'single' ? seed.replaceAll('\n', ' ') : seed;
      // Stay away from the local-window boundary during repeated typing and
      // backspace so both implementations perform the same document edits.
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
        testWidgets('$label $shape $size $operation', (tester) async {
          tester.view.physicalSize = const Size(390, 800);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          var text = TextEditingController.fromValue(
            TextEditingValue(
              text: source,
              selection: TextSelection.collapsed(offset: caret),
            ),
          );
          var changes = 0;
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: LongMessageEditor(
                  controller: text,
                  autofocus: true,
                  decoration: const InputDecoration(),
                  onChanged: (_) => changes++,
                ),
              ),
            ),
          );
          await tester.pump();
          var client =
              (tester.testTextInput.log
                          .lastWhere((c) => c.method == 'TextInput.setClient')
                          .arguments
                      as List)
                  .first;
          var native = sentState(tester)!;
          final nativeCaret = native.selection.start;
          final durations = <int>[];
          final dispatch = <int>[];
          final payloadBytes = <int>[];
          final platformEncode = <int>[];
          final outgoingTextUnits = <int>[];
          final notices = <int>[], changedSamples = <int>[];
          var notificationCount = 0;
          void observeController() => tester
              .widget<CodeEditor>(find.byType(CodeEditor))
              .controller!
              .addListener(() => notificationCount++);
          observeController();
          var correct = true;
          var correctSelection = true;
          for (var i = 0; i < samples + warmup; i++) {
            if (operation.endsWith('paste_replace_4k')) {
              if (i > 0) {
                await tester.pumpWidget(const SizedBox.shrink());
                text.dispose();
                text = TextEditingController.fromValue(
                  TextEditingValue(
                    text: source,
                    selection: TextSelection.collapsed(offset: caret),
                  ),
                );
                await tester.pumpWidget(
                  MaterialApp(
                    home: Scaffold(
                      body: LongMessageEditor(
                        controller: text,
                        autofocus: true,
                        decoration: const InputDecoration(),
                        onChanged: (_) => changes++,
                      ),
                    ),
                  ),
                );
                await tester.pump();
                client =
                    (tester.testTextInput.log
                                .lastWhere(
                                  (c) => c.method == 'TextInput.setClient',
                                )
                                .arguments
                            as List)
                        .first;
                observeController();
              }
              text.selection = TextSelection(
                baseOffset: caret,
                extentOffset: caret + 5,
              );
              await tester.pump();
              native = sentState(tester)!;
            } else if (operation == 'app_select_all' ||
                operation == 'app_range_selection') {
              text.selection = TextSelection.collapsed(offset: caret);
              await tester.pump();
              native = sentState(tester) ?? native;
            }
            tester.testTextInput.log.clear();
            notificationCount = 0;
            final previousChanges = changes;
            final oldDocument = text.text;
            final oldSelection = text.selection;
            final before = native;
            final deltas = <Map<String, dynamic>>[];
            var next = before;
            void delta(
              TextEditingValue previous,
              TextEditingValue after, {
              TextRange? range,
              String insertion = '',
            }) {
              deltas.add({
                'oldText': previous.text,
                'deltaText': insertion,
                'deltaStart': range?.start ?? -1,
                'deltaEnd': range?.end ?? -1,
                ...after.toJSON()..remove('text'),
              });
              next = after;
            }

            if (operation == 'type') {
              delta(
                before,
                before.replaced(before.selection, 'x'),
                range: before.selection,
                insertion: 'x',
              );
            } else if (operation == 'delete') {
              final range = TextRange(
                start: before.selection.start - 1,
                end: before.selection.start,
              );
              delta(before, before.replaced(range, ''), range: range);
            } else if (operation == 'paste_replace_4k') {
              final deleted = before.replaced(before.selection, '');
              delta(before, deleted, range: before.selection);
              delta(
                deleted,
                deleted.replaced(deleted.selection, paste),
                range: deleted.selection,
                insertion: paste,
              );
            } else if (operation == 'native_selection') {
              delta(
                before,
                before.copyWith(
                  selection: TextSelection(
                    baseOffset: nativeCaret,
                    extentOffset: nativeCaret + (i.isEven ? 5 : 12),
                  ),
                ),
              );
            }
            final encoding = Stopwatch()..start();
            final message = codec.encodeMethodCall(
              MethodCall('TextInputClient.updateEditingStateWithDeltas', [
                client,
                {'deltas': deltas},
              ]),
            );
            final encodeUs = encoding.elapsedMicroseconds;
            final watch = Stopwatch()..start();
            if (operation == 'app_paste_replace_4k') {
              text.value = text.value
                  .replaced(text.selection, paste)
                  .copyWith(
                    selection: TextSelection.collapsed(
                      offset: caret + paste.length,
                    ),
                  );
            } else if (operation == 'app_select_all') {
              text.selection = TextSelection(
                baseOffset: 0,
                extentOffset: source.length,
              );
            } else if (operation == 'app_range_selection') {
              text.selection = TextSelection(
                baseOffset: caret,
                extentOffset: caret + 500,
              );
            } else {
              await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
                'flutter/textinput',
                message,
                (_) {},
              );
            }
            final dispatchUs = watch.elapsedMicroseconds;
            await tester.pump();
            final totalUs = watch.elapsedMicroseconds;
            final sentTextUnits = tester.testTextInput.log
                .where((call) => call.method == 'TextInput.setEditingState')
                .fold<int>(
                  0,
                  (total, call) =>
                      total +
                      ((call.arguments as Map)['text'] as String).length,
                );
            native = sentState(tester) ?? next;
            if (operation == 'type') {
              correct &=
                  text.text ==
                  oldDocument.replaceRange(
                    oldSelection.start,
                    oldSelection.end,
                    'x',
                  );
            } else if (operation == 'delete') {
              correct &=
                  text.text ==
                  oldDocument.replaceRange(
                    oldSelection.start - 1,
                    oldSelection.start,
                    '',
                  );
            } else if (operation.endsWith('paste_replace_4k')) {
              correct &=
                  text.text == source.replaceRange(caret, caret + 5, paste);
            } else {
              correct &= text.text == source;
            }
            final TextSelection expectedSelection;
            if (operation == 'type') {
              expectedSelection = TextSelection.collapsed(
                offset: oldSelection.start + 1,
              );
            } else if (operation == 'delete') {
              expectedSelection = TextSelection.collapsed(
                offset: oldSelection.start - 1,
              );
            } else if (operation.endsWith('paste_replace_4k')) {
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
            correctSelection &= text.selection == expectedSelection;
            if (i >= warmup) {
              durations.add(totalUs);
              notices.add(notificationCount);
              changedSamples.add(changes - previousChanges);
              dispatch.add(dispatchUs);
              payloadBytes.add(deltas.isEmpty ? 0 : message.lengthInBytes);
              platformEncode.add(encodeUs);
              outgoingTextUnits.add(sentTextUnits);
            }
          }
          // ignore: avoid_print
          final result = {
            'sample_total_us': durations,
            'sample_dispatch_us': dispatch,
            'sample_pump_us': [
              for (var n = 0; n < durations.length; n++)
                durations[n] - dispatch[n],
            ],
            'sample_notifications': notices,
            'sample_onChanged': changedSamples,
            'paste_reset': 'fresh_mount',
            'label': label,
            'shape': shape,
            'chars': size,
            'operation': operation,
            'samples': samples,
            'correct_text': correct,
            'correct_selection': correctSelection,
            'onChanged': changes,
            'median_us': percentile(durations, .5),
            'p95_us': percentile(durations, .95),
            'dispatch_median_us': percentile(dispatch, .5),
            'simulated_native_encode_median_us': percentile(platformEncode, .5),
            'incoming_bytes_median': percentile(payloadBytes, .5),
            'outgoing_text_units_median': percentile(outgoingTextUnits, .5),
          };
          // ignore: avoid_print
          print('IME_BENCH ${jsonEncode(result)}');
          await tester.pumpWidget(const SizedBox.shrink());
          text.dispose();
        }, variant: TargetPlatformVariant.only(TargetPlatform.android));
      }
    }
  }
}
