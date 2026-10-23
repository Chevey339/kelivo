import 'dart:io';
import 'dart:ui' as ui;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:provider/provider.dart';

import 'package:Kelivo/core/database/app_database.dart';
import 'package:Kelivo/core/database/business_preferences.dart';
import 'package:Kelivo/core/database/business_repository.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/browser/browser_engine.dart';
import 'package:Kelivo/core/services/browser/browser_service.dart';
import 'package:Kelivo/core/services/browser/browser_store.dart';
import 'package:Kelivo/features/browser/pages/browser_page.dart';
import 'package:Kelivo/features/browser/pages/browser_management_page.dart';
import 'package:Kelivo/features/browser/models/browser_models.dart';
import 'package:Kelivo/features/browser/widgets/browser_surface_controls.dart';
import 'package:Kelivo/features/browser/pages/browser_mobile_layout.dart';
import 'package:Kelivo/features/browser/widgets/browser_controls.dart';
import 'package:Kelivo/features/browser/widgets/native_browser_glass.dart';
import 'package:Kelivo/l10n/app_localizations.dart';

// Runs the real platform renderer with isolated settings and browser storage.
// flutter drive -d <simulator> --keep-app-running \
//   --driver=test_driver/integration_test.dart \
//   --target=integration_test/browser_interaction_test.dart
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('native browser keeps a held finger through menu selection', (
    tester,
  ) async {
    final directory = await Directory.systemTemp.createTemp('browser-touch-');
    final database = AppDatabase(NativeDatabase.memory());
    final preferences = BusinessPreferences(BusinessRepository(database));
    await preferences.load();
    final settings = SettingsProvider(preferences);
    await settings.loaded;
    final service = BrowserService(store: BrowserStore(directory: directory));
    await service.initialize();
    final tab = await service.createTab(ownerSessionId: 'touch-test');
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: settings,
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: BrowserPage(service: service, conversationId: 'touch-test'),
        ),
      ),
    );
    try {
      await tester.pumpAndSettle();
      await service.loadHtml('''<!doctype html>
<meta name="viewport" content="width=device-width,initial-scale=1">
<body style="margin:0;background:linear-gradient(135deg,#ef8a78,#f3d675,#70b8ad,#7b9bc9);min-height:2400px;font:24px sans-serif">
<h1 style="padding:48px 24px">Shared browser interactions</h1>
<p style="padding:24px">Hold, move, release. The webpage remains the same native view.</p>
</body>''', tabId: tab.id);
      await service.waitForLoad(tabId: tab.id);
      await tester.pumpAndSettle();
      if (Platform.isIOS || Platform.isMacOS) {
        expect(NativeBrowserGlass.isSupported, isTrue);
        expect(find.byType(NativeBrowserGlass), findsWidgets);
      } else if (ui.ImageFilter.isShaderFilterSupported) {
        expect(find.byType(AdaptiveGlass), findsWidgets);
      }

      final scrollEvents = <BrowserScrollState>[];
      Future<void> waitUntil(bool Function() condition) async {
        for (var attempt = 0; attempt < 60 && !condition(); attempt++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        if (!condition()) {
          final geometry = await service.evaluateJavascript(
            'JSON.stringify({y:scrollY,h:innerHeight,content:document.documentElement.scrollHeight,ready:document.readyState,observer:!!window.__kelivoBrowserScroll})',
            tabId: tab.id,
          );
          fail(
            'Native browser event timed out: $geometry; hasContent=${service.activeTab?.hasContent}; events=${scrollEvents.map((e) => '${e.phase.name}:${e.offset}/${e.viewportExtent}/${e.contentExtent}').join(',')}',
          );
        }
      }

      await waitUntil(
        () =>
            service.scrollPosition.value?.state.viewportExtent != null &&
            (service.scrollPosition.value!.state.viewportExtent -
                        tester
                            .getSize(
                              find.byKey(
                                const ValueKey('browserMobileViewportSlot'),
                              ),
                            )
                            .height)
                    .abs() <
                1,
      );
      expect(service.scrollPosition.value!.state.supportsScrollEnd, isTrue);
      void captureScroll() {
        final position = service.scrollPosition.value;
        if (position?.tabId == tab.id) scrollEvents.add(position!.state);
      }

      service.scrollPosition.addListener(captureScroll);
      try {
        await service.evaluateJavascript(
          'window.scrollTo({top: 240, behavior: "smooth"})',
          tabId: tab.id,
        );
        await waitUntil(
          () => scrollEvents.any(
            (event) =>
                event.phase == BrowserScrollPhase.end && event.offset > 200,
          ),
        );
        await tester.pumpAndSettle();
        expect(
          scrollEvents.where(
            (event) => event.phase == BrowserScrollPhase.update,
          ),
          isNotEmpty,
        );
        expect(
          tester
              .widget<BrowserChromeTransition>(
                find.byType(BrowserChromeTransition),
              )
              .progress,
          1,
          reason:
              'tab=${service.activeTab?.toJson()} hasContent=${service.activeTab?.hasContent} events=${scrollEvents.map((e) => '${e.phase.name}:${e.offset}/${e.viewportExtent}/${e.contentExtent}').join(',')} focus=${FocusManager.instance.primaryFocus}',
        );
        scrollEvents.clear();
        await service.evaluateJavascript(
          'window.scrollTo({top: 0, behavior: "smooth"})',
          tabId: tab.id,
        );
        await waitUntil(
          () => scrollEvents.any(
            (event) =>
                event.phase == BrowserScrollPhase.end && event.offset == 0,
          ),
        );
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<BrowserChromeTransition>(
                find.byType(BrowserChromeTransition),
              )
              .progress,
          0,
        );
      } finally {
        service.scrollPosition.removeListener(captureScroll);
      }

      Finder more() => find.byWidgetPredicate(
        (widget) => widget is BrowserActionButton && widget.label == 'More',
      );
      final surface = find.byKey(const ValueKey('browserMenuSurface'));
      final selection = find.byKey(const ValueKey('browserMenuSelection'));
      final pointer = await tester.startGesture(tester.getCenter(more()));
      await tester.pump(const Duration(milliseconds: 650));
      await tester.pumpAndSettle();
      expect(surface, findsOneWidget);
      await pointer.moveTo(tester.getCenter(find.text('New tab')));
      await tester.pump(const Duration(milliseconds: 240));
      expect(selection, findsOneWidget);
      expect(
        tester
            .getRect(selection)
            .contains(tester.getCenter(find.text('New tab'))),
        isTrue,
      );
      expect(service.tabs, hasLength(1));
      await pointer.moveTo(tester.getCenter(find.text('Bookmarks')));
      await tester.pump(const Duration(milliseconds: 240));
      expect(selection, findsOneWidget);
      expect(
        tester
            .getRect(selection)
            .contains(tester.getCenter(find.text('Bookmarks'))),
        isTrue,
      );
      // Return to a command before release; crossing rows never executes them.
      await pointer.moveTo(tester.getCenter(find.text('New tab')));
      await tester.pump(const Duration(milliseconds: 240));
      expect(
        tester
            .getRect(selection)
            .contains(tester.getCenter(find.text('New tab'))),
        isTrue,
      );
      expect(service.tabs, hasLength(1));
      await pointer.up();
      await tester.pumpAndSettle();
      expect(surface, findsNothing);
      expect(service.tabs, hasLength(2));

      // Creating a tab intentionally focuses its address field. This test
      // switches tabs directly, so leave that editing session first.
      FocusManager.instance.primaryFocus?.unfocus();
      await service.selectTab(tab.id);
      await tester.pumpAndSettle();
      final cancel = await tester.startGesture(tester.getCenter(more()));
      await tester.pump(const Duration(milliseconds: 650));
      await tester.pumpAndSettle();
      await cancel.moveTo(tester.getCenter(find.text('New tab')));
      await tester.pump(const Duration(milliseconds: 100));
      await cancel.cancel();
      await tester.pumpAndSettle();
      expect(service.tabs, hasLength(2));
      expect(surface, findsNothing);

      final release = await tester.startGesture(tester.getCenter(more()));
      await tester.pump(const Duration(milliseconds: 650));
      await tester.pumpAndSettle();
      await release.up();
      await tester.pumpAndSettle();
      expect(surface, findsOneWidget);
      await tester.tap(find.text('Browser settings'));
      await tester.pumpAndSettle();
      expect(find.text('Search engine'), findsOneWidget);
      expect(find.byType(BrowserManagementPage), findsOneWidget);
      // These are route-level settings, rendered by the same Flutter controls
      // on both platforms. Changing the material must preserve the native page.
      for (final choice in [
        ('Solid', BrowserSurfaceStyle.solid),
        ('Liquid glass', BrowserSurfaceStyle.liquid),
        ('Frosted', BrowserSurfaceStyle.frosted),
        ('Liquid glass', BrowserSurfaceStyle.liquid),
      ]) {
        await tester.tap(find.text(choice.$1));
        await tester.pumpAndSettle();
        expect(service.settings.surfaceStyle, choice.$2);
        expect(service.activeTabId, tab.id);
      }
      await tester.tap(
        find.byWidgetPredicate(
          (widget) =>
              widget is BrowserSurfaceIconButton && widget.label == 'Done',
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(BrowserManagementPage), findsNothing);
      await tester.tap(more());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Page options'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('browserSubmenuSurface')),
        findsOneWidget,
      );
      expect(find.text('Find on page'), findsOneWidget);
      // System Back returns to the parent layer before it closes the menu.
      await binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(surface, findsOneWidget);
      await tester.tap(find.text('Bookmarks'));
      await tester.pumpAndSettle();
      expect(find.byType(BrowserManagementPage), findsOneWidget);
      expect(tester.takeException(), isNull);
      binding.reportData = {
        'nativeScroll': {
          'trustedScrollUpdates': true,
          'nativeScrollEnd': true,
          'collapseAndExpand': true,
        },
        'heldMenu': {
          'platform': Platform.operatingSystem,
          'nativeMaterial': NativeBrowserGlass.isSupported,
          'shaderFilters': ui.ImageFilter.isShaderFilterSupported,
          'crossRowAndFooter': true,
          'releaseExecutesOnce': true,
          'cancelExecutesNothing': true,
          'releaseWithoutMoveAllowsTap': true,
          'layeredSubmenuBack': true,
          'fullManagementRoutes': true,
          'materialSwitchKeepsTab': true,
        },
      };
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await service.flush();
      service.dispose();
      settings.dispose();
      await database.close();
      await directory.delete(recursive: true);
    }
  }, timeout: const Timeout(Duration(minutes: 2)));
}
