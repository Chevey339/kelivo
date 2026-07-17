import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/features/migration/hive_to_sqlite_migration_page.dart';
import 'package:Kelivo/features/migration/hive_to_sqlite_migration_service.dart';
import 'package:Kelivo/icons/lucide_adapter.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/main.dart' show MigrationApp;
import 'package:Kelivo/shared/widgets/snackbar.dart';

void main() {
  testWidgets('mobile retry does not export an already saved backup again', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(800, 1000);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final testDirectory = Directory.systemTemp.createTempSync(
      'kelivo_mobile_migration_retry_',
    );
    addTearDown(() {
      if (testDirectory.existsSync()) {
        testDirectory.deleteSync(recursive: true);
      }
    });
    final service = _RetryMigrationService(
      HiveToSqliteMigrationDecision(
        needsMigration: true,
        appDataDir: testDirectory,
        sqliteFile: File('${testDirectory.path}/kelivo-test.sqlite'),
        hiveFiles: const <File>[],
      ),
    );
    var saveCalls = 0;

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: HiveToSqliteMigrationPage(
          service: service,
          mobileBackupSaver: ({required sourcePath, fileName}) async {
            saveCalls++;
            expect(File(sourcePath).existsSync(), isTrue);
            expect(fileName, isNotEmpty);
            return true;
          },
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));

    final startButton = _buttonForIcon(tester, Lucide.FolderPlus);
    await tester.runAsync(() async {
      startButton.onTap!();
      await _waitUntil(
        () =>
            service.migrationBackupPaths.isNotEmpty &&
            !service.temporaryBackup.existsSync(),
      );
    });
    await tester.pump(const Duration(milliseconds: 300));

    expect(service.backupCalls, 1);
    expect(saveCalls, 1);
    expect(service.migrationBackupPaths, <String?>[null]);
    expect(service.temporaryBackup.existsSync(), isFalse);
    expect(find.byIcon(Lucide.RotateCcw), findsOneWidget);

    final retryButton = _buttonForIcon(tester, Lucide.RotateCcw);
    await tester.runAsync(() async {
      retryButton.onTap!();
      await _waitUntil(() => service.migrationBackupPaths.length == 2);
    });
    await tester.pump();

    expect(service.backupCalls, 1);
    expect(saveCalls, 1);
    expect(service.migrationBackupPaths, <String?>[null, null]);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('real migration shell renders localized restart failures', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    MethodCall? restartCall;
    const restartChannel = MethodChannel('restart');
    messenger.setMockMethodCallHandler(restartChannel, (call) async {
      restartCall = call;
      return <String, dynamic>{
        'success': false,
        'mode': 'process',
        'code': 'INJECTED_FAILURE',
      };
    });
    addTearDown(() {
      debugDefaultTargetPlatformOverride = null;
      messenger.setMockMethodCallHandler(restartChannel, null);
    });
    tester.binding.platformDispatcher.localesTestValue = const <Locale>[
      Locale('zh'),
    ];
    addTearDown(tester.binding.platformDispatcher.clearLocalesTestValue);
    await tester.pumpWidget(MigrationApp(service: _completeService()));
    await tester.pumpAndSettle();

    expect(find.byType(AppSnackBarOverlay), findsOneWidget);
    expect(find.text('对话'), findsOneWidget);
    expect(find.text('消息'), findsOneWidget);
    expect(find.byType(HiveToSqliteMigrationPage), findsOneWidget);
    final restartButton = find.byIcon(Lucide.RefreshCw);
    expect(restartButton, findsOneWidget);
    final reportedErrors = <FlutterErrorDetails>[];
    final previousOnError = FlutterError.onError;
    FlutterError.onError = reportedErrors.add;
    try {
      await tester.tap(restartButton);
      await tester.pump();
    } finally {
      FlutterError.onError = previousOnError;
    }

    expect(restartCall?.method, 'restartApp');
    expect(restartCall?.arguments, containsPair('mode', 'process'));
    expect(reportedErrors, hasLength(1));
    expect(find.text('Kelivo 无法自动重启，请完全关闭后重新打开。'), findsOneWidget);

    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    debugDefaultTargetPlatformOverride = null;
    messenger.setMockMethodCallHandler(restartChannel, null);
  });
}

GestureDetector _buttonForIcon(WidgetTester tester, IconData icon) {
  final button = find.ancestor(
    of: find.byIcon(icon),
    matching: find.byType(GestureDetector),
  );
  expect(button, findsOneWidget);
  return tester.widget<GestureDetector>(button);
}

Future<void> _waitUntil(bool Function() condition) async {
  for (var i = 0; i < 100 && !condition(); i++) {
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  expect(condition(), isTrue);
}

HiveToSqliteMigrationService _completeService() {
  return _CompleteMigrationService(
    HiveToSqliteMigrationDecision(
      needsMigration: true,
      appDataDir: Directory.systemTemp,
      sqliteFile: File('${Directory.systemTemp.path}/kelivo-test.sqlite'),
      hiveFiles: const <File>[],
    ),
  );
}

final class _CompleteMigrationService extends HiveToSqliteMigrationService {
  _CompleteMigrationService(super.decision);

  @override
  HiveToSqliteMigrationStatus initialStatus() {
    return const HiveToSqliteMigrationStatus(
      stage: HiveToSqliteMigrationStage.complete,
      progress: 1,
      title: 'complete',
      detail: 'done',
    );
  }
}

final class _RetryMigrationService extends HiveToSqliteMigrationService {
  _RetryMigrationService(super.decision)
    : temporaryBackup = File('${decision.appDataDir.path}/migration.zip');

  final File temporaryBackup;
  final List<String?> migrationBackupPaths = <String?>[];
  int backupCalls = 0;

  @override
  Future<File> backupToTemporaryFile() async {
    backupCalls++;
    temporaryBackup.writeAsStringSync('temporary migration backup');
    return temporaryBackup;
  }

  @override
  Future<void> migrate({String? backupPath}) async {
    migrationBackupPaths.add(backupPath);
    if (migrationBackupPaths.length == 1) {
      throw StateError('injected migration failure');
    }
  }
}
