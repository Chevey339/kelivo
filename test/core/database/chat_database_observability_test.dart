import 'dart:convert';
import 'dart:io';

import 'package:Kelivo/core/database/chat_database_observer.dart';
import 'package:Kelivo/core/database/chat_database_repository.dart';
import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/core/models/conversation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Chat database observability', () {
    late Directory directory;
    late File databaseFile;
    late ChatDatabaseObserver observer;
    late ChatDatabaseRepository repository;

    setUp(() async {
      directory = await Directory.systemTemp.createTemp(
        'kelivo_database_observability_',
      );
      databaseFile = File('${directory.path}/private-database-name.sqlite');
      observer = ChatDatabaseObserver();
      repository = ChatDatabaseRepository.open(
        file: databaseFile,
        observer: observer,
      );
      await repository.ensureReady();
    });

    tearDown(() async {
      await repository.close();
      if (await directory.exists()) await directory.delete(recursive: true);
    });

    ChatMessage message({
      required String id,
      required String content,
      bool streaming = false,
      String role = 'assistant',
    }) {
      return ChatMessage(
        id: id,
        role: role,
        content: content,
        conversationId: 'private-conversation-id',
        isStreaming: streaming,
      );
    }

    test('records query, command, WAL and checkpoint aggregates', () async {
      const secret = 'must-not-appear-in-database-observation';
      final connection = await repository.validateConnectionContract();
      expect(connection.schemaVersion, 3);
      expect(connection.journalModeWal, isTrue);
      expect(connection.foreignKeysEnabled, isTrue);
      expect(connection.busyTimeoutMillis, 5000);
      expect(connection.synchronous, 2);
      expect(connection.walAutoCheckpointPages, 1000);
      expect(connection.journalSizeLimitBytes, 16 << 20);
      final conversation = Conversation(
        id: 'private-conversation-id',
        title: 'Private title $secret',
      );
      final streaming = message(
        id: 'private-message-id',
        content: secret,
        streaming: true,
      );
      await repository.appendMessageToConversation(
        conversation: conversation,
        message: streaming,
      );
      await repository.getAllConversationSummaries();
      await repository.getMessagesRange(conversation.id, start: 0, limit: 20);
      await repository.getMessagesByIds([streaming.id]);
      await repository.searchConversationMatches(tokens: const [secret]);
      await repository.updateStreamingCheckpoint(streaming, const [
        {
          'name': 'private-tool-name',
          'content': secret,
          'arguments': {'secret': secret},
        },
      ]);
      await repository.updateStreamingCheckpoint(
        message(id: streaming.id, content: secret),
        const [],
      );
      await repository.checkpoint();

      final snapshot = observer.snapshot();
      expect(snapshot.connectionContract, same(connection));
      expect(
        snapshot
            .operations[ChatDatabaseOperation.queryConversationList]
            ?.totalCount,
        1,
      );
      expect(
        snapshot
            .operations[ChatDatabaseOperation.queryMessageRange]
            ?.totalResultCount,
        1,
      );
      expect(
        snapshot.operations[ChatDatabaseOperation.querySearch]?.totalCount,
        1,
      );
      expect(
        snapshot
            .operations[ChatDatabaseOperation.commandStreamingCheckpoint]
            ?.totalCount,
        1,
      );
      expect(
        snapshot
            .operations[ChatDatabaseOperation.commandFinalCheckpoint]
            ?.totalCount,
        1,
      );
      expect(snapshot.checkpointCount, 1);
      expect(snapshot.checkpointFailureCount, 0);
      expect(snapshot.lastCheckpointBusy, 0);
      expect(snapshot.lastCheckpointedFrames, isNotNull);
      expect(snapshot.walPeakBytes, greaterThan(0));
      expect(snapshot.walLatestBytes, 0);

      final encoded = jsonEncode(snapshot.toSafeJson());
      for (final sensitive in [
        secret,
        conversation.id,
        streaming.id,
        databaseFile.path,
        'private-tool-name',
        'SELECT',
        'message_rows',
      ]) {
        expect(encoded, isNot(contains(sensitive)));
      }
    });

    test('records rollback failure without database values', () async {
      const secret = 'failed-secret-content';
      await expectLater(
        repository.appendMessageToConversation(
          conversation: Conversation(
            id: 'private-conversation-id',
            title: secret,
          ),
          message: message(id: 'private-message-id', content: secret, role: ''),
        ),
        throwsA(anything),
      );

      final metric = observer
          .snapshot()
          .operations[ChatDatabaseOperation.commandAppendMessage]!;
      expect(metric.totalCount, 1);
      expect(metric.failureCount, 1);
      expect(metric.lastFailureKind, ChatDatabaseFailureKind.remoteDatabase);
      expect(
        jsonEncode(metric.toSafeJson()),
        isNot(anyOf(contains(secret), contains('private-message-id'))),
      );
      expect(await repository.getConversationCount(), 0);
    });

    test(
      'records checkpoint failure and keeps the original error visible',
      () async {
        await repository.close();

        await expectLater(repository.checkpoint(), throwsA(anything));

        final snapshot = observer.snapshot();
        expect(snapshot.checkpointCount, 1);
        expect(snapshot.checkpointFailureCount, 1);
        final metric =
            snapshot.operations[ChatDatabaseOperation.walCheckpoint]!;
        expect(metric.failureCount, 1);
        expect(metric.lastFailureKind, isNotNull);

        repository = ChatDatabaseRepository.open(
          file: databaseFile,
          observer: observer,
        );
        await repository.ensureReady();
      },
    );
  });
}
