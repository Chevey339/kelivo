import 'package:provider/provider.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import '../../support/business_test_harness.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:Kelivo/core/services/browser/browser_service.dart';
import 'package:Kelivo/features/browser/models/browser_models.dart';
import 'package:Kelivo/features/browser/models/browser_tool_presentation.dart';
import 'package:Kelivo/features/browser/widgets/browser_page_card.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/widgets/ios_tactile.dart';

class CardBrowser extends BrowserService {
  Uint8List? preview;
  String? runningTab;
  final watched = <String>{};
  @override
  String? get agentSessionId => runningTab == null ? null : 'chat';
  @override
  String? get agentTabId => runningTab;
  @override
  VoidCallback watchTabPreview(String id) {
    watched.add(id);
    return () => watched.remove(id);
  }

  @override
  List<BrowserTab> get tabs => const [
    BrowserTab(id: 'one', url: 'https://www.example.com/path', title: 'Title'),
    BrowserTab(id: 'second', url: 'https://two.example', title: 'Second page'),
  ];
  @override
  Uint8List? previewForTab(String id) => id == 'one' ? preview : null;
  @override
  Future<void> refreshActivePreview({bool fresh = false}) =>
      throw StateError('Cards must not capture');
  void changed() => notifyListeners();
}

BrowserToolAction action(
  String id, {
  bool failed = false,
  bool loading = false,
  String tab = 'one',
}) => BrowserToolAction(
  id: id,
  arguments: const {
    'action': 'open',
    'url': 'https://www.example.com/path?q=1',
  },
  loading: loading,
  content: loading
      ? null
      : jsonEncode(
          failed
              ? {'ok': false, 'error': 'browser_agent_disabled'}
              : {
                  'ok': true,
                  'page': {
                    'tab_id': tab,
                    'title': 'A very long page title ' * 8,
                    'url': 'https://www.example.com/path?q=1',
                  },
                },
        ),
);
void main() {
  late CardBrowser browser;
  late SettingsProvider settings;
  setUp(() async {
    browser = CardBrowser();
    settings = SettingsProvider(createBusinessTestPreferences());
    await settings.loaded;
  });
  tearDown(() {
    browser.dispose();
    settings.dispose();
  });
  Future<void> pump(
    WidgetTester tester,
    List<BrowserToolAction> actions, {
    bool lite = false,
    bool dark = false,
    Locale locale = const Locale('en'),
    bool visible = true,
    ValueChanged<String?>? onOpen,
  }) async {
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: settings,
        child: MaterialApp(
          theme: ThemeData(
            brightness: dark ? Brightness.dark : Brightness.light,
          ),
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: 300,
                child: TickerMode(
                  enabled: visible,
                  child: BrowserStepGroupBody(
                    key: const ValueKey('body'),
                    actions: actions,
                    conversationId: 'chat',
                    lite: lite,
                    service: browser,
                    onOpen: onOpen,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets(
    'completed card uses local placeholder, compact height, host and correct tab',
    (tester) async {
      String? opened;
      await pump(tester, [action('a')], onOpen: (id) => opened = id);
      expect(
        find.byKey(const ValueKey('browser-preview-placeholder')),
        findsOneWidget,
      );
      expect(find.text('example.com'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('browser-actions-toggle')),
        findsNothing,
      );
      expect(tester.getSize(find.byType(BrowserPageCard)).height, 64);
      await tester.tap(find.byType(BrowserPageCard));
      expect(opened, 'one');
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('failed card shows enable action and bounded error', (
    tester,
  ) async {
    await pump(tester, [action('a', failed: true)], dark: true);
    expect(find.text("Couldn't open page"), findsOneWidget);
    expect(find.text('Enable'), findsOneWidget);
    expect(find.text('Browser control is off'), findsOneWidget);
    expect(find.byKey(const ValueKey('browser-preview-error')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'preview follows running/completed state and lightweight layout',
    (tester) async {
      await pump(tester, [action('a'), action('b', loading: true)]);
      expect(find.text('Live'), findsOneWidget);
      await pump(tester, [action('a'), action('b')]);
      await tester.pumpAndSettle();
      expect(find.text('Live'), findsNothing);
      await pump(tester, [action('a'), action('b')], lite: true);
      expect(tester.getSize(find.byType(BrowserPageCard)).height, 36);
      expect(
        find.byKey(const ValueKey('browser-actions-toggle')),
        findsNothing,
      );
    },
  );
  for (final dark in [false, true]) {
    testWidgets('card uses quiet fill in ${dark ? 'dark' : 'light'} theme', (
      tester,
    ) async {
      await pump(tester, [action('a')], dark: dark);
      final card = find.byKey(const ValueKey('browser-page-card'));
      final press = tester.widget<IosCardPress>(card);
      final cs = Theme.of(tester.element(card)).colorScheme;
      expect(press.baseColor, cs.onSurface.withValues(alpha: dark ? .06 : .04));
      expect(press.baseColor, isNot(Colors.white));
      expect(
        press.border!.top.color,
        cs.onSurface.withValues(alpha: dark ? .08 : .06),
      );
    });
  }
  testWidgets(
    'live preview opens the displayed tab before its tool result arrives',
    (tester) async {
      browser.runningTab = 'second';
      String? opened;
      await pump(tester, [
        action('a'),
        action('b', loading: true),
      ], onOpen: (id) => opened = id);
      await tester.tap(find.byKey(const ValueKey('browser-page-card')));
      await tester.pump();
      expect(opened, 'second');
      expect(find.text('Second page'), findsOneWidget);
      expect(browser.watched, {'second'});
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
  );

  testWidgets('covered and lightweight cards release preview observation', (
    tester,
  ) async {
    final actions = [action('a')];
    await pump(tester, actions);
    expect(browser.watched, {'one'});
    await pump(tester, actions, visible: false);
    expect(browser.watched, isEmpty);
    await pump(tester, actions, visible: true);
    expect(browser.watched, {'one'});
    await pump(tester, actions, lite: true);
    expect(browser.watched, isEmpty);
  });

  testWidgets(
    'cached preview text follows locale changes without new actions',
    (tester) async {
      final actions = [action('a', failed: true)];
      await pump(tester, actions);
      final state = tester.state(find.byType(BrowserStepGroupBody));
      expect(find.text("Couldn't open page"), findsOneWidget);
      expect(find.text('Browser control is off'), findsOneWidget);
      await pump(tester, actions, locale: const Locale('zh'));
      await tester.pumpAndSettle();
      expect(tester.state(find.byType(BrowserStepGroupBody)), same(state));
      expect(find.text('未能打开页面'), findsOneWidget);
      expect(find.text('浏览器控制未开启'), findsOneWidget);
      expect(find.text('去开启'), findsOneWidget);
      expect(find.text("Couldn't open page"), findsNothing);
    },
  );

  testWidgets(
    'unrelated browser notifications reuse the card, cached pixels update it without capture',
    (tester) async {
      await pump(tester, [action('a')]);
      final first = tester.widget<BrowserPageCard>(
        find.byType(BrowserPageCard),
      );
      browser.changed();
      await tester.pump();
      expect(
        tester.widget<BrowserPageCard>(find.byType(BrowserPageCard)),
        same(first),
      );
      browser.preview = base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
      );
      browser.changed();
      await tester.pump();
      final current = tester.widget<BrowserPageCard>(
        find.byType(BrowserPageCard),
      );
      expect(current, isNot(same(first)));
      expect(current.preview, same(browser.preview));
      expect(find.byType(Image), findsOneWidget);
    },
  );
}
