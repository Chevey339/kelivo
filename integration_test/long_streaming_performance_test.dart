import 'dart:io';
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
import 'package:Kelivo/features/home/controllers/stream_controller.dart'
    as stream;
import 'package:Kelivo/features/home/widgets/message_list_view.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';
import 'package:super_sliver_list/super_sliver_list.dart';

import '../test/support/business_test_harness.dart';
import 'markdown_viewport_animation_test.dart' as viewport_animation;

// flutter drive --profile -d DEVICE --driver=test_driver/integration_test.dart
//   --target=integration_test/long_streaming_performance_test.dart
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  if (const bool.fromEnvironment('STREAM_CHECK_COLLAPSE')) {
    viewport_animation.main();
  }
  const seconds = int.fromEnvironment('STREAM_SECONDS');
  const maxBlocks = int.fromEnvironment(
    'STREAM_MAX_BLOCKS',
    defaultValue: 2000,
  );
  const shape = String.fromEnvironment(
    'STREAM_SHAPE',
    defaultValue: 'paragraphs',
  );
  const defaultFrosted = bool.fromEnvironment('STREAM_FROSTED');
  const timeline = bool.fromEnvironment('STREAM_TIMELINE');
  const richAppend = bool.fromEnvironment('STREAM_RICH_APPEND');
  for (final frosted
      in const bool.fromEnvironment('STREAM_BOTH_STYLES')
          ? [false, true]
          : [defaultFrosted]) {
    testWidgets(
      'profiles growing replies and reasoning on device (frosted: $frosted)',
      (tester) async {
        debugFrostedForceLiveBackdropFilter = frosted;
        final results = <String, Object>{};
        final frames = <FrameTiming>[];
        // Device touches otherwise make WidgetTester walk the complete element
        // tree to print finder suggestions, contaminating frame measurements.
        final deviceDispatcher = binding.deviceEventDispatcher;
        binding.deviceEventDispatcher = null;
        void collect(List<FrameTiming> batch) => frames.addAll(batch);
        SchedulerBinding.instance.addTimingsCallback(collect);
        try {
          for (final reasoning in seconds > 0 ? [true] : [false, true]) {
            for (final count
                in seconds > 0 ? [maxBlocks] : [20, 200, maxBlocks]) {
              final source = ValueNotifier(
                List.generate(
                  count,
                  (i) =>
                      'Paragraph $i **加粗** reasoning 中文内容。'
                      ' Keep rendering Markdown while the response grows.',
                ).join(
                  shape == 'paragraphs'
                      ? '\n\n'
                      : shape == 'single'
                      ? ' '
                      : '\n',
                ),
              );
              if (shape == 'code') source.value = '```dart\n${source.value}';
              final scroll = ScrollController();
              final settings = SettingsProvider(
                createBusinessTestPreferences(),
              );
              await settings.loaded;
              if (frosted) {
                await settings.setChatMessageBackgroundStyle(
                  ChatMessageBackgroundStyle.frosted,
                );
              }
              final start = DateTime.now().subtract(
                const Duration(minutes: 12),
              );
              final message = ChatMessage(
                id: 'profile',
                role: 'assistant',
                content: '',
                conversationId: 'profile',
                isStreaming: true,
              );
              final controller = stream.StreamController(
                onStateChanged: () {},
                getSettingsProvider: () => settings,
                getCurrentConversationId: () => 'profile',
              );
              final state = stream.StreamingState(
                stream.GenerationContext(
                  assistantMessage: message,
                  apiMessages: const [],
                  userImagePaths: const [],
                  allowImagesApiRouting: false,
                  providerKey: 'profile',
                  modelId: 'profile',
                  assistant: null,
                  settings: settings,
                  config: ProviderConfig(
                    id: 'profile',
                    enabled: true,
                    name: 'Profile',
                    apiKey: '',
                    baseUrl: '',
                  ),
                  toolDefs: const [],
                  supportsReasoning: true,
                  enableReasoning: true,
                  streamOutput: true,
                ),
              );
              final listController = ListController();
              final processingFiles = ValueNotifier<String?>(null);
              if (timeline) {
                controller.markStreamingStarted(message.id);
                if (reasoning) {
                  await controller.handleReasoningChunk(source.value, state);
                } else {
                  controller.streamingContentNotifier.updateContent(
                    message.id,
                    source.value,
                    0,
                  );
                }
              }
              await tester.pumpWidget(
                MultiProvider(
                  providers: [
                    ChangeNotifierProvider.value(value: settings),
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
                      create: (_) => TtsProvider(
                        preferences: createBusinessTestPreferences(),
                      ),
                    ),
                    ChangeNotifierProvider(
                      create: (_) => ToolApprovalService(),
                    ),
                    ChangeNotifierProvider(
                      create: (_) => AskUserInteractionService(),
                    ),
                  ],
                  child: MaterialApp(
                    localizationsDelegates:
                        AppLocalizations.localizationsDelegates,
                    supportedLocales: AppLocalizations.supportedLocales,
                    home: Scaffold(
                      body: Stack(
                        fit: StackFit.expand,
                        children: [
                          if (frosted)
                            const DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Color(0xffe0d1ff),
                                    Color(0xffb1e7df),
                                    Color(0xffffd9c3),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                              ),
                            ),
                          if (timeline)
                            MessageListView(
                              scrollController: scroll,
                              listController: listController,
                              messages: [message],
                              byGroup: const {},
                              versionSelections: const {},
                              reasoning: controller.reasoning,
                              reasoningSegments: controller.reasoningSegments,
                              contentSplits: controller.contentSplits,
                              toolParts: controller.toolParts,
                              translations: const {},
                              selecting: false,
                              selectedItems: const {},
                              dividerPadding: EdgeInsets.zero,
                              processingFilesMessageId: processingFiles,
                              streamingContentNotifier:
                                  controller.streamingContentNotifier,
                            )
                          else
                            SingleChildScrollView(
                              controller: scroll,
                              child: ValueListenableBuilder<String>(
                                valueListenable: source,
                                builder: (_, value, _) => ChatMessageWidget(
                                  message: ChatMessage(
                                    id: 'profile',
                                    role: 'assistant',
                                    content: reasoning ? '' : value,
                                    conversationId: 'profile',
                                    isStreaming: true,
                                  ),
                                  reasoningText: reasoning ? value : null,
                                  reasoningLoading: reasoning,
                                  reasoningStartAt: reasoning ? start : null,
                                  showModelIcon: false,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
              await tester.pump(const Duration(seconds: 1));
              scroll.jumpTo(scroll.position.maxScrollExtent);
              await tester.pump(const Duration(seconds: 1));
              if (frosted) expect(find.byType(BackdropFilter), findsWidgets);
              frames.clear();
              final updates = <int>[];
              final elapsed = Stopwatch()..start();
              for (
                var i = 0;
                i < 100 || elapsed.elapsed.inSeconds < seconds;
                i++
              ) {
                final watch = Stopwatch()..start();
                final delta = shape == 'paragraphs' && i % 10 == 0
                    ? '\n\nNext **paragraph** '
                    : richAppend
                    ? ' **新增粗体** 和 *斜体*，继续推导。'
                    : seconds > 0
                    ? ' 持续思考并追加内容，保持 Markdown、文字选择及毛玻璃效果。'
                    : ' 新增输出。';
                source.value += delta;
                if (timeline) {
                  if (reasoning) {
                    await controller.handleReasoningChunk(delta, state);
                  } else {
                    controller.streamingContentNotifier.updateContent(
                      message.id,
                      source.value,
                      0,
                    );
                  }
                }
                if (i > 0 && i % 500 == 0) {
                  // ignore: avoid_print
                  print(
                    'LONG_STREAM_PROGRESS seconds=${elapsed.elapsed.inSeconds} chars=${source.value.length} rss=${ProcessInfo.currentRss}',
                  );
                }
                await tester.pump();
                watch.stop();
                updates.add(watch.elapsedMicroseconds);
                await tester.pump(const Duration(milliseconds: 60));
                scroll.jumpTo(scroll.position.maxScrollExtent);
                await tester.pump();
              }
              await tester.pump(const Duration(seconds: 1));
              final name = '${reasoning ? 'reasoning' : 'reply'}-$count';
              final summary = <String, Object>{
                'chars': source.value.length,
                'seconds': elapsed.elapsed.inSeconds,
                'shape': shape,
                'frosted': frosted,
                'timeline': timeline,
                'richAppend': richAppend,
                'frames': frames.length,
                'buildP50Us': _percentile(
                  frames.map((f) => f.buildDuration.inMicroseconds),
                  .5,
                ),
                'buildP95Us': _percentile(
                  frames.map((f) => f.buildDuration.inMicroseconds),
                  .95,
                ),
                'rasterP95Us': _percentile(
                  frames.map((f) => f.rasterDuration.inMicroseconds),
                  .95,
                ),
                'missed60Hz': frames
                    .where(
                      (f) =>
                          f.buildDuration.inMicroseconds > 16667 ||
                          f.rasterDuration.inMicroseconds > 16667,
                    )
                    .length,
                'updateP95Us': _percentile(updates, .95),
                'rssBytes': ProcessInfo.currentRss,
              };
              results[frosted ? 'frosted-$name' : name] = summary;
              // ignore: avoid_print
              print('LONG_STREAM_DEVICE $name $summary');
              expect(frames, isNotEmpty);
              expect(tester.takeException(), isNull);
              await tester.pumpWidget(const SizedBox.shrink());
              source.dispose();
              controller.dispose();
              listController.dispose();
              processingFiles.dispose();
              scroll.dispose();
              settings.dispose();
            }
          }
          binding.reportData = {...?binding.reportData, ...results};
        } finally {
          binding.deviceEventDispatcher = deviceDispatcher;
          debugFrostedForceLiveBackdropFilter = false;
          SchedulerBinding.instance.removeTimingsCallback(collect);
        }
      },
      timeout: const Timeout(Duration(minutes: 30)),
    );
  }
}

int _percentile(Iterable<int> input, double fraction) {
  final sorted = input.toList()..sort();
  return sorted.isEmpty ? 0 : sorted[((sorted.length - 1) * fraction).ceil()];
}
