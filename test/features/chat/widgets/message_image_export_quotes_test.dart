import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/core/models/message_part.dart';
import 'package:Kelivo/core/models/quote_ref.dart';
import 'package:Kelivo/core/providers/assistant_provider.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/providers/user_provider.dart';
import 'package:Kelivo/features/chat/widgets/message_export_sheet.dart';
import 'package:Kelivo/features/chat/widgets/quote_chip.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/widgets/export_capture_scope.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../../../support/business_test_harness.dart';

void main() {
  for (final bubble in [true, false]) {
    for (final locale in [const Locale('en'), const Locale('zh')]) {
      for (final code in [false, true]) {
        testWidgets(
          'image export preserves inline quote identities: bubble=$bubble locale=$locale code=$code',
          (tester) async {
            final preferences = createBusinessTestPreferences();
            final settings = SettingsProvider(preferences);
            await settings.loaded;
            addTearDown(settings.dispose);
            final quotes = [
              for (var i = 0; i < 2; i++)
                QuoteRef(
                  id: 'q$i',
                  messageId: 'source$i',
                  start: 0,
                  end: 40,
                  text: i == 0
                      ? 'https://www.gstatic.com/generate_204'
                      : 'A second original source retained in full',
                  model: 'Model',
                  createdAt: DateTime(2026),
                ),
            ];
            // The long word exercises export-only soft-break insertion before
            // placeholders; code uses the renderer's literal-span path.
            final source = code
                ? '${'a' * 80}\n\n`call(\uFFFC)`\n\n```text\nvalue \uFFFC\n```'
                : 'Before \uFFFC after \uFFFC.';
            final message = ChatMessage(
              id: 'reply',
              conversationId: 'c',
              role: 'user',
              parts: [
                TextPart(source),
                const FilePart(
                  uri: '/tmp/report.txt',
                  name: 'report.txt',
                  mime: 'text/plain',
                ),
              ],
              quotes: quotes,
            );
            final stored = message.toJson();
            await tester.pumpWidget(
              MultiProvider(
                providers: [
                  ChangeNotifierProvider.value(value: settings),
                  ChangeNotifierProvider(
                    create: (_) => AssistantProvider(preferences: preferences),
                  ),
                  ChangeNotifierProvider(
                    create: (_) => UserProvider(preferences: preferences),
                  ),
                ],
                child: MaterialApp(
                  locale: locale,
                  localizationsDelegates:
                      AppLocalizations.localizationsDelegates,
                  supportedLocales: AppLocalizations.supportedLocales,
                  home: Scaffold(
                    body: SingleChildScrollView(
                      child: ExportCaptureScope(
                        enabled: true,
                        child: buildExportedMessageCardForTesting(
                          message,
                          conversationBubble: bubble,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
            final tokens = tester.widgetList<QuoteChip>(find.byType(QuoteChip));
            expect(tokens.map((token) => token.quote).toList(), quotes);
            expect(tokens.every((token) => token.onRemove == null), isTrue);
            final renderedText = tester
                .widgetList<RichText>(find.byType(RichText))
                .map((text) => text.text.toPlainText())
                .join('\n');
            expect(renderedText, isNot(contains('[引用1]')));
            expect(renderedText, isNot(contains('[Quote 1]')));
            expect(renderedText, contains('report.txt'));
            expect(message.toJson(), stored);
            await tester.pumpWidget(const SizedBox.shrink());
          },
          variant: TargetPlatformVariant({
            TargetPlatform.macOS,
            TargetPlatform.iOS,
          }),
        );
      }
    }
  }
}
