import 'package:drift/native.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:Kelivo/core/database/app_database.dart';
import 'package:Kelivo/core/database/business_preferences.dart';
import 'package:Kelivo/core/database/business_repository.dart';
import 'package:Kelivo/core/providers/assistant_provider.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/providers/tts_provider.dart';
import 'package:Kelivo/core/providers/user_provider.dart';
import 'package:Kelivo/features/home/services/ask_user_interaction_service.dart';
import 'package:Kelivo/features/home/services/tool_approval_service.dart';

/// App-lifetime providers for isolated message probes. Replacing a timeline or
/// reopening its database does not recreate the application's TTS engine.
class MessageTestServices {
  MessageTestServices._(this.database, BusinessPreferences preferences)
    : settings = SettingsProvider(preferences),
      assistants = AssistantProvider(preferences: preferences),
      user = UserProvider(preferences: preferences),
      tts = TtsProvider(preferences: preferences);
  final AppDatabase database;
  final SettingsProvider settings;
  final AssistantProvider assistants;
  final UserProvider user;
  final TtsProvider tts;
  final ask = AskUserInteractionService();
  final approval = ToolApprovalService();

  static Future<MessageTestServices> open() async {
    SharedPreferences.setMockInitialValues({});
    final db = AppDatabase(NativeDatabase.memory());
    final preferences = BusinessPreferences(BusinessRepository(db));
    await preferences.load();
    final services = MessageTestServices._(db, preferences);
    await services.settings.loaded;
    await services.assistants.loaded;
    final deadline = DateTime.now().add(const Duration(seconds: 10));
    while (!services.tts.isAvailable &&
        services.tts.error == null &&
        DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    return services;
  }

  Widget wrap(Widget child) => MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: settings),
      ChangeNotifierProvider.value(value: assistants),
      ChangeNotifierProvider.value(value: user),
      ChangeNotifierProvider.value(value: tts),
      ChangeNotifierProvider.value(value: ask),
      ChangeNotifierProvider.value(value: approval),
    ],
    child: child,
  );

  Future<void> close() async {
    settings.dispose();
    assistants.dispose();
    user.dispose();
    tts.dispose();
    ask.dispose();
    approval.dispose();
    await database.close();
  }
}
