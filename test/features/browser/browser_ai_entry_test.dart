import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:Kelivo/core/models/conversation.dart';
import 'package:Kelivo/core/models/assistant.dart';
import 'package:Kelivo/core/providers/assistant_provider.dart';
import 'package:Kelivo/core/services/browser/browser_service.dart';
import 'package:Kelivo/core/services/chat/chat_service.dart';
import 'package:Kelivo/core/services/notification_service.dart';
import 'package:Kelivo/features/browser/browser_ai_entry.dart';
import 'package:Kelivo/features/browser/models/browser_models.dart';
import 'package:Kelivo/features/home/services/local_tools_service.dart';
import 'package:Kelivo/l10n/app_localizations.dart';

class _EntryBrowser extends ChangeNotifier implements BrowserService {
  BrowserSettings configuration = const BrowserSettings(agentEnabled: false);
  @override
  BrowserSettings get settings => configuration;
  @override
  Future<void> initialize() async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _EntryAssistants extends ChangeNotifier implements AssistantProvider {
  Assistant current = const Assistant(
    id: 'browser-assistant',
    name: 'Browser assistant',
  );
  @override
  Assistant? resolveConversationAssistant(String? id) => current;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _EntryChat extends ChangeNotifier implements ChatService {
  _EntryChat(this.conversation);
  final Conversation conversation;
  @override
  Conversation? getConversation(String id) =>
      id == conversation.id ? conversation : null;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('standalone browser reports unavailable without app providers', (
    tester,
  ) async {
    late BuildContext context;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (value) {
            context = value;
            return const SizedBox();
          },
        ),
      ),
    );
    final browser = _EntryBrowser();
    expect(
      await requestBrowserAiDraft(
        context,
        browser: browser,
        conversationId: 'missing',
      ),
      BrowserAiEntryResult.unavailable,
    );
    expect(tester.takeException(), isNull);
    browser.dispose();
  });

  testWidgets(
    'entry respects both permissions and only prepares a navigation draft',
    (tester) async {
      final assistants = _EntryAssistants();
      final assistantId = assistants.current.id;
      final chat = _EntryChat(
        Conversation(
          id: 'browser-chat',
          title: 'Browser chat',
          assistantId: assistantId,
        ),
      );
      final browser = _EntryBrowser();
      late BuildContext context;
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            InheritedProvider<ChatService>.value(value: chat),
            InheritedProvider<AssistantProvider>.value(value: assistants),
          ],
          child: Localizations(
            locale: const Locale('en'),
            delegates: AppLocalizations.localizationsDelegates,
            child: Builder(
              builder: (value) {
                context = value;
                return const SizedBox();
              },
            ),
          ),
        ),
      );
      NotificationService.takePendingConversationId();
      expect(
        await requestBrowserAiDraft(
          context,
          browser: browser,
          conversationId: 'browser-chat',
        ),
        BrowserAiEntryResult.assistantToolDisabled,
      );
      expect(NotificationService.takePendingConversationId(), isNull);
      expect(browser.settings.agentEnabled, isFalse);
      assistants.current = assistants.current.copyWith(
        localToolIds: [LocalToolNames.browser],
      );
      expect(
        await requestBrowserAiDraft(
          context,
          browser: browser,
          conversationId: 'browser-chat',
        ),
        BrowserAiEntryResult.browserPermissionDisabled,
      );
      expect(NotificationService.takePendingConversationId(), isNull);
      browser.configuration = const BrowserSettings(agentEnabled: true);
      expect(
        await requestBrowserAiDraft(
          context,
          browser: browser,
          conversationId: 'browser-chat',
          tab: const BrowserTab(
            id: 'tab-a',
            url: 'https://user:secret@example.com/page',
          ),
        ),
        BrowserAiEntryResult.requested,
      );
      expect(NotificationService.takePendingConversationId(), 'browser-chat');
      final draft = NotificationService.takePendingComposerText(
        'browser-chat',
      )!;
      expect(draft, contains('https://example.com/page'));
      expect(draft, isNot(contains('secret')));
      expect(draft, contains('My request:'));
      browser.dispose();
      assistants.dispose();
      chat.dispose();
    },
    timeout: const Timeout(Duration(seconds: 20)),
  );
}
