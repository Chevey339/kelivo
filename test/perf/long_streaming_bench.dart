import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/core/providers/tts_provider.dart';
import 'package:Kelivo/features/chat/widgets/chat_message_widget.dart';
import 'package:Kelivo/features/home/services/tool_approval_service.dart';
import 'package:Kelivo/features/home/services/ask_user_interaction_service.dart';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';
import 'dart:isolate';
// ignore: depend_on_referenced_packages
import 'package:vm_service/vm_service_io.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/widgets/markdown_with_highlight.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../support/business_test_harness.dart';

// Explicit benchmark; timings are observations, not regression assertions.
void main() {
  const maxBlocks = int.fromEnvironment('PERF_BLOCKS');
  for (final paragraphs in maxBlocks > 0 ? [maxBlocks] : [20, 200, 2000]) {
    for (final shape in ['paragraphs', 'lines', 'single', 'code']) {
      testWidgets('long stream $paragraphs $shape', (tester) async {
        final initial =
            List.generate(
              paragraphs,
              (i) =>
                  'Paragraph $i **加粗** reasoning 中文内容。'
                  ' Keep rendering Markdown while the response grows.',
            ).join(
              shape == 'paragraphs'
                  ? '\n\n'
                  : shape == 'single'
                  ? ' '
                  : '\n',
            );
        final source = ValueNotifier(
          shape == 'code' ? '```text\n$initial' : initial,
        );
        final scroll = ScrollController();
        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider(
                create: (_) =>
                    SettingsProvider(createBusinessTestPreferences()),
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
                body: SingleChildScrollView(
                  controller: scroll,
                  child: ValueListenableBuilder<String>(
                    valueListenable: source,
                    builder: (_, text, _) =>
                        const bool.fromEnvironment('PERF_REASONING')
                        ? ChatMessageWidget(
                            message: ChatMessage(
                              id: 'perf',
                              role: 'assistant',
                              content: '',
                              conversationId: 'perf',
                              isStreaming: true,
                            ),
                            reasoningText: text,
                            reasoningLoading: true,
                            reasoningStartAt: DateTime(2026),
                            showModelIcon: false,
                          )
                        : MarkdownWithCodeHighlight(
                            text: text,
                            streaming: true,
                          ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 100));
        scroll.jumpTo(scroll.position.maxScrollExtent);
        await tester.pump();
        final vm = const bool.fromEnvironment('CPU_PROFILE')
            ? await tester.runAsync(() async {
                final info = await developer.Service.getInfo();
                final uri = info.serverUri!;
                final vm = await vmServiceConnectUri(
                  uri.replace(scheme: 'ws', path: '${uri.path}ws').toString(),
                );
                await vm.setFlag('profiler', 'true');
                await vm.clearCpuSamples(
                  developer.Service.getIsolateId(Isolate.current)!,
                );
                return vm;
              })
            : null;
        final samples = <int>[];
        final stages = [0, 0, 0];
        for (var i = 0; i < 30; i++) {
          final sw = Stopwatch()..start();
          source.value += shape == 'paragraphs' && i % 5 == 0
              ? '\n\nNext **paragraph** '
              : const bool.fromEnvironment('PERF_RICH_APPEND')
              ? ' **新增粗体** 和 *斜体*，继续推导。'
              : '新增输出。';
          await tester.pump();
          final first = sw.elapsedMicroseconds;
          await tester.pump(const Duration(milliseconds: 60));
          final second = sw.elapsedMicroseconds;
          scroll.jumpTo(scroll.position.maxScrollExtent);
          await tester.pump();
          sw.stop();
          if (i >= 5) {
            samples.add(sw.elapsedMicroseconds);
            stages[0] += first;
            stages[1] += second - first;
            stages[2] += sw.elapsedMicroseconds - second;
          }
        }
        if (vm != null) {
          await tester.runAsync(() async {
            final cpu = await vm.getCpuSamples(
              developer.Service.getIsolateId(Isolate.current)!,
              0,
              1 << 60,
            );
            await File(
              '/tmp/kelivo-cpu-$paragraphs.json',
            ).writeAsString(jsonEncode(cpu.toJson()));
            await vm.dispose();
          });
        }
        samples.sort();
        // ignore: avoid_print
        print(
          'LONG_STREAM shape=$shape paragraphs=$paragraphs chars=${source.value.length} '
          'medianUs=${samples[samples.length ~/ 2]} '
          'p95Us=${samples[(samples.length * .95).floor()]} stages=${stages.map((s) => s ~/ 25).toList()}',
        );
        await tester.pumpWidget(const SizedBox.shrink());
        source.dispose();
        scroll.dispose();
      });
    }
  }
}
