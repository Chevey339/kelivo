import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/theme/theme_factory.dart';
import 'package:Kelivo/features/intelligent_ui/runtime/ui_surface_controller.dart';
import 'package:Kelivo/features/intelligent_ui/runtime/ui_surface_state.dart';
import 'package:Kelivo/features/intelligent_ui/widgets/genui_surface.dart';
import 'package:Kelivo/features/intelligent_ui/widgets/gallery/scenario_sources.dart';
import '../integration_test/support/profile_measurement.dart';
import 'genui_profile_harness.dart';

/// Explicit print-only native experiment. The legacy viewport exists only here
/// to isolate the layout/paint cost of removing the cap from identical widgets.
/// This does not replace production-timeline or hardware-input measurements.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final probe = GenUiProfileMeasurement();
  final harness = GenUiProfileHarness();
  final surfaces = <UiSurfaceController>[];
  final source =
      genUiScenarioSources['S6']!
          .replaceFirst('0, 5, 6)', '0, 5, 501)')
          .replaceFirst(
            'table,ask,reset]',
            'table,ask,reset,${List.generate(16, (i) => 'm$i').join(',')}]',
          ) +
      List.generate(
        16,
        (i) => 'm$i = Metric(label="Result $i",value=$i)\n',
      ).join();
  for (var i = 0; i < 12; i++) {
    surfaces.add(
      UiSurfaceController(
        owner: UiSurfaceOwner(revisionId: 'inline-bench-$i', surfaceKey: '0:0'),
      )..updateSource(
        source,
        closed: true,
        generation: UiGenerationStatus.complete,
      ),
    );
  }
  try {
    for (var round = 0; round < 3; round++) {
      for (final capped in round.isEven ? [true, false] : [false, true]) {
        final scroll = ScrollController();
        await harness.mount(
          MaterialApp(
            theme: buildLightTheme(null),
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 720,
                  child: ListView(
                    controller: scroll,
                    children: [
                      for (final surface in surfaces)
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: capped
                              ? SizedBox(
                                  height: 900,
                                  child: SingleChildScrollView(
                                    primary: false,
                                    physics:
                                        const NeverScrollableScrollPhysics(),
                                    child: GenUiSurface(controller: surface),
                                  ),
                                )
                              : GenUiSurface(controller: surface),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
        Future<void> traverse() async {
          final destination = math.min(scroll.position.maxScrollExtent, 5000.0);
          await scroll.animateTo(
            destination,
            duration: const Duration(seconds: 3),
            curve: Curves.linear,
          );
          await scroll.animateTo(
            0,
            duration: const Duration(seconds: 3),
            curve: Curves.linear,
          );
        }

        await traverse();
        await probe.measure('${capped ? 'capped' : 'full'}-$round', traverse);
        await harness.mount(const SizedBox());
        scroll.dispose();
      }
    }
    final report = probe.report(
      '12 full native surfaces, 501-point charts and 16 extra metrics each',
    )..['profile'] = kProfileMode;
    // ignore: avoid_print
    print('GENUI_INLINE_PROFILE_END ${jsonEncode(report)}');
  } finally {
    await harness.mount(const SizedBox());
    for (final surface in surfaces) {
      surface.dispose();
    }
  }
  exit(0);
}
