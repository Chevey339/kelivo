import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/desktop/mini_map_popover.dart';
import 'package:Kelivo/l10n/app_localizations.dart';

ChatMessage _message({
  required String id,
  required String role,
  required String content,
}) {
  return ChatMessage(
    id: id,
    role: role,
    content: content,
    conversationId: 'conversation-1',
  );
}

class _MiniMapPopoverHarness extends StatelessWidget {
  const _MiniMapPopoverHarness({required this.messages});

  final List<ChatMessage> messages;

  @override
  Widget build(BuildContext context) {
    final anchorKey = GlobalKey();
    return Scaffold(
      body: Align(
        alignment: Alignment.bottomCenter,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 80),
          child: SizedBox(
            width: 420,
            child: FilledButton(
              key: anchorKey,
              onPressed: () {
                unawaited(
                  showDesktopMiniMapPopover(
                    context,
                    anchorKey: anchorKey,
                    messages: messages,
                  ),
                );
              },
              child: const Text('Open minimap'),
            ),
          ),
        ),
      ),
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('showDesktopMiniMapPopover', () {
    final messages = <ChatMessage>[
      _message(id: 'u1', role: 'user', content: 'Alpha question'),
      _message(id: 'a1', role: 'assistant', content: 'Alpha answer'),
      _message(id: 'u2', role: 'user', content: 'Beta prompt'),
      _message(id: 'a2', role: 'assistant', content: 'Beta explanation'),
    ];

    Future<void> openPopover(WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: _MiniMapPopoverHarness(messages: messages),
        ),
      );

      await tester.tap(find.text('Open minimap'));
      await tester.pumpAndSettle();
    }

    testWidgets('filters message pairs by search query', (tester) async {
      await openPopover(tester);

      await tester.tap(
        find.byKey(const ValueKey('desktopMiniMapSearchButton')),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'beta');
      await tester.pumpAndSettle();

      expect(find.text('Alpha question'), findsNothing);
      expect(find.text('Alpha answer'), findsNothing);
      expect(find.text('Beta prompt'), findsOneWidget);
      expect(find.text('Beta explanation'), findsOneWidget);
    });

    testWidgets('closing search restores full message list', (tester) async {
      await openPopover(tester);

      await tester.tap(
        find.byKey(const ValueKey('desktopMiniMapSearchButton')),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'beta');
      await tester.pumpAndSettle();

      expect(find.text('Alpha question'), findsNothing);

      await tester.tap(
        find.byKey(const ValueKey('desktopMiniMapCloseSearchButton')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Alpha question'), findsOneWidget);
      expect(find.text('Alpha answer'), findsOneWidget);
      expect(find.text('Beta prompt'), findsOneWidget);
      expect(find.text('Beta explanation'), findsOneWidget);
    });
  });
}
