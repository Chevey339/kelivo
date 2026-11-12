import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

import 'package:Kelivo/core/database/database_installation_gate.dart';
import 'package:Kelivo/core/database/empty_database_recovery_guard.dart';
import 'package:Kelivo/core/database/private_data_storage.dart';
import 'package:Kelivo/core/services/backup/local_snapshot_schedule.dart';
import 'package:Kelivo/core/services/backup/restore_startup_gate.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/widgets/restore_failure_screen.dart';
import 'package:Kelivo/utils/app_directories.dart';

import '../test/support/recovery_snapshot_fixture.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'iOS preserves originals and WAL, discovers renamed snapshots and restores with user notice',
    (tester) async {
      final documents = await getApplicationDocumentsDirectory();
      final support = await getApplicationSupportDirectory();
      expect(
        (await AppDirectories.getAppDataDirectory()).path,
        p.join(support.path, AppDirectories.privateDataDirectoryName),
      );
      expect(
        (await AppDirectories.documentsDirectoryFor(
          await AppDirectories.getAppDataDirectory(),
        ))!.path,
        documents.path,
      );
      // Only task-owned subdirectories are touched, even if this is rerun on a device.
      final source = await documents.createTemp('recovery-test-');
      final destinationParent = await (await support.create(
        recursive: true,
      )).createTemp('recovery-test-');
      final destination = Directory(
        p.join(destinationParent.path, 'kelivo-data'),
      );
      addTearDown(() async {
        await source.delete(recursive: true);
        await destinationParent.delete(recursive: true);
      });
      await DatabaseInstallationGate.ensureReady(appDataDirectory: source);
      final sourceDatabase = File(p.join(source.path, 'kelivo.db'));
      final writer = sqlite.sqlite3.open(sourceDatabase.path);
      writer.execute('PRAGMA journal_mode=WAL');
      writer.execute('PRAGMA wal_autocheckpoint=0');
      writer.execute(
        "INSERT INTO chat_storage_meta_rows (key,value) VALUES ('recovery_test_wal','committed')",
      );
      final wal = File('${sourceDatabase.path}-wal');
      final originalWal = await wal.readAsBytes();
      expect(originalWal, isNotEmpty);
      final name = LocalSnapshotPaths.fileNameFor(DateTime.utc(2026, 10, 19));
      final snapshot = await writeRecoverySnapshot(
        File(p.join(source.path, 'snapshots 2', name)),
      );
      final originalArchive = await snapshot.readAsBytes();
      try {
        await PrivateDataStorage.prepare(source: source, target: destination);
        expect(await wal.readAsBytes(), originalWal);
        final copied = sqlite.sqlite3.open(
          p.join(destination.path, 'kelivo.db'),
        );
        try {
          expect(
            copied
                .select(
                  "SELECT value FROM chat_storage_meta_rows WHERE key='recovery_test_wal'",
                )
                .single['value'],
            'committed',
          );
        } finally {
          copied.close();
        }
      } finally {
        writer.close();
      }
      final sourceBeforeRestore = await sourceDatabase.readAsBytes();
      final active = File(p.join(destination.path, 'kelivo.db'));
      await active.rename('${active.path}.retained-by-test');
      await expectLater(
        DatabaseInstallationGate.ensureReady(appDataDirectory: destination),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'code',
            'database_missing_with_prior_data',
          ),
        ),
      );
      expect(await active.exists(), isFalse);

      var restarted = false;
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('zh'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: RestoreFailureScreen(
            report: StartupFailureReport.capture(
              stage: StartupFailureStage.databaseAdmission,
              error: StateError('database_missing_with_prior_data'),
            ),
            appDataDirectory: destination,
            privateStorageSource: source,
            restart: () async {
              restarted = true;
            },
            appVersionLoader: () async => (version: '1.3.1', build: '80'),
          ),
        ),
      );
      final labels = AppLocalizations.of(
        tester.element(find.byType(RestoreFailureScreen)),
      )!;
      final choose = find.text(labels.startupRecoverySnapshotButton);
      for (var i = 0; i < 300 && choose.evaluate().isEmpty; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        await tester.pump();
      }
      expect(find.text('检测到已有数据'), findsOneWidget);
      expect(choose, findsOneWidget);
      await tester.tap(choose);
      await tester.pumpAndSettle();
      final l10n = AppLocalizations.of(
        tester.element(find.byType(RestoreFailureScreen)),
      )!;
      await tester.tap(find.text(l10n.localSnapshotCopyContents(2, 42)));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.localSnapshotActionRestore).last);
      for (var i = 0; i < 600 && !restarted; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        await tester.pump();
      }
      expect(restarted, isTrue);
      await tester.pumpWidget(const SizedBox());
      final restored = await RestoreStartupGate.recoverAndRequireBusinessReady(
        appDataDirectory: destination,
      );
      expect(restored, isNotNull);
      final receipt = await DatabaseInstallationGate.ensureReady(
        appDataDirectory: destination,
        allowDatabaseIdentityChange: true,
      );
      await EmptyDatabaseRecoveryGuard.check(
        appDataDirectory: destination,
        databaseId: receipt.databaseId,
      );
      final database = sqlite.sqlite3.open(active.path);
      try {
        expect(
          database
              .select('SELECT count(*) AS n FROM conversation_rows')
              .single['n'],
          2,
        );
        expect(
          database.select('SELECT count(*) AS n FROM message_rows').single['n'],
          42,
        );
      } finally {
        database.close();
      }
      expect(await sourceDatabase.readAsBytes(), sourceBeforeRestore);
      expect(await snapshot.readAsBytes(), originalArchive);
      expect(
        await File(p.join(source.path, 'snapshots 2', name)).readAsBytes(),
        originalArchive,
      );
      expect(
        await Directory(p.join(destination.path, 'snapshots 2')).exists(),
        isFalse,
      );
      // ignore: avoid_print
      print(
        'DATA_RECOVERY_RESULT:${jsonEncode({'platform': Platform.operatingSystem, 'originalsPreserved': true, 'walPreserved': true, 'missingDatabaseBlocked': true, 'renamedSnapshotVerified': true, 'noticeAndConfirmation': true, 'restoredConversations': 2, 'restoredMessages': 42})}',
      );
    },
    skip: !Platform.isIOS,
  );
}
