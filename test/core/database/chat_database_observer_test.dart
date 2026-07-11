import 'dart:convert';
import 'dart:io';

import 'package:Kelivo/core/database/chat_database_observer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

void main() {
  group('ChatDatabaseObserver', () {
    test('computes bounded p50/p95 and aggregate result counts', () {
      final observer = ChatDatabaseObserver(maxSamplesPerOperation: 3);
      for (var index = 1; index <= 5; index++) {
        observer.record(
          ChatDatabaseObservation(
            operation: ChatDatabaseOperation.queryMessageRange,
            elapsedMicros: index * 10,
            succeeded: true,
            resultCount: index,
          ),
        );
      }

      final summary = observer
          .snapshot()
          .operations[ChatDatabaseOperation.queryMessageRange]!;
      expect(summary.totalCount, 5);
      expect(summary.retainedSamples, 3);
      expect(summary.p50Micros, 40);
      expect(summary.p95Micros, 50);
      expect(summary.maxMicros, 50);
      expect(summary.totalResultCount, 15);
    });

    test('measure records success and sanitized failure categories', () async {
      final observer = ChatDatabaseObserver();

      final values = await observer.measure(
        ChatDatabaseOperation.queryMessagesByIds,
        () async => [1, 2, 3],
        resultCount: (rows) => rows.length,
      );
      expect(values, [1, 2, 3]);

      final failures =
          <({Object error, ChatDatabaseFailureKind kind, int? errorCode})>[
            (
              error: sqlite.SqliteException(
                extendedResultCode: 787,
                message: 'secret-message',
                causingStatement: 'SELECT secret FROM private_path',
                parametersToStatement: const ['secret-parameter'],
              ),
              kind: ChatDatabaseFailureKind.sqlite,
              errorCode: 787,
            ),
            (
              error: const FileSystemException(
                'secret-filesystem-message',
                '/private/secret/path',
                OSError('secret-os-message', 13),
              ),
              kind: ChatDatabaseFailureKind.filesystem,
              errorCode: 13,
            ),
            (
              error: StateError('secret-state-message'),
              kind: ChatDatabaseFailureKind.state,
              errorCode: null,
            ),
            (
              error: ArgumentError('secret-input-message'),
              kind: ChatDatabaseFailureKind.input,
              errorCode: null,
            ),
            (
              error: Exception('secret-unknown-message'),
              kind: ChatDatabaseFailureKind.unknown,
              errorCode: null,
            ),
          ];
      for (final failure in failures) {
        await expectLater(
          observer.measure<void>(
            ChatDatabaseOperation.querySearch,
            () async => throw failure.error,
          ),
          throwsA(same(failure.error)),
        );
        final metric = observer
            .snapshot()
            .operations[ChatDatabaseOperation.querySearch]!;
        expect(metric.lastFailureKind, failure.kind);
        expect(metric.lastErrorCode, failure.errorCode);
      }

      final encoded = jsonEncode(observer.snapshot().toSafeJson());
      for (final sensitive in const [
        'secret-message',
        'SELECT secret',
        'secret-parameter',
        '/private/secret/path',
        'secret-os-message',
        'secret-state-message',
        'secret-input-message',
        'secret-unknown-message',
      ]) {
        expect(encoded, isNot(contains(sensitive)));
      }
    });

    test('tracks WAL and checkpoint result without paths or SQL', () {
      final observer = ChatDatabaseObserver();
      observer.record(
        const ChatDatabaseObservation(
          operation: ChatDatabaseOperation.walCheckpoint,
          elapsedMicros: 1200,
          succeeded: true,
          walBytesBefore: 8192,
          walBytesAfter: 0,
          checkpointBusy: 0,
          checkpointLogFrames: 2,
          checkpointedFrames: 2,
        ),
      );
      observer.record(
        const ChatDatabaseObservation(
          operation: ChatDatabaseOperation.walCheckpoint,
          elapsedMicros: 800,
          succeeded: false,
          failureKind: ChatDatabaseFailureKind.sqlite,
          errorCode: 5,
          walBytesBefore: 4096,
        ),
      );

      final snapshot = observer.snapshot();
      expect(snapshot.walPeakBytes, 8192);
      expect(snapshot.walLatestBytes, 0);
      expect(snapshot.checkpointCount, 2);
      expect(snapshot.checkpointFailureCount, 1);
      expect(snapshot.lastCheckpointBusy, isNull);
      expect(
        snapshot.operations[ChatDatabaseOperation.walCheckpoint]!.failureCount,
        1,
      );
      expect(
        snapshot.toSafeJson().keys,
        unorderedEquals(['format', 'operations', 'wal']),
      );
    });

    test('reset removes every retained metric', () {
      final observer = ChatDatabaseObserver();
      observer.record(
        const ChatDatabaseObservation(
          operation: ChatDatabaseOperation.gatewayOpen,
          elapsedMicros: 1,
          succeeded: true,
        ),
      );

      observer.reset();

      final snapshot = observer.snapshot();
      expect(snapshot.operations, isEmpty);
      expect(snapshot.walPeakBytes, 0);
      expect(snapshot.checkpointCount, 0);
    });
  });
}
