import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:Kelivo/core/database/chat_database_repository.dart';
import 'package:Kelivo/core/models/conversation.dart';
import 'package:Kelivo/core/services/backup/restore_bundle_mover.dart';
import 'package:Kelivo/core/services/backup/restore_bundle_staging.dart';
import 'package:Kelivo/core/services/backup/restore_durability.dart';
import 'package:Kelivo/core/services/backup/restore_previous_builder.dart';
import 'package:Kelivo/core/services/backup/restore_previous_store.dart';
import 'package:Kelivo/core/services/backup/restore_receipt.dart';

const _runId = '0123456789abcdef0123456789abcdef';
const _candidateHash =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('RestoreBundleMover', () {
    late Directory appData;
    late Directory runDirectory;
    late Directory candidateDirectory;

    setUp(() async {
      appData = await Directory.systemTemp.createTemp(
        'kelivo_restore_bundle_mover_test_',
      );
      runDirectory = Directory(p.join(appData.path, 'run_$_runId'));
      candidateDirectory = Directory(p.join(runDirectory.path, 'candidate'));
      await candidateDirectory.create(recursive: true);
    });

    tearDown(() async {
      if (await appData.exists()) await appData.delete(recursive: true);
    });

    test('rejects a candidate without the mandatory database leg', () async {
      final candidate = ValidatedRestoreCandidate(
        includeChats: false,
        includeFiles: false,
        manifestSha256: _candidateHash,
        entries: const {},
        databaseInfo: null,
      );
      final mover = RestoreBundleMover(
        appDataDirectory: appData,
        candidateDirectory: candidateDirectory,
        previousStore: RestorePreviousStore(runDirectory: runDirectory),
      );

      await expectLater(
        mover.installCandidate(receipt: _receipt(), candidate: candidate),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            'restore_mover_candidate_binding',
          ),
        ),
      );
    });

    test(
      'resumes old database and asset moves after a post-rename failure',
      () async {
        final database = File(p.join(appData.path, 'kelivo.db'));
        await database.writeAsBytes([1, 2, 3], flush: true);
        final upload = File(p.join(appData.path, 'upload', 'item'));
        await upload.parent.create();
        await upload.writeAsString('old asset', flush: true);
        await Directory(p.join(appData.path, 'images')).create();
        final receipt = _receipt(files: true);
        final bundle = await RestorePreviousBuilder.build(
          appDataDirectory: appData,
          preparedReceipt: receipt,
        );
        final previousStore = RestorePreviousStore(runDirectory: runDirectory);
        final persisted = await previousStore.persistPending(
          bundle: bundle,
          preparedReceipt: receipt,
        );
        final failingMover = RestoreBundleMover(
          appDataDirectory: appData,
          candidateDirectory: candidateDirectory,
          previousStore: previousStore,
          durability: _ThrowAfterRenameDurability(RestorePlatformDurability()),
        );

        await expectLater(
          failingMover.moveLiveToPending(persisted),
          throwsA(isA<StateError>()),
        );
        final resumedMover = RestoreBundleMover(
          appDataDirectory: appData,
          candidateDirectory: candidateDirectory,
          previousStore: previousStore,
        );
        await resumedMover.moveLiveToPending(persisted);
        final previous = await previousStore.promotePending(
          preparedReceipt: receipt,
        );

        expect(await database.exists(), isFalse);
        expect(previous.plan.assets?.entries.keys, ['upload/item']);
        expect(previous.plan.database.descriptor?.bytes, 3);
      },
    );

    test('syncs every old asset before the first bundle rename', () async {
      final database = File(p.join(appData.path, 'kelivo.db'));
      await database.writeAsBytes([1, 2, 3], flush: true);
      final asset = File(p.join(appData.path, 'upload', 'nested', 'item.txt'));
      await asset.parent.create(recursive: true);
      await asset.writeAsString('old asset');
      final receipt = _receipt(files: true);
      final bundle = await RestorePreviousBuilder.build(
        appDataDirectory: appData,
        preparedReceipt: receipt,
      );
      final previousStore = RestorePreviousStore(runDirectory: runDirectory);
      final pending = await previousStore.persistPending(
        bundle: bundle,
        preparedReceipt: receipt,
      );
      final durability = _RecordingDelegatingDurability(
        root: appData,
        delegate: RestorePlatformDurability(),
      );
      final mover = RestoreBundleMover(
        appDataDirectory: appData,
        candidateDirectory: candidateDirectory,
        previousStore: previousStore,
        durability: durability,
      );

      await mover.moveLiveToPending(pending);

      final firstRename = durability.events.indexWhere(
        (event) => event.startsWith('rename:'),
      );
      final fileSync = durability.events.indexOf(
        'file:upload/nested/item.txt:false',
      );
      final phaseBarrier = durability.events.indexOf('directory:.:true');
      final databaseRename = durability.events.indexWhere(
        (event) => event.endsWith('/previous.pending/database/kelivo.db'),
      );
      expect(fileSync, inInclusiveRange(0, firstRename - 1));
      expect(phaseBarrier, inInclusiveRange(0, firstRename - 1));
      expect(
        durability.events[firstRename],
        endsWith('/previous.pending/upload'),
      );
      expect(databaseRename, greaterThan(firstRename));
    });

    test(
      'resumes database and asset installation from mixed positions',
      () async {
        final fixture = await _prepareCutoverFixture(
          appData: appData,
          runDirectory: runDirectory,
          candidateDirectory: candidateDirectory,
        );
        final failingMover = RestoreBundleMover(
          appDataDirectory: appData,
          candidateDirectory: candidateDirectory,
          previousStore: fixture.previousStore,
          durability: _ThrowAfterRenameDurability(RestorePlatformDurability()),
        );

        await expectLater(
          failingMover.installCandidate(
            receipt: fixture.oldRenamed,
            candidate: fixture.candidate,
          ),
          throwsA(isA<StateError>()),
        );
        await fixture.mover.installCandidate(
          receipt: fixture.oldRenamed,
          candidate: fixture.candidate,
        );
        final newInstalled = fixture.oldRenamed.advance(
          RestoreReceiptState.newInstalled,
        );
        await fixture.mover.validateInstalled(
          receipt: newInstalled,
          candidate: fixture.candidate,
          previous: fixture.previous,
        );

        final installed = await RestorePreviousBuilder.describeFile(
          File(p.join(appData.path, 'kelivo.db')),
        );
        expect(installed.sha256, fixture.newDatabaseSha256);
        expect(
          await File(p.join(appData.path, 'upload', 'new')).readAsString(),
          'new',
        );
        expect(
          await Directory(p.join(candidateDirectory.path, 'upload')).exists(),
          isFalse,
        );
      },
    );

    test('resumes an interrupted database and asset rollback', () async {
      final fixture = await _prepareCutoverFixture(
        appData: appData,
        runDirectory: runDirectory,
        candidateDirectory: candidateDirectory,
      );
      await fixture.mover.installCandidate(
        receipt: fixture.oldRenamed,
        candidate: fixture.candidate,
      );
      final rollingBack = fixture.oldRenamed
          .advance(RestoreReceiptState.newInstalled)
          .advance(RestoreReceiptState.rollingBack);
      final failingMover = RestoreBundleMover(
        appDataDirectory: appData,
        candidateDirectory: candidateDirectory,
        previousStore: fixture.previousStore,
        durability: _ThrowAfterRenameDurability(RestorePlatformDurability()),
      );

      await expectLater(
        failingMover.rollbackToPrevious(
          receipt: rollingBack,
          candidate: fixture.candidate,
          previous: fixture.previous,
        ),
        throwsA(isA<StateError>()),
      );
      await fixture.mover.rollbackToPrevious(
        receipt: rollingBack,
        candidate: fixture.candidate,
        previous: fixture.previous,
      );
      await fixture.mover.validateRolledBack(
        receipt: rollingBack,
        candidate: fixture.candidate,
        previous: fixture.previous,
      );

      final restored = await RestorePreviousBuilder.describeFile(
        File(p.join(appData.path, 'kelivo.db')),
      );
      expect(restored.sha256, fixture.oldDatabaseSha256);
      expect(
        await File(p.join(appData.path, 'upload', 'old')).readAsString(),
        'old',
      );
      expect(
        await File(
          p.join(candidateDirectory.path, 'upload', 'new'),
        ).readAsString(),
        'new',
      );
    });
  });
}

RestoreReceipt _receipt({bool files = false, String? manifestSha256}) {
  return RestoreReceipt.prepared(
    runId: _runId,
    createdAtUtc: DateTime.utc(2026, 7, 9),
    restoreFiles: files,
    candidateManifestSha256: manifestSha256 ?? _candidateHash,
  );
}

final class _CutoverFixture {
  const _CutoverFixture({
    required this.oldRenamed,
    required this.candidate,
    required this.previous,
    required this.previousStore,
    required this.mover,
    required this.oldDatabaseSha256,
    required this.newDatabaseSha256,
  });

  final RestoreReceipt oldRenamed;
  final ValidatedRestoreCandidate candidate;
  final PersistedRestorePrevious previous;
  final RestorePreviousStore previousStore;
  final RestoreBundleMover mover;
  final String oldDatabaseSha256;
  final String newDatabaseSha256;
}

Future<_CutoverFixture> _prepareCutoverFixture({
  required Directory appData,
  required Directory runDirectory,
  required Directory candidateDirectory,
}) async {
  final liveDatabase = File(p.join(appData.path, 'kelivo.db'));
  await _createDatabase(liveDatabase, conversationId: 'old');
  final oldDatabase = await RestorePreviousBuilder.describeFile(liveDatabase);
  final oldUpload = File(p.join(appData.path, 'upload', 'old'));
  await oldUpload.parent.create();
  await oldUpload.writeAsString('old', flush: true);
  await Directory(p.join(appData.path, 'images')).create();

  final candidateDatabase = File(
    p.join(candidateDirectory.path, 'database', 'kelivo.db'),
  );
  await candidateDatabase.parent.create(recursive: true);
  await _createDatabase(candidateDatabase, conversationId: 'new');
  final databaseInfo = await ChatDatabaseRepository.prepareSnapshotForRestore(
    candidateDatabase,
  );
  final databaseDescriptor = await _manifestDescriptor(candidateDatabase);
  for (final root in const ['upload', 'images', 'avatars', 'fonts']) {
    await Directory(p.join(candidateDirectory.path, root)).create();
  }
  final newUpload = File(p.join(candidateDirectory.path, 'upload', 'new'));
  await newUpload.writeAsString('new', flush: true);
  final uploadDescriptor = await _manifestDescriptor(newUpload);
  final manifest = File(p.join(candidateDirectory.path, 'manifest.json'));
  await manifest.writeAsString(
    jsonEncode({
      'format': 'kelivo-backup',
      'formatVersion': 2,
      'payloadKind': 'sqlite',
      'createdAtUtc': '2026-07-09T00:00:00.000Z',
      'appVersion': 'test',
      'includeChats': true,
      'includeFiles': true,
      'database': {
        'entry': 'database/kelivo.db',
        'schemaVersion': databaseInfo.schemaVersion,
        'conversationCount': databaseInfo.conversationCount,
        'messageCount': databaseInfo.messageCount,
      },
      'entries': {
        'database/kelivo.db': databaseDescriptor,
        'upload/new': uploadDescriptor,
      },
    }),
    flush: true,
  );
  final manifestSha256 = (await sha256.bind(manifest.openRead()).first)
      .toString();
  final candidate = await RestoreBundleStaging.validateExistingCandidate(
    candidateDirectory: candidateDirectory,
    expectedManifestSha256: manifestSha256,
  );
  final prepared = _receipt(files: true, manifestSha256: manifestSha256);
  final bundle = await RestorePreviousBuilder.build(
    appDataDirectory: appData,
    preparedReceipt: prepared,
  );
  final previousStore = RestorePreviousStore(runDirectory: runDirectory);
  final pending = await previousStore.persistPending(
    bundle: bundle,
    preparedReceipt: prepared,
  );
  final mover = RestoreBundleMover(
    appDataDirectory: appData,
    candidateDirectory: candidateDirectory,
    previousStore: previousStore,
  );
  await mover.moveLiveToPending(pending);
  final previous = await previousStore.promotePending(
    preparedReceipt: prepared,
  );
  final oldRenamed = prepared.advance(
    RestoreReceiptState.oldRenamed,
    previousManifestSha256: previous.manifestSha256,
  );
  return _CutoverFixture(
    oldRenamed: oldRenamed,
    candidate: candidate,
    previous: previous,
    previousStore: previousStore,
    mover: mover,
    oldDatabaseSha256: oldDatabase.sha256,
    newDatabaseSha256: databaseDescriptor['sha256']! as String,
  );
}

Future<Map<String, Object>> _manifestDescriptor(File file) async => {
  'bytes': await file.length(),
  'sha256': (await sha256.bind(file.openRead()).first).toString(),
};

Future<void> _createDatabase(
  File file, {
  required String conversationId,
}) async {
  final repository = ChatDatabaseRepository.open(file: file);
  try {
    await repository.ensureReady();
    await repository.putMigrationBatch(
      conversations: [Conversation(id: conversationId, title: conversationId)],
      messages: const [],
      toolEventsByMessageId: const {},
      geminiSignaturesByMessageId: const {},
    );
    await repository.markMigrationComplete();
    await repository.checkpoint();
  } finally {
    await repository.close();
  }
}

final class _ThrowAfterRenameDurability implements RestoreDurability {
  _ThrowAfterRenameDurability(this.delegate);

  final RestoreDurability delegate;
  var didThrow = false;

  @override
  Future<void> renameAndSync({
    required FileSystemEntity source,
    required String targetPath,
  }) async {
    await delegate.renameAndSync(source: source, targetPath: targetPath);
    if (!didThrow) {
      didThrow = true;
      throw StateError('injected_after_rename');
    }
  }

  @override
  Future<void> restrictDirectory(Directory directory) =>
      delegate.restrictDirectory(directory);

  @override
  Future<void> restrictFile(File file) => delegate.restrictFile(file);

  @override
  Future<void> syncDirectory(Directory directory, {bool fullBarrier = false}) =>
      delegate.syncDirectory(directory, fullBarrier: fullBarrier);

  @override
  Future<void> syncFile(File file, {bool fullBarrier = false}) =>
      delegate.syncFile(file, fullBarrier: fullBarrier);
}

final class _RecordingDelegatingDurability implements RestoreDurability {
  _RecordingDelegatingDurability({required this.root, required this.delegate});

  final Directory root;
  final RestoreDurability delegate;
  final events = <String>[];

  String _relative(String path) =>
      p.relative(path, from: root.path).replaceAll('\\', '/');

  @override
  Future<void> restrictDirectory(Directory directory) =>
      delegate.restrictDirectory(directory);

  @override
  Future<void> restrictFile(File file) => delegate.restrictFile(file);

  @override
  Future<void> syncFile(File file, {bool fullBarrier = false}) async {
    events.add('file:${_relative(file.path)}:$fullBarrier');
    await delegate.syncFile(file, fullBarrier: fullBarrier);
  }

  @override
  Future<void> syncDirectory(
    Directory directory, {
    bool fullBarrier = false,
  }) async {
    events.add('directory:${_relative(directory.path)}:$fullBarrier');
    await delegate.syncDirectory(directory, fullBarrier: fullBarrier);
  }

  @override
  Future<void> renameAndSync({
    required FileSystemEntity source,
    required String targetPath,
  }) async {
    events.add('rename:${_relative(targetPath)}');
    await delegate.renameAndSync(source: source, targetPath: targetPath);
  }
}
