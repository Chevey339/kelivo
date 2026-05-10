import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/features/chat/widgets/message_more_sheet.dart';
import 'package:Kelivo/l10n/app_localizations.dart';

ChatMessage _message({String role = 'assistant'}) {
  return ChatMessage(
    id: 'message-1',
    role: role,
    content: 'hello',
    conversationId: 'conversation-1',
  );
}

Future<MessageMoreAction?> _openMoreSheet(
  WidgetTester tester, {
  required bool canDeleteAllVersions,
  String role = 'assistant',
  String? tapLabel,
}) async {
  final selectedAction = ValueNotifier<MessageMoreAction?>(null);
  await tester.pumpWidget(
    ChangeNotifierProvider(
      create: (_) => SettingsProvider(),
      child: MaterialApp(
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
                onPressed: () async {
                  selectedAction.value = await showMessageMoreSheet(
                    context,
                    _message(role: role),
                    canDeleteAllVersions: canDeleteAllVersions,
                  );
                },
                child: const Text('open'),
              );
            },
          ),
        ),
      ),
    ),
  );

  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  if (tapLabel != null) {
    await tester.tap(find.text(tapLabel));
    await tester.pumpAndSettle();
  }
  return selectedAction.value;
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

  testWidgets('助手消息菜单可以切换为用户', (tester) async {
    final action = await _openMoreSheet(
      tester,
      canDeleteAllVersions: false,
      tapLabel: 'Switch to User',
    );

    expect(action, MessageMoreAction.switchToUser);
  });

  testWidgets('用户消息菜单可以切换为模型', (tester) async {
    final action = await _openMoreSheet(
      tester,
      canDeleteAllVersions: false,
      role: 'user',
      tapLabel: 'Switch to Model',
    );

    expect(action, MessageMoreAction.switchToAssistant);
  });
}
