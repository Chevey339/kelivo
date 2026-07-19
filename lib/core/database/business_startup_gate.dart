import 'business_migration_engine.dart';
import 'business_preferences.dart';
import 'business_repository.dart';

/// Completes the one-time legacy migration before exposing business state.
///
/// Keeping this gate outside the widget tree prevents providers from observing
/// an empty database when migration, verification, or legacy cleanup fails.
final class BusinessStartupGate {
  BusinessStartupGate._();

  static Future<BusinessPreferences> migrateAndLoad({
    required BusinessRepository repository,
    required LegacyBusinessPreferences legacyPreferences,
  }) async {
    await BusinessMigrationEngine(
      repository: repository,
      legacyPreferences: legacyPreferences,
    ).run();
    final preferences = BusinessPreferences(repository);
    await preferences.load();
    return preferences;
  }
}
