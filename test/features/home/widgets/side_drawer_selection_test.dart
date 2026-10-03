import 'dart:async';
import 'dart:io';

import "../../../support/business_test_harness.dart";
import 'package:Kelivo/core/providers/assistant_provider.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/providers/update_provider.dart';
import 'package:Kelivo/core/providers/backup_reminder_provider.dart';
import 'package:Kelivo/core/providers/tag_provider.dart';
import 'package:Kelivo/core/providers/user_provider.dart';
import 'package:Kelivo/core/services/chat/chat_service.dart';
import 'package:Kelivo/core/models/conversation.dart';
import 'package:Kelivo/features/home/widgets/side_drawer.dart';
import 'package:Kelivo/features/home/widgets/sidebar_selection_bars.dart';
import 'package:Kelivo/features/stats/pages/stats_page.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/widgets/snackbar.dart';
import 'package:flutter/foundation.dart';
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

  void seedConversationsForTest(List<Conversation> conversations) {
    _stubConversations = conversations;
    _stubRevision = (_stubRevision ?? super.conversationListRevision) + 1;
    notifyListeners();
  }

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
      'kelivo_side_drawer_selection_test_',
    );
    PathProviderPlatform.instance = _FakePathProviderPlatform(tempDir.path);
    SideDrawer.debugConversationListBuildCount = 0;
    SideDrawer.debugSidebarRowsComputeCount = 0;
    SideDrawer.debugRequestConversationListHostRebuild = null;
    SideDrawer.debugEnterSelectionMode = null;
    AppSnackBarManager().dismissAll();
  });

  tearDown(() async {
    AppSnackBarManager().dismissAll();
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
    bool embedded = true,
    bool showBottomBar = false,
    Size physicalSize = const Size(1200, 900),
    FutureOr<void> Function(String id, {bool closeDrawer})?
    onSelectConversation,
  }) async {
    tester.view.physicalSize = physicalSize;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final settingsPrefs = createBusinessTestPreferences();
    final assistantPrefs = createBusinessTestPreferences();
    final backupPrefs = createBusinessTestPreferences();
    final tagPrefs = createBusinessTestPreferences();
    final userPrefs = createBusinessTestPreferences();
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
            embedded: embedded,
            desktopTopicsOnly: desktopTopicsOnly,
            desktopAssistantsOnly: desktopAssistantsOnly,
            globalSearchMode: globalSearchMode,
            globalSearchQuery: globalSearchQuery,
            showBottomBar: showBottomBar,
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
          ChangeNotifierProvider(
            create: (_) => UserProvider(preferences: userPrefs),
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

  testWidgets('mobile bottom bar opens the statistics page', (tester) async {
    final service = createService();
    await tester.runAsync(service.init);

    await pumpDrawer(
      tester,
      service,
      desktopTopicsOnly: false,
      embedded: false,
      showBottomBar: true,
      physicalSize: const Size(390, 844),
    );

    final statsButton = find.byKey(
      const ValueKey<String>('sidebar-stats-button'),
    );
    expect(statsButton, findsOneWidget);

    await tester.tap(statsButton);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(StatsPage), findsOneWidget);
    expect(find.text('Statistics'), findsOneWidget);
  });

  testWidgets(
    'entering selection does not recompute sidebar rows or bump revision',
    (tester) async {
      await asDesktop(() async {
        final service = createService();
        late final String alphaId;
        await tester.runAsync(() async {
          await service.init();
          alphaId = (await service.createConversation(title: 'Alpha')).id;
          await service.createConversation(title: 'Beta');
        });
        await pumpDrawer(tester, service);
        expect(find.text('Alpha'), findsOneWidget);

        final computes = SideDrawer.debugSidebarRowsComputeCount;
        final revision = service.conversationListRevision;
        expect(SideDrawer.debugEnterSelectionMode, isNotNull);

        SideDrawer.debugEnterSelectionMode!(alphaId);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        expect(SideDrawer.debugSidebarRowsComputeCount, computes);
        expect(service.conversationListRevision, revision);
        expect(find.byType(SidebarSelectionHeader), findsOneWidget);
      });
    },
  );

  testWidgets(
    'multi-select delete removes conversations with one ChatService notify',
    (tester) async {
      await asDesktop(() async {
        final service = createService();
        late final String alphaId;
        await tester.runAsync(() async {
          await service.init();
          alphaId = (await service.createConversation(title: 'Alpha')).id;
          await service.createConversation(title: 'Beta');
          await service.createConversation(title: 'Gamma');
        });
        await pumpDrawer(tester, service);
        expect(find.text('Alpha'), findsOneWidget);
        expect(find.text('Beta'), findsOneWidget);
        expect(find.text('Gamma'), findsOneWidget);

        final l10n = AppLocalizations.of(
          tester.element(find.byType(SideDrawer)),
        )!;
        final notifyBaseline = service.notifyCount;

        SideDrawer.debugEnterSelectionMode!(alphaId);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        expect(find.text(l10n.sideDrawerSelectionTitle(1)), findsOneWidget);

        await tester.tap(find.text('Beta'));
        await tester.pump();
        expect(find.text(l10n.sideDrawerSelectionTitle(2)), findsOneWidget);

        await tester.tap(find.text(l10n.sideDrawerSelectionSelectAll));
        await tester.pump();
        expect(find.text(l10n.sideDrawerSelectionTitle(3)), findsOneWidget);
        expect(find.text(l10n.sideDrawerSelectionDeselectAll), findsOneWidget);

        final notifyBeforeDelete = service.notifyCount;
        expect(notifyBeforeDelete, notifyBaseline);

        await tester.tap(find.text(l10n.sideDrawerSelectionDelete).first);
        await tester.pumpAndSettle();
        expect(
          find.text(l10n.sideDrawerSelectionDeleteConfirmTitle),
          findsOneWidget,
        );
        expect(find.byType(AlertDialog), findsOneWidget);

        final confirmButton = find.descendant(
          of: find.byType(AlertDialog),
          matching: find.widgetWithText(
            TextButton,
            l10n.sideDrawerSelectionDelete,
          ),
        );
        expect(confirmButton, findsOneWidget);
        await tester.tap(confirmButton);
        await tester.pump();
        // deleteConversations does sqlite + asset-maintenance dart:io; those
        // hops complete in the real async zone and need interleaved pumps.
        for (var i = 0; i < 40; i++) {
          if (service.notifyCount > notifyBeforeDelete) break;
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 50)),
          );
          await tester.pump();
        }
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pump(const Duration(seconds: 3));
        await tester.pumpAndSettle();

        expect(service.notifyCount, notifyBeforeDelete + 1);
        expect(service.getConversation(alphaId), isNull);
        expect(find.text('Alpha'), findsNothing);
        expect(find.text('Beta'), findsNothing);
        expect(find.text('Gamma'), findsNothing);
        expect(find.byType(SidebarSelectionHeader), findsNothing);
      });
    },
  );

  testWidgets(
    'external delete updates selection header count and disables empty actions',
    (tester) async {
      await asDesktop(() async {
        final service = createService();
        late final String alphaId;
        late final String betaId;
        await tester.runAsync(() async {
          await service.init();
          alphaId = (await service.createConversation(title: 'Alpha')).id;
          betaId = (await service.createConversation(title: 'Beta')).id;
        });
        await pumpDrawer(tester, service);

        final l10n = AppLocalizations.of(
          tester.element(find.byType(SideDrawer)),
        )!;

        SideDrawer.debugEnterSelectionMode!(alphaId);
        await tester.pump();
        await tester.tap(find.text('Beta'));
        await tester.pump();
        expect(find.text(l10n.sideDrawerSelectionTitle(2)), findsOneWidget);
        expect(
          tester
              .widget<SidebarSelectionActionBar>(
                find.byType(SidebarSelectionActionBar),
              )
              .selectedCount,
          2,
        );

        await tester.runAsync(() => service.deleteConversation(alphaId));
        for (var i = 0; i < 40; i++) {
          if (service.getConversation(alphaId) == null) break;
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 50)),
          );
          await tester.pump();
        }
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        expect(find.text('Alpha'), findsNothing);
        expect(find.text('Beta'), findsOneWidget);
        expect(find.text(l10n.sideDrawerSelectionTitle(1)), findsOneWidget);
        expect(find.text(l10n.sideDrawerSelectionTitle(2)), findsNothing);
        expect(
          tester
              .widget<SidebarSelectionActionBar>(
                find.byType(SidebarSelectionActionBar),
              )
              .selectedCount,
          1,
        );

        await tester.runAsync(() => service.deleteConversation(betaId));
        for (var i = 0; i < 40; i++) {
          if (service.getConversation(betaId) == null) break;
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 50)),
          );
          await tester.pump();
        }
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        expect(find.text(l10n.sideDrawerSelectionTitle(0)), findsOneWidget);
        expect(
          tester
              .widget<SidebarSelectionActionBar>(
                find.byType(SidebarSelectionActionBar),
              )
              .selectedCount,
          0,
        );
      });
    },
  );
}
