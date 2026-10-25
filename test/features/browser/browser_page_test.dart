import 'package:Kelivo/features/browser/widgets/browser_text_field.dart';
import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import '../../support/business_test_harness.dart';
import 'package:Kelivo/core/services/browser/browser_engine.dart';
import 'package:Kelivo/core/services/browser/browser_service.dart';
import 'package:Kelivo/core/services/browser/browser_store.dart';
import 'package:Kelivo/core/services/haptics.dart';
import 'package:Kelivo/features/browser/models/browser_models.dart';
import 'package:Kelivo/features/browser/browser_tabs_route.dart';
import 'package:Kelivo/features/browser/pages/browser_desktop_layout.dart';
import 'package:Kelivo/features/browser/pages/browser_mobile_layout.dart';
import 'package:Kelivo/features/browser/pages/browser_management_page.dart';
import 'package:Kelivo/features/browser/pages/browser_page.dart';
import 'package:Kelivo/features/browser/widgets/browser_glass.dart';
import 'package:Kelivo/features/browser/widgets/browser_controls.dart';
import 'package:Kelivo/features/browser/widgets/browser_find_bar.dart';
import 'package:Kelivo/features/browser/widgets/browser_library.dart';
import 'package:Kelivo/features/browser/widgets/browser_settings.dart';
import 'package:Kelivo/features/browser/widgets/browser_tabs.dart';
import 'package:Kelivo/features/browser/widgets/browser_transition_snapshot.dart';
import 'package:Kelivo/features/browser/widgets/browser_window_chrome.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/widgets/custom_bottom_sheet.dart';
import 'package:Kelivo/shared/widgets/snackbar.dart';

BrowserPageState _scroll(
  double offset, {
  BrowserScrollPhase phase = BrowserScrollPhase.update,
  double viewport = 844,
  double content = 4000,
  bool supportsEnd = true,
  bool interacting = true,
  double gestureDelta = 0,
}) => BrowserPageState(
  scroll: BrowserScrollState(
    offset: offset,
    viewportExtent: viewport,
    contentExtent: content,
    phase: phase,
    supportsScrollEnd: supportsEnd,
    isUserInteracting: interacting,
    gestureDelta: gestureDelta,
  ),
);

void main() {
  late BrowserService service;
  late SettingsProvider settings;
  late Map<String, _Engine> engines;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    settings = SettingsProvider(createBusinessTestPreferences());
    await settings.loaded;
    Haptics.setEnabled(false);
    engines = {};
    service = BrowserService(
      supported: true,
      store: _MemoryStore(),
      engineFactory:
          ({
            required tab,
            required settings,
            required onChanged,
            required onDownload,
            required onNewWindow,
            required isAgentActive,
          }) async {
            final engine = _Engine(onChanged);
            if (tab.url == 'https://dark.example') {
              engine.backgroundColor = Colors.black;
            }
            engines[tab.id] = engine;
            await engine.navigate(tab.url);
            return engine;
          },
    );
  });

  tearDown(() {
    service.dispose();
    settings.dispose();
    Haptics.setEnabled(true);
    debugDefaultTargetPlatformOverride = null;
  });

  // Flutter verifies pending timers before package:test tearDown callbacks.
  // Dispose the browser in the widget-test body after unmounting its host.
  void browserTestWidgets(String description, WidgetTesterCallback callback) {
    testWidgets(description, (tester) async {
      try {
        await callback(tester);
      } finally {
        await tester.pump(const Duration(seconds: 4));
        await tester.pumpAndSettle();
        await tester.pumpWidget(const SizedBox.shrink());
        service.dispose();
        debugDefaultTargetPlatformOverride = null;
        await tester.pump(const Duration(seconds: 4));
        await tester.pumpAndSettle();
      }
    });
  }

  Future<void> mount(
    WidgetTester tester, {
    String? conversationId,
    String? initialTabId,
    Size size = const Size(390, 844),
    double textScale = 1,
    bool reduceMotion = false,
    bool embedded = false,
    bool shortcutsEnabled = true,
    bool settle = true,
    ThemeData? theme,
    VoidCallback? onClose,
    VoidCallback? onExpand,
    VoidCallback? onDock,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ChangeNotifierProvider<SettingsProvider>.value(
        value: settings,
        child: MaterialApp(
          theme: theme,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(textScale),
              disableAnimations: reduceMotion,
            ),
            child: AppSnackBarOverlay(child: child ?? const SizedBox.shrink()),
          ),
          home: BrowserPage(
            service: service,
            conversationId: conversationId,
            initialTabId: initialTabId,
            embedded: embedded,
            shortcutsEnabled: shortcutsEnabled,
            onClose: onClose,
            onExpand: onExpand,
            onDock: onDock,
          ),
        ),
      ),
    );
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
    }
  }

  Future<Uint8List> previewFixture(
    WidgetTester tester, {
    int width = 8,
  }) async => (await tester.runAsync(() async {
    final image = await createTestImage(width: width, height: 8, cache: false);
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      return data!.buffer.asUint8List();
    } finally {
      image.dispose();
    }
  }))!;

  Future<void> openMobileMenuItem(WidgetTester tester, String label) async {
    await tester.tap(find.byTooltip('More').last);
    await tester.pumpAndSettle();
    expect(find.byType(InkWell), findsNothing);
    expect(find.byType(InkResponse), findsNothing);
    final item = find.text(label);
    await tester.ensureVisible(item);
    await tester.tap(item);
    await tester.pumpAndSettle();
  }

  double expectReadableCollapsedAddress(
    WidgetTester tester,
    Finder address,
    double expandedWidth,
  ) {
    final host = find.descendant(
      of: address,
      matching: find.text('example.com'),
    );
    expect(host, findsOneWidget);
    final paragraph = tester.renderObject<RenderParagraph>(host);
    final hostWidth = paragraph.getMaxIntrinsicWidth(double.infinity) * 13 / 16;
    final collapsedWidth = tester.getSize(address).width;
    // The capsule must shrink while preserving its host label and padding.
    // Its final width depends on the rendered font, not a fraction of the bar.
    expect(collapsedWidth, lessThan(expandedWidth));
    expect(collapsedWidth, greaterThan(hostWidth));
    expect(paragraph.size.width, greaterThanOrEqualTo(hostWidth));
    expect(paragraph.didExceedMaxLines, isFalse);
    expect(tester.widget<BrowserAddressBar>(address).collapsed, isTrue);
    return collapsedWidth;
  }

  browserTestWidgets(
    'address dismissal fades side controls and interpolates capsule width',
    (tester) async {
      await service.initialize();
      await service.createTab(url: 'https://example.com');
      await mount(tester);
      final address = find.byType(BrowserAddressBar);
      final normalWidth = tester.getSize(address).width;
      final navigation = find.byKey(
        const ValueKey('browserMobileNavigationGroup'),
      );
      await tester.tap(address);
      await tester.pumpAndSettle();
      final editWidth = tester.getSize(address).width;
      expect(editWidth, greaterThan(normalWidth));
      expect(tester.widget<BrowserGlass>(navigation).opacity, 0);
      tester.widget<BrowserAddressBar>(address).focusNode.unfocus();
      await tester.pump();
      // FocusManager delivers the focus change after the current frame.
      await tester.pump();
      expect(tester.widget<BrowserGlass>(navigation).opacity, 0);
      await tester.pump(const Duration(milliseconds: 70));
      expect(
        tester.widget<BrowserGlass>(navigation).opacity,
        inExclusiveRange(0, 1),
      );
      expect(
        tester.getSize(address).width,
        inExclusiveRange(normalWidth, editWidth),
      );
      await tester.pumpAndSettle();
      expect(tester.widget<BrowserGlass>(navigation).opacity, 1);
      expect(tester.getSize(address).width, normalWidth);
    },
  );

  browserTestWidgets(
    'Android keyboard Back leaves address editing and restores controls',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      addTearDown(tester.view.resetViewInsets);
      await service.initialize();
      await service.createTab(url: 'https://example.com');
      await mount(tester);
      final address = find.byType(BrowserAddressBar);
      await tester.tap(address);
      await tester.pumpAndSettle();
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.pumpAndSettle();
      expect(tester.widget<BrowserAddressBar>(address).editing, isTrue);
      tester.view.viewInsets = FakeViewPadding.zero;
      await tester.pumpAndSettle();
      expect(tester.widget<BrowserAddressBar>(address).editing, isFalse);
      expect(
        tester
            .widget<BrowserGlass>(
              find.byKey(const ValueKey('browserMobileNavigationGroup')),
            )
            .opacity,
        1,
      );
    },
  );

  browserTestWidgets(
    'Android collapsed dock retains clearance above the gesture area',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      tester.view.viewPadding = const FakeViewPadding(bottom: 24);
      addTearDown(tester.view.resetViewPadding);
      await service.initialize();
      final tab = await service.createTab(url: 'https://example.com');
      await mount(tester);
      engines[tab.id]!.onChanged(_scroll(180));
      await tester.pumpAndSettle();
      final address = find.byType(BrowserAddressBar);
      expect(tester.widget<BrowserAddressBar>(address).collapsed, isTrue);
      expect(tester.getRect(address).bottom, lessThanOrEqualTo(844 - 24));
    },
  );

  browserTestWidgets(
    'More never starts a native screenshot during its presentation',
    (tester) async {
      await service.initialize();
      final tab = await service.createTab(url: 'https://example.com');
      await mount(tester);
      final engine = engines[tab.id]!;
      final captures = engine.screenshotCalls;
      await tester.tap(find.byTooltip('More').last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));
      expect(find.text('New tab'), findsOneWidget);
      expect(engine.screenshotCalls, captures);
      await tester.pumpAndSettle();
      expect(engine.screenshotCalls, captures);
    },
  );

  browserTestWidgets(
    'preview capture waits for an idle viewport and does not repeat unchanged',
    (tester) async {
      await service.initialize();
      final tab = await service.createTab(url: 'https://example.com');
      await mount(tester);
      final engine = engines[tab.id]!;
      engine.previewBytes = await previewFixture(tester);
      final captures = engine.screenshotCalls;
      final gesture = await tester.startGesture(
        tester.getCenter(
          find.byKey(const ValueKey('browserMobileViewportSlot')),
        ),
      );
      engine.onChanged(_scroll(100));
      await tester.pump(const Duration(seconds: 2));
      expect(engine.screenshotCalls, captures);
      await gesture.up();
      engine.onChanged(_scroll(100, interacting: false));
      await tester.pump(const Duration(milliseconds: 900));
      expect(engine.screenshotCalls, captures);
      await tester.pump(const Duration(milliseconds: 200));
      expect(engine.screenshotCalls, captures + 1);
      await tester.pump(const Duration(seconds: 3));
      expect(engine.screenshotCalls, captures + 1);

      // A new quiet period must be cancelled when address editing starts.
      engine.onChanged(_scroll(120, interacting: false));
      await tester.pump();
      await tester.tap(find.byType(BrowserAddressBar));
      await tester.pump(const Duration(seconds: 2));
      expect(engine.screenshotCalls, captures + 1);
    },
  );

  browserTestWidgets('identical captured pixels reuse the cached preview', (
    tester,
  ) async {
    await service.initialize();
    final tab = await service.createTab(url: 'https://preview.example');
    await mount(tester);
    final engine = engines[tab.id]!;
    engine.previewBytes = await previewFixture(tester);
    await service.refreshActivePreview();
    final first = service.previewForTab(tab.id);
    // cache: false creates a new byte buffer, not different image content.
    final identicalPixels = await previewFixture(tester);
    expect(identicalPixels, isNot(same(first)));
    expect(listEquals(first, identicalPixels), isTrue);
    engine.previewBytes = identicalPixels;
    final captures = engine.screenshotCalls;
    await service.refreshActivePreview(fresh: true);
    expect(engine.screenshotCalls, captures + 1);
    expect(service.previewForTab(tab.id), same(first));
  });

  browserTestWidgets(
    'tabs capture the current page before starting the card flight',
    (tester) async {
      await service.initialize();
      final tab = await service.createTab(url: 'https://preview.example');
      await mount(tester);
      final engine = engines[tab.id]!;
      engine.previewBytes = await previewFixture(tester);
      await service.refreshActivePreview();
      final old = service.previewForTab(tab.id);
      engine.onChanged(_scroll(200));
      final current = await previewFixture(tester, width: 9);
      expect(listEquals(old, current), isFalse);
      engine.previewBytes = current;
      await tester.runAsync(
        () => precacheImage(
          MemoryImage(current),
          tester.element(find.byType(BrowserPage)),
        ),
      );
      final captures = engine.screenshotCalls;
      await openMobileMenuItem(tester, 'Tabs (1)');
      final overview = find.byType(BrowserTabOverview);
      expect(overview, findsOneWidget);
      final route =
          ModalRoute.of(tester.element(overview))! as BrowserTabsRoute;
      expect(engine.screenshotCalls, captures + 1);
      expect(route.transition.openingPreviewReady, isTrue);
      expect(route.transition.previewBytes, same(current));
      expect(route.transition.previewBytes, isNot(same(old)));
    },
  );

  browserTestWidgets(
    'collapsed address measures the inherited app typography',
    (tester) async {
      await service.initialize();
      final tab = await service.createTab(url: 'https://xy.io');
      final base = ThemeData(fontFamily: 'BrowserCustomFont');
      await mount(
        tester,
        theme: base.copyWith(
          textTheme: base.textTheme.copyWith(
            bodyMedium: base.textTheme.bodyMedium!.copyWith(letterSpacing: 3),
          ),
        ),
      );
      engines[tab.id]!.onChanged(_scroll(160));
      await tester.pumpAndSettle();
      final address = find.byType(BrowserAddressBar);
      expect(tester.widget<BrowserAddressBar>(address).collapseProgress, 1);
      final paragraph = tester.renderObject<RenderParagraph>(
        find.descendant(
          of: address,
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is RichText && widget.text.toPlainText() == 'xy.io',
          ),
        ),
      );
      expect(paragraph.text.style!.fontFamily, 'BrowserCustomFont');
      expect(
        tester.getSize(address).width,
        closeTo(
          paragraph.getMaxIntrinsicWidth(double.infinity) * 13 / 16 + 32,
          .01,
        ),
      );
    },
  );

  browserTestWidgets(
    'mobile address submits a search and mounts the shared engine',
    (tester) async {
      await mount(tester, conversationId: 'chat-a');
      expect(find.text('Kelivo'), findsOneWidget);
      expect(find.byKey(const ValueKey('browserAddressField')), findsNothing);
      await tester.tap(
        find.descendant(
          of: find.byType(BrowserAddressBar),
          matching: find.text('Search or enter website'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('browserAddressField')),
        'flutter widgets',
      );
      await tester.testTextInput.receiveAction(TextInputAction.go);
      await tester.pumpAndSettle();
      expect(service.activeTab!.url, contains('q=flutter'));
      expect(service.activeTab!.ownerSessionId, 'chat-a');
      expect(find.byKey(const ValueKey('fakeNativeView')), findsOneWidget);
      expect(find.text('Kelivo'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  browserTestWidgets(
    'opening from a chat selects its owned tab instead of another chat',
    (tester) async {
      await service.initialize();
      final owned = await service.createTab(
        url: 'https://owned.example',
        ownerSessionId: 'chat-a',
      );
      await service.createTab(
        url: 'https://other.example',
        ownerSessionId: 'chat-b',
      );
      await mount(tester, conversationId: 'chat-a');
      expect(service.activeTabId, owned.id);
      expect(service.tabs, hasLength(2));
    },
  );

  for (final selectedOwner in ['chat-b', null]) {
    browserTestWidgets(
      'presentation handoff keeps the selected tab and engine (owner: $selectedOwner)',
      (tester) async {
        await service.initialize();
        final conversationTab = await service.createTab(
          ownerSessionId: 'chat-a',
        );
        final selected = await service.createTab(
          url: 'https://selected.example/kept-document',
          ownerSessionId: selectedOwner,
        );
        await mount(
          tester,
          conversationId: 'chat-a',
          embedded: true,
          size: const Size(1100, 800),
        );
        expect(service.activeTabId, conversationTab.id);
        await service.selectTab(selected.id);
        await tester.pumpAndSettle();
        final engine = engines[selected.id]!;
        engine.onChanged(const BrowserPageState(title: 'Existing document'));
        await tester.pumpAndSettle();
        final navigations = List<String>.of(engine.navigations);

        // Expansion transfers the selected tab rather than resolving chat A.
        await tester.pumpWidget(const SizedBox.shrink());
        await mount(
          tester,
          conversationId: 'chat-a',
          initialTabId: selected.id,
          size: const Size(1100, 800),
        );
        expect(service.activeTabId, selected.id);
        expect(service.activeTab!.url, selected.url);
        expect(service.activeTab!.title, 'Existing document');
        expect(engines[selected.id], same(engine));
        expect(engine.navigations, navigations);
        expect(find.byKey(const ValueKey('fakeNativeView')), findsOneWidget);
        expect(find.text('Kelivo'), findsNothing);

        // Docking must also honor the explicit handoff if global selection
        // changes while the outgoing route finishes detaching.
        await tester.pumpWidget(const SizedBox.shrink());
        await service.selectTab(conversationTab.id);
        await mount(
          tester,
          conversationId: 'chat-a',
          initialTabId: selected.id,
          embedded: true,
          size: const Size(1100, 800),
        );
        expect(service.activeTabId, selected.id);
        expect(service.activeTab!.title, 'Existing document');
        expect(service.activeTab!.ownerSessionId, selectedOwner);
        expect(engines[selected.id], same(engine));
        expect(engine.navigations, navigations);
        expect(service.tabs, hasLength(2));
        expect(
          () => service.requireAgentTab('chat-a', selected.id),
          throwsA(
            isA<StateError>().having(
              (error) => error.message,
              'message',
              'browser_tab_not_owned',
            ),
          ),
        );
        expect(service.requireAgentTab('chat-a', null).id, conversationTab.id);
        expect(tester.takeException(), isNull);
      },
    );
  }

  browserTestWidgets(
    'a stale presentation tab falls back to normal conversation routing',
    (tester) async {
      await service.initialize();
      final owned = await service.createTab(
        url: 'https://owned.example',
        ownerSessionId: 'chat-a',
      );
      final removed = await service.createTab(
        url: 'https://closed.example',
        ownerSessionId: 'chat-b',
      );
      await service.closeTab(removed.id);
      await service.createTab(
        url: 'https://other.example',
        ownerSessionId: 'chat-c',
      );
      await mount(tester, conversationId: 'chat-a', initialTabId: removed.id);
      expect(service.activeTabId, owned.id);
      expect(service.activeTab!.url, 'https://owned.example');
      expect(service.tabs, hasLength(2));
      expect(tester.takeException(), isNull);
    },
  );

  browserTestWidgets(
    'opening from a new chat shows a start page without allocating a tab',
    (tester) async {
      await service.initialize();
      await service.createTab(
        url: 'https://other.example',
        ownerSessionId: 'chat-b',
      );
      await mount(tester, conversationId: 'chat-a');
      expect(service.tabs, hasLength(1));
      expect(service.activeTab, isNull);
      expect(find.text('Kelivo'), findsOneWidget);
      expect(service.liveViewCount, 0);
    },
  );

  for (final move in [true, false]) {
    browserTestWidgets(
      'user can ${move ? "move" : "reopen"} a page in this chat',
      (tester) async {
        final other = await service.createTab(
          url: 'https://other.example',
          ownerSessionId: 'other',
        );
        await mount(tester, conversationId: 'chat-a', initialTabId: other.id);
        final originalEngine = engines[other.id];
        await openMobileMenuItem(
          tester,
          move ? 'Move to this chat' : 'Reopen in this chat',
        );
        expect(service.activeTab!.ownerSessionId, 'chat-a');
        expect(service.activeTab!.url, 'https://other.example');
        if (move) {
          expect(service.activeTabId, other.id);
          expect(service.tabs, hasLength(1));
          expect(engines[other.id], same(originalEngine));
        } else {
          expect(service.activeTabId, isNot(other.id));
          expect(service.requireTab(other.id).ownerSessionId, 'other');
          expect(service.tabs, hasLength(2));
        }
        expect(tester.takeException(), isNull);
      },
    );
  }

  browserTestWidgets(
    'personal tabs stay visible when opened from another chat',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      final personal = await service.createTab(url: 'https://personal.example');
      await service.createTab(ownerSessionId: 'chat-a');
      await mount(
        tester,
        conversationId: 'chat-a',
        initialTabId: personal.id,
        size: const Size(1200, 800),
      );
      final strip = tester.widget<BrowserTabStrip>(
        find.byType(BrowserTabStrip),
      );
      expect(strip.tabs.map((tab) => tab.id), [personal.id]);
      expect(strip.activeId, personal.id);
      expect(tester.takeException(), isNull);
    },
  );

  for (final ownedTabExists in [false, true]) {
    browserTestWidgets(
      'disposed browser does not change tabs after delayed initialization (owned: $ownedTabExists)',
      (tester) async {
        service.dispose();
        final ready = Completer<void>();
        final store = _MemoryStore(readGate: ready.future);
        store.state = {
          'activeTabId': 'other',
          'tabs': [
            const BrowserTab(
              id: 'other',
              url: 'https://other.example',
              ownerSessionId: 'other-chat',
            ).toJson(),
            if (ownedTabExists)
              const BrowserTab(
                id: 'owned',
                url: 'https://owned.example',
                ownerSessionId: 'chat-a',
              ).toJson(),
          ],
        };
        service = BrowserService(supported: true, store: store);
        await mount(
          tester,
          conversationId: 'chat-a',
          embedded: true,
          shortcutsEnabled: false,
          settle: false,
        );
        expect(service.isInitialized, isFalse);
        await tester.pumpWidget(const SizedBox.shrink());
        ready.complete();
        await tester.pumpAndSettle();
        expect(service.isInitialized, isTrue);
        expect(service.activeTabId, 'other');
        expect(
          service.tabs.map((tab) => tab.id),
          ownedTabExists ? ['other', 'owned'] : ['other'],
        );
        expect(service.liveViewCount, 0);
        expect(tester.takeException(), isNull);
      },
    );
  }

  browserTestWidgets(
    'eight old tabs do not block a new conversation or leak into its overview',
    (tester) async {
      await service.initialize();
      for (var index = 0; index < 8; index++) {
        await service.createTab(ownerSessionId: 'other-$index');
      }
      await mount(tester, conversationId: 'chat-a');
      expect(service.tabs, hasLength(8));
      expect(service.activeTab, isNull);
      await openMobileMenuItem(tester, 'Tabs (0)');
      expect(find.byKey(const ValueKey('browserTabScope')), findsOneWidget);
      expect(find.byTooltip('Close tab'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('browserTabScope')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('All tabs'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Close tab'), findsWidgets);
      await tester.tap(find.byTooltip('New tab'));
      await tester.pumpAndSettle();
      expect(service.tabs, hasLength(9));
      expect(service.activeTab!.ownerSessionId, 'chat-a');
      expect(tester.takeException(), isNull);
    },
  );

  browserTestWidgets('agent rendered HTML at about blank remains visible', (
    tester,
  ) async {
    await service.initialize();
    final tab = await service.createTab();
    await service.loadHtml('<h1>Rendered page</h1>', tabId: tab.id);
    await mount(tester);
    expect(service.activeTab!.url, 'about:blank');
    expect(find.byKey(const ValueKey('fakeNativeView')), findsOneWidget);
    expect(find.text('Kelivo'), findsNothing);
  });

  browserTestWidgets(
    'rendered blank documents expose find but no website-link actions',
    (tester) async {
      await service.initialize();
      final tab = await service.createTab();
      await service.loadHtml('<h1>Rendered page</h1>', tabId: tab.id);
      await mount(tester);
      await tester.tap(find.byTooltip('More').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Page options').last);
      await tester.pumpAndSettle();
      expect(find.text('Find on page'), findsOneWidget);
      expect(find.text('Add bookmark'), findsNothing);
      expect(find.text('Copy link'), findsNothing);
      expect(find.text('Open in default browser'), findsNothing);
    },
  );

  browserTestWidgets(
    'mobile find dock groups its controls above the keyboard on a dark webpage',
    (tester) async {
      await service.initialize();
      final tab = await service.createTab(url: 'https://dark.example');
      await mount(tester, size: const Size(320, 844));
      final viewport = find.byKey(const ValueKey('fakeNativeView'));
      expect(tester.widget<ColoredBox>(viewport).color, Colors.black);
      final viewportBounds = tester.getRect(viewport);
      await openMobileMenuItem(tester, 'Page options');
      await tester.tap(find.text('Find on page'));
      await tester.pumpAndSettle();
      final field = find.byKey(const ValueKey('browserFindField'));
      final surface = find.ancestor(
        of: field,
        matching: find.byType(BrowserGlass),
      );
      expect(surface, findsOneWidget);
      final surfaceBounds = tester.getRect(surface);
      final fieldBounds = tester.getRect(field);
      expect(surfaceBounds.contains(fieldBounds.topLeft), isTrue);
      expect(
        surfaceBounds.contains(fieldBounds.bottomRight - const Offset(.1, .1)),
        isTrue,
      );
      addTearDown(tester.view.resetViewInsets);
      final dock = find.byType(BrowserFindBar);
      final dockBounds = tester.getRect(dock);
      for (final label in ['Back', 'Forward', 'Done']) {
        final button = find.descendant(
          of: dock,
          matching: find.byTooltip(label),
        );
        expect(button, findsOneWidget);
        expect(dockBounds.contains(tester.getCenter(button)), isTrue);
      }
      expect(dockBounds.bottom, viewportBounds.bottom - 10);
      final navigation = find.byKey(
        const ValueKey('browserMobileNavigationGroup'),
      );
      expect(tester.widget<BrowserGlass>(navigation).opacity, 0);
      expect(tester.getRect(viewport), viewportBounds);
      expect(engines[tab.id]!.viewMounts, 1);
      expect(engines[tab.id]!.viewDisposals, 0);
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.pumpAndSettle();
      expect(tester.getRect(dock).bottom, viewportBounds.bottom - 310);
      tester.view.resetViewInsets();
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(of: dock, matching: find.byTooltip('Done')),
      );
      await tester.pumpAndSettle();
      expect(field, findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  browserTestWidgets('closing the final tab disables reload', (tester) async {
    await service.createTab();
    await mount(tester);
    await service.closeTab(service.activeTabId!);
    await tester.pumpAndSettle();
    final reload = tester.widget<BrowserActionButton>(
      find.byWidgetPredicate(
        (widget) => widget is BrowserActionButton && widget.label == 'Reload',
      ),
    );
    expect(reload.onPressed, isNull);
    expect(service.tabs, isEmpty);
    expect(tester.takeException(), isNull);
  });

  browserTestWidgets(
    'mobile management destinations are complete routes and Done restores the browser',
    (tester) async {
      await service.initialize();
      final tab = await service.createTab(url: 'https://example.com');
      await mount(tester);
      final engine = engines[tab.id]!;
      engine.onChanged(const BrowserPageState(canGoBack: true));
      await tester.pumpAndSettle();
      final viewport = find.byKey(
        const ValueKey('fakeNativeView'),
        skipOffstage: false,
      );
      final element = tester.element(viewport);
      final bounds = tester.getRect(viewport);
      for (final label in [
        'Bookmarks',
        'History',
        'Downloads',
        'Browser settings',
        'Tabs (1)',
      ]) {
        await openMobileMenuItem(tester, label);
        final page = find.byType(BrowserManagementPage);
        expect(page, findsOneWidget);
        expect(
          ModalRoute.of(tester.element(page)),
          label.startsWith('Tabs')
              ? isA<BrowserTabsRoute>()
              : isA<MaterialPageRoute<void>>(),
        );
        expect(BrowserGlassBackdrop.nativeOf(tester.element(page)), isFalse);
        expect(tester.getSize(page), const Size(390, 844));
        expect(find.byType(Dialog), findsNothing);
        expect(find.byType(CustomBottomSheet), findsNothing);
        expect(find.byKey(const ValueKey('browserPanel')), findsNothing);
        expect(find.byType(BrowserPage), findsNothing);
        expect(identical(tester.element(viewport), element), isTrue);
        if (label.startsWith('Tabs')) {
          expect(find.byType(BrowserTabOverview), findsOneWidget);
          expect(find.byTooltip('New tab'), findsOneWidget);
        }
        await tester.tap(
          find.byTooltip(label.startsWith('Tabs') ? 'Done' : 'Back'),
        );
        await tester.pumpAndSettle();
        expect(page, findsNothing);
        expect(find.byType(BrowserPage), findsOneWidget);
        expect(identical(tester.element(viewport), element), isTrue);
        expect(tester.getRect(viewport), bounds);
        expect(
          engine.backCalls,
          0,
        ); // Done pops the manager, never WebView history.
        expect(engine.viewMounts, 1);
        expect(engine.viewDisposals, 0);
      }
      expect(tester.takeException(), isNull);
    },
  );

  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    for (final reduced in [false, true]) {
      browserTestWidgets(
        'tab selection reveals retained toolbar gradually on $platform (reduced: $reduced)',
        (tester) async {
          debugDefaultTargetPlatformOverride = platform;
          await service.initialize();
          final tab = await service.createTab(url: 'https://toolbar.example');
          await mount(tester, reduceMotion: reduced);
          final navigation = find.byKey(
            const ValueKey('browserMobileNavigationGroup'),
            skipOffstage: false,
          );
          final original = tester.element(navigation);
          double opacity() => tester.widget<BrowserGlass>(navigation).opacity;
          expect(opacity(), 1);
          await openMobileMenuItem(tester, 'Tabs (1)');
          final tabsRoute = ModalRoute.of(
            tester.element(find.byType(BrowserTabOverview)),
          )!;
          var returnCompleted = false;
          unawaited(tabsRoute.completed.then((_) => returnCompleted = true));
          await tester.tap(find.byKey(ValueKey('browserTabCard-${tab.id}')));
          await tester.pump();
          if (!reduced) {
            // Hide before the flight uncovers the toolbar. Only the material's
            // own visibility changes; native hosts keep their identity.
            expect(opacity(), 0);
            await tester.pump(const Duration(milliseconds: 320));
            for (var frame = 0; frame < 8 && !returnCompleted; frame++) {
              await tester.pump(const Duration(milliseconds: 16));
            }
            expect(returnCompleted, isTrue);
            await tester.pump();
            await tester
                .pump(); // Start the reveal ticker after route disposal.
            expect(opacity(), 0);
            await tester.pump(const Duration(milliseconds: 80));
            expect(opacity(), inExclusiveRange(0.0, 1.0));
          }
          await tester.pumpAndSettle();
          expect(opacity(), 1);
          expect(tester.element(navigation), same(original));
          expect(find.byType(BrowserTabOverview), findsNothing);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  for (final (completion, reducedMotion) in [
    ('ready', false),
    ('error', false),
    ('attachment failure', false),
    ('other tab', false),
    ('dispose', false),
    ('ready', true),
    ('error', true),
  ]) {
    browserTestWidgets(
      'tab return cover survives route completion until $completion (reduced motion: $reducedMotion)',
      (tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
        tester.view.viewPadding = const FakeViewPadding(top: 59, bottom: 34);
        addTearDown(tester.view.resetViewPadding);
        await service.initialize();
        final original = await service.createTab(
          url: 'https://original.example',
        );
        final destination = await service.createTab(
          url: 'https://destination.example',
        );
        await mount(tester, reduceMotion: reducedMotion);
        final engine = engines[destination.id]!;
        engine.previewBytes = await previewFixture(tester);
        await service.refreshActivePreview();
        await tester.pumpAndSettle();
        expect(service.isTabPresented(destination.id), isTrue);
        expect(service.previewForTab(destination.id), isNotNull);
        // Decoding is real engine work, outside testWidgets' FakeAsync zone.
        // Await its first frame rather than hoping pumpAndSettle drives IO.
        await tester.runAsync(
          () => precacheImage(
            MemoryImage(service.previewForTab(destination.id)!),
            tester.element(find.byType(BrowserPage)),
          ),
        );
        final navigationCount = engine.navigations.length;
        await service.selectTab(original.id);
        await tester.pumpAndSettle();
        expect(service.isTabPresented(destination.id), isFalse);
        final ready = Completer<void>();
        engine.attachmentReady = ready;
        try {
          await openMobileMenuItem(tester, 'Tabs (2)');
          final overview = find.byType(BrowserTabOverview);
          final flightViewport = tester.getRect(
            find.byType(BrowserManagementPage),
          );
          final route = ModalRoute.of(tester.element(overview))!;
          var routeCompleted = false;
          unawaited(route.completed.then((_) => routeCompleted = true));
          await tester.tap(
            find.byKey(ValueKey('browserTabCard-${destination.id}')),
          );
          await tester.pumpAndSettle();
          expect(routeCompleted, isTrue);
          expect(overview, findsNothing);
          expect(service.activeTabId, destination.id);
          expect(service.isTabPresented(destination.id), isFalse);
          final cover = find.byWidgetPredicate(
            (widget) =>
                widget is AnimatedOpacity &&
                widget.key.toString().contains('browserTabReturnCover-'),
          );
          expect(cover, findsOneWidget);
          expect(tester.getRect(cover), flightViewport);
          expect(tester.widget<AnimatedOpacity>(cover).opacity, 1);
          await tester.pump(const Duration(milliseconds: 500));
          expect(cover, findsOneWidget);
          expect(tester.getRect(cover), flightViewport);
          expect(tester.widget<AnimatedOpacity>(cover).opacity, 1);
          switch (completion) {
            case 'ready':
              ready.complete();
              await tester.pumpAndSettle();
              expect(service.isTabPresented(destination.id), isTrue);
              expect(cover, findsNothing);
              expect(engine.navigations.length, navigationCount);
              expect(engine.viewMounts, 1);
              expect(engine.viewDisposals, 0);
            case 'error':
              engine.onChanged(const BrowserPageState(error: 'Load failed'));
              await tester.pumpAndSettle();
              expect(cover, findsNothing);
              expect(find.text('Load failed'), findsOneWidget);
            case 'attachment failure':
              ready.completeError(StateError('Attachment unavailable'));
              await tester.pumpAndSettle();
              expect(service.isTabPresented(destination.id), isTrue);
              expect(cover, findsNothing);
              expect(
                find.textContaining('Attachment unavailable'),
                findsOneWidget,
              );
              expect(
                find.byKey(
                  ValueKey('browserAttachmentPreview-${destination.id}'),
                ),
                findsNothing,
              );
            case 'other tab':
              await service.selectTab(original.id);
              await tester.pumpAndSettle();
              expect(cover, findsNothing);
              ready.complete();
              await tester.pumpAndSettle();
              expect(cover, findsNothing);
              expect(service.activeTabId, original.id);
              expect(service.isTabPresented(destination.id), isFalse);
            case 'dispose':
              await tester.pumpWidget(const SizedBox.shrink());
              ready.complete();
              await tester.pumpAndSettle();
              expect(service.isTabPresented(destination.id), isFalse);
          }
          expect(tester.takeException(), isNull);
        } finally {
          if (!ready.isCompleted) ready.complete();
        }
      },
    );
  }

  for (final replaceWhilePending in [false, true]) {
    browserTestWidgets(
      'tab overview waits for cached pixels and freezes that image (replacement: $replaceWhilePending)',
      (tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
        await service.initialize();
        final tab = await service.createTab(url: 'https://preview.example');
        await mount(tester);
        final engine = engines[tab.id]!;
        final capturedBytes = await previewFixture(tester);
        engine.previewBytes = capturedBytes;
        final image = (await tester.runAsync(
          () => createTestImage(width: 8, height: 8, cache: false),
        ))!;
        final decoded = Completer<ImageInfo>();
        final provider = MemoryImage(capturedBytes);
        final cache = PaintingBinding.instance.imageCache;
        // Reserve the exact provider key used by attachment, card and precache.
        // This future models a decoder that has not emitted its first frame yet.
        cache.putIfAbsent(
          provider,
          () => OneFrameImageStreamCompleter(decoded.future),
        );
        try {
          await service.refreshActivePreview();
          await tester.pumpAndSettle();
          expect(cache.statusForKey(provider).pending, isTrue);
          await openMobileMenuItem(tester, 'Tabs (1)');
          expect(find.byType(BrowserTabOverview), findsNothing);
          expect(find.byType(BrowserTransitionSnapshot), findsNothing);
          expect(cache.statusForKey(provider).pending, isTrue);
          if (replaceWhilePending) {
            engine.previewBytes = await previewFixture(tester, width: 9);
            expect(listEquals(capturedBytes, engine.previewBytes), isFalse);
            await service.refreshActivePreview();
            await tester.pump();
            expect(service.previewForTab(tab.id), same(engine.previewBytes));
            expect(service.previewForTab(tab.id), isNot(same(capturedBytes)));
            expect(find.byType(BrowserTabOverview), findsNothing);
          }
          decoded.complete(ImageInfo(image: image.clone()));
          await tester.pumpAndSettle();
          final overview = find.byType(BrowserTabOverview);
          expect(overview, findsOneWidget);
          final route =
              ModalRoute.of(tester.element(overview))! as BrowserTabsRoute;
          expect(route.transition.previewForTab(tab.id), same(capturedBytes));
          expect(route.transition.previewBytes, same(capturedBytes));
          final card = find.byKey(ValueKey('browserTabCard-${tab.id}'));
          final pixels = find.descendant(
            of: card,
            matching: find.byType(RawImage),
          );
          expect(pixels, findsOneWidget);
          expect(
            tester.widget<RawImage>(pixels).image!.isCloneOf(image),
            isTrue,
          );
          // The return flight also consumes the warmed route snapshot, even
          // when the service has already published a newer uncached thumbnail.
          await tester.tap(find.byTooltip('Done'));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 16));
          final flight = find.byKey(const ValueKey('browserTabSnapshotFlight'));
          expect(flight, findsOneWidget);
          final flightPixels = find.descendant(
            of: flight,
            matching: find.byType(RawImage),
          );
          expect(
            tester.widget<RawImage>(flightPixels).image!.isCloneOf(image),
            isTrue,
          );
          final snapshot = find.descendant(
            of: find.byType(BrowserTransitionSnapshot),
            matching: find.byType(SnapshotWidget),
          );
          expect(
            tester
                .widget<SnapshotWidget>(snapshot)
                .controller
                .allowSnapshotting,
            isTrue,
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        } finally {
          if (!decoded.isCompleted) {
            decoded.complete(ImageInfo(image: image.clone()));
          }
          await tester.pumpWidget(const SizedBox.shrink());
          cache.evict(provider);
          image.dispose();
          await tester.pumpAndSettle();
        }
      },
    );
  }

  browserTestWidgets(
    'start page tab flight keeps its Flutter backdrop outside the route builder',
    (tester) async {
      await service.createTab();
      await mount(tester);
      await tester.tap(find.byTooltip('More').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tabs (1)'));
      await tester.pump();
      // The menu completes its own dismissal before pushing the tab route.
      for (
        var i = 0;
        i < 20 && find.byType(BrowserManagementPage).evaluate().isEmpty;
        i++
      ) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      await tester.pump(const Duration(milliseconds: 16));
      final flight = find.byKey(const ValueKey('browserTabSnapshotFlight'));
      expect(flight, findsOneWidget);
      expect(
        find.descendant(of: flight, matching: find.byType(BrowserStartPage)),
        findsNothing,
      );
      expect(
        find.descendant(of: flight, matching: find.byType(BrowserGlass)),
        findsNothing,
      );
      expect(
        find.descendant(of: flight, matching: find.byType(RawImage)),
        findsOneWidget,
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  browserTestWidgets(
    'full page keeps an explicit dock action even with history and narrow width',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      await service.initialize();
      final tab = await service.createTab(url: 'https://example.com');
      var docks = 0;
      for (final width in [1200.0, 520.0]) {
        await mount(tester, size: Size(width, 800), onDock: () => docks++);
        engines[tab.id]!.onChanged(const BrowserPageState(canGoBack: true));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Open in sidebar'));
        await tester.pumpAndSettle();
        expect(engines[tab.id]!.backCalls, 0);
      }
      expect(docks, 2);
      expect(tester.takeException(), isNull);
    },
  );

  browserTestWidgets(
    'address keyboard preserves viewport through dismiss and yields to webpage input',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      tester.view.viewPadding = const FakeViewPadding(top: 59, bottom: 34);
      addTearDown(tester.view.resetViewPadding);
      addTearDown(tester.view.resetViewInsets);
      await service.initialize();
      final tab = await service.createTab(url: 'https://example.com');
      await mount(tester);
      final viewport = find.byKey(const ValueKey('fakeNativeView'));
      final before = tester.getRect(viewport);
      final state = tester.state(find.byType(_EngineView));
      final navigationMaterial = find.byKey(
        const ValueKey('browserMobileNavigationGroup'),
      );
      final materialState = tester.state(navigationMaterial);
      final address = tester.widget<BrowserAddressBar>(
        find.byType(BrowserAddressBar),
      );
      await tester.tap(find.byType(BrowserAddressBar));
      await tester.pumpAndSettle();
      expect(address.focusNode.hasFocus, isTrue);
      expect(tester.state(navigationMaterial), same(materialState));
      expect(tester.widget<BrowserGlass>(navigationMaterial).opacity, 0);
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.pumpAndSettle();
      expect(tester.getRect(viewport), before);
      expect(
        tester.getRect(find.byType(BrowserAddressBar)).bottom,
        lessThan(544),
      );
      address.focusNode.unfocus();
      await tester.pumpAndSettle();
      expect(tester.getRect(viewport), before);
      tester.view.viewInsets = const FakeViewPadding();
      await tester.pumpAndSettle();
      expect(tester.getRect(viewport), before);
      expect(tester.state(navigationMaterial), same(materialState));
      expect(tester.widget<BrowserGlass>(navigationMaterial).opacity, 1);
      await tester.tapAt(tester.getCenter(viewport));
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.pumpAndSettle();
      expect(tester.getRect(viewport).height, before.height - 300);
      expect(tester.state(find.byType(_EngineView)), same(state));
      expect(engines[tab.id]!.viewMounts, 1);
      expect(tester.takeException(), isNull);
    },
  );

  browserTestWidgets(
    'tap outside URL input preserves page bounds for every keyboard dismissal frame',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      tester.view.viewPadding = const FakeViewPadding(top: 59, bottom: 34);
      addTearDown(tester.view.resetViewPadding);
      addTearDown(tester.view.resetViewInsets);
      await service.initialize();
      final tab = await service.createTab(url: 'https://example.com');
      await mount(tester);
      final viewport = find.byKey(const ValueKey('fakeNativeView'));
      final before = tester.getRect(viewport);
      final state = tester.state(find.byType(_EngineView));
      await tester.tap(find.byType(BrowserAddressBar));
      await tester.pumpAndSettle();
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.pump();

      // This is the real dismissal path in the phone recording. Directly
      // unfocusing the field misses the webpage Listener's pointer-down path.
      await tester.tapAt(tester.getCenter(viewport));
      await tester.pump();
      expect(
        tester
            .widget<BrowserAddressBar>(find.byType(BrowserAddressBar))
            .focusNode
            .hasFocus,
        isFalse,
      );
      for (final inset in [300.0, 200.0, 120.0, 34.0, 1.0, 0.0]) {
        tester.view.viewInsets = FakeViewPadding(bottom: inset);
        await tester.pump();
        expect(
          tester.getRect(viewport),
          before,
          reason: 'The webpage must not reflow at inset $inset',
        );
        expect(tester.state(find.byType(_EngineView)), same(state));
      }
      expect(engines[tab.id]!.viewMounts, 1);

      // Ownership ends with that keyboard, so a later native webpage field
      // still receives normal viewport avoidance without an extra page tap.
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.pump();
      expect(tester.getRect(viewport).height, before.height - 300);
      expect(tester.takeException(), isNull);
    },
  );

  browserTestWidgets(
    'address keyboard dismissal never drops the dock into the home indicator',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      tester.view.viewPadding = const FakeViewPadding(top: 59, bottom: 34);
      addTearDown(tester.view.resetViewPadding);
      addTearDown(tester.view.resetViewInsets);
      await service.initialize();
      final tab = await service.createTab(url: 'https://example.com');
      await mount(tester);
      final viewport = find.byKey(const ValueKey('fakeNativeView'));
      final before = tester.getRect(viewport);
      final state = tester.state(find.byType(_EngineView));
      await tester.tap(find.byType(BrowserAddressBar));
      await tester.pumpAndSettle();
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.pump();
      tester
          .widget<BrowserAddressBar>(find.byType(BrowserAddressBar))
          .focusNode
          .unfocus();
      for (final inset in [300.0, 120.0, 34.0, 20.0, 1.0, 0.0]) {
        tester.view.viewInsets = FakeViewPadding(bottom: inset);
        await tester.pump();
        final bottom = tester.getRect(find.byType(BrowserAddressBar)).bottom;
        final lowerBoundary = 844 - (inset > 34 ? inset : 34);
        expect(
          bottom,
          closeTo(lowerBoundary - 10, .001),
          reason: 'The $inset inset frame must stop above the safe area',
        );
        expect(tester.getRect(viewport), before);
        expect(tester.state(find.byType(_EngineView)), same(state));
      }
      expect(engines[tab.id]!.viewMounts, 1);
      expect(tester.takeException(), isNull);
    },
  );

  browserTestWidgets(
    'native form keyboard expands collapsed chrome and keeps stable dismissal geometry',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      tester.view.viewPadding = const FakeViewPadding(top: 59, bottom: 34);
      addTearDown(tester.view.resetViewPadding);
      addTearDown(tester.view.resetViewInsets);
      await service.initialize();
      final tab = await service.createTab(url: 'https://example.com');
      await mount(tester);
      final engine = engines[tab.id]!;
      final viewport = find.byKey(const ValueKey('fakeNativeView'));
      final before = tester.getRect(viewport);
      final state = tester.state(find.byType(_EngineView));
      engine.onChanged(_scroll(100));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<BrowserAddressBar>(find.byType(BrowserAddressBar))
            .collapseProgress,
        1,
      );
      // Native webpage fields do not focus Flutter's address field.
      expect(
        tester
            .widget<BrowserAddressBar>(find.byType(BrowserAddressBar))
            .focusNode
            .hasFocus,
        isFalse,
      );
      for (final inset in [300.0, 120.0, 34.0, 20.0, 1.0, 0.0]) {
        tester.view.viewInsets = FakeViewPadding(bottom: inset);
        await tester.pump();
        final bar = tester.widget<BrowserAddressBar>(
          find.byType(BrowserAddressBar),
        );
        expect(bar.collapseProgress, 0);
        final lowerBoundary = 844 - (inset > 34 ? inset : 34);
        expect(
          tester.getRect(find.byType(BrowserAddressBar)).bottom,
          closeTo(lowerBoundary - 10, .001),
        );
        expect(tester.getRect(viewport).height, before.height - inset);
        expect(tester.state(find.byType(_EngineView)), same(state));
        if (inset > 0) {
          engine.onChanged(_scroll(400 + inset));
          await tester.pump();
          expect(
            tester
                .widget<BrowserAddressBar>(find.byType(BrowserAddressBar))
                .collapseProgress,
            0,
          );
        }
      }
      expect(engine.viewMounts, 1);
      expect(tester.takeException(), isNull);
    },
  );

  browserTestWidgets('start wallpaper reaches beneath the status bar', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    tester.view.viewPadding = const FakeViewPadding(top: 59, bottom: 34);
    addTearDown(tester.view.resetViewPadding);
    await mount(tester);
    expect(tester.getRect(find.byType(BrowserStartPage)).top, 0);
    expect(tester.getRect(find.byType(BrowserStartPage)).bottom, 844);
    expect(tester.takeException(), isNull);
  });

  browserTestWidgets(
    'embedded browser isolates inactive shortcuts and delegates close and expand',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      const channel = MethodChannel('app.browser_window');
      final calls = <MethodCall>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
        call,
      ) async {
        calls.add(call);
        return null;
      });
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          null,
        ),
      );
      Future<void> nativeShortcut(String key) {
        final done = Completer<void>();
        tester.binding.channelBuffers.push(
          channel.name,
          channel.codec.encodeMethodCall(MethodCall('shortcut', key)),
          (_) => done.complete(),
        );
        return done.future;
      }

      Future<void> keyboardReload() async {
        await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.keyR);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
        await tester.pumpAndSettle();
      }

      await service.initialize();
      final tab = await service.createTab(url: 'https://example.com');
      var closes = 0;
      var expands = 0;
      Future<void> show({required bool shortcuts}) => mount(
        tester,
        size: const Size(560, 800),
        embedded: true,
        shortcutsEnabled: shortcuts,
        onClose: () => closes++,
        onExpand: () => expands++,
      );
      await show(shortcuts: false);
      final engine = engines[tab.id]!;
      final pageState = tester.state(find.byType(BrowserPage));
      final window = tester.widget<BrowserWindowChrome>(
        find.byType(BrowserWindowChrome),
      );
      expect(window.windowSpacing, isFalse);
      expect(window.shortcutsEnabled, isFalse);
      expect(
        tester
            .widget<BrowserDesktopLayout>(find.byType(BrowserDesktopLayout))
            .embedded,
        isTrue,
      );
      expect(tester.getRect(find.byType(BrowserTabStrip)).left, 0);
      expect(find.byTooltip('Close browser'), findsNothing);
      await nativeShortcut('r');
      await nativeShortcut('t');
      await nativeShortcut('f');
      await keyboardReload();
      expect(engine.reloadCalls, 0);
      expect(service.tabs, hasLength(1));
      expect(find.byKey(const ValueKey('browserFindField')), findsNothing);
      expect(
        calls.any(
          (call) => call.method == 'setBrowserChrome' && call.arguments == true,
        ),
        isFalse,
      );
      await tester.tap(find.byTooltip('Open in full page'));
      await tester.pumpAndSettle();
      expect(expands, 1);
      await tester.tap(find.byTooltip('Close browser panel'));
      await tester.pumpAndSettle();
      expect(closes, 1);
      expect(find.byType(BrowserPage), findsOneWidget);
      await show(shortcuts: true);
      expect(
        identical(tester.state(find.byType(BrowserPage)), pageState),
        isTrue,
      );
      await nativeShortcut('r');
      await keyboardReload();
      expect(engine.reloadCalls, 2);
      expect(engine.viewMounts, 1);
      expect(tester.takeException(), isNull);
    },
  );

  browserTestWidgets(
    'desktop overview replaces only content and returns to the same mounted viewport',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      await service.initialize();
      final tab = await service.createTab(url: 'https://example.com');
      await mount(tester, size: const Size(1200, 800));
      final engine = engines[tab.id]!;
      final nativeView = find.byType(_EngineView, skipOffstage: false);
      final viewport = find.byKey(
        const ValueKey('fakeNativeView'),
        skipOffstage: false,
      );
      final nativeState = tester.state(nativeView);
      final viewportElement = tester.element(viewport);
      final viewportBounds = tester.getRect(viewport);
      final header = find.byKey(const ValueKey('browserDesktopHeader'));
      final headerBounds = tester.getRect(header);
      final route = ModalRoute.of(tester.element(find.byType(BrowserPage)));
      for (final useTopTab in [false, true]) {
        await tester.tap(find.byTooltip('Tabs'));
        await tester.pumpAndSettle();
        final overview = find.byType(BrowserTabOverview);
        expect(overview, findsOneWidget);
        expect(find.byKey(const ValueKey('browserPanel')), findsNothing);
        expect(find.byType(Dialog), findsNothing);
        expect(
          identical(ModalRoute.of(tester.element(overview)), route),
          isTrue,
        );
        expect(
          ModalRoute.of(tester.element(overview)),
          isNot(isA<PopupRoute<void>>()),
        );
        expect(tester.getRect(header), headerBounds);
        expect(tester.getSize(overview).width, 1200);
        expect(Visibility.of(tester.element(viewport)), isFalse);
        expect(viewport.hitTestable(), findsNothing);
        expect(identical(tester.state(nativeView), nativeState), isTrue);
        expect(identical(tester.element(viewport), viewportElement), isTrue);
        expect(engine.viewMounts, 1);
        expect(engine.viewDisposals, 0);
        await tester.tap(
          find.byKey(
            ValueKey(
              useTopTab
                  ? 'browserDesktopTab-${tab.id}'
                  : 'browserTabCard-${tab.id}',
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(overview, findsNothing);
        expect(Visibility.of(tester.element(viewport)), isTrue);
        expect(viewport.hitTestable(), findsOneWidget);
        expect(identical(tester.state(nativeView), nativeState), isTrue);
        expect(identical(tester.element(viewport), viewportElement), isTrue);
        expect(tester.getRect(viewport), viewportBounds);
        expect(engine.viewMounts, 1);
        expect(engine.viewDisposals, 0);
      }
      expect(tester.takeException(), isNull);
    },
  );

  browserTestWidgets(
    'desktop overview new card and address actions return to browser editing',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      await service.initialize();
      final original = await service.createTab(url: 'https://example.com');
      await mount(tester, size: const Size(1200, 800));
      final overview = find.byType(BrowserTabOverview);
      final address = find.byType(BrowserAddressBar);
      final field = find.byKey(const ValueKey('browserAddressField'));
      await tester.tap(find.byTooltip('Tabs'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('browserNewTabCard')));
      await tester.pumpAndSettle();
      expect(overview, findsNothing);
      expect(service.tabs, hasLength(2));
      final createdId = service.activeTabId!;
      expect(createdId, isNot(original.id));
      expect(service.activeTab!.url, 'about:blank');
      expect(
        tester.widget<BrowserAddressBar>(address).focusNode.hasFocus,
        isTrue,
      );
      expect(field, findsOneWidget);
      await tester.enterText(field, 'https://created.example');
      await tester.testTextInput.receiveAction(TextInputAction.go);
      await tester.pumpAndSettle();
      expect(service.activeTab!.url, 'https://created.example');
      final createdEngine = engines[createdId]!;
      final createdView = find.byWidgetPredicate(
        (widget) => widget is _EngineView && widget.engine == createdEngine,
      );
      final nativeState = tester.state(createdView);

      await tester.tap(find.byTooltip('Tabs'));
      await tester.pumpAndSettle();
      expect(overview, findsOneWidget);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyL);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
      await tester.pumpAndSettle();
      expect(overview, findsNothing);
      expect(
        tester.widget<BrowserAddressBar>(address).focusNode.hasFocus,
        isTrue,
      );
      expect(
        tester.widget<BrowserTextField>(field).controller.text,
        'https://created.example',
      );
      expect(identical(tester.state(createdView), nativeState), isTrue);

      await tester.tap(find.byTooltip('Tabs'));
      await tester.pumpAndSettle();
      expect(overview, findsOneWidget);
      // Address navigation can also originate from paste-and-go or another
      // toolbar callback while the overview has focus.
      tester
          .widget<BrowserAddressBar>(address)
          .onSubmitted('https://changed.example');
      await tester.pumpAndSettle();
      expect(overview, findsNothing);
      expect(service.activeTab!.url, 'https://changed.example');
      expect(service.activeTabId, createdId);
      expect(identical(tester.state(createdView), nativeState), isTrue);
      await tester.tap(find.byTooltip('Tabs'));
      await tester.pumpAndSettle();
      expect(overview, findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(overview, findsNothing);
      expect(Visibility.of(tester.element(createdView)), isTrue);
      await tester.tap(find.byTooltip('Tabs'));
      await tester.pumpAndSettle();
      expect(overview, findsOneWidget);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
      await tester.pumpAndSettle();
      expect(overview, findsNothing);
      expect(find.byKey(const ValueKey('browserFindField')), findsOneWidget);
      expect(Visibility.of(tester.element(createdView)), isTrue);
      expect(identical(tester.state(createdView), nativeState), isTrue);
      expect(createdEngine.viewMounts, 1);
      expect(createdEngine.viewDisposals, 0);
      expect(tester.takeException(), isNull);
    },
  );

  browserTestWidgets(
    'macOS native shortcuts share browser actions and find retains its query',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      const channel = MethodChannel('app.browser_window');
      Future<void> shortcut(String key) {
        final done = Completer<void>();
        tester.binding.channelBuffers.push(
          channel.name,
          channel.codec.encodeMethodCall(MethodCall('shortcut', key)),
          (_) => done.complete(),
        );
        return done.future;
      }

      await service.initialize();
      final tab = await service.createTab(url: 'https://example.com');
      await mount(tester, size: const Size(1100, 800));
      await shortcut('f');
      await tester.pumpAndSettle();
      final field = find.byKey(const ValueKey('browserFindField'));
      final input = field;
      expect(field, findsOneWidget);
      await tester.enterText(input, 'kept query');
      await shortcut('l');
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<BrowserAddressBar>(find.byType(BrowserAddressBar))
            .focusNode
            .hasFocus,
        isTrue,
      );
      await shortcut('f');
      await tester.pumpAndSettle();
      expect(field, findsOneWidget);
      final findInput = tester.widget<BrowserTextField>(input);
      expect(findInput.controller.text, 'kept query');
      expect(findInput.focusNode!.hasFocus, isTrue);

      await shortcut('r');
      await tester.pumpAndSettle();
      expect(engines[tab.id]!.reloadCalls, 1);
      await shortcut('t');
      await tester.pumpAndSettle();
      expect(service.tabs.length, 2);
      expect(service.activeTabId, isNot(tab.id));
      await shortcut('w');
      await tester.pumpAndSettle();
      expect(service.tabs.length, 1);
      expect(service.activeTabId, tab.id);
      expect(tester.takeException(), isNull);
    },
  );

  browserTestWidgets(
    'observing absorbs page input and only explicit takeover interrupts the agent',
    (tester) async {
      await service.initialize();
      await service.updateSettings(
        service.settings.copyWith(agentEnabled: true),
      );
      final tab = await service.createTab(
        url: 'https://example.com',
        ownerSessionId: 'chat-a',
      );
      await mount(tester, conversationId: 'chat-a');
      final pending = Completer<void>();
      final action = service.runAgentAction<void>(
        sessionId: 'chat-a',
        tabId: tab.id,
        label: 'click',
        action: () => pending.future,
      );
      final outcome = action.then<Object?>(
        (_) => null,
        onError: (Object error) => error,
      );
      try {
        await tester.pumpAndSettle();
        expect(find.text('AI is working'), findsOneWidget);
        final page = find.byKey(const ValueKey('fakeNativeView'));
        final mounts = engines[tab.id]!.viewMounts;
        await tester.tapAt(tester.getCenter(page));
        await tester.dragFrom(tester.getCenter(page), const Offset(0, -90));
        await tester.tap(find.text('AI is working'));
        await tester.pumpAndSettle();
        expect(service.agentPaused, isFalse);
        expect(engines[tab.id]!.humanPointerDowns, 0);
        expect(engines[tab.id]!.viewMounts, mounts);
        await tester.tap(find.text('Take over'));
        await tester.pumpAndSettle();
        expect(service.agentPaused, isTrue);
        expect(find.text('AI actions paused'), findsOneWidget);
        pending.complete();
        expect(await outcome, isA<StateError>());
        await tester.pumpAndSettle();
      } finally {
        if (!pending.isCompleted) pending.complete();
      }
    },
  );

  browserTestWidgets(
    'explicit takeover targets the agent owning the visible tab after switching chats',
    (tester) async {
      await service.initialize();
      await service.updateSettings(
        service.settings.copyWith(agentEnabled: true),
      );
      await service.createTab(
        url: 'https://a.example',
        ownerSessionId: 'chat-a',
      );
      final other = await service.createTab(
        url: 'https://b.example',
        ownerSessionId: 'chat-b',
      );
      await mount(tester, conversationId: 'chat-a');
      await service.selectTab(other.id);
      final pending = Completer<void>();
      final action = service.runAgentAction<void>(
        sessionId: 'chat-b',
        tabId: other.id,
        label: 'click',
        action: () => pending.future,
      );
      final outcome = action.then<Object?>(
        (_) => null,
        onError: (Object error) => error,
      );
      try {
        await tester.pumpAndSettle();
        expect(find.text('AI is working'), findsOneWidget);
        await tester.tap(find.text('Take over'));
        await tester.pumpAndSettle();
        expect(service.pausedAgentSessionId, 'chat-b');
        expect(find.text('AI actions paused'), findsOneWidget);
        pending.complete();
        expect(await outcome, isA<StateError>());
      } finally {
        if (!pending.isCompleted) pending.complete();
      }
    },
  );

  browserTestWidgets(
    'opening browser chrome observes; submitting a URL takes over',
    (tester) async {
      await service.initialize();
      final tab = await service.createTab(
        url: 'https://example.com',
        ownerSessionId: 'chat-a',
      );
      await mount(tester, conversationId: 'chat-a');
      final pending = Completer<void>();
      final outcome = service
          .runAgentAction<void>(
            sessionId: 'chat-a',
            tabId: tab.id,
            label: 'extract',
            action: () => pending.future,
          )
          .then<Object?>((_) => null, onError: (Object e) => e);
      try {
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('More').last);
        await tester.pumpAndSettle();
        expect(service.agentPaused, isFalse);
        await tester.tapAt(const Offset(8, 80));
        await tester.pumpAndSettle();
        final address = tester.widget<BrowserAddressBar>(
          find.byType(BrowserAddressBar),
        );
        address.onEdit!();
        await tester.pumpAndSettle();
        expect(service.agentPaused, isFalse);
        address.onSubmitted('https://next.example');
        await tester.pumpAndSettle();
        expect(service.agentPaused, isTrue);
        expect(service.activeTab!.url, 'https://next.example');
        pending.complete();
        expect(await outcome, isA<StateError>());
      } finally {
        if (!pending.isCompleted) pending.complete();
      }
    },
  );

  for (final platform in [
    TargetPlatform.iOS,
    TargetPlatform.android,
    TargetPlatform.macOS,
    TargetPlatform.windows,
    TargetPlatform.linux,
  ]) {
    for (final brightness in Brightness.values) {
      browserTestWidgets(
        'browser inherits app colors on $platform / $brightness',
        (tester) async {
          debugDefaultTargetPlatformOverride = platform;
          final colors = ColorScheme.fromSeed(
            seedColor: const Color(0xff9b6234),
            brightness: brightness,
          );
          final desktop = [
            TargetPlatform.macOS,
            TargetPlatform.windows,
            TargetPlatform.linux,
          ].contains(platform);
          await mount(
            tester,
            theme: ThemeData(colorScheme: colors),
            size: desktop ? const Size(1100, 800) : const Size(390, 844),
            embedded: desktop,
            shortcutsEnabled: false,
          );
          final address = find.byType(BrowserAddressBar);
          final actual = Theme.of(tester.element(address)).colorScheme;
          expect(actual.primary, colors.primary);
          expect(actual.surface, colors.surface);
          expect(actual.onSurface, colors.onSurface);
          if (desktop) {
            final header = find.byKey(const ValueKey('browserDesktopHeader'));
            final cover = tester.widget<DecoratedBox>(
              find
                  .descendant(
                    of: header,
                    matching: find.byKey(
                      const ValueKey('browserMaterialCover'),
                    ),
                  )
                  .first,
            );
            expect((cover.decoration as BoxDecoration).color, colors.surface);
          }
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  browserTestWidgets(
    'settings and tab overview stay observational and completion releases input',
    (tester) async {
      await service.initialize();
      final tab = await service.createTab(
        url: 'https://example.com',
        ownerSessionId: 'chat-a',
      );
      await mount(tester, conversationId: 'chat-a');
      final pending = Completer<void>();
      final action = service.runAgentAction<void>(
        sessionId: 'chat-a',
        tabId: tab.id,
        label: 'extract',
        action: () => pending.future,
      );
      try {
        await tester.pumpAndSettle();
        await openMobileMenuItem(tester, 'Browser settings');
        expect(service.agentPaused, isFalse);
        Navigator.of(tester.element(find.byType(BrowserSettingsPanel))).pop();
        await tester.pumpAndSettle();
        await openMobileMenuItem(tester, 'Tabs (1)');
        expect(service.agentPaused, isFalse);
        await tester.tap(find.byTooltip('Done').last);
        await tester.pumpAndSettle();
        pending.complete();
        await action;
        await tester.pumpAndSettle();
        expect(find.text('AI is working'), findsNothing);
        expect(
          tester
              .widget<AbsorbPointer>(
                find.byKey(const ValueKey('browserObserverInputShield')),
              )
              .absorbing,
          isFalse,
        );
        await tester.tapAt(
          tester.getCenter(find.byKey(const ValueKey('fakeNativeView'))),
        );
        expect(engines[tab.id]!.humanPointerDowns, 1);
      } finally {
        if (!pending.isCompleted) pending.complete();
      }
    },
  );

  for (final platform in [
    TargetPlatform.macOS,
    TargetPlatform.windows,
    TargetPlatform.linux,
  ]) {
    browserTestWidgets(
      'desktop tab overview remains observational on $platform',
      (tester) async {
        debugDefaultTargetPlatformOverride = platform;
        final tab = await service.createTab(
          url: 'https://example.com',
          ownerSessionId: 'chat-a',
        );
        await mount(
          tester,
          conversationId: 'chat-a',
          size: const Size(1100, 800),
          embedded: true,
        );
        final pending = Completer<void>();
        final outcome = service
            .runAgentAction<void>(
              sessionId: 'chat-a',
              tabId: tab.id,
              label: 'extract',
              action: () => pending.future,
            )
            .then<Object?>((_) => null, onError: (Object error) => error);
        try {
          await tester.pumpAndSettle();
          final mounts = engines[tab.id]!.viewMounts;
          await tester.tap(find.byTooltip('All tabs'));
          await tester.pumpAndSettle();
          expect(find.byType(BrowserTabOverview), findsOneWidget);
          expect(service.agentPaused, isFalse);
          await tester.tap(find.byTooltip('All tabs'));
          await tester.pumpAndSettle();
          expect(find.byType(BrowserTabOverview), findsNothing);
          expect(service.agentPaused, isFalse);
          await tester.tap(find.byTooltip('More').last);
          await tester.pumpAndSettle();
          await tester.tap(find.text('Tabs (1)'));
          await tester.pumpAndSettle();
          expect(find.byType(BrowserTabOverview), findsOneWidget);
          expect(service.agentPaused, isFalse);
          expect(engines[tab.id]!.viewMounts, mounts);
          pending.complete();
          expect(await outcome, isNull);
          expect(tester.takeException(), isNull);
        } finally {
          if (!pending.isCompleted) pending.complete();
        }
      },
    );
  }

  browserTestWidgets('large-text agent controls fit a narrow mobile viewport', (
    tester,
  ) async {
    await service.initialize();
    await service.updateSettings(service.settings.copyWith(agentEnabled: true));
    service.takeOver();
    await mount(tester, size: const Size(320, 844), textScale: 3);
    final action = find.text('Allow to continue');
    expect(action, findsOneWidget);
    final bounds = tester.getRect(action);
    expect(bounds.left, greaterThanOrEqualTo(0));
    expect(bounds.right, lessThanOrEqualTo(320));
    expect(bounds.bottom, lessThanOrEqualTo(844));
    expect(tester.takeException(), isNull);
    await tester.tap(action);
    await tester.pumpAndSettle();
    expect(service.agentPaused, isFalse);
    expect(tester.takeException(), isNull);
  });

  browserTestWidgets(
    'bookmarks are searchable and open their saved destination',
    (tester) async {
      await service.initialize();
      await service.addBookmark(url: 'https://flutter.dev', title: 'Flutter');
      await service.addBookmark(url: 'https://dart.dev', title: 'Dart');
      await mount(tester);
      await openMobileMenuItem(tester, 'Bookmarks');
      expect(find.byType(BrowserLibrary), findsOneWidget);
      expect(find.byType(CustomBottomSheet), findsNothing);
      await tester.tap(
        find.byKey(const ValueKey('browserLibrarySearchAction')),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(BrowserTextField, 'Search saved pages'),
        'dart',
      );
      await tester.pumpAndSettle();
      // The previous browser route remains mounted but is offstage.
      expect(find.text('Dart'), findsOneWidget);
      final row = find.text('Dart').last;
      await tester.tap(row);
      await tester.pumpAndSettle();
      expect(service.activeTab!.url, 'https://dart.dev');
      expect(find.byType(BrowserLibrary), findsNothing);
      expect(find.byType(CustomBottomSheet), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  browserTestWidgets(
    'bookmark editing survives save transition and validates URLs',
    (tester) async {
      await service.initialize();
      await service.addBookmark(url: 'https://flutter.dev', title: 'Flutter');
      await mount(tester);
      await openMobileMenuItem(tester, 'Bookmarks');
      await tester.tap(find.byTooltip('Edit bookmark'));
      await tester.pumpAndSettle();
      final fields = find.byType(BrowserTextField);
      await tester.enterText(fields.last, 'javascript:alert(1)');
      await tester.tap(find.text('Save'));
      await tester.pump();
      expect(
        find.text('Enter a valid HTTP or HTTPS website address.'),
        findsOneWidget,
      );
      await tester.enterText(fields.last, 'https://dart.dev');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(service.bookmarks.single.url, 'https://dart.dev');
      expect(tester.takeException(), isNull);
    },
  );

  browserTestWidgets(
    'system back navigates page history before leaving browser',
    (tester) async {
      await service.initialize();
      final tab = await service.createTab(url: 'https://example.com');
      await mount(tester);
      final engine = engines[tab.id]!;
      engine.onChanged(const BrowserPageState(canGoBack: true));
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(engine.backCalls, 1);
      expect(find.byType(BrowserPage), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  browserTestWidgets(
    'mobile history shows forward only when available and keeps viewport stable',
    (tester) async {
      await service.initialize();
      final tab = await service.createTab(url: 'https://example.com');
      await mount(tester);
      final engine = engines[tab.id]!;
      final address = find.byType(BrowserAddressBar);
      final viewport = find.byKey(const ValueKey('fakeNativeView'));
      final viewportBounds = tester.getRect(viewport);
      final singleRect = tester.getRect(address);
      expect(singleRect.left, 74); // 16 inset + 48 navigation + 10 gap.
      expect(singleRect.width, 242);
      for (final (back, forward) in [
        (true, false),
        (false, true),
        (true, true),
      ]) {
        engine.onChanged(
          BrowserPageState(canGoBack: back, canGoForward: forward),
        );
        await tester.pumpAndSettle();
        final group = find.byKey(
          const ValueKey('browserMobileNavigationGroup'),
        );
        expect(tester.getSize(group), Size(forward ? 84 : 48, 48));
        expect(tester.getRect(address).left, forward ? 110 : 74);
        expect(tester.getRect(address).width, forward ? 206 : 242);
        for (final (label, enabled) in [('Back', back), ('Forward', forward)]) {
          if (label == 'Forward' && !forward) {
            expect(find.byTooltip('Forward'), findsNothing);
            continue;
          }
          final button = tester.widget<BrowserActionButton>(
            find.descendant(
              of: group,
              matching: find.byWidgetPredicate(
                (widget) =>
                    widget is BrowserActionButton && widget.label == label,
              ),
            ),
          );
          expect(button.onPressed != null, enabled);
        }
      }
      engine.onChanged(_scroll(160));
      await tester.pumpAndSettle();
      expect(tester.getRect(address).center.dx, 195);
      expect(tester.getRect(address).width, lessThanOrEqualTo(206));
      engine.onChanged(_scroll(0));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(engine.backCalls, 1);
      await tester.tap(find.byTooltip('Forward'));
      await tester.pumpAndSettle();
      expect(engine.forwardCalls, 1);
      expect(find.byTooltip('Forward'), findsNothing);
      expect(tester.getRect(address), singleRect);
      expect(tester.getRect(viewport), viewportBounds);
      expect(engine.viewMounts, 1);
      expect(tester.takeException(), isNull);
    },
  );

  browserTestWidgets(
    'forward availability animates one retained navigation surface',
    (tester) async {
      await service.initialize();
      final tab = await service.createTab(url: 'https://example.com');
      await mount(tester);
      final engine = engines[tab.id]!;
      final group = find.byKey(const ValueKey('browserMobileNavigationGroup'));
      final element = tester.element(group);
      final viewport = tester.getRect(
        find.byKey(const ValueKey('fakeNativeView')),
      );
      engine.onChanged(
        const BrowserPageState(canGoBack: true, canGoForward: true),
      );
      await tester.pump();
      expect(tester.getSize(group).width, 48);
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.getSize(group).width, inExclusiveRange(48, 84));
      expect(tester.element(group), same(element));
      await tester.pumpAndSettle();
      expect(tester.getSize(group).width, 84);
      engine.onChanged(
        const BrowserPageState(canGoBack: true, canGoForward: false),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.getSize(group).width, inExclusiveRange(48, 84));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Forward'), findsNothing);
      expect(tester.getSize(group).width, 48);
      expect(tester.element(group), same(element));
      expect(
        tester.getRect(find.byKey(const ValueKey('fakeNativeView'))),
        viewport,
      );
      expect(engine.viewMounts, 1);
    },
  );

  browserTestWidgets(
    'pressing either navigation action lifts the shared capsule and cancels a drag',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      await service.initialize();
      final tab = await service.createTab(url: 'https://example.com');
      await mount(tester);
      final engine = engines[tab.id]!;
      engine.onChanged(
        const BrowserPageState(canGoBack: true, canGoForward: true),
      );
      await tester.pumpAndSettle();
      final group = find.byKey(const ValueKey('browserMobileNavigationGroup'));
      final resting = tester.getRect(group);
      for (final label in ['Back', 'Forward']) {
        final button = find.descendant(
          of: group,
          matching: find.byTooltip(label),
        );
        final pointer = await tester.startGesture(tester.getCenter(button));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 160));
        final pressed = tester.getRect(group);
        expect(pressed.width, greaterThan(resting.width + 8));
        expect(pressed.height, greaterThan(resting.height + 4));
        expect(
          find.descendant(
            of: group,
            matching: find.byKey(const ValueKey('browserGlassTouchLight')),
          ),
          findsOneWidget,
        );
        await pointer.moveBy(const Offset(24, -8));
        await tester.pump(const Duration(milliseconds: 50));
        expect(tester.getRect(group).center.dx, greaterThan(resting.center.dx));
        await pointer.cancel();
        await tester.pumpAndSettle();
        expect(
          tester.getRect(group),
          rectMoreOrLessEquals(resting, epsilon: .05),
        );
        expect(engine.backCalls, 0);
        expect(engine.forwardCalls, 0);
      }
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(engine.backCalls, 1);
      expect(engine.forwardCalls, 0);
      expect(tester.takeException(), isNull);
    },
  );

  for (final desktop in [false, true]) {
    browserTestWidgets(
      'menu omits redundant Forward while toolbar works (desktop: $desktop)',
      (tester) async {
        debugDefaultTargetPlatformOverride = desktop
            ? TargetPlatform.macOS
            : TargetPlatform.iOS;
        await service.initialize();
        final tab = await service.createTab(url: 'https://example.com');
        await mount(
          tester,
          size: desktop ? const Size(1100, 800) : const Size(390, 844),
        );
        final engine = engines[tab.id]!;
        engine.onChanged(const BrowserPageState(canGoForward: true));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('More').last);
        await tester.pumpAndSettle();
        final menu = find.byKey(const ValueKey('browserMenuSurface'));
        expect(menu, findsOneWidget);
        expect(
          find.descendant(of: menu, matching: find.text('Forward')),
          findsNothing,
        );
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Forward').last);
        await tester.pumpAndSettle();
        expect(engine.forwardCalls, 1);
        expect(service.activeTab!.canGoForward, isFalse);
        expect(tester.takeException(), isNull);
      },
    );
  }

  browserTestWidgets(
    'More stays visible until menu material is ready and restores without fading',
    (tester) async {
      await mount(tester);
      final more = find.byWidgetPredicate(
        (widget) => widget is BrowserActionButton && widget.label == 'More',
        skipOffstage: false,
      );
      final companion = find.byKey(
        const ValueKey('browserMobileNavigationGroup'),
      );
      final original = tester.element(more);
      expect(tester.widget<BrowserActionButton>(more).opacity, 1);
      await tester.tap(find.byTooltip('More').last);
      await tester.pump();
      expect(tester.widget<BrowserActionButton>(more).opacity, 1);
      expect(tester.widget<BrowserGlass>(companion).opacity, 1);
      final surface = find.byKey(const ValueKey('browserMenuSurface'));
      expect(tester.widget<BrowserGlass>(surface).opacity, 0);
      for (
        var frame = 0;
        frame < 5 && tester.widget<BrowserGlass>(surface).opacity == 0;
        frame++
      ) {
        expect(tester.widget<BrowserActionButton>(more).opacity, 1);
        expect(tester.widget<BrowserGlass>(companion).opacity, 1);
        await tester.pump();
      }
      expect(tester.widget<BrowserActionButton>(more).opacity, 0);
      expect(tester.widget<BrowserGlass>(surface).opacity, 1);
      expect(identical(tester.element(more), original), isTrue);
      await tester.pump(const Duration(milliseconds: 16));
      expect(
        tester.widget<BrowserGlass>(companion).opacity,
        inExclusiveRange(0, 1),
      );
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(10, 200));
      await tester.pump();
      expect(tester.widget<BrowserActionButton>(more).opacity, 0);
      await tester.pump(const Duration(milliseconds: 251));
      await tester.pump();
      expect(find.byKey(const ValueKey('browserMenuSurface')), findsNothing);
      expect(tester.widget<BrowserActionButton>(more).opacity, 1);
      expect(identical(tester.element(more), original), isTrue);
    },
  );

  browserTestWidgets(
    'toolbar glass survives collapse and stays onstage during held-menu handoff',
    (tester) async {
      await service.initialize();
      final tab = await service.createTab(url: 'https://example.com');
      await mount(tester);
      final engine = engines[tab.id]!;
      engine.onChanged(
        const BrowserPageState(canGoBack: true, canGoForward: true),
      );
      await tester.pumpAndSettle();
      final semantics = tester.ensureSemantics();
      try {
        await tester.pump();
        final controls = [
          for (final label in ['Back', 'More'])
            find.byWidgetPredicate(
              (widget) =>
                  widget is BrowserActionButton && widget.label == label,
              skipOffstage: false,
            ),
          find.byType(BrowserAddressBar, skipOffstage: false),
        ];
        final glasses = [
          find.byKey(
            const ValueKey('browserMobileNavigationGroup'),
            skipOffstage: false,
          ),
          for (final control in controls.skip(1))
            find.descendant(
              of: control,
              matching: find.byType(BrowserGlass, skipOffstage: false),
              skipOffstage: false,
            ),
        ];
        final elements = glasses.map(tester.element).toList();
        final states = glasses.map(tester.state).toList();
        final viewport = find.byKey(const ValueKey('fakeNativeView'));
        final viewportBounds = tester.getRect(viewport);
        final moreSlot = find.byKey(const ValueKey('browserMorePosition'));
        final restBounds = tester.getRect(moreSlot);

        void expectRetained({required int hiddenCount, bool menuOpen = false}) {
          final accessibleLabels = tester.semantics
              .simulatedAccessibilityTraversal()
              .expand((node) => node.label.split('\n'));
          for (var index = 0; index < controls.length; index++) {
            expect(
              identical(tester.element(glasses[index]), elements[index]),
              isTrue,
            );
            expect(
              identical(tester.state(glasses[index]), states[index]),
              isTrue,
            );
            final offstage = find.ancestor(
              of: controls[index],
              matching: find.byType(Offstage, skipOffstage: false),
            );
            expect(
              tester
                  .widgetList<Offstage>(offstage)
                  .any((widget) => widget.offstage),
              isFalse,
            );
            if (index < hiddenCount) {
              expect(tester.widget<BrowserGlass>(glasses[index]).opacity, 0);
            }
            if (index < hiddenCount || menuOpen) {
              expect(controls[index].hitTestable(), findsNothing);
              // The open menu has its own "More" barrier/title semantics. Check
              // that source label while collapsed, and the other unique toolbar
              // labels during both hiding paths.
              if (index != 1 || !menuOpen) {
                expect(
                  accessibleLabels,
                  isNot(
                    contains(
                      ['Back', 'More', 'Search or enter website'][index],
                    ),
                  ),
                );
              }
            }
          }
          expect(tester.getSize(moreSlot), const Size(48, 48));
          expect(tester.getRect(viewport), viewportBounds);
          expect(engine.viewMounts, 1);
          expect(engine.viewDisposals, 0);
        }

        engine.onChanged(_scroll(160));
        await tester.pumpAndSettle();
        expectRetained(hiddenCount: 2);
        engine.onChanged(_scroll(0));
        await tester.pumpAndSettle();
        expectRetained(hiddenCount: 0);
        expect(controls[1].hitTestable(), findsOneWidget);
        expect(tester.getRect(moreSlot), restBounds);

        // Menu opacity must not remove the native source from composition:
        // actual UIKit touches can cancel if its platform layer is removed.
        // The overlay blocks new hits/semantics while the held pointer continues.
        final finger = await tester.startGesture(tester.getCenter(controls[1]));
        await tester.pump(const Duration(milliseconds: 650));
        await tester.pumpAndSettle();
        expectRetained(hiddenCount: 0, menuOpen: true);
        for (final glass in glasses) {
          expect(tester.widget<BrowserGlass>(glass).opacity, 0);
        }
        expect(tester.getRect(moreSlot), restBounds);
        await finger.moveTo(tester.getCenter(find.text('Add bookmark')));
        await tester.pump(const Duration(milliseconds: 220));
        await finger.up();
        await tester.pumpAndSettle();
        expect(
          service.bookmarks.any((bookmark) => bookmark.url == tab.url),
          isTrue,
        );
        expect(find.byKey(const ValueKey('browserMenuSurface')), findsNothing);
        expectRetained(hiddenCount: 0);
        expect(controls[1].hitTestable(), findsOneWidget);
        expect(tester.getRect(moreSlot), restBounds);
        expect(tester.takeException(), isNull);
      } finally {
        semantics.dispose();
      }
    },
  );

  browserTestWidgets('menu opens settings and saves history preference', (
    tester,
  ) async {
    await mount(tester);
    await tester.tap(find.byTooltip('More').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Browser settings'));
    await tester.tap(find.text('Browser settings'));
    await tester.pumpAndSettle();
    expect(find.text('Search engine'), findsOneWidget);
    expect(find.byType(BrowserSettingsPanel), findsOneWidget);
    final panelContext = tester.element(find.byType(BrowserSettingsPanel));
    final panelStyle = DefaultTextStyle.of(panelContext).style;
    final panelTheme = Theme.of(panelContext);
    expect(panelStyle.color, panelTheme.colorScheme.onSurface);
    expect(panelStyle.fontSize, panelTheme.textTheme.bodyMedium!.fontSize);
    expect(panelStyle.decoration, TextDecoration.none);
    expect(find.byType(InkWell), findsNothing);
    expect(find.byType(InkResponse), findsNothing);
    expect(find.byType(CustomBottomSheet), findsNothing);
    await tester.ensureVisible(find.text('Save history'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save history'));
    await tester.pumpAndSettle();
    expect(service.settings.saveHistory, isFalse);
    expect(tester.takeException(), isNull);
  });

  for (final desktop in [false, true]) {
    browserTestWidgets(
      '${desktop ? 'desktop' : 'mobile'} settings route preserves its content through page notifications',
      (tester) async {
        if (desktop) debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
        await service.initialize();
        final tab = await service.createTab(url: 'https://example.com');
        await mount(tester);
        await openMobileMenuItem(tester, 'Browser settings');
        final panel = find.byType(BrowserSettingsPanel);
        final original = tester.widget<BrowserSettingsPanel>(panel);
        final element = tester.element(panel);
        for (final progress in [.2, .4, .8]) {
          engines[tab.id]!.onChanged(BrowserPageState(progress: progress));
          await tester.pump();
          expect(tester.widget<BrowserSettingsPanel>(panel), same(original));
          expect(tester.element(panel), same(element));
        }
        // The fixed child still inherits a selected surface-style change.
        await service.updateSettings(
          service.settings.copyWith(surfaceStyle: BrowserSurfaceStyle.solid),
        );
        await tester.pumpAndSettle();
        expect(
          BrowserGlassScope.of(tester.element(panel)),
          BrowserSurfaceStyle.solid,
        );
        expect(tester.widget<BrowserSettingsPanel>(panel), same(original));
        expect(tester.takeException(), isNull);
      },
    );
  }

  browserTestWidgets('narrow desktop uses dialogs rather than mobile sheets', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    await mount(tester);
    expect(find.byType(BrowserDesktopLayout), findsOneWidget);
    await openMobileMenuItem(tester, 'Bookmarks');
    expect(find.byType(CustomBottomSheet), findsNothing);
    expect(
      find.descendant(
        of: find.byType(BrowserLibrary),
        matching: find.text('Your favorite places, all together.'),
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  browserTestWidgets('macOS title controls and compact dialog fit the window', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    await mount(tester, size: const Size(760, 560));
    final closeButton = find
        .byWidgetPredicate(
          (widget) =>
              widget is BrowserActionButton && widget.label == 'Close browser',
        )
        .first;
    // Only the upper tab row reserves macOS title controls; toolbar below it
    // starts at the content edge instead of carrying a second empty spacer.
    expect(
      tester.getRect(find.byType(BrowserTabStrip)).left,
      greaterThanOrEqualTo(96),
    );
    expect(tester.getRect(closeButton).left, lessThan(96));
    await openMobileMenuItem(tester, 'Browser settings');
    final panel = tester.getRect(find.byKey(const ValueKey('browserPanel')));
    expect(panel.width, 440);
    expect(panel.top, greaterThanOrEqualTo(12));
    expect(panel.bottom, lessThanOrEqualTo(548));
    await tester.tapAt(const Offset(20, 200));
    await tester.pumpAndSettle();
    expect(find.byType(BrowserSettingsPanel), findsNothing);
    expect(tester.takeException(), isNull);
  });

  browserTestWidgets(
    'scroll collapses and restores floating controls without remounting the page',
    (tester) async {
      await service.initialize();
      final tab = await service.createTab(url: 'https://example.com');
      await mount(tester);
      final engine = engines[tab.id]!;
      final viewport = find.byKey(const ValueKey('fakeNativeView'));
      final initialBounds = tester.getRect(viewport);
      final addressGlass = find.descendant(
        of: find.byType(BrowserAddressBar),
        matching: find.byType(BrowserGlass),
      );
      final addressElement = tester.element(addressGlass);
      void expectCenteredHost() {
        final host = tester.getRect(find.text('example.com').last);
        final capsule = tester.getRect(find.byType(BrowserAddressBar));
        expect(host.center.dy, closeTo(capsule.center.dy, .5));
      }

      expectCenteredHost();
      expect(engine.viewMounts, 1);
      expect(initialBounds.bottom, 844);
      expect(find.byTooltip('More'), findsWidgets);
      expect(find.byType(InkWell), findsNothing);
      expect(find.byType(InkResponse), findsNothing);

      engine.onChanged(_scroll(160));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<BrowserAddressBar>(find.byType(BrowserAddressBar))
            .collapsed,
        isTrue,
      );
      expect(find.byTooltip('More').hitTestable(), findsNothing);
      expect(tester.getSize(find.byType(BrowserAddressBar)).height, 34);
      expectCenteredHost();
      expect(tester.getRect(viewport), initialBounds);
      expect(identical(tester.element(addressGlass), addressElement), isTrue);
      expect(engine.viewMounts, 1);
      expect(engine.viewDisposals, 0);

      await tester.tap(find.text('example.com'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<BrowserAddressBar>(find.byType(BrowserAddressBar))
            .collapsed,
        isFalse,
      );
      expect(find.byKey(const ValueKey('browserAddressField')), findsNothing);
      engine.onChanged(_scroll(260));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<BrowserAddressBar>(find.byType(BrowserAddressBar))
            .collapsed,
        isTrue,
      );
      engine.onChanged(_scroll(220));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<BrowserAddressBar>(find.byType(BrowserAddressBar))
            .collapsed,
        isFalse,
      );
      expect(find.byTooltip('More'), findsWidgets);
      expect(tester.getRect(viewport), initialBounds);
      expect(identical(tester.element(addressGlass), addressElement), isTrue);
      expect(engine.viewMounts, 1);
      expect(engine.viewDisposals, 0);
      expect(tester.takeException(), isNull);
    },
  );

  for (final (host, scale) in [
    ('a-very-long-subdomain.documentation.example.com', 1.0),
    ('example.com', 3.0),
  ]) {
    browserTestWidgets(
      'collapse never widens the capsule for $host at text scale $scale',
      (tester) async {
        await service.initialize();
        final tab = await service.createTab(url: 'https://$host');
        await mount(tester, textScale: scale);
        final engine = engines[tab.id]!;
        final address = find.byType(BrowserAddressBar);
        final expanded = tester.getRect(address);
        var previousWidth = expanded.width;

        for (final offset in [12.0, 27.0, 42.0, 54.0]) {
          engine.onChanged(_scroll(offset));
          await tester.pump(const Duration(milliseconds: 64));
          final current = tester.getRect(address);
          expect(current.width, lessThanOrEqualTo(previousWidth));
          expect(current.center.dx, closeTo(expanded.center.dx, .01));
          expect(current.left, greaterThanOrEqualTo(expanded.left));
          expect(current.right, lessThanOrEqualTo(expanded.right));
          previousWidth = current.width;
        }
        await tester.pumpAndSettle();
        expect(tester.widget<BrowserAddressBar>(address).collapsed, isTrue);
        expect(
          tester.getRect(address).width,
          lessThanOrEqualTo(expanded.width),
        );
        expect(
          find.descendant(of: address, matching: find.text(host)),
          findsOneWidget,
        );
        engine.onChanged(_scroll(0));
        await tester.pumpAndSettle();
        expect(tester.getRect(address), expanded);
        expect(engine.viewMounts, 1);
        expect(tester.takeException(), isNull);
      },
    );
  }

  browserTestWidgets(
    'fitting host scales continuously without endpoint crossfade',
    (tester) async {
      await service.initialize();
      final tab = await service.createTab(url: 'https://x.io');
      await mount(tester);
      final engine = engines[tab.id]!;
      final address = find.byType(BrowserAddressBar);
      final host = find.descendant(of: address, matching: find.text('x.io'));
      var intermediateFrames = 0;
      for (final offset in [100.0, 0.0]) {
        engine.onChanged(_scroll(offset));
        await tester.pump();
        for (var frame = 0; frame < 36; frame++) {
          await tester.pump(const Duration(milliseconds: 16));
          final bar = tester.widget<BrowserAddressBar>(address);
          expect(bar.stabilizeTruncation, isFalse);
          expect(host, findsOneWidget);
          final text = tester.widget<Text>(host);
          expect(text.style!.fontSize, 16);
          if (bar.collapseProgress > 0 && bar.collapseProgress < 1) {
            intermediateFrames++;
          }
        }
      }
      expect(intermediateFrames, greaterThan(1));
      expect(engine.viewMounts, 1);
      expect(tester.takeException(), isNull);
    },
  );

  browserTestWidgets(
    'collapse endpoints keep the same address material and text weight',
    (tester) async {
      await service.initialize();
      final tab = await service.createTab(url: 'https://example.com');
      await mount(tester);
      final engine = engines[tab.id]!;
      final address = find.byType(BrowserAddressBar);
      final glass = find.descendant(
        of: address,
        matching: find.byType(BrowserGlass),
      );
      final glassElement = tester.element(glass);
      final host = find.descendant(
        of: address,
        matching: find.text('example.com'),
      );

      void expectStableMaterial() {
        final progress = tester
            .widget<BrowserAddressBar>(address)
            .collapseProgress;
        expect(identical(tester.element(glass), glassElement), isTrue);
        expect(tester.widget<BrowserGlass>(glass).clear, isFalse);
        final labels = tester.widgetList<Text>(host).toList();
        expect(labels, hasLength(progress > 0 && progress < 1 ? 2 : 1));
        for (final text in labels) {
          expect(text.style!.fontWeight, FontWeight.w500);
          expect(text.style!.fontSize, 16);
        }
      }

      expectStableMaterial();
      for (final offset in [100.0, 0.0]) {
        engine.onChanged(_scroll(offset));
        await tester.pump();
        for (var frame = 0; frame < 36; frame++) {
          await tester.pump(const Duration(milliseconds: 16));
          expectStableMaterial();
        }
        await tester.pumpAndSettle();
        expect(
          tester.widget<BrowserAddressBar>(address).collapseProgress,
          offset == 0 ? 0 : 1,
        );
        expectStableMaterial();
      }
      expect(engine.viewMounts, 1);
      expect(tester.takeException(), isNull);
    },
  );

  browserTestWidgets(
    'Android raw input survives DOM cancellation and ignores pinch and momentum',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      final tab = await service.createTab(url: 'https://scroll.example');
      await mount(tester);
      final engine = engines[tab.id]!;
      final chrome = find.byType(BrowserChromeTransition);
      double target() =>
          tester.widget<BrowserChromeTransition>(chrome).progress;
      engine.onChanged(
        _scroll(100, phase: BrowserScrollPhase.metrics, interacting: false),
      );
      final finger = await tester.startGesture(
        tester.getCenter(find.byKey(const ValueKey('fakeNativeView'))),
      );
      for (var i = 0; i < 4; i++) {
        await finger.moveBy(const Offset(0, -4));
        engine.onChanged(
          _scroll(
            104 + i * 4,
            phase: BrowserScrollPhase.metrics,
            interacting: false,
          ),
        );
        await tester.pump();
      }
      expect(
        target(),
        1,
        reason: 'DOM touchcancel must not cancel native scroll intent',
      );
      await finger.up();
      engine.onChanged(_scroll(90, interacting: false));
      await tester.pump();
      expect(target(), 1, reason: 'momentum is not a new gesture');
      final down = await tester.startGesture(const Offset(180, 300));
      await down.moveBy(const Offset(0, 10));
      await tester.pump();
      expect(target(), 0);
      final second = await tester.startGesture(
        const Offset(240, 300),
        pointer: 2,
      );
      await down.moveBy(const Offset(0, -100));
      await tester.pump();
      expect(target(), 0, reason: 'pinch does not collapse toolbar');
      await second.up();
      await down.up();
      expect(engine.viewMounts, 1);
    },
  );

  browserTestWidgets(
    'Android raw input reveals chrome at document edges and after content shrinks',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      final tab = await service.createTab(url: 'https://scroll.example');
      await mount(tester);
      final engine = engines[tab.id]!;
      double target() => tester
          .widget<BrowserChromeTransition>(find.byType(BrowserChromeTransition))
          .progress;
      engine.onChanged(_scroll(100, interacting: false));
      final finger = await tester.startGesture(
        tester.getCenter(find.byKey(const ValueKey('fakeNativeView'))),
      );
      await finger.moveBy(const Offset(0, -16));
      await tester.pump();
      expect(target(), 1);
      // A compositor can report the bottom with DOM touching already cancelled.
      engine.onChanged(_scroll(3156, interacting: false));
      await tester.pump();
      expect(target(), 0);
      await finger.moveBy(const Offset(0, -30));
      await tester.pump();
      expect(target(), 0, reason: 'pinned bottom cannot hide navigation');
      await finger.up();
      engine.onChanged(_scroll(100, interacting: false));
      final next = await tester.startGesture(const Offset(180, 300));
      await next.moveBy(const Offset(0, -16));
      await next.up();
      await tester.pump();
      expect(target(), 1);
      engine.onChanged(_scroll(0, content: 844, interacting: false));
      await tester.pump();
      expect(
        target(),
        0,
        reason: 'a dynamically shortened page must reveal navigation',
      );
      expect(engine.viewMounts, 1);
    },
  );

  browserTestWidgets(
    'direction intent uses 12 point collapse and 6 point expansion hysteresis',
    (tester) async {
      await service.initialize();
      final tab = await service.createTab(url: 'https://example.com');
      await mount(tester);
      final engine = engines[tab.id]!;
      final address = find.byType(BrowserAddressBar);
      final chrome = find.byType(BrowserChromeTransition);
      final viewport = find.byKey(const ValueKey('fakeNativeView'));
      final element = tester.element(viewport);
      final bounds = tester.getRect(viewport);
      final builds = engine.viewBuilds;
      double visible() =>
          tester.widget<BrowserAddressBar>(address).collapseProgress;
      double target() =>
          tester.widget<BrowserChromeTransition>(chrome).progress;
      engine.onChanged(_scroll(100, phase: BrowserScrollPhase.metrics));
      for (final offset in [104.0, 108.0, 111.0]) {
        engine.onChanged(_scroll(offset));
        await tester.pumpAndSettle();
        expect(target(), 0);
        expect(visible(), 0);
      }
      engine.onChanged(_scroll(112));
      await tester.pump();
      expect(target(), 1);
      expect(visible(), 0); // An event chooses a target, never frame geometry.
      await tester.pump(const Duration(milliseconds: 16));
      expect(visible(), inExclusiveRange(0, .2));
      await tester.pumpAndSettle();
      expect(visible(), 1);
      for (final offset in [110.0, 108.0, 107.0]) {
        engine.onChanged(_scroll(offset));
        await tester.pumpAndSettle();
        expect(target(), 1);
        expect(visible(), 1);
      }
      engine.onChanged(_scroll(106));
      await tester.pump();
      expect(target(), 0);
      expect(visible(), 1);
      await tester.pumpAndSettle();
      expect(visible(), 0);
      expect(identical(tester.element(viewport), element), isTrue);
      expect(tester.getRect(viewport), bounds);
      expect(engine.viewBuilds, builds);
      expect(engine.viewMounts, 1);
      expect(engine.viewDisposals, 0);
    },
  );

  browserTestWidgets(
    'end metrics and duplicate updates preserve the spring without adding intent',
    (tester) async {
      await service.initialize();
      final tab = await service.createTab(url: 'https://example.com');
      await mount(tester);
      final engine = engines[tab.id]!;
      final address = find.byType(BrowserAddressBar);
      final chrome = find.byType(BrowserChromeTransition);
      double visible() =>
          tester.widget<BrowserAddressBar>(address).collapseProgress;
      double target() =>
          tester.widget<BrowserChromeTransition>(chrome).progress;
      engine.onChanged(_scroll(100, phase: BrowserScrollPhase.metrics));
      engine.onChanged(_scroll(110));
      engine.onChanged(_scroll(240, phase: BrowserScrollPhase.end));
      engine.onChanged(_scroll(300, phase: BrowserScrollPhase.metrics));
      await tester.pumpAndSettle();
      expect(target(), 0);
      engine.onChanged(_scroll(302)); // Ten update points + two update points.
      await tester.pump();
      expect(target(), 1);
      expect(visible(), 0);
      engine.onChanged(_scroll(302, phase: BrowserScrollPhase.end));
      engine.onChanged(_scroll(302));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 64));
      final before = visible();
      expect(before, inExclusiveRange(0, 1));
      engine.onChanged(_scroll(302, phase: BrowserScrollPhase.metrics));
      engine.onChanged(_scroll(302));
      await tester.pump();
      expect(visible(), closeTo(before, .00001));
      await tester.pumpAndSettle();
      expect(visible(), 1);
      engine.onChanged(_scroll(302, phase: BrowserScrollPhase.reset));
      await tester.pump();
      expect(visible(), 0);
      expect(target(), 0);
      engine.onChanged(_scroll(313));
      await tester.pumpAndSettle();
      expect(visible(), 0); // Reset discarded the previous direction intent.
    },
  );

  browserTestWidgets(
    'coalesced native scroll batches animate with the same path as one direction event',
    (tester) async {
      await service.initialize();
      final tab = await service.createTab(url: 'https://example.com');
      await mount(tester);
      final engine = engines[tab.id]!;
      final address = find.byType(BrowserAddressBar);
      final state = tester.state(find.byType(BrowserChromeTransition));
      double visible() =>
          tester.widget<BrowserAddressBar>(address).collapseProgress;
      Future<List<double>> sample({required bool noisy}) async {
        engine.onChanged(_scroll(0, phase: BrowserScrollPhase.reset));
        await tester.pump();
        for (final offset in noisy ? [16.0, 99.0, 600.0] : [600.0]) {
          engine.onChanged(_scroll(offset));
        }
        await tester.pump();
        expect(visible(), 0);
        final values = <double>[visible()];
        for (var frame = 0; frame < 16; frame++) {
          if (noisy) {
            engine.onChanged(_scroll(600 + frame * 2.0));
            engine.onChanged(BrowserPageState(progress: .1 + frame * .02));
          }
          await tester.pump(const Duration(milliseconds: 16));
          values.add(visible());
        }
        return values;
      }

      final uninterrupted = await sample(noisy: false);
      final coalesced = await sample(noisy: true);
      for (var i = 1; i < coalesced.length; i++) {
        expect(coalesced[i], closeTo(uninterrupted[i], .00001));
        expect(coalesced[i] - coalesced[i - 1], inInclusiveRange(0, .15));
      }
      expect(coalesced[1], inExclusiveRange(0, .2));
      expect(coalesced[4], inExclusiveRange(.2, .8));
      await tester.pumpAndSettle();
      expect(visible(), 1);
      expect(
        identical(tester.state(find.byType(BrowserChromeTransition)), state),
        isTrue,
      );
      expect(engine.viewMounts, 1);
    },
  );

  browserTestWidgets(
    'CSS viewport scaling applies direction thresholds and eight point document edges',
    (tester) async {
      await service.initialize();
      final tab = await service.createTab(url: 'https://example.com');
      await mount(tester);
      final engine = engines[tab.id]!;
      final address = find.byType(BrowserAddressBar);
      final chrome = find.byType(BrowserChromeTransition);
      double target() =>
          tester.widget<BrowserChromeTransition>(chrome).progress;
      void emit(
        double offset, {
        BrowserScrollPhase phase = BrowserScrollPhase.update,
      }) {
        // A page without a meta viewport has twice as many CSS units as the
        // visible native slot: 24 CSS pixels are twelve logical points.
        engine.onChanged(
          _scroll(offset, viewport: 1688, content: 4000, phase: phase),
        );
      }

      emit(100, phase: BrowserScrollPhase.metrics);
      emit(123);
      await tester.pumpAndSettle();
      expect(target(), 0);
      emit(124);
      await tester.pumpAndSettle();
      expect(target(), 1);
      emit(113);
      await tester.pumpAndSettle();
      expect(target(), 1);
      emit(112);
      await tester.pumpAndSettle();
      expect(target(), 0);
      emit(2280, phase: BrowserScrollPhase.metrics);
      emit(2304); // Only four logical points remain before the bottom.
      await tester.pumpAndSettle();
      expect(target(), 0);
      emit(16);
      await tester.pumpAndSettle();
      expect(target(), 0);
      emit(-20);
      await tester.pumpAndSettle();
      expect(tester.widget<BrowserAddressBar>(address).collapseProgress, 0);
      expect(engine.viewMounts, 1);
    },
  );

  browserTestWidgets('direction transitions do not require scrollend support', (
    tester,
  ) async {
    await service.initialize();
    final tab = await service.createTab(url: 'https://example.com');
    await mount(tester);
    final engine = engines[tab.id]!;
    final address = find.byType(BrowserAddressBar);
    engine.onChanged(_scroll(100, supportsEnd: false));
    await tester.pump();
    expect(tester.widget<BrowserAddressBar>(address).collapseProgress, 0);
    await tester.pumpAndSettle();
    expect(tester.widget<BrowserAddressBar>(address).collapseProgress, 1);
    engine.onChanged(_scroll(94, supportsEnd: false));
    await tester.pumpAndSettle();
    expect(tester.widget<BrowserAddressBar>(address).collapseProgress, 0);
    expect(service.scrollStateForTab(tab.id)!.supportsScrollEnd, isFalse);
  });

  browserTestWidgets(
    'scroll reversal retargets continuously and top bounce restores the expanded capsule',
    (tester) async {
      await service.initialize();
      final tab = await service.createTab(url: 'https://example.com');
      await mount(tester);
      final engine = engines[tab.id]!;
      final address = find.byType(BrowserAddressBar);
      double visible() =>
          tester.widget<BrowserAddressBar>(address).collapseProgress;
      engine.onChanged(_scroll(100));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 64));
      final turningPoint = visible();
      expect(turningPoint, inExclusiveRange(.2, .8));
      engine.onChanged(_scroll(94));
      await tester.pump();
      expect(visible(), closeTo(turningPoint, .00001));
      var previous = visible();
      for (var frame = 0; frame < 12; frame++) {
        await tester.pump(const Duration(milliseconds: 16));
        expect((visible() - previous).abs(), lessThan(.15));
        previous = visible();
      }
      expect(visible(), lessThan(turningPoint));
      await tester.pumpAndSettle();
      expect(visible(), 0);
      engine.onChanged(_scroll(200));
      await tester.pumpAndSettle();
      expect(visible(), 1);
      for (final offset in [-30.0, -10.0, 0.0]) {
        engine.onChanged(_scroll(offset));
        await tester.pumpAndSettle();
        expect(visible(), 0);
      }
      expect(engine.viewMounts, 1);
      expect(tester.takeException(), isNull);
    },
  );

  browserTestWidgets(
    'released top overscroll cannot collapse chrome during rubber-band recovery',
    (tester) async {
      await service.initialize();
      final tab = await service.createTab(url: 'https://example.com');
      await mount(tester);
      final engine = engines[tab.id]!;
      double target() => tester
          .widget<BrowserChromeTransition>(find.byType(BrowserChromeTransition))
          .progress;
      engine.onChanged(_scroll(100));
      await tester.pumpAndSettle();
      expect(target(), 1);
      engine.onChanged(_scroll(-90, gestureDelta: -90));
      await tester.pumpAndSettle();
      expect(target(), 0);
      for (final offset in [-80.0, -20.0, 0.0, 14.0, 30.0, 4.0, 0.0]) {
        engine.onChanged(_scroll(offset, interacting: false));
        await tester.pumpAndSettle();
        expect(target(), 0);
      }
      // A new deliberate scroll starts from the recovered offset.
      engine.onChanged(_scroll(11, gestureDelta: 11));
      await tester.pumpAndSettle();
      expect(target(), 0);
      engine.onChanged(_scroll(12, gestureDelta: 1));
      await tester.pumpAndSettle();
      expect(target(), 1);
      expect(engine.viewMounts, 1);
    },
  );

  browserTestWidgets(
    'bottom opens on manual input even when pinned and ignores rebound after release',
    (tester) async {
      await service.initialize();
      final tab = await service.createTab(url: 'https://example.com');
      await mount(tester);
      final engine = engines[tab.id]!;
      double target() => tester
          .widget<BrowserChromeTransition>(find.byType(BrowserChromeTransition))
          .progress;
      engine.onChanged(_scroll(100));
      await tester.pumpAndSettle();
      expect(target(), 1);
      // Momentum reaching the end should not jump the chrome open.
      engine.onChanged(_scroll(3156, interacting: false));
      await tester.pumpAndSettle();
      expect(target(), 1);
      // Android can pin scrollY exactly at max while the finger keeps moving.
      engine.onChanged(_scroll(3156, gestureDelta: 16));
      await tester.pumpAndSettle();
      expect(target(), 0);
      for (final offset in [3196.0, 3180.0, 3156.0, 3140.0, 3156.0]) {
        engine.onChanged(_scroll(offset, interacting: false));
        await tester.pumpAndSettle();
        expect(target(), 0);
      }
      // A long page's scripted jump also cannot hide navigation controls.
      engine.onChanged(_scroll(200, interacting: false));
      engine.onChanged(_scroll(1200, interacting: false));
      await tester.pumpAndSettle();
      expect(target(), 0);
      expect(engine.viewMounts, 1);
    },
  );

  browserTestWidgets(
    'finger intent changes chrome before delayed compositor scroll offsets',
    (tester) async {
      await service.initialize();
      final tab = await service.createTab(url: 'https://example.com');
      await mount(tester);
      final engine = engines[tab.id]!;
      double target() => tester
          .widget<BrowserChromeTransition>(find.byType(BrowserChromeTransition))
          .progress;

      // WebKit can deliver all finger moves before the scroll compositor
      // publishes its first scrollY change, including a flick from the top.
      engine.onChanged(_scroll(0, phase: BrowserScrollPhase.metrics));
      engine.onChanged(_scroll(0, gestureDelta: 7));
      engine.onChanged(_scroll(0, gestureDelta: 5));
      await tester.pumpAndSettle();
      expect(target(), 1);
      engine.onChanged(
        _scroll(0, phase: BrowserScrollPhase.metrics, interacting: false),
      );
      engine.onChanged(_scroll(200, interacting: false));
      await tester.pumpAndSettle();
      expect(target(), 1);

      engine.onChanged(_scroll(200, phase: BrowserScrollPhase.metrics));
      engine.onChanged(_scroll(200, gestureDelta: -6));
      await tester.pumpAndSettle();
      expect(target(), 0);
      // An older positive scroll delta must not reverse the new finger intent.
      engine.onChanged(_scroll(260));
      await tester.pumpAndSettle();
      expect(target(), 0);
      engine.onChanged(
        _scroll(260, phase: BrowserScrollPhase.metrics, interacting: false),
      );
      engine.onChanged(_scroll(160, interacting: false));
      await tester.pumpAndSettle();
      expect(target(), 0);
      expect(engine.viewMounts, 1);
    },
  );

  browserTestWidgets(
    'finger and compositor reports count each move only once',
    (tester) async {
      await service.initialize();
      final tab = await service.createTab(url: 'https://example.com');
      await mount(tester);
      final engine = engines[tab.id]!;
      double target() => tester
          .widget<BrowserChromeTransition>(find.byType(BrowserChromeTransition))
          .progress;
      engine.onChanged(_scroll(100, phase: BrowserScrollPhase.metrics));
      engine.onChanged(_scroll(100, gestureDelta: 7));
      engine.onChanged(_scroll(107));
      await tester.pumpAndSettle();
      expect(target(), 0, reason: 'One seven-point move is not fourteen');
      engine.onChanged(_scroll(107, gestureDelta: 5));
      await tester.pumpAndSettle();
      expect(target(), 1);
    },
  );

  browserTestWidgets(
    'fresh touch consumes the previous momentum offset as a baseline',
    (tester) async {
      await service.initialize();
      final tab = await service.createTab(url: 'https://example.com');
      await mount(tester);
      final engine = engines[tab.id]!;
      double target() => tester
          .widget<BrowserChromeTransition>(find.byType(BrowserChromeTransition))
          .progress;
      engine.onChanged(_scroll(100, interacting: false));
      engine.onChanged(_scroll(800, phase: BrowserScrollPhase.metrics));
      engine.onChanged(_scroll(811, gestureDelta: 11));
      await tester.pumpAndSettle();
      expect(target(), 0);
      engine.onChanged(_scroll(812, gestureDelta: 1));
      await tester.pumpAndSettle();
      expect(target(), 1);
      engine.onChanged(
        _scroll(812, phase: BrowserScrollPhase.metrics, interacting: false),
      );
      engine.onChanged(_scroll(1200, phase: BrowserScrollPhase.metrics));
      engine.onChanged(_scroll(1195, gestureDelta: -5));
      await tester.pumpAndSettle();
      expect(target(), 1);
      engine.onChanged(_scroll(1194, gestureDelta: -1));
      await tester.pumpAndSettle();
      expect(target(), 0);
    },
  );

  browserTestWidgets(
    'short documents keep chrome expanded through both edges',
    (tester) async {
      await service.initialize();
      final tab = await service.createTab(url: 'https://example.com');
      await mount(tester);
      final engine = engines[tab.id]!;
      for (final offset in [-60.0, 0.0, 7.0, 50.0, 0.0]) {
        engine.onChanged(_scroll(offset, content: 851, gestureDelta: 20));
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<BrowserChromeTransition>(
                find.byType(BrowserChromeTransition),
              )
              .progress,
          0,
        );
      }
      expect(engine.viewMounts, 1);
    },
  );

  browserTestWidgets(
    'address editing holds chrome open and consumes ignored scroll movement',
    (tester) async {
      await service.initialize();
      final tab = await service.createTab(url: 'https://example.com');
      await mount(tester);
      final engine = engines[tab.id]!;
      final address = find.byType(BrowserAddressBar);
      engine.onChanged(_scroll(48));
      await tester.pumpAndSettle();
      await tester.tap(address);
      await tester.pumpAndSettle();
      await tester.tap(address);
      await tester.pumpAndSettle();
      final field = find.byKey(const ValueKey('browserAddressField'));
      expect(field, findsOneWidget);
      engine.onChanged(_scroll(400));
      await tester.pumpAndSettle();
      expect(tester.widget<BrowserAddressBar>(address).collapseProgress, 0);
      tester.widget<BrowserTextField>(field).focusNode!.unfocus();
      await tester.pumpAndSettle();
      engine.onChanged(_scroll(404));
      await tester.pumpAndSettle();
      expect(tester.widget<BrowserAddressBar>(address).collapseProgress, 0);
      engine.onChanged(_scroll(412));
      await tester.pumpAndSettle();
      expect(tester.widget<BrowserAddressBar>(address).collapseProgress, 1);
      expect(tester.takeException(), isNull);
    },
  );

  browserTestWidgets(
    'find consumes ignored scroll intent and reduced motion jumps only at thresholds',
    (tester) async {
      await service.initialize();
      final tab = await service.createTab(url: 'https://example.com');
      await mount(tester, reduceMotion: true);
      final engine = engines[tab.id]!;
      final address = find.byType(BrowserAddressBar);
      final state = tester.state(find.byType(BrowserChromeTransition));
      double visible() =>
          tester.widget<BrowserAddressBar>(address).collapseProgress;
      engine.onChanged(_scroll(100, phase: BrowserScrollPhase.metrics));
      engine.onChanged(_scroll(110));
      await tester.pump();
      expect(visible(), 0);
      await openMobileMenuItem(tester, 'Page options');
      await tester.tap(find.text('Find on page'));
      await tester.pumpAndSettle();
      engine.onChanged(_scroll(400));
      await tester.pump();
      expect(visible(), 0);
      await tester.tap(find.byTooltip('Done'));
      await tester.pumpAndSettle();
      engine.onChanged(_scroll(404));
      await tester.pump();
      expect(visible(), 0);
      engine.onChanged(_scroll(412));
      await tester.pump();
      expect(visible(), 1);
      engine.onChanged(_scroll(407));
      await tester.pump();
      expect(visible(), 1);
      engine.onChanged(_scroll(406));
      await tester.pump();
      expect(visible(), 0);
      expect(
        identical(tester.state(find.byType(BrowserChromeTransition)), state),
        isTrue,
      );
      expect(engine.viewMounts, 1);
      expect(tester.takeException(), isNull);
    },
  );

  browserTestWidgets(
    'collapse draws side controls inward and keeps the lower capsule tappable',
    (tester) async {
      tester.view.viewPadding = const FakeViewPadding(bottom: 34);
      addTearDown(tester.view.resetViewPadding);
      await service.initialize();
      final tab = await service.createTab(url: 'https://example.com');
      await mount(tester);
      final engine = engines[tab.id]!;
      final address = find.byType(BrowserAddressBar);
      final more = find.byTooltip('More');
      final expandedAddress = tester.getRect(address);
      final expandedMore = tester.getCenter(more);
      final viewport = tester.getRect(
        find.byKey(const ValueKey('fakeNativeView')),
      );
      engine.onChanged(_scroll(48));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 64));
      expect(tester.getRect(address).width, lessThan(expandedAddress.width));
      expect(
        tester.getRect(address).bottom,
        greaterThan(expandedAddress.bottom),
      );
      expect(tester.getCenter(more).dx, lessThan(expandedMore.dx));
      expect(tester.getCenter(more).dy, greaterThan(expandedMore.dy));
      expect(tester.getCenter(more).dy - expandedMore.dy, lessThan(25));
      engine.onChanged(_scroll(160));
      await tester.pumpAndSettle();
      expect(tester.getRect(address).bottom, lessThan(844));
      await tester.tapAt(tester.getCenter(address));
      await tester.pumpAndSettle();
      expect(tester.widget<BrowserAddressBar>(address).collapseProgress, 0);
      expect(tester.getRect(address), expandedAddress);
      expect(
        tester.getRect(find.byKey(const ValueKey('fakeNativeView'))),
        viewport,
      );
      expect(engine.viewMounts, 1);
      expect(tester.takeException(), isNull);
    },
  );

  browserTestWidgets(
    'full page chrome keeps identity and frame geometry under repeated notifications',
    (tester) async {
      await service.initialize();
      final tab = await service.createTab(url: 'https://example.com');
      await mount(tester);
      final engine = engines[tab.id]!;
      final chrome = find.byType(BrowserChromeTransition);
      final address = find.byType(BrowserAddressBar);
      final viewport = find.byKey(const ValueKey('fakeNativeView'));
      final chromeState = tester.state(chrome);
      final addressElement = tester.element(address);
      final viewportElement = tester.element(viewport);
      final viewportBounds = tester.getRect(viewport);
      final expandedWidth = tester.getSize(address).width;
      var previousWidth = expandedWidth;
      final collapseWidths = <double>[];

      void expectIdentityAndGeometry() {
        expect(identical(tester.state(chrome), chromeState), isTrue);
        expect(identical(tester.element(address), addressElement), isTrue);
        expect(identical(tester.element(viewport), viewportElement), isTrue);
        expect(tester.getRect(viewport), viewportBounds);
        expect(engine.viewMounts, 1);
        expect(engine.viewDisposals, 0);
      }

      // A native batch can jump hundreds of CSS pixels while Flutter was busy.
      // Keep the initial geometry, then advance only on animation frames.
      engine.onChanged(_scroll(600));
      await tester.pump();
      expect(tester.getSize(address).width, expandedWidth);
      for (var frame = 0; frame < 18; frame++) {
        engine.onChanged(_scroll(602 + frame * 3.0));
        engine.onChanged(BrowserPageState(progress: .1 + frame * .02));
        await tester.pump(const Duration(milliseconds: 16));
        final width = tester.getSize(address).width;
        expect(width, lessThanOrEqualTo(previousWidth + .01));
        expectIdentityAndGeometry();
        collapseWidths.add(width);
        previousWidth = width;
      }
      await tester.pumpAndSettle();
      final collapsedWidth = expectReadableCollapsedAddress(
        tester,
        address,
        expandedWidth,
      );
      final travel = expandedWidth - collapsedWidth;
      expect(
        expandedWidth - collapseWidths.first,
        inExclusiveRange(0, travel * .2),
      );
      expect(collapseWidths[3], lessThan(expandedWidth - travel * .2));
      expect(collapseWidths[3], greaterThan(collapsedWidth + travel * .2));
      for (var frame = 1; frame < collapseWidths.length; frame++) {
        expect(
          (collapseWidths[frame] - collapseWidths[frame - 1]).abs(),
          lessThan(travel * .15),
        );
      }
      engine.onChanged(_scroll(600));
      await tester.pump();
      expect(tester.getSize(address).width, collapsedWidth);
      await tester.pump(const Duration(milliseconds: 64));
      previousWidth = tester.getSize(address).width;
      expect(previousWidth, inExclusiveRange(collapsedWidth, expandedWidth));
      // Reverse while expansion is moving: target changes without snapping
      // geometry or resetting the state that owns the original velocity.
      engine.onChanged(_scroll(612));
      await tester.pump();
      expect(tester.getSize(address).width, closeTo(previousWidth, .01));
      for (var frame = 0; frame < 12; frame++) {
        engine.onChanged(BrowserPageState(progress: .5 + frame * .02));
        await tester.pump(const Duration(milliseconds: 16));
        final width = tester.getSize(address).width;
        expect((width - previousWidth).abs(), lessThan(travel * .15));
        expectIdentityAndGeometry();
        previousWidth = width;
      }
      await tester.pumpAndSettle();
      expect(tester.getSize(address).width, closeTo(collapsedWidth, .01));
      expect(tester.takeException(), isNull);
    },
  );

  browserTestWidgets(
    'optional top overlay does not remount or snap partially collapsed chrome',
    (tester) async {
      await service.initialize();
      await service.updateSettings(
        service.settings.copyWith(agentEnabled: true),
      );
      final tab = await service.createTab(
        url: 'https://example.com',
        ownerSessionId: 'chrome-test',
      );
      await mount(tester, conversationId: 'chrome-test');
      final engine = engines[tab.id]!;
      final chrome = find.byType(BrowserChromeTransition);
      final address = find.byType(BrowserAddressBar);
      final chromeState = tester.state(chrome);
      final addressElement = tester.element(address);
      final viewport = find.byKey(const ValueKey('fakeNativeView'));
      final viewportElement = tester.element(viewport);
      final viewportBounds = tester.getRect(viewport);
      final expandedWidth = tester.getSize(address).width;
      final frameSteps = <double>[];

      engine.onChanged(_scroll(18));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 32));
      final movingWidth = tester.getSize(address).width;
      expect(movingWidth, lessThan(expandedWidth));

      for (var change = 0; change < 6; change++) {
        final before = tester.getSize(address).width;
        if (change.isEven) {
          service.takeOver(sessionId: 'chrome-test', tabId: tab.id);
        } else {
          service.allowAgentControl(sessionId: 'chrome-test');
        }
        engine.onChanged(BrowserPageState(progress: .1 + change * .03));
        await tester.pump();
        expect(identical(tester.state(chrome), chromeState), isTrue);
        expect(identical(tester.element(address), addressElement), isTrue);
        expect(tester.getSize(address).width, closeTo(before, .01));
        expect(identical(tester.element(viewport), viewportElement), isTrue);
        expect(tester.getRect(viewport), viewportBounds);
        expect(engine.viewMounts, 1);
        expect(engine.viewDisposals, 0);
        engine.onChanged(_scroll(18 + (change + 1) * 3.0));
        await tester.pump(const Duration(milliseconds: 16));
        frameSteps.add((tester.getSize(address).width - before).abs());
      }
      engine.onChanged(_scroll(100));
      await tester.pumpAndSettle();
      final collapsedWidth = expectReadableCollapsedAddress(
        tester,
        address,
        expandedWidth,
      );
      final travel = expandedWidth - collapsedWidth;
      expect(movingWidth, greaterThan(collapsedWidth));
      for (final step in frameSteps) {
        expect(step, lessThan(travel * .25));
      }
      expect(tester.takeException(), isNull);
    },
  );

  browserTestWidgets(
    'forced chrome progress and reduced motion cancel an unfinished spring',
    (tester) async {
      Future<void> show({
        required double progress,
        bool animate = true,
        bool reducedMotion = false,
      }) => tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: BrowserChromeTransition(
              progress: progress,
              animate: animate,
              reducedMotion: reducedMotion,
              builder: (_, value) => SizedBox(
                key: const ValueKey('testChromeSize'),
                width: 200 - 100 * value,
                height: 34,
              ),
            ),
          ),
        ),
      );
      final size = find.byKey(const ValueKey('testChromeSize'));
      await show(progress: 0);
      final state = tester.state(find.byType(BrowserChromeTransition));
      await show(progress: .7);
      await tester.pump(const Duration(milliseconds: 32));
      expect(tester.getSize(size).width, inExclusiveRange(130, 200));
      await show(progress: 0, animate: false);
      expect(tester.getSize(size).width, 200);
      await tester.pumpAndSettle();
      expect(tester.getSize(size).width, 200);
      await show(progress: .8);
      await tester.pump(const Duration(milliseconds: 32));
      await show(progress: .4, reducedMotion: true);
      expect(tester.getSize(size).width, 160);
      await tester.pumpAndSettle();
      expect(tester.getSize(size).width, 160);
      expect(
        identical(tester.state(find.byType(BrowserChromeTransition)), state),
        isTrue,
      );
      expect(tester.takeException(), isNull);
    },
  );

  browserTestWidgets(
    'glass control follows drag then settles and honors reduced motion',
    (tester) async {
      Future<void> pumpGlass({required bool reduceMotion}) async {
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(disableAnimations: reduceMotion),
              child: const Scaffold(
                body: Center(
                  child: BrowserSpring(
                    child: BrowserGlass(
                      child: SizedBox(width: 160, height: 46),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }

      await pumpGlass(reduceMotion: false);
      final spring = find.byType(BrowserSpring);
      final start = tester.getCenter(spring);
      final gesture = await tester.startGesture(start);
      await gesture.moveBy(const Offset(20, 0));
      await gesture.moveBy(const Offset(70, 20));
      await tester.pump();
      final transform = tester.widget<Transform>(
        find.byKey(const ValueKey('browserSpringTransform')),
      );
      expect(transform.transform.storage[12], greaterThan(0));
      await gesture.up();
      await tester.pumpAndSettle();
      final settled = tester.widget<Transform>(
        find.byKey(const ValueKey('browserSpringTransform')),
      );
      expect(settled.transform.storage[12], closeTo(0, .05));
      await pumpGlass(reduceMotion: true);
      await tester.drag(spring, const Offset(70, 20));
      await tester.pumpAndSettle();
      final reduced = tester.widget<Transform>(
        find.byKey(const ValueKey('browserSpringTransform')),
      );
      expect(reduced.transform.storage[12], 0);
    },
  );
}

class _MemoryStore extends BrowserStore {
  _MemoryStore({this.readGate});
  final Future<void>? readGate;
  Map<String, dynamic> state = {};
  @override
  Future<Map<String, dynamic>> read() async {
    if (readGate != null) await readGate;
    return state;
  }

  @override
  Future<void> write(Map<String, Object?> value) async {
    state = Map<String, dynamic>.from(value);
  }
}

class _Engine extends BrowserEngine {
  _Engine(this.onChanged);
  final void Function(BrowserPageState) onChanged;
  Color backgroundColor = Colors.white;
  final List<String> navigations = [];
  int backCalls = 0;
  int forwardCalls = 0;
  int reloadCalls = 0;
  int viewMounts = 0;
  int humanPointerDowns = 0;
  int viewBuilds = 0;
  int viewDisposals = 0;
  Uint8List? previewBytes;
  int screenshotCalls = 0;
  Completer<void>? attachmentReady;
  @override
  Future<void> get viewReady => attachmentReady?.future ?? Future<void>.value();
  @override
  Widget buildView() => _EngineView(engine: this);
  @override
  Future<void> navigate(String url) async {
    navigations.add(url);
    onChanged(
      BrowserPageState(
        url: url,
        title: url == 'about:blank' ? '' : 'Website',
        isLoading: false,
        progress: 1,
      ),
    );
  }

  @override
  Future<void> loadHtml(String html, {String? baseUrl}) async {}
  @override
  Future<void> back() async {
    backCalls++;
    onChanged(const BrowserPageState(canGoBack: false));
  }

  @override
  Future<void> forward() async {
    forwardCalls++;
    onChanged(const BrowserPageState(canGoForward: false));
  }

  @override
  Future<void> reload() async {
    reloadCalls++;
  }

  @override
  Future<void> stop() async {}
  @override
  Future<void> waitForLoad(Duration timeout) async {}
  @override
  Future<Object?> evaluate(String source, {bool awaitPromise = false}) async =>
      null;
  @override
  Future<Uint8List?> screenshot() async {
    screenshotCalls++;
    return previewBytes;
  }

  @override
  Future<void> updateSettings(BrowserSettings settings) async {}
  @override
  Future<void> find(String text) async {}
  @override
  Future<void> findNext(bool forward) async {}
  @override
  Future<void> clearFind() async {}
  @override
  Future<Map<String, String>> downloadHeaders(String url) async => {};
  @override
  Future<void> pause() async {}
  @override
  Future<void> resume() async {}
  @override
  Future<void> dispose() async {}
}

class _EngineView extends StatefulWidget {
  const _EngineView({required this.engine});
  final _Engine engine;
  @override
  State<_EngineView> createState() => _EngineViewState();
}

class _EngineViewState extends State<_EngineView> {
  @override
  void initState() {
    super.initState();
    widget.engine.viewMounts++;
  }

  @override
  void dispose() {
    widget.engine.viewDisposals++;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    widget.engine.viewBuilds++;
    return Listener(
      onPointerDown: (_) => widget.engine.humanPointerDowns++,
      child: ColoredBox(
        key: const ValueKey('fakeNativeView'),
        color: widget.engine.backgroundColor,
        child: const Center(child: Text('Native website content')),
      ),
    );
  }
}
