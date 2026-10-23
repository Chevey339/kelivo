import 'package:drift/native.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:Kelivo/core/database/app_database.dart';
import 'package:Kelivo/core/database/business_preferences.dart';
import 'package:Kelivo/core/database/business_repository.dart';
import 'package:Kelivo/features/intelligent_ui/host/gallery/message_gallery.dart';

/// Isolated native fixture: production message/list/focus widgets, in-memory
/// storage, no credentials or model requests. Never imported by the app entry.
/// flutter run -d macos -t tool/genui_message_gallery.dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Prevent even device-local SettingsProvider keys from reaching installed
  // app settings. This is explicitly a development executable.
  // ignore: invalid_use_of_visible_for_testing_member
  SharedPreferences.setMockInitialValues({});
  final database = AppDatabase(NativeDatabase.memory());
  final preferences = BusinessPreferences(BusinessRepository(database));
  await preferences.load();
  runApp(GenUiMessageGallery(preferences: preferences));
}
