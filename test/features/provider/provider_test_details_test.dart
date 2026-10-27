import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:Kelivo/features/provider/utils/provider_test_failure.dart';
import 'package:Kelivo/features/provider/widgets/provider_test_details.dart';
import 'package:Kelivo/l10n/app_localizations.dart';

void main() {
  test('HTTP failure keeps status and reason separate from server detail', () {
    final failure = ProviderTestFailure(
      const HttpException('HTTP 404 Not Found: no such endpoint'),
    );
    expect(failure.statusCode, 404);
    expect(failure.summary, '404 Not Found');
    expect(failure.detail, contains('no such endpoint'));
    expect(
      ProviderTestFailure(
        const HttpException('HTTP 401: unauthorized'),
      ).summary,
      '401',
    );
    expect(
      ProviderTestFailure(
        const SocketException('Connection refused'),
      ).statusCode,
      isNull,
    );
  });
  for (final (base, code, suggested) in [
    ('https://example.com', 404, true),
    ('https://example.com/openai', 404, true),
    ('https://example.com/api/v3', 404, false),
    ('https://example.com/api/paas/v4', 404, false),
    ('https://example.com/v1beta', 404, false),
    ('https://example.com', 401, false),
  ]) {
    testWidgets(
      '$code $base only suggests a missing version for an unversioned 404',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('en'),
            home: Scaffold(
              body: ProviderTestDetails(
                requestUrl: '$base/chat/completions',
                baseUrl: base,
                failure: ProviderTestFailure(
                  HttpException('HTTP $code Not Found: missing'),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('$base/chat/completions'), findsOneWidget);
        expect(
          find.textContaining('The URL may be missing a version'),
          suggested ? findsOneWidget : findsNothing,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
  for (final (base, request) in [
    (
      'https://gateway.example.com',
      'https://gateway.example.com/v1/chat/completions',
    ),
    (
      'https://aiplatform.googleapis.com',
      'https://aiplatform.googleapis.com/v1/projects/demo/locations/global/publishers/google/models/missing-model:generateContent',
    ),
  ]) {
    testWidgets('404 respects the version already present in $request', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: Scaffold(
            body: ProviderTestDetails(
              requestUrl: request,
              baseUrl: base,
              failure: ProviderTestFailure(
                const HttpException('HTTP 404 Not Found: model missing'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.textContaining('The URL may be missing a version'),
        findsNothing,
      );
    });
  }
  testWidgets('successful test details have no error suggestion', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(
          body: ProviderTestDetails(
            requestUrl: 'https://example.com/v1/responses',
            baseUrl: 'https://example.com/v1',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('https://example.com/v1/responses'), findsOneWidget);
    expect(
      find.textContaining('The URL may be missing a version'),
      findsNothing,
    );
  });
}
