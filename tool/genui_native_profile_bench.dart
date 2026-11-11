import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:Kelivo/core/database/generation_run.dart';
import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/features/intelligent_ui/host/ui_web_controller.dart';
import 'package:Kelivo/features/intelligent_ui/widgets/gallery/scenario_sources.dart';
import 'package:Kelivo/features/intelligent_ui/widgets/genui_slider.dart';
import 'package:Kelivo/features/intelligent_ui/widgets/genui_surface.dart';
import '../integration_test/support/message_profile_host.dart';
import '../integration_test/support/profile_measurement.dart';
import 'genui_profile_harness.dart';
import 'package:Kelivo/features/intelligent_ui/runtime/ui_surface_controller.dart';

/// Print-only profile measurements. Local state-to-raster latency is distinct
/// from the continuous pointer-drag frame sample and actual IME acceptance.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final services = await MessageTestServices.open();
  final probe = GenUiProfileMeasurement();
  final harness = GenUiProfileHarness();
  try {
    final viewsBefore = _createdViews();
    final cold = <String, Object?>{};
    final memory = <String, int>{'initial': ProcessInfo.currentRss};
    for (final scene in ['S1', 'S2', 'S6', 'limit']) {
      final source = scene == 'limit'
          ? _maximumChart()
          : scene == 'S2'
          ? genUiScenarioSources[scene]!.replaceFirst(
              '-2, 4, 13)',
              '-2, 4, 501)',
            )
          : genUiScenarioSources[scene]!;
      final message = ChatMessage(
        id: 'profile-$scene',
        conversationId: 'native-profile',
        role: 'assistant',
        content: '```kelivo-ui\n$source```',
      );
      message.hydrateGenerationState(GenerationRunState.completed);
      final watch = Stopwatch()..start();
      await harness.mount(
        MessageProfileHost(
          key: ValueKey(scene),
          messages: [message],
          services: services,
        ),
      );
      await harness.settle();
      cold[scene] = {
        'mountAndSettleUs': watch.elapsedMicroseconds,
        'sourceBytes': utf8.encode(source).length,
      };
      final controller = harness.widget<GenUiSurface>().controller;
      final input = switch (scene) {
        'S1' => 'speed',
        'S2' => 'offset',
        'limit' => 'gain',
        _ => 'slope',
      };
      for (var i = 0; i < 10; i++) {
        controller.setInputs({input: 1 + i / 10}, token: controller.token);
        await Future<void>.delayed(const Duration(milliseconds: 32));
      }
      await probe.measure('$scene-input', () async {
        for (var i = 0; i < 80; i++) {
          final began = DateTime.now().microsecondsSinceEpoch;
          final result = controller.setInputs({
            input: 1 + (i % 20) / 10,
          }, token: controller.token);
          if (result == UiMutationResult.accepted) probe.acceptedInput(began);
          await Future<void>.delayed(const Duration(milliseconds: 32));
        }
      }, latency: true);
      await Scrollable.ensureVisible(harness.element((w) => w is GenUiSlider));
      await harness.settle();
      final traces = <Map<String, Object?>>[];
      final changedValues = <Object?>{};
      final stop = controller.listenAcceptedState(
        () => changedValues.add(controller.captureRead().inputs[input]),
      );
      await probe.measure('$scene-drag', () async {
        final box = harness.rect((w) => w is GenUiSlider);
        for (var round = 0; round < 3; round++) {
          final start = Offset(box.left + 22, box.center.dy);
          final end = Offset(box.right - 22, box.center.dy);
          traces.add(
            await harness.drag(start, end, const Duration(seconds: 1)),
          );
          traces.add(
            await harness.drag(end, start, const Duration(seconds: 1)),
          );
        }
      });
      stop();
      probe.record('$scene-drag-input', {
        'distinctAcceptedValues': changedValues.length,
        'traces': traces,
        'input':
            'Flutter synthesized pointer events; no hardware latency claim',
      });
      if (scene == 'limit') {
        final canvas = harness.element(
          (w) => w.key == const ValueKey('genui-chart-canvas-chart'),
        );
        await Scrollable.ensureVisible(canvas);
        await harness.settle();
        final rect = harness.rect(
          (w) => w.key == const ValueKey('genui-chart-canvas-chart'),
        );
        await probe.measure('limit-hover', () => harness.hover(rect));
      }
      memory['$scene-steady'] = ProcessInfo.currentRss;
      probe.record('$scene-state', {
        'phase': controller.phase.name,
        'validNodes': controller.nodes.values.where((n) => n.valid).length,
        'chartRows': controller.nodes['chart']?.chartData?.rows.length,
        'nativeWebViewsCreated': _createdViews() - viewsBefore,
      });
      await harness.mount(const SizedBox());
      await Future<void>.delayed(const Duration(seconds: 2));
      memory['$scene-afterUnmount'] = ProcessInfo.currentRss;
    }
    final history = <ChatMessage>[];
    for (var i = 0; i < 60; i++) {
      final scene = ['S1', 'S2', 'S6'][(i ~/ 2) % 3];
      final message = ChatMessage(
        id: 'mixed-$i',
        conversationId: 'mixed-history',
        role: i.isEven ? 'user' : 'assistant',
        content: i.isEven
            ? 'Synthetic question $i'
            : '```kelivo-ui\n${genUiScenarioSources[scene]}```',
      );
      message.hydrateGenerationState(GenerationRunState.completed);
      history.add(message);
    }
    final historyKey = GlobalKey<MessageProfileHostState>();
    await harness.mount(
      MessageProfileHost(
        key: historyKey,
        messages: history,
        services: services,
      ),
    );
    await harness.settle();
    final scroll = historyKey.currentState!.scroll;
    for (var round = 0; round < 3; round++) {
      await probe.measure('native-history-scroll-$round', () async {
        await scroll.animateTo(
          math.min(scroll.position.maxScrollExtent, 12000),
          duration: const Duration(seconds: 4),
          curve: Curves.linear,
        );
        await scroll.animateTo(
          0,
          duration: const Duration(seconds: 4),
          curve: Curves.linear,
        );
      });
    }
    await probe.measure('native-history-idle', () async {
      await Future<void>.delayed(const Duration(seconds: 10));
    });
    await harness.mount(const SizedBox());
    await harness.settle();
    // Observe idle scheduling and memory after repeated complete mount/unmount.
    final source = genUiScenarioSources['S6']!;
    for (var round = 0; round < 8; round++) {
      final message = ChatMessage(
        id: 'cycle-$round',
        conversationId: 'cycles',
        role: 'assistant',
        content: '```kelivo-ui\n$source```',
      );
      message.hydrateGenerationState(GenerationRunState.completed);
      await harness.mount(
        MessageProfileHost(
          key: ValueKey(round),
          messages: [message],
          services: services,
        ),
      );
      await harness.settle();
      await harness.mount(const SizedBox());
      await harness.settle();
      memory['cycle-$round'] = ProcessInfo.currentRss;
    }
    probe.record('cold-mount', cold);
    probe.record('memory', memory);
    final report = probe.report('native-local-parameters')
      ..addAll({
        'profile': kProfileMode,
        'remainingTransientCallbacks':
            WidgetsBinding.instance.transientCallbackCount,
        'nativeWebViewsCreated': _createdViews() - viewsBefore,
        'memoryBoundary':
            'Process RSS includes engine, font and GPU caches; unmount samples do not imply all caches are released',
      });
    // ignore: avoid_print
    print('GENUI_PROFILE_END ${jsonEncode(report)}');
  } finally {
    await harness.mount(const SizedBox());
    await services.close();
  }
  exit(0);
}

String _maximumChart() {
  final rows = List.generate(500, (i) {
    final fields = List.generate(
      4,
      (s) => '"s$s":\$gain * ${((i * (s + 1)) % 101) - 50}',
    ).join(',');
    return '{"x":$i,$fields}';
  }).join(',');
  return 'ui 1 catalog "kelivo.native/1"\n'
      '\$gain: number = 1\n'
      'root = Column(children=[control,chart,unrelated])\n'
      'control = Slider(label="Gain",bind=\$gain,min=0,max=4,step=0.01)\n'
      'chart = Chart(kind="line",data=[$rows],x="x",y=["s0","s1","s2","s3"])\n'
      'unrelated = Metric(label="Unchanged",value=42)\n';
}

// This is a development-only benchmark, outside the production entrypoint.
// ignore: invalid_use_of_visible_for_testing_member
int _createdViews() => UiWebController.createdNativeViews;
