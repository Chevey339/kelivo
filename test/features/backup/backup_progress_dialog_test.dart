import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/services/backup/backup_activity.dart';
import 'package:Kelivo/core/services/backup/backup_task_progress.dart';
import 'package:Kelivo/features/backup/backup_task_runner.dart';
import 'package:Kelivo/features/backup/widgets/backup_progress_dialog.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/utils/backup_progress_text.dart';
import 'package:Kelivo/shared/widgets/animated_progress_bar.dart';
import 'package:Kelivo/shared/widgets/task_progress_dialog.dart';

Future<void> _openDialog(
  WidgetTester tester,
  Future<void> Function(BuildContext context) onStart, {
  TextScaler textScaler = TextScaler.noScaling,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('en'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: textScaler),
        child: child!,
      ),
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => unawaited(onStart(context)),
            child: const Text('Start'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Start'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  setUp(BackupActivity.debugReset);
  tearDown(BackupActivity.debugReset);

  test('shows discoveries and elapsed time for unmeasured phases', () {
    final l10n = lookupAppLocalizations(const Locale('en'));
    expect(
      backupProgressSubtitle(
        l10n,
        const BackupProgress(
          phase: BackupPhase.scanning,
          processed: 42,
          unit: BackupProgressUnit.items,
        ),
      ),
      '42 files found',
    );
    expect(
      backupProgressSubtitle(
        l10n,
        const BackupProgress(phase: BackupPhase.checkingDatabase, processed: 0),
        elapsed: const Duration(minutes: 2, seconds: 8),
      ),
      'Elapsed 2:08',
    );
  });

  for (final failTask in [false, true]) {
    testWidgets(
      'detached task delivers its final result once (failure=$failTask)',
      (tester) async {
        final pending = Completer<void>();
        final settled = <BackupTaskResult<void>>[];
        await _openDialog(tester, (context) async {
          await runBackupTask(
            context,
            title: 'Upload',
            backgroundLabel: 'Hide',
            task: (_) => pending.future,
            onSettled: (result, detached) async {
              expect(detached, true);
              settled.add(result);
            },
          );
        });
        await tester.tap(find.text('Hide'));
        await tester.pumpAndSettle();
        expect(BackupActivity.isActive, true);
        if (failTask) {
          pending.completeError(StateError('upload'));
        } else {
          pending.complete();
        }
        await tester.pumpAndSettle();
        expect(settled, hasLength(1));
        expect(settled.single.isSuccess, !failTask);
        expect(BackupActivity.isActive, false);
      },
    );
  }
  for (final total in <int?>[null, 10]) {
    testWidgets('failure stays visible and copies details (total: $total)', (
      tester,
    ) async {
      final pending = Completer<void>();
      const error = FormatException('settings.json is missing');
      BackupTaskResult<void>? result;
      String? copied;
      final messenger = tester.binding.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String;
        }
        return null;
      });
      addTearDown(
        () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
      );

      await _openDialog(tester, (context) async {
        result = await showBackupProgressDialog<void>(
          context,
          title: 'Import backup',
          backgroundLabel: 'Continue in background',
          task: (handle) {
            handle.report(
              BackupProgress(
                phase: BackupPhase.validating,
                processed: 3,
                total: total,
                unit: BackupProgressUnit.items,
              ),
            );
            return pending.future;
          },
        );
      });
      expect(find.text('Checking restore files'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(BackupActivity.isActive, isTrue);

      pending.completeError(error);
      await tester.pumpAndSettle();

      expect(result, isNull);
      expect(find.text('Operation failed'), findsOneWidget);
      expect(
        find.text('Failed during: Checking restore files'),
        findsOneWidget,
      );
      expect(find.text(error.toString()), findsOneWidget);
      expect(find.byType(SelectableText), findsOneWidget);
      expect(find.byType(CupertinoActivityIndicator), findsNothing);
      expect(find.byType(AnimatedProgressBar), findsNothing);
      expect(find.textContaining('%'), findsNothing);
      expect(find.text('Cancel'), findsNothing);
      expect(find.text('Continue in background'), findsNothing);

      await tester.tap(find.text('Copy error'));
      await tester.pumpAndSettle();
      expect(
        copied,
        'Import backup\nFailed during: Checking restore files\n\n$error',
      );
      expect(find.text('Error copied'), findsOneWidget);
      expect(result, isNull);

      await tester.pump(const Duration(seconds: 5));
      expect(find.text(error.toString()), findsOneWidget);
      expect(result, isNull);

      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      expect(find.byType(TaskProgressDialogCard), findsNothing);
      expect(result!.error, same(error));
      expect(result!.cancelled, isFalse);
      expect(BackupActivity.isActive, isFalse);
    });
  }

  testWidgets('runner shows its localized error before closing the dialog', (
    tester,
  ) async {
    bool? result;
    var successCalls = 0;
    await _openDialog(tester, (context) async {
      final l10n = AppLocalizations.of(context)!;
      result = await runBackupTask(
        context,
        title: 'Export backup',
        errorMessage: (error) => l10n.backupPageExportFailedMessage('$error'),
        task: (_) async => throw const FormatException('archive is invalid'),
        onSuccess: () async => successCalls++,
      );
    });
    await tester.pumpAndSettle();

    expect(
      find.text('Export failed: FormatException: archive is invalid'),
      findsOneWidget,
    );
    expect(result, isNull);
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    expect(result, isFalse);
    expect(successCalls, 0);
    // Drain the caller's existing error notification.
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
  });

  testWidgets('long errors scroll while actions fit a small enlarged screen', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 480);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final details = List.generate(
      80,
      (index) => 'FileSystemException: cannot read backup entry $index',
    ).join('\n');
    BackupTaskResult<void>? result;

    await _openDialog(tester, (context) async {
      result = await showBackupProgressDialog<void>(
        context,
        title: 'Import backup file',
        task: (handle) async {
          handle.report(
            const BackupProgress(
              phase: BackupPhase.snapshottingDatabase,
              processed: 0,
            ),
          );
          throw FormatException(details);
        },
      );
    }, textScaler: TextScaler.linear(1.6));
    await tester.pumpAndSettle();

    expect(find.text('Copy error').hitTestable(), findsOneWidget);
    expect(find.text('Close').hitTestable(), findsOneWidget);
    final scrollable = tester.state<ScrollableState>(
      find
          .descendant(
            of: find.byType(SingleChildScrollView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(scrollable.position.maxScrollExtent, greaterThan(0));
    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -150),
    );
    await tester.pumpAndSettle();
    expect(scrollable.position.pixels, greaterThan(0));
    expect(
      tester.widget<SelectableText>(find.byType(SelectableText)).data,
      'FormatException: $details',
    );

    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    expect(result!.error, isA<FormatException>());
  });

  testWidgets('success still closes automatically and returns its value', (
    tester,
  ) async {
    BackupTaskResult<int>? result;
    await _openDialog(tester, (context) async {
      result = await showBackupProgressDialog<int>(
        context,
        title: 'Export backup',
        task: (_) async => 42,
      );
    });
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(result!.isSuccess, isTrue);
    expect(result!.value, 42);
    expect(find.byType(TaskProgressDialogCard), findsNothing);
    expect(BackupActivity.isActive, isFalse);
  });

  testWidgets(
    'skipped paths remain visible after later phases and return success',
    (tester) async {
      BackupTaskResult<int>? result;
      await _openDialog(tester, (context) async {
        result = await showBackupProgressDialog<int>(
          context,
          title: 'Export backup',
          task: (handle) async {
            handle.report(
              const BackupProgress(
                phase: BackupPhase.packing,
                processed: 10,
                skippedEntries: [
                  'sessions/chat/outputs/locked.docx',
                  'upload/locked',
                ],
              ),
            );
            handle.report(
              const BackupProgress(
                phase: BackupPhase.uploading,
                processed: 20,
                total: 20,
              ),
            );
            return 42;
          },
        );
      });
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 5));
      expect(result, isNull);
      expect(find.text('Backup completed with skipped items'), findsOneWidget);
      expect(
        find.text(
          'Unreadable files or directories skipped: 2. They are not included in this backup.',
        ),
        findsOneWidget,
      );
      expect(
        find.text('sessions/chat/outputs/locked.docx\nupload/locked'),
        findsOneWidget,
      );
      expect(find.text('Operation failed'), findsNothing);
      expect(find.text('Cancel'), findsNothing);
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      expect(result!.isSuccess, isTrue);
      expect(result!.value, 42);
    },
  );

  testWidgets('cancellation closes without a failure state', (tester) async {
    BackupTaskResult<void>? result;
    await _openDialog(tester, (context) async {
      result = await showBackupProgressDialog<void>(
        context,
        title: 'Import backup',
        task: (handle) async {
          await handle.cancelToken.whenCancelled;
          handle.cancelToken.throwIfCancelled();
        },
      );
    });
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(result!.cancelled, isTrue);
    expect(result!.error, isNull);
    expect(find.text('Operation failed'), findsNothing);
    expect(find.byType(TaskProgressDialogCard), findsNothing);
    expect(BackupActivity.isActive, isFalse);
  });
}
