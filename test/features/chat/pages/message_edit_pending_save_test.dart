import 'dart:async';

import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/features/chat/pages/message_edit_page.dart';
import 'package:Kelivo/features/chat/widgets/message_edit_sheet.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/text_input/message_editing_controller.dart';
import 'package:Kelivo/shared/widgets/long_message_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../../../support/business_test_harness.dart';

void main() {
  for (final sheet in [false, true]) {
    for (final cancel in [false, true]) {
      testWidgets(
        'pending save pops only its own route: sheet=$sheet cancel=$cancel',
        (tester) async {
          final navigation = GlobalKey<NavigatorState>();
          final settings = SettingsProvider(createBusinessTestPreferences());
          await settings.loaded;
          addTearDown(settings.dispose);
          await tester.pumpWidget(
            ChangeNotifierProvider.value(
              value: settings,
              child: MaterialApp(
                navigatorKey: navigation,
                locale: const Locale('en'),
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                home: const Scaffold(body: Text('Root')),
              ),
            ),
          );
          unawaited(
            navigation.currentState!.push<void>(
              MaterialPageRoute(
                builder: (_) => const Scaffold(body: Text('Parent')),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final message = ChatMessage(
            id: 'edit',
            role: 'user',
            conversationId: 'a',
            content: 'original',
          );
          if (sheet) {
            unawaited(
              showMessageEditSheet(
                tester.element(find.text('Parent')),
                message: message,
              ),
            );
          } else {
            unawaited(
              navigation.currentState!.push<String>(
                MaterialPageRoute(
                  builder: (_) => MessageEditPage(message: message),
                ),
              ),
            );
          }
          await tester.pumpAndSettle();
          final document =
              tester
                      .widget<LongMessageEditor>(find.byType(LongMessageEditor))
                      .controller
                  as MessageEditingController;
          final clipboard = Completer<void>();
          document.configureOwner(
            onCommand: (_, _) async {
              await clipboard.future;
              document.text = 'original plus accepted paste';
            },
          );
          final pending = document.performCommand('paste');
          await tester.tap(find.text('Save'));
          if (cancel) {
            navigation.currentState!.pop();
          } else {
            await tester.tap(find.text('Save'));
          }
          clipboard.complete();
          await pending;
          await tester.pumpAndSettle();
          expect(find.text('Parent'), findsOneWidget);
          expect(find.byType(LongMessageEditor), findsNothing);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
        },
      );
    }
  }
}
