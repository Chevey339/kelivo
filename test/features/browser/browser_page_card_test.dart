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

class CardBrowser extends BrowserService {
  Uint8List? preview;
  @override
  List<BrowserTab> get tabs => const [
    BrowserTab(id: 'one', url: 'https://www.example.com/path', title: 'Title'),
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
    ValueChanged<String?>? onOpen,
  }) async {
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: settings,
        child: MaterialApp(
          theme: ThemeData(
            brightness: dark ? Brightness.dark : Brightness.light,
          ),
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: 300,
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
      expect(find.text('1 actions'), findsOneWidget);
      expect(find.byType(BrowserActionRow), findsNothing);
      expect(tester.getSize(find.byType(BrowserPageCard)).height, 64);
      await tester.tap(find.byType(BrowserPageCard));
      expect(opened, 'one');
      await tester.tap(find.byKey(const ValueKey('browser-actions-toggle')));
      await tester.pumpAndSettle();
      expect(find.byType(BrowserActionRow), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'failed card defaults expanded with enable action and bounded error',
    (tester) async {
      await pump(tester, [action('a', failed: true)], dark: true);
      expect(find.text("Couldn't open page"), findsOneWidget);
      expect(find.text('Enable'), findsOneWidget);
      expect(find.text('Browser control is off'), findsNWidgets(2));
      expect(
        find.byKey(const ValueKey('browser-preview-error')),
        findsOneWidget,
      );
      expect(find.byType(BrowserActionRow), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'streaming defaults expand then collapse, explicit choice survives group growth',
    (tester) async {
      await pump(tester, [action('a'), action('b', loading: true)]);
      expect(find.text('Live'), findsOneWidget);
      expect(find.byType(BrowserActionRow), findsNWidgets(2));
      await pump(tester, [action('a'), action('b')]);
      await tester.pumpAndSettle();
      expect(find.byType(BrowserActionRow), findsNothing);
      await tester.tap(find.byKey(const ValueKey('browser-actions-toggle')));
      await tester.pumpAndSettle();
      await pump(tester, [action('a'), action('b'), action('c')]);
      await tester.pumpAndSettle();
      expect(find.byType(BrowserActionRow), findsNWidgets(3));
      await pump(tester, [action('a'), action('b')], lite: true);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('browser-actions-toggle')),
        findsNothing,
      );
      expect(tester.getSize(find.byType(BrowserPageCard)).height, 36);
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
