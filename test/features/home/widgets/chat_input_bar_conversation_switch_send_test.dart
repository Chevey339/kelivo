import 'dart:async';

import 'package:Kelivo/core/models/chat_input_data.dart';
import 'package:Kelivo/core/providers/assistant_provider.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/features/home/widgets/chat_input_bar.dart';
import 'package:Kelivo/icons/lucide_adapter.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../../../support/business_test_harness.dart';

void main() {
  testWidgets(
    'switching conversations unlocks send while a submit is in flight',
    (tester) async {
      final submitted = <String>[];
      final firstSend = Completer<ChatInputSubmissionResult>();
      final inputKey = GlobalKey();
      final controller = TextEditingController();
      final focusNode = FocusNode();
      addTearDown(controller.dispose);
      addTearDown(focusNode.dispose);

      Future<ChatInputSubmissionResult> onSend(ChatInputData input) {
        submitted.add(input.text);
        if (submitted.length == 1) return firstSend.future;
        return Future.value(ChatInputSubmissionResult.sent);
      }

      Future<void> pumpBar(String conversationId) {
        return tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider(
                create: (_) =>
                    SettingsProvider(createBusinessTestPreferences()),
              ),
              ChangeNotifierProvider(
                create: (_) => AssistantProvider(
                  preferences: createBusinessTestPreferences(),
                ),
              ),
            ],
            child: MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: ChatInputBar(
                  key: inputKey,
                  conversationId: conversationId,
                  controller: controller,
                  focusNode: focusNode,
                  onSend: onSend,
                ),
              ),
            ),
          ),
        );
      }

      controller.text = 'from a';
      await pumpBar('conv-a');
      await tester.tap(find.byIcon(Lucide.ArrowUp));
      await tester.pump();
      expect(submitted, ['from a']);
      expect(controller.text, isEmpty);

      controller.text = 'from b';
      await pumpBar('conv-b');
      await tester.tap(find.byIcon(Lucide.ArrowUp));
      await tester.pump();
      expect(submitted, ['from a', 'from b']);
      expect(controller.text, isEmpty);

      firstSend.complete(ChatInputSubmissionResult.sent);
      await tester.pump();
      expect(controller.text, isEmpty);
    },
  );

  testWidgets(
    'a late rejected send does not restore the previous conversation draft',
    (tester) async {
      final firstSend = Completer<ChatInputSubmissionResult>();
      final inputKey = GlobalKey();
      final controller = TextEditingController();
      final focusNode = FocusNode();
      addTearDown(controller.dispose);
      addTearDown(focusNode.dispose);

      Future<void> pumpBar(String conversationId) {
        return tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider(
                create: (_) =>
                    SettingsProvider(createBusinessTestPreferences()),
              ),
              ChangeNotifierProvider(
                create: (_) => AssistantProvider(
                  preferences: createBusinessTestPreferences(),
                ),
              ),
            ],
            child: MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: ChatInputBar(
                  key: inputKey,
                  conversationId: conversationId,
                  controller: controller,
                  focusNode: focusNode,
                  onSend: (_) => firstSend.future,
                ),
              ),
            ),
          ),
        );
      }

      controller.text = 'from a';
      await pumpBar('conv-a');
      await tester.tap(find.byIcon(Lucide.ArrowUp));
      await tester.pump();
      expect(controller.text, isEmpty);

      controller.text = 'from b';
      await pumpBar('conv-b');
      firstSend.complete(ChatInputSubmissionResult.rejected);
      await tester.pump();
      expect(controller.text, 'from b');
    },
  );
}
