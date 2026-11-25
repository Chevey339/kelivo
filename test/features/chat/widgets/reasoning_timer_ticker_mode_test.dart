import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/providers/tts_provider.dart';
import 'package:Kelivo/features/chat/widgets/chat_message_widget.dart';
import 'package:Kelivo/features/home/services/ask_user_interaction_service.dart';
import 'package:Kelivo/features/home/services/tool_approval_service.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../support/business_test_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'reasoning elapsed timer stops when TickerMode disables or lifecycle hides and resumes cleanly',
    (tester) async {
      SharedPreferences.setMockInitialValues(const {});
      final tickerEnabled = ValueNotifier<bool>(true);
      addTearDown(tickerEnabled.dispose);
      addTearDown(() => debugOnRebuildDirtyWidget = null);
      addTearDown(() {
        switch (tester.binding.lifecycleState) {
          case null:
          case AppLifecycleState.resumed:
            return;
          case AppLifecycleState.paused:
            tester.binding.handleAppLifecycleStateChanged(
              AppLifecycleState.hidden,
            );
            tester.binding.handleAppLifecycleStateChanged(
              AppLifecycleState.inactive,
            );
            tester.binding.handleAppLifecycleStateChanged(
              AppLifecycleState.resumed,
            );
          case AppLifecycleState.hidden:
            tester.binding.handleAppLifecycleStateChanged(
              AppLifecycleState.inactive,
            );
            tester.binding.handleAppLifecycleStateChanged(
              AppLifecycleState.resumed,
            );
          case AppLifecycleState.inactive:
          case AppLifecycleState.detached:
            tester.binding.handleAppLifecycleStateChanged(
              AppLifecycleState.resumed,
            );
        }
      });

      var elapsedRebuilds = 0;
      debugOnRebuildDirtyWidget = (element, _) {
        if (element.widget is ValueListenableBuilder<int>) {
          elapsedRebuilds++;
        }
      };

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(
              create: (_) => SettingsProvider(createBusinessTestPreferences()),
            ),
            ChangeNotifierProvider(
              create: (_) =>
                  TtsProvider(preferences: createBusinessTestPreferences()),
            ),
            ChangeNotifierProvider(create: (_) => ToolApprovalService()),
            ChangeNotifierProvider(create: (_) => AskUserInteractionService()),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: ValueListenableBuilder<bool>(
                valueListenable: tickerEnabled,
                builder: (context, enabled, child) =>
                    TickerMode(enabled: enabled, child: child!),
                child: ChatMessageWidget(
                  message: ChatMessage(
                    id: 'reasoning-timer',
                    role: 'assistant',
                    content: '',
                    conversationId: 'c1',
                    isStreaming: true,
                  ),
                  showModelIcon: false,
                  reasoningText: 'Thinking through the problem',
                  reasoningLoading: true,
                  reasoningExpanded: true,
                  reasoningStartAt: DateTime.now(),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      elapsedRebuilds = 0;

      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(elapsedRebuilds, greaterThanOrEqualTo(5));

      // Disabling TickerMode cancels the 100ms timer so no background rebuilds run.
      tickerEnabled.value = false;
      await tester.pump();
      elapsedRebuilds = 0;

      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(elapsedRebuilds, 0);

      // Re-enabling TickerMode immediately refreshes and restarts the timer.
      tickerEnabled.value = true;
      await tester.pump();
      expect(elapsedRebuilds, greaterThanOrEqualTo(1));

      elapsedRebuilds = 0;
      for (var i = 0; i < 3; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(elapsedRebuilds, greaterThanOrEqualTo(2));

      // Hiding the window also cancels the 100ms timer directly via lifecycle.
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      elapsedRebuilds = 0;
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      tester.binding.scheduleWarmUpFrame();
      expect(elapsedRebuilds, 0);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(elapsedRebuilds, greaterThanOrEqualTo(1));

      elapsedRebuilds = 0;
      for (var i = 0; i < 3; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(elapsedRebuilds, greaterThanOrEqualTo(2));
      expect(tester.takeException(), isNull);
    },
  );
}
