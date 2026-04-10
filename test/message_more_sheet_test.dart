import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/features/chat/widgets/message_more_sheet.dart';
import 'package:Kelivo/l10n/app_localizations.dart';

ChatMessage _message() {
  return ChatMessage(
    id: 'message-1',
    role: 'assistant',
    content: 'hello',
    conversationId: 'conversation-1',
  );
}

Future<void> _openMoreSheet(
  WidgetTester tester, {
  required bool canDeleteAllVersions,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Builder(
          builder: (context) {
            return TextButton(
              onPressed: () {
                showMessageMoreSheet(
                  context,
                  _message(),
                  canDeleteAllVersions: canDeleteAllVersions,
                );
              },
              child: const Text('open'),
            );
          },
        ),
      ),
    ),
  );

  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('多版本消息菜单显示删除全部版本', (tester) async {
    await _openMoreSheet(tester, canDeleteAllVersions: true);

    expect(find.text('Delete This Version'), findsOneWidget);
    expect(find.text('Delete All Versions'), findsOneWidget);
  });

  testWidgets('单版本消息菜单不显示删除全部版本', (tester) async {
    await _openMoreSheet(tester, canDeleteAllVersions: false);

    expect(find.text('Delete This Version'), findsOneWidget);
    expect(find.text('Delete All Versions'), findsNothing);
  });
}
