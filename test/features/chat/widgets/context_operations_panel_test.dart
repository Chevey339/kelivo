import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
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
import 'package:Kelivo/features/home/widgets/chat_input_section.dart';
import 'package:Kelivo/features/home/widgets/chat_input_bar.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/l10n/app_localizations_en.dart';
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
    debugDefaultTargetPlatformOverride = null;
  });

  Future<void> until(bool Function() done) async {
    for (var i = 0; i < 500; i++) {
      if (done()) return;
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    fail('Compression did not finish');
  }

  Future<void> start(Future<String> Function(String, String) generate) =>
      chat.contextCompression.start(
        id,
        CompressionRequest(
          options: const CompressContextOptions(
            mode: CompressContextLimitMode.keepRecent,
            keepUserMessages: 25,
          ),
          model: 'test',
          generate: generate,
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
      () => find.text('Saved history: 60 messages').evaluate().isNotEmpty,
    );
  }

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
      expect(find.text('Saved history: 60 messages'), findsOneWidget);
      expect(
        find.text(
          'History for the next request: 1 summaries + 50 original messages',
        ),
        findsOneWidget,
      );
      final record = find.byKey(ValueKey('context-operation-${operation.id}'));
      await tester.tap(record);
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
            .text(
              'History for the next request: 0 summaries + 60 original messages',
            )
            .evaluate()
            .isNotEmpty,
      );
      await tester.pumpAndSettle();
      expect(
        find.text(
          'History for the next request: 0 summaries + 60 original messages',
        ),
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
        await tester.tap(find.text('Dismiss status'));
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
