import 'package:Kelivo/shared/widgets/ios_switch.dart';
import 'package:Kelivo/core/providers/s3_backup_provider.dart';
import 'package:Kelivo/core/providers/backup_provider.dart';
import 'package:Kelivo/core/providers/external_backup_auto_provider.dart';
import '../../support/business_test_harness.dart';

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:Kelivo/core/database/business_preferences.dart';
import 'package:Kelivo/core/database/business_repository.dart';
import 'package:Kelivo/core/providers/backup_reminder_provider.dart';
import 'package:Kelivo/core/providers/local_snapshot_provider.dart';
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
  required BusinessPreferences businessPreferences,
}) {
  return MultiProvider(
    providers: [
      Provider<BusinessRepository>.value(value: businessRepository),
      Provider<BusinessPreferences>.value(value: businessPreferences),
      ChangeNotifierProvider<SettingsProvider>.value(value: settings),
      ChangeNotifierProvider<ChatService>(create: (_) => ChatService()),
      ChangeNotifierProvider<BackupReminderProvider>.value(value: reminder),
      ChangeNotifierProvider<LocalSnapshotProvider>(
        create: (context) => LocalSnapshotProvider(
          appDataDirectory: Directory.systemTemp.createTempSync(
            'kelivo_backup_page_',
          ),
          chatService: context.read<ChatService>(),
          businessRepository: businessRepository,
          businessPreferences: businessPreferences,
          autoLoad: false,
        ),
      ),
      ChangeNotifierProvider(
        create: (ctx) => BackupProvider(
          chatService: ctx.read<ChatService>(),
          businessPreferences: businessPreferences,
          businessRepository: businessRepository,
          initialConfig: settings.webDavConfig,
        ),
      ),
      ChangeNotifierProvider(
        create: (ctx) => S3BackupProvider(
          chatService: ctx.read<ChatService>(),
          businessPreferences: businessPreferences,
          businessRepository: businessRepository,
          initialConfig: settings.s3Config,
        ),
      ),
      ChangeNotifierProvider(
        create: (ctx) => ExternalBackupAutoProvider(
          preferences: businessPreferences,
          settings: ctx.read<SettingsProvider>(),
          reminder: ctx.read<BackupReminderProvider>(),
          webdav: ctx.read<BackupProvider>(),
          s3: ctx.read<S3BackupProvider>(),
          desktop: false,
        ),
      ),
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
          businessPreferences: business.preferences,
        ),
      );
      await tester.pump();
      await tester.scrollUntilVisible(find.text('Backup Reminder'), 300);
      await tester.pumpAndSettle();

      expect(find.text('Backup Reminder'), findsOneWidget);
      expect(find.text('Remind me to back up'), findsOneWidget);
      expect(find.text('Frequency'), findsNothing);
      expect(
        find.byKey(const ValueKey('external-backup-auto-switch')),
        findsNothing,
      );
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
          businessPreferences: business.preferences,
        ),
      );
      await tester.pump();
      await tester.scrollUntilVisible(find.text('Backup Reminder'), 300);
      await tester.pumpAndSettle();

      expect(find.text('Backup Reminder'), findsOneWidget);
      expect(find.text('Frequency'), findsOneWidget);
      expect(find.text('Every week'), findsOneWidget);
      expect(find.text('Last Backup'), findsOneWidget);
      expect(find.text('Next Reminder'), findsOneWidget);
      expect(find.text('Set up WebDAV or S3 first.'), findsOneWidget);
      expect(find.text('Choose folder…'), findsNothing);
      final toggle = tester.widget<IosSwitch>(
        find.byKey(const ValueKey('external-backup-auto-switch')),
      );
      expect(toggle.onChanged, isNull);
    });
  });
}
