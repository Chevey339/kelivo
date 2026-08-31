import 'dart:io';

import 'package:Kelivo/core/database/app_database.dart';
import 'package:Kelivo/core/database/chat_database_repository.dart';
import 'package:Kelivo/core/database/database_installation_gate.dart';
import 'package:Kelivo/core/database/startup_recovery_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

String? installedDatabaseId(Directory root) {
  final file = File(p.join(root.path, AppDatabase.databaseFileName));
  if (!file.existsSync()) return null;
  return ChatDatabaseRepository.inspectInstalledDatabase(file).databaseId;
}

void main() {
  late Directory directory;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp(
      'kelivo_startup_recovery_',
    );
  });

  tearDown(() async {
    if (await directory.exists()) await directory.delete(recursive: true);
  });

  File databaseFile(Directory root) =>
      File(p.join(root.path, AppDatabase.databaseFileName));

  List<File> receiptFiles(Directory root) => root
      .listSync()
      .whereType<File>()
      .where(
        (file) =>
            p
                .basename(file.path)
                .startsWith('database_installation_receipt_') &&
            file.path.endsWith('.json'),
      )
      .toList();

  group('repair', () {
    test(
      'rebuilds a corrupt receipt from the live database identity',
      () async {
        await DatabaseInstallationGate.ensureReady(appDataDirectory: directory);
        final originalId = installedDatabaseId(directory);
        // Corrupt the receipt the way a torn write / partial platform-backup
        // restore would.
        receiptFiles(directory).single.writeAsStringSync('{not valid json');

        // Sanity: admission is now dead-locked.
        await expectLater(
          DatabaseInstallationGate.ensureReady(appDataDirectory: directory),
          throwsA(anything),
        );

        await StartupRecoveryService.repair(appDataDirectory: directory);

        // A fresh, valid receipt matching the untouched database is republished
        // and admission succeeds again.
        final receipt = await DatabaseInstallationGate.ensureReady(
          appDataDirectory: directory,
        );
        expect(receipt.databaseId, originalId);
        expect(receiptFiles(directory), hasLength(1));
      },
    );

    test('clears leftover publish temp files', () async {
      await DatabaseInstallationGate.ensureReady(appDataDirectory: directory);
      await File(
        p.join(directory.path, '.database_installation_receipt.tmp'),
      ).create();
      await File(
        p.join(directory.path, '.database_installation_receipt_9_1.tmp'),
      ).create();

      await StartupRecoveryService.repair(appDataDirectory: directory);

      expect(
        File(
          p.join(directory.path, '.database_installation_receipt.tmp'),
        ).existsSync(),
        isFalse,
      );
      expect(
        File(
          p.join(directory.path, '.database_installation_receipt_9_1.tmp'),
        ).existsSync(),
        isFalse,
      );
    });

    test('sweeps inert OS junk from the restore workspace', () async {
      await DatabaseInstallationGate.ensureReady(appDataDirectory: directory);
      final completed = Directory(
        p.join(directory.path, '.kelivo_restore', 'completed'),
      )..createSync(recursive: true);
      final junk = File(p.join(completed.path, '.DS_Store'))..createSync();
      final realState = File(p.join(completed.path, 'keep.dat'))..createSync();

      await StartupRecoveryService.repair(appDataDirectory: directory);

      expect(junk.existsSync(), isFalse);
      // Non-junk entries are left untouched.
      expect(realState.existsSync(), isTrue);
    });

    test('adopts a swapped database when the user repairs', () async {
      await DatabaseInstallationGate.ensureReady(appDataDirectory: directory);
      final other = await Directory.systemTemp.createTemp('kelivo_other_');
      addTearDown(() async => other.delete(recursive: true));
      await DatabaseInstallationGate.ensureReady(appDataDirectory: other);
      final swappedId = installedDatabaseId(other);

      // Replace the database with a different install; admission now throws
      // database_identity_mismatch.
      await databaseFile(other).copy(databaseFile(directory).path);
      for (final suffix in const ['-wal', '-shm']) {
        final stale = File('${databaseFile(directory).path}$suffix');
        if (stale.existsSync()) stale.deleteSync();
      }
      await expectLater(
        DatabaseInstallationGate.ensureReady(appDataDirectory: directory),
        throwsA(anything),
      );

      await StartupRecoveryService.repair(appDataDirectory: directory);

      final receipt = await DatabaseInstallationGate.ensureReady(
        appDataDirectory: directory,
      );
      expect(receipt.databaseId, swappedId);
    });

    test('rethrows when the database itself is missing', () async {
      await DatabaseInstallationGate.ensureReady(appDataDirectory: directory);
      for (final suffix in const ['', '-wal', '-shm']) {
        final file = File('${databaseFile(directory).path}$suffix');
        if (file.existsSync()) file.deleteSync();
      }
      await expectLater(
        StartupRecoveryService.repair(appDataDirectory: directory),
        throwsA(anything),
      );
    });
  });

  group('exportDataCopy', () {
    test('copies the whole data tree into a timestamped folder', () async {
      await DatabaseInstallationGate.ensureReady(appDataDirectory: directory);
      Directory(p.join(directory.path, 'images')).createSync();
      File(
        p.join(directory.path, 'images', 'a.png'),
      ).writeAsBytesSync(const [1, 2, 3]);

      final destination = await Directory.systemTemp.createTemp('kelivo_dest_');
      addTearDown(() async => destination.delete(recursive: true));

      final exported = await StartupRecoveryService.exportDataCopy(
        appDataDirectory: directory,
        destinationParent: destination,
      );

      expect(exported.existsSync(), isTrue);
      expect(
        File(p.join(exported.path, AppDatabase.databaseFileName)).existsSync(),
        isTrue,
      );
      expect(
        File(p.join(exported.path, 'images', 'a.png')).readAsBytesSync(),
        const [1, 2, 3],
      );
      // The original data is untouched.
      expect(databaseFile(directory).existsSync(), isTrue);
    });
  });

  group('exportDataCopy destination guard', () {
    test('rejects a destination inside the data directory', () async {
      await DatabaseInstallationGate.ensureReady(appDataDirectory: directory);
      final inside = Directory(p.join(directory.path, 'exports'));

      await expectLater(
        StartupRecoveryService.exportDataCopy(
          appDataDirectory: directory,
          destinationParent: inside,
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            'startup_recovery_export_inside_source',
          ),
        ),
      );
      await expectLater(
        StartupRecoveryService.exportDataCopy(
          appDataDirectory: directory,
          destinationParent: directory,
        ),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('reset', () {
    test('rebuilds a fresh installation after the database is lost', () async {
      await DatabaseInstallationGate.ensureReady(appDataDirectory: directory);
      final originalId = installedDatabaseId(directory);
      // A missing database cannot be repaired; reset must recover.
      databaseFile(directory).deleteSync();

      await StartupRecoveryService.reset(appDataDirectory: directory);

      final receipt = await DatabaseInstallationGate.ensureReady(
        appDataDirectory: directory,
      );
      expect(receipt.databaseId, isNotEmpty);
      expect(receipt.databaseId, isNot(originalId));
      expect(receiptFiles(directory), hasLength(1));
    });

    test('leaves no displaced copy behind', () async {
      // The confirmation dialog promises the data is permanently gone, so
      // unlike an unattended rebuild this must not stash a copy.
      await DatabaseInstallationGate.ensureReady(appDataDirectory: directory);

      await StartupRecoveryService.reset(appDataDirectory: directory);

      final displaced = directory
          .listSync(followLinks: false)
          .map((entity) => p.basename(entity.path))
          .where(
            (name) => name.startsWith(
              '${AppDatabase.databaseFileName}'
              '${DatabaseInstallationGate.displacedDatabasePrefix}',
            ),
          );
      expect(displaced, isEmpty);
    });
  });
}
