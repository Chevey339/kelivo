import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:Kelivo/core/providers/assistant_provider.dart';
import 'package:Kelivo/core/providers/instruction_injection_provider.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/providers/world_book_provider.dart';
import 'package:Kelivo/core/services/chat/chat_service.dart';
import 'package:Kelivo/features/chat/widgets/context_management_sheet.dart';
import 'package:Kelivo/features/chat/widgets/context_dialog.dart';
import 'package:Kelivo/features/chat/widgets/context_usage_header.dart';
import 'package:Kelivo/features/home/services/context_usage_service.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/widgets/context_usage_ring.dart';

import '../../../support/business_test_harness.dart';

class _RecordingUsage extends ContextUsageService {
  _RecordingUsage({
    required super.chatService,
    required super.settings,
    required super.assistants,
    required super.instructions,
    required super.worldBooks,
  });

  ContextUsageSnapshot? seeded;
  int refreshCalls = 0;
  String? lastDraft;
  bool? lastForce;

  @override
  ContextUsageSnapshot? get current => seeded;

  @override
  ContextUsageSnapshot? snapshot(String conversationId) => seeded;

  @override
  Future<void> refresh(
    String conversationId, {
    String? draftText,
    bool force = false,
  }) async {
    refreshCalls++;
    lastDraft = draftText;
    lastForce = force;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('header renders and triggers refresh on open', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(393, 852);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final settings = SettingsProvider(createBusinessTestPreferences());
    final assistants = AssistantProvider(
      preferences: createBusinessTestPreferences(),
    );
    await settings.loaded;
    await assistants.loaded;
    final instructions = InstructionInjectionProvider(
      preferences: createBusinessTestPreferences(),
    );
    final worldBooks = WorldBookProvider(
      preferences: createBusinessTestPreferences(),
    );
    final chat = ChatService();
    final usage = _RecordingUsage(
      chatService: chat,
      settings: settings,
      assistants: assistants,
      instructions: instructions,
      worldBooks: worldBooks,
    );
    usage.seeded = ContextUsageSnapshot(
      state: ContextUsageState.estimated,
      buckets: const ContextUsageBuckets(
        system: 12,
        injections: 0,
        history: 40,
        tools: 0,
        attachments: 0,
        draft: 5,
      ),
      usedTokens: 57,
      contextWindow: 1000,
      conversationId: 'c1',
      revision: 1,
      providerKey: 'TestProvider',
      modelId: 'window-model',
      assistantId: null,
      computedAt: DateTime.utc(2026, 1, 1),
    );
    addTearDown(assistants.dispose);
    addTearDown(settings.dispose);
    addTearDown(instructions.dispose);
    addTearDown(worldBooks.dispose);
    addTearDown(usage.dispose);

    var operationsOpened = 0;
    var imagesOpened = 0, compressionsOpened = 0, clears = 0;
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SettingsProvider>.value(value: settings),
          ChangeNotifierProvider<AssistantProvider>.value(value: assistants),
          ChangeNotifierProvider<ChatService>.value(value: chat),
          ChangeNotifierProvider<ContextUsageService>.value(value: usage),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: ContextManagementSheet(
              conversationId: 'c1',
              draftText: 'draft',
              onOperations: () => operationsOpened++,
              onImages: () => imagesOpened++,
              onCompress: () => compressionsOpened++,
              onClear: () => clears++,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    for (final row in find.byType(ContextActionRow).evaluate()) {
      expect(
        tester.getSize(find.byWidget(row.widget)).height,
        lessThanOrEqualTo(64),
      );
    }
    expect(
      find.byKey(const ValueKey('context-usage-bucket-history')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('context-usage-toggle-details')),
      findsNothing,
    );
    expect(find.text('For this conversation'), findsNothing);
    expect(find.text('Clear Context').hitTestable(), findsOneWidget);
    final l10n = AppLocalizations.of(
      tester.element(find.byType(ContextManagementSheet)),
    )!;
    await tester.tap(find.text(l10n.imageContextTitle));
    await tester.tap(find.text(l10n.compressContext));
    await tester.tap(find.text(l10n.bottomToolsSheetClearContext));
    expect(imagesOpened, 1);
    expect(compressionsOpened, 1);
    expect(clears, 1);

    await tester.ensureVisible(find.text('Compression and clear history'));
    await tester.tap(find.text('Compression and clear history'));
    expect(operationsOpened, 1);

    expect(find.byType(ContextUsageHeader), findsOneWidget);
    expect(find.byType(ContextUsageRing), findsNothing);
    expect(find.text('Context window'), findsOneWidget);
    expect(find.text('57 / 1k (6%)'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('context-usage-stacked-bar')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('context-usage-bucket-freeSpace')),
      findsOneWidget,
    );
    expect(usage.refreshCalls, 1);
    expect(usage.lastDraft, 'draft');
    expect(usage.lastForce, isFalse);
    expect(
      find.byKey(const ValueKey('context-usage-bucket-system')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('context-usage-bucket-history')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('context-usage-bucket-draft')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('context-usage-bucket-tools')),
      findsNothing,
    );

    // All sources on a short phone must remain reachable by scrolling.
    tester.view.physicalSize = const Size(320, 440);
    const detailed = ContextUsageBuckets(
      history: 40,
      system: 12,
      memory: 5,
      worldBook: 5,
      skills: 5,
      workspace: 5,
      search: 5,
      tools: 5,
      mcpTools: 5,
      injections: 5,
      attachments: 5,
      draft: 5,
    );
    usage.seeded = usage.seeded!.copyWith(
      state: ContextUsageState.failed,
      buckets: detailed,
      usedTokens: detailed.total,
    );
    usage.notifyListeners();
    await tester.pump();
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text('Clear Context'));
    await tester.pumpAndSettle();
    expect(find.text('Clear Context').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);

    expect(
      find.text(
        'Couldn’t refresh. Showing the previous result, which may be out of date.',
      ),
      findsOneWidget,
    );
    await tester.ensureVisible(find.byTooltip('Retry'));
    await tester.tap(find.byTooltip('Retry'));
    await tester.pump();
    expect(usage.refreshCalls, 2);
    expect(usage.lastForce, isTrue);
    expect(usage.lastDraft, isNull);

    usage.seeded = usage.seeded!.copyWith(state: ContextUsageState.estimated);
    usage.notifyListeners();
    await tester.pump();
    expect(find.byTooltip('Retry'), findsNothing);
    expect(find.text('Estimated'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('context-usage-bucket-history')),
      findsOneWidget,
    );
    await tester.ensureVisible(find.text('Clear Context'));
    await tester.pumpAndSettle();
    expect(find.text('Clear Context').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
