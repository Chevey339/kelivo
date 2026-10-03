import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/core/providers/assistant_provider.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/providers/tts_provider.dart';
import 'package:Kelivo/core/providers/user_provider.dart';
import 'package:Kelivo/features/chat/widgets/chat_message_widget.dart';
import 'package:Kelivo/features/chat/widgets/frosted/chat_frosted_backdrop.dart';
import 'package:Kelivo/features/home/services/ask_user_interaction_service.dart';
import 'package:Kelivo/features/home/services/tool_approval_service.dart';
import 'package:Kelivo/features/home/widgets/message_list_view.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/theme/theme_factory.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';
import 'package:super_sliver_list/super_sliver_list.dart';

import '../test/support/business_test_harness.dart';

// Explicit device benchmark. Frame timings are observations, not timing asserts.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  final results = <String, Object>{};
  // Additional fonts are opt-in: device font paths differ between vendors.
  const onlyFont = String.fromEnvironment('PERF_FONT', defaultValue: 'default');
  const fontFile = String.fromEnvironment(
    'PERF_FONT_FILE',
    defaultValue: '/system/fonts/NotoSerifCJK-Regular.ttc',
  );
  const frosted = bool.fromEnvironment('PERF_FROSTED', defaultValue: true);
  const uniqueGlyphs = bool.fromEnvironment('PERF_UNIQUE_GLYPHS');
  const capture = bool.fromEnvironment('PERF_CAPTURE');
  const backdropScope = bool.fromEnvironment('PERF_BACKDROP_SCOPE');
  const forceLive = bool.fromEnvironment('PERF_FORCE_LIVE', defaultValue: true);
  const semantics = bool.fromEnvironment('PERF_SEMANTICS', defaultValue: true);
  for (final font in onlyFont.split(',')) {
    testWidgets(
      'scrolls real chat messages with $font',
      (tester) async {
        final frames = <FrameTiming>[];
        void collect(List<FrameTiming> batch) => frames.addAll(batch);
        final settings = SettingsProvider(createBusinessTestPreferences());
        await settings.loaded;
        final assistants = AssistantProvider(
          preferences: createBusinessTestPreferences(),
        );
        await assistants.loaded;
        if (backdropScope && !forceLive) {
          final id = await assistants.addAssistant(
            name: 'Static backdrop profile',
          );
          await assistants.setCurrentAssistant(id);
          // The harness paints the gradient below. This identity marks it as
          // static artwork and exercises the production pre-blur capture path.
          await assistants.updateAssistant(
            assistants.currentAssistant!.copyWith(
              background: 'https://perf.invalid/static-backdrop',
            ),
          );
        }
        String? family;
        if (font == 'serif') family = 'serif';
        if (font.startsWith('local-')) {
          final path = switch (font) {
            'local-variable' => '/system/fonts/MiSansVF.ttf',
            'local-wenkai' => const String.fromEnvironment('PERF_WENKAI_URL'),
            'local-iming' => const String.fromEnvironment('PERF_IMING_URL'),
            _ => fontFile,
          };
          Uint8List bytes;
          if (path.startsWith('http://')) {
            final client = HttpClient();
            try {
              final response = await (await client.getUrl(
                Uri.parse(path),
              )).close();
              expect(response.statusCode, 200);
              final buffer = BytesBuilder(copy: false);
              await for (final chunk in response) {
                buffer.add(chunk);
              }
              bytes = buffer.takeBytes();
            } finally {
              client.close();
            }
          } else {
            bytes = await File(path).readAsBytes();
          }
          final source = File('${Directory.systemTemp.path}/$font.ttf');
          await source.writeAsBytes(bytes);
          try {
            expect(await settings.setAppFontFromLocal(path: source.path), true);
            family = settings.appFontFamily;
          } finally {
            await source.delete();
          }
        } else {
          await settings.setAppFontSystemFamily(family);
        }
        if (frosted) {
          await settings.setChatMessageBackgroundStyle(
            ChatMessageBackgroundStyle.frosted,
          );
        }
        final scroll = ScrollController();
        final list = ListController();
        final processing = ValueNotifier<String?>(null);
        const paragraph =
            '现在看规范性词汇这个场景里面发生的事情。你追问一个问题，'
            '讨论逐渐深入，模型需要理解上下文并提供清晰而完整的回答。'
            '长文本包括中文与 English mixed content，数字 1234567890，'
            '**粗体强调** 和 *斜体*；文字选择、复制、代码高亮和毛玻璃全部保留。';
        final messages = List.generate(
          80,
          (index) => ChatMessage(
            id: 'font-$index',
            role: index.isEven ? 'user' : 'assistant',
            conversationId: 'font-profile',
            timestamp: DateTime.utc(2026, 9, 20),
            content: List.generate(
              6,
              (part) =>
                  '$index.$part $paragraph${uniqueGlyphs ? String.fromCharCodes(List.generate(120, (i) => 0x4e00 + ((index * 6 + part) * 120 + i) % 20000)) : ''}',
            ).join('\n\n'),
          ),
        );
        final theme = ThemeData(
          brightness: Brightness.dark,
          fontFamily: family,
          fontFamilyFallback: getPlatformFontFallback(),
        );
        debugFrostedForceLiveBackdropFilter = frosted && forceLive;
        final captureKey = GlobalKey();
        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider.value(value: settings),
              ChangeNotifierProvider.value(value: assistants),
              ChangeNotifierProvider(
                create: (_) =>
                    UserProvider(preferences: createBusinessTestPreferences()),
              ),
              ChangeNotifierProvider(
                create: (_) =>
                    TtsProvider(preferences: createBusinessTestPreferences()),
              ),
              ChangeNotifierProvider(create: (_) => ToolApprovalService()),
              ChangeNotifierProvider(
                create: (_) => AskUserInteractionService(),
              ),
            ],
            child: MaterialApp(
              theme: theme,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: RepaintBoundary(
                  key: captureKey,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Color(0xff30243f),
                              Color(0xff123d32),
                              Color(0xff493425),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                      ),
                      _ProfileBackdrop(
                        enabled: backdropScope,
                        child: MessageListView(
                          scrollController: scroll,
                          listController: list,
                          messages: messages,
                          byGroup: const {},
                          versionSelections: const {},
                          reasoning: const {},
                          reasoningSegments: const {},
                          contentSplits: const {},
                          toolParts: const {},
                          translations: const {},
                          selecting: false,
                          selectedItems: const {},
                          dividerPadding: EdgeInsets.zero,
                          processingFilesMessageId: processing,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump(const Duration(seconds: 2));
        expect(find.byType(ChatMessageWidget), findsWidgets);
        if (frosted && forceLive) {
          expect(find.byType(BackdropFilter), findsWidgets);
        }
        if (frosted && backdropScope && !forceLive) {
          final controller = tester
              .widget<ChatFrostedBackdropScope>(
                find.byType(ChatFrostedBackdropScope),
              )
              .controller;
          expect(controller.mode, FrostedRenderMode.cached);
          expect(controller.debugCaptureCount, greaterThan(0));
        }
        // ignore: avoid_print
        print('FONT_SCROLL_READY $font');
        SchedulerBinding.instance.addTimingsCallback(collect);
        final rssBefore = ProcessInfo.currentRss;
        final watch = Stopwatch()..start();
        for (var pass = 0; pass < 4; pass++) {
          final destination = pass.isEven ? 12000.0 : 0.0;
          await scroll.animateTo(
            destination.clamp(0.0, scroll.position.maxScrollExtent),
            duration: const Duration(seconds: 3),
            curve: Curves.linear,
          );
        }
        await tester.pump(const Duration(seconds: 1));
        watch.stop();
        SchedulerBinding.instance.removeTimingsCallback(collect);
        int percentile(Iterable<int> data, double fraction) {
          final values = data.toList()..sort();
          return values[((values.length - 1) * fraction).ceil()];
        }

        expect(frames, isNotEmpty);
        final starts =
            frames
                .map(
                  (frame) =>
                      frame.timestampInMicroseconds(FramePhase.vsyncStart),
                )
                .toList()
              ..sort();
        final intervals = [
          for (var index = 1; index < starts.length; index++)
            starts[index] - starts[index - 1],
        ];
        final result = <String, Object>{
          'font': font,
          'frosted': frosted,
          'backdropScope': backdropScope,
          'forceLive': forceLive,
          'uniqueGlyphs': uniqueGlyphs,
          'refreshRateHz':
              PlatformDispatcher.instance.views.first.display.refreshRate,
          'frames': frames.length,
          'vsyncIntervalP50Us': percentile(intervals, .5),
          'vsyncIntervalP95Us': percentile(intervals, .95),
          'elapsedMs': watch.elapsedMilliseconds,
          'buildP50Us': percentile(
            frames.map((f) => f.buildDuration.inMicroseconds),
            .5,
          ),
          'buildP95Us': percentile(
            frames.map((f) => f.buildDuration.inMicroseconds),
            .95,
          ),
          'buildP99Us': percentile(
            frames.map((f) => f.buildDuration.inMicroseconds),
            .99,
          ),
          'rasterP95Us': percentile(
            frames.map((f) => f.rasterDuration.inMicroseconds),
            .95,
          ),
          'rasterP99Us': percentile(
            frames.map((f) => f.rasterDuration.inMicroseconds),
            .99,
          ),
          'overBudget60Hz': frames
              .where(
                (f) =>
                    f.buildDuration.inMicroseconds > 16667 ||
                    f.rasterDuration.inMicroseconds > 16667,
              )
              .length,
          'overBudget120Hz': frames
              .where(
                (f) =>
                    f.buildDuration.inMicroseconds > 8333 ||
                    f.rasterDuration.inMicroseconds > 8333,
              )
              .length,
          'semanticsEnabled': semantics,
          'rssBeforeBytes': rssBefore,
          'rssAfterBytes': ProcessInfo.currentRss,
        };
        results[font] = result;
        // ignore: avoid_print
        print('FONT_SCROLL_DEVICE $result');
        binding.reportData = results;
        expect(tester.takeException(), isNull);
        if (capture) {
          final boundary =
              captureKey.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary;
          final image = boundary.toImageSync();
          try {
            final png = (await image.toByteData(format: ImageByteFormat.png))!;
            result['screenshotPngBase64'] = base64Encode(
              png.buffer.asUint8List(png.offsetInBytes, png.lengthInBytes),
            );
          } finally {
            image.dispose();
          }
        }
        await tester.pumpWidget(const SizedBox.shrink());
        scroll.dispose();
        list.dispose();
        processing.dispose();
        await settings.clearAppFont();
        settings.dispose();
        assistants.dispose();
        debugFrostedForceLiveBackdropFilter = false;
      },
      semanticsEnabled: semantics,
      timeout: const Timeout(Duration(minutes: 5)),
    );
  }
}

class _ProfileBackdrop extends StatelessWidget {
  const _ProfileBackdrop({required this.enabled, required this.child});
  final bool enabled;
  final Widget child;

  @override
  Widget build(BuildContext context) => enabled
      ? ChatFrostedBackdrop(
          backdrop: const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xff30243f),
                  Color(0xff123d32),
                  Color(0xff493425),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          child: child,
        )
      : child;
}
