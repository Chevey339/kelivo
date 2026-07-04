import 'package:Cuplivo/core/models/chat_message.dart';
import 'package:Cuplivo/core/providers/settings_provider.dart';
import 'package:Cuplivo/core/providers/user_provider.dart';
import 'package:Cuplivo/features/chat/widgets/chat_message_widget.dart';
import 'package:Cuplivo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('用户消息附件显示在文本气泡上方且不在气泡内部', (tester) async {
    const messageId = 'user-with-attachments';

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => SettingsProvider()),
          ChangeNotifierProvider(create: (_) => UserProvider()),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: ChatMessageWidget(
              showUserAvatar: false,
              message: ChatMessage(
                id: messageId,
                role: 'user',
                content:
                    '请看这个\n[image:missing-user-image.png]\n[file:/tmp/spec.pdf|spec.pdf|application/pdf]',
                conversationId: 'conversation-user-attachments',
              ),
            ),
          ),
        ),
      ),
    );

    final bubbleFinder = find.byKey(
      const ValueKey('user-message-text-bubble:$messageId'),
    );
    final attachmentsFinder = find.byKey(
      const ValueKey('user-message-attachments:$messageId'),
    );
    final imagesFinder = find.byKey(
      const ValueKey('user-message-images:$messageId'),
    );
    final docsFinder = find.byKey(
      const ValueKey('user-message-docs:$messageId'),
    );

    expect(bubbleFinder, findsOneWidget);
    expect(attachmentsFinder, findsOneWidget);
    expect(imagesFinder, findsOneWidget);
    expect(docsFinder, findsOneWidget);
    expect(
      find.descendant(of: bubbleFinder, matching: find.text('请看这个')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: bubbleFinder, matching: find.text('spec.pdf')),
      findsNothing,
    );
    expect(
      find.descendant(of: bubbleFinder, matching: find.byType(Image)),
      findsNothing,
    );
    expect(
      find.descendant(of: attachmentsFinder, matching: find.text('spec.pdf')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: attachmentsFinder, matching: find.byType(Image)),
      findsOneWidget,
    );
    expect(
      find.descendant(of: attachmentsFinder, matching: find.byType(InkWell)),
      findsNothing,
    );

    final attachmentsRect = tester.getRect(attachmentsFinder);
    final imagesRect = tester.getRect(imagesFinder);
    final docsRect = tester.getRect(docsFinder);
    final bubbleRect = tester.getRect(bubbleFinder);
    expect(imagesRect.bottom, lessThanOrEqualTo(docsRect.top));
    expect(attachmentsRect.bottom, lessThanOrEqualTo(bubbleRect.top));
  });
}
