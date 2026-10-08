import '../models/backup_scope.dart';
import 'backup_content_filter.dart';
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
    BackupScope scope = const BackupScope(),
    bool preserveExplicitEmptyInstructionList = false,
    Map<String, Object?>? entityRowIds,
    bool assumePreV3EmbeddingMigrationWhenVersionMissing = false,
  }) async {
    final replacement = BackupPortability.portable(
      BusinessSettingsRouter.normalizeAndRoute(
        BackupContentFilter.select(_portablePreferences(imported), scope),
        preserveExplicitEmptyInstructionList:
            preserveExplicitEmptyInstructionList,
        entityRowIds: entityRowIds == null
            ? null
            : BackupContentFilter.select(entityRowIds, scope),
        assumePreV3EmbeddingMigrationWhenVersionMissing:
            assumePreV3EmbeddingMigrationWhenVersionMissing,
      ),
    );
    await _repository.transformSnapshot(
      (current) => BackupPortability.preserveDeviceState(
        BackupContentFilter.preserveUnselected(replacement, current, scope),
        current,
      ),
      writeReceipt: true,
    );
  }

  Future<void> merge(
    Map<String, Object?> imported, {
    BackupScope scope = const BackupScope(),
    bool preserveExplicitEmptyInstructionList = false,
    Map<String, Object?>? entityRowIds,
    bool assumePreV3EmbeddingMigrationWhenVersionMissing = false,
  }) async {
    // Validate and normalize before opening the write transaction. The
    // transaction then merges those immutable imported rows with its current
    // snapshot, preserving both sides' database identities.
    final incoming = BackupPortability.portable(
      BusinessSettingsRouter.normalizeAndRoute(
        BackupContentFilter.select(_portablePreferences(imported), scope),
        preserveExplicitEmptyInstructionList:
            preserveExplicitEmptyInstructionList,
        entityRowIds: entityRowIds == null
            ? null
            : BackupContentFilter.select(entityRowIds, scope),
        assumePreV3EmbeddingMigrationWhenVersionMissing:
            assumePreV3EmbeddingMigrationWhenVersionMissing,
      ),
    );
    await _repository.transformSnapshot((current) {
      return BusinessSettingsMerger.mergeSnapshots(
        current,
        incoming,
        incomingKeys: BackupContentFilter.select(imported, scope).keys.toSet(),
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
