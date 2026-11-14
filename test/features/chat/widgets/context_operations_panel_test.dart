import 'package:Kelivo/features/chat/widgets/context_operation_widgets.dart';
import 'package:Kelivo/core/models/message_part.dart';
import 'package:Kelivo/core/services/api/generation/text_generation_result.dart';
import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:Kelivo/core/database/chat_database_repository.dart';
import 'package:Kelivo/core/models/compress_context_options.dart';
import 'package:Kelivo/core/models/context_operation.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/providers/assistant_provider.dart';
import 'package:Kelivo/core/providers/asr_provider.dart';
import 'package:Kelivo/core/providers/world_book_provider.dart';
import 'package:Kelivo/core/providers/instruction_injection_provider.dart';
import 'package:Kelivo/core/providers/mcp_provider.dart';
import 'package:Kelivo/core/providers/quick_phrase_provider.dart';
import 'package:Kelivo/core/services/chat/chat_service.dart';
import 'package:Kelivo/core/services/chat/context_compression_service.dart';
import 'package:Kelivo/features/chat/widgets/context_operations_panel.dart';
import 'package:Kelivo/features/chat/widgets/context_operation_actions.dart';
import 'package:Kelivo/features/home/widgets/chat_input_section.dart';
import 'package:Kelivo/features/home/widgets/chat_input_bar.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/l10n/app_localizations_en.dart';
import 'package:Kelivo/shared/widgets/ios_tactile.dart';
import 'package:Kelivo/theme/theme_factory.dart';
import '../../../support/business_test_harness.dart';

class _Paths extends PathProviderPlatform {
  _Paths(this.path);
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

void check(String name, WidgetTesterCallback body) {
  testWidgets(name, (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    try {
      await body(tester);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      debugDefaultTargetPlatformOverride = null;
    }
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late ChatDatabaseRepository repo;
  late ChatService chat;
  late String id;
  late SettingsProvider settings;

  setUp(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('haptic_feedback'),
          (_) async => null,
        );
    directory = await Directory.systemTemp.createTemp('context_operations_');
    PathProviderPlatform.instance = _Paths(directory.path);
    repo = ChatDatabaseRepository.open(
      file: File('${directory.path}/chat.sqlite'),
    );
    chat = ChatService(existingRepository: repo);
    settings = SettingsProvider(createBusinessTestPreferences());
    await settings.loaded;
    await chat.init();
    id = (await chat.createConversation(title: 'History')).id;
    for (var i = 0; i < 30; i++) {
      for (final role in ['user', 'assistant']) {
        await chat.addMessage(
          conversationId: id,
          role: role,
          content: '$role $i ${'history ' * 20}',
        );
      }
    }
    chat.contextCompression.estimateCandidate =
        (_, _, {bool? fixedContextStart}) async =>
            (usedTokens: 100, contextWindow: 4000);
  });
  tearDown(() async {
    await chat.close();
    await repo.close();
    settings.dispose();
    await directory.delete(recursive: true);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('haptic_feedback'), null);
    debugDefaultTargetPlatformOverride = null;
  });

  Future<void> until(bool Function() done) async {
    for (var i = 0; i < 500; i++) {
      if (done()) return;
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    fail('Compression did not finish');
  }

  Future<void> start(
    Future<String> Function(String, String) generate, {
    CompressContextOptions options = const CompressContextOptions(
      mode: CompressContextLimitMode.keepRecent,
      keepUserMessages: 25,
    ),
  }) => chat.contextCompression.start(
    id,
    CompressionRequest(
      options: options,
      model: 'test',
      generate: (prompt, id, _, _) async =>
          TextGenerationResult(parts: [TextPart(await generate(prompt, id))]),
      quoteMarker: AppLocalizationsEn().selectionQuoteMarker,
    ),
  );

  Future<void> pumpUntil(WidgetTester tester, bool Function() done) async {
    for (var i = 0; i < 300; i++) {
      await tester.pump();
      if (done()) return;
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
    }
    fail(
      'Panel did not finish loading: ${find.byType(Text).evaluate().map((e) => (e.widget as Text).data).toList()}',
    );
  }

  Future<void> pumpPanel(
    WidgetTester tester, {
    ValueChanged<ContextOperation>? onOpen,
    VoidCallback? onBarOpen,
  }) async {
    addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: chat),
          ChangeNotifierProvider.value(value: settings),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: buildLightTheme(null),
          home: Scaffold(
            body: Column(
              children: [
                ContextTaskBar(conversationId: id, onOpen: onBarOpen ?? () {}),
                Expanded(
                  child: ContextOperationsPanel(
                    chat: chat,
                    conversationId: id,
                    messageLimit: 100,
                    onOpenOperation: onOpen ?? (_) {},
                    onRetry: (_) {},
                    onAdjust: (_) {},
                    onReview: (_) {},
                    onOpenConversation: (_) {},
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await pumpUntil(
      tester,
      () =>
          find
              .text(AppLocalizationsEn().contextOperationsStored(60))
              .evaluate()
              .isNotEmpty &&
          find.text('Loading...').evaluate().isEmpty,
    );
  }

  Future<void> pumpTaskEntry(
    WidgetTester tester, {
    ValueChanged<String>? onOpenConversation,
  }) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: chat),
          ChangeNotifierProvider.value(value: settings),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: buildLightTheme(null),
          home: Scaffold(
            body: Builder(
              builder: (context) => ContextTaskBar(
                conversationId: id,
                onOpen: () => showContextOperations(
                  context,
                  chat: chat,
                  conversationId: id,
                  messageLimit: 100,
                  onOpenOperation: (_) {},
                  onRetry: (_) {},
                  onAdjust: (_) {},
                  onOpenConversation: onOpenConversation ?? (_) {},
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('context-task-bar')));
    await pumpUntil(
      tester,
      () =>
          find
              .text(AppLocalizationsEn().contextOperationsStored(60))
              .evaluate()
              .isNotEmpty &&
          find.text('Loading...').evaluate().isEmpty,
    );
    await tester.pump(const Duration(seconds: 1));
  }

  Future<List<ContextOperation>> seedHistory(int count) async {
    final anchor = (await chat.loadRawSelectedContextMessages(
      id,
      limit: 1,
    )).last.id;
    final operations = [
      for (var i = 0; i < count; i++)
        ContextOperation(
          id: 'history-$i',
          kind: ContextOperationKind.compress,
          anchorGroupId: anchor,
          appliedAfterGroupId: anchor,
          sourceGroups: [anchor],
          dependencies: const [],
          createdAt: DateTime.utc(2026, 1, 1, 0, i),
          revoked: true,
          summary: 'Record $i ${'details ' * 100}',
        ),
    ];
    await repo.restoreContextOperations(
      id,
      operations,
      expectedFingerprint: (await repo.readContextSnapshot(id)).fingerprint,
    );
    return operations;
  }

  Finder panelList() => find.descendant(
    of: find.byType(ContextOperationsPanel),
    matching: find.byType(ListView),
  );

  int loadedRows(WidgetTester tester) =>
      tester
          .widget<ListView>(panelList())
          .childrenDelegate
          .estimatedChildCount! -
      3;

  final more = find.byKey(const ValueKey('context-operations-load-more'));

  Future<void> expandHistory(WidgetTester tester, int count) async {
    await tester.scrollUntilVisible(
      more,
      400,
      scrollable: find.descendant(
        of: panelList(),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.tap(more);
    await pumpUntil(tester, () => loadedRows(tester) == count);
  }

  for (final platform in [TargetPlatform.android, TargetPlatform.macOS]) {
    check(
      'history loads 3 then 10 at a time and resets on reopen on $platform',
      (tester) async {
        debugDefaultTargetPlatformOverride = platform;
        await tester.runAsync(() => seedHistory(25));
        ContextOperation? opened;
        await pumpPanel(tester, onOpen: (operation) => opened = operation);
        await pumpUntil(tester, () => loadedRows(tester) == 3);
        expect(chat.contextOperationsFor(id), isEmpty);
        expect(
          find.byKey(const ValueKey('context-operation-history-24')),
          findsOneWidget,
        );
        for (final count in [13, 23, 25]) {
          await expandHistory(tester, count);
          expect(chat.contextOperationsFor(id), isEmpty);
        }
        await tester.drag(panelList(), const Offset(0, -2000));
        await tester.pumpAndSettle();
        expect(more, findsNothing);
        final oldest = find.byKey(
          const ValueKey('context-operation-history-0'),
        );
        await tester.scrollUntilVisible(
          oldest,
          400,
          scrollable: find.descendant(
            of: panelList(),
            matching: find.byType(Scrollable),
          ),
        );
        await tester.tap(oldest);
        await pumpUntil(tester, () => opened != null);
        expect(opened!.id, 'history-0');
        expect(opened!.summary.length, greaterThan(240));
        expect(chat.contextOperationsFor(id), isEmpty);
        await tester.pumpWidget(const SizedBox.shrink());
        await pumpPanel(tester);
        await pumpUntil(tester, () => loadedRows(tester) == 3);
        expect(
          find.byKey(const ValueKey('context-operation-history-24')),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  check('history refresh preserves expanded count after append and undo', (
    tester,
  ) async {
    await tester.runAsync(() => seedHistory(25));
    await pumpPanel(tester);
    await pumpUntil(tester, () => loadedRows(tester) == 3);
    await expandHistory(tester, 13);
    // A context mutation invalidates an in-flight request for the next page.
    await tester.scrollUntilVisible(
      more,
      400,
      scrollable: find.descendant(
        of: panelList(),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.tap(more);
    await tester.runAsync(() async {
      final snapshot = await chat.loadContextSnapshot(id);
      await chat.appendContextOperation(
        id,
        ContextOperation(
          id: 'new',
          kind: ContextOperationKind.compress,
          anchorGroupId: snapshot.messages.first.id,
          appliedAfterGroupId: snapshot.messages.last.id,
          sourceGroups: [snapshot.messages.first.id],
          dependencies: const [],
          createdAt: DateTime.utc(2027),
          summary: 'New summary',
        ),
        expectedFingerprint: snapshot.fingerprint,
      );
    });
    await tester.drag(panelList(), const Offset(0, 5000));
    await pumpUntil(
      tester,
      () => find.text('New summary').evaluate().isNotEmpty,
    );
    expect(loadedRows(tester), 13);
    await tester.runAsync(
      () => chat.changeContextOperation(
        id,
        'new',
        includeDependents: true,
        expectedState: ContextHistory.operationsFingerprint(
          chat.contextOperationsFor(id),
        ),
      ),
    );
    await pumpUntil(
      tester,
      () => find
          .descendant(
            of: find.byKey(const ValueKey('context-operation-new')),
            matching: find.textContaining('Undone'),
          )
          .evaluate()
          .isNotEmpty,
    );
    expect(loadedRows(tester), 13);
    await expandHistory(tester, 23);
    await expandHistory(tester, 26);
    expect(more, findsNothing);
    expect(tester.takeException(), isNull);
  });

  check('expansion detects a committed write before the service notification', (
    tester,
  ) async {
    late List<ContextOperation> operations;
    await tester.runAsync(() async => operations = await seedHistory(25));
    await pumpPanel(tester);
    final revision = chat.contextRevision(id);
    await tester.runAsync(() async {
      // Reproduce the window after repository commit, before ChatService's
      // subsequent reload completes and bumps its in-memory revision.
      await repo.restoreContextOperations(id, [
        ...operations,
        ContextOperation(
          id: 'new-before-notify',
          kind: ContextOperationKind.compress,
          anchorGroupId: operations.last.anchorGroupId,
          appliedAfterGroupId: operations.last.appliedAfterGroupId,
          sourceGroups: operations.last.sourceGroups,
          dependencies: const [],
          createdAt: DateTime.utc(2027),
          revoked: true,
          summary: 'Committed before notification',
        ),
      ], expectedFingerprint: (await repo.readContextSnapshot(id)).fingerprint);
    });
    expect(chat.contextRevision(id), revision);
    await expandHistory(tester, 13);
    await tester.drag(panelList(), const Offset(0, 5000));
    await tester.pumpAndSettle();
    expect(find.text('Committed before notification'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('context-operation-history-24')),
      findsOneWidget,
    );
    await expandHistory(tester, 23);
    await expandHistory(tester, 26);
    expect(more, findsNothing);
    expect(tester.takeException(), isNull);
  });

  check('failed expansion retains rows and retries the same page', (
    tester,
  ) async {
    await tester.runAsync(() => seedHistory(25));
    await pumpPanel(tester);
    final database = sqlite.sqlite3.open('${directory.path}/chat.sqlite');
    addTearDown(database.close);
    final metadata =
        database.select(
              'SELECT metadata FROM context_operation_state WHERE conversation_id=?',
              [id],
            ).single['metadata']
            as String;
    database.execute(
      'UPDATE context_operation_state SET metadata=? WHERE conversation_id=?',
      ['{', id],
    );
    await tester.scrollUntilVisible(
      more,
      400,
      scrollable: find.descendant(
        of: panelList(),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.tap(more);
    await pumpUntil(tester, () => find.text('Retry').evaluate().isNotEmpty);
    expect(loadedRows(tester), 3);
    database.execute(
      'UPDATE context_operation_state SET metadata=? WHERE conversation_id=?',
      [metadata, id],
    );
    await tester.tap(find.text('Retry'));
    await pumpUntil(tester, () => loadedRows(tester) == 13);
    expect(tester.takeException(), isNull);
  });

  check('temporary conversations page their in-memory operations', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final temporary = await chat.createDraftConversation(
        title: 'Temporary',
        temporary: true,
      );
      final message = await chat.addMessage(
        conversationId: temporary.id,
        role: 'user',
        content: 'Source',
      );
      final operations = [
        for (var i = 0; i < 15; i++)
          ContextOperation(
            id: 'temporary-$i',
            kind: ContextOperationKind.compress,
            anchorGroupId: message.id,
            appliedAfterGroupId: message.id,
            sourceGroups: [message.id],
            dependencies: const [],
            createdAt: DateTime.utc(2026, 1, 1, 0, i),
            revoked: true,
            summary: 'Summary $i',
          ),
      ];
      await chat.restoreContextOperations(
        temporary.id,
        operations,
        expectedFingerprint: (await chat.loadContextSnapshot(
          temporary.id,
        )).fingerprint,
      );
      final first = await chat.loadContextOperationPage(
        temporary.id,
        offset: 0,
        limit: 3,
      );
      final second = await chat.loadContextOperationPage(
        temporary.id,
        offset: 3,
        limit: 10,
      );
      final last = await chat.loadContextOperationPage(
        temporary.id,
        offset: 13,
        limit: 10,
      );
      expect(
        [...first.items, ...second.items, ...last.items].map((item) => item.id),
        operations.reversed.map((operation) => operation.id),
      );
      expect(
        [first.hasMore, second.hasMore, last.hasMore],
        [true, true, false],
      );
      expect(
        (await chat.loadContextOperation(
          temporary.id,
          operations.first.id,
        ))!.summary,
        'Summary 0',
      );
    });
  });

  check('operation details paint and close while budgets are pending', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await start((_, _) async => 'Saved detail summary');
      await until(
        () =>
            chat.contextCompression.taskFor(id)!.phase ==
            CompressionPhase.completed,
      );
    });
    final operation = chat.contextOperationsFor(id).single;
    final budget = Completer<CompressionBudget>();
    var started = 0;
    chat.contextCompression.estimateCandidate =
        (_, _, {bool? fixedContextStart}) {
          started++;
          return budget.future;
        };
    BuildContext? pageContext;
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: settings,
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (context) {
                pageContext = context;
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      ),
    );
    final closed = showContextOperationDetails(
      pageContext!,
      chat: chat,
      conversationId: id,
      operation: operation,
    );
    await tester.pump();
    expect(find.byType(ContextOperationContent), findsOneWidget);
    expect(
      tester
          .widget<ContextOperationContent>(find.byType(ContextOperationContent))
          .budget,
      isNull,
    );
    final estimate = tester
        .widget<ContextOperationContent>(find.byType(ContextOperationContent))
        .estimateSummary;
    expect(estimate, isNotNull);
    final earlyEditBudget = estimate!('Edited before history was ready');
    await pumpUntil(tester, () => started == 3);
    final detailContext = tester.element(find.byType(ContextOperationContent));
    Navigator.of(detailContext).pop();
    await tester.pumpAndSettle();
    await closed;
    budget.complete((usedTokens: 100, contextWindow: 4000));
    await tester.pump();
    expect((await earlyEditBudget)?.usedTokens, 100);
    expect(find.byType(ContextOperationContent), findsNothing);
    expect(tester.takeException(), isNull);
  });

  final closePanel = find.byWidgetPredicate(
    (widget) => widget is IosIconButton && widget.semanticLabel == 'Close',
  );

  for (final platform in [
    TargetPlatform.android,
    TargetPlatform.iOS,
    TargetPlatform.macOS,
  ]) {
    for (final openResult in [false, true]) {
      check(
        'viewed completion clears its notice and preserves the result on $platform (open result: $openResult)',
        (tester) async {
          debugDefaultTargetPlatformOverride = platform;
          await tester.runAsync(() async {
            await start(
              (_, _) async => 'saved summary',
              options: const CompressContextOptions(
                mode: CompressContextLimitMode.keepRecent,
                keepUserMessages: 1,
                newConversation: true,
              ),
            );
            await until(
              () =>
                  chat.contextCompression.taskFor(id)!.phase ==
                  CompressionPhase.completed,
            );
          });
          final result = chat.contextCompression
              .taskFor(id)!
              .resultConversationId!;
          final phases = <CompressionPhase?>[];
          void observe() =>
              phases.add(chat.contextCompression.taskFor(id)?.phase);
          chat.contextCompression.addListener(observe);
          addTearDown(() => chat.contextCompression.removeListener(observe));
          String? opened;
          await pumpTaskEntry(tester, onOpenConversation: (id) => opened = id);
          expect(find.text('Dismiss'), findsNothing);
          expect(chat.contextCompression.taskFor(id), isNotNull);
          await tester.tap(
            openResult ? find.text('Open new chat') : closePanel,
          );
          await pumpUntil(
            tester,
            () => chat.contextCompression.taskFor(id) == null,
          );
          await tester.pumpAndSettle();
          expect(opened, openResult ? result : isNull);
          expect(find.byKey(const ValueKey('context-task-bar')), findsNothing);
          expect(phases, isNot(contains(CompressionPhase.cancelled)));
          await tester.runAsync(() async {
            expect(chat.getConversation(result), isNotNull);
            expect(
              (await chat.loadContextOperations(
                result,
                refresh: true,
              )).single.summary,
              'saved summary',
            );
            expect(await chat.loadMessages(id), hasLength(60));
            await chat.close();
            await chat.init();
            expect(chat.contextCompression.taskFor(id), isNull);
            expect(chat.getConversation(result), isNotNull);
          });
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  for (final phase in [
    CompressionPhase.waiting,
    CompressionPhase.review,
    CompressionPhase.failed,
  ]) {
    check('closing task details preserves $phase for further action', (
      tester,
    ) async {
      await tester.runAsync(() async {
        if (phase == CompressionPhase.waiting) {
          chat.contextCompression.isConversationBusy = (_) => true;
        } else if (phase == CompressionPhase.review) {
          chat.contextCompression.estimateCandidate =
              (_, _, {bool? fixedContextStart}) async =>
                  (usedTokens: 5000, contextWindow: 4000);
        }
        await start((_, _) async {
          if (phase == CompressionPhase.failed) {
            throw StateError('test failure');
          }
          return 'summary';
        });
        await until(() => chat.contextCompression.taskFor(id)!.phase == phase);
      });
      final task = chat.contextCompression.taskFor(id);
      await pumpTaskEntry(tester);
      await tester.tap(closePanel);
      await tester.pump(const Duration(seconds: 1));
      expect(chat.contextCompression.taskFor(id), same(task));
      expect(task!.phase, phase);
      expect(find.byKey(const ValueKey('context-task-bar')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  check('closing old task details does not dismiss a replacement completion', (
    tester,
  ) async {
    await tester.runAsync(() async {
      chat.contextCompression.isConversationBusy = (_) => true;
      await start((_, _) async => 'old summary');
    });
    await pumpTaskEntry(tester);
    await tester.runAsync(() async {
      await chat.contextCompression.cancel(id);
      chat.contextCompression.isConversationBusy = (_) => false;
      await start((_, _) async => 'new summary');
      await until(
        () =>
            chat.contextCompression.taskFor(id)!.phase ==
            CompressionPhase.completed,
      );
    });
    final replacement = chat.contextCompression.taskFor(id);
    await tester.pump();
    await tester.tap(closePanel);
    await tester.pumpAndSettle();
    expect(chat.contextCompression.taskFor(id), same(replacement));
    expect(replacement!.phase, CompressionPhase.completed);
    await tester.runAsync(() => chat.contextCompression.dismiss(id));
    expect(tester.takeException(), isNull);
  });

  check(
    'measured composer includes the task bar without recreating its input',
    (tester) async {
      final assistants = AssistantProvider(
        preferences: createBusinessTestPreferences(),
      );
      await tester.runAsync(() => assistants.loaded);
      addTearDown(assistants.dispose);
      final key = GlobalKey();
      final input = TextEditingController();
      final focus = FocusNode();
      addTearDown(input.dispose);
      addTearDown(focus.dispose);
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: chat),
            ChangeNotifierProvider.value(value: settings),
            ChangeNotifierProvider.value(value: assistants),
            ChangeNotifierProvider(create: (_) => AsrProvider()),
            ChangeNotifierProvider(
              create: (_) => WorldBookProvider(
                preferences: createBusinessTestPreferences(),
              ),
            ),
            ChangeNotifierProvider(
              create: (_) => InstructionInjectionProvider(
                preferences: createBusinessTestPreferences(),
              ),
            ),
            ChangeNotifierProvider(
              create: (_) =>
                  McpProvider(preferences: createBusinessTestPreferences()),
            ),
            ChangeNotifierProvider(
              create: (_) => QuickPhraseProvider(
                preferences: createBusinessTestPreferences(),
              ),
            ),
          ],
          child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: buildLightTheme(null),
            home: Scaffold(
              body: Align(
                alignment: Alignment.bottomCenter,
                child: ChatInputSection(
                  inputBarKey: key,
                  inputFocus: focus,
                  inputController: input,
                  mediaController: ChatInputBarController(),
                  isTablet: false,
                  isLoading: false,
                  isToolModel: (_, _) => false,
                  isReasoningModel: (_, _) => false,
                  isReasoningEnabled: (_) => false,
                  conversationId: id,
                  onContextOperations: () {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final inputState = tester.state(find.byType(ChatInputBar));
      final before = tester.getSize(find.byKey(key)).height;
      await tester.runAsync(() async {
        chat.contextCompression.isConversationBusy = (_) => true;
        await start((_, _) async => 'summary');
      });
      await tester.pump();
      final task = find.byKey(const ValueKey('context-task-bar'));
      expect(task, findsOneWidget);
      expect(
        tester.getSize(find.byKey(key)).height,
        greaterThanOrEqualTo(before + tester.getSize(task).height),
      );
      expect(tester.state(find.byType(ChatInputBar)), same(inputState));
      await tester.runAsync(() => chat.contextCompression.cancel(id));
      await tester.pumpAndSettle();
      expect(tester.getSize(find.byKey(key)).height, before);
      expect(tester.state(find.byType(ChatInputBar)), same(inputState));
      expect(tester.takeException(), isNull);
    },
  );

  check(
    'persisted operation remains reachable outside the loaded history window',
    (tester) async {
      late ContextOperation operation;
      await tester.runAsync(() async {
        await start((_, _) async => 'saved summary');
        await until(
          () =>
              chat.contextCompression.taskFor(id)!.phase ==
              CompressionPhase.completed,
        );
        operation = (await chat.loadContextOperations(id)).single;
        await chat.close();
        await chat.init();
        final page = await chat.loadTimelinePage(id, limit: 40);
        expect(
          page!.slots.any(
            (slot) => slot.identity.slotId == operation.anchorGroupId,
          ),
          isFalse,
        );
      });
      ContextOperation? opened;
      await pumpPanel(tester, onOpen: (op) => opened = op);
      await tester.pumpAndSettle();
      expect(
        find.text(AppLocalizationsEn().contextOperationsStored(60)),
        findsOneWidget,
      );
      expect(
        find.text(AppLocalizationsEn().contextOperationsEffective(1, 50)),
        findsOneWidget,
      );
      final record = find.byKey(ValueKey('context-operation-${operation.id}'));
      await tester.tap(record);
      await pumpUntil(tester, () => opened != null);
      expect(opened!.id, operation.id);
      await tester.runAsync(
        () => chat.changeContextOperation(
          id,
          operation.id,
          includeDependents: true,
          expectedState: ContextHistory.operationsFingerprint(
            chat.contextOperationsFor(id),
          ),
        ),
      );
      await pumpUntil(
        tester,
        () => find
            .text(AppLocalizationsEn().contextOperationsEffective(0, 60))
            .evaluate()
            .isNotEmpty,
      );
      await tester.pumpAndSettle();
      expect(
        find.text(AppLocalizationsEn().contextOperationsEffective(0, 60)),
        findsOneWidget,
      );
      expect(find.textContaining('Undone'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  check('running task has a fixed entry and cancel rejects a late summary', (
    tester,
  ) async {
    final response = Completer<String>();
    await tester.runAsync(() async {
      await start((_, _) => response.future);
      await until(
        () =>
            chat.contextCompression.taskFor(id)!.phase ==
            CompressionPhase.summarizing,
      );
    });
    var opens = 0;
    await pumpPanel(tester, onBarOpen: () => opens++);
    await tester.tap(find.byKey(const ValueKey('context-task-bar')));
    expect(opens, 1);
    await tester.runAsync(() async {
      await tester.tap(find.text('Cancel compression'));
      await until(() => !chat.contextCompression.blocksSending(id));
      response.complete('late result');
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('context-task-bar')), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(() async {
      expect(await chat.loadContextOperations(id, refresh: true), isEmpty);
      await chat.close();
      await chat.init();
      expect(chat.contextCompression.taskFor(id), isNull);
    });
    await tester.pumpWidget(const SizedBox.shrink());
  });

  check(
    'review remains visible and cancellable; interrupted status can be dismissed across restarts',
    (tester) async {
      await tester.runAsync(() async {
        chat.contextCompression.estimateCandidate =
            (_, _, {bool? fixedContextStart}) async =>
                (usedTokens: 5000, contextWindow: 4000);
        await start((_, _) async => 'summary');
        await until(
          () =>
              chat.contextCompression.taskFor(id)!.phase ==
              CompressionPhase.review,
        );
      });
      await pumpPanel(tester);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('context-task-bar')), findsOneWidget);
      expect(find.text('Cancel compression'), findsOneWidget);
      expect(chat.contextCompression.blocksSending(id), isTrue);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(() async {
        await chat.close();
        await chat.init();
      });
      await pumpPanel(tester);
      await tester.pumpAndSettle();
      expect(
        chat.contextCompression.taskFor(id)!.phase,
        CompressionPhase.interrupted,
      );
      expect(find.text('Retry'), findsOneWidget);
      await tester.runAsync(() async {
        await tester.tap(find.text('Dismiss'));
        await until(() => chat.contextCompression.taskFor(id) == null);
      });
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('context-task-bar')), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(() async {
        await chat.close();
        await chat.init();
        expect(chat.contextCompression.taskFor(id), isNull);
      });
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
