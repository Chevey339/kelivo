import 'dart:io';

import 'package:Kelivo/core/database/app_database.dart';
import 'package:Kelivo/core/database/bridge_delivery.dart';
import 'package:Kelivo/core/database/chat_database_repository.dart';
import 'package:Kelivo/core/database/generation_run.dart';
import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/core/models/conversation.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late AppDatabase database;
  late ChatDatabaseRepository repository;
  late Conversation conversation;
  final timestamp = DateTime.fromMicrosecondsSinceEpoch(1783784523123456);

  setUp(() async {
    database = AppDatabase(
      NativeDatabase.memory(
        setup: (raw) => raw.execute('PRAGMA foreign_keys = ON;'),
      ),
    );
    repository = ChatDatabaseRepository(database);
    await repository.ensureReady();
    conversation = Conversation(
      id: 'conversation-1',
      title: 'Conversation',
      createdAt: timestamp,
      updatedAt: timestamp,
    );
  });

  tearDown(() => repository.close());

  ChatMessage user(String id) => ChatMessage(
    id: id,
    conversationId: conversation.id,
    role: 'user',
    content: 'ROOM_EVENT\n{"content":"Question"}',
    timestamp: timestamp,
  );

  ChatMessage assistant(String id) => ChatMessage(
    id: id,
    conversationId: conversation.id,
    role: 'assistant',
    content: '',
    timestamp: timestamp.add(const Duration(microseconds: 1)),
    modelId: 'model',
    providerId: 'provider',
    isStreaming: true,
  );

  BridgeDeliveryClaim claim({String fingerprintCharacter = 'a'}) =>
      BridgeDeliveryClaim(
        originSystem: 'room-harness',
        originInstanceId: 'instance-1',
        idempotencyKey: 'delivery-1',
        requestFingerprint: fingerprintCharacter * 64,
        roomEventId: 'event-1',
        roomId: 'room-1',
      );

  Future<BridgeGenerationBeginResult> begin({
    String userId = 'user-1',
    String assistantId = 'assistant-1',
    String runId = 'run-1',
    BridgeDeliveryClaim? deliveryClaim,
    Conversation? source,
  }) => repository.beginBridgeSendGeneration(
    conversation: source ?? conversation,
    userMessage: user(userId),
    assistantMessage: assistant(assistantId),
    runId: runId,
    deliveryClaim: deliveryClaim ?? claim(),
  );

  test(
    'bridge claim, native pair and generation run commit atomically',
    () async {
      final result = await begin();

      expect(result.disposition, BridgeGenerationBeginDisposition.created);
      expect(result.generation?.userMessage?.id, 'user-1');
      expect(result.generation?.assistantMessage.id, 'assistant-1');
      expect(result.delivery.generationRunId, 'run-1');
      expect(result.delivery.state, GenerationRunState.preparing);
      expect(await repository.getMessageIds(conversation.id), [
        'user-1',
        'assistant-1',
      ]);
      expect(
        await database.select(database.generationRunRows).get(),
        hasLength(1),
      );
      expect(
        await database.select(database.bridgeDeliveryRows).get(),
        hasLength(1),
      );
    },
  );

  test(
    'same idempotency key and fingerprint returns the original turn',
    () async {
      final first = await begin();
      final duplicate = await begin(
        userId: 'user-2',
        assistantId: 'assistant-2',
        runId: 'run-2',
        source: first.generation!.conversation,
      );

      expect(duplicate.disposition, BridgeGenerationBeginDisposition.duplicate);
      expect(duplicate.generation, isNull);
      expect(duplicate.delivery.userRevisionId, 'user-1');
      expect(duplicate.delivery.assistantRevisionId, 'assistant-1');
      expect(await repository.getMessage('user-2'), isNull);
      expect(await repository.getMessage('assistant-2'), isNull);
      expect(
        await database.select(database.generationRunRows).get(),
        hasLength(1),
      );
      expect(
        await database.select(database.bridgeDeliveryRows).get(),
        hasLength(1),
      );
    },
  );

  test(
    'same idempotency key with a different payload writes nothing',
    () async {
      final first = await begin();
      final conflict = await begin(
        userId: 'user-2',
        assistantId: 'assistant-2',
        runId: 'run-2',
        deliveryClaim: claim(fingerprintCharacter: 'b'),
        source: first.generation!.conversation,
      );

      expect(conflict.disposition, BridgeGenerationBeginDisposition.conflict);
      expect(conflict.generation, isNull);
      expect(await repository.getMessageCount(conversation.id), 2);
      expect(
        await database.select(database.generationRunRows).get(),
        hasLength(1),
      );
      expect(
        await database.select(database.bridgeDeliveryRows).get(),
        hasLength(1),
      );
    },
  );

  test(
    'mapping insert is rolled back when generation run insert fails',
    () async {
      final native = await repository.beginSendGeneration(
        conversation: conversation,
        userMessage: user('native-user'),
        assistantMessage: assistant('native-assistant'),
        runId: 'run-1',
      );

      await expectLater(
        begin(
          userId: 'bridge-user',
          assistantId: 'bridge-assistant',
          runId: 'run-1',
          source: native.conversation,
        ),
        throwsA(anything),
      );

      expect(await repository.getMessage('bridge-user'), isNull);
      expect(await repository.getMessage('bridge-assistant'), isNull);
      expect(await database.select(database.bridgeDeliveryRows).get(), isEmpty);
      expect(await repository.getMessageCount(conversation.id), 2);
    },
  );

  test(
    'terminal run state and final assistant snapshot update the mapping',
    () async {
      final started = await begin();
      var run = started.generation!.run;
      run = await repository.transitionGenerationRun(
        id: run.id,
        expectedState: run.state,
        expectedStateRevision: run.stateRevision,
        nextState: GenerationRunState.requesting,
        updatedAt: timestamp.add(const Duration(microseconds: 2)),
      );
      run = await repository.transitionGenerationRun(
        id: run.id,
        expectedState: run.state,
        expectedStateRevision: run.stateRevision,
        nextState: GenerationRunState.streaming,
        updatedAt: timestamp.add(const Duration(microseconds: 3)),
      );

      await repository.finalizeGenerationRun(
        message: started.generation!.assistantMessage.copyWith(
          content: 'final answer',
          isStreaming: false,
        ),
        toolEvents: const [],
        generationRunId: run.id,
        expectedState: run.state,
        expectedStateRevision: run.stateRevision,
        terminalState: GenerationRunState.completed,
        checkpointSeq: 1,
      );

      final snapshot = await repository.getBridgeTurnSnapshot(
        originInstanceId: 'instance-1',
        idempotencyKey: 'delivery-1',
      );
      expect(snapshot?.delivery.state, GenerationRunState.completed);
      expect(snapshot?.run.state, GenerationRunState.completed);
      expect(snapshot?.assistantMessage.content, 'final answer');
    },
  );

  test(
    'restart recovery interrupts the run and durable bridge mapping',
    () async {
      await begin();

      expect(await repository.resetStaleStreamingState(), 1);

      final snapshot = await repository.getBridgeTurnSnapshot(
        originInstanceId: 'instance-1',
        idempotencyKey: 'delivery-1',
      );
      expect(snapshot?.delivery.state, GenerationRunState.interrupted);
      expect(snapshot?.run.state, GenerationRunState.interrupted);
      expect(snapshot?.run.errorCode, 'app_restart');
      expect(snapshot?.assistantMessage.isStreaming, isFalse);
    },
  );

  test('mapping survives closing and reopening the database', () async {
    final directory = Directory(
      '.dart_tool/bridge-restart-${DateTime.now().microsecondsSinceEpoch}',
    );
    await directory.create(recursive: true);
    final file = File('${directory.path}/kelivo.db');
    ChatDatabaseRepository? firstRepository;
    ChatDatabaseRepository? reopenedRepository;
    try {
      final firstDatabase = AppDatabase.open(file: file);
      firstRepository = ChatDatabaseRepository(firstDatabase);
      await firstRepository.ensureReady();
      final localConversation = Conversation(
        id: 'restart-conversation',
        title: 'Restart',
        createdAt: timestamp,
        updatedAt: timestamp,
      );
      await firstRepository.beginBridgeSendGeneration(
        conversation: localConversation,
        userMessage: user(
          'restart-user',
        ).copyWith(conversationId: localConversation.id),
        assistantMessage: assistant(
          'restart-assistant',
        ).copyWith(conversationId: localConversation.id),
        runId: 'restart-run',
        deliveryClaim: claim(),
      );
      await firstRepository.close();
      firstRepository = null;

      final reopenedDatabase = AppDatabase.open(file: file);
      reopenedRepository = ChatDatabaseRepository(reopenedDatabase);
      await reopenedRepository.ensureReady();
      final snapshot = await reopenedRepository.getBridgeTurnSnapshot(
        originInstanceId: 'instance-1',
        idempotencyKey: 'delivery-1',
      );
      expect(snapshot?.delivery.userRevisionId, 'restart-user');
      expect(snapshot?.delivery.assistantRevisionId, 'restart-assistant');
      expect(snapshot?.delivery.generationRunId, 'restart-run');
    } finally {
      await firstRepository?.close();
      await reopenedRepository?.close();
      if (await directory.exists()) await directory.delete(recursive: true);
    }
  });
}
