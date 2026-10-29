import 'support/business_test_harness.dart';
import 'package:provider/provider.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
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
  bool canCreateBranch = true,
  ValueChanged<MessageMoreAction?>? onSelected,
}) async {
  await tester.pumpWidget(
    ChangeNotifierProvider(
      create: (_) => SettingsProvider(createBusinessTestPreferences()),
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
                onPressed: () {
                  showMessageMoreSheet(
                    context,
                    _message(),
                    canDeleteAllVersions: canDeleteAllVersions,
                    canCreateBranch: canCreateBranch,
                  ).then((action) => onSelected?.call(action));
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
}

void main() {
  testWidgets(
    'one menu entry selects messages for every batch action',
    (tester) async {
      MessageMoreAction? selected;
      await _openMoreSheet(
        tester,
        canDeleteAllVersions: false,
        onSelected: (action) => selected = action,
      );
      expect(find.text('Share'), findsNothing);
      expect(find.text('Select Messages'), findsOneWidget);
      await tester.tap(find.text('Select Messages'));
      await tester.pumpAndSettle();
      expect(selected, MessageMoreAction.selectMessages);
    },
    variant: TargetPlatformVariant({
      TargetPlatform.android,
      TargetPlatform.iOS,
      TargetPlatform.macOS,
      TargetPlatform.windows,
      TargetPlatform.linux,
    }),
  );

  testWidgets('多版本消息菜单显示删除全部版本', (tester) async {
    await _openMoreSheet(tester, canDeleteAllVersions: true);

    expect(find.text('Select Messages'), findsOneWidget);
    expect(find.text('Create Branch'), findsOneWidget);
    expect(find.text('Delete This Version'), findsOneWidget);
    expect(find.text('Delete All Versions'), findsOneWidget);
  });

  testWidgets('单版本消息菜单不显示删除全部版本', (tester) async {
    await _openMoreSheet(tester, canDeleteAllVersions: false);

    expect(find.text('Select Messages'), findsOneWidget);
    expect(find.text('Delete This Version'), findsOneWidget);
    expect(find.text('Delete All Versions'), findsNothing);
  });

  testWidgets('临时会话消息菜单不显示创建分支', (tester) async {
    await _openMoreSheet(
      tester,
      canDeleteAllVersions: false,
      canCreateBranch: false,
    );

    expect(find.text('Create Branch'), findsNothing);
  });
}
