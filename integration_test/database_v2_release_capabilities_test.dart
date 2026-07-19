import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:Kelivo/core/database/app_database.dart';
import 'package:Kelivo/core/database/business_repository.dart';
import 'package:Kelivo/core/database/business_restore_service.dart';
import 'package:Kelivo/core/services/database_v2_rollout_ledger.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('OPS-08 release capabilities', (tester) async {
    final key =
        'kelivo.ops08.${DateTime.now().toUtc().microsecondsSinceEpoch}.$pid';
    const firstValue = 'secret-value-one';
    const secondValue = 'secret-value-two';
    var credentialBackup = false;
    final root = await Directory.systemTemp.createTemp('kelivo_ops08_');
    final database = AppDatabase.open(file: File('${root.path}/kelivo.db'));
    final repository = BusinessRepository(database);
    try {
      await repository.setPreference(key, firstValue);
      expect(await repository.getPreference(key), firstValue);
      await repository.setPreference(key, secondValue);
      expect(await repository.getPreference(key), secondValue);
      final snapshot = await BusinessRestoreService(
        repository,
      ).exportSettings();
      expect(snapshot[key], secondValue);
      credentialBackup = true;
    } finally {
      await database.close();
      await root.delete(recursive: true);
    }

    final rollbackCompatible =
        DatabaseV2RollbackCompatibility.supportsSchema(
          AppDatabase.currentSchemaVersion,
        ) &&
        DatabaseV2RollbackCompatibility.manifest()['downMigrationAllowed'] ==
            false &&
        DatabaseV2RollbackCompatibility.manifest()['hiveWriterAllowed'] ==
            false;
    expect(rollbackCompatible, isTrue);

    final report = <String, Object>{
      'platform': defaultTargetPlatform.name,
      'operatingSystem': Platform.operatingSystem,
      'operatingSystemVersion': Platform.operatingSystemVersion,
      'credentialDatabaseBackupRoundTrip': credentialBackup,
      'databaseSchemaVersion': AppDatabase.currentSchemaVersion,
      'rollbackCompatible': rollbackCompatible,
      'storageContractVersion':
          DatabaseV2RollbackCompatibility.storageContractVersion,
    };
    // Machine-readable evidence for the five-platform release ledger.
    // ignore: avoid_print
    print('OPS08_RELEASE_CAPABILITY_RESULT:${jsonEncode(report)}');
  });
}
