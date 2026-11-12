import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/desktop/desktop_settings_page.dart';
import 'package:Kelivo/features/provider/pages/provider_balance_page.dart';
import 'package:Kelivo/features/provider/pages/provider_detail_page.dart';
import 'package:Kelivo/features/provider/widgets/provider_balance_badge.dart';
import 'package:Kelivo/features/provider/widgets/provider_balance_request_editor.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/widgets/segmented_tabs.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../../support/business_test_harness.dart';

void main() {
  for (final desktop in [false, true]) {
    for (final kind in ProviderKind.values) {
      testWidgets(
        '${desktop ? 'desktop' : 'mobile'} ${kind.name} balance entry, edit, reopen and reset',
        (tester) async {
          tester.view.physicalSize = desktop
              ? const Size(1000, 900)
              : const Size(390, 844);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          late SettingsProvider settings;
          await tester.runAsync(() async {
            final harness = await createBusinessTestHarness();
            settings = SettingsProvider(harness.preferences);
            await settings.loaded;
            await settings.setProviderConfig(
              'BalanceTest',
              ProviderConfig(
                id: 'BalanceTest',
                name: 'Balance Test',
                enabled: false,
                apiKey: 'test-key',
                baseUrl: 'https://example.test/v1',
                providerType: kind,
                balanceEnabled: true,
                customHeaders: const [
                  {'name': 'X-Chat', 'value': 'chat-only'},
                ],
              ),
            );
          });
          addTearDown(settings.dispose);

          Widget page() => ChangeNotifierProvider.value(
            value: settings,
            child: MaterialApp(
              locale: const Locale('en'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: desktop
                  ? const Scaffold(
                      body: DesktopProviderDetailPane(
                        providerKey: 'BalanceTest',
                        displayName: 'Balance Test',
                      ),
                    )
                  : const ProviderDetailPage(
                      keyName: 'BalanceTest',
                      displayName: 'Balance Test',
                    ),
            ),
          );

          Future<void> tap(Finder finder) async {
            await tester.ensureVisible(finder);
            await tester.tap(finder);
            await tester.pumpAndSettle();
          }

          Future<void> enter(Finder finder, String text) async {
            await tester.ensureVisible(finder);
            await tester.enterText(finder, text);
            await tester.pumpAndSettle();
          }

          final settingsButton = find.byKey(
            const ValueKey('desktop-provider-settings-BalanceTest'),
          );
          Future<void> openSettings() async {
            if (desktop) {
              await tap(settingsButton);
            }
            expect(
              find.text('Send Conversation Cache Key'),
              kind == ProviderKind.openai ? findsOneWidget : findsNothing,
            );
            if (!desktop) {
              await tap(find.text('Get account balance'));
              expect(find.byType(ProviderBalancePage), findsOneWidget);
            }
          }

          await tester.pumpWidget(page());
          await tester.pumpAndSettle();
          expect(find.byType(ProviderBalanceBadge), findsOneWidget);
          await openSettings();

          final editor = find.byType(ProviderBalanceRequestEditor);
          Finder inEditor(String key) =>
              find.descendant(of: editor, matching: find.byKey(ValueKey(key)));
          final method = inEditor('provider-balance-method');
          final body = find.descendant(
            of: inEditor('provider-balance-body'),
            matching: find.byType(TextField),
          );
          final headerName = inEditor('provider-custom-header-name-0');
          final headerValue = inEditor('provider-custom-header-value-0');
          final apiPath = find.byKey(
            const ValueKey('provider-balance-api-path'),
          );
          final resultPath = find.byKey(
            const ValueKey('provider-balance-result-path'),
          );

          expect(tester.widget<SegmentedTabs>(method).index, 0);
          expect(body, findsNothing);
          await enter(apiPath, 'https://example.test/api/check-balance');
          await tap(find.descendant(of: method, matching: find.text('POST')));
          await tap(inEditor('provider-custom-header-add'));
          await enter(headerName, 'x-api-key');
          await enter(headerValue, '{{apiKey}}');
          await enter(body, '{"api_key":"{{apiKey}}","account":"main"}');
          await enter(resultPath, 'usd_balance');

          var config = settings.getProviderConfig('BalanceTest');
          expect(config.balanceMethod, 'POST');
          expect(config.balanceHeaders, [
            {'name': 'x-api-key', 'value': '{{apiKey}}'},
          ]);
          expect(
            config.balanceBody,
            '{"api_key":"{{apiKey}}","account":"main"}',
          );
          expect(config.balanceResultPath, 'usd_balance');
          expect(config.providerType, kind);
          expect(config.customHeaders, [
            {'name': 'X-Chat', 'value': 'chat-only'},
          ]);

          // Some IMEs commit by clearing composing without changing the text.
          const imeBody = '{"api_key":"{{apiKey}}","account":"中文"}';
          await tester.ensureVisible(body);
          await tester.showKeyboard(body);
          final composing = TextEditingValue(
            text: imeBody,
            selection: TextSelection.collapsed(offset: imeBody.length - 2),
            composing: TextRange(
              start: imeBody.indexOf('中文'),
              end: imeBody.indexOf('中文') + 2,
            ),
          );
          tester.testTextInput.updateEditingValue(composing);
          await tester.pump();
          tester.testTextInput.updateEditingValue(
            composing.copyWith(composing: TextRange.empty),
          );
          await tester.pumpAndSettle();
          config = settings.getProviderConfig('BalanceTest');
          expect(config.balanceBody, imeBody);

          await tap(find.descendant(of: method, matching: find.text('GET')));
          expect(body, findsNothing);
          expect(
            settings.getProviderConfig('BalanceTest').balanceBody,
            config.balanceBody,
          );
          await tap(find.descendant(of: method, matching: find.text('POST')));
          Navigator.of(tester.element(method)).pop();
          await tester.pumpAndSettle();
          await openSettings();

          expect(tester.widget<SegmentedTabs>(method).index, 1);
          expect(
            tester.widget<TextField>(apiPath).controller!.text,
            config.balanceApiPath,
          );
          expect(
            tester.widget<TextField>(headerName).controller!.text,
            'x-api-key',
          );
          expect(
            tester.widget<TextField>(headerValue).controller!.text,
            '{{apiKey}}',
          );
          expect(
            tester.widget<TextField>(body).controller!.text,
            config.balanceBody,
          );
          await tap(inEditor('provider-custom-header-delete-0'));
          expect(
            settings.getProviderConfig('BalanceTest').balanceHeaders,
            isEmpty,
          );
          await tap(find.byTooltip('Reset balance settings'));
          config = settings.getProviderConfig('BalanceTest');
          expect(config.balanceEnabled, isFalse);
          expect(config.balanceMethod, 'GET');
          expect(config.balanceHeaders, isEmpty);
          expect(config.balanceBody, isEmpty);
          expect(config.providerType, kind);
          expect(config.customHeaders, [
            {'name': 'X-Chat', 'value': 'chat-only'},
          ]);
          await tap(find.byKey(const ValueKey('provider-balance-enabled')));
          expect(tester.widget<SegmentedTabs>(method).index, 0);
          expect(headerName, findsNothing);
          await tap(find.descendant(of: method, matching: find.text('POST')));
          expect(tester.widget<TextField>(body).controller!.text, isEmpty);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
          await tester.runAsync(() async => await settings.loaded);
        },
      );
    }
  }
}
