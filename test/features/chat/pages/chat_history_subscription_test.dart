import 'dart:async';
import 'package:Kelivo/core/models/conversation.dart';
import 'package:Kelivo/core/services/chat/chat_service.dart';
import 'package:Kelivo/desktop/chat_history_dialog.dart';
import 'package:Kelivo/features/chat/pages/chat_history_page.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

class _Chat extends ChatService {
  bool ready = false;
  int revision = 0;
  int reads = 0;
  List<Conversation> conversations = [];
  @override
  bool get initialized => ready;
  @override
  int get conversationListRevision => revision;
  @override
  List<Conversation> getAllConversations() {
    reads++;
    return conversations;
  }

  void publish({bool changed = false}) {
    if (changed) revision++;
    notifyListeners();
  }
}

void main() {
  for (final desktop in [false, true]) {
    testWidgets(
      '${desktop ? 'desktop' : 'mobile'} history observes list changes only',
      (tester) async {
        final chat = _Chat();
        addTearDown(chat.dispose);
        final navigator = GlobalKey<NavigatorState>();
        await tester.pumpWidget(
          ChangeNotifierProvider<ChatService>.value(
            value: chat,
            child: MaterialApp(
              navigatorKey: navigator,
              locale: const Locale('en'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: desktop
                  ? const Scaffold()
                  : const ChatHistoryPage(assistantId: 'a'),
            ),
          ),
        );
        if (desktop) {
          unawaited(
            showChatHistoryDesktopDialog(
              navigator.currentContext!,
              assistantId: 'a',
            ),
          );
        }
        await tester.pumpAndSettle();
        chat.conversations = [
          Conversation(id: 'one', title: 'First', assistantId: 'a'),
          Conversation(id: 'two', title: 'Excluded', assistantId: 'b'),
        ];
        chat.ready = true;
        chat.publish();
        await tester.pumpAndSettle();
        expect(find.text('First'), findsOneWidget);
        expect(find.text('Excluded'), findsNothing);
        chat.reads = 0;
        for (var i = 0; i < 5; i++) {
          chat.publish();
          await tester.pump();
        }
        expect(chat.reads, 0);
        chat.conversations = [
          Conversation(
            id: 'one',
            title: 'Renamed',
            assistantId: 'a',
            isPinned: true,
          ),
        ];
        chat.publish(changed: true);
        await tester.pumpAndSettle();
        expect(find.text('Renamed'), findsOneWidget);
        expect(find.text('First'), findsNothing);
        expect(chat.reads, 1);
        chat.conversations = [];
        chat.publish(changed: true);
        await tester.pumpAndSettle();
        expect(find.text('Renamed'), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}
