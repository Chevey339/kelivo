import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/models/message_part.dart';
import 'package:Kelivo/features/chat/widgets/response_truncation_notice.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import '../../../support/business_test_harness.dart';

void main() {
  testWidgets(
    'context limit exposes an image-free retry and fits narrow layouts',
    (tester) async {
      var retries = 0;
      final settings = SettingsProvider(createBusinessTestPreferences());
      addTearDown(settings.dispose);
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: settings,
          child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 260,
                  child: ResponseTruncationNotice(
                    truncation: const ResponseTruncationPart(
                      inputTokens: 1042909,
                      contextWindow: 1048576,
                      hadImages: true,
                    ),
                    onRetryWithoutImages: () {
                      retries++;
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      expect(find.textContaining('1042909'), findsOneWidget);
      expect(find.textContaining('1048576'), findsOneWidget);
      await tester.tap(find.text('Retry without images (keep originals)'));
      expect(retries, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'unknown usage reports output limit without blaming the context',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(
            body: ResponseTruncationNotice(
              truncation: ResponseTruncationPart(),
            ),
          ),
        ),
      );
      expect(
        find.textContaining('output limit includes reasoning'),
        findsOneWidget,
      );
      expect(find.textContaining('context limit'), findsNothing);
      expect(find.text('Retry without images (keep originals)'), findsNothing);
    },
  );
}
