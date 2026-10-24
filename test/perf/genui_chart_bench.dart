import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:Kelivo/features/intelligent_ui/catalog/ui_catalog.dart';
import 'package:Kelivo/features/intelligent_ui/runtime/ui_surface_controller.dart';
import 'package:Kelivo/features/intelligent_ui/runtime/ui_surface_state.dart';
import 'package:Kelivo/features/intelligent_ui/widgets/genui_surface.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/theme/theme_factory.dart';

// Explicit, print-only diagnostic. These debug widget timings are not device
// build/raster timings or a substitute for C24's profile and scrolling runs.
void main() {
  for (final kind in ['line', 'area', 'bar', 'scatter']) {
    testWidgets('Chart 2000 slots $kind', (tester) async {
      tester.view.physicalSize = const Size(720, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final rows = List.generate(500, (i) {
        final values = List.generate(4, (s) {
          final value = kind == 'area' && i.isOdd
              ? 'null'
              : r'$gain * '
                    '${((i * (s + 1)) % 101) - 50}';
          return '"s$s":$value';
        }).join(',');
        return '{"x":$i,$values}';
      }).join(',');
      final c = UiSurfaceController(
        owner: const UiSurfaceOwner(
          revisionId: 'chart-bench',
          surfaceKey: '0:0',
        ),
      );
      addTearDown(c.dispose);
      c.updateSource(
        '${UiCatalog.header}\n'
        r'$gain: number = 1'
        '\n'
        'root = Column(children=[control,chart,unrelated])\n'
        r'control = Slider(label="Gain",bind=$gain,min=0,max=4,step=0.01)'
        '\n'
        'chart = Chart(kind="$kind",data=[$rows],x="x",y=["s0","s1","s2","s3"])\n'
        'unrelated = Metric(label="Unchanged",value=42)\n',
        closed: true,
        generation: UiGenerationStatus.complete,
      );
      var unrelatedUpdates = 0;
      final stop = c.listenNode('unrelated', () => unrelatedUpdates++);
      addTearDown(stop);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildLightTheme(null),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SingleChildScrollView(child: GenUiSurface(controller: c)),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final inputTimes = <int>[];
      for (var i = 0; i < 45; i++) {
        final watch = Stopwatch()..start();
        c.setInputs({'gain': 1.0 + i / 100}, token: c.token);
        await tester.pump();
        watch.stop();
        if (i >= 5) inputTimes.add(watch.elapsedMicroseconds);
      }
      final canvas = tester.getRect(
        find.byKey(const ValueKey('genui-chart-canvas-chart')),
      );
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: canvas.center);
      final hoverTimes = <int>[];
      for (var i = 0; i < 45; i++) {
        final watch = Stopwatch()..start();
        await mouse.moveTo(
          Offset(
            canvas.left + 45 + (canvas.width - 70) * i / 45,
            canvas.top + 30 + (i % 5) * 25,
          ),
        );
        await tester.pump();
        watch.stop();
        if (i >= 5) hoverTimes.add(watch.elapsedMicroseconds);
      }
      await mouse.removePointer();
      // ignore: avoid_print
      print(
        'GENUI_CHART kind=$kind slots=2000 phase=${c.phase.name} '
        'inputToPaint=${_stats(inputTimes)} hoverToPaint=${_stats(hoverTimes)} '
        'unrelatedNodeUpdates=$unrelatedUpdates',
      );
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}

String _stats(List<int> values) {
  values.sort();
  return 'medianUs:${values[values.length ~/ 2]},p95Us:${values[(values.length * .95).floor()]},maxUs:${values.last}';
}
