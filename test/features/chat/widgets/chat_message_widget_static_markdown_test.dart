import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markstream/markstream.dart';
import 'package:provider/provider.dart';
import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/providers/tts_provider.dart';
import 'package:Kelivo/core/providers/user_provider.dart';
import 'package:Kelivo/features/chat/widgets/chat_message_widget.dart';
import 'package:Kelivo/features/home/services/ask_user_interaction_service.dart';
import 'package:Kelivo/features/home/services/tool_approval_service.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/markdown/markdown_with_code_highlight.dart';
import '../../../support/business_test_harness.dart';
import '../../../support/markdown_render_helpers.dart';

void main() {
  for (final platform in [TargetPlatform.macOS, TargetPlatform.android]) {
    for (final translation in [false, true]) {
      testWidgets(
        'static ${translation ? "translation" : "user"} uses markstream on $platform',
        (tester) async {
          final settings = SettingsProvider(createBusinessTestPreferences());
          await settings.loaded;
          addTearDown(settings.dispose);
          final source = ValueNotifier('# Heading\n\n**body** with `code`');
          addTearDown(source.dispose);
          await tester.pumpWidget(
            MultiProvider(
              providers: [
                ChangeNotifierProvider.value(value: settings),
                ChangeNotifierProvider(
                  create: (_) => UserProvider(
                    preferences: createBusinessTestPreferences(),
                  ),
                ),
                ChangeNotifierProvider(
                  create: (_) =>
                      TtsProvider(preferences: createBusinessTestPreferences()),
                ),
                ChangeNotifierProvider(create: (_) => ToolApprovalService()),
                ChangeNotifierProvider(
                  create: (_) => AskUserInteractionService(),
                ),
              ],
              child: MaterialApp(
                theme: ThemeData(platform: platform),
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                home: Scaffold(
                  body: SingleChildScrollView(
                    child: ValueListenableBuilder<String>(
                      valueListenable: source,
                      builder: (_, value, _) => ChatMessageWidget(
                        message: ChatMessage(
                          id: 'static',
                          role: translation ? 'assistant' : 'user',
                          content: translation ? '' : value,
                          translation: translation ? value : null,
                          conversationId: 'static-conversation',
                        ),
                        showModelIcon: false,
                        showUserAvatar: false,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final view = find.byType(MarkstreamView);
          expect(view, findsOneWidget);
          final state = tester.state(view);
          expect(tester.widget<MarkstreamView>(view).source, source.value);
          expect(
            markdownParagraph(tester, 'Heading').text.toPlainText(),
            'Heading',
          );
          expect(find.byType(InlineCodeCapsule), findsOneWidget);
          source.value += '\n\nUpdated body';
          await tester.pumpAndSettle();
          expect(tester.state(view), same(state));
          expect(
            markdownParagraph(tester, 'Updated body').text.toPlainText(),
            'Updated body',
          );
          expect(
            tester
                .widget<MarkdownWithCodeHighlight>(
                  find.byType(MarkdownWithCodeHighlight),
                )
                .conversationId,
            'static-conversation',
          );
          if (translation) {
            await settings.setEnableAssistantMarkdown(false);
          } else {
            await settings.setEnableUserMarkdown(false);
          }
          await tester.pumpAndSettle();
          expect(view, findsNothing);
          expect(find.text(source.value), findsOneWidget);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
        },
        variant: TargetPlatformVariant.only(platform),
      );
    }
  }
}
