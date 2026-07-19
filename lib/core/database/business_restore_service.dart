import 'business_repository.dart';
import 'business_settings_merger.dart';
import 'business_settings_router.dart';

final class BusinessRestoreService {
  BusinessRestoreService(this._repository);

  final BusinessRepository _repository;

  Future<Map<String, Object>> exportSettings() async =>
      BusinessSettingsRouter.exportSnapshot(await _repository.readSnapshot());

  Future<void> overwrite(Map<String, Object?> imported) async {
    final replacement = BusinessSettingsRouter.normalizeAndRoute(imported);
    await _repository.replaceSnapshot(replacement, writeReceipt: true);
  }

  Future<void> merge(Map<String, Object?> imported) async {
    // Validate and normalize before opening the write transaction. The merger
    // repeats canonicalization against the transaction's current snapshot so
    // concurrent business writes cannot be lost between read and commit.
    BusinessSettingsRouter.normalizeAndRoute(imported);
    await _repository.transformSnapshot((current) {
      final currentSettings = BusinessSettingsRouter.exportSnapshot(current);
      final merged = BusinessSettingsMerger.merge(currentSettings, imported);
      return BusinessSettingsRouter.normalizeAndRoute(merged);
    }, writeReceipt: true);
  }
}
