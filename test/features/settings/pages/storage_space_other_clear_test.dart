import '../../../support/business_test_harness.dart';
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

Future<void> _writeSizedFile(Directory root, String name, int size) async {
  final file = File(p.join(root.path, name));
  await file.parent.create(recursive: true);
  await file.writeAsBytes(List<int>.filled(size, 1), flush: true);
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
    root = await Directory.systemTemp.createTemp('kelivo_storage_other_ui_');
    previousPathProvider = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _FakePathProvider(root.path);
    SharedPreferences.setMockInitialValues({});
    await _writeSizedFile(root, p.join('fonts', 'Custom.ttf'), 40);
    await _writeSizedFile(
      root,
      p.join('asr_models', 'paraformer-zh-small-2024-03-09', 'model.int8.onnx'),
      80,
    );
  });

  tearDown(() async {
    PathProviderPlatform.instance = previousPathProvider;
    if (await root.exists()) await root.delete(recursive: true);
  });

  testWidgets('other fonts and local models expose confirmed clear actions', (
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
      await _pumpUntilFound(tester, find.text('Other'));

      await tester.tap(find.text('Other').last);
      await _pumpUntilFound(tester, find.text('Fonts'));
      await _pumpUntilFound(tester, find.text('Local Models'));
      expect(find.text('Clear'), findsNWidgets(2));

      final fontsClear = find.ancestor(
        of: find.text('Clear').first,
        matching: find.byType(GestureDetector),
      );
      tester.widget<GestureDetector>(fontsClear).onTap?.call();
      await tester.pump();
      await _pumpUntilFound(tester, find.text('Clear Fonts?'));
      expect(find.widgetWithText(TextButton, 'Cancel'), findsOneWidget);

      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pump();
      expect(find.text('Clear Fonts?'), findsNothing);

      final modelsClear = find.ancestor(
        of: find.text('Clear').at(1),
        matching: find.byType(GestureDetector),
      );
      tester.widget<GestureDetector>(modelsClear).onTap?.call();
      await tester.pump();
      await _pumpUntilFound(tester, find.text('Clear Local Models?'));

      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pump();
      expect(find.text('Clear Local Models?'), findsNothing);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}
