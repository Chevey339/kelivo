import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:provider/provider.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/browser/browser_service.dart';
import 'package:Kelivo/features/browser/browser_navigation.dart';
import 'package:Kelivo/features/browser/browser_panel_controller.dart';
import 'package:Kelivo/features/browser/pages/browser_page.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import '../../support/business_test_harness.dart';

class _Paths extends PathProviderPlatform {
  _Paths(this.path);
  final String path;
  @override
  Future<String?> getApplicationSupportPath() async => path;
}

void main() {
  testWidgets(
    'card tab is selected for dock and full page; closed tab falls back',
    (tester) async {
      final oldPaths = PathProviderPlatform.instance;
      late Directory directory;
      late SettingsProvider settings;
      final browser = BrowserService.instance;
      final panel = BrowserPanelController.instance;
      // Keep the singleton's cold and warm checks in one fake-clock lifetime.
      expect(browser.isInitialized, isFalse);
      panel.attachHost();
      late BuildContext coldEntry;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              coldEntry = context;
              return const Scaffold();
            },
          ),
        ),
      );
      await openBrowserPage(
        coldEntry,
        conversationId: 'chat',
        tabId: 'not-restored',
      );
      expect(panel.isOpen, isTrue);
      expect(panel.initialTabId, isNull);
      expect(browser.isInitialized, isFalse);
      await tester.runAsync(() async {
        directory = await Directory.systemTemp.createTemp(
          'browser-card-navigation',
        );
        PathProviderPlatform.instance = _Paths(directory.path);
        settings = SettingsProvider(createBusinessTestPreferences());
        await settings.loaded;
        await browser.initialize();
      });
      addTearDown(() async {
        panel.detachHost();
        await browser.flush();
        browser.dispose();
        settings.dispose();
        PathProviderPlatform.instance = oldPaths;
        await directory.delete(recursive: true);
      });
      final first = (await tester.runAsync(
        () => browser.createTab(ownerSessionId: 'chat'),
      ))!;
      final second = (await tester.runAsync(
        () => browser.createTab(ownerSessionId: 'chat'),
      ))!;
      late BuildContext entry;
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: settings,
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Builder(
              builder: (context) {
                entry = context;
                return const Scaffold(body: Text('Chat'));
              },
            ),
          ),
        ),
      );
      await openBrowserPage(entry, conversationId: 'chat', tabId: first.id);
      expect(browser.activeTabId, first.id);
      expect(panel.initialTabId, first.id);
      expect(panel.isOpen, isTrue);
      await tester.runAsync(() => browser.closeTab(second.id));
      await openBrowserPage(entry, conversationId: 'chat', tabId: second.id);
      expect(panel.initialTabId, isNull);
      expect(browser.activeTabId, first.id);
      final route = openBrowserPage(
        entry,
        conversationId: 'chat',
        tabId: first.id,
        fullPage: true,
      );
      await tester.pumpAndSettle();
      expect(
        tester.widget<BrowserPage>(find.byType(BrowserPage)).initialTabId,
        first.id,
      );
      expect(browser.activeTabId, first.id);
      Navigator.of(tester.element(find.byType(BrowserPage))).pop();
      await tester.pumpAndSettle();
      await route;
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(browser.flush);
    },
  );
}
