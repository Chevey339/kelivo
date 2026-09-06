import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:Kelivo/core/providers/environment_provider.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/features/workspace/pages/environment_variables_page.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/widgets/ios_settings_rows.dart';
import 'package:Kelivo/theme/theme_factory.dart';

import '../../../support/business_test_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('haptic_feedback'),
          (_) async => true,
        );
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('haptic_feedback'), null);
  });

  for (final platform in [
    TargetPlatform.android,
    TargetPlatform.iOS,
    TargetPlatform.macOS,
  ]) {
    testWidgets(
      'environment variables CRUD, visibility and privacy on $platform',
      (tester) async {
        late EnvironmentProvider env;
        await tester.runAsync(() async {
          env = EnvironmentProvider(
            preferences: createBusinessTestPreferences(),
          );
          await env.loaded;
        });
        tester.view.physicalSize = platform == TargetPlatform.macOS
            ? const Size(1100, 900)
            : const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
          env.dispose();
        });
        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider<EnvironmentProvider>.value(value: env),
              ChangeNotifierProvider(
                create: (_) =>
                    SettingsProvider(createBusinessTestPreferences()),
              ),
            ],
            child: MaterialApp(
              theme: buildLightTheme(null),
              locale: const Locale('zh'),
              supportedLocales: AppLocalizations.supportedLocales,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              home: Scaffold(
                body: Builder(
                  builder: (context) => TextButton(
                    onPressed: () => openEnvironmentVariablesPage(context),
                    child: const Text('open'),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();
        expect(find.text('隐私模式'), findsOneWidget);
        await tester.tap(
          find.byKey(const ValueKey('environment-variable-add')),
        );
        await tester.pumpAndSettle();
        expect(
          find.byType(BottomSheet),
          platform == TargetPlatform.macOS ? findsNothing : findsOneWidget,
        );
        final nameField = find.descendant(
          of: find.byKey(const ValueKey('environment-variable-name')),
          matching: find.byType(TextField),
        );
        final valueField = find.descendant(
          of: find.byKey(const ValueKey('environment-variable-value')),
          matching: find.byType(TextField),
        );
        expect(tester.widget<TextField>(valueField).obscureText, isFalse);
        await tester.enterText(nameField, 'API_KEY');
        await tester.enterText(valueField, 'private-token-123');
        await tester.runAsync(() async {
          await tester.tap(find.text('保存'));
          await env.preferences.flushPendingWrites();
          await Future<void>.delayed(const Duration(milliseconds: 100));
        });
        await tester.pumpAndSettle();
        expect(env.variables.single.value, 'private-token-123');
        expect(find.text('private-token-123'), findsNothing);
        final row = find.byKey(const ValueKey('environment-variable-API_KEY'));
        await tester.tap(
          find.descendant(of: row, matching: find.byTooltip('显示')),
        );
        await tester.pumpAndSettle();
        expect(find.text('private-token-123'), findsOneWidget);
        await tester.runAsync(() async {
          await tester.tap(
            find.byKey(const ValueKey('environment-privacy-mode')),
          );
          await Future<void>.delayed(const Duration(milliseconds: 100));
        });
        await tester.pumpAndSettle();
        expect(env.privacyMode, isFalse);
        await tester.tap(find.text('API_KEY'));
        await tester.pumpAndSettle();
        expect(tester.widget<TextField>(valueField).obscureText, isFalse);
        await tester.enterText(nameField, 'NEW_KEY');
        await tester.runAsync(() async {
          await tester.tap(find.text('保存'));
          await Future<void>.delayed(const Duration(milliseconds: 100));
        });
        await tester.pumpAndSettle();
        expect(env.variables.single.name, 'NEW_KEY');
        expect(find.text('private-token-123'), findsNothing);
        await tester.tap(find.text('NEW_KEY'));
        await tester.pumpAndSettle();
        await tester.runAsync(() async {
          await tester.tap(
            find.byKey(const ValueKey('environment-variable-delete')),
          );
          await Future<void>.delayed(const Duration(milliseconds: 100));
        });
        await tester.pumpAndSettle();
        expect(env.variables, isEmpty);
        expect(find.byType(IosNavRow), findsNothing);
        expect(tester.takeException(), isNull);
      },
      variant: TargetPlatformVariant.only(platform),
    );
  }
}
