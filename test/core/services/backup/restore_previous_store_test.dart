import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:Kelivo/core/services/backup/restore_durability.dart';
import 'package:Kelivo/core/services/backup/restore_previous_builder.dart';
import 'package:Kelivo/core/services/backup/restore_previous_store.dart';
import 'package:Kelivo/core/services/backup/restore_receipt.dart';
import 'package:Kelivo/core/services/backup/restore_settings_transition.dart';

const _runId = '0123456789abcdef0123456789abcdef';
const _candidateHash =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

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
    currentSettings: const {
      'theme': 'dark',
      'provider_api_key_v1': 'old-secret',
    },
    candidateSettings: const {'theme': 'light'},
    secretsIncluded: true,
  );
}

void main() {
  group('RestorePreviousStore', () {
    late Directory appData;
    late Directory runDirectory;

    setUp(() async {
      appData = await Directory.systemTemp.createTemp(
        'kelivo_previous_store_test_',
      );
      runDirectory = Directory(p.join(appData.path, 'run_$_runId'));
      await runDirectory.create();
    });

    tearDown(() async {
      if (await appData.exists()) await appData.delete(recursive: true);
    });

    test('publishes settings first and canonical manifest last', () async {
      final receipt = _receipt();
      final bundle = await RestorePreviousBuilder.build(
        appDataDirectory: appData,
        preparedReceipt: receipt,
        settingsTransition: _transition(),
      );
      final recording = _RecordingDurability(RestorePlatformDurability());
      final store = RestorePreviousStore(
        runDirectory: runDirectory,
        durability: recording,
      );

      final persisted = await store.persistPending(
        bundle: bundle,
        preparedReceipt: receipt,
      );

      expect(persisted.plan.checksum, bundle.plan.checksum);
      expect(persisted.manifestSha256, hasLength(64));
      expect(
        recording.events.indexOf('sync:settings.json.tmp:false'),
        lessThan(recording.events.indexOf('rename:settings.json.tmp')),
      );
      expect(
        recording.events.indexOf('rename:settings.json.tmp'),
        lessThan(recording.events.indexOf('sync:manifest.json.tmp:true')),
      );
      expect(
        recording.events.indexOf('sync:manifest.json.tmp:true'),
        lessThan(recording.events.indexOf('rename:manifest.json.tmp')),
      );
      if (!Platform.isWindows) {
        expect((await store.pendingDirectory.stat()).mode & 0x1ff, 0x1c0);
        expect(
          (await File(
                p.join(store.pendingDirectory.path, 'settings.json'),
              ).stat()).mode &
              0x1ff,
          0x180,
        );
      }
    });

    test(
      'resumes after settings publication and rejects snapshot drift',
      () async {
        final receipt = _receipt();
        final bundle = await RestorePreviousBuilder.build(
          appDataDirectory: appData,
          preparedReceipt: receipt,
          settingsTransition: _transition(),
        );
        final store = RestorePreviousStore(runDirectory: runDirectory);
        await store.persistPending(bundle: bundle, preparedReceipt: receipt);
        final manifest = File(
          p.join(store.pendingDirectory.path, 'manifest.json'),
        );
        await manifest.delete();

        final resumed = await store.persistPending(
          bundle: bundle,
          preparedReceipt: receipt,
        );

        expect(resumed.plan.checksum, bundle.plan.checksum);
        final settings = File(
          p.join(store.pendingDirectory.path, 'settings.json'),
        );
        await settings.writeAsString('{}', flush: true);
        await expectLater(
          store.readPending(preparedReceipt: receipt),
          throwsFormatException,
        );
      },
    );

    test('promotes a complete settings-only previous idempotently', () async {
      final receipt = _receipt();
      final bundle = await RestorePreviousBuilder.build(
        appDataDirectory: appData,
        preparedReceipt: receipt,
        settingsTransition: _transition(),
      );
      final store = RestorePreviousStore(runDirectory: runDirectory);
      await store.persistPending(bundle: bundle, preparedReceipt: receipt);

      final promoted = await store.promotePending(preparedReceipt: receipt);
      final repeated = await store.promotePending(preparedReceipt: receipt);

      expect(await store.pendingDirectory.exists(), isFalse);
      expect(await store.previousDirectory.exists(), isTrue);
      expect(repeated.manifestSha256, promoted.manifestSha256);
    });

    test(
      'requires every selected database and asset payload before promotion',
      () async {
        final database = File(p.join(appData.path, 'kelivo.db'));
        await database.writeAsBytes([1, 2, 3], flush: true);
        final upload = File(p.join(appData.path, 'upload', 'item'));
        await upload.parent.create();
        await upload.writeAsString('asset', flush: true);
        await Directory(p.join(appData.path, 'images')).create();
        final receipt = _receipt(chats: true, files: true);
        final bundle = await RestorePreviousBuilder.build(
          appDataDirectory: appData,
          preparedReceipt: receipt,
          settingsTransition: _transition(),
        );
        final store = RestorePreviousStore(runDirectory: runDirectory);
        await store.persistPending(bundle: bundle, preparedReceipt: receipt);

        await expectLater(
          store.promotePending(preparedReceipt: receipt),
          throwsA(isA<StateError>()),
        );
        expect(await database.exists(), isTrue);
        await Directory(
          p.join(store.pendingDirectory.path, 'database'),
        ).create();
        await database.rename(
          p.join(store.pendingDirectory.path, 'database', 'kelivo.db'),
        );
        await Directory(
          p.join(appData.path, 'upload'),
        ).rename(p.join(store.pendingDirectory.path, 'upload'));
        await Directory(
          p.join(appData.path, 'images'),
        ).rename(p.join(store.pendingDirectory.path, 'images'));

        final promoted = await store.promotePending(preparedReceipt: receipt);

        expect(promoted.plan.database, isNotNull);
        expect(promoted.plan.assets?.entries.keys, ['upload/item']);
      },
    );

    test('fails closed when both pending and previous exist', () async {
      final receipt = _receipt();
      final bundle = await RestorePreviousBuilder.build(
        appDataDirectory: appData,
        preparedReceipt: receipt,
        settingsTransition: _transition(),
      );
      final store = RestorePreviousStore(runDirectory: runDirectory);
      await store.persistPending(bundle: bundle, preparedReceipt: receipt);
      await store.previousDirectory.create();

      await expectLater(
        store.promotePending(preparedReceipt: receipt),
        throwsA(isA<StateError>()),
      );
    });
  });
}

final class _RecordingDurability implements RestoreDurability {
  _RecordingDurability(this.delegate);

  final RestoreDurability delegate;
  final events = <String>[];

  @override
  Future<void> restrictDirectory(Directory directory) async {
    events.add('restrict-dir:${p.basename(directory.path)}');
    await delegate.restrictDirectory(directory);
  }

  @override
  Future<void> restrictFile(File file) async {
    events.add('restrict-file:${p.basename(file.path)}');
    await delegate.restrictFile(file);
  }

  @override
  Future<void> syncDirectory(
    Directory directory, {
    bool fullBarrier = false,
  }) async {
    events.add('sync-dir:${p.basename(directory.path)}');
    await delegate.syncDirectory(directory, fullBarrier: fullBarrier);
  }

  @override
  Future<void> syncFile(File file, {bool fullBarrier = false}) async {
    events.add('sync:${p.basename(file.path)}:$fullBarrier');
    await delegate.syncFile(file, fullBarrier: fullBarrier);
  }

  @override
  Future<void> renameAndSync({
    required FileSystemEntity source,
    required String targetPath,
  }) async {
    events.add('rename:${p.basename(source.path)}');
    await delegate.renameAndSync(source: source, targetPath: targetPath);
  }
}
