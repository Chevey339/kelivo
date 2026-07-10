import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/widgets/restart_app_action.dart';
import 'package:Kelivo/shared/widgets/snackbar.dart';

void main() {
  testWidgets('reports restart failure and keeps the retry dialog open', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        builder: (context, child) => AppSnackBarOverlay(child: child!),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () {
                showDialog<void>(
                  context: context,
                  barrierDismissible: false,
                  builder: (dialogContext) => AlertDialog(
                    title: const Text('Restart prompt'),
                    actions: [
                      TextButton(
                        onPressed: () async {
                          if (await requestAppRestart(dialogContext, () async {
                                throw StateError('injected_restart_failure');
                              }) &&
                              dialogContext.mounted) {
                            Navigator.of(dialogContext).pop();
                          }
                        },
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    final reportedErrors = <FlutterErrorDetails>[];
    final previousOnError = FlutterError.onError;
    FlutterError.onError = reportedErrors.add;
    try {
      await tester.tap(find.text('Retry'));
      await tester.pump();
    } finally {
      FlutterError.onError = previousOnError;
    }

    expect(reportedErrors, hasLength(1));
    expect(find.text('Restart prompt'), findsOneWidget);
    expect(
      find.text(
        'Kelivo could not restart automatically. Fully close it, then open it again.',
      ),
      findsOneWidget,
    );
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
  });
}
