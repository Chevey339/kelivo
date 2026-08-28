import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:Kelivo/core/database/business_preferences.dart';
import 'package:Kelivo/core/database/business_repository.dart';
import 'package:Kelivo/core/models/backup.dart';
import 'package:Kelivo/core/providers/backup_provider.dart';
import 'package:Kelivo/core/providers/backup_reminder_provider.dart';
import 'package:Kelivo/core/providers/s3_backup_provider.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/backup/backup_cancel_token.dart';
import 'package:Kelivo/core/services/backup/backup_task_progress.dart';
import 'package:Kelivo/core/services/chat/chat_service.dart';
import 'package:Kelivo/features/backup/pages/backup_page.dart';
import 'package:Kelivo/l10n/app_localizations.dart';

import '../../support/business_test_harness.dart';

class _HangingBackupProvider extends BackupProvider {
  _HangingBackupProvider({
    required super.chatService,
    required super.businessRepository,
    required super.businessPreferences,
  });

  final Completer<List<BackupFileItem>> pending =
      Completer<List<BackupFileItem>>();
  var started = false;

  @override
  Future<List<BackupFileItem>> listRemote({
    BackupProgressSink? onProgress,
    BackupCancelToken? cancelToken,
  }) {
    started = true;
    return pending.future;
  }
}

class _HangingS3BackupProvider extends S3BackupProvider {
  _HangingS3BackupProvider({
    required super.chatService,
    required super.businessRepository,
    required super.businessPreferences,
  });

  final Completer<List<BackupFileItem>> pending =
      Completer<List<BackupFileItem>>();
  var started = false;

  @override
  Future<List<BackupFileItem>> listRemote({
    BackupProgressSink? onProgress,
    BackupCancelToken? cancelToken,
  }) {
    started = true;
    return pending.future;
  }
}

Future<BackupReminderProvider> _reminder(
  BusinessPreferences preferences,
) async {
  final provider = BackupReminderProvider(
    preferences: preferences,
    autoLoad: false,
  );
  await provider.load(startTimer: false);
  return provider;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final sampleItem = BackupFileItem(
    href: Uri.parse('https://example.com/backup.zip'),
    displayName: 'kelivo_backup.zip',
    size: 12,
    lastModified: null,
  );

  testWidgets(
    'destroying BackupPage during WebDAV list does not setState after dispose',
    (tester) async {
      await _expectNoSetStateAfterDispose(
        tester,
        tapFirstRestore: true,
        complete: (webDav, s3) => webDav.pending.complete([sampleItem]),
      );
    },
  );

  testWidgets(
    'destroying BackupPage during S3 list does not setState after dispose',
    (tester) async {
      await _expectNoSetStateAfterDispose(
        tester,
        tapFirstRestore: false,
        complete: (webDav, s3) => s3.pending.complete([sampleItem]),
      );
    },
  );
}

Future<void> _expectNoSetStateAfterDispose(
  WidgetTester tester, {
  required bool tapFirstRestore,
  required void Function(
    _HangingBackupProvider webDav,
    _HangingS3BackupProvider s3,
  )
  complete,
}) async {
  final business = await createBusinessTestHarness();
  final settings = SettingsProvider(business.preferences);
  await settings.loaded;
  final reminder = await _reminder(business.preferences);
  final chatService = ChatService();
  addTearDown(chatService.close);

  final webDav = _HangingBackupProvider(
    chatService: chatService,
    businessRepository: business.repository,
    businessPreferences: business.preferences,
  );
  final s3 = _HangingS3BackupProvider(
    chatService: chatService,
    businessRepository: business.repository,
    businessPreferences: business.preferences,
  );

  final navKey = GlobalKey<NavigatorState>();
  final backupRoute = MaterialPageRoute<void>(
    builder: (_) => MultiProvider(
      providers: [
        Provider<BusinessRepository>.value(value: business.repository),
        Provider<BusinessPreferences>.value(value: business.preferences),
        ChangeNotifierProvider<SettingsProvider>.value(value: settings),
        ChangeNotifierProvider<ChatService>.value(value: chatService),
        ChangeNotifierProvider<BackupReminderProvider>.value(value: reminder),
      ],
      child: BackupPage(debugBackupProvider: webDav, debugS3BackupProvider: s3),
    ),
  );

  final flutterErrors = <Object>[];
  final previousOnError = FlutterError.onError;
  FlutterError.onError = (details) {
    flutterErrors.add(details.exception);
    previousOnError?.call(details);
  };
  addTearDown(() => FlutterError.onError = previousOnError);

  await tester.binding.setSurfaceSize(const Size(800, 1400));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      navigatorKey: navKey,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const SizedBox.shrink(),
    ),
  );
  navKey.currentState!.push(backupRoute);
  await tester.pumpAndSettle();

  final restoreFinder = find.text('Restore');
  final target = tapFirstRestore ? restoreFinder.first : restoreFinder.last;
  await tester.scrollUntilVisible(target, 300);
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pump();
  expect(
    tapFirstRestore ? webDav.started : s3.started,
    isTrue,
    reason: 'list request never started',
  );

  complete(webDav, s3);
  await tester.pump();
  navKey.currentState!.removeRoute(backupRoute);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 700));

  expect(tester.takeException(), isNull);
  expect(flutterErrors.whereType<FlutterError>(), isEmpty);
}
