import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/widgets/restore_cold_restart_screen.dart';

void main() {
  testWidgets('blocks business UI and keeps restart retry visible on failure', (
    tester,
  ) async {
    final reportedErrors = <FlutterErrorDetails>[];
    final previousOnError = FlutterError.onError;
    FlutterError.onError = reportedErrors.add;
    addTearDown(() => FlutterError.onError = previousOnError);
    var attempts = 0;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: RestoreColdRestartScreen(
          restart: () async {
            attempts++;
            throw StateError('injected_restart_failure');
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('One more restart is required'), findsOneWidget);
    expect(find.text('business ready'), findsNothing);

    await tester.tap(find.text('Restart Kelivo'));
    await tester.pumpAndSettle();

    expect(attempts, 1);
    expect(reportedErrors, hasLength(1));
    expect(
      find.text(
        'Kelivo could not restart automatically. Fully close it, then open it again.',
      ),
      findsOneWidget,
    );
    expect(find.text('Restart Kelivo'), findsOneWidget);
  });
}
