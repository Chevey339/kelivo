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
  for (final pinnedCount in [0, 2, 4]) {
    testWidgets(
      'mobile history preserves rows with $pinnedCount pinned chats',
      (tester) async {
        final chat = _Chat()
          ..ready = true
          ..conversations = [
            for (var i = 0; i < 4; i++)
              Conversation(
                id: '$i',
                title: 'Chat $i',
                isPinned: i < pinnedCount,
              ),
          ];
        addTearDown(chat.dispose);
        await tester.pumpWidget(
          ChangeNotifierProvider<ChatService>.value(
            value: chat,
            child: MaterialApp(
              theme: ThemeData(platform: TargetPlatform.android),
              locale: const Locale('en'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: const ChatHistoryPage(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final list = tester.widget<ListView>(find.byType(ListView));
        final delegate = list.childrenDelegate as SliverChildBuilderDelegate;
        expect(delegate.childCount, 4 + (pinnedCount > 0 ? 3 : 1));
        final context = tester.element(find.byType(ListView));
        var index = 0;
        if (pinnedCount > 0) {
          final header = delegate.builder(context, index++)! as Padding;
          expect(header.padding, const EdgeInsets.fromLTRB(4, 4, 4, 8));
        }
        for (var i = 0; i < 4; i++) {
          if (pinnedCount > 0 && i == pinnedCount) {
            expect((delegate.builder(context, index++)! as SizedBox).height, 8);
          }
          final row = delegate.builder(context, index++)! as Dismissible;
          expect(row.key, ValueKey('history-$i'));
          expect(row.direction, DismissDirection.endToStart);
          expect(row.onDismissed, isNotNull);
        }
        if (pinnedCount == 4) {
          expect((delegate.builder(context, index++)! as SizedBox).height, 8);
        }
        expect((delegate.builder(context, index)! as SizedBox).height, 8);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  testWidgets('pinning retains the state of an existing history row', (
    tester,
  ) async {
    final chat = _Chat()
      ..ready = true
      ..conversations = [
        Conversation(id: 'one', title: 'First'),
        Conversation(id: 'two', title: 'Second'),
      ];
    addTearDown(chat.dispose);
    await tester.pumpWidget(
      ChangeNotifierProvider<ChatService>.value(
        value: chat,
        child: MaterialApp(
          theme: ThemeData(platform: TargetPlatform.android),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const ChatHistoryPage(),
        ),
      ),
    );
    final row = find.byKey(const ValueKey('history-one'));
    final state = tester.state(row);
    chat.conversations = [
      chat.conversations.first,
      Conversation(id: 'two', title: 'Second', isPinned: true),
    ];
    chat.publish(changed: true);
    await tester.pumpAndSettle();
    expect(tester.state(row), same(state));
  });

  testWidgets(
    'mobile history builds distant conversations only after scrolling',
    (tester) async {
      final chat = _Chat()
        ..ready = true
        ..conversations = [
          for (var i = 0; i < 200; i++)
            Conversation(id: '$i', title: 'Chat $i'),
        ];
      addTearDown(chat.dispose);
      await tester.pumpWidget(
        ChangeNotifierProvider<ChatService>.value(
          value: chat,
          child: const MaterialApp(
            locale: Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: ChatHistoryPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Chat 0'), findsOneWidget);
      expect(find.text('Chat 199'), findsNothing);
      await tester.scrollUntilVisible(
        find.text('Chat 199'),
        500,
        maxScrolls: 100,
      );
      expect(find.text('Chat 199'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

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
