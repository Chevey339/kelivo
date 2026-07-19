import 'dart:io';

import 'package:Kelivo/core/database/app_database.dart';
import 'package:Kelivo/core/database/business_preferences.dart';
import 'package:Kelivo/core/database/business_repository.dart';
import 'package:drift/native.dart';

final class BusinessPreferencesTestHarness {
  BusinessPreferencesTestHarness._(this.directory, this.file);

  final Directory directory;
  final File file;
  final List<BusinessPreferencesTestSession> _sessions =
      <BusinessPreferencesTestSession>[];

  static Future<BusinessPreferencesTestHarness> create() async {
    final directory = await Directory.systemTemp.createTemp(
      'kelivo_business_preferences_test_',
    );
    return BusinessPreferencesTestHarness._(
      directory,
      File('${directory.path}/kelivo.db'),
    );
  }

  Future<BusinessPreferencesTestSession> open() async {
    final database = AppDatabase(NativeDatabase(file));
    final preferences = BusinessPreferences(BusinessRepository(database));
    await preferences.load();
    final session = BusinessPreferencesTestSession._(database, preferences);
    _sessions.add(session);
    return session;
  }

  Future<void> dispose() async {
    for (final session in _sessions.reversed) {
      await session.close();
    }
    if (await directory.exists()) await directory.delete(recursive: true);
  }
}

final class BusinessPreferencesTestSession {
  BusinessPreferencesTestSession._(this.database, this.preferences);

  final AppDatabase database;
  final BusinessPreferences preferences;
  bool _closed = false;

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await database.close();
  }
}
