import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/features/migration/hive_to_sqlite_migration_page.dart';
import 'package:Kelivo/features/migration/hive_to_sqlite_migration_service.dart';
import 'package:Kelivo/icons/lucide_adapter.dart';
import 'package:Kelivo/main.dart' show MigrationApp;
import 'package:Kelivo/shared/widgets/snackbar.dart';

void main() {
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
