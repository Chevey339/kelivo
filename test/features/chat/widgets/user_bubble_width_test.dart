import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/providers/user_provider.dart';
import 'package:Kelivo/features/chat/widgets/chat_message_widget.dart';
import 'package:Kelivo/l10n/app_localizations.dart';

import '../../../support/business_test_harness.dart';
import '../../../support/markdown_render_helpers.dart';

void main() {
  for (final markdown in [true, false]) {
    for (final collapse in [false, true]) {
      testWidgets(
        'user bubble hugs the longest wrapped line (Markdown: $markdown, collapse: $collapse)',
        (tester) async {
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = const Size(800, 600);
          addTearDown(tester.view.resetDevicePixelRatio);
          addTearDown(tester.view.resetPhysicalSize);

          const firstWord = 'accessibilityPreferences';
          const secondWord = 'internationalizationSupport';
          const source = '$firstWord **$secondWord**';
          final message = ChatMessage(
            role: 'user',
            content: source,
            conversationId: 'chat',
          );
          final harness = await createBusinessTestHarness();
          final settings = SettingsProvider(harness.preferences);
          addTearDown(settings.dispose);
          await settings.loaded;
          await settings.setEnableUserMarkdown(markdown);
          await settings.setCollapseLongUserMessages(collapse);
          await settings.setCollapseLongUserMessageChars(
            SettingsProvider.minCollapseLongUserMessageChars,
          );
          await tester.pumpWidget(
            MultiProvider(
              providers: [
                ChangeNotifierProvider.value(value: settings),
                ChangeNotifierProvider(
                  create: (_) => UserProvider(preferences: harness.preferences),
                ),
              ],
              child: MaterialApp(
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                home: Scaffold(
                  body: ChatMessageWidget(
                    message: message,
                    showUserAvatar: false,
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          final bubble = find.byKey(
            ValueKey('user-message-text-bubble:${message.id}'),
          );
          final renderedText = markdown ? '$firstWord $secondWord' : source;
          final paragraph = renderParagraphs(
            bubble,
          ).singleWhere((p) => p.text.toPlainText() == renderedText);
          final firstLine = paragraph
              .getBoxesForSelection(
                const TextSelection(
                  baseOffset: 0,
                  extentOffset: firstWord.length,
                ),
              )
              .single;
          final secondLine = paragraph
              .getBoxesForSelection(
                TextSelection(
                  baseOffset: firstWord.length + 1,
                  extentOffset: renderedText.length,
                ),
              )
              .single;
          expect(secondLine.top, greaterThan(firstLine.top));

          final bounds = tester.getRect(bubble);
          final rightEdge = math.max(firstLine.right, secondLine.right);
          final leftPadding =
              paragraph.localToGlobal(Offset.zero).dx - bounds.left;
          final rightPadding =
              bounds.right - paragraph.localToGlobal(Offset(rightEdge, 0)).dx;
          expect(rightPadding, closeTo(leftPadding, 1));
        },
        variant: TargetPlatformVariant.only(TargetPlatform.windows),
      );
    }
  }
}
