import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:Kelivo/core/services/backup/restore_bundle_mover.dart';
import 'package:Kelivo/core/services/backup/restore_bundle_staging.dart';
import 'package:Kelivo/core/services/backup/restore_durability.dart';
import 'package:Kelivo/core/services/backup/restore_previous_builder.dart';
import 'package:Kelivo/core/services/backup/restore_previous_store.dart';
import 'package:Kelivo/core/services/backup/restore_receipt.dart';
import 'package:Kelivo/core/services/backup/restore_settings_store.dart';
import 'package:Kelivo/core/services/backup/restore_settings_transition.dart';

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
      SharedPreferences.setMockInitialValues({'theme': 'old'});
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

    test('rejects candidate components not selected by the receipt', () async {
      final candidate = ValidatedRestoreCandidate(
        includeChats: false,
        includeFiles: true,
        secretsIncluded: true,
        manifestSha256: _candidateHash,
        settings: const {'theme': 'new'},
        entries: const {},
        databaseInfo: null,
      );
      final preferences = await SharedPreferences.getInstance();
      final mover = RestoreBundleMover(
        appDataDirectory: appData,
        candidateDirectory: candidateDirectory,
        previousStore: RestorePreviousStore(runDirectory: runDirectory),
      );

      await expectLater(
        mover.installCandidate(
          receipt: _receipt(),
          candidate: candidate,
          settingsTransition: _transition(),
          settingsStore: RestoreSettingsStore(preferences),
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            'restore_mover_candidate_binding',
          ),
        ),
      );
      await preferences.reload();
      expect(preferences.getString('theme'), 'old');
    });

    test(
      'resumes old DB and asset moves after a post-rename failure',
      () async {
        final database = File(p.join(appData.path, 'kelivo.sqlite'));
        await database.writeAsBytes([1, 2, 3], flush: true);
        final upload = File(p.join(appData.path, 'upload', 'item'));
        await upload.parent.create();
        await upload.writeAsString('old asset', flush: true);
        await Directory(p.join(appData.path, 'images')).create();
        final receipt = _receipt(chats: true, files: true);
        final transition = _transition();
        final bundle = await RestorePreviousBuilder.build(
          appDataDirectory: appData,
          preparedReceipt: receipt,
          settingsTransition: transition,
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
        expect(await database.exists(), isTrue);
        expect(await upload.parent.exists(), isFalse);
        final resumedMover = RestoreBundleMover(
          appDataDirectory: appData,
          candidateDirectory: candidateDirectory,
          previousStore: previousStore,
        );
        await resumedMover.moveLiveToPending(persisted);
        final previous = await previousStore.promotePending(
          preparedReceipt: receipt,
        );

        expect(await previousStore.previousDirectory.exists(), isTrue);
        expect(previous.plan.assets?.entries.keys, ['upload/item']);
      },
    );

    test('syncs every old asset before the first bundle rename', () async {
      final database = File(p.join(appData.path, 'kelivo.sqlite'));
      await database.writeAsBytes([1, 2, 3], flush: true);
      final asset = File(p.join(appData.path, 'upload', 'nested', 'item.txt'));
      await asset.parent.create(recursive: true);
      await asset.writeAsString('old asset');
      final receipt = _receipt(chats: true, files: true);
      final bundle = await RestorePreviousBuilder.build(
        appDataDirectory: appData,
        preparedReceipt: receipt,
        settingsTransition: _transition(),
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
        (event) => event.endsWith('/previous.pending/database/kelivo.sqlite'),
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
      'resumes settings and asset installation from mixed positions',
      () async {
        final oldUpload = File(p.join(appData.path, 'upload', 'old'));
        await oldUpload.parent.create();
        await oldUpload.writeAsString('old', flush: true);
        for (final root in const ['images', 'avatars', 'fonts']) {
          await Directory(p.join(appData.path, root)).create();
        }
        final receipt = _receipt(files: true);
        final transition = _transition();
        final bundle = await RestorePreviousBuilder.build(
          appDataDirectory: appData,
          preparedReceipt: receipt,
          settingsTransition: transition,
        );
        final previousStore = RestorePreviousStore(runDirectory: runDirectory);
        final persisted = await previousStore.persistPending(
          bundle: bundle,
          preparedReceipt: receipt,
        );
        final initialMover = RestoreBundleMover(
          appDataDirectory: appData,
          candidateDirectory: candidateDirectory,
          previousStore: previousStore,
        );
        await initialMover.moveLiveToPending(persisted);
        final previous = await previousStore.promotePending(
          preparedReceipt: receipt,
        );

        final candidateEntries = <String, ValidatedRestoreEntry>{};
        final settingsBytes = utf8.encode(jsonEncode({'theme': 'new'}));
        candidateEntries['settings.json'] = (
          bytes: settingsBytes.length,
          sha256: sha256.convert(settingsBytes).toString(),
        );
        for (final root in const ['upload', 'images', 'avatars', 'fonts']) {
          await Directory(p.join(candidateDirectory.path, root)).create();
        }
        final newUpload = File(
          p.join(candidateDirectory.path, 'upload', 'new'),
        );
        await newUpload.writeAsString('new', flush: true);
        candidateEntries['upload/new'] = (
          bytes: await newUpload.length(),
          sha256: (await sha256.bind(newUpload.openRead()).first).toString(),
        );
        final candidate = ValidatedRestoreCandidate(
          includeChats: false,
          includeFiles: true,
          secretsIncluded: true,
          manifestSha256: _candidateHash,
          settings: const {'theme': 'new'},
          entries: candidateEntries,
          databaseInfo: null,
        );
        final preferences = await SharedPreferences.getInstance();
        final settingsStore = RestoreSettingsStore(preferences);
        final resumedTransition = RestoreSettingsTransition.resume(
          plan: previous.plan.settings,
          snapshotBytes: previous.settingsSnapshotBytes,
          candidateSettings: candidate.settings,
          secretsIncluded: candidate.secretsIncluded,
        );
        final failingMover = RestoreBundleMover(
          appDataDirectory: appData,
          candidateDirectory: candidateDirectory,
          previousStore: previousStore,
          durability: _ThrowAfterRenameDurability(RestorePlatformDurability()),
        );

        await expectLater(
          failingMover.installCandidate(
            receipt: receipt,
            candidate: candidate,
            settingsTransition: resumedTransition,
            settingsStore: settingsStore,
          ),
          throwsA(isA<StateError>()),
        );
        final resumedMover = RestoreBundleMover(
          appDataDirectory: appData,
          candidateDirectory: candidateDirectory,
          previousStore: previousStore,
        );
        await resumedMover.installCandidate(
          receipt: receipt,
          candidate: candidate,
          settingsTransition: resumedTransition,
          settingsStore: settingsStore,
        );
        await resumedMover.validateInstalled(
          receipt: receipt,
          candidate: candidate,
          settingsTransition: resumedTransition,
          settingsStore: settingsStore,
          previous: previous,
        );

        await preferences.reload();
        expect(preferences.getString('theme'), 'new');
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

    test('resumes an interrupted asset rollback to previous', () async {
      final oldUpload = File(p.join(appData.path, 'upload', 'old'));
      await oldUpload.parent.create();
      await oldUpload.writeAsString('old', flush: true);
      for (final root in const ['images', 'avatars', 'fonts']) {
        await Directory(p.join(appData.path, root)).create();
      }
      final prepared = _receipt(files: true);
      final transition = _transition();
      final bundle = await RestorePreviousBuilder.build(
        appDataDirectory: appData,
        preparedReceipt: prepared,
        settingsTransition: transition,
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

      for (final root in const ['upload', 'images', 'avatars', 'fonts']) {
        await Directory(p.join(candidateDirectory.path, root)).create();
      }
      final newUpload = File(p.join(candidateDirectory.path, 'upload', 'new'));
      await newUpload.writeAsString('new', flush: true);
      final settingsBytes = utf8.encode(jsonEncode({'theme': 'new'}));
      final candidate = ValidatedRestoreCandidate(
        includeChats: false,
        includeFiles: true,
        secretsIncluded: true,
        manifestSha256: _candidateHash,
        settings: const {'theme': 'new'},
        entries: {
          'settings.json': (
            bytes: settingsBytes.length,
            sha256: sha256.convert(settingsBytes).toString(),
          ),
          'upload/new': (
            bytes: await newUpload.length(),
            sha256: (await sha256.bind(newUpload.openRead()).first).toString(),
          ),
        },
        databaseInfo: null,
      );
      final preferences = await SharedPreferences.getInstance();
      final settingsStore = RestoreSettingsStore(preferences);
      final resumedTransition = RestoreSettingsTransition.resume(
        plan: previous.plan.settings,
        snapshotBytes: previous.settingsSnapshotBytes,
        candidateSettings: candidate.settings,
        secretsIncluded: candidate.secretsIncluded,
      );
      final oldRenamed = prepared.advance(
        RestoreReceiptState.oldRenamed,
        previousManifestSha256: previous.manifestSha256,
      );
      await mover.installCandidate(
        receipt: oldRenamed,
        candidate: candidate,
        settingsTransition: resumedTransition,
        settingsStore: settingsStore,
      );
      final rollingBack = oldRenamed.advance(RestoreReceiptState.rollingBack);

      final failingMover = RestoreBundleMover(
        appDataDirectory: appData,
        candidateDirectory: candidateDirectory,
        previousStore: previousStore,
        durability: _ThrowAfterRenameDurability(RestorePlatformDurability()),
      );
      await expectLater(
        failingMover.rollbackToPrevious(
          receipt: rollingBack,
          candidate: candidate,
          settingsTransition: resumedTransition,
          settingsStore: settingsStore,
          previous: previous,
        ),
        throwsA(isA<StateError>()),
      );

      await mover.rollbackToPrevious(
        receipt: rollingBack,
        candidate: candidate,
        settingsTransition: resumedTransition,
        settingsStore: settingsStore,
        previous: previous,
      );
      await previousStore.validateControlOnlyAfterRollback(previous);
      await preferences.reload();
      expect(preferences.getString('theme'), 'old');
      expect(await oldUpload.readAsString(), 'old');
      expect(
        await File(
          p.join(candidateDirectory.path, 'upload', 'new'),
        ).readAsString(),
        'new',
      );
    });
  });
}

RestoreReceipt _receipt({bool chats = false, bool files = false}) {
  return RestoreReceipt.prepared(
    runId: _runId,
    createdAtUtc: DateTime.utc(2026, 7, 9),
    restoreChats: chats,
    restoreFiles: files,
    candidateManifestSha256: _candidateHash,
  );
}

RestoreSettingsTransition _transition() {
  return RestoreSettingsTransition.build(
    currentSettings: const {'theme': 'old'},
    candidateSettings: const {'theme': 'new'},
    secretsIncluded: true,
  );
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
