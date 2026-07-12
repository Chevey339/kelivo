import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:Kelivo/core/database/app_database.dart';
import 'package:Kelivo/core/services/database_v2_rollout_ledger.dart';
import 'package:Kelivo/core/services/secure_credential_store.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('OPS-08 release capabilities', (tester) async {
    const storage = SecureCredentialStore();
    final preferences = await SharedPreferences.getInstance();
    final key =
        'kelivo.ops08.${DateTime.now().toUtc().microsecondsSinceEpoch}.$pid';
    const firstValue = 'secret-value-one';
    const secondValue = 'secret-value-two';
    var secureStorage = false;
    try {
      await storage.writeSecret(preferences, key, firstValue);
      expect(await storage.readSecret(preferences, key), firstValue);
      await storage.writeSecret(preferences, key, secondValue);
      expect(await storage.readSecret(preferences, key), secondValue);
      await storage.writeSecret(preferences, key, '');
      expect(await storage.readSecret(preferences, key), isEmpty);
      secureStorage = true;
    } finally {
      await storage.writeSecret(preferences, key, '');
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
      'secureStorageWriteReadOverwriteDelete': secureStorage,
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
