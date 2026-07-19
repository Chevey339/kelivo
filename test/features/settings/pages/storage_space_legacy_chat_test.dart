import "../../../support/business_test_harness.dart";
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/database_v2_rollout_ledger.dart';
import 'package:Kelivo/features/settings/pages/storage_space_page.dart';
import 'package:Kelivo/l10n/app_localizations.dart';

class _FakePathProvider extends PathProviderPlatform {
  _FakePathProvider(this.root);

  final String root;

  @override
  Future<String?> getApplicationDocumentsPath() async => root;

  @override
  Future<String?> getApplicationSupportPath() async => root;

  @override
  Future<String?> getApplicationCachePath() async => p.join(root, 'cache');

  @override
  Future<String?> getTemporaryPath() async => p.join(root, 'tmp');
}

Future<void> _pumpUntilFound(WidgetTester tester, Finder finder) async {
  for (var attempt = 0; attempt < 40 && finder.evaluate().isEmpty; attempt++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump(const Duration(milliseconds: 50));
  }
  expect(
    finder,
    findsWidgets,
    reason: tester
        .widgetList<Text>(find.byType(Text))
        .map((widget) => widget.data)
        .whereType<String>()
        .join(' | '),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory root;
  late PathProviderPlatform previousPathProvider;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('kelivo_storage_legacy_ui_');
    previousPathProvider = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _FakePathProvider(root.path);
    SharedPreferences.setMockInitialValues({});
    await DatabaseV2RolloutLedger(root).recordMigrationCompleted(
      migrationRunId: 'hive-0123456789abcdef0123456789abcdef',
      sourceKind: 'hive',
      sourceHash: List.filled(64, 'a').join(),
      migratedAtUtc: DateTime.utc(2026, 7, 12),
      conversationCount: 2,
      messageCount: 4,
      issueCounts: const {},
    );
    await File(p.join(root.path, 'messages.hive')).writeAsString('legacy');
  });

  tearDown(() async {
    PathProviderPlatform.instance = previousPathProvider;
    if (await root.exists()) await root.delete(recursive: true);
  });

  testWidgets('old chat records expose a safe cleanup confirmation', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    try {
      await tester.pumpWidget(
        ChangeNotifierProvider(
          create: (_) => SettingsProvider(createBusinessTestPreferences()),
          child: const MaterialApp(
            locale: Locale('en'),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            home: StorageSpacePage(),
          ),
        ),
      );
      await _pumpUntilFound(tester, find.text('Chat Records (Old)'));

      await tester.tap(find.text('Chat Records (Old)').last);
      await _pumpUntilFound(tester, find.text('Clear Old Chat Records'));

      await tester.tap(find.text('Clear Old Chat Records'));
      await _pumpUntilFound(
        tester,
        find.textContaining('current SQLite chat records'),
      );
      expect(find.widgetWithText(TextButton, 'Clear'), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Cancel'), findsOneWidget);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}
