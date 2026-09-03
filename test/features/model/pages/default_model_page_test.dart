import '../../../support/business_test_harness.dart';
import 'package:Kelivo/core/models/conversation.dart';
import 'package:Kelivo/core/providers/assistant_provider.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/chat/chat_service.dart';
import 'package:Kelivo/features/model/pages/default_model_page.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/core/services/haptics.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

ProviderConfig _providerConfig(String key, String modelId) => ProviderConfig(
  id: key,
  enabled: true,
  name: key,
  apiKey: '',
  baseUrl: '',
  providerType: ProviderKind.openai,
  models: [modelId],
  balanceEnabled: false,
);

class _FakeChatService extends ChatService {
  _FakeChatService([this.conversation]);

  final Conversation? conversation;

  @override
  String? get currentConversationId => conversation?.id;

  @override
  Conversation? getConversation(String id) =>
      id == conversation?.id ? conversation : null;
}

bool _providerTabSelected(WidgetTester tester, String providerKey) {
  final semantics = tester.widget<Semantics>(
    find.descendant(
      of: find.byKey(ValueKey('model-selector-provider-tab-$providerKey')),
      matching: find.byType(Semantics),
    ),
  );
  return semantics.properties.selected ?? false;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(const {});
  });

  testWidgets('title summary follows the current chat model by default', (
    tester,
  ) async {
    final settings = SettingsProvider(createBusinessTestPreferences());
    addTearDown(settings.dispose);
    await settings.loaded;

    await tester.pumpWidget(
      ChangeNotifierProvider<SettingsProvider>.value(
        value: settings,
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: DefaultModelPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Title Summary Model'), findsOneWidget);
    expect(
      find.text(
        'Summarizes conversation titles using the current chat model by default, or a selected model.',
      ),
      findsOneWidget,
    );
    expect(settings.isTitleGenerationEnabled, isTrue);
    expect(find.text('Use current chat model'), findsWidgets);
    expect(find.byTooltip('Disable'), findsOneWidget);

    await tester.tap(find.byTooltip('Disable'));
    await tester.pumpAndSettle();

    expect(settings.isTitleGenerationEnabled, isFalse);
    expect(find.text('Not enabled'), findsWidgets);
    expect(find.byTooltip('Use current chat model'), findsWidgets);
  });

  testWidgets(
    'follow-current title picker opens on the conversation model',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      try {
        final settings = SettingsProvider(createBusinessTestPreferences());
        await settings.loaded;
        for (final model in const {
          'global-provider': 'global-model',
          'assistant-provider': 'assistant-model',
          'conversation-provider': 'conversation-model',
        }.entries) {
          await settings.setProviderConfig(
            model.key,
            _providerConfig(model.key, model.value),
          );
        }
        await settings.setProvidersOrder(const [
          'global-provider',
          'assistant-provider',
          'conversation-provider',
        ]);
        await settings.setCurrentModel('global-provider', 'global-model');

        final assistants = AssistantProvider(
          preferences: createBusinessTestPreferences(),
        );
        await assistants.loaded;
        final assistantId = await assistants.addAssistant(name: 'Assistant');
        await assistants.setCurrentAssistant(assistantId);
        await assistants.updateAssistant(
          assistants.currentAssistant!.copyWith(
            chatModelProvider: 'assistant-provider',
            chatModelId: 'assistant-model',
          ),
        );
        final chats = _FakeChatService(
          Conversation(
            title: 'Chat',
            assistantId: assistantId,
            chatModelProvider: 'conversation-provider',
            chatModelId: 'conversation-model',
          ),
        );
        addTearDown(chats.dispose);
        addTearDown(settings.dispose);
        addTearDown(assistants.dispose);

        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider<SettingsProvider>.value(value: settings),
              ChangeNotifierProvider<AssistantProvider>.value(
                value: assistants,
              ),
              ChangeNotifierProvider<ChatService>.value(value: chats),
            ],
            child: const MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: DefaultModelPage(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        Haptics.setEnabled(false);
        await tester.tap(find.text('Use current chat model').first);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 500)),
        );
        await tester.pump(const Duration(milliseconds: 500));

        expect(_providerTabSelected(tester, 'conversation-provider'), isTrue);
        expect(_providerTabSelected(tester, 'assistant-provider'), isFalse);

        Navigator.of(tester.element(find.byType(BottomSheet))).pop();
        await tester.pumpAndSettle();
      } finally {
        Haptics.setEnabled(true);
        debugDefaultTargetPlatformOverride = null;
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      }
    },
    timeout: const Timeout(Duration(seconds: 20)),
  );
}
