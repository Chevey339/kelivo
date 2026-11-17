import 'dart:io';

import 'package:Kelivo/core/database/business_preferences.dart';
import 'package:Kelivo/core/database/business_repository.dart';
import 'package:Kelivo/core/providers/backup_provider.dart';
import 'package:Kelivo/core/providers/backup_reminder_provider.dart';
import 'package:Kelivo/core/providers/external_backup_auto_provider.dart';
import 'package:Kelivo/core/providers/local_snapshot_provider.dart';
import 'package:Kelivo/core/providers/s3_backup_provider.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/chat/chat_service.dart';
import 'package:Kelivo/desktop/setting/backup_pane.dart';
import 'package:Kelivo/features/backup/pages/backup_page.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/widgets/snackbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'business_test_harness.dart';

Future<void> pumpBackupSettingsPage(
  WidgetTester tester, {
  required SettingsProvider settings,
  required BusinessTestHarness business,
  bool desktop = false,
  Locale locale = const Locale('en'),
  ChatService? chat,
  BackupProvider? backup,
}) async {
  final directory = Directory.systemTemp.createTempSync('kelivo_backup_page_');
  addTearDown(() => directory.deleteSync(recursive: true));
  final reminder = BackupReminderProvider(
    preferences: business.preferences,
    autoLoad: false,
  );
  await reminder.load(startTimer: false);
  addTearDown(reminder.dispose);
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        Provider<BusinessRepository>.value(value: business.repository),
        Provider<BusinessPreferences>.value(value: business.preferences),
        ChangeNotifierProvider<SettingsProvider>.value(value: settings),
        ChangeNotifierProvider<ChatService>(
          create: (_) => chat ?? ChatService(),
        ),
        ChangeNotifierProvider<BackupReminderProvider>.value(value: reminder),
        ChangeNotifierProvider<LocalSnapshotProvider>(
          create: (ctx) => LocalSnapshotProvider(
            appDataDirectory: directory,
            chatService: ctx.read<ChatService>(),
            businessRepository: business.repository,
            businessPreferences: business.preferences,
            autoLoad: false,
          ),
        ),
        ChangeNotifierProvider<BackupProvider>(
          create: (ctx) =>
              backup ??
              BackupProvider(
                chatService: ctx.read<ChatService>(),
                businessPreferences: business.preferences,
                businessRepository: business.repository,
              ),
        ),
        ChangeNotifierProvider<S3BackupProvider>(
          create: (ctx) => S3BackupProvider(
            chatService: ctx.read<ChatService>(),
            businessPreferences: business.preferences,
            businessRepository: business.repository,
          ),
        ),
        ChangeNotifierProvider(
          create: (ctx) => ExternalBackupAutoProvider(
            preferences: business.preferences,
            settings: settings,
            reminder: reminder,
            webdav: ctx.read<BackupProvider>(),
            s3: ctx.read<S3BackupProvider>(),
            desktop: desktop,
          ),
        ),
      ],
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (_, child) => AppSnackBarOverlay(child: child!),
        home: desktop
            ? const Scaffold(body: DesktopBackupPane())
            : const BackupPage(),
      ),
    ),
  );
  await tester.pump();
}
