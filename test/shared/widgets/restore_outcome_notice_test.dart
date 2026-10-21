import 'dart:io';
import 'package:flutter/material.dart';
import 'package:Kelivo/core/database/private_data_storage.dart';
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

  testWidgets(
    'explains protected storage and retains the notice until acknowledged',
    (tester) async {
      final directory = (await tester.runAsync(() async {
        final root = await Directory.systemTemp.createTemp(
          'kelivo-storage-notice-',
        );
        await File(
          '${root.path}/${PrivateDataStorage.noticeName}',
        ).writeAsString('pending');
        return root;
      }))!;
      addTearDown(() async => directory.delete(recursive: true));
      final notice = File('${directory.path}/${PrivateDataStorage.noticeName}');
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: RestoreOutcomeNotice(
            outcome: null,
            dataDirectory: directory,
            child: const Scaffold(body: Text('business ready')),
          ),
        ),
      );
      for (
        var i = 0;
        i < 100 &&
            find
                .text('Chat database moved to internal storage')
                .evaluate()
                .isEmpty;
        i++
      ) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump();
      }
      expect(
        find.text('Chat database moved to internal storage'),
        findsOneWidget,
      );
      expect(
        find.textContaining(
          'Snapshots, images and attachments remain accessible in the Files app',
        ),
        findsOneWidget,
      );
      expect(await tester.runAsync(() => notice.exists()), isTrue);
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      for (var i = 0; i < 100 && notice.existsSync(); i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump();
      }
      expect(notice.existsSync(), isFalse);
    },
  );
  testWidgets('does not interrupt a committed startup', (tester) async {
    await tester.pumpWidget(_testApp(RestoreReceiptState.committed));
    await tester.pumpAndSettle();

    expect(find.text('Restore was rolled back'), findsNothing);
    expect(find.text('business ready'), findsOneWidget);
  });
}
