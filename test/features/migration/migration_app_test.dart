import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/features/migration/hive_to_sqlite_migration_page.dart';
import 'package:Kelivo/features/migration/hive_to_sqlite_migration_service.dart';
import 'package:Kelivo/features/migration/widgets/migration_backup_options.dart';
import 'package:Kelivo/icons/lucide_adapter.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/main.dart' show MigrationApp;
import 'package:Kelivo/shared/widgets/ios_checkbox.dart';
import 'package:Kelivo/shared/widgets/snackbar.dart';

void main() {
  testWidgets('can skip backup and start migration immediately', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(800, 1000);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final testDirectory = Directory.systemTemp.createTempSync(
      'kelivo_skip_backup_option_',
    );
    addTearDown(() {
      if (testDirectory.existsSync()) {
        testDirectory.deleteSync(recursive: true);
      }
    });
    final service = _OptionMigrationService(
      HiveToSqliteMigrationDecision(
        needsMigration: true,
        appDataDir: testDirectory,
        sqliteFile: File('${testDirectory.path}/kelivo-test.sqlite'),
        hiveFiles: const <File>[],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: HiveToSqliteMigrationPage(
          service: service,
          mobileBackupSaver: ({required sourcePath, fileName}) async => true,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));

    final options = find.byType(MigrationBackupOptions);
    expect(
      find.descendant(of: options, matching: find.byType(IosCheckbox)),
      findsNWidgets(2),
    );
    expect(
      find.descendant(of: options, matching: find.byType(CheckboxListTile)),
      findsNothing,
    );
    expect(
      find.descendant(of: options, matching: find.byType(Divider)),
      findsNothing,
    );
    expect(
      find.descendant(of: options, matching: find.byType(InkWell)),
      findsNothing,
    );

    await tester.tap(find.byKey(const Key('migration_skip_backup')));
    await tester.pump();
    final skipBackupControl = find.descendant(
      of: find.byKey(const Key('migration_skip_backup')),
      matching: find.byType(IosCheckbox),
    );
    expect(tester.widget<IosCheckbox>(skipBackupControl).value, isTrue);

    await tester.runAsync(() async {
      _buttonForIcon(tester, Lucide.Database).onTap!();
      await _waitUntil(() => service.migrationCalls == 1);
    });

    expect(service.temporaryBackupCalls, 0);
    expect(service.directBackupIncludesChats, isEmpty);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('direct mobile backup can omit chats.json', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(800, 1000);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final testDirectory = Directory.systemTemp.createTempSync(
      'kelivo_skip_chats_option_',
    );
    addTearDown(() {
      if (testDirectory.existsSync()) {
        testDirectory.deleteSync(recursive: true);
      }
    });
    final service = _OptionMigrationService(
      HiveToSqliteMigrationDecision(
        needsMigration: true,
        appDataDir: testDirectory,
        sqliteFile: File('${testDirectory.path}/kelivo-test.sqlite'),
        hiveFiles: const <File>[],
      ),
    );
    var destinationCalls = 0;

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: HiveToSqliteMigrationPage(
          service: service,
          mobileDirectBackupSaver: ({required fileName, required write}) async {
            destinationCalls++;
            expect(fileName, endsWith('.zip'));
            await write((_) async {});
            return true;
          },
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));

    await tester.tap(find.byKey(const Key('migration_skip_chats_json')));
    await tester.pump();
    await tester.runAsync(() async {
      _buttonForIcon(tester, Lucide.FolderPlus).onTap!();
      await _waitUntil(() => service.migrationCalls == 1);
    });

    expect(destinationCalls, 1);
    expect(service.directBackupIncludesChats, <bool>[false]);
    expect(service.temporaryBackupCalls, 0);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

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

final class _OptionMigrationService extends HiveToSqliteMigrationService {
  _OptionMigrationService(super.decision);

  int temporaryBackupCalls = 0;
  int migrationCalls = 0;
  final List<bool> directBackupIncludesChats = <bool>[];

  @override
  Future<File> backupToTemporaryFile({bool includeChatsJson = true}) async {
    temporaryBackupCalls++;
    final file = File('${decision.appDataDir.path}/temporary.zip');
    await file.writeAsString('backup');
    return file;
  }

  @override
  Future<void> backupToWritableSink(
    MigrationBackupChunkWriter writeChunk, {
    bool includeChatsJson = true,
  }) async {
    directBackupIncludesChats.add(includeChatsJson);
    await writeChunk(Uint8List.fromList(const <int>[1, 2, 3]));
  }

  @override
  Future<void> migrate({String? backupPath}) async {
    migrationCalls++;
  }
}

final class _RetryMigrationService extends HiveToSqliteMigrationService {
  _RetryMigrationService(super.decision)
    : temporaryBackup = File('${decision.appDataDir.path}/migration.zip');

  final File temporaryBackup;
  final List<String?> migrationBackupPaths = <String?>[];
  int backupCalls = 0;

  @override
  Future<File> backupToTemporaryFile({bool includeChatsJson = true}) async {
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
