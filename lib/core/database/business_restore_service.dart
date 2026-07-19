import 'business_repository.dart';
import 'business_settings_merger.dart';
import 'business_settings_router.dart';

final class BusinessRestoreService {
  BusinessRestoreService(this._repository);

  final BusinessRepository _repository;

  Future<Map<String, Object>> exportSettings() async =>
      BusinessSettingsRouter.exportSnapshot(await _repository.readSnapshot());

  Future<void> overwrite(
    Map<String, Object?> imported, {
    bool preserveExplicitEmptyInstructionList = false,
  }) async {
    final replacement = BusinessSettingsRouter.normalizeAndRoute(
      imported,
      preserveExplicitEmptyInstructionList:
          preserveExplicitEmptyInstructionList,
    );
    await _repository.replaceSnapshot(replacement, writeReceipt: true);
  }

  Future<void> merge(
    Map<String, Object?> imported, {
    bool preserveExplicitEmptyInstructionList = false,
  }) async {
    // Validate and normalize before opening the write transaction. The merger
    // repeats canonicalization against the transaction's current snapshot so
    // concurrent business writes cannot be lost between read and commit.
    BusinessSettingsRouter.normalizeAndRoute(
      imported,
      preserveExplicitEmptyInstructionList:
          preserveExplicitEmptyInstructionList,
    );
    await _repository.transformSnapshot((current) {
      final currentSettings = BusinessSettingsRouter.exportSnapshot(current);
      final merged = BusinessSettingsMerger.merge(
        currentSettings,
        imported,
        preserveExplicitEmptyInstructionList:
            preserveExplicitEmptyInstructionList,
      );
      return BusinessSettingsRouter.normalizeAndRoute(merged);
    }, writeReceipt: true);
  }
}
