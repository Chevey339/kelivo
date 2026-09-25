import 'dart:io';
import 'dart:ui';

import 'package:Kelivo/core/database/chat_database_observer.dart';
import 'package:Kelivo/core/database/chat_database_repository.dart';
import 'package:Kelivo/core/models/chat_input_data.dart';
import 'package:Kelivo/core/models/conversation.dart';
import 'package:Kelivo/core/models/message_part.dart';
import 'package:Kelivo/core/providers/assistant_provider.dart';
import 'package:Kelivo/core/providers/mcp_provider.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/providers/tts_provider.dart';
import 'package:Kelivo/core/providers/user_provider.dart';
import 'package:Kelivo/core/services/chat/chat_service.dart';
import 'package:Kelivo/core/services/mcp/mcp_tool_service.dart';
import 'package:Kelivo/features/chat/widgets/frosted/chat_frosted_backdrop.dart';
import 'package:Kelivo/features/home/controllers/home_page_controller.dart';
import 'package:Kelivo/features/home/controllers/scroll_controller.dart';
import 'package:Kelivo/features/home/services/ask_user_interaction_service.dart';
import 'package:Kelivo/features/home/services/tool_approval_service.dart';
import 'package:Kelivo/features/home/widgets/chat_input_bar.dart';
import 'package:Kelivo/features/home/widgets/message_list_view.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:provider/provider.dart';
import 'package:super_sliver_list/super_sliver_list.dart';

import '../test/support/business_test_harness.dart';

// Start test/perf/support/stream_replay_server.py on the host and run
// adb reverse tcp:8790 tcp:8790 before this explicit profile-mode benchmark.
class _Paths extends PathProviderPlatform {
  _Paths(this.root);
  final String root;
  @override
  Future<String?> getApplicationDocumentsPath() async => root;
  @override
  Future<String?> getApplicationSupportPath() async => root;
  @override
  Future<String?> getApplicationCachePath() async => '$root/cache';
  @override
  Future<String?> getTemporaryPath() async => '$root/tmp';
}

int _cpuTicks() {
  final stat = File('/proc/self/stat').readAsStringSync();
  final fields = stat.substring(stat.lastIndexOf(')') + 2).split(' ');
  return int.parse(fields[11]) + int.parse(fields[12]);
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  const base = String.fromEnvironment(
    'REPLAY_URL',
    defaultValue: 'http://127.0.0.1:8790',
  );
  const onlyStreams = int.fromEnvironment('PERF_STREAMS');
  final results = <String, Object>{};
  for (final count in onlyStreams > 0 ? [onlyStreams] : [1, 2, 4]) {
    testWidgets(
      'profiles $count conversations through HTTP, dispatch, UI and SQLite',
      (tester) async {
        final root = await Directory.systemTemp.createTemp('kelivo-replay-');
        final previousPaths = PathProviderPlatform.instance;
        PathProviderPlatform.instance = _Paths(root.path);
        final observer = ChatDatabaseObserver();
        final repository = ChatDatabaseRepository.open(
          file: File('${root.path}/chat.db'),
          observer: observer,
        );
        await repository.ensureReady();
        final service = ChatService(existingRepository: repository);
        await service.init();
        final settings = SettingsProvider(createBusinessTestPreferences());
        await settings.loaded;
        await settings.setProviderConfig(
          'SiliconFlow',
          ProviderConfig(
            id: 'SiliconFlow',
            enabled: true,
            name: 'Replay',
            apiKey: 'local-replay',
            baseUrl: '$base/v1',
            providerType: ProviderKind.openai,
          ),
        );
        await settings.setCurrentModel('SiliconFlow', 'deepseek-reasoner');
        await settings.disableTitleGeneration();
        await settings.disableSuggestionGeneration();
        await settings.setChatMessageBackgroundStyle(
          ChatMessageBackgroundStyle.frosted,
        );
        final assistants = AssistantProvider(
          preferences: createBusinessTestPreferences(),
        );
        await assistants.loaded;
        await assistants.setCurrentAssistant(
          await assistants.addAssistant(name: 'Replay'),
        );
        late HomePageController controller;
        debugFrostedForceLiveBackdropFilter = true;
        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider<SettingsProvider>.value(value: settings),
              ChangeNotifierProvider<AssistantProvider>.value(
                value: assistants,
              ),
              ChangeNotifierProvider<ChatService>.value(value: service),
              ChangeNotifierProvider(
                create: (_) =>
                    UserProvider(preferences: createBusinessTestPreferences()),
              ),
              ChangeNotifierProvider(
                create: (_) =>
                    TtsProvider(preferences: createBusinessTestPreferences()),
              ),
              ChangeNotifierProvider(
                create: (_) =>
                    McpProvider(preferences: createBusinessTestPreferences()),
              ),
              ChangeNotifierProvider(create: (_) => McpToolService()),
              ChangeNotifierProvider(
                create: (_) => AskUserInteractionService(),
              ),
              ChangeNotifierProvider(create: (_) => ToolApprovalService()),
            ],
            child: MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: _Harness(onCreated: (c) => controller = c),
            ),
          ),
        );
        final client = HttpClient();
        await (await (await client.getUrl(
          Uri.parse('$base/reset?streams=$count'),
        )).close()).drain<void>();
        client.close();
        final conversations = <Conversation>[];
        final notifications = List.filled(count, 0);
        for (var i = 0; i < count; i++) {
          final conversation = await service.createConversation(
            title: 'Replay $i',
          );
          conversations.add(conversation);
          await controller.chatController.setCurrentConversationAndLoad(
            conversation,
          );
          final sent = await controller.sendMessage(
            ChatInputData(text: 'Replay $i'),
          );
          expect(sent, ChatInputSubmissionResult.sent);
          final assistant = controller.messages.lastWhere(
            (m) => m.role == 'assistant',
          );
          final index = i;
          controller.streamingContentNotifier
              .getNotifier(assistant.id)
              .addListener(() => notifications[index]++);
          await tester.pump();
        }
        final frames = <FrameTiming>[];
        void collect(List<FrameTiming> batch) => frames.addAll(batch);
        SchedulerBinding.instance.addTimingsCallback(collect);
        final watch = Stopwatch()..start();
        final cpuBefore = _cpuTicks();
        final rssBefore = ProcessInfo.currentRss;
        var peakRss = rssBefore;
        while (conversations.any(
          (c) => controller.chatController.isConversationLoading(c.id),
        )) {
          await Future<void>.delayed(const Duration(milliseconds: 20));
          if (ProcessInfo.currentRss > peakRss) {
            peakRss = ProcessInfo.currentRss;
          }
          expect(watch.elapsed, lessThan(const Duration(seconds: 90)));
        }
        final cpuAfter = _cpuTicks();
        await tester.pump(const Duration(seconds: 1));
        watch.stop();
        SchedulerBinding.instance.removeTimingsCallback(collect);
        expect(frames, isNotEmpty);
        expect(find.byType(BackdropFilter), findsWidgets);
        final expectedReasoning =
            List.filled(
              1800,
              '正在分析长文本，保留 Markdown **粗体**、中文和 English。\n\n',
            ).join() +
            List.filled(240, '继续分析上下文并核对事实。').join();
        final expectedText = List.filled(
          720,
          '正文持续输出，保留 **Markdown** 和文字选择。 ',
        ).join();
        for (final conversation in conversations) {
          final messages = await service.loadMessages(conversation.id);
          final assistant = messages.singleWhere((m) => m.role == 'assistant');
          expect(assistant.isStreaming, false);
          expect(assistant.content, expectedText);
          expect(
            assistant.parts.whereType<ReasoningPart>().single.text,
            expectedReasoning,
          );
        }
        int percentile(Iterable<int> input, double fraction) {
          final values = input.toList()..sort();
          return values[((values.length - 1) * fraction).ceil()];
        }

        final result = <String, Object>{
          'streams': count,
          'refreshRateHz':
              PlatformDispatcher.instance.views.first.display.refreshRate,
          'frames': frames.length,
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
          'cpuTicks': cpuAfter - cpuBefore,
          'cpuTicksPerSecond': 100,
          'rssBeforeBytes': rssBefore,
          'rssPeakBytes': peakRss,
          'notifications': notifications,
          'frameTimingsUs': [
            for (final frame in frames)
              {
                'start': frame.timestampInMicroseconds(FramePhase.buildStart),
                'build': frame.buildDuration.inMicroseconds,
                'raster': frame.rasterDuration.inMicroseconds,
              },
          ],
          'database': observer.snapshot().toSafeJson(),
        };
        results['streams-$count'] = result;
        binding.reportData = results;
        // ignore: avoid_print
        print(
          'CONCURRENT_STREAM_DEVICE ${Map.of(result)..remove('frameTimingsUs')}',
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        debugFrostedForceLiveBackdropFilter = false;
        await service.close();
        await repository.close();
        PathProviderPlatform.instance = previousPaths;
      },
      timeout: const Timeout(Duration(minutes: 4)),
    );
  }
}

class _Harness extends StatefulWidget {
  const _Harness({required this.onCreated});
  final ValueChanged<HomePageController> onCreated;
  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> with TickerProviderStateMixin {
  final _scaffold = GlobalKey<ScaffoldState>();
  final _inputBar = GlobalKey();
  final _focus = FocusNode();
  final _input = TextEditingController();
  final _media = ChatInputBarController();
  final _scroll = ChatAutoFollowScrollController();
  final _list = ListController();
  late final HomePageController _controller;
  @override
  void initState() {
    super.initState();
    _controller = HomePageController(
      context: context,
      vsync: this,
      scaffoldKey: _scaffold,
      inputBarKey: _inputBar,
      inputFocus: _focus,
      inputController: _input,
      mediaController: _media,
      scrollController: _scroll,
    );
    widget.onCreated(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    _input.dispose();
    _scroll.dispose();
    _list.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    key: _scaffold,
    body: Stack(
      fit: StackFit.expand,
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xffe0d1ff), Color(0xffb1e7df), Color(0xffffd9c3)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        AnimatedBuilder(
          animation: _controller,
          builder: (_, __) => MessageListView(
            scrollController: _scroll,
            listController: _list,
            messages: _controller.messages,
            byGroup: const {},
            versionSelections: _controller.versionSelections,
            reasoning: _controller.reasoning,
            reasoningSegments: _controller.reasoningSegments,
            contentSplits: _controller.contentSplits,
            toolParts: _controller.toolParts,
            translations: const {},
            selecting: false,
            selectedItems: const {},
            dividerPadding: EdgeInsets.zero,
            processingFilesMessageId: _controller.processingFilesMessageId,
            streamingContentNotifier: _controller.streamingContentNotifier,
          ),
        ),
      ],
    ),
  );
}
