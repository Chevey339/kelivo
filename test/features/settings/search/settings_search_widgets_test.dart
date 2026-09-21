import 'dart:ui' show SemanticsAction;
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/desktop/desktop_settings_page.dart';
import 'package:Kelivo/features/settings/pages/settings_search_page.dart';
import 'package:Kelivo/features/settings/pages/settings_page.dart';
import 'package:Kelivo/features/settings/search/settings_search_index.dart';
import 'package:Kelivo/features/settings/search/settings_search_navigation.dart';
import 'package:Kelivo/features/settings/widgets/settings_search_entry.dart';
import 'package:Kelivo/features/settings/widgets/settings_search_view.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/l10n/app_localizations_en.dart';
import 'package:Kelivo/shared/widgets/ios_switch.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'
    show debugDefaultTargetPlatformOverride;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../../../support/business_test_harness.dart';

void main() {
  Future<SettingsProvider> pump(
    WidgetTester tester,
    Widget child, {
    Size size = const Size(390, 844),
    TargetPlatform platform = TargetPlatform.iOS,
    double textScale = 1,
  }) async {
    debugDefaultTargetPlatformOverride = platform;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final settings = SettingsProvider(createBusinessTestPreferences());
    await settings.loaded;
    addTearDown(settings.dispose);
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: settings,
        child: Consumer<SettingsProvider>(
          builder: (context, settings, _) => MaterialApp(
            locale: settings.appLocaleForMaterialApp,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(textScale)),
              child: child!,
            ),
            home: child,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return settings;
  }

  testWidgets('search is hidden initially, pulls into view, and scrolls away', (
    tester,
  ) async {
    var taps = 0;
    await pump(
      tester,
      Scaffold(
        appBar: AppBar(title: const Text('Settings')),
        body: SettingsSearchList(
          onSearch: (_) async {
            taps++;
          },
          children: List.generate(
            30,
            (i) => SizedBox(height: 56, child: Text('Setting $i')),
          ),
        ),
      ),
    );
    expect(find.byType(SettingsSearchEntry).hitTestable(), findsNothing);
    await tester.drag(find.byType(CustomScrollView), const Offset(0, 100));
    await tester.pumpAndSettle();
    expect(find.byType(SettingsSearchEntry).hitTestable(), findsOneWidget);
    await tester.tap(find.byType(SettingsSearchEntry));
    expect(taps, 1);
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -200));
    await tester.pumpAndSettle();
    expect(find.byType(SettingsSearchEntry).hitTestable(), findsNothing);
    expect(tester.takeException(), isNull);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets(
    'clear, no-results, submit and cancel work on a small large-text screen',
    (tester) async {
      SettingsSearchItem? selected;
      var cancelled = false;
      await pump(
        tester,
        Scaffold(
          body: SettingsSearchView(
            index: SettingsSearchIndex(
              AppLocalizationsEn(),
              platform: TargetPlatform.iOS,
            ),
            onSelected: (item) => selected = item,
            onClose: () => cancelled = true,
          ),
        ),
        size: const Size(320, 568),
        textScale: 1.5,
      );
      expect(tester.testTextInput.isVisible, isTrue);
      await tester.enterText(find.byType(TextField), 'no matching setting xyz');
      await tester.pumpAndSettle();
      expect(find.text('No settings found'), findsOneWidget);
      await tester.tap(find.byTooltip('Clear search'));
      await tester.pumpAndSettle();
      expect(find.text('Quick access'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'font size');
      await tester.pumpAndSettle();
      await tester.testTextInput.receiveAction(TextInputAction.search);
      expect(selected?.id, 'displaySettingsPageChatFontSizeTitle');
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      // Re-focus after submission so the escape shortcut receives the event.
      await tester.tap(find.byType(TextField));
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      expect(cancelled, isTrue);
      expect(tester.takeException(), isNull);
      debugDefaultTargetPlatformOverride = null;
    },
  );

  testWidgets('mobile result locates a distant row and back preserves query', (
    tester,
  ) async {
    final settings = await pump(
      tester,
      const SettingsSearchPage(onColorMode: _noop),
    );
    await tester.enterText(find.byType(TextField), 'Show Files Below Replies');
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('displaySettingsPageShowProducedFilesTitle')),
    );
    await tester.pumpAndSettle();
    final title = find.text('Show Files Below Replies').hitTestable();
    expect(title, findsOneWidget);
    final rect = tester.getRect(title);
    expect(rect.top, greaterThan(60));
    expect(rect.bottom, lessThan(844));
    await tester.tap(title);
    await tester.pumpAndSettle();
    expect(settings.showProducedFiles, isFalse);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'Show Files Below Replies',
    );
    expect(tester.takeException(), isNull);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('IME commit and submit in one frame use the latest query', (
    tester,
  ) async {
    try {
      SettingsSearchItem? selected;
      await pump(
        tester,
        Scaffold(
          body: SettingsSearchView(
            index: SettingsSearchIndex(
              AppLocalizationsEn(),
              platform: TargetPlatform.iOS,
            ),
            onSelected: (item) => selected = item,
            onClose: _noop,
          ),
        ),
      );
      for (final (draft, committed, expectedId) in [
        ('font size', 'language', 'displaySettingsPageLanguageTitle'),
        ('yuyan', '语言', 'displaySettingsPageLanguageTitle'),
        ('font size', 'no matching setting qzx', null),
        ('language', '  ', null),
      ]) {
        selected = null;
        await tester.enterText(find.byType(TextField), draft);
        await tester.pumpAndSettle();
        // The IME can commit its final text and submit before the next frame.
        tester.testTextInput.enterText(committed);
        await tester.testTextInput.receiveAction(TextInputAction.search);
        expect(selected?.id, expectedId, reason: '$draft -> $committed');
        await tester.pumpAndSettle();
      }
      expect(tester.takeException(), isNull);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('every mobile display result reaches its visible target', (
    tester,
  ) async {
    late BuildContext host;
    await pump(
      tester,
      Builder(
        builder: (context) {
          host = context;
          return const Scaffold(body: SizedBox());
        },
      ),
    );
    final index = SettingsSearchIndex(
      AppLocalizationsEn(),
      platform: TargetPlatform.iOS,
    );
    for (final item in index.entries.where(
      (item) => item.targetLabel != null,
    )) {
      openMobileSettingsSearchResult(host, item);
      await tester.pumpAndSettle();
      expect(
        find.text(item.targetLabel!).hitTestable(),
        findsOneWidget,
        reason: item.id,
      );
      expect(tester.takeException(), isNull, reason: item.id);
      Navigator.of(host).pop();
      await tester.pumpAndSettle();
    }
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets(
    'desktop search jumps down the display pane and works repeatedly',
    (tester) async {
      final settings = await pump(
        tester,
        const Scaffold(body: DesktopSettingsPage()),
        size: const Size(1280, 900),
        platform: TargetPlatform.macOS,
      );
      for (var i = 0; i < 2; i++) {
        await tester.tap(find.byType(SettingsSearchEntry));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.descendant(
            of: find.byType(SettingsSearchView),
            matching: find.byType(TextField),
          ),
          'Show Files Below Replies',
        );
        await tester.pumpAndSettle();
        await tester.tap(
          find.descendant(
            of: find.byType(SettingsSearchView),
            matching: find.byKey(
              const ValueKey('displaySettingsPageShowProducedFilesTitle'),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(SettingsSearchView), findsNothing);
        final label = find.text('Show Files Below Replies').hitTestable();
        expect(label, findsOneWidget);
        final row = find.ancestor(of: label, matching: find.byType(Row)).first;
        await tester.tap(
          find.descendant(of: row, matching: find.byType(IosSwitch)),
        );
        await tester.pumpAndSettle();
        expect(settings.showProducedFiles, i == 1);
      }
      expect(tester.takeException(), isNull);
      debugDefaultTargetPlatformOverride = null;
    },
  );
  testWidgets('every desktop display result reveals its target', (
    tester,
  ) async {
    await pump(
      tester,
      const Scaffold(body: DesktopSettingsPage()),
      size: const Size(1280, 900),
      platform: TargetPlatform.macOS,
    );
    final index = SettingsSearchIndex(
      AppLocalizationsEn(),
      platform: TargetPlatform.macOS,
    );
    for (final item in index.entries.where(
      (item) => item.targetLabel != null,
    )) {
      await tester.tap(find.byType(SettingsSearchEntry));
      await tester.pumpAndSettle();
      final view = find.byType(SettingsSearchView);
      await tester.enterText(
        find.descendant(of: view, matching: find.byType(TextField)),
        item.title,
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(of: view, matching: find.byKey(ValueKey(item.id))),
      );
      await tester.pumpAndSettle();
      expect(
        find.text(item.targetLabel!).hitTestable(),
        findsOneWidget,
        reason: item.id,
      );
      expect(tester.takeException(), isNull, reason: item.id);
    }
    debugDefaultTargetPlatformOverride = null;
  });
  testWidgets(
    'settings entry opens search, color mode picker and returns in place',
    (tester) async {
      final settings = await pump(tester, const SettingsPage());
      await tester.drag(
        find.byType(CustomScrollView).first,
        const Offset(0, 110),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(SettingsSearchEntry));
      await tester.pumpAndSettle();
      expect(find.byType(SettingsSearchView), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'Color Mode');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('colorMode')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Dark'));
      await tester.pumpAndSettle();
      expect(settings.themeMode, ThemeMode.dark);
      expect(find.byType(SettingsSearchView), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.byType(SettingsSearchEntry).hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
      debugDefaultTargetPlatformOverride = null;
    },
  );

  testWidgets('keyboard can focus and activate a result', (tester) async {
    SettingsSearchItem? selected;
    await pump(
      tester,
      Scaffold(
        body: SettingsSearchView(
          index: SettingsSearchIndex(
            AppLocalizationsEn(),
            platform: TargetPlatform.macOS,
          ),
          onSelected: (item) => selected = item,
          onClose: _noop,
        ),
      ),
      platform: TargetPlatform.macOS,
    );
    await tester.enterText(find.byType(TextField), 'font size');
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(selected?.id, 'displaySettingsPageChatFontSizeTitle');
    expect(tester.takeException(), isNull);
    debugDefaultTargetPlatformOverride = null;
  });
  testWidgets('color picker uses the locale changed through a search result', (
    tester,
  ) async {
    try {
      final settings = await pump(tester, const SettingsPage());
      await tester.drag(find.byType(CustomScrollView), const Offset(0, 110));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(SettingsSearchEntry));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'language');
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('displaySettingsPageLanguageTitle')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find
            .text(AppLocalizationsEn().displaySettingsPageLanguageTitle)
            .hitTestable(),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Simplified Chinese'));
      await tester.pumpAndSettle();
      expect(settings.appLocale.languageCode, 'zh');
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'color mode');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('colorMode')));
      await tester.pumpAndSettle();
      final l10n = AppLocalizations.of(
        tester.element(find.byType(BottomSheet)),
      )!;
      Finder option(String label) => find.descendant(
        of: find.byType(BottomSheet),
        matching: find.text(label),
      );
      expect(option(l10n.settingsPageSystemMode), findsOneWidget);
      expect(option(l10n.settingsPageLightMode), findsOneWidget);
      expect(option(l10n.settingsPageDarkMode), findsOneWidget);
      expect(option('Dark'), findsNothing);
      await tester.tap(option(l10n.settingsPageDarkMode));
      await tester.pumpAndSettle();
      expect(settings.themeMode, ThemeMode.dark);
      await tester.tap(find.text(l10n.settingsSearchCancel));
      await tester.pumpAndSettle();
      expect(find.byType(SettingsSearchEntry).hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
  testWidgets(
    'accessible navigation shows the search entry without a gesture',
    (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        await pump(
          tester,
          Builder(
            builder: (context) => Scaffold(
              body: MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(accessibleNavigation: true),
                child: SettingsSearchList(
                  onSearch: (_) async {},
                  children: const [SizedBox(height: 1000)],
                ),
              ),
            ),
          ),
        );
        expect(find.byType(SettingsSearchEntry).hitTestable(), findsOneWidget);
        expect(
          tester
              .getSemantics(find.bySemanticsLabel('Search settings'))
              .getSemanticsData()
              .hasAction(SemanticsAction.tap),
          isTrue,
        );
        expect(tester.takeException(), isNull);
      } finally {
        semantics.dispose();
        debugDefaultTargetPlatformOverride = null;
      }
    },
  );
}

void _noop() {}
