import 'dart:convert';

import 'package:Kelivo/core/providers/asr_provider.dart';
import 'package:Kelivo/core/providers/assistant_provider.dart';
import 'package:Kelivo/core/providers/mcp_provider.dart';
import 'package:Kelivo/core/providers/quick_phrase_provider.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/features/home/widgets/chat_input_bar.dart';
import 'package:Kelivo/features/home/widgets/chat_input_section.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/core/database/business_preferences.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../../../support/business_test_harness.dart';

/// The composer force-disables capabilities the current model lacks by writing
/// to the ASSISTANT. Once a conversation can pin its own model, that write
/// would reach every other conversation sharing the assistant, so it has to be
/// scoped to the case where the assistant really is the source of the model.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late BusinessPreferences preferences;

  setUp(() {
    preferences = createBusinessTestPreferences();
  });

  /// Loads the provider outside the fake clock: it reads through drift, and a
  /// widget test's timers never advance on their own.
  Future<AssistantProvider> loadAssistantWithMcp(WidgetTester tester) async {
    late AssistantProvider provider;
    await tester.runAsync(() async {
      await preferences.setString(
        'assistants_v1',
        jsonEncode([
          {
            'id': 'assistant-1',
            'name': 'Assistant',
            'mcpServerIds': ['server-1'],
          },
        ]),
      );
      await preferences.setString('current_assistant_id_v1', 'assistant-1');
      provider = AssistantProvider(preferences: preferences);
      for (var i = 0; i < 100; i++) {
        if (provider.currentAssistant != null) break;
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
    });
    return provider;
  }

  Future<void> pumpComposer(
    WidgetTester tester, {
    required AssistantProvider assistants,
    required bool isConversationOverride,
  }) async {
    final settings = SettingsProvider(preferences);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: settings),
          ChangeNotifierProvider.value(value: assistants),
          ChangeNotifierProvider(create: (_) => AsrProvider()),
          ChangeNotifierProvider(
            create: (_) => McpProvider(preferences: preferences),
          ),
          ChangeNotifierProvider(
            create: (_) => QuickPhraseProvider(preferences: preferences),
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: ChatInputSection(
              inputBarKey: GlobalKey(),
              chatModelProviderKey: 'SomeProvider',
              chatModelId: 'no-tools-model',
              chatModelIsConversationOverride: isConversationOverride,
              inputFocus: FocusNode(),
              inputController: TextEditingController(),
              mediaController: ChatInputBarController(),
              isTablet: false,
              isLoading: false,
              // The model in play supports neither tools nor reasoning, which
              // is what triggers the enforcement under test.
              isToolModel: (_, _) => false,
              isReasoningModel: (_, _) => false,
              isReasoningEnabled: (_) => true,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  testWidgets('a conversation-pinned model leaves the assistant alone', (
    tester,
  ) async {
    final assistants = await loadAssistantWithMcp(tester);

    await pumpComposer(
      tester,
      assistants: assistants,
      isConversationOverride: true,
    );

    expect(
      assistants.currentAssistant?.mcpServerIds,
      const ['server-1'],
      reason:
          'one conversation must not rewrite settings shared by all of them',
    );
  });

  testWidgets('the assistant\'s own model still disables what it cannot do', (
    tester,
  ) async {
    final assistants = await loadAssistantWithMcp(tester);

    await pumpComposer(
      tester,
      assistants: assistants,
      isConversationOverride: false,
    );

    expect(assistants.currentAssistant?.mcpServerIds, isEmpty);
  });
}
