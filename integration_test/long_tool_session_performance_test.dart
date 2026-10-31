import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/core/providers/assistant_provider.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/providers/tts_provider.dart';
import 'package:Kelivo/core/providers/user_provider.dart';
import 'package:Kelivo/core/services/api/stream/stream_chunk.dart';
import 'package:Kelivo/core/services/api/stream/stream_chunk_handler.dart';
import 'package:Kelivo/core/services/api/tool_call_cancellation.dart';
import 'package:Kelivo/core/services/workspace/tool_run_registry.dart';
import 'package:Kelivo/features/home/services/ask_user_interaction_service.dart';
import 'package:Kelivo/features/home/services/tool_approval_service.dart';
import 'package:Kelivo/features/home/widgets/message_list_view.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';
import 'package:super_sliver_list/super_sliver_list.dart';

import '../test/support/business_test_harness.dart';

// Synthetic tools only: no model requests, subprocesses or workspace edits.
// flutter drive --profile -d DEVICE --driver=test_driver/integration_test.dart
//   --target=integration_test/long_tool_session_performance_test.dart
//   --dart-define=TOOL_REPLAY_COUNT=5000 --dart-define=TOOL_REPLAY_SECONDS=7200
// Add --dart-define=TOOL_REPLAY_INTERLEAVED=true for tool/text alternation.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  const seconds = int.fromEnvironment('TOOL_REPLAY_SECONDS', defaultValue: 10);
  const countOverride = int.fromEnvironment('TOOL_REPLAY_COUNT');
  const interleaved = bool.fromEnvironment('TOOL_REPLAY_INTERLEAVED');
  final counts = countOverride > 0
      ? [countOverride]
      : seconds > 60
      ? [5000]
      : [10, 100, 1000, 5000];
  testWidgets('profiles a long synthetic tool session', (tester) async {
    final results = <String, Object>{};
    final dispatcher = binding.deviceEventDispatcher;
    binding.deviceEventDispatcher = null;
    try {
      for (final count in counts) {
        final handler = StreamChunkHandler();
        var nextId = 0;
        void completeTool() {
          final id = 'tool-${nextId++}';
          handler.handle(ToolCallStart(id: id, toolName: 'mcp_read_file'));
          handler.handle(
            ToolCallDelta(id: id, inputDelta: '{"path":"replay/$id.dart"}'),
          );
          handler.handle(ToolCallEnd(id));
          handler.handle(
            ToolCallResult(id: id, output: 'Synthetic result for $id'),
          );
          if (interleaved) {
            handler.handle(
              TextDelta(id: 'explanation-$id', text: 'Checked **$id**.\n\n'),
            );
            handler.handle(TextEnd('explanation-$id'));
          }
        }

        for (var i = 0; i < count; i++) {
          completeTool();
        }
        final source = ValueNotifier(
          ChatMessage(
            id: 'replay',
            role: 'assistant',
            conversationId: 'replay',
            parts: handler.parts,
            isStreaming: true,
          ),
        );
        final scroll = ScrollController();
        final list = ListController();
        final processing = ValueNotifier<String?>(null);
        final settings = SettingsProvider(createBusinessTestPreferences());
        await settings.loaded;
        await settings.setCollapseThinkingSteps(false);
        final registry = ToolRunRegistry();
        final cancelled = Completer<void>();
        final cancellation = ToolCallCancellation(
          isCancelled: () => cancelled.isCompleted,
          cancelled: cancelled.future,
        );
        final ui = _TimingHistogram(),
            raster = _TimingHistogram(),
            updates = _TimingHistogram();
        void timing(List<FrameTiming> frames) {
          for (final frame in frames) {
            ui.add(frame.buildDuration.inMicroseconds);
            raster.add(frame.rasterDuration.inMicroseconds);
          }
        }

        final rssBefore = ProcessInfo.currentRss;
        try {
          await tester.pumpWidget(
            MultiProvider(
              providers: [
                ChangeNotifierProvider<SettingsProvider>.value(value: settings),
                ChangeNotifierProvider(
                  create: (_) => AssistantProvider(
                    preferences: createBusinessTestPreferences(),
                  ),
                ),
                ChangeNotifierProvider(
                  create: (_) => UserProvider(
                    preferences: createBusinessTestPreferences(),
                  ),
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
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                home: Scaffold(
                  body: ValueListenableBuilder<ChatMessage>(
                    valueListenable: source,
                    builder: (context, message, _) => MessageListView(
                      scrollController: scroll,
                      listController: list,
                      messages: [message],
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
                ),
              ),
            ),
          );
          await tester.pump(const Duration(seconds: 1));
          scroll.jumpTo(scroll.position.maxScrollExtent);
          await tester.pump(const Duration(seconds: 1));
          SchedulerBinding.instance.addTimingsCallback(timing);
          final elapsed = Stopwatch()..start();
          var tick = 0;
          var tailId = 'tail-0';
          while (elapsed.elapsed.inSeconds < seconds || tick < 100) {
            final update = Stopwatch()..start();
            if (tick > 0 && tick % 20 == 0) {
              handler.handle(TextEnd(tailId));
              completeTool();
              tailId = 'tail-$tick';
              final unregister = cancellation.onCancel(() {});
              try {
                registry.start('run-$tick', 'shell')
                  ..appendStdout(utf8.encode('${'x' * 32768}\n'))
                  ..complete(status: ToolRunStatus.succeeded);
              } finally {
                unregister();
              }
            }
            handler.handle(TextDelta(id: tailId, text: ' Update $tick.'));
            source.value = source.value.copyWith(parts: handler.parts);
            await tester.pump();
            updates.add(update.elapsedMicroseconds);
            // Alternate following the tail and reading earlier tools.
            if (tick % 200 == 100) {
              scroll.jumpTo(scroll.position.maxScrollExtent * .4);
            }
            if (tick % 200 < 100) {
              scroll.jumpTo(scroll.position.maxScrollExtent);
            }
            await tester.pump(const Duration(milliseconds: 50));
            tick++;
          }
          await tester.pump(const Duration(seconds: 1));
          expect(cancellation.listenerCount, 0);
          expect(handler.pendingToolBufferCount, 0);
          expect(
            registry.retainedBytes,
            lessThanOrEqualTo(ToolRunRegistry.maxRetainedBytes),
          );
          expect(ui.count, greaterThan(0));
          expect(tester.takeException(), isNull);
          final report = <String, Object>{
            'initialTools': count,
            'finalTools': nextId,
            'interleaved': interleaved,
            'seconds': elapsed.elapsed.inSeconds,
            'updates': tick,
            'ui': ui.summary,
            'raster': raster.summary,
            'update': updates.summary,
            'rssBefore': rssBefore,
            'rssAfter': ProcessInfo.currentRss,
            'retainedRunBytes': registry.retainedBytes,
            'completedRuns': registry.all.length,
            'cancelListeners': cancellation.listenerCount,
            'pendingToolBuffers': handler.pendingToolBufferCount,
          };
          results['tools-$count'] = report;
          // ignore: avoid_print
          print('LONG_TOOL_SESSION ${jsonEncode(report)}');
        } finally {
          SchedulerBinding.instance.removeTimingsCallback(timing);
          cancelled.complete();
          await tester.pumpWidget(const SizedBox.shrink());
          source.dispose();
          scroll.dispose();
          list.dispose();
          processing.dispose();
          settings.dispose();
          registry.dispose();
        }
      }
      binding.reportData = {...?binding.reportData, ...results};
    } finally {
      binding.deviceEventDispatcher = dispatcher;
    }
  }, timeout: Timeout(Duration(seconds: counts.length * (seconds + 30) + 180)));
}

// Fixed-size histograms keep instrumentation memory bounded in multi-hour runs.
// Percentiles use 250us buckets; samples above 1s have their own overflow count.
class _TimingHistogram {
  final _buckets = List<int>.filled(4001, 0);
  int count = 0, over60Hz = 0, over120Hz = 0, over1Second = 0;
  void add(int micros) {
    count++;
    if (micros > 16667) over60Hz++;
    if (micros > 8333) over120Hz++;
    if (micros > 1000000) over1Second++;
    _buckets[((micros + 249) ~/ 250).clamp(0, 4000)]++;
  }

  int percentile(double fraction) {
    var seen = 0;
    final target = (count * fraction).ceil();
    for (var i = 0; i < _buckets.length; i++) {
      seen += _buckets[i];
      if (seen >= target) return i * 250;
    }
    return 0;
  }

  Map<String, int> get summary => {
    'samples': count,
    'p95Us': percentile(.95),
    'p99Us': percentile(.99),
    'over60Hz': over60Hz,
    'over120Hz': over120Hz,
    'over1Second': over1Second,
  };
}
