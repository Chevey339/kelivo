import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:Kelivo/core/providers/backup_provider.dart';
import 'package:Kelivo/core/providers/backup_reminder_provider.dart';
import 'package:Kelivo/core/providers/s3_backup_provider.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/chat/chat_service.dart';
import 'package:Kelivo/desktop/setting/backup_pane.dart';
import 'package:Kelivo/features/backup/pages/backup_page.dart';
import 'package:Kelivo/l10n/app_localizations.dart';

Future<BackupReminderProvider> _createReminderProvider() async {
  final provider = BackupReminderProvider(autoLoad: false);
  await provider.load(startTimer: false);
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

Widget _buildDesktopHarness({
  required SettingsProvider settings,
  required BackupReminderProvider reminder,
}) {
  final chatService = ChatService();

  return MultiProvider(
    providers: [
      ChangeNotifierProvider<SettingsProvider>.value(value: settings),
      ChangeNotifierProvider<ChatService>.value(value: chatService),
      ChangeNotifierProvider<BackupReminderProvider>.value(value: reminder),
      ChangeNotifierProvider<BackupProvider>(
        create: (_) => BackupProvider(
          chatService: chatService,
          initialConfig: settings.webDavConfig,
        ),
      ),
      ChangeNotifierProvider<S3BackupProvider>(
        create: (_) => S3BackupProvider(
          chatService: chatService,
          initialConfig: settings.s3Config,
        ),
      ),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const Scaffold(body: DesktopBackupPane()),
    ),
  );
}

Future<void> _pumpBackupPage(
  WidgetTester tester, {
  required SettingsProvider settings,
}) async {
  final reminder = await _createReminderProvider();

  await tester.pumpWidget(
    _buildHarness(settings: settings, reminder: reminder),
  );
  await tester.pump();
}

Future<void> _pumpDesktopBackupPane(
  WidgetTester tester, {
  required SettingsProvider settings,
}) async {
  final reminder = await _createReminderProvider();

  await tester.pumpWidget(
    _buildDesktopHarness(settings: settings, reminder: reminder),
  );
  await tester.pump();
}

Future<void> _openSettingsPage(WidgetTester tester, String label) async {
  final target = find.text(label);
  await tester.scrollUntilVisible(
    target,
    120,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

void _expectAbove(WidgetTester tester, String upper, String lower) {
  final upperTop = tester.getTopLeft(find.text(upper).first).dy;
  final lowerTop = tester.getTopLeft(find.text(lower).first).dy;

  expect(upperTop, lessThan(lowerTop));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BackupPage mobile backup settings navigation', () {
    setUp(() {
      SharedPreferences.setMockInitialValues(const {});
    });

    testWidgets('opens WebDAV settings as a full page and saves config', (
      tester,
    ) async {
      final settings = SettingsProvider();

      await _pumpBackupPage(tester, settings: settings);

      await _openSettingsPage(tester, 'WebDAV Server Settings');

      expect(find.byType(BottomSheet), findsNothing);
      expect(find.widgetWithText(AppBar, 'WebDAV Server Settings'), findsOne);
      expect(find.text('WebDAV Server URL'), findsOneWidget);
      expect(find.text('User-Agent'), findsOneWidget);

      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), ' https://dav.example.com/root ');
      await tester.enterText(fields.at(4), ' KelivoTest/1.0 ');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(
        find.widgetWithText(AppBar, 'WebDAV Server Settings'),
        findsNothing,
      );
      expect(settings.webDavConfig.url, 'https://dav.example.com/root');
      expect(settings.webDavConfig.userAgent, 'KelivoTest/1.0');
    });

    testWidgets('shows local backup before WebDAV and S3 backup sections', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(900, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final settings = SettingsProvider();

      await _pumpBackupPage(tester, settings: settings);

      expect(find.text('Backup Reminder'), findsOneWidget);
      expect(find.text('Local Backup'), findsOneWidget);
      expect(find.text('WebDAV Backup'), findsOneWidget);
      expect(find.text('S3 Backup'), findsOneWidget);
      _expectAbove(tester, 'Backup Reminder', 'Local Backup');
      _expectAbove(tester, 'Local Backup', 'WebDAV Backup');
      _expectAbove(tester, 'WebDAV Backup', 'S3 Backup');
    });

    testWidgets('opens S3 settings as a full page and saves config', (
      tester,
    ) async {
      final settings = SettingsProvider();

      await _pumpBackupPage(tester, settings: settings);

      await _openSettingsPage(tester, 'S3 Settings');

      expect(find.byType(BottomSheet), findsNothing);
      expect(find.widgetWithText(AppBar, 'S3 Settings'), findsOne);
      expect(find.text('Endpoint'), findsOneWidget);
      expect(find.text('User-Agent'), findsOneWidget);

      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), ' https://s3.example.com ');
      await tester.enterText(fields.at(7), ' KelivoS3/1.0 ');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(AppBar, 'S3 Settings'), findsNothing);
      expect(settings.s3Config.endpoint, 'https://s3.example.com');
      expect(settings.s3Config.userAgent, 'KelivoS3/1.0');
    });

    testWidgets('desktop shows local backup before WebDAV and S3 sections', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1100, 1300));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final settings = SettingsProvider();

      await _pumpDesktopBackupPane(tester, settings: settings);

      expect(find.text('Backup Reminder'), findsOneWidget);
      expect(find.text('Local Backup'), findsOneWidget);
      expect(find.text('WebDAV Server Settings'), findsOneWidget);
      expect(find.text('S3 Settings'), findsOneWidget);
      _expectAbove(tester, 'Backup Reminder', 'Local Backup');
      _expectAbove(tester, 'Local Backup', 'WebDAV Server Settings');
      _expectAbove(tester, 'WebDAV Server Settings', 'S3 Settings');
    });
  });
}
