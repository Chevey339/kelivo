import 'dart:io';

import 'package:Kelivo/core/providers/backup_provider.dart';
import 'package:Kelivo/core/providers/backup_reminder_provider.dart';
import 'package:Kelivo/core/providers/local_snapshot_provider.dart';
import 'package:Kelivo/core/providers/s3_backup_provider.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/chat/chat_service.dart';
import 'package:Kelivo/desktop/setting/backup_pane.dart';
import 'package:Kelivo/desktop/setting/network_proxy_pane.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/widgets/ios_switch.dart';
import 'package:Kelivo/shared/widgets/section_card.dart';
import 'package:Kelivo/theme/palettes.dart';
import 'package:Kelivo/theme/theme_factory.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../support/business_test_harness.dart';

Future<SettingsProvider> _pumpPane(
  WidgetTester tester,
  Widget pane,
  Brightness brightness,
) async {
  tester.view.physicalSize = const Size(1200, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final business = await createBusinessTestHarness();
  final settings = SettingsProvider(business.preferences);
  await settings.loaded;
  final chat = ChatService();
  addTearDown(chat.close);
  final directory = Directory.systemTemp.createTempSync('settings_layout_');
  addTearDown(() => directory.deleteSync(recursive: true));
  final theme = brightness == Brightness.light
      ? buildLightThemeForScheme(ThemePalettes.defaultPalette.light)
      : buildDarkThemeForScheme(ThemePalettes.defaultPalette.dark);

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<SettingsProvider>(create: (_) => settings),
        ChangeNotifierProvider<BackupProvider>(
          create: (_) => BackupProvider(
            chatService: chat,
            businessRepository: business.repository,
            businessPreferences: business.preferences,
          ),
        ),
        ChangeNotifierProvider<S3BackupProvider>(
          create: (_) => S3BackupProvider(
            chatService: chat,
            businessRepository: business.repository,
            businessPreferences: business.preferences,
          ),
        ),
        ChangeNotifierProvider<BackupReminderProvider>(
          create: (_) => BackupReminderProvider(
            preferences: business.preferences,
            autoLoad: false,
          ),
        ),
        ChangeNotifierProvider<LocalSnapshotProvider>(
          create: (_) => LocalSnapshotProvider(
            appDataDirectory: directory,
            chatService: chat,
            businessRepository: business.repository,
            businessPreferences: business.preferences,
            autoLoad: false,
          ),
        ),
      ],
      child: MaterialApp(
        theme: theme,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: pane),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return settings;
}

void _expectInsetHeading(WidgetTester tester, String title) {
  final heading = find.text(title);
  expect(heading, findsOneWidget);
  final card = find.ancestor(of: heading, matching: find.byType(SectionCard));
  final headingRect = tester.getRect(heading);
  final cardRect = tester.getRect(card);
  expect(
    headingRect.left - cardRect.left,
    closeTo(12, 1),
    reason:
        '$title must start at the card content inset, not its edge or center',
  );
  expect(headingRect.top - cardRect.top, closeTo(12, 1));
}

void main() {
  for (final brightness in Brightness.values) {
    testWidgets(
      'proxy headings and notes are inset and left aligned ($brightness)',
      (tester) async {
        final settings = await _pumpPane(
          tester,
          const DesktopNetworkProxyPane(),
          brightness,
        );
        final l10n = AppLocalizations.of(
          tester.element(find.byType(DesktopNetworkProxyPane)),
        )!;
        _expectInsetHeading(tester, l10n.networkProxySettingsHeader);
        final note = find.text(l10n.networkProxyPriorityNote);
        final label = find.text(l10n.networkProxyEnableLabel);
        expect(tester.getTopLeft(note).dx, tester.getTopLeft(label).dx);
        final testButton = find.ancestor(
          of: find.text(l10n.networkProxyTestButton),
          matching: find.byType(AnimatedScale),
        );
        expect(tester.getSize(testButton).width, lessThan(180));
        await tester.tap(find.byType(IosSwitch));
        await tester.pumpAndSettle();
        expect(settings.globalProxyEnabled, isTrue);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'all backup section headings retain their content inset ($brightness)',
      (tester) async {
        await _pumpPane(tester, const DesktopBackupPane(), brightness);
        final l10n = AppLocalizations.of(
          tester.element(find.byType(DesktopBackupPane)),
        )!;
        for (final title in [
          l10n.backupPageBackupManagement,
          l10n.backupReminderSectionTitle,
          l10n.localSnapshotSectionTitle,
          l10n.backupPageLocalBackup,
          l10n.backupPageWebDavServerSettings,
          l10n.backupPageS3ServerSettings,
        ]) {
          await tester.scrollUntilVisible(
            find.text(title),
            300,
            scrollable: find.byType(Scrollable).first,
          );
          await tester.pumpAndSettle();
          _expectInsetHeading(tester, title);
          if (title == l10n.backupPageLocalBackup) {
            final export = find.text(l10n.backupPageExportToFile);
            final import = find.text(l10n.backupPageImportBackupFile);
            expect(tester.getTopLeft(export).dy, tester.getTopLeft(import).dy);
          }
        }
        expect(tester.takeException(), isNull);
      },
    );
  }
}
