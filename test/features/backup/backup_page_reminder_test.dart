import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:Kelivo/core/providers/backup_reminder_provider.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/chat/chat_service.dart';
import 'package:Kelivo/features/backup/pages/backup_page.dart';
import 'package:Kelivo/l10n/app_localizations.dart';

Future<BackupReminderProvider> _createReminderProvider({
  bool enabled = false,
}) async {
  final provider = BackupReminderProvider(autoLoad: false);
  await provider.load(startTimer: false);
  if (enabled) {
    await provider.saveSchedule(
      enabled: true,
      intervalDays: 7,
      reminderMinutesOfDay: 8 * 60 + 30,
      now: DateTime(2026, 5, 5, 9),
    );
  }
  return provider;
}

Widget _buildHarness({
  required SettingsProvider settings,
  required BackupReminderProvider reminder,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<SettingsProvider>.value(value: settings),
      ChangeNotifierProvider<ChatService>(create: (_) => ChatService()),
      ChangeNotifierProvider<BackupReminderProvider>.value(value: reminder),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const BackupPage(),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BackupPage reminder settings', () {
    testWidgets('shows reminder switch while disabled', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final settings = SettingsProvider();
      final reminder = await _createReminderProvider();

      await tester.pumpWidget(
        _buildHarness(settings: settings, reminder: reminder),
      );
      await tester.pump();

      expect(find.text('Backup Reminder'), findsOneWidget);
      expect(find.text('Remind me to back up'), findsOneWidget);
      expect(find.text('Frequency'), findsNothing);
    });

    testWidgets('shows frequency and reminder status when enabled', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final settings = SettingsProvider();
      final reminder = await _createReminderProvider(enabled: true);

      await tester.pumpWidget(
        _buildHarness(settings: settings, reminder: reminder),
      );
      await tester.pump();

      expect(find.text('Backup Reminder'), findsOneWidget);
      expect(find.text('Frequency'), findsOneWidget);
      expect(find.text('Every week'), findsOneWidget);
      expect(find.text('Last Backup'), findsOneWidget);
      expect(find.text('Next Reminder'), findsOneWidget);
    });
  });
}
