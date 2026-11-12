import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';

import 'package:Kelivo/core/database/app_database.dart';
import 'package:Kelivo/core/database/business_preferences.dart';
import 'package:Kelivo/core/database/business_repository.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/browser/browser_service.dart';
import 'package:Kelivo/core/services/browser/browser_store.dart';
import 'package:Kelivo/features/browser/models/browser_models.dart';
import 'package:Kelivo/features/browser/browser_management_route.dart';
import 'package:Kelivo/features/browser/pages/browser_management_page.dart';
import 'package:Kelivo/features/browser/pages/browser_page.dart';
import 'package:Kelivo/features/browser/widgets/browser_glass.dart';
import 'package:Kelivo/features/browser/widgets/browser_settings.dart';
import 'package:Kelivo/l10n/app_localizations.dart';

// Explicit on-screen iOS composition probe. Capture the simulator DISPLAY while
// GLASS_COMPOSITOR_STAGE is logged; toImage cannot include native overlay slices.
// flutter drive -d <simulator> --keep-app-running \
//   --driver=test_driver/integration_test.dart \
//   --target=integration_test/browser_glass_compositor_probe.dart
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized()
    ..framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  testWidgets('inspect glass across actual Cupertino and WK overlay slices', (
    tester,
  ) async {
    final directory = await Directory.systemTemp.createTemp(
      'glass-compositor-',
    );
    final database = AppDatabase(NativeDatabase.memory());
    final preferences = BusinessPreferences(BusinessRepository(database));
    await preferences.load();
    final settings = SettingsProvider(preferences);
    await settings.loaded;
    final service = BrowserService(store: BrowserStore(directory: directory));
    await service.initialize();
    final tab = await service.createTab(ownerSessionId: 'compositor-probe');
    final stages = <Map<String, Object>>[];
    try {
      for (final native in [true]) {
        final navigatorKey = GlobalKey<NavigatorState>();
        await tester.pumpWidget(
          ChangeNotifierProvider.value(
            value: settings,
            child: MaterialApp(
              navigatorKey: navigatorKey,
              theme: ThemeData.light().copyWith(
                colorScheme: const ColorScheme.light(
                  primary: Color(0xff007aff),
                  surface: Color(0xfff2f2f7),
                  onSurface: Color(0xff161618),
                ),
              ),
              locale: const Locale('en'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: native
                  ? BrowserPage(
                      service: service,
                      conversationId: 'compositor-probe',
                    )
                  : const Scaffold(
                      backgroundColor: Color(0xffd5e9e5),
                      body: Center(
                        child: Text('Flutter backing — no WKWebView'),
                      ),
                    ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        if (native) {
          await service.loadHtml(_document, tabId: tab.id);
          await service.waitForLoad(tabId: tab.id);
          await tester.pumpAndSettle();
        }
        const variants = ['actual', 'stationary'];
        for (final variant in variants) {
          final name = '${native ? 'native' : 'flutter'}_$variant';
          final navigator = navigatorKey.currentState!;
          Widget pageBuilder(BuildContext _) => BrowserGlassBackdrop(
            native: false,
            child: BrowserGlassScope(
              style: BrowserSurfaceStyle.liquid,
              child: BrowserManagementPage(
                title: name,
                child: _settings(service),
              ),
            ),
          );
          final PageRoute<void> route = variant == 'stationary'
              ? _HeldStationaryRoute(builder: pageBuilder)
              : _HeldCupertinoRoute(builder: pageBuilder);
          final motion = route as _HeldRouteControl<void>;
          final closed = navigator.push<void>(route);
          await tester.pumpAndSettle();
          final width =
              tester.view.physicalSize.width / tester.view.devicePixelRatio;
          // Cupertino moves the outgoing WK route left by one third. At this
          // fraction its right edge crosses the management back-button centre.
          final crossing = .25 + 30 / width;
          navigator.didStartUserGesture();
          for (final value in [crossing]) {
            motion.hold(value);
            await tester.pump();
            final stage = {
              'name': name,
              'routeValue': value,
              'expectedNativeRight': variant == 'stationary'
                  ? width
                  : width * (1 - (1 - value) / 3),
              'expectedButtonCentre': width * (1 - value) + 40,
            };
            stages.add(stage);
            debugPrint('GLASS_COMPOSITOR_STAGE $stage — hold 30 seconds');
            await Future<void>.delayed(const Duration(seconds: 30));
          }
          motion.hold(1);
          navigator.didStopUserGesture();
          await tester.pump();
          navigator.pop();
          await tester.pumpAndSettle();
          await closed;
          await route.completed;
        }
      }
      expect(tester.takeException(), isNull);
      binding.reportData = {'compositorStages': stages};
    } finally {
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

Widget _settings(BrowserService service) => BrowserSettingsPanel(
  service: service,
  onError: (error) => debugPrint('GLASS_COMPOSITOR_ERROR $error'),
  onDataCleared: () {},
);

mixin _HeldRouteControl<T> on TransitionRoute<T> {
  void hold(double value) {
    controller!.stop();
    controller!.value = value;
  }
}

class _HeldCupertinoRoute extends CupertinoPageRoute<void>
    with _HeldRouteControl<void> {
  _HeldCupertinoRoute({required super.builder});
}

/// Keep the production Cupertino transition and interactive back gesture; only
/// opt out of moving the preceding native page with the secondary animation.
class _HeldStationaryRoute extends BrowserManagementRoute<void>
    with _HeldRouteControl<void> {
  _HeldStationaryRoute({required super.builder});
}

const _document = '''<!doctype html>
<meta name="viewport" content="width=device-width,initial-scale=1">
<body style="margin:0;min-height:2400px;background:repeating-linear-gradient(135deg,#d5e9e5 0px,#d5e9e5 20px,#739c98 20px,#739c98 22px);font:24px sans-serif">
<h1 style="padding:90px 24px">Native WKWebView</h1>
<p style="padding:0 24px">The page remains native under the paused Cupertino route.</p>
</body>''';
