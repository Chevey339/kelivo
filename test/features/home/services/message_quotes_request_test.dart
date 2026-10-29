import 'package:Kelivo/core/models/assistant.dart';
import 'package:Kelivo/core/models/chat_input_data.dart';
import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/core/models/compress_context_options.dart';
import 'package:Kelivo/core/models/conversation.dart';
import 'package:Kelivo/core/models/message_part.dart';
import 'package:Kelivo/core/models/quote_ref.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/chat/chat_service.dart';
import 'package:Kelivo/features/chat/widgets/message_export_sheet.dart';
import 'package:Kelivo/features/home/services/message_builder_service.dart';
import 'package:Kelivo/features/home/services/message_generation_service.dart';
import 'package:Kelivo/features/intelligent_ui/host/ui_copy_actions.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/widgets/snackbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../../support/business_test_harness.dart';

class _Chat extends ChatService {
  @override
  List<ChatMessage> getMessages(String id) => [];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final scenario in [
    (system: const Locale('en'), app: null, marker: '[Quote 1]'),
    (system: const Locale('zh'), app: const Locale('en'), marker: '[Quote 1]'),
    (system: const Locale('en'), app: const Locale('zh'), marker: '[引用1]'),
    (
      system: const Locale('en'),
      app: const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
      marker: '[引用1]',
    ),
  ]) {
    testWidgets(
      'quotes use UI locale throughout requests, compression, copy and export: $scenario',
      (tester) async {
        tester.platformDispatcher.localesTestValue = [scenario.system];
        addTearDown(tester.platformDispatcher.clearLocalesTestValue);
        final settings = SettingsProvider(createBusinessTestPreferences());
        addTearDown(settings.dispose);
        await settings.loaded;
        if (scenario.app case final locale?) {
          await settings.setAppLocale(locale);
        } else {
          await settings.setAppLocaleFollowSystem();
        }
        late BuildContext context;
        await tester.pumpWidget(
          MaterialApp(
            locale: settings.appLocaleForMaterialApp,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: Builder(
                builder: (value) {
                  context = value;
                  return const SizedBox.shrink();
                },
              ),
            ),
          ),
        );
        final l10n = AppLocalizations.of(context)!;
        final quote = QuoteRef(
          id: 'q',
          messageId: 'deleted-source',
          start: 3,
          end: 10,
          text: 'first line\nsecond line',
          model: 'model',
          createdAt: DateTime(2026),
        );
        final input = ChatInputData(
          text: 'Before \uFFFC after',
          quotes: [quote],
        );
        final parts =
            await MessageGenerationService.buildPersistedUserMessageParts(
              input,
              assistant: null,
            );
        expect((parts.single as TextPart).text, 'Before \uFFFC after');
        final message = ChatMessage(
          id: 'reply',
          conversationId: 'c',
          role: 'user',
          parts: parts,
          quotes: input.quotes,
        );
        final chat = _Chat();
        addTearDown(chat.dispose);
        final service = MessageBuilderService(
          chatService: chat,
          contextProvider: context,
        );
        final api = service.buildApiMessages(
          messages: [message],
          versionSelections: const {},
          currentConversation: Conversation(id: 'c', title: 'test'),
        );
        final marker = scenario.marker;
        final expected =
            '> $marker first line\n> second line\n\nBefore $marker after';
        expect(api.single['content'], expected);
        await service.processUserMessagesForApi(
          api,
          settings,
          const Assistant(id: 'a', name: 'test'),
          sourceMessages: [message],
          previewOnly: true,
        );
        expect(api.single['content'], expected);
        for (final mode in CompressContextLimitMode.values) {
          final text = buildCompressRequestContents(
            [message],
            CompressContextOptions(mode: mode, maxChars: 10000),
            quoteMarker: l10n.selectionQuoteMarker,
          ).join();
          expect(text, contains(expected));
          expect(text, isNot(contains(quotePlaceholder)));
        }
        for (final markdown in [true, false]) {
          final text = await exportMessageBlocksForTesting(
            message,
            showThinkingAndToolCards: false,
            markdown: markdown,
            locale: Localizations.localeOf(context),
          );
          expect(text, contains(expected));
        }
        String? copied;
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          (call) async {
            if (call.method == 'Clipboard.setData') {
              copied = (call.arguments as Map)['text'] as String;
            }
            return null;
          },
        );
        addTearDown(
          () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            SystemChannels.platform,
            null,
          ),
        );
        await copyUiMessage(context, message);
        expect(copied, expected);
        await copyUiMessageSource(context, message);
        expect(copied, expected);
        AppSnackBarManager().dismissAll();
        await tester.pump(const Duration(seconds: 4));
        await tester.pumpAndSettle();
        final edit = service.parseInputFromMessage(message);
        expect(edit.text, input.text);
        expect(edit.quotes, [quote]);
      },
    );
  }
}
