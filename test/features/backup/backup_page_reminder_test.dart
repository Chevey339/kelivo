import '../../support/business_test_harness.dart';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:Kelivo/core/database/business_preferences.dart';
import 'package:Kelivo/core/database/business_repository.dart';
import 'package:Kelivo/core/providers/backup_reminder_provider.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/chat/chat_service.dart';
import 'package:Kelivo/features/backup/pages/backup_page.dart';
import 'package:Kelivo/l10n/app_localizations.dart';

Future<BackupReminderProvider> _createReminderProvider({
  required BusinessPreferences preferences,
  bool enabled = false,
}) async {
  final provider = BackupReminderProvider(
    preferences: preferences,
    autoLoad: false,
  );
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
  required BusinessRepository businessRepository,
}) {
  return MultiProvider(
    providers: [
      Provider<BusinessRepository>.value(value: businessRepository),
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
      final business = await createBusinessTestHarness();
      final settings = SettingsProvider(business.preferences);
      await settings.loaded;
      final reminder = await _createReminderProvider(
        preferences: business.preferences,
      );

      await tester.pumpWidget(
        _buildHarness(
          settings: settings,
          reminder: reminder,
          businessRepository: business.repository,
        ),
      );
      await tester.pump();

      expect(find.text('Backup Reminder'), findsOneWidget);
      expect(find.text('Remind me to back up'), findsOneWidget);
      expect(find.text('Frequency'), findsNothing);
    });

    testWidgets('shows frequency and reminder status when enabled', (
      tester,
    ) async {
      final business = await createBusinessTestHarness();
      final settings = SettingsProvider(business.preferences);
      await settings.loaded;
      final reminder = await _createReminderProvider(
        preferences: business.preferences,
        enabled: true,
      );

      await tester.pumpWidget(
        _buildHarness(
          settings: settings,
          reminder: reminder,
          businessRepository: business.repository,
        ),
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
