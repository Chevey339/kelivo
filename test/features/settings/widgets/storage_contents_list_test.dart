import '../../../support/business_test_harness.dart';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/storage/storage_usage_service.dart';
import 'package:Kelivo/features/settings/widgets/storage_contents_list.dart';
import 'package:Kelivo/features/workspace/widgets/files/file_browser.dart';
import 'package:Kelivo/l10n/app_localizations.dart';

void main() {
  late Directory root;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('storage_contents_ui_');
    SharedPreferences.setMockInitialValues({});
  });
  tearDown(() async {
    debugDefaultTargetPlatformOverride = null;
    await root.delete(recursive: true);
  });

  for (final platform in [TargetPlatform.android, TargetPlatform.macOS]) {
    testWidgets(
      '$platform session storage browses real files without a workspace binding',
      (tester) async {
        debugDefaultTargetPlatformOverride = platform;
        try {
          tester.view.physicalSize = Size(
            platform == TargetPlatform.android ? 420 : 1200,
            900,
          );
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          await tester.runAsync(() async {
            await Directory('${root.path}/attachments').create();
            await File(
              '${root.path}/attachments/报告.txt',
            ).writeAsString('report');
          });
          final category = StorageUsageCategory(
            key: StorageUsageCategoryKey.sessionFiles,
            stats: const StorageUsageStats(fileCount: 1, bytes: 6),
            subcategories: [
              StorageUsageSubcategory(
                id: 'conversation-a',
                path: root.path,
                isDirectory: true,
                stats: const StorageUsageStats(fileCount: 1, bytes: 6),
              ),
            ],
          );
          await tester.pumpWidget(
            ChangeNotifierProvider(
              create: (_) => SettingsProvider(createBusinessTestPreferences()),
              child: MaterialApp(
                locale: const Locale('en'),
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                home: Scaffold(
                  body: StorageContentsList(
                    category: category,
                    fmtBytes: (bytes) => '$bytes B',
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.text('6 B · 1 files'), findsOneWidget);
          await tester.tap(
            find.byKey(const ValueKey('storage-content-conversation-a')),
          );
          await _waitFor(
            tester,
            find.byKey(FileBrowser.itemKey('attachments')),
          );
          expect(find.byType(BottomSheet), findsNothing);
          final browser = tester.widget<FileBrowser>(find.byType(FileBrowser));
          expect(browser.root.path, root.path);
          await tester.tap(find.byKey(FileBrowser.itemKey('attachments')));
          await _waitFor(tester, find.byKey(FileBrowser.itemKey('报告.txt')));
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
          await tester.pumpAndSettle();
        } finally {
          debugDefaultTargetPlatformOverride = null;
        }
      },
    );
  }
}

Future<void> _waitFor(WidgetTester tester, Finder finder) async {
  for (var i = 0; i < 60 && finder.evaluate().isEmpty; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump(const Duration(milliseconds: 50));
  }
  expect(finder, findsOneWidget);
}
