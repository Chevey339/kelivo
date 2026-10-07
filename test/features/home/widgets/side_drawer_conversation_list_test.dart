import 'dart:async';
import 'dart:io';

import "../../../support/business_test_harness.dart";
import 'package:Kelivo/core/providers/assistant_provider.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/providers/update_provider.dart';
import 'package:Kelivo/core/providers/backup_reminder_provider.dart';
import 'package:Kelivo/core/providers/tag_provider.dart';
import 'package:Kelivo/core/services/chat/chat_service.dart';
import 'package:Kelivo/core/models/conversation.dart';
import 'package:Kelivo/features/home/widgets/side_drawer.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:provider/provider.dart';

class _FakePathProviderPlatform extends PathProviderPlatform {
  _FakePathProviderPlatform(this.path);

  final String path;

  @override
  Future<String?> getApplicationDocumentsPath() async => path;

  @override
  Future<String?> getApplicationSupportPath() async => path;

  @override
  Future<String?> getApplicationCachePath() async => '$path/cache';

  @override
  Future<String?> getTemporaryPath() async => '$path/tmp';
}

class _TestChatService extends ChatService {
  final List<String> timelineCalls = <String>[];
  int notifyCount = 0;
  List<Conversation>? _stubConversations;
  int? _stubRevision;
  bool? _stubInitialized;

  void poke() => notifyListeners();

  /// Seeds thousands of conversations without per-item persistence I/O.
  void seedConversationsForTest(List<Conversation> conversations) {
    _stubConversations = conversations;
    _stubRevision = (_stubRevision ?? super.conversationListRevision) + 1;
    notifyListeners();
  }

  /// Reproduces startup ordering: summaries and their revision are published
  /// before the service flips its public initialized flag.
  void stageConversationsBeforeInitialization(
    List<Conversation> conversations,
  ) {
    _stubConversations = conversations;
    _stubRevision = (_stubRevision ?? super.conversationListRevision) + 1;
    _stubInitialized = false;
  }

  void completeInitializationForTest() {
    _stubInitialized = true;
    notifyListeners();
  }

  @override
  bool get initialized => _stubInitialized ?? super.initialized;

  @override
  int get conversationListRevision =>
      _stubRevision ?? super.conversationListRevision;

  @override
  List<Conversation> getAllConversations() {
    if (_stubConversations != null) {
      if (_stubInitialized == false) return const <Conversation>[];
      return List<Conversation>.of(_stubConversations!);
    }
    return super.getAllConversations();
  }

  @override
  void notifyListeners() {
    notifyCount++;
    super.notifyListeners();
  }

  @override
  Future<LoadedTimelinePage?> loadTimelinePage(
    String conversationId, {
    String? beforeRevisionId,
    String? afterRevisionId,
    String? aroundRevisionId,
    bool fromStart = false,
    int limit = 40,
  }) {
    timelineCalls.add(conversationId);
    return super.loadTimelinePage(
      conversationId,
      beforeRevisionId: beforeRevisionId,
      afterRevisionId: afterRevisionId,
      aroundRevisionId: aroundRevisionId,
      fromStart: fromStart,
      limit: limit,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  final services = <ChatService>[];

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp(
      'kelivo_side_drawer_list_test_',
    );
    PathProviderPlatform.instance = _FakePathProviderPlatform(tempDir.path);
    SideDrawer.debugConversationListBuildCount = 0;
    SideDrawer.debugSidebarRowsComputeCount = 0;
    SideDrawer.debugRequestConversationListHostRebuild = null;
  });

  tearDown(() async {
    for (final service in services) {
      await service.close();
    }
    services.clear();
    await Hive.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  _TestChatService createService() {
    final service = _TestChatService();
    services.add(service);
    return service;
  }

  // The drawer only enables topics-only mode and hover prefetch on desktop;
  // the platform override must be reset inside the test body because the
  // binding verifies foundation debug variables before package:test tearDowns.
  Future<void> asDesktop(Future<void> Function() body) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    try {
      await body();
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  }

  Future<void> pumpDrawer(
    WidgetTester tester,
    ChatService service, {
    bool desktopTopicsOnly = true,
    bool desktopAssistantsOnly = false,
    bool globalSearchMode = false,
    String globalSearchQuery = '',
    Locale locale = const Locale('en'),
    ValueNotifier<Locale>? localeListenable,
    bool showChatListDate = false,
    FutureOr<void> Function(String id, {bool closeDrawer})?
    onSelectConversation,
  }) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final settingsPrefs = createBusinessTestPreferences();
    final assistantPrefs = createBusinessTestPreferences();
    final backupPrefs = createBusinessTestPreferences();
    final tagPrefs = createBusinessTestPreferences();
    final settings = SettingsProvider(settingsPrefs);
    Widget materialFor(Locale currentLocale) {
      return MaterialApp(
        locale: currentLocale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SideDrawer(
            userName: 'User',
            assistantName: 'Assistant',
            embedded: true,
            desktopTopicsOnly: desktopTopicsOnly,
            desktopAssistantsOnly: desktopAssistantsOnly,
            globalSearchMode: globalSearchMode,
            globalSearchQuery: globalSearchQuery,
            showBottomBar: false,
            onSelectConversation: onSelectConversation,
          ),
        ),
      );
    }

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<ChatService>.value(value: service),
          ChangeNotifierProvider<SettingsProvider>.value(value: settings),
          ChangeNotifierProvider(
            create: (_) => AssistantProvider(preferences: assistantPrefs),
          ),
          ChangeNotifierProvider(
            create: (_) => BackupReminderProvider(preferences: backupPrefs),
          ),
          ChangeNotifierProvider(
            create: (_) => TagProvider(preferences: tagPrefs),
          ),
          ChangeNotifierProvider(create: (_) => UpdateProvider()),
        ],
        child: localeListenable == null
            ? materialFor(locale)
            : ValueListenableBuilder<Locale>(
                valueListenable: localeListenable,
                builder: (_, currentLocale, __) => materialFor(currentLocale),
              ),
      ),
    );
    // Let providers finish their async loads, then settle animations.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
    await tester.pump();
    if (showChatListDate) {
      await tester.runAsync(() async {
        await settings.loaded;
        await settings.setShowChatListDate(true);
      });
      await tester.pump();
    }
    await tester.pump(const Duration(milliseconds: 400));
  }

  Finder drawerScrollable(WidgetTester tester) {
    // Prefer the onstage conversation ListView. PageTransitionSwitcher can
    // keep an offstage prior ListView; pick the one with the largest extent.
    final listViews = find.descendant(
      of: find.byType(SideDrawer),
      matching: find.byType(ListView),
    );
    final elements = listViews.evaluate().toList();
    expect(elements, isNotEmpty, reason: 'expected a conversation ListView');
    Element best = elements.first;
    var bestExtent = -1.0;
    for (final element in elements) {
      final scrollableFinder = find.descendant(
        of: find.byWidget(element.widget),
        matching: find.byType(Scrollable),
      );
      if (scrollableFinder.evaluate().isEmpty) continue;
      final extent = tester
          .state<ScrollableState>(scrollableFinder)
          .position
          .maxScrollExtent;
      if (extent >= bestExtent) {
        bestExtent = extent;
        best = element;
      }
    }
    return find
        .descendant(
          of: find.byWidget(best.widget),
          matching: find.byType(Scrollable),
        )
        .first;
  }

  testWidgets('list does not rebuild on unrelated ChatService notify', (
    tester,
  ) async {
    await asDesktop(() async {
      final service = createService();
      await tester.runAsync(() async {
        await service.init();
        await service.createConversation(title: 'Alpha');
        await service.createConversation(title: 'Beta');
      });
      await pumpDrawer(tester, service);
      expect(find.text('Alpha'), findsOneWidget);
      expect(find.text('Beta'), findsOneWidget);

      final builds = SideDrawer.debugConversationListBuildCount;
      service.poke();
      await tester.pump();

      expect(SideDrawer.debugConversationListBuildCount, builds);
    });
  });

  testWidgets('list rebuilds when the conversation list revision changes', (
    tester,
  ) async {
    await asDesktop(() async {
      final service = createService();
      await tester.runAsync(() async {
        await service.init();
        await service.createConversation(title: 'Alpha');
        await service.createConversation(title: 'Beta');
      });
      await pumpDrawer(tester, service);
      expect(find.text('Alpha'), findsOneWidget);

      final alpha = service.getAllConversations().firstWhere(
        (c) => c.title == 'Alpha',
      );
      final builds = SideDrawer.debugConversationListBuildCount;
      await tester.runAsync(
        () => service.renameConversation(alpha.id, 'Alpha2'),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(SideDrawer.debugConversationListBuildCount, greaterThan(builds));
      expect(find.text('Alpha2'), findsOneWidget);
      expect(find.text('Alpha'), findsNothing);
    });
  });

  testWidgets(
    'topics appear when initialization completes after revision is published',
    (tester) async {
      await asDesktop(() async {
        final service = createService();
        service.stageConversationsBeforeInitialization([
          Conversation(title: 'Recovered topic'),
        ]);

        await pumpDrawer(tester, service);
        expect(find.text('Recovered topic'), findsNothing);
        final computesBeforeReady = SideDrawer.debugSidebarRowsComputeCount;

        service.completeInitializationForTest();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        expect(find.text('Recovered topic'), findsOneWidget);
        expect(
          SideDrawer.debugSidebarRowsComputeCount,
          greaterThan(computesBeforeReady),
        );
      });
    },
  );

  testWidgets('switching the selected conversation does not rebuild the list', (
    tester,
  ) async {
    await asDesktop(() async {
      final service = createService();
      await tester.runAsync(() async {
        await service.init();
        await service.createConversation(title: 'Alpha');
        await service.createConversation(title: 'Beta');
      });
      await pumpDrawer(tester, service);

      final alpha = service.getAllConversations().firstWhere(
        (c) => c.title == 'Alpha',
      );
      expect(service.currentConversationId, isNot(alpha.id));
      final builds = SideDrawer.debugConversationListBuildCount;
      service.setCurrentConversation(alpha.id);
      await tester.pump();

      expect(service.currentConversationId, alpha.id);
      expect(SideDrawer.debugConversationListBuildCount, builds);
    });
  });

  testWidgets('desktop hover prefetches the tail window without notifying', (
    tester,
  ) async {
    await asDesktop(() async {
      var service = createService();
      late final String alphaId;
      await tester.runAsync(() async {
        await service.init();
        final alpha = await service.createConversation(title: 'Alpha');
        alphaId = alpha.id;
        for (var i = 0; i < 3; i++) {
          await service.addMessage(
            conversationId: alpha.id,
            role: i.isEven ? 'user' : 'assistant',
            content: 'message $i',
          );
        }
        // The most recently created conversation becomes the current one, so
        // Alpha is a non-current hover target.
        await service.createConversation(title: 'Beta');
        await service.close();
        service = createService();
        await service.init();
      });
      await pumpDrawer(tester, service);
      expect(service.isConversationFullyCached(alphaId), isFalse);

      final notifyBefore = service.notifyCount;
      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset.zero);
      await gesture.moveTo(tester.getCenter(find.text('Alpha')));
      await tester.pump();

      expect(service.timelineCalls, contains(alphaId));
      expect(service.notifyCount, notifyBefore);

      // The cold index install and prefetch chain sequential database hops; each needs
      // a real-async window (isolate round trip) followed by a pump (fake-zone
      // continuation microtasks).
      for (var i = 0; i < 80; i++) {
        if (service.isConversationFullyCached(alphaId)) break;
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 100)),
        );
        await tester.pump();
      }
      expect(
        service.isConversationFullyCached(alphaId),
        isTrue,
        reason:
            'count=${service.getMessageCount(alphaId)}, '
            'cached=${service.getMessages(alphaId).length}',
      );
      expect(service.notifyCount, notifyBefore);

      await gesture.removePointer();
    });
  });

  testWidgets(
    'sidebar rows recompute when memo key changes but not on host rebuild',
    (tester) async {
      await asDesktop(() async {
        final service = createService();
        await tester.runAsync(() async {
          await service.init();
          await service.createConversation(title: 'Alpha');
          await service.createConversation(title: 'Beta');
        });
        await pumpDrawer(tester, service);
        expect(find.text('Alpha'), findsOneWidget);

        final computes = SideDrawer.debugSidebarRowsComputeCount;
        expect(computes, greaterThan(0));

        // Host setState without changing
        // (revision, initialized, query, assistantId).
        final rebuild = SideDrawer.debugRequestConversationListHostRebuild;
        expect(rebuild, isNotNull);
        rebuild!();
        await tester.pump();
        expect(SideDrawer.debugSidebarRowsComputeCount, computes);

        final alpha = service.getAllConversations().firstWhere(
          (c) => c.title == 'Alpha',
        );
        await tester.runAsync(() => service.togglePinConversation(alpha.id));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(SideDrawer.debugSidebarRowsComputeCount, greaterThan(computes));
      });
    },
  );

  testWidgets('pin moves a conversation into the pinned section', (
    tester,
  ) async {
    await asDesktop(() async {
      final service = createService();
      await tester.runAsync(() async {
        await service.init();
        await service.createConversation(title: 'Alpha');
        await service.createConversation(title: 'Beta');
      });
      await pumpDrawer(tester, service);

      final l10n = AppLocalizations.of(
        tester.element(find.byType(SideDrawer)),
      )!;
      expect(find.text(l10n.sideDrawerPinnedLabel), findsNothing);

      final alpha = service.getAllConversations().firstWhere(
        (c) => c.title == 'Alpha',
      );
      await tester.runAsync(() => service.togglePinConversation(alpha.id));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text(l10n.sideDrawerPinnedLabel), findsOneWidget);
      expect(find.text('Alpha'), findsOneWidget);
      expect(find.text('Beta'), findsOneWidget);
      expect(service.getConversation(alpha.id)!.isPinned, isTrue);

      await tester.runAsync(() => service.togglePinConversation(alpha.id));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text(l10n.sideDrawerPinnedLabel), findsNothing);
      expect(find.text('Alpha'), findsOneWidget);
      expect(service.getConversation(alpha.id)!.isPinned, isFalse);
    });
  });

  testWidgets(
    'virtualized conversation list builds only viewport-constrained tiles',
    (tester) async {
      await asDesktop(() async {
        final service = createService();
        await tester.runAsync(() => service.init());
        final now = DateTime.now();
        const total = 2000;
        service.seedConversationsForTest([
          for (var i = 0; i < total; i++)
            Conversation(
              id: 'c-$i',
              title: 'Chat $i',
              // Newer first in getAllConversations sort via updatedAt.
              // Seconds keep the bulk of rows in one local-day group.
              updatedAt: now.subtract(Duration(seconds: i)),
              createdAt: now.subtract(Duration(seconds: i)),
            ),
        ]);
        await pumpDrawer(tester, service);

        final tileCount = find
            .byType(SideDrawer.debugChatTileType)
            .evaluate()
            .length;
        expect(tileCount, greaterThan(0));
        expect(tileCount, lessThan(80));
        expect(tileCount, lessThan(total ~/ 4));

        // Top of the list is visible; far rows are not built yet.
        expect(find.text('Chat 0'), findsOneWidget);
        expect(find.text('Chat ${total - 1}'), findsNothing);
      });
    },
  );

  test('capped stagger delay plateaus for deep absolute indices', () {
    // Date-group step 16ms; pinned step 20ms; cap index 7 → 112ms / 140ms.
    expect(
      SideDrawer.debugSidebarTileStaggerDelay(
        indexInSection: 0,
        pinnedSection: false,
      ),
      Duration.zero,
    );
    expect(
      SideDrawer.debugSidebarTileStaggerDelay(
        indexInSection: 7,
        pinnedSection: false,
      ),
      const Duration(milliseconds: 112),
    );
    expect(
      SideDrawer.debugSidebarTileStaggerDelay(
        indexInSection: 1000,
        pinnedSection: false,
      ),
      const Duration(milliseconds: 112),
    );
    expect(
      SideDrawer.debugSidebarTileStaggerDelay(
        indexInSection: 1000,
        pinnedSection: true,
      ),
      const Duration(milliseconds: 140),
    );
    // Uncapped absolute index 1000 would be multi-second; cap stays ≤160ms.
    expect(
      SideDrawer.debugSidebarTileStaggerDelay(
        indexInSection: 1000,
        pinnedSection: true,
      ).inMilliseconds,
      lessThanOrEqualTo(160),
    );
  });

  testWidgets('scroll to end keeps last tile tappable with correct id', (
    tester,
  ) async {
    await asDesktop(() async {
      final service = createService();
      await tester.runAsync(() => service.init());
      final now = DateTime.now();
      const total = 2000;
      String? selectedId;
      service.seedConversationsForTest([
        for (var i = 0; i < total; i++)
          Conversation(
            id: 'c-$i',
            title: 'Chat $i',
            updatedAt: now.subtract(Duration(seconds: i)),
            createdAt: now.subtract(Duration(seconds: i)),
          ),
      ]);
      await pumpDrawer(
        tester,
        service,
        onSelectConversation: (id, {closeDrawer = true}) async {
          selectedId = id;
        },
      );

      expect(find.text('Chat 0'), findsOneWidget);
      // Tap near the top first to prove selection wiring, then scroll away.
      await tester.tap(find.text('Chat 0'));
      await tester.pump();
      expect(selectedId, 'c-0');

      final scrollable = drawerScrollable(tester);
      final position = tester.state<ScrollableState>(scrollable).position;
      expect(position.maxScrollExtent, greaterThan(0));
      position.jumpTo(position.maxScrollExtent);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // Top item is gone; a far chat title remains in the built viewport.
      expect(find.text('Chat 0'), findsNothing);
      final farIndexes = find
          .byType(Text)
          .evaluate()
          .map((e) => (e.widget as Text).data)
          .whereType<String>()
          .map((t) => RegExp(r'^Chat (\d+)$').firstMatch(t))
          .whereType<RegExpMatch>()
          .map((m) => int.parse(m.group(1)!))
          .toList();
      expect(farIndexes, isNotEmpty);
      expect(
        farIndexes.reduce((a, b) => a > b ? a : b),
        greaterThan(total ~/ 2),
      );
      expect(find.byType(SideDrawer.debugChatTileType), findsWidgets);
    });
  });

  testWidgets(
    'locale switch relocalizes headers without recomputing rows or jumping scroll',
    (tester) async {
      await asDesktop(() async {
        final service = createService();
        await tester.runAsync(() => service.init());
        final now = DateTime.now();
        service.seedConversationsForTest([
          Conversation(
            id: 'pin-1',
            title: 'Pinned Chat',
            isPinned: true,
            updatedAt: now,
            createdAt: now,
          ),
          Conversation(
            id: 'today-1',
            title: 'Today Chat',
            updatedAt: now,
            createdAt: now,
          ),
          Conversation(
            id: 'today-2',
            title: 'Today Chat 2',
            updatedAt: now.subtract(const Duration(minutes: 1)),
            createdAt: now.subtract(const Duration(minutes: 1)),
          ),
        ]);
        final localeListenable = ValueNotifier<Locale>(const Locale('en'));
        addTearDown(localeListenable.dispose);
        // Pinned header is enough to prove locale is resolved at render time
        // (not memoized into row labels). Avoid showChatListDate prefs I/O.
        await pumpDrawer(tester, service, localeListenable: localeListenable);

        final en = await AppLocalizations.delegate.load(const Locale('en'));
        final zh = await AppLocalizations.delegate.load(const Locale('zh'));
        expect(find.text(en.sideDrawerPinnedLabel), findsOneWidget);
        expect(find.text('Pinned Chat'), findsOneWidget);
        expect(find.text('Today Chat'), findsOneWidget);

        final computesBefore = SideDrawer.debugSidebarRowsComputeCount;
        final offsetBefore = tester
            .state<ScrollableState>(drawerScrollable(tester))
            .position
            .pixels;
        final tileCountBefore = find
            .byType(SideDrawer.debugChatTileType)
            .evaluate()
            .length;

        localeListenable.value = const Locale('zh');
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        expect(find.text(zh.sideDrawerPinnedLabel), findsOneWidget);
        expect(find.text(en.sideDrawerPinnedLabel), findsNothing);
        expect(SideDrawer.debugSidebarRowsComputeCount, computesBefore);
        expect(
          find.byType(SideDrawer.debugChatTileType).evaluate().length,
          tileCountBefore,
        );
        expect(find.text('Pinned Chat'), findsOneWidget);
        expect(find.text('Today Chat'), findsOneWidget);
        expect(find.text('Today Chat 2'), findsOneWidget);
        expect(
          tester
              .state<ScrollableState>(drawerScrollable(tester))
              .position
              .pixels,
          offsetBefore,
        );

        localeListenable.value = const Locale('en');
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        expect(find.text(en.sideDrawerPinnedLabel), findsOneWidget);
        expect(find.text(zh.sideDrawerPinnedLabel), findsNothing);
        expect(SideDrawer.debugSidebarRowsComputeCount, computesBefore);
        expect(
          tester
              .state<ScrollableState>(drawerScrollable(tester))
              .position
              .pixels,
          offsetBefore,
        );
      });
    },
  );

  testWidgets('topicsOnly mode renders the conversation list without errors', (
    tester,
  ) async {
    await asDesktop(() async {
      final service = createService();
      await tester.runAsync(() async {
        await service.init();
        await service.createConversation(title: 'Topic A');
      });
      await pumpDrawer(tester, service, desktopTopicsOnly: true);
      expect(tester.takeException(), isNull);
      expect(find.text('Topic A'), findsOneWidget);
      expect(find.byType(SideDrawer), findsOneWidget);
    });
  });

  testWidgets('assistOnly mode renders without errors', (tester) async {
    await asDesktop(() async {
      final service = createService();
      await tester.runAsync(() => service.init());
      await pumpDrawer(
        tester,
        service,
        desktopTopicsOnly: false,
        desktopAssistantsOnly: true,
      );
      expect(tester.takeException(), isNull);
      expect(find.byType(SideDrawer), findsOneWidget);
      // Assistants path must not mount conversation tiles.
      expect(find.byType(SideDrawer.debugChatTileType), findsNothing);
    });
  });

  testWidgets(
    'global search mode uses its independent results path without errors',
    (tester) async {
      await asDesktop(() async {
        final service = createService();
        await tester.runAsync(() async {
          await service.init();
          await service.createConversation(title: 'Should Not Appear As Tile');
        });
        await pumpDrawer(
          tester,
          service,
          desktopTopicsOnly: false,
          globalSearchMode: true,
        );
        expect(tester.takeException(), isNull);
        expect(find.byType(SideDrawer), findsOneWidget);
        // Independent path: conversation tiles from the topics list are absent.
        expect(find.byType(SideDrawer.debugChatTileType), findsNothing);
        final l10n = AppLocalizations.of(
          tester.element(find.byType(SideDrawer)),
        )!;
        expect(find.text(l10n.sideDrawerGlobalSearchEmptyHint), findsOneWidget);
      });
    },
  );
}
