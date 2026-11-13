import 'dart:io';

import 'package:Kelivo/core/database/business_repository.dart';
import 'package:Kelivo/core/models/backup.dart';
import 'package:Kelivo/core/services/backup/data_sync.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/business_preferences_test_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late BusinessPreferencesTestHarness harness;
  late BusinessPreferencesTestSession session;

  setUp(() async {
    harness = await BusinessPreferencesTestHarness.create();
    session = await harness.open();
  });

  tearDown(() => harness.dispose());

  for (final scope in [
    const BackupScope(),
    const BackupScope(excluded: {BackupCategory.chats}),
  ]) {
    test(
      'headless preparation honors persisted encryption before accessing files (${scope.excluded})',
      () async {
        final repository = BusinessRepository(session.database);
        // Change the persisted choice directly: the uncached repository is
        // authoritative even before a preferences object has reloaded it.
        await repository.setPreference('backup_encryption_enabled_v1', true);
        expect(
          session.preferences.getBool('backup_encryption_enabled_v1'),
          isNull,
        );
        final missingSource = File('${harness.directory.path}/missing.db');

        await expectLater(
          DataSync.prepareScheduledBackupArchive(
            databaseFile: missingSource,
            businessRepository: repository,
            config: WebDavConfig(scope: scope),
          ),
          throwsA(
            isA<FormatException>().having(
              (error) => error.message,
              'message',
              'backup_password_required',
            ),
          ),
        );
        expect(await missingSource.exists(), isFalse);
      },
    );
  }
}
