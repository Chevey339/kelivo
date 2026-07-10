import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/services/backup/restore_receipt.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/widgets/restore_outcome_notice.dart';

Widget _testApp(RestoreReceiptState? outcome) {
  return MaterialApp(
    locale: const Locale('en'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    home: RestoreOutcomeNotice(
      outcome: outcome,
      child: const Scaffold(body: Text('business ready')),
    ),
  );
}

void main() {
  testWidgets('requires acknowledgement after an automatic rollback', (
    tester,
  ) async {
    await tester.pumpWidget(_testApp(RestoreReceiptState.rolledBack));
    await tester.pumpAndSettle();

    expect(find.text('Restore was rolled back'), findsOneWidget);
    expect(
      find.text(
        'The restore could not be completed. Kelivo verified and kept your previous data.',
      ),
      findsOneWidget,
    );
    expect(find.text('business ready'), findsOneWidget);

    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(find.text('Restore was rolled back'), findsNothing);
    expect(find.text('business ready'), findsOneWidget);
  });

  testWidgets('does not interrupt a committed startup', (tester) async {
    await tester.pumpWidget(_testApp(RestoreReceiptState.committed));
    await tester.pumpAndSettle();

    expect(find.text('Restore was rolled back'), findsNothing);
    expect(find.text('business ready'), findsOneWidget);
  });
}
