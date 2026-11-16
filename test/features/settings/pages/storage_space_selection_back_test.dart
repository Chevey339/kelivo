import 'package:Kelivo/shared/widgets/ios_tile_button.dart';
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:provider/provider.dart';

import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/features/settings/pages/storage_space_page.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/widgets/snackbar.dart';

import '../../../support/business_test_harness.dart';

class _GatedPathProvider extends PathProviderPlatform {
  _GatedPathProvider(this.root);

  final String root;
  Completer<void>? documentsGate;
  int gatedReads = 0;

  @override
  Future<String?> getApplicationDocumentsPath() async {
    final gate = documentsGate;
    if (gate != null) {
      gatedReads++;
      await gate.future;
    }
    return root;
  }

  @override
  Future<String?> getApplicationSupportPath() async => root;

  @override
  Future<String?> getApplicationCachePath() async => '$root/cache';

  @override
  Future<String?> getTemporaryPath() async => '$root/tmp';
}

Future<void> _pumpUntil(WidgetTester tester, bool Function() ready) async {
  for (var i = 0; i < 500 && !ready(); i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump(const Duration(milliseconds: 50));
  }
  expect(ready(), isTrue);
}

Widget _storagePage() => ChangeNotifierProvider(
  create: (_) => SettingsProvider(createBusinessTestPreferences()),
  child: MaterialApp(
    locale: const Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    builder: (_, child) => AppSnackBarOverlay(child: child!),
    home: const StorageSpacePage(),
  ),
);

void main() {
  testWidgets(
    'reopening files while the previous directory walk is pending rechecks the inventory',
    (tester) async {
      tester.view.physicalSize = const Size(400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final root = Directory.systemTemp.createTempSync(
        'storage_directory_navigation_',
      );
      final previousPaths = PathProviderPlatform.instance;
      final paths = _GatedPathProvider(root.path);
      PathProviderPlatform.instance = paths;
      addTearDown(() {
        PathProviderPlatform.instance = previousPaths;
        root.deleteSync(recursive: true);
      });
      await tester.pumpWidget(_storagePage());
      await _pumpUntil(tester, () => find.text('Files').evaluate().isNotEmpty);
      // Settings startup also asks for Documents to clean logs. Finish that
      // lookup before measuring just the directory walks across navigation.
      var settingsReady = false;
      final settings = tester
          .element(find.byType(StorageSpacePage))
          .read<SettingsProvider>();
      settings.loaded.then((_) => settingsReady = true);
      await _pumpUntil(tester, () => settingsReady);
      final gate = paths.documentsGate = Completer<void>();
      addTearDown(() {
        if (!gate.isCompleted) gate.complete();
      });
      await tester.tap(find.text('Files').last);
      await _pumpUntil(tester, () => paths.gatedReads == 1);
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Files').last);
      await tester.pumpAndSettle();
      expect(paths.gatedReads, 1);
      gate.complete();
      // Neither category contains any files, so a second path lookup belongs
      // to the new directory walk, not a database reference check.
      await _pumpUntil(tester, () => paths.gatedReads == 2);
      await tester.pumpWidget(const SizedBox.shrink());
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets(
    'back and a new selection cannot change a confirmed file deletion',
    (tester) async {
      tester.view.physicalSize = const Size(400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final root = Directory.systemTemp.createTempSync('kelivo_delete_back_');
      final upload = Directory('${root.path}/upload')..createSync();
      final first = File('${upload.path}/first.txt')
        ..writeAsStringSync('first');
      final second = File('${upload.path}/second.txt')
        ..writeAsStringSync('second');
      final keep = File('${upload.path}/keep.txt')..writeAsStringSync('keep');
      final previousPaths = PathProviderPlatform.instance;
      final paths = _GatedPathProvider(root.path);
      PathProviderPlatform.instance = paths;
      addTearDown(() {
        PathProviderPlatform.instance = previousPaths;
        root.deleteSync(recursive: true);
      });
      await tester.pumpWidget(_storagePage());
      await _pumpUntil(tester, () => find.text('Files').evaluate().isNotEmpty);
      await tester.ensureVisible(find.text('Files').last);
      await tester.tap(find.text('Files').last);
      await _pumpUntil(tester, () => find.text('Unused').evaluate().isNotEmpty);
      await tester.pumpAndSettle();
      await tester.longPress(find.text('first.txt'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('second.txt'));
      await tester.pumpAndSettle();
      expect(find.text('2 selected'), findsOneWidget);
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      final gate = paths.documentsGate = Completer<void>();
      addTearDown(() {
        if (!gate.isCompleted) gate.complete();
      });
      await tester.tap(find.widgetWithText(IosTileButton, 'Delete').last);
      await tester.pumpAndSettle();
      expect(paths.gatedReads, greaterThan(0));
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Select all'), findsOneWidget);
      await tester.longPress(find.text('keep.txt'));
      await tester.pumpAndSettle();
      expect(find.text('1 selected'), findsOneWidget);

      gate.complete();
      await _pumpUntil(
        tester,
        () =>
            find.text('Deleted 2 items').evaluate().isNotEmpty ||
            !keep.existsSync(),
      );
      AppSnackBarManager().dismissAll();
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      expect(first.existsSync(), isFalse);
      expect(second.existsSync(), isFalse);
      expect(keep.readAsStringSync(), 'keep');
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );
}
