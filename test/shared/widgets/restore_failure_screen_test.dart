import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/widgets/restore_failure_screen.dart';

void main() {
  test('keeps only stable diagnostic codes', () {
    expect(
      restoreFailureDiagnosticCode(StateError('restore_startup_receipt')),
      'restore_startup_receipt',
    );
    expect(
      restoreFailureDiagnosticCode(StateError('/private/user path')),
      'StateError',
    );
    expect(
      restoreFailureDiagnosticCode(
        const FileSystemException(
          'denied',
          '/private/user',
          OSError('permission denied', 13),
        ),
      ),
      'filesystem_13',
    );
  });

  testWidgets('explains fail-closed startup without opening business UI', (
    tester,
  ) async {
    var restartCalls = 0;
    await tester.pumpWidget(
      MaterialApp(
        locale: Locale('en'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: RestoreFailureScreen(
          diagnosticCode: 'restore_startup_receipt',
          restart: () async => restartCalls++,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Restore requires attention'), findsOneWidget);
    expect(find.textContaining('chat data was not opened'), findsOneWidget);
    expect(
      find.text('Diagnostic code: restore_startup_receipt'),
      findsOneWidget,
    );
    expect(find.text('Restart Kelivo'), findsOneWidget);
    expect(find.text('Copy diagnostic code'), findsOneWidget);

    await tester.tap(find.text('Restart Kelivo'));
    await tester.pump();
    expect(restartCalls, 1);
  });

  testWidgets('explains an occupied business lease with a useful action', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: RestoreFailureScreen(
          diagnosticCode: 'RestoreBusinessLeaseUnavailable',
          restart: () async {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Kelivo is already running'), findsOneWidget);
    expect(find.textContaining('another app process'), findsOneWidget);
    expect(find.text('Restart Kelivo'), findsOneWidget);
  });
}
