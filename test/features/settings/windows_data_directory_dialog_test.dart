import 'dart:io';

import 'package:Kelivo/core/services/app_exit_flush.dart';
import 'package:Kelivo/core/services/storage/windows_data_directory.dart';
import 'package:Kelivo/features/settings/widgets/windows_data_directory_tile.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory root, source, target;
  late WindowsDataDirectory storage;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('kelivo-directory-widget-');
    root = Directory(await root.resolveSymbolicLinks());
    source = await Directory(p.join(root.path, 'source')).create();
    target = await Directory(p.join(root.path, 'target')).create();
    storage = WindowsDataDirectory(supportDirectory: source);
    await storage.initialize();
  });

  tearDown(() async {
    AppExitFlush.debugReset();
    await storage.close();
    await root.delete(recursive: true);
  });

  Future<void> mount(
    WidgetTester tester, {
    Future<void> Function()? restart,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Scaffold(
          body: Center(
            child: WindowsDataDirectoryDialog(
              storage: storage,
              pickDirectory: () async => target.path,
              restart: restart,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> settleIo(WidgetTester tester) async {
    for (var i = 0; i < 300; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump();
      if (find.byType(LinearProgressIndicator).evaluate().isEmpty) {
        await tester.pumpAndSettle();
        return;
      }
    }
    fail('directory operation did not finish');
  }

  testWidgets(
    'choose schedules restart and cancel restores the original choice',
    (tester) async {
      await mount(tester);
      expect(find.text(source.path), findsOneWidget);
      await tester.tap(find.text('Change directory'));
      await settleIo(tester);
      expect(find.text(target.path), findsOneWidget);
      expect(find.text('Restart and move data'), findsOneWidget);
      expect((await storage.state).pending!.path, target.path);
      expect(
        (await tester.runAsync(() => storage.directory))!.path,
        source.path,
      );
      await tester.ensureVisible(
        find.text('Cancel move and keep original directory'),
      );
      await tester.tap(find.text('Cancel move and keep original directory'));
      await settleIo(tester);
      expect(find.text('Change directory'), findsOneWidget);
      expect(find.text(target.path), findsNothing);
      expect((await storage.state).pending, isNull);
    },
  );

  testWidgets('nonempty destination shows an error without scheduling a move', (
    tester,
  ) async {
    await tester.runAsync(
      () => File(p.join(target.path, 'keep.txt')).writeAsString('keep'),
    );
    await mount(tester);
    await tester.tap(find.text('Change directory'));
    await settleIo(tester);
    expect(
      find.text(
        'Choose an empty folder. Existing files will not be overwritten.',
      ),
      findsOneWidget,
    );
    expect((await storage.state).pending, isNull);
    expect(find.text('Restart and move data'), findsNothing);
  });

  testWidgets(
    'restart flushes pending writes before requesting process restart',
    (tester) async {
      await tester.runAsync(() => storage.schedule(target));
      final order = <String>[];
      AppExitFlush.register(() async => order.add('flush'));
      await mount(tester, restart: () async => order.add('restart'));
      await tester.tap(find.text('Restart and move data'));
      await settleIo(tester);
      expect(order, ['flush', 'restart']);
      expect((await storage.state).pending, isNotNull);
    },
  );
}
