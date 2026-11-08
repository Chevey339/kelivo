import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:provider/provider.dart';

import 'package:Kelivo/core/database/chat_database_repository.dart';
import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/core/models/context_operation.dart';
import 'package:Kelivo/core/providers/assistant_provider.dart';
import 'package:Kelivo/core/services/chat/chat_service.dart';
import 'package:Kelivo/features/chat/widgets/context_message_count.dart';
import 'package:Kelivo/l10n/app_localizations.dart';

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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late PathProviderPlatform previousPaths;
  late ChatDatabaseRepository repository;
  late ChatService chat;
  late AssistantProvider assistants;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('context_count_');
    previousPaths = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _Paths(directory.path);
    repository = ChatDatabaseRepository.open(
      file: File('${directory.path}/chat.sqlite'),
    );
    chat = ChatService(existingRepository: repository);
    await chat.init();
    assistants = AssistantProvider(
      preferences: createBusinessTestPreferences(),
    );
    await assistants.loaded;
    final id = await assistants.addAssistant(name: 'Limited');
    await assistants.setCurrentAssistant(id);
    await assistants.updateAssistant(
      assistants.currentAssistant!.copyWith(
        limitContextMessages: true,
        contextMessageSize: 100,
      ),
    );
  });

  tearDown(() async {
    assistants.dispose();
    await chat.close();
    await repository.close();
    PathProviderPlatform.instance = previousPaths;
    await directory.delete(recursive: true);
  });

  Future<String> seed({int count = 120, bool temporary = false}) async {
    final conversation = temporary
        ? await chat.createDraftConversation(
            title: 'Temporary',
            assistantId: assistants.currentAssistantId,
            temporary: true,
          )
        : await chat.createConversation(
            title: 'History',
            assistantId: assistants.currentAssistantId,
          );
    for (var i = 0; i < count; i++) {
      await chat.addMessage(
        conversationId: conversation.id,
        role: i.isEven ? 'user' : 'assistant',
        content: 'message $i',
      );
    }
    return conversation.id;
  }

  Future<ContextOperation> compress(
    String id,
    int sourceCount, {
    int sourceStart = 0,
  }) async {
    final snapshot = await chat.loadContextSnapshot(id);
    final operation = ContextOperation(
      id: 'summary-$sourceCount',
      kind: ContextOperationKind.compress,
      anchorGroupId: ContextHistory.group(snapshot.messages[sourceCount - 1]),
      appliedAfterGroupId: ContextHistory.group(snapshot.messages.last),
      sourceGroups: snapshot.messages
          .skip(sourceStart)
          .take(sourceCount - sourceStart)
          .map(ContextHistory.group)
          .toList(),
      dependencies:
          ContextHistory.resolve(snapshot.messages, snapshot.operations)
              .where(ContextOperation.isSummary)
              .map(
                (message) =>
                    message.id.substring(ContextOperation.summaryPrefix.length),
              )
              .toList(),
      createdAt: DateTime.now(),
      summary: 'Compressed history',
    );
    await chat.appendContextOperation(
      id,
      operation,
      expectedFingerprint: snapshot.fingerprint,
    );
    return operation;
  }

  Future<void> undo(String id, ContextOperation operation) =>
      chat.changeContextOperation(
        id,
        operation.id,
        includeDependents: true,
        expectedState: ContextHistory.operationsFingerprint(
          chat.contextOperationsFor(id),
        ),
      );

  Future<void> pumpCount(WidgetTester tester, String? id) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: chat),
          ChangeNotifierProvider.value(value: assistants),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: ContextMessageCount(conversationId: id)),
        ),
      ),
    );
  }

  Future<void> expectLabel(WidgetTester tester, String label) async {
    for (var i = 0; i < 300; i++) {
      await tester.pump();
      if (find.text(label).evaluate().isNotEmpty) break;
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
    }
    expect(find.text(label), findsOneWidget);
    expect(tester.takeException(), isNull);
  }

  for (final temporary in [false, true]) {
    testWidgets(
      'count refreshes after compression, new messages, undo and clear: temporary=$temporary',
      (tester) async {
        addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
        final id = (await tester.runAsync(() => seed(temporary: temporary)))!;
        await pumpCount(tester, id);
        await expectLabel(tester, '100/100 messages');

        final operation = (await tester.runAsync(() => compress(id, 108)))!;
        await expectLabel(tester, '12/100 messages');
        await tester.runAsync(() async {
          final effective = await chat.loadSelectedContextMessages(
            id,
            limit: 100,
          );
          expect(effective.where(ContextOperation.isSummary), hasLength(1));
          expect(
            effective.where((m) => !ContextOperation.isSummary(m)),
            hasLength(12),
          );
          await chat.addMessage(
            conversationId: id,
            role: 'user',
            content: 'Next',
          );
        });
        await expectLabel(tester, '13/100 messages');

        await tester.runAsync(() => compress(id, 118));
        await expectLabel(tester, '3/100 messages');
        await tester.runAsync(() => undo(id, operation));
        await expectLabel(tester, '100/100 messages');
        await tester.runAsync(() => chat.clearConversationContext(id));
        await expectLabel(tester, '0/100 messages');
        await tester.runAsync(
          () => chat.addMessage(
            conversationId: id,
            role: 'user',
            content: 'After clear',
          ),
        );
        await expectLabel(tester, '1/100 messages');
      },
    );

    testWidgets(
      'fixed start counts follow compression, moving and cancelling: temporary=$temporary',
      (tester) async {
        addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
        late List<ChatMessage> messages;
        final id = (await tester.runAsync(() async {
          await assistants.updateAssistant(
            assistants.currentAssistant!.copyWith(contextMessageSize: 2),
          );
          final id = await seed(count: 12, temporary: temporary);
          messages = await chat.loadSelectedContextMessages(id, limit: 100);
          await compress(id, 8);
          return id;
        }))!;
        await pumpCount(tester, id);
        await expectLabel(tester, '2/2 messages');

        // A pin inside compressed history restores originals from that point
        // and ignores the assistant's rolling limit.
        await tester.runAsync(
          () => chat.setConversationContextStart(id, messages[4].id),
        );
        await expectLabel(tester, '8 messages');
        await tester.runAsync(() => compress(id, 10, sourceStart: 4));
        await expectLabel(tester, '2 messages');
        await tester.runAsync(() async {
          final effective = await chat.loadSelectedContextMessages(
            id,
            limit: 2,
          );
          expect(effective.map((message) => message.id), [
            '${ContextOperation.summaryPrefix}summary-10',
            messages[10].id,
            messages[11].id,
          ]);
        });

        await tester.runAsync(
          () => chat.setConversationContextStart(id, messages[6].id),
        );
        await expectLabel(tester, '6 messages');
        final start = ContextHistory.fixedStart(chat.contextOperationsFor(id))!;
        await tester.runAsync(() => undo(id, start));
        await expectLabel(tester, '2/2 messages');
        await tester.runAsync(() async {
          final effective = await chat.loadSelectedContextMessages(
            id,
            limit: 2,
          );
          expect(effective.map((message) => message.id), [
            '${ContextOperation.summaryPrefix}summary-8',
            messages[10].id,
            messages[11].id,
          ]);
        });
      },
    );
  }

  testWidgets('cold start counts compressed history outside the loaded page', (
    tester,
  ) async {
    addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
    final id = (await tester.runAsync(() async {
      final id = await seed();
      await compress(id, 108);
      await chat.close();
      chat = ChatService(existingRepository: repository);
      await chat.init();
      final page = await chat.loadTimelinePage(id, limit: 4);
      expect(page!.slots, hasLength(4));
      expect(chat.isConversationFullyCached(id), isFalse);
      return id;
    }))!;
    await pumpCount(tester, id);
    await expectLabel(tester, '12/100 messages');
  });

  testWidgets(
    'count follows conversation ownership, versions, limits and fixed start',
    (tester) async {
      addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
      late List<ChatMessage> messages;
      final id = (await tester.runAsync(() async {
        final id = await seed(count: 12);
        messages = await chat.loadSelectedContextMessages(id, limit: 100);
        await chat.appendMessageVersion(
          messageId: messages.last.id,
          content: 'Answer v2',
        );
        await chat.appendMessageVersion(
          messageId: messages.last.id,
          content: 'Answer v3',
        );
        final other = await assistants.addAssistant(name: 'Another assistant');
        await assistants.setCurrentAssistant(other);
        return id;
      }))!;
      await pumpCount(tester, id);
      await expectLabel(tester, '12/100 messages');
      final owner = assistants.getById(chat.getConversation(id)!.assistantId!)!;

      await tester.runAsync(
        () => assistants.updateAssistant(owner.copyWith(contextMessageSize: 2)),
      );
      await expectLabel(tester, '2/2 messages');
      await tester.runAsync(
        () => chat.setConversationContextStart(id, messages[4].id),
      );
      await expectLabel(tester, '8 messages');
      final start = ContextHistory.fixedStart(chat.contextOperationsFor(id))!;
      await tester.runAsync(() => undo(id, start));
      await expectLabel(tester, '2/2 messages');

      await tester.runAsync(
        () => assistants.updateAssistant(
          owner.copyWith(limitContextMessages: false),
        ),
      );
      await expectLabel(tester, '12 messages');
      await tester.runAsync(() => compress(id, 10));
      await expectLabel(tester, '2 messages');

      final next = (await tester.runAsync(() => seed(count: 4)))!;
      await pumpCount(tester, next);
      expect(find.text('2 messages'), findsNothing);
      await expectLabel(tester, '4 messages');
    },
  );
}
