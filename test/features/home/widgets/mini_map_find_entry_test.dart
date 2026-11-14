import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/desktop/mini_map_popover.dart';
import 'package:Kelivo/features/home/widgets/mini_map_sheet.dart';
import 'package:Kelivo/l10n/app_localizations.dart';

void main() {
  for (final desktop in [false, true]) {
    for (final selecting in [false, true]) {
      testWidgets(
        'map opens chat find only in browse mode (desktop=$desktop, selecting=$selecting)',
        (tester) async {
          final anchor = GlobalKey();
          var opened = 0;
          final messages = [
            ChatMessage(
              role: 'user',
              conversationId: 'c',
              content: 'visible row',
            ),
          ];
          await tester.pumpWidget(
            MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: Builder(
                  builder: (context) => Align(
                    alignment: Alignment.bottomCenter,
                    child: TextButton(
                      key: anchor,
                      onPressed: () {
                        if (desktop) {
                          showDesktopMiniMapPopover(
                            context,
                            anchorKey: anchor,
                            messages: messages,
                            selecting: selecting,
                            selectedMessageIds: {},
                            onToggleSelection: (_) {},
                            onOpenConversationFind: () => opened++,
                          );
                        } else {
                          showMiniMapSheet(
                            context,
                            messages,
                            selecting: selecting,
                            selectedMessageIds: {},
                            onToggleSelection: (_) {},
                            onOpenConversationFind: () => opened++,
                          );
                        }
                      },
                      child: const Text('open'),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.tap(find.text('open'));
          await tester.pumpAndSettle();
          final entry = find.byKey(const ValueKey('miniMapSearchButton'));
          expect(find.text('visible row'), findsOneWidget);
          expect(find.byType(EditableText), findsNothing);
          if (selecting) {
            expect(entry, findsNothing);
          } else {
            await tester.tap(entry);
            await tester.pumpAndSettle();
            expect(opened, 1);
            expect(find.text('visible row'), findsNothing);
          }
        },
      );
    }
  }
}
