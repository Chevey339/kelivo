import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import '../../../support/business_test_harness.dart';
import 'package:Kelivo/core/models/request_budget.dart';
import 'package:Kelivo/features/provider/widgets/request_budget_settings.dart';
import 'package:Kelivo/l10n/app_localizations.dart';

void main() {
  late SettingsProvider settings;
  setUp(() async {
    settings = SettingsProvider(createBusinessTestPreferences());
    await settings.loaded;
  });
  tearDown(() => settings.dispose());
  Future<void> open(
    WidgetTester tester, {
    Size size = const Size(390, 844),
    RequestBudgetOverrides initial = const RequestBudgetOverrides(),
    required ValueChanged<RequestBudgetOverrides> save,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: settings,
        child: MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: RequestBudgetRow(
              value: initial,
              inherited: const RequestBudget(imageCount: 60),
              modelOverride: true,
              onChanged: (value) async => save(value),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('图片与请求预算'));
    await tester.pumpAndSettle();
  }

  Finder field(int index) => find.descendant(
    of: find.byKey(ValueKey('request-budget-$index')),
    matching: find.byType(TextField),
  );

  testWidgets(
    'mobile editor validates input and keeps blank fields inherited',
    (tester) async {
      RequestBudgetOverrides? saved;
      await open(tester, save: (value) => saved = value);
      expect(find.textContaining('留空继承'), findsOneWidget);
      expect(tester.widget<TextField>(field(2)).decoration!.hintText, '60');
      await tester.enterText(field(0), '5.5');
      await tester.enterText(field(2), '-1');
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();
      expect(saved, isNull);
      expect(find.textContaining('请输入正数'), findsOneWidget);
      await tester.enterText(field(2), '1.5');
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();
      expect(saved, isNull);
      await tester.enterText(field(2), '100');
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();
      expect(saved!.singleImageBytes, (5.5 * RequestBudget.mib).round());
      expect(saved!.imageCount, 100);
      expect(saved!.bodyBytes, isNull);
      expect(saved!.totalImageBytes, isNull);
      expect(tester.takeException(), isNull);
    },
  );

  for (final size in [const Size(320, 568), const Size(1200, 800)]) {
    testWidgets('reset restores inheritance at $size', (tester) async {
      RequestBudgetOverrides? saved;
      await open(
        tester,
        size: size,
        initial: const RequestBudgetOverrides(
          imageCount: 100,
          bodyBytes: 64 * RequestBudget.mib,
        ),
        save: (value) => saved = value,
      );
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('恢复默认'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();
      expect(saved!.isEmpty, isTrue);
      expect(tester.takeException(), isNull);
    });
  }
}
