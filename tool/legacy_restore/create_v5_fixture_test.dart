// Manual fixture generation only; this is outside the default test glob.
import 'dart:io';
import 'package:Kelivo/core/database/app_database.dart';
import 'package:Kelivo/core/models/backup.dart';
import 'package:Kelivo/core/services/backup/data_sync.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../test/support/genui_backup_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('export a real current v5 synthetic backup', () async {
    expect(AppDatabase.currentSchemaVersion, 5);
    const output = String.fromEnvironment('GENUI_LEGACY_FIXTURE_OUT');
    expect(output, isNotEmpty);
    final root = await Directory.systemTemp.createTemp('genui-current-export-');
    final fixture = await GenUiBackupFixture.create(root);
    File? archive;
    try {
      archive = await fixture.sync.prepareBackupFile(
        const WebDavConfig(
          scope: BackupScope(
            excluded: {
              BackupCategory.files,
              BackupCategory.skills,
              BackupCategory.workspaces,
            },
          ),
        ),
      );
      final destination = File(output);
      await destination.parent.create(recursive: true);
      await archive.copy(destination.path);
      expect(await destination.length(), greaterThan(0));
    } finally {
      if (archive != null) await DataSync.cleanupTemporaryBackupFile(archive);
      await fixture.dispose();
      await root.delete(recursive: true);
    }
  });
}
