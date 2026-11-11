import 'package:Kelivo/core/models/provider_oauth.dart';
import 'package:Kelivo/features/provider/widgets/oauth_login_panel.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final (locale, stage, reason) in [
    (
      const Locale('en'),
      'Failed at: Requesting a device code',
      'DNS lookup failed.',
    ),
    (const Locale('zh'), '失败阶段：申请设备码', 'DNS 解析失败'),
    (
      const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans'),
      '失败阶段：申请设备码',
      'DNS 解析失败',
    ),
    (
      const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
      '失敗階段：申請裝置碼',
      'DNS 解析失敗',
    ),
  ]) {
    testWidgets('OAuth diagnostics are localized for $locale', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              body: Column(
                children: [
                  Text(
                    oauthErrorText(
                      context,
                      const ProviderOAuthException(
                        ProviderOAuthFailure.network,
                        stage: ProviderOAuthStage.requestDeviceCode,
                        transportFailure: ProviderOAuthTransportFailure.dns,
                      ),
                    ),
                  ),
                  Text(
                    oauthErrorText(
                      context,
                      const ProviderOAuthException(
                        ProviderOAuthFailure.requestRejected,
                        stage: ProviderOAuthStage.exchangeToken,
                        statusCode: 403,
                        code: 'access_denied',
                        message: 'Safe server explanation',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining(stage), findsOneWidget);
      expect(find.textContaining(reason), findsOneWidget);
      expect(find.textContaining('(dns)'), findsOneWidget);
      expect(find.textContaining('HTTP 403 / access_denied'), findsOneWidget);
      expect(find.textContaining('Safe server explanation'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
