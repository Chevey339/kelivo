import 'dart:io';
import 'dart:convert';
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

// Store writes started by a pumped debounce timer continue in the fake zone.
// Let real I/O finish AND pump those continuations instead of awaiting their
// queue from runAsync, which cannot drain the fake zone while it is blocked.
Future<void> _flushBrowser(WidgetTester tester, BrowserService browser) async {
  var done = false;
  final pending = browser.flush().whenComplete(() => done = true);
  pending.ignore();
  for (var i = 0; i < 400 && !done; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump();
  }
  expect(done, isTrue, reason: 'Browser state writes must finish');
  await pending;
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
        await _flushBrowser(tester, browser);
        await tester.runAsync(() async {
          panel.detachHost();
          browser.dispose();
          settings.dispose();
          PathProviderPlatform.instance = oldPaths;
          await directory.delete(recursive: true);
        });
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
      // Expanding this conversation must not inherit another chat's docked tab.
      final other = (await tester.runAsync(
        () => browser.createTab(ownerSessionId: 'other-chat'),
      ))!;
      panel.open(conversationId: 'other-chat', initialTabId: other.id);
      final ownRoute = openBrowserPage(
        entry,
        conversationId: 'chat',
        fullPage: true,
      );
      await tester.pumpAndSettle();
      expect(
        tester.widget<BrowserPage>(find.byType(BrowserPage)).initialTabId,
        isNull,
      );
      // Unsupported hosts show the empty state without switching sessions.
      final expectedActiveTabId = browser.isSupported ? first.id : other.id;
      expect(browser.activeTabId, expectedActiveTabId);
      if (!browser.isSupported) {
        final l = AppLocalizations.of(
          tester.element(find.byType(BrowserPage)),
        )!;
        expect(find.text(l.browserUnsupported), findsOneWidget);
      }
      Navigator.of(tester.element(find.byType(BrowserPage))).pop();
      await tester.pumpAndSettle();
      await ownRoute;
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await _flushBrowser(tester, browser);
      final saved =
          (await tester.runAsync(
                () async => jsonDecode(
                  await File(
                    '${directory.path}/browser/state.json',
                  ).readAsString(),
                ),
              ))
              as Map;
      expect(saved['activeTabId'], expectedActiveTabId);
      expect((saved['lastTabBySession'] as Map)['chat'], first.id);
    },
  );
}
