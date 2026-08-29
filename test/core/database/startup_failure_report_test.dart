import 'dart:io';

import 'package:Kelivo/core/database/app_database.dart';
import 'package:Kelivo/core/database/chat_database_repository.dart';
import 'package:Kelivo/core/database/startup_failure_report.dart';
import 'package:Kelivo/core/database/startup_recovery_service.dart';
import 'package:drift/isolate.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart' as sqlite;

void main() {
  late Directory directory;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('kelivo_startup_report_');
  });

  tearDown(() async {
    if (await directory.exists()) await directory.delete(recursive: true);
  });

  File databaseFile(Directory root) =>
      File(p.join(root.path, AppDatabase.databaseFileName));

  Future<void> createDatabaseAtVersion(Directory root, int userVersion) async {
    final repository = ChatDatabaseRepository.open(file: databaseFile(root));
    try {
      await repository.ensureReady();
    } finally {
      await repository.close();
    }
    if (userVersion == AppDatabase.currentSchemaVersion) return;
    final raw = sqlite.sqlite3.open(databaseFile(root).absolute.path);
    try {
      raw.execute('PRAGMA wal_checkpoint(TRUNCATE);');
      raw.userVersion = userVersion;
    } finally {
      raw.close();
    }
  }

  group('diagnostic codes', () {
    test('keeps only stable, path-free codes', () {
      expect(
        restoreFailureDiagnosticCode(StateError('restore_startup_receipt')),
        'restore_startup_receipt',
      );
      expect(
        restoreFailureDiagnosticCode(StateError('/private/user path')),
        'StateError',
      );
      expect(
        restoreFailureDiagnosticCode(
          const FileSystemException(
            'denied',
            '/private/user',
            OSError('permission denied', 13),
          ),
        ),
        'filesystem_13',
      );
    });

    test('names the SQLite result code instead of the type', () {
      expect(
        restoreFailureDiagnosticCode(
          sqlite.SqliteException(extendedResultCode: 11, message: 'malformed'),
        ),
        'sqlite_11',
      );
    });

    test(
      'unwraps a failure raised on drift\'s worker isolate',
      () async {
        // The exact shape of the TestFlight report: an unpublished schema makes
        // the live executor's setup throw on drift's worker isolate, so the
        // caller only ever sees DriftRemoteException.
        await createDatabaseAtVersion(directory, 7);
        final database = AppDatabase.open(file: databaseFile(directory));
        Object? caught;
        StackTrace? caughtStack;
        try {
          await database.customSelect('SELECT 1;').getSingle();
        } catch (error, stackTrace) {
          caught = error;
          caughtStack = stackTrace;
        } finally {
          await database.close();
        }

        expect(caught, isA<DriftRemoteException>());
        expect(
          restoreFailureDiagnosticCode(caught!),
          'drift:database_schema_version',
        );

        final report = StartupFailureReport.capture(
          stage: StartupFailureStage.databaseAdmission,
          error: caught,
          step: 'gateway_open',
          stackTrace: caughtStack,
        );
        expect(report.causes.first.type, 'DriftRemoteException');
        expect(report.causes.last.type, 'StateError');
        expect(report.summary, contains('database_schema_version'));
        expect(report.toText(), contains('stage: database_admission'));
        expect(report.toText(), contains('step: gateway_open'));
        expect(report.toText(), contains('database_schema_version'));
      },
      // Spawning drift's worker isolate and loading sqlite3 is slower than the
      // default budget on a cold machine.
      timeout: const Timeout(Duration(minutes: 1)),
    );
  });

  group('environment snapshot', () {
    test('reports an installed schema that is behind this build', () async {
      await createDatabaseAtVersion(directory, 1);

      final environment = await StartupFailureEnvironment.collect(
        appDataDirectory: directory,
        appVersion: '1.2.4',
        buildNumber: '68',
      );

      expect(environment.installedSchemaVersion, 1);
      expect(
        environment.expectedSchemaVersion,
        AppDatabase.currentSchemaVersion,
      );
      expect(environment.installedSchemaIsBehind, isTrue);
      final database = environment.files.singleWhere(
        (file) => file.name == AppDatabase.databaseFileName,
      );
      expect(database.note, 'user_version=1');
      expect(database.sizeBytes, greaterThan(0));
    });

    test('survives a missing data directory', () async {
      final missing = Directory(p.join(directory.path, 'absent'));
      final environment = await StartupFailureEnvironment.collect(
        appDataDirectory: missing,
      );
      expect(environment.installedSchemaVersion, isNull);
      expect(environment.files, isNotEmpty);
    });
  });

  group('failure report log', () {
    test('writes the report and keeps only the newest few', () async {
      for (
        var index = 0;
        index < StartupDiagnosticsService.retainedReports + 3;
        index++
      ) {
        final written = await StartupDiagnosticsService.writeFailureReport(
          appDataDirectory: directory,
          text: 'report $index',
          clock: () => DateTime.utc(2026, 1, 1).add(Duration(minutes: index)),
        );
        expect(written, isNotNull);
      }

      final logs = Directory(p.join(directory.path, 'logs'));
      final reports = logs
          .listSync()
          .whereType<File>()
          .where((file) => p.basename(file.path).startsWith('startup_failure_'))
          .toList();
      expect(reports, hasLength(StartupDiagnosticsService.retainedReports));
      final contents = reports.map((file) => file.readAsStringSync()).toSet();
      expect(contents, contains('report 7'));
      expect(contents, isNot(contains('report 0')));
    });

    test('never throws when the directory cannot be written', () async {
      final blocked = File(p.join(directory.path, 'blocked'))
        ..writeAsStringSync('not a directory');
      final written = await StartupDiagnosticsService.writeFailureReport(
        appDataDirectory: Directory(blocked.path),
        text: 'report',
      );
      expect(written, isNull);
    });
  });

  group('data archive', () {
    test('packs the whole data directory into one file', () async {
      await createDatabaseAtVersion(
        directory,
        AppDatabase.currentSchemaVersion,
      );
      final workspace = await Directory.systemTemp.createTemp(
        'kelivo_startup_archive_',
      );
      addTearDown(() async {
        if (await workspace.exists()) await workspace.delete(recursive: true);
      });

      final archive = await StartupDiagnosticsService.createDataArchive(
        appDataDirectory: directory,
        workingDirectory: workspace,
      );

      expect(await archive.exists(), isTrue);
      expect(await archive.length(), greaterThan(0));
      expect(p.extension(archive.path), '.zip');
    });

    test('refuses a destination inside the data directory', () async {
      await expectLater(
        StartupDiagnosticsService.createDataArchive(
          appDataDirectory: directory,
          workingDirectory: Directory(p.join(directory.path, 'inside')),
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            'startup_recovery_export_inside_source',
          ),
        ),
      );
    });
  });

  group('integrity check', () {
    test('passes on a freshly created database', () async {
      await createDatabaseAtVersion(
        directory,
        AppDatabase.currentSchemaVersion,
      );
      final result = await StartupDiagnosticsService.checkIntegrity(
        appDataDirectory: directory,
      );
      expect(result.databasePresent, isTrue);
      expect(result.isHealthy, isTrue);
      expect(result.describe(), contains('quick_check: ok'));
    });

    test('reports a missing database instead of throwing', () async {
      final result = await StartupDiagnosticsService.checkIntegrity(
        appDataDirectory: directory,
      );
      expect(result.databasePresent, isFalse);
      expect(result.isHealthy, isFalse);
      expect(result.describe(), 'database file missing');
    });
  });
}
