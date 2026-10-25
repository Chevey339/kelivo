import 'dart:developer' as developer;
import 'dart:io';
import 'dart:ui' as ui;

import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';

import 'package:Kelivo/core/database/app_database.dart';
import 'package:Kelivo/core/database/business_preferences.dart';
import 'package:Kelivo/core/database/business_repository.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/browser/browser_engine.dart';
import 'package:Kelivo/core/services/browser/browser_service.dart';
import 'package:Kelivo/core/services/browser/browser_store.dart';
import 'package:Kelivo/features/browser/models/browser_models.dart';
import 'package:Kelivo/features/browser/pages/browser_mobile_layout.dart';
import 'package:Kelivo/features/browser/pages/browser_page.dart';
import 'package:Kelivo/features/browser/widgets/browser_controls.dart';
import 'package:Kelivo/features/browser/widgets/native_browser_glass.dart';
import 'package:Kelivo/l10n/app_localizations.dart';

// Explicit mobile-only probe; excluded from the default *_test.dart glob.
// Keep the installed app after drive (its default cleanup uninstalls it):
// flutter drive -d <simulator> --keep-app-running --no-dds \
//   --driver=test_driver/integration_test.dart \
//   --target=integration_test/browser_motion_bench.dart
// The existing driver saves all report keys to build/integration_response_data.json.
// Debug simulator samples describe this run, not physical-device performance.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized()
    ..framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  testWidgets('bench browser material menu and scroll motion', (tester) async {
    final directory = await Directory.systemTemp.createTemp('browser-motion-');
    final database = AppDatabase(NativeDatabase.memory());
    final preferences = BusinessPreferences(BusinessRepository(database));
    await preferences.load();
    final settings = SettingsProvider(preferences);
    await settings.loaded;
    final service = BrowserService(store: BrowserStore(directory: directory));
    await service.initialize();
    final tab = await service.createTab(ownerSessionId: 'motion-bench');
    final viewport = find.byKey(const ValueKey('browserMobileViewportSlot'));
    final surface = find.byKey(const ValueKey('browserMenuSurface'));
    final more = find.byWidgetPredicate(
      (widget) => widget is BrowserActionButton && widget.label == 'More',
    );
    final scrollEvents = <BrowserScrollState>[];
    void captureScroll() {
      final position = service.scrollPosition.value;
      if (position?.tabId == tab.id) scrollEvents.add(position!.state);
    }

    service.scrollPosition.addListener(captureScroll);
    try {
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: settings,
          child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: BrowserPage(service: service, conversationId: 'motion-bench'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        viewport,
        findsOneWidget,
        reason: 'Use a mobile simulator viewport.',
      );
      await service.loadHtml(_fixture, tabId: tab.id);
      await service.waitForLoad(tabId: tab.id);
      await tester.pumpAndSettle();

      // fullyLive advances real animations. Polling does not pump synthetic
      // frames, and scroll completion always requires the actual DOM scrollend.
      Future<void> waitUntil(String label, bool Function() ready) async {
        final deadline = DateTime.now().add(const Duration(seconds: 10));
        while (!ready()) {
          if (DateTime.now().isAfter(deadline)) {
            fail(
              '$label timed out; hasContent=${service.activeTab?.hasContent}; '
              'scroll=${scrollEvents.map((e) => '${e.phase.name}:${e.offset}/${e.viewportExtent}/${e.contentExtent}').join(',')}',
            );
          }
          await Future<void>.delayed(const Duration(milliseconds: 25));
        }
      }

      Future<void> idle() => waitUntil(
        'Flutter animation completion',
        () => !binding.hasScheduledFrame && binding.transientCallbackCount == 0,
      );

      // A headless engine can report its old viewport before being attached.
      // The viewport meta makes CSS px equal to logical px for this fixture.
      await waitUntil('Visible native viewport', () {
        final position = service.scrollPosition.value;
        return position?.tabId == tab.id &&
            (position!.state.viewportExtent - tester.getSize(viewport).height)
                    .abs() <
                1;
      });
      expect(service.activeTab?.hasContent, isTrue);
      expect(service.scrollPosition.value!.state.supportsScrollEnd, isTrue);
      final media = MediaQuery.of(tester.element(viewport));
      expect(media.disableAnimations, isFalse);
      expect(media.highContrast, isFalse);
      binding.reportData = {
        'protocol': {
          'platform': Platform.operatingSystem,
          'osVersion': Platform.operatingSystemVersion,
          'buildMode': kDebugMode
              ? 'debug'
              : (kProfileMode ? 'profile' : 'release'),
          'framePolicy': binding.framePolicy.name,
          'devicePixelRatio': media.devicePixelRatio,
          'viewportHeight': tester.getSize(viewport).height,
          'nativeGlass': NativeBrowserGlass.isSupported,
          'shaderFilters': ui.ImageFilter.isShaderFilterSupported,
          'styles': BrowserSurfaceStyle.values.map((e) => e.name).toList(),
          'warmupRoundsPerStyle': 1,
          'measuredRoundsPerStyle': 3,
          'scrollTargetCssPx': 240,
          'frameDrainMilliseconds': 2000,
          'traceGranularity': 'phase',
          // Each trace clears the VM ring. Only frame metrics in the outer SDK
          // summary cover the whole round; its GC counts do not.
          'sdkGcCountsCoverWholeRound': false,
          'scope':
              'Actual runtime FrameTiming and VM timeline only; '
              'debug simulator results do not establish device performance. '
              'Apple solid retains the same native glass platform-view carrier. '
              'SDK summary budget counts use its fixed frame budget; inspect '
              'raw timings against the actual display cadence.',
        },
      };

      Future<void> scrollTo(int offset) async {
        scrollEvents.clear();
        await service.evaluateJavascript(
          'window.scrollTo({top: $offset, behavior: "smooth"})',
          tabId: tab.id,
        );
        await waitUntil('DOM scrollend at $offset', () {
          return scrollEvents.any(
            (event) =>
                event.phase == BrowserScrollPhase.end &&
                (event.offset - offset).abs() < 1,
          );
        });
        await waitUntil('Chrome target at $offset', () {
          return tester
                  .widget<BrowserChromeTransition>(
                    find.byType(BrowserChromeTransition),
                  )
                  .progress ==
              (offset == 0 ? 0 : 1);
        });
        await idle();
      }

      Future<void> round(String key, {bool trace = true}) async {
        Future<void> phase(String name, Future<void> Function() action) async {
          if (!trace) return action();
          // watchPerformance enables only GC internally. Re-enable these
          // streams per phase and export before subsequent phases can evict
          // the beginning from the VM ring. Retain engine submit/wait events
          // where emitted; never infer missing events.
          await binding.traceAction(
            () async {
              final task = developer.TimelineTask()
                ..start('browser_motion.$name');
              try {
                await action();
              } finally {
                task.finish();
              }
            },
            streams: const ['Dart', 'Embedder', 'GC'],
            reportKey: '$name.timeline',
          );
        }

        await phase('$key.menu_open', () async {
          await tester.tap(more);
          await waitUntil('Menu open', () => surface.evaluate().isNotEmpty);
          await idle();
        });
        await phase('$key.menu_close', () async {
          final outside =
              tester.getRect(viewport).topLeft + const Offset(12, 12);
          expect(tester.getRect(surface).contains(outside), isFalse);
          await tester.tapAt(outside);
          await waitUntil('Menu closed', () => surface.evaluate().isEmpty);
          await idle();
        });
        await phase('$key.collapse', () => scrollTo(240));
        await phase('$key.expand', () => scrollTo(0));
        expect(service.tabs, hasLength(1));
        expect(tester.takeException(), isNull);
      }

      for (final style in BrowserSurfaceStyle.values) {
        await service.updateSettings(
          service.settings.copyWith(surfaceStyle: style),
        );
        await tester.pumpAndSettle();
        await round('${style.name}.warmup', trace: false);
        for (var sample = 1; sample <= 3; sample++) {
          final key = '${style.name}.$sample';
          await binding.watchPerformance(() async {
            await round(key);
            // Drain batched FrameTimings outside the already-exported phase
            // traces, without requesting additional frames.
            await Future<void>.delayed(const Duration(seconds: 2));
          }, reportKey: '$key.summary');
        }
      }
    } finally {
      service.scrollPosition.removeListener(captureScroll);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await service.flush();
      service.dispose();
      settings.dispose();
      await database.close();
      await directory.delete(recursive: true);
    }
  }, timeout: const Timeout(Duration(minutes: 5)));
}

const _fixture = '''<!doctype html>
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>Browser motion benchmark</title>
<style>
html,body{margin:0;font:24px system-ui;color:#172942}
body{min-height:4200px;background:repeating-linear-gradient(135deg,
#ef8a78 0px,#f3d675 180px,#70b8ad 360px,#7b9bc9 540px,#ef8a78 720px)}
section{height:540px;padding:36px 24px;box-sizing:border-box}
h1{font-size:38px}p{max-width:24ch;line-height:1.5}
</style>
<section><h1>Browser motion</h1><p>One native webpage. Three materials.
The same menu and scroll sequence.</p></section>
<section><h1>Color and type</h1><p>Visible detail behind the floating controls.</p></section>
<section><h1>Scroll continuity</h1><p>Collapse, reverse, and return to the top.</p></section>
''';
