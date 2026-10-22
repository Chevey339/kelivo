import 'dart:convert';
import 'dart:io';
import 'package:Kelivo/core/database/chat_database_repository.dart';
import 'package:Kelivo/core/models/conversation.dart';
import 'package:Kelivo/core/models/chat_message.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;
import 'package:Kelivo/core/database/database_installation_gate.dart';
import 'package:Kelivo/core/database/chat_database_gateway.dart';
import 'package:Kelivo/core/database/empty_database_recovery_guard.dart';
import 'package:Kelivo/core/services/backup/local_copy_catalog.dart';
import 'package:Kelivo/core/services/backup/data_sync.dart';
import 'package:Kelivo/core/services/backup/local_snapshot_schedule.dart';
import '../../support/recovery_snapshot_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('kelivo-loss-recovery-');
  });
  tearDown(() async => root.delete(recursive: true));
  for (final location in [
    '',
    'snapshots',
    'snapshots 2',
    'snapshots 3',
    'snapshots (2)',
  ]) {
    test(
      'discovers and validates snapshot at $location without moving or deleting it',
      () async {
        final name = LocalSnapshotPaths.fileNameFor(DateTime.utc(2026, 10, 19));
        final archive = await writeRecoverySnapshot(
          File('${root.path}/${location.isEmpty ? '' : '$location/'}$name'),
        );
        final before = await archive.readAsBytes();
        final catalog = LocalCopyCatalog(appDataDirectory: root);
        final copies = await catalog.list();
        expect(copies, hasLength(1));
        expect(copies.single.file.path, archive.path);
        final info = await DataSync.inspectRecoverySnapshot(copies.single.file);
        expect(info.conversationCount, 2);
        expect(info.messageCount, 42);
        if (copies.single.discovered) {
          expect(
            () => catalog.delete(copies.single),
            throwsA(isA<StateError>()),
          );
        }
        expect(await archive.readAsBytes(), before);
        await expectLater(
          DatabaseInstallationGate.ensureReady(appDataDirectory: root),
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'code',
              'database_missing_with_prior_data',
            ),
          ),
        );
        expect(await File('${root.path}/kelivo.db').exists(), isFalse);
      },
    );
  }
  test(
    'retains different archives with identical names in separate folders',
    () async {
      const name = 'kelivo-snapshot-1792421104232879.zip';
      await writeRecoverySnapshot(File('${root.path}/snapshots 2/$name'));
      await writeRecoverySnapshot(
        File('${root.path}/snapshots 3/$name'),
        conversations: 1,
        messages: 3,
      );
      final copies = await LocalCopyCatalog(appDataDirectory: root).list();
      expect(copies, hasLength(2));
      expect(copies.map((c) => c.id).toSet(), hasLength(2));
    },
  );
  test('rejects corrupt snapshots without modifying the original', () async {
    final file = File('${root.path}/kelivo-snapshot-1792421104232879.zip');
    await file.writeAsString('retained damaged archive');
    await expectLater(
      DataSync.inspectRecoverySnapshot(file),
      throwsA(anything),
    );
    expect(await file.readAsString(), 'retained damaged archive');
  });
  test(
    'database journals are retained with their copy, not listed as databases',
    () async {
      final base = '${root.path}/kelivo.db.displaced-0000000000000001';
      for (final suffix in ['', '-wal', '-shm', '-journal']) {
        await File('$base$suffix').writeAsString('retained $suffix');
      }
      final copies = await LocalCopyCatalog(appDataDirectory: root).list();
      expect(copies, hasLength(1));
      expect(copies.single.file.path, base);
      for (final suffix in ['', '-wal', '-shm', '-journal']) {
        expect(await File('$base$suffix').readAsString(), 'retained $suffix');
      }
    },
  );
  test('an orphaned renamed WAL still blocks empty initialization', () async {
    final wal = File('${root.path}/kelivo 2.db-wal');
    await wal.writeAsString('committed history');
    await expectLater(
      DatabaseInstallationGate.ensureReady(appDataDirectory: root),
      throwsA(isA<StateError>()),
    );
    expect(await File('${root.path}/kelivo.db').exists(), isFalse);
    expect(await wal.readAsString(), 'committed history');
  });
  test(
    'valid empty database pauses before defaults and allows explicit acknowledgement',
    () async {
      final receipt = await DatabaseInstallationGate.ensureReady(
        appDataDirectory: root,
      );
      final name = LocalSnapshotPaths.fileNameFor(DateTime.utc(2026, 10, 19));
      final file = await writeRecoverySnapshot(
        File('${root.path}/snapshots/$name'),
      );
      await File(
        '${file.path}.json',
      ).writeAsString(jsonEncode({'conversationCount': 2, 'messageCount': 42}));
      Future<void> check() => EmptyDatabaseRecoveryGuard.check(
        appDataDirectory: root,
        databaseId: receipt.databaseId,
      );
      await expectLater(
        check(),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'code',
            'database_empty_with_recovery_copies',
          ),
        ),
      );
      await EmptyDatabaseRecoveryGuard.acknowledge(root);
      await check();
      final db = sqlite.sqlite3.open('${root.path}/kelivo.db');
      db.execute(
        "INSERT INTO conversation_rows (id,title,created_at,updated_at) VALUES ('new','New',1,1)",
      );
      db.close();
      await check();
      final later = sqlite.sqlite3.open('${root.path}/kelivo.db');
      later.execute('DELETE FROM conversation_rows');
      later.close();
      await expectLater(check(), throwsA(isA<StateError>()));
      expect(await file.exists(), isTrue);
    },
  );
  test(
    'deleting the last conversation intentionally allows an empty startup',
    () async {
      final receipt = await DatabaseInstallationGate.ensureReady(
        appDataDirectory: root,
      );
      await writeRecoverySnapshot(File('${root.path}/kelivo-snapshot-old.zip'));
      final repository = ChatDatabaseRepository.open(
        file: File('${root.path}/kelivo.db'),
      );
      try {
        await repository.putConversation(
          Conversation(id: 'last', title: 'Last'),
        );
        await repository.putMessage(
          ChatMessage(
            id: 'last-message',
            conversationId: 'last',
            role: 'user',
            content: 'Last message',
          ),
        );
        await repository.deleteConversation('last');
        expect(await repository.readTombstones(), hasLength(1));
      } finally {
        await repository.close();
      }
      await EmptyDatabaseRecoveryGuard.check(
        appDataDirectory: root,
        databaseId: receipt.databaseId,
      );
    },
  );
  test(
    'a no-op deletion cannot authorize an unexplained empty database',
    () async {
      final receipt = await DatabaseInstallationGate.ensureReady(
        appDataDirectory: root,
      );
      await writeRecoverySnapshot(File('${root.path}/kelivo-snapshot-old.zip'));
      final repository = ChatDatabaseRepository.open(
        file: File('${root.path}/kelivo.db'),
      );
      try {
        await repository.deleteConversation('missing');
      } finally {
        await repository.close();
      }
      await expectLater(
        EmptyDatabaseRecoveryGuard.check(
          appDataDirectory: root,
          databaseId: receipt.databaseId,
        ),
        throwsStateError,
      );
    },
  );
  for (final replace in [false, true]) {
    test(
      'explicit ${replace ? 'empty replacement' : 'clear all'} remains allowed with retained chats',
      () async {
        final receipt = await DatabaseInstallationGate.ensureReady(
          appDataDirectory: root,
        );
        await writeRecoverySnapshot(
          File('${root.path}/kelivo-snapshot-old.zip'),
        );
        final repository = ChatDatabaseRepository.open(
          file: File('${root.path}/kelivo.db'),
        );
        try {
          await repository.putConversation(
            Conversation(id: 'old', title: 'Old'),
          );
          if (replace) {
            await repository.replaceBackupData(
              conversations: [],
              messages: [],
              toolEventsByMessageId: {},
              geminiSignaturesByMessageId: {},
            );
          } else {
            await repository.clearAllData();
          }
        } finally {
          await repository.close();
        }
        await EmptyDatabaseRecoveryGuard.check(
          appDataDirectory: root,
          databaseId: receipt.databaseId,
        );
      },
    );
  }
  test(
    'a rolled-back last deletion cannot grant empty-state permission',
    () async {
      final receipt = await DatabaseInstallationGate.ensureReady(
        appDataDirectory: root,
      );
      await writeRecoverySnapshot(File('${root.path}/kelivo-snapshot-old.zip'));
      final live = File('${root.path}/kelivo.db');
      var repository = ChatDatabaseRepository.open(file: live);
      await repository.putConversation(Conversation(id: 'last', title: 'Last'));
      await repository.close();
      final fault = sqlite.sqlite3.open(live.path);
      fault.execute(
        "CREATE TRIGGER reject_empty_permission BEFORE INSERT ON chat_storage_meta_rows WHEN NEW.key = 'intentional_empty_chat_state_v1' BEGIN SELECT RAISE(ABORT, 'injected failure after permission file'); END",
      );
      fault.close();
      repository = ChatDatabaseRepository.open(file: live);
      try {
        await expectLater(
          repository.deleteConversation('last'),
          throwsA(anything),
        );
        expect(await repository.getConversation('last'), isNotNull);
        expect(await repository.readTombstones(), isEmpty);
      } finally {
        await repository.close();
      }
      // The acknowledgement file was published, but its DB transaction failed.
      final later = sqlite.sqlite3.open(live.path);
      later.execute('DELETE FROM conversation_rows');
      later.close();
      await expectLater(
        EmptyDatabaseRecoveryGuard.check(
          appDataDirectory: root,
          databaseId: receipt.databaseId,
        ),
        throwsStateError,
      );
    },
  );
  test(
    'restoring an old empty database cannot restore its expired permission',
    () async {
      final receipt = await DatabaseInstallationGate.ensureReady(
        appDataDirectory: root,
      );
      await writeRecoverySnapshot(File('${root.path}/kelivo-snapshot-old.zip'));
      await EmptyDatabaseRecoveryGuard.acknowledge(root);
      final live = File('${root.path}/kelivo.db');
      final priorEmpty = await live.copy('${root.path}/old-empty.sqlite');
      final repository = ChatDatabaseRepository.open(file: live);
      try {
        await repository.putConversation(Conversation(id: 'new', title: 'New'));
      } finally {
        await repository.close();
      }
      await priorEmpty.copy(live.path);
      await expectLater(
        EmptyDatabaseRecoveryGuard.check(
          appDataDirectory: root,
          databaseId: receipt.databaseId,
        ),
        throwsStateError,
      );
    },
  );
  test(
    'failed and empty merges do not revoke a valid empty-state choice',
    () async {
      final receipt = await DatabaseInstallationGate.ensureReady(
        appDataDirectory: root,
      );
      await writeRecoverySnapshot(File('${root.path}/kelivo-snapshot-old.zip'));
      await EmptyDatabaseRecoveryGuard.acknowledge(root);
      final empty = File('${root.path}/empty-source.sqlite');
      final source = ChatDatabaseRepository.open(file: empty);
      await source.ensureReady();
      await source.close();
      final repository = ChatDatabaseRepository.open(
        file: File('${root.path}/kelivo.db'),
      );
      try {
        await expectLater(
          repository.mergeBackupSnapshot(File('${root.path}/missing.sqlite')),
          throwsA(isA<FileSystemException>()),
        );
        final report = await repository.mergeBackupSnapshot(empty);
        expect(report.importedConversations, 0);
      } finally {
        await repository.close();
      }
      await EmptyDatabaseRecoveryGuard.check(
        appDataDirectory: root,
        databaseId: receipt.databaseId,
      );
    },
  );
  test(
    'empty snapshots and removal of old copies keep an empty choice valid',
    () async {
      final receipt = await DatabaseInstallationGate.ensureReady(
        appDataDirectory: root,
      );
      final old = await writeRecoverySnapshot(
        File('${root.path}/kelivo-snapshot-old.zip'),
      );
      await EmptyDatabaseRecoveryGuard.acknowledge(root);
      await writeRecoverySnapshot(
        File('${root.path}/kelivo-snapshot-empty.zip'),
        conversations: 0,
        messages: 0,
      );
      Future<void> check() => EmptyDatabaseRecoveryGuard.check(
        appDataDirectory: root,
        databaseId: receipt.databaseId,
      );
      await check();
      await old.delete();
      await check();
    },
  );
  test('a nonempty database cannot receive an empty-start permission', () async {
    final receipt = await DatabaseInstallationGate.ensureReady(
      appDataDirectory: root,
    );
    await writeRecoverySnapshot(File('${root.path}/kelivo-snapshot-old.zip'));
    final repository = ChatDatabaseRepository.open(
      file: File('${root.path}/kelivo.db'),
    );
    try {
      await repository.putConversation(
        Conversation(id: 'restored', title: 'Restored'),
      );
    } finally {
      await repository.close();
    }
    // main calls this after a successful database restore, including nonempty ones.
    await EmptyDatabaseRecoveryGuard.acknowledge(root);
    final database = sqlite.sqlite3.open('${root.path}/kelivo.db');
    database.execute('DELETE FROM conversation_rows');
    database.close();
    await expectLater(
      EmptyDatabaseRecoveryGuard.check(
        appDataDirectory: root,
        databaseId: receipt.databaseId,
      ),
      throwsStateError,
    );
  });
  test(
    'an acknowledgement cannot hide data loss after a new snapshot in the same session',
    () async {
      final receipt = await DatabaseInstallationGate.ensureReady(
        appDataDirectory: root,
      );
      final old = await writeRecoverySnapshot(
        File('${root.path}/snapshots 2/kelivo-snapshot-1.zip'),
      );
      await EmptyDatabaseRecoveryGuard.acknowledge(root);
      final db = sqlite.sqlite3.open('${root.path}/kelivo.db');
      db.execute(
        "INSERT INTO conversation_rows (id,title,created_at,updated_at) VALUES ('new','New',1,1)",
      );
      // There is no intervening nonempty startup check to clear the old ack.
      final latest = await writeRecoverySnapshot(
        File('${root.path}/snapshots 2/kelivo-snapshot-2.zip'),
      );
      await old.rename(
        '${old.path}.retained',
      ); // the number of copies is unchanged
      db.execute('DELETE FROM conversation_rows');
      db.close();
      await expectLater(
        EmptyDatabaseRecoveryGuard.check(
          appDataDirectory: root,
          databaseId: receipt.databaseId,
        ),
        throwsStateError,
      );
      expect(await latest.exists(), isTrue);
    },
  );
  test(
    'conversation writes invalidate the acknowledgement before any new snapshot exists',
    () async {
      final receipt = await DatabaseInstallationGate.ensureReady(
        appDataDirectory: root,
      );
      await writeRecoverySnapshot(File('${root.path}/kelivo-snapshot-1.zip'));
      await EmptyDatabaseRecoveryGuard.acknowledge(root);
      final repository = ChatDatabaseRepository.open(
        file: File('${root.path}/kelivo.db'),
      );
      try {
        await repository.putConversation(Conversation(id: 'new', title: 'New'));
      } finally {
        await repository.close();
      }
      expect(
        await File(
          '${root.path}/${EmptyDatabaseRecoveryGuard.acknowledgementName}',
        ).exists(),
        isFalse,
      );
      final db = sqlite.sqlite3.open('${root.path}/kelivo.db');
      db.execute('DELETE FROM conversation_rows');
      db.close();
      await expectLater(
        EmptyDatabaseRecoveryGuard.check(
          appDataDirectory: root,
          databaseId: receipt.databaseId,
        ),
        throwsStateError,
      );
    },
  );
  test(
    'first message in a draft conversation invalidates an empty start acknowledgement',
    () async {
      final receipt = await DatabaseInstallationGate.ensureReady(
        appDataDirectory: root,
      );
      await writeRecoverySnapshot(File('${root.path}/kelivo-snapshot-1.zip'));
      await EmptyDatabaseRecoveryGuard.acknowledge(root);
      final repository = ChatDatabaseRepository.open(
        file: File('${root.path}/kelivo.db'),
      );
      try {
        await repository.beginSendGeneration(
          conversation: Conversation(id: 'draft', title: 'Draft'),
          userMessage: ChatMessage(
            id: 'user',
            conversationId: 'draft',
            role: 'user',
            content: 'New chat',
          ),
          assistantMessage: ChatMessage(
            id: 'assistant',
            conversationId: 'draft',
            role: 'assistant',
            content: '',
            isStreaming: true,
          ),
          runId: 'run-draft',
        );
      } finally {
        await repository.close();
      }
      expect(
        await File(
          '${root.path}/${EmptyDatabaseRecoveryGuard.acknowledgementName}',
        ).exists(),
        isFalse,
      );
      final db = sqlite.sqlite3.open('${root.path}/kelivo.db');
      db.execute('DELETE FROM conversation_rows');
      db.close();
      await expectLater(
        EmptyDatabaseRecoveryGuard.check(
          appDataDirectory: root,
          databaseId: receipt.databaseId,
        ),
        throwsStateError,
      );
    },
  );
  test(
    'independent installation history blocks silent recreation after DB and receipt disappear',
    () async {
      await DatabaseInstallationGate.ensureReady(appDataDirectory: root);
      await File('${root.path}/kelivo.db').delete();
      await for (final file in root.list()) {
        if (file.path.contains('database_installation_receipt_')) {
          await file.delete();
        }
      }
      await expectLater(
        DatabaseInstallationGate.ensureReady(appDataDirectory: root),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'code',
            'database_missing_with_prior_data',
          ),
        ),
      );
      expect(await File('${root.path}/kelivo.db').exists(), isFalse);
    },
  );
  test(
    'gateway cannot recreate a database removed after startup admission',
    () async {
      await DatabaseInstallationGate.ensureReady(appDataDirectory: root);
      final database = File('${root.path}/kelivo.db');
      await database.delete();
      final gateway = ChatDatabaseGateway();
      await expectLater(gateway.acquire(database), throwsA(isA<StateError>()));
      expect(await database.exists(), isFalse);
    },
  );
  test(
    'a true fresh install and an intentionally empty snapshot do not trigger recovery',
    () async {
      final receipt = await DatabaseInstallationGate.ensureReady(
        appDataDirectory: root,
      );
      await EmptyDatabaseRecoveryGuard.check(
        appDataDirectory: root,
        databaseId: receipt.databaseId,
      );
      final name = LocalSnapshotPaths.fileNameFor(DateTime.utc(2026, 10, 19));
      final file = await writeRecoverySnapshot(
        File('${root.path}/snapshots/$name'),
        conversations: 0,
        messages: 0,
      );
      await File(
        '${file.path}.json',
      ).writeAsString(jsonEncode({'conversationCount': 0, 'messageCount': 0}));
      await EmptyDatabaseRecoveryGuard.check(
        appDataDirectory: root,
        databaseId: receipt.databaseId,
      );
    },
  );
}
