import 'backup_portability.dart';
import 'business_repository.dart';
import 'business_settings_merger.dart';
import 'business_settings_router.dart';

final class BusinessRestoreService {
  BusinessRestoreService(this._repository);

  final BusinessRepository _repository;

  Future<Map<String, Object>> exportSettings() async =>
      BusinessSettingsRouter.exportSnapshot(
        BackupPortability.portable(await _repository.readSnapshot()),
      );

  Future<void> overwrite(
    Map<String, Object?> imported, {
    bool preserveExplicitEmptyInstructionList = false,
    Map<String, Object?>? entityRowIds,
    bool assumePreV3EmbeddingMigrationWhenVersionMissing = false,
  }) async {
    final replacement = BackupPortability.portable(
      BusinessSettingsRouter.normalizeAndRoute(
        _portablePreferences(imported),
        preserveExplicitEmptyInstructionList:
            preserveExplicitEmptyInstructionList,
        entityRowIds: entityRowIds,
        assumePreV3EmbeddingMigrationWhenVersionMissing:
            assumePreV3EmbeddingMigrationWhenVersionMissing,
      ),
    );
    await _repository.transformSnapshot(
      (current) => BackupPortability.preserveDeviceState(replacement, current),
      writeReceipt: true,
    );
  }

  Future<void> merge(
    Map<String, Object?> imported, {
    bool preserveExplicitEmptyInstructionList = false,
    Map<String, Object?>? entityRowIds,
    bool assumePreV3EmbeddingMigrationWhenVersionMissing = false,
  }) async {
    // Validate and normalize before opening the write transaction. The
    // transaction then merges those immutable imported rows with its current
    // snapshot, preserving both sides' database identities.
    final incoming = BackupPortability.portable(
      BusinessSettingsRouter.normalizeAndRoute(
        _portablePreferences(imported),
        preserveExplicitEmptyInstructionList:
            preserveExplicitEmptyInstructionList,
        entityRowIds: entityRowIds,
        assumePreV3EmbeddingMigrationWhenVersionMissing:
            assumePreV3EmbeddingMigrationWhenVersionMissing,
      ),
    );
    await _repository.transformSnapshot((current) {
      return BusinessSettingsMerger.mergeSnapshots(
        current,
        incoming,
        incomingKeys: imported.keys.toSet(),
      );
    }, writeReceipt: true);
  }

  static Map<String, Object?> _portablePreferences(
    Map<String, Object?> values,
  ) => {...values}
    ..removeWhere(
      (key, _) => BackupPortability.devicePreferenceKeys.contains(key),
    );
}
