import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:Kelivo/core/database/app_database.dart';
import 'package:Kelivo/core/database/business_preferences.dart';
import 'package:Kelivo/core/database/business_repository.dart';
import 'package:Kelivo/core/database/business_settings_router.dart';

final class BusinessTestHarness {
  BusinessTestHarness._(this.database, this.repository, this.preferences);

  final AppDatabase database;
  final BusinessRepository repository;
  final BusinessPreferences preferences;

  static Future<BusinessTestHarness> create({
    Map<String, Object?> initial = const <String, Object?>{},
    Map<String, Object> localInitial = const <String, Object>{},
  }) async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    SharedPreferences.setMockInitialValues(localInitial);
    final database = AppDatabase(NativeDatabase.memory());
    final repository = BusinessRepository(database);
    await database.customSelect('SELECT 1;').getSingle();
    if (initial.isNotEmpty) {
      await repository.replaceSnapshot(
        BusinessSettingsRouter.normalizeAndRoute(initial),
      );
    }
    final preferences = BusinessPreferences(repository);
    await preferences.load();
    return BusinessTestHarness._(database, repository, preferences);
  }

  Future<void> close() => database.close();
}

Future<BusinessTestHarness> createBusinessTestHarness({
  Map<String, Object?> initial = const <String, Object?>{},
  Map<String, Object> localInitial = const <String, Object>{},
}) async {
  final harness = await BusinessTestHarness.create(
    initial: initial,
    localInitial: localInitial,
  );
  addTearDown(harness.close);
  return harness;
}

/// Creates an isolated SQLite-backed preference facade for tests that only need
/// to satisfy a provider dependency. The provider will await [load] itself.
///
/// Prefer [createBusinessTestHarness] when a test needs seeded business data or
/// direct access to the repository. These dependency-only databases intentionally
/// live for the test isolate: a provider can keep writing defaults after a widget
/// test has completed, so closing them from `addTearDown` races that work.
BusinessPreferences createBusinessTestPreferences({
  Map<String, Object> localInitial = const <String, Object>{},
}) {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  SharedPreferences.setMockInitialValues(localInitial);
  final database = AppDatabase(NativeDatabase.memory());
  return BusinessPreferences(BusinessRepository(database));
}
