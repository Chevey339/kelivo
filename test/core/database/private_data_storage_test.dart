import 'dart:io';
import 'package:archive/archive_io.dart';
import 'package:Kelivo/core/database/startup_recovery_service.dart';
import 'package:Kelivo/core/database/database_installation_gate.dart';
import 'package:Kelivo/core/services/backup/local_copy_catalog.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;
import 'package:Kelivo/core/services/backup/restore_startup_gate.dart';
import '../../support/recovery_snapshot_fixture.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:Kelivo/core/database/private_data_storage.dart';
import '../../support/recovery_fault_durability.dart';
import 'package:Kelivo/core/services/storage/device_storage_probe.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root, source, target;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('kelivo-private-storage-');
    source = await Directory(p.join(root.path, 'Documents')).create();
    target = Directory(p.join(root.path, 'Support', 'kelivo-data'));
    await File(
      p.join(source.path, 'kelivo.db'),
    ).writeAsString('original database');
    await File(
      p.join(source.path, 'kelivo.db-wal'),
    ).writeAsString('committed WAL');
    await Directory(p.join(source.path, 'snapshots 2')).create();
    await File(
      p.join(source.path, 'snapshots 2', 'kept.zip'),
    ).writeAsString('old snapshot');
  });
  tearDown(() async => root.delete(recursive: true));
  test(
    'copies only database state and leaves snapshots and assets in Documents',
    () async {
      await PrivateDataStorage.prepare(source: source, target: target);
      for (final path in ['kelivo.db', 'kelivo.db-wal']) {
        expect(
          await File(p.join(target.path, path)).readAsBytes(),
          await File(p.join(source.path, path)).readAsBytes(),
        );
      }
      expect(
        await Directory(p.join(target.path, 'snapshots 2')).exists(),
        isFalse,
      );
      expect(
        await File(p.join(source.path, 'snapshots 2/kept.zip')).readAsString(),
        'old snapshot',
      );
      await File(
        p.join(target.path, 'kelivo.db'),
      ).writeAsString('new conversations');
      await PrivateDataStorage.prepare(source: source, target: target);
      expect(
        await File(p.join(target.path, 'kelivo.db')).readAsString(),
        'new conversations',
      );
      expect(
        await File(p.join(source.path, 'kelivo.db')).readAsString(),
        'original database',
      );
      expect(
        await File(p.join(target.path, PrivateDataStorage.noticeName)).exists(),
        isTrue,
      );
    },
  );
  test(
    'retains completed archives publicly but copies a referenced archiving run',
    () async {
      final workspace = Directory(p.join(source.path, '.kelivo_restore'));
      const active = '11111111111111111111111111111111';
      const older = '22222222222222222222222222222222';
      for (final id in [active, older]) {
        final file = File(
          p.join(
            workspace.path,
            'completed',
            'run_$id',
            'previous',
            'images',
            'old.png',
          ),
        );
        await file.parent.create(recursive: true);
        await file.writeAsString(id);
      }
      await File(
        p.join(workspace.path, '.active_run.archiving'),
      ).writeAsString(active);
      await PrivateDataStorage.prepare(source: source, target: target);
      expect(
        await File(
          p.join(
            target.path,
            '.kelivo_restore',
            'completed',
            'run_$active',
            'previous',
            'images',
            'old.png',
          ),
        ).readAsString(),
        active,
      );
      expect(
        await Directory(
          p.join(target.path, '.kelivo_restore', 'completed', 'run_$older'),
        ).exists(),
        isFalse,
      );
      expect(
        await File(
          p.join(
            workspace.path,
            'completed',
            'run_$older',
            'previous',
            'images',
            'old.png',
          ),
        ).readAsString(),
        older,
      );
    },
  );
  test('copies the family needed to resume interrupted preservation', () async {
    const family = 'kelivo.db.displaced-1792600000000000';
    final copy = File(p.join(source.path, family, 'kelivo.db-wal'));
    await copy.parent.create();
    await copy.writeAsString('retained WAL');
    await File(
      p.join(source.path, '.kelivo_database_preservation.json'),
    ).writeAsString('{"version":1,"directory":"$family"}');
    await PrivateDataStorage.prepare(source: source, target: target);
    expect(
      await File(p.join(target.path, family, 'kelivo.db-wal')).readAsString(),
      'retained WAL',
    );
    expect(await copy.readAsString(), 'retained WAL');
  });
  test(
    'resumes interrupted directory publication using the verified staged copy',
    () async {
      await expectLater(
        PrivateDataStorage.prepare(
          source: source,
          target: target,
          durability: FaultDurability()..failPublish = true,
        ),
        throwsA(isA<FileSystemException>()),
      );
      expect(await target.exists(), isFalse);
      await PrivateDataStorage.prepare(source: source, target: target);
      expect(
        await File(p.join(target.path, 'kelivo.db-wal')).readAsString(),
        'committed WAL',
      );
      expect(await File(p.join(source.path, 'kelivo.db-wal')).exists(), isTrue);
    },
  );
  test(
    'never silently restores old Documents after the active directory disappears',
    () async {
      await PrivateDataStorage.prepare(source: source, target: target);
      await target.rename('${target.path}-moved');
      await expectLater(
        PrivateDataStorage.prepare(source: source, target: target),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'code',
            'private_storage_missing',
          ),
        ),
      );
      expect(await target.exists(), isFalse);
      expect(await File(p.join(source.path, 'kelivo.db')).exists(), isTrue);
    },
  );
  test(
    'fails closed when source changes during copy and retains every source file',
    () async {
      final durability = FaultDurability();
      var changed = false;
      durability.onSync = (file) async {
        if (!changed && file.path.contains('.kelivo-data-staging-')) {
          changed = true;
          await File(
            p.join(source.path, 'kelivo.db'),
          ).writeAsString('new source data');
        }
      };
      await expectLater(
        PrivateDataStorage.prepare(
          source: source,
          target: target,
          durability: durability,
        ),
        throwsA(isA<StateError>()),
      );
      expect(await target.exists(), isFalse);
      expect(
        await File(p.join(source.path, 'kelivo.db')).readAsString(),
        'new source data',
      );
      expect(
        await File(p.join(source.path, 'snapshots 2/kept.zip')).readAsString(),
        'old snapshot',
      );
    },
  );
  test(
    'rejects an existing untracked target without merging or overwriting it',
    () async {
      await target.create(recursive: true);
      final existing = File(p.join(target.path, 'kelivo.db'));
      await existing.writeAsString('untracked newer database');
      await expectLater(
        PrivateDataStorage.prepare(source: source, target: target),
        throwsA(isA<StateError>()),
      );
      expect(await existing.readAsString(), 'untracked newer database');
    },
  );
  test(
    'low space stops before copying and leaves source data untouched',
    () async {
      DeviceStorageProbe.debugOverride = () async => 1;
      addTearDown(() => DeviceStorageProbe.debugOverride = null);
      await expectLater(
        PrivateDataStorage.prepare(source: source, target: target),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'code',
            'private_storage_insufficient_space',
          ),
        ),
      );
      expect(await target.exists(), isFalse);
      expect(
        await File(p.join(source.path, 'kelivo.db')).readAsString(),
        'original database',
      );
    },
  );
  test(
    'reuses interrupted copy staging instead of creating another full copy',
    () async {
      final fault = FaultDurability();
      fault.onSync = (file) async {
        if (p.basename(file.path) == 'kelivo.db') {
          throw const FileSystemException('injected interruption');
        }
      };
      await expectLater(
        PrivateDataStorage.prepare(
          source: source,
          target: target,
          durability: fault,
        ),
        throwsA(isA<FileSystemException>()),
      );
      final staged = (await target.parent.list().toList())
          .whereType<Directory>()
          .where((d) => p.basename(d.path).startsWith('.kelivo-data-staging-'))
          .single;
      await PrivateDataStorage.prepare(source: source, target: target);
      expect(await staged.exists(), isFalse);
      expect(
        (await target.parent.list().toList()).whereType<Directory>().where(
          (d) => p.basename(d.path).startsWith('.kelivo-data-staging-'),
        ),
        isEmpty,
      );
      expect(
        await File(p.join(target.path, 'kelivo.db-wal')).readAsString(),
        'committed WAL',
      );
    },
  );
  test(
    'rejects target symlinks and overlapping source and target directories',
    () async {
      final outside = await Directory(p.join(root.path, 'outside')).create();
      await target.parent.create(recursive: true);
      await Link(target.path).create(outside.path);
      await expectLater(
        PrivateDataStorage.prepare(source: source, target: target),
        throwsA(isA<StateError>()),
      );
      await expectLater(
        PrivateDataStorage.prepare(
          source: source,
          target: Directory(p.join(source.path, 'nested')),
        ),
        throwsA(isA<StateError>()),
      );
      expect(await outside.list().isEmpty, isTrue);
    },
  );
  for (final damage in ['record', 'ready', 'missing-target', 'untracked']) {
    test(
      'confirmed snapshot recovery repairs $damage and preserves all retained roots',
      () async {
        final snapshot = await writeRecoverySnapshot(
          File(p.join(source.path, 'snapshots 2', 'kelivo-snapshot-1.zip')),
        );
        await Directory(p.join(source.path, 'images')).create();
        await File(
          p.join(source.path, 'images', 'retained.png'),
        ).writeAsString('retained attachment');
        await PrivateDataStorage.prepare(source: source, target: target);
        if (damage == 'missing-target') {
          await target.rename('${target.path}-saved');
        } else if (damage == 'record') {
          await File(
            p.join(target.parent.path, PrivateDataStorage.recordName),
          ).writeAsString('invalid old record');
        } else if (damage == 'ready') {
          await File(
            p.join(target.path, PrivateDataStorage.readyName),
          ).writeAsString('invalid ready record');
        } else {
          await File(
            p.join(target.parent.path, PrivateDataStorage.recordName),
          ).delete();
        }
        await expectLater(
          PrivateDataStorage.prepare(source: source, target: target),
          throwsA(anything),
        );
        final roots = await PrivateDataStorage.recoveryDirectories(
          source: source,
          target: target,
        );
        final catalog = LocalCopyCatalog(
          appDataDirectory: target,
          additionalRoots: roots,
          includeActiveDatabase: true,
        );
        expect(
          (await catalog.list()).where((copy) => copy.isArchive),
          isNotEmpty,
        );
        final before = await snapshot.readAsBytes();
        await PrivateDataStorage.recover(
          source: source,
          target: target,
          snapshot: snapshot,
        );
        await PrivateDataStorage.prepare(source: source, target: target);
        await RestoreStartupGate.recoverAndRequireBusinessReady(
          appDataDirectory: target,
        );
        await DatabaseInstallationGate.ensureReady(
          appDataDirectory: target,
          allowDatabaseIdentityChange: true,
        );
        final restored = sqlite.sqlite3.open(p.join(target.path, 'kelivo.db'));
        try {
          expect(
            restored
                .select('SELECT COUNT(*) AS count FROM message_rows')
                .single['count'],
            42,
          );
          expect(
            restored
                .select('SELECT COUNT(*) AS count FROM conversation_rows')
                .single['count'],
            2,
          );
        } finally {
          restored.close();
        }
        expect(await snapshot.readAsBytes(), before);
        expect(
          await File(p.join(source.path, 'kelivo.db')).readAsString(),
          'original database',
        );
        expect(
          await File(p.join(source.path, 'kelivo.db-wal')).readAsString(),
          'committed WAL',
        );
        expect(
          await File(
            p.join(source.path, 'images', 'retained.png'),
          ).readAsString(),
          'retained attachment',
        );
        if (damage == 'record') {
          final records = await Directory(
            p.join(target.parent.path, '.kelivo-storage-records'),
          ).list().where((entry) => entry is File).cast<File>().toList();
          expect(
            await Future.wait(records.map((f) => f.readAsString())),
            contains('invalid old record'),
          );
        }
      },
    );
  }
  test(
    'interrupted recovery metadata publication resumes with the same verified restore candidate',
    () async {
      final snapshot = await writeRecoverySnapshot(
        File(p.join(source.path, 'kelivo-snapshot-1.zip')),
      );
      await PrivateDataStorage.prepare(source: source, target: target);
      await File(
        p.join(target.path, PrivateDataStorage.readyName),
      ).writeAsString('corrupt');
      final io = FaultDurability()
        ..afterRename = (path) async {
          if (p.basename(path) == PrivateDataStorage.readyName) {
            throw StateError('injected termination');
          }
        };
      await expectLater(
        PrivateDataStorage.recover(
          source: source,
          target: target,
          snapshot: snapshot,
          durability: io,
        ),
        throwsStateError,
      );
      expect(
        await File(
          p.join(target.parent.path, PrivateDataStorage.recoveryName),
        ).exists(),
        isTrue,
      );
      await PrivateDataStorage.prepare(source: source, target: target);
      expect(
        await File(
          p.join(target.parent.path, PrivateDataStorage.recoveryName),
        ).exists(),
        isFalse,
      );
      expect(
        await RestoreStartupGate.inspect(appDataDirectory: target),
        isNotNull,
      );
      await RestoreStartupGate.recoverAndRequireBusinessReady(
        appDataDirectory: target,
      );
      expect(await snapshot.exists(), isTrue);
    },
  );
  test(
    'explicit private reset repairs metadata while retaining the old database and snapshots',
    () async {
      await PrivateDataStorage.prepare(source: source, target: target);
      await File(
        p.join(target.path, PrivateDataStorage.readyName),
      ).writeAsString('corrupt');
      await PrivateDataStorage.recover(source: source, target: target);
      await PrivateDataStorage.prepare(source: source, target: target);
      final copies = await DatabaseInstallationGate.listDisplacedDatabases(
        appDataDirectory: target,
      );
      expect(await copies.single.file.readAsString(), 'original database');
      expect(
        await File('${copies.single.file.path}-wal').readAsString(),
        'committed WAL',
      );
      expect(
        await File(
          p.join(source.path, 'snapshots 2', 'kept.zip'),
        ).readAsString(),
        'old snapshot',
      );
    },
  );
  test(
    'full export includes current private data, partial staging and original Documents',
    () async {
      await PrivateDataStorage.prepare(source: source, target: target);
      final partial = await Directory(
        p.join(target.parent.path, '.kelivo-data-staging-partial'),
      ).create();
      await File(
        p.join(partial.path, 'kelivo.db'),
      ).writeAsString('partial evidence');
      await File(
        p.join(target.path, 'kelivo.db'),
      ).writeAsString('current database');
      final archive = await StartupDiagnosticsService.createDataArchive(
        appDataDirectory: target.parent,
        additionalDataDirectories: [source],
        workingDirectory: Directory(p.join(root.path, 'export')),
      );
      final input = InputFileStream(archive.path);
      try {
        final zip = ZipDecoder().decodeStream(input);
        expect(zip.findFile('data-0/kelivo-data/kelivo.db'), isNotNull);
        expect(
          zip.findFile('data-0/.kelivo-data-staging-partial/kelivo.db'),
          isNotNull,
        );
        expect(
          zip.findFile('data-0/${PrivateDataStorage.recordName}'),
          isNotNull,
        );
        expect(zip.findFile('data-1/kelivo.db-wal'), isNotNull);
        expect(zip.findFile('data-1/snapshots 2/kept.zip'), isNotNull);
      } finally {
        await input.close();
      }
    },
  );
}
