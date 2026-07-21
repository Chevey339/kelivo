import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/providers/tts_provider.dart';
import 'package:Kelivo/core/providers/user_provider.dart';
import 'package:Kelivo/features/chat/widgets/chat_message_widget.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  for (final role in <String>['user', 'assistant']) {
    testWidgets('desktop $role message selection exposes Quote action', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      try {
        final quoted = <String>[];
        final message = ChatMessage(
          id: '$role-message',
          role: role,
          content: '$role selected text',
          conversationId: 'conversation-1',
        );

        await tester.pumpWidget(
          _buildHarness(
            child: ChatMessageWidget(
              message: message,
              showModelIcon: false,
              showUserAvatar: false,
              showTokenStats: false,
              onQuoteSelection: quoted.add,
            ),
          ),
        );

        final areaFinder = find.byKey(ValueKey('${role}_${message.id}'));
        expect(areaFinder, findsOneWidget);
        final area = tester.widget<SelectionArea>(areaFinder);
        final areaState = tester.state<SelectionAreaState>(areaFinder);
        areaState.selectableRegion.selectAll();
        await tester.pump();

        final toolbar = area.contextMenuBuilder!(
          tester.element(areaFinder),
          areaState.selectableRegion,
        );
        expect(toolbar, isA<AdaptiveTextSelectionToolbar>());
        final buttons = (toolbar as AdaptiveTextSelectionToolbar).buttonItems!;
        final quoteButton = buttons.singleWhere(
          (item) => item.label == 'Quote',
        );
        quoteButton.onPressed!();
        await tester.pump();

        expect(quoted, <String>['$role selected text']);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });
  }

  testWidgets('mobile assistant selection keeps the default context menu', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    try {
      await tester.pumpWidget(
        _buildHarness(
          child: ChatMessageWidget(
            message: ChatMessage(
              id: 'assistant-mobile',
              role: 'assistant',
              content: 'mobile answer',
              conversationId: 'conversation-1',
            ),
            showModelIcon: false,
            showTokenStats: false,
            onQuoteSelection: (_) {},
          ),
        ),
      );

      final area = tester.widget<SelectionArea>(
        find.byKey(const ValueKey('assistant_assistant-mobile')),
      );
      expect(area.onSelectionChanged, isNull);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}

Widget _buildHarness({required Widget child}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => SettingsProvider()),
      ChangeNotifierProvider(create: (_) => TtsProvider()),
      ChangeNotifierProvider(create: (_) => UserProvider()),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    ),
  );
}
