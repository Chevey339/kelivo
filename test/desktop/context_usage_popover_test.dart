import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:Kelivo/core/providers/assistant_provider.dart';
import 'package:Kelivo/core/providers/instruction_injection_provider.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/providers/world_book_provider.dart';
import 'package:Kelivo/core/services/chat/chat_service.dart';
import 'package:Kelivo/desktop/context_usage_popover.dart';
import 'package:Kelivo/desktop/desktop_glass_popover.dart';
import 'package:Kelivo/features/home/services/context_usage_service.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/widgets/context_usage_details.dart';

import '../support/business_test_harness.dart';

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
  bool? lastForce;
  String? lastDraft;

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
    lastForce = force;
    lastDraft = draftText;
  }
}

ContextUsageSnapshot usageSnap({
  ContextUsageState state = ContextUsageState.estimated,
  int used = 110,
  int? window = 1000,
  ContextUsageBuckets buckets = const ContextUsageBuckets(
    system: 10,
    injections: 8,
    history: 70,
    tools: 6,
    attachments: 7,
    draft: 9,
  ),
  String modelId = 'window-model',
}) {
  return ContextUsageSnapshot(
    state: state,
    buckets: buckets,
    usedTokens: used,
    contextWindow: window,
    conversationId: 'c1',
    revision: 1,
    providerKey: 'TestProvider',
    modelId: modelId,
    assistantId: null,
    computedAt: DateTime.utc(2026, 1, 1),
  );
}

Future<_RecordingUsage> _createUsage() async {
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
  final usage = _RecordingUsage(
    chatService: ChatService(),
    settings: settings,
    assistants: assistants,
    instructions: instructions,
    worldBooks: worldBooks,
  );
  addTearDown(assistants.dispose);
  addTearDown(settings.dispose);
  addTearDown(instructions.dispose);
  addTearDown(worldBooks.dispose);
  addTearDown(usage.dispose);
  return usage;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpOpenButton(
    WidgetTester tester, {
    required _RecordingUsage usage,
  }) {
    final settings = SettingsProvider(createBusinessTestPreferences());
    addTearDown(settings.dispose);
    final anchorKey = GlobalKey();
    return tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SettingsProvider>.value(value: settings),
          ChangeNotifierProvider<ContextUsageService>.value(value: usage),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Align(
              alignment: Alignment.bottomCenter,
              child: SizedBox(
                key: anchorKey,
                width: 320,
                height: 48,
                child: Builder(
                  builder: (context) {
                    return TextButton(
                      key: const ValueKey('open-context-usage-popover'),
                      onPressed: () {
                        showContextUsagePopover(
                          context,
                          anchorKey: anchorKey,
                          conversationId: 'c1',
                          draftText: 'hello',
                        );
                      },
                      child: const Text('open'),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('opens with an estimated snapshot and refreshes once', (
    tester,
  ) async {
    final usage = await _createUsage();
    usage.seeded = usageSnap();
    await pumpOpenButton(tester, usage: usage);

    await tester.tap(find.byKey(const ValueKey('open-context-usage-popover')));
    await tester.pumpAndSettle();

    expect(usage.refreshCalls, 1);
    expect(usage.lastForce, isFalse);
    expect(find.byType(DesktopGlassPanel), findsOneWidget);
    expect(find.byType(ContextUsageBreakdown), findsOneWidget);
    expect(find.byKey(contextUsagePopoverKey), findsOneWidget);
    expect(find.text('Compress Context'), findsNothing);
    expect(find.text('Clear Context'), findsNothing);
    expect(find.text('Context window'), findsOneWidget);
    expect(find.text('110 / 1k (11%)'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('context-usage-stacked-bar')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('context-usage-bucket-freeSpace')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('context-usage-bucket-system')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('context-usage-bucket-injections')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('context-usage-bucket-history')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('context-usage-bucket-tools')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('context-usage-bucket-attachments')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('context-usage-bucket-draft')),
      findsOneWidget,
    );
    expect(find.text('Estimated'), findsOneWidget);
    expect(usage.lastDraft, 'hello');
    await tester.tap(find.byTooltip('Refresh'));
    await tester.pump();
    expect(usage.lastForce, isTrue);
    expect(
      usage.lastDraft,
      isNull,
    ); // Refresh must use the live composer state.
  });

  testWidgets('shows set context window when the window is null', (
    tester,
  ) async {
    final usage = await _createUsage();
    usage.seeded = usageSnap(window: null, used: 40);
    await pumpOpenButton(tester, usage: usage);

    await tester.tap(find.byKey(const ValueKey('open-context-usage-popover')));
    await tester.pumpAndSettle();

    expect(find.byType(DesktopGlassPanel), findsOneWidget);
    expect(find.byType(ContextUsageBreakdown), findsOneWidget);
    expect(find.text('Compress Context'), findsNothing);
    expect(find.text('Clear Context'), findsNothing);
    expect(
      find.byKey(const ValueKey('context-usage-set-window')),
      findsOneWidget,
    );
    expect(find.text('Set context window'), findsOneWidget);
    expect(find.text('40'), findsWidgets);
    expect(find.textContaining('%'), findsNothing);
  });
}
