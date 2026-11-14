import 'dart:async';
import 'dart:io';

import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/core/models/context_operation.dart';
import 'package:Kelivo/core/providers/assistant_provider.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/chat/chat_service.dart';
import 'package:Kelivo/features/chat/widgets/context_operation_actions.dart';
import 'package:Kelivo/features/chat/widgets/context_operation_widgets.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/theme/theme_factory.dart';
import 'package:Kelivo/utils/sandbox_path_resolver.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

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

class _PausingCopyChatService extends ChatService {
  Completer<void>? copyGate;
  Completer<String>? copyTarget;

  @override
  Future<void> addMessageDirectly(
    String conversationId,
    ChatMessage message,
  ) async {
    final gate = copyGate;
    if (gate != null) {
      copyGate = null;
      copyTarget!.complete(conversationId);
      await gate.future;
    }
    await super.addMessageDirectly(conversationId, message);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late ChatService chat;
  late String sourceId;
  late List<ChatMessage> messages;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('context_continue_');
    PathProviderPlatform.instance = _Paths(directory.path);
    SandboxPathResolver.debugSetDirs(
      docsDir: directory.path,
      supportDir: directory.path,
    );
    chat = _PausingCopyChatService();
    await chat.init();
  });

  tearDown(() async {
    await chat.close();
    await Hive.close();
    SandboxPathResolver.debugSetDirs(docsDir: null, supportDir: null);
    await directory.delete(recursive: true);
  });

  Future<ContextOperation> compress({
    bool temporary = false,
    bool keepTail = true,
  }) async {
    final source = temporary
        ? await chat.createDraftConversation(title: 'Original', temporary: true)
        : await chat.createConversation(title: 'Original');
    sourceId = source.id;
    await chat.setConversationModel(
      sourceId,
      providerKey: 'pinned-provider',
      modelId: 'pinned-model',
    );
    messages = [];
    for (var i = 0; i < 3; i++) {
      for (final role in ['user', 'assistant']) {
        messages.add(
          await chat.addMessage(
            conversationId: sourceId,
            role: role,
            content: '$role $i',
          ),
        );
      }
    }
    await chat.appendMessageVersion(
      messageId: messages[1].id,
      content: 'revised original answer',
    );
    await chat.setToolEvents(messages.last.id, const [
      {'id': 'tool', 'name': 'search', 'content': 'retained result'},
    ]);
    final snapshot = await chat.loadContextSnapshot(sourceId);
    messages = snapshot.messages;
    final covered = keepTail ? messages.take(4).toList() : messages;
    final operation = ContextOperation(
      id: 'summary',
      kind: ContextOperationKind.compress,
      anchorGroupId: ContextHistory.group(covered.last),
      appliedAfterGroupId: ContextHistory.group(messages.last),
      sourceGroups: covered.map(ContextHistory.group).toList(),
      dependencies: const [],
      createdAt: DateTime(2026),
      summary: 'Edited summary',
      originalSummary: 'Original summary',
      keepUserMessages: keepTail ? 1 : 0,
    );
    await chat.appendContextOperation(
      sourceId,
      operation,
      expectedFingerprint: snapshot.fingerprint,
    );
    return operation;
  }

  for (final temporary in [false, true]) {
    for (final keepTail in [false, true]) {
      test('continue from summary copies only summary and retained messages '
          '(temporary: $temporary, keepTail: $keepTail)', () async {
        final operation = await compress(
          temporary: temporary,
          keepTail: keepTail,
        );
        final before = await chat.loadContextSnapshot(sourceId);
        final expected = [
          'Edited summary',
          if (keepTail) ...messages.skip(4).map((m) => m.content),
        ];
        final created = await chat.continueFromContextSummary(
          sourceId,
          operation.id,
        );
        final copied = await chat.loadMessages(created.id);
        expect(copied.map((m) => m.content), expected);
        expect(copied.map((m) => m.version).toSet(), {0});
        expect(copied.every((m) => (m.groupId ?? m.id) == m.id), isTrue);
        expect(chat.getVersionSelections(created.id), isEmpty);
        final nodes = await chat.loadContextOperations(created.id);
        expect(nodes.single.sourceGroups, [copied.first.id]);
        expect(created.chatModelProvider, 'pinned-provider');
        expect(created.chatModelId, 'pinned-model');
        expect(
          (await chat.loadSelectedContextMessages(
            created.id,
            limit: 1,
          )).map((m) => m.content),
          ['Edited summary', if (keepTail) 'assistant 2'],
        );
        expect(chat.getToolEvents(copied.first.id), isEmpty);
        if (keepTail) {
          expect(chat.getToolEvents(copied.last.id), [
            {'id': 'tool', 'name': 'search', 'content': 'retained result'},
          ]);
        }
        expect(
          (await chat.loadContextSnapshot(sourceId)).fingerprint,
          before.fingerprint,
        );
        expect(chat.currentConversationId, sourceId);

        await chat.close();
        chat = ChatService();
        await chat.init();
        if (temporary) {
          expect(chat.getConversation(created.id), isNull);
          expect(await chat.loadMessages(created.id), isEmpty);
          expect(
            await chat.chatRepositoryOrNull!.getConversation(created.id),
            isNull,
          );
          return;
        }
        expect(
          (await chat.loadMessages(created.id)).map((m) => m.content),
          expected,
        );
        expect(
          (await chat.loadSelectedContextMessages(
            created.id,
            limit: 100,
          )).map((m) => m.content),
          expected,
        );
        expect(
          (await chat.loadContextOperations(created.id)).single.sourceGroups,
          [copied.first.id],
        );
        expect(
          chat.getConversation(created.id)!.chatModelProvider,
          'pinned-provider',
        );
        expect(chat.getConversation(created.id)!.chatModelId, 'pinned-model');
        expect(
          (await chat.loadSelectedContextMessages(
            created.id,
            limit: 1,
          )).first.content,
          'Edited summary',
        );
        if (!temporary) {
          expect(
            (await chat.loadContextSnapshot(sourceId)).fingerprint,
            before.fingerprint,
          );
        }
      });
    }
  }

  for (final state in ['revoked', 'hidden', 'superseded']) {
    test('cannot continue from a $state summary', () async {
      final operation = await compress();
      final snapshot = await chat.loadContextSnapshot(sourceId);
      if (state == 'revoked') {
        await chat.changeContextOperation(
          sourceId,
          operation.id,
          includeDependents: true,
          expectedState: ContextHistory.operationsFingerprint(
            snapshot.operations,
          ),
        );
      } else if (state == 'hidden') {
        await chat.clearConversationContext(sourceId);
      } else {
        await chat.appendContextOperation(
          sourceId,
          ContextOperation(
            id: 'new-summary',
            kind: ContextOperationKind.compress,
            anchorGroupId: ContextHistory.group(messages.last),
            appliedAfterGroupId: ContextHistory.group(messages.last),
            sourceGroups: messages.map(ContextHistory.group).toList(),
            dependencies: [operation.id],
            createdAt: DateTime(2026),
            summary: 'New summary',
          ),
          expectedFingerprint: snapshot.fingerprint,
        );
      }
      final before = await chat.chatRepositoryOrNull!
          .getAllConversationSummaries();
      await expectLater(
        chat.continueFromContextSummary(sourceId, operation.id),
        throwsStateError,
      );
      expect(
        (await chat.chatRepositoryOrNull!.getAllConversationSummaries()).map(
          (c) => c.id,
        ),
        before.map((c) => c.id),
      );
    });
  }

  test(
    'temporary compression publishes only a complete, usable target',
    () async {
      final operation = await compress(temporary: true);
      final copying = chat as _PausingCopyChatService;
      final gate = Completer<void>();
      copying.copyGate = gate;
      copying.copyTarget = Completer<String>();
      String? targetId;
      String? adopted;
      final publishedCounts = <int>[];
      void adoptNewConversation() {
        if (adopted != null) return;
        final target = targetId == null
            ? null
            : chat.getCompleteConversation(targetId);
        if (target == null) return;
        publishedCounts.add(chat.getMessageCount(target.id));
        expect(chat.contextOperationsFor(target.id), hasLength(1));
        expect(target.chatModelProvider, 'pinned-provider');
        expect(target.chatModelId, 'pinned-model');
        adopted = target.id;
        chat.setCurrentConversation(target.id);
      }

      chat.addListener(adoptNewConversation);
      try {
        final future = chat.continueFromContextSummary(sourceId, operation.id);
        targetId = await copying.copyTarget!.future;
        expect(chat.getCompleteConversation(targetId), isNull);
        gate.complete();
        final created = await future;
        expect(adopted, created.id);
        expect(publishedCounts, [3]);
        expect(chat.currentConversationId, created.id);
        expect(chat.getConversation(sourceId), isNull);
        expect(
          await chat.chatRepositoryOrNull!.getConversation(created.id),
          isNull,
        );
        expect(
          (await chat.loadSelectedContextMessages(
            created.id,
            limit: 1,
          )).map((m) => m.content),
          ['Edited summary', 'assistant 2'],
        );
      } finally {
        chat.removeListener(adoptNewConversation);
      }
    },
  );

  test('unpublished temporary copies cannot be searched or selected', () async {
    final visible = await chat.createConversation(
      title: 'Original visible chat',
    );
    final operation = await compress(temporary: true);
    final copying = chat as _PausingCopyChatService;
    final gate = Completer<void>();
    copying.copyGate = gate;
    copying.copyTarget = Completer<String>();
    final future = chat.continueFromContextSummary(sourceId, operation.id);
    final targetId = await copying.copyTarget!.future;
    try {
      expect(chat.getAllConversations().any((c) => c.id == targetId), isFalse);
      expect(chat.getCompleteConversation(targetId), isNull);
      chat.setCurrentConversation(targetId);
      expect(chat.currentConversationId, sourceId);
      final results = await chat.searchConversationMatches(
        tokens: ['original'],
        limit: 1,
      );
      expect(results, isNotEmpty);
      expect(
        results.every((match) => match.conversationId == visible.id),
        isTrue,
      );
    } finally {
      gate.complete();
    }
    final created = await future;
    expect(created.id, targetId);
    expect(chat.getCompleteConversation(targetId), isNotNull);
    expect(
      (await chat.searchConversationMatches(
        tokens: ['original'],
      )).any((match) => match.conversationId == targetId),
      isFalse, // Temporary chats stay out of persisted search.
    );
    chat.setCurrentConversation(targetId);
    expect(chat.currentConversationId, targetId);
  });

  testWidgets('summary details continue action opens the compact new chat', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    try {
      late ContextOperation operation;
      late SettingsProvider settings;
      late AssistantProvider assistants;
      await tester.runAsync(() async {
        operation = await compress();
        settings = SettingsProvider(createBusinessTestPreferences());
        assistants = AssistantProvider(
          preferences: createBusinessTestPreferences(),
        );
        await Future.wait([settings.loaded, assistants.loaded]);
      });
      addTearDown(settings.dispose);
      addTearDown(assistants.dispose);
      chat.contextCompression.estimateCandidate =
          (_, _, {bool? fixedContextStart}) async =>
              (usedTokens: 100, contextWindow: 4000);
      Future<void> pumpUntil(bool Function() complete) async {
        for (var i = 0; i < 500; i++) {
          await tester.pump();
          if (complete()) return;
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 10)),
          );
        }
        fail('Context continuation did not finish');
      }

      late BuildContext pageContext;
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: settings),
            ChangeNotifierProvider.value(value: assistants),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('en'),
            theme: buildLightTheme(null),
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
      final opened = Completer<String>();
      unawaited(
        showContextOperationDetails(
          pageContext,
          chat: chat,
          conversationId: sourceId,
          operation: operation,
          onOpenConversation: (id) async => opened.complete(id),
        ),
      );
      await pumpUntil(
        () =>
            find.byType(ContextOperationContent).evaluate().isNotEmpty &&
            tester
                    .widget<ContextOperationContent>(
                      find.byType(ContextOperationContent),
                    )
                    .onContinueNewChat !=
                null,
      );
      await tester.pumpAndSettle();
      expect(find.byType(ContextOperationContent), findsOneWidget);
      await tester.tap(find.byTooltip('More'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue in new chat'));
      await pumpUntil(() => opened.isCompleted);
      final id = await opened.future;
      await tester.runAsync(() async {
        expect((await chat.loadMessages(id)).map((m) => m.content), [
          'Edited summary',
          'user 2',
          'assistant 2',
        ]);
      });
      await tester.pumpAndSettle();
      expect(find.byType(ContextOperationContent), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}
