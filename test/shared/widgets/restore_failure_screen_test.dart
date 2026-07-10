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
    await tester.pumpWidget(
      const MaterialApp(
        locale: Locale('en'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: RestoreFailureScreen(diagnosticCode: 'restore_startup_receipt'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Restore requires attention'), findsOneWidget);
    expect(find.textContaining('chat data was not opened'), findsOneWidget);
    expect(
      find.text('Diagnostic code: restore_startup_receipt'),
      findsOneWidget,
    );
  });
}
