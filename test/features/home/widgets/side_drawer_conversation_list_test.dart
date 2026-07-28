import 'dart:io';

import "../../../support/business_test_harness.dart";
import 'package:Kelivo/core/providers/assistant_provider.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/providers/update_provider.dart';
import 'package:Kelivo/core/services/chat/chat_service.dart';
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

  void poke() => notifyListeners();

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

  Future<void> pumpDrawer(WidgetTester tester, ChatService service) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<ChatService>.value(value: service),
          ChangeNotifierProvider(
            create: (_) => SettingsProvider(createBusinessTestPreferences()),
          ),
          ChangeNotifierProvider(
            create: (_) =>
                AssistantProvider(preferences: createBusinessTestPreferences()),
          ),
          ChangeNotifierProvider(create: (_) => UpdateProvider()),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SideDrawer(
              userName: 'User',
              assistantName: 'Assistant',
              embedded: true,
              desktopTopicsOnly: true,
              showBottomBar: false,
            ),
          ),
        ),
      ),
    );
    // Let providers finish their async loads, then settle animations.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
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
      final service = createService();
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

      // The prefetch chains several sequential database hops; each hop needs
      // a real-async window (isolate round trip) followed by a pump (fake-zone
      // continuation microtasks).
      for (var i = 0; i < 20; i++) {
        if (service.isConversationFullyCached(alphaId)) break;
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 100)),
        );
        await tester.pump();
      }
      expect(service.isConversationFullyCached(alphaId), isTrue);
      expect(service.notifyCount, notifyBefore);

      await gesture.removePointer();
    });
  });
}
