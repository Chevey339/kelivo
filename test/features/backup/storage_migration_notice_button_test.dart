import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/database/private_data_storage.dart';
import 'package:Kelivo/features/backup/widgets/storage_migration_notice_button.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/widgets/restore_outcome_notice.dart';

const _title = 'Chat database moved to internal storage';

Widget _testApp(Directory directory) => MaterialApp(
  locale: const Locale('en'),
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  home: RestoreOutcomeNotice(
    outcome: null,
    child: Scaffold(
      appBar: AppBar(
        actions: [StorageMigrationNoticeButton(dataDirectory: directory)],
      ),
      body: const Text('backup page'),
    ),
  ),
);

Future<void> _mount(WidgetTester tester, Directory directory) async {
  await tester.pumpWidget(_testApp(directory));
  // Wait for real filesystem I/O before asserting visibility.
  final read = tester
      .widget<FutureBuilder<bool>>(find.byType(FutureBuilder<bool>))
      .future!;
  var readCompleted = false;
  read.then((_) => readCompleted = true);
  for (var i = 0; i < 100 && !readCompleted; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump();
  }
  expect(readCompleted, isTrue);
  await tester.pumpAndSettle();
}

void main() {
  late Directory directory;
  late File notice;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('kelivo-storage-notice-');
    notice = File('${directory.path}/${PrivateDataStorage.noticeName}');
  });
  tearDown(() async => directory.delete(recursive: true));

  testWidgets('does not show an icon without a pending migration notice', (
    tester,
  ) async {
    await _mount(tester, directory);

    expect(find.byTooltip(_title), findsNothing);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('opens only on demand and keeps unread notice across visits', (
    tester,
  ) async {
    await tester.runAsync(() => notice.writeAsString('pending'));
    await _mount(tester, directory);

    expect(find.byTooltip(_title), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
    expect(notice.existsSync(), isTrue);

    await tester.pumpWidget(const SizedBox.shrink());
    await _mount(tester, directory);
    expect(find.byTooltip(_title), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);

    await tester.tap(find.byTooltip(_title));
    await tester.pumpAndSettle();
    expect(find.text(_title), findsOneWidget);
    expect(
      find.textContaining(
        'Snapshots, images and attachments remain accessible in the Files app',
      ),
      findsOneWidget,
    );
    expect(notice.existsSync(), isTrue);

    // Dismissing without acknowledgement must not consume the pending notice.
    Navigator.of(tester.element(find.byType(AlertDialog))).pop();
    await tester.pumpAndSettle();
    expect(find.byTooltip(_title), findsOneWidget);
    expect(notice.existsSync(), isTrue);
  });

  testWidgets('acknowledgement hides the icon persistently and keeps data', (
    tester,
  ) async {
    final database = File('${directory.path}/kelivo.db');
    final snapshot = File('${directory.path}/snapshots/old.zip');
    await tester.runAsync(() async {
      await notice.writeAsString('pending');
      await database.writeAsString('original database');
      await snapshot.parent.create();
      await snapshot.writeAsString('original snapshot');
    });
    await _mount(tester, directory);
    await tester.tap(find.byTooltip(_title));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    for (
      var i = 0;
      i < 100 &&
          (notice.existsSync() || find.byTooltip(_title).evaluate().isNotEmpty);
      i++
    ) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
    }
    await tester.pumpAndSettle();

    expect(notice.existsSync(), isFalse);
    expect(find.byTooltip(_title), findsNothing);
    expect(find.byType(AlertDialog), findsNothing);
    expect(database.readAsStringSync(), 'original database');
    expect(snapshot.readAsStringSync(), 'original snapshot');

    await tester.pumpWidget(const SizedBox.shrink());
    await _mount(tester, directory);
    expect(find.byTooltip(_title), findsNothing);
    expect(find.byType(AlertDialog), findsNothing);
  });
}
