import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/core/providers/assistant_provider.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/features/chat/pages/message_edit_page.dart';
import 'package:Kelivo/features/chat/widgets/message_edit_sheet.dart';
import 'package:Kelivo/features/chat/widgets/frosted/chat_frosted_backdrop.dart';
import 'package:Kelivo/features/home/widgets/chat_input_bar.dart';
import 'package:Kelivo/features/home/widgets/chat_input_overlay_layout.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/widgets/markdown_with_highlight.dart';
import 'package:Kelivo/shared/widgets/long_message_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';
import 'package:re_editor/re_editor.dart';

import '../test/support/business_test_harness.dart';

// Explicit real-device benchmark. Run in profile mode. Timings are observations;
// the assertions verify that the measured widgets still edit and render content.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  final results = <String, Object?>{};
  const capture = bool.fromEnvironment('PERF_CAPTURE');
  const scene = String.fromEnvironment('PERF_SCENE', defaultValue: 'all');
  const nativeInput = bool.fromEnvironment('PERF_NATIVE_INPUT');
  const lineMutation = bool.fromEnvironment('PERF_LINE_MUTATION');
  const semantics = bool.fromEnvironment('PERF_SEMANTICS', defaultValue: true);
  const characters = int.fromEnvironment(
    'PERF_CHARACTERS',
    defaultValue: 64000,
  );
  final source = StringBuffer();
  while (source.length < characters) {
    source.writeln('中文 English mixed content **Markdown** 1234567890.');
  }
  final content = source.toString().substring(0, characters);

  testWidgets(
    'profiles editing, scrolling and real IME transitions',
    (tester) async {
      final settings = SettingsProvider(createBusinessTestPreferences());
      await settings.loaded;
      final assistant = AssistantProvider(
        preferences: createBusinessTestPreferences(),
      );
      final captureKey = GlobalKey();
      final hostKey = GlobalKey<NavigatorState>();
      Widget host(Widget home) => MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: settings),
          ChangeNotifierProvider.value(value: assistant),
        ],
        child: RepaintBoundary(
          key: captureKey,
          child: MaterialApp(
            navigatorKey: hostKey,
            locale: const Locale('en'),
            theme: ThemeData(brightness: Brightness.dark),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: home,
          ),
        ),
      );

      Future<void> snapshot(String name) async {
        if (!capture) return;
        final boundary =
            captureKey.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        final image = boundary.toImageSync(pixelRatio: 1);
        try {
          final bytes = (await image.toByteData(format: ImageByteFormat.png))!;
          results['$name.png'] = base64Encode(
            bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
          );
        } finally {
          image.dispose();
        }
      }

      Future<void> measure(String name, Future<void> Function() action) async {
        await tester.pump(const Duration(milliseconds: 600));
        final frames = <FrameTiming>[];
        void collect(List<FrameTiming> batch) => frames.addAll(batch);
        SchedulerBinding.instance.addTimingsCallback(collect);
        final watch = Stopwatch()..start();
        try {
          await action();
          watch.stop();
          await tester.pump(const Duration(milliseconds: 600));
        } finally {
          SchedulerBinding.instance.removeTimingsCallback(collect);
        }
        expect(frames, isNotEmpty, reason: name);
        final summary = _summarize(frames)
          ..['elapsedMs'] = watch.elapsedMilliseconds
          ..['rssBytes'] = ProcessInfo.currentRss;
        results[name] = summary;
        // ignore: avoid_print
        print('INTERACTIVE_DEVICE $name $summary');
      }

      Future<void> exerciseNativeInput(
        String name,
        TextEditingController controller,
      ) async {
        final code = tester.widget<CodeEditor>(find.byType(CodeEditor));
        await tester.tap(find.byType(CodeEditor));
        code.controller!.selection = const CodeLineSelection.collapsed(
          index: 0,
          offset: 0,
        );
        await tester.pump(const Duration(milliseconds: 500));
        final beforeCommit = controller.text;
        // Host adb input commits through the actual Android connection here.
        expect(code.controller!.text, controller.text);
        await measure('$name.nativeInput', () async {
          // ignore: avoid_print
          print(
            'NATIVE_IME_READY $name focus=${code.focusNode!.hasFocus} inset=${View.of(captureKey.currentContext!).viewInsets.bottom} length=${code.controller!.text.length}',
          );
          await tester.pump(const Duration(seconds: 6));
        });
        // ignore: avoid_print
        print(
          'NATIVE_IME_RESULT $name app=${controller.text.length} lines=${code.controller!.text.length} currentLine=${code.controller!.extentLine.text}',
        );
        // The phone's real IME may convert the host's Latin keystrokes to
        // Chinese. Verify the submitted edit and all untouched content.
        expect(controller.text, isNot(beforeCommit));
        expect(controller.text, endsWith(beforeCommit));
        expect(code.controller!.text, controller.text);
        results['$name.nativeCommitVerified'] = true;
        code.focusNode!.unfocus();
        await tester.pump(const Duration(seconds: 1));
      }

      Future<void> exerciseEditor(String name) async {
        final editor = find.byType(LongMessageEditor);
        final controller = tester.widget<LongMessageEditor>(editor).controller;
        expect(controller.text, content);
        final scrollables = find.descendant(
          of: editor,
          matching: find.byWidgetPredicate((widget) => widget is Scrollable),
        );
        final position = scrollables
            .evaluate()
            .map(
              (element) =>
                  (element as StatefulElement).state as ScrollableState,
            )
            .map((state) => state.position)
            .firstWhere(
              (position) =>
                  axisDirectionToAxis(position.axisDirection) == Axis.vertical,
            );
        results['$name.editorHeight'] = tester.getSize(editor).height;
        results['$name.scrollExtent'] = position.maxScrollExtent;
        await measure('$name.scroll', () async {
          for (var pass = 0; pass < 4; pass++) {
            await position.animateTo(
              pass.isEven ? position.maxScrollExtent.clamp(0, 12000) : 0,
              duration: const Duration(seconds: 2),
              curve: Curves.linear,
            );
          }
        });
        await snapshot(name);
        final mutations = <int>[];
        await measure('$name.type', () async {
          for (var index = 0; index < 40; index++) {
            final watch = Stopwatch()..start();
            final offset = controller.text.length ~/ 2;
            if (lineMutation && find.byType(CodeEditor).evaluate().isNotEmpty) {
              if (index == 0) {
                controller.selection = TextSelection.collapsed(offset: offset);
              }
              tester
                  .widget<CodeEditor>(find.byType(CodeEditor))
                  .controller!
                  .replaceSelection('测');
            } else {
              controller.value = TextEditingValue(
                text: controller.text.replaceRange(offset, offset, '测'),
                selection: TextSelection.collapsed(offset: offset + 1),
              );
            }
            watch.stop();
            mutations.add(watch.elapsedMicroseconds);
            await tester.pump(const Duration(milliseconds: 50));
          }
        });
        mutations.sort();
        final mutationResult = {
          'p95Us': mutations[(mutations.length * .95).ceil() - 1],
          'maxUs': mutations.last,
        };
        results['$name.mutation'] = mutationResult;
        // ignore: avoid_print
        print('INTERACTIVE_MUTATION $name $mutationResult');
        expect(controller.text.length, content.length + 40);
        expect(tester.takeException(), isNull);
        if (nativeInput) await exerciseNativeInput(name, controller);
      }

      final message = ChatMessage(
        id: 'interactive',
        role: 'user',
        conversationId: 'interactive',
        content: content,
      );
      if (scene == 'all' || scene == 'editor') {
        await tester.pumpWidget(host(MessageEditPage(message: message)));
        await tester.pump(const Duration(seconds: 2));
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pump(const Duration(seconds: 1));
        await exerciseEditor('page');

        await tester.pumpWidget(
          host(
            Builder(
              builder: (context) {
                return Scaffold(
                  body: TextButton(
                    onPressed: () =>
                        showMessageEditSheet(context, message: message),
                    child: const Text('Edit'),
                  ),
                );
              },
            ),
          ),
        );
        await tester.tap(find.text('Edit'));
        await tester.pump(const Duration(seconds: 2));
        await exerciseEditor('sheet');
        hostKey.currentState!.pop();
        await tester.pump(const Duration(seconds: 1));
      }

      if (scene == 'all' || scene == 'composer') {
        final draft = TextEditingController(text: content);
        final focus = FocusNode();
        await tester.pumpWidget(
          host(
            ChatFrostedBackdrop(
              backdrop: const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xff30243f), Color(0xff123d32)],
                  ),
                ),
              ),
              child: Scaffold(
                backgroundColor: Colors.transparent,
                body: ChatInputOverlayLayout(
                  topInset: 0,
                  content: RepaintBoundary(
                    child: SingleChildScrollView(
                      child: MarkdownWithCodeHighlight(
                        text: content,
                        streaming: true,
                      ),
                    ),
                  ),
                  bottomOverlay: ChatInputBar(
                    controller: draft,
                    focusNode: focus,
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump(const Duration(seconds: 2));
        expect(find.byType(BackdropFilter), findsWidgets);
        expect(find.byType(MarkdownWithCodeHighlight), findsOneWidget);
        final field = tester.widget<LongMessageEditor>(
          find.byType(LongMessageEditor),
        );
        await measure('composer.type', () async {
          for (var index = 0; index < 40; index++) {
            draft.value = TextEditingValue(
              text: '${draft.text}测',
              selection: TextSelection.collapsed(offset: draft.text.length + 1),
            );
            field.onChanged?.call(draft.text);
            await tester.pump(const Duration(milliseconds: 50));
          }
        });
        var maximumInset = 0.0;
        await measure('composer.keyboard', () async {
          for (var pass = 0; pass < 4; pass++) {
            focus.requestFocus();
            await SystemChannels.textInput.invokeMethod<void>('TextInput.show');
            await tester.pump(const Duration(seconds: 1));
            maximumInset =
                maximumInset <
                    View.of(captureKey.currentContext!).viewInsets.bottom
                ? View.of(captureKey.currentContext!).viewInsets.bottom
                : maximumInset;
            focus.unfocus();
            await tester.pump(const Duration(seconds: 1));
          }
        });
        results['composer.maximumImeInsetPx'] = maximumInset;
        expect(
          maximumInset,
          greaterThan(0),
          reason: 'Real Android IME must open',
        );
        await snapshot('composer');
        if (nativeInput) await exerciseNativeInput('composer', draft);
        await tester.pumpWidget(const SizedBox.shrink());
        draft.dispose();
        focus.dispose();
      }
      results['characters'] = characters;
      results['lineMutation'] = lineMutation;
      results['semanticsEnabled'] = semantics;
      results['refreshRateHz'] =
          PlatformDispatcher.instance.views.first.display.refreshRate;
      binding.reportData = results;
      await tester.pumpWidget(const SizedBox.shrink());
      settings.dispose();
      assistant.dispose();
    },
    semanticsEnabled: semantics,
    timeout: const Timeout(Duration(minutes: 10)),
  );
}

Map<String, Object> _summarize(List<FrameTiming> frames) {
  int percentile(Iterable<int> values, double fraction) {
    final sorted = values.toList()..sort();
    return sorted[((sorted.length - 1) * fraction).ceil()];
  }

  final builds = frames.map((frame) => frame.buildDuration.inMicroseconds);
  final rasters = frames.map((frame) => frame.rasterDuration.inMicroseconds);
  final starts =
      frames
          .map((frame) => frame.timestampInMicroseconds(FramePhase.vsyncStart))
          .toList()
        ..sort();
  final intervals = [
    for (var i = 1; i < starts.length; i++) starts[i] - starts[i - 1],
  ];
  return {
    'frames': frames.length,
    'vsyncIntervalP50Us': percentile(intervals, .5),
    'vsyncIntervalP95Us': percentile(intervals, .95),
    'buildP50Us': percentile(builds, .5),
    'buildP95Us': percentile(builds, .95),
    'buildP99Us': percentile(builds, .99),
    'buildMaxUs': builds.reduce((a, b) => a > b ? a : b),
    'rasterP95Us': percentile(rasters, .95),
    'rasterP99Us': percentile(rasters, .99),
    'rasterMaxUs': rasters.reduce((a, b) => a > b ? a : b),
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
