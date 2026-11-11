import 'package:Kelivo/core/models/conversation.dart';
import 'package:Kelivo/core/models/model_spec.dart';
import 'package:Kelivo/core/models/provider_oauth.dart';
import 'package:Kelivo/core/models/reasoning_request.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/api/response_speed.dart';
import 'package:Kelivo/core/services/chat/chat_service.dart';
import 'package:Kelivo/desktop/reasoning_level_popover.dart';
import 'package:Kelivo/desktop/desktop_glass_popover.dart';
import 'package:Kelivo/features/chat/widgets/reasoning_level_sheet.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/widgets/effort_slider.dart';
import 'package:Kelivo/shared/widgets/ios_tactile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../../../support/business_test_harness.dart';

class _Chat extends ChatService {
  final conversations = {
    'one': Conversation(id: 'one', title: 'one'),
    'two': Conversation(id: 'two', title: 'two'),
  };

  @override
  Conversation? getConversation(String id) => conversations[id];

  @override
  Future<void> updateConversationExtras(
    String id,
    Map<String, dynamic> Function(Map<String, dynamic>) update, {
    Conversation? expectedOwner,
  }) async {
    conversations[id] = conversations[id]!.copyWith(
      extras: update(conversations[id]!.extras),
    );
    notifyListeners();
  }
}

void main() {
  for (final desktop in [false, true]) {
    for (final oauth in [false, true]) {
      testWidgets(
        '${desktop ? 'desktop' : 'mobile'} ${oauth ? 'OAuth' : 'relay'} preserves the picker and saves speed independently',
        (tester) async {
          final settings = SettingsProvider(createBusinessTestPreferences());
          await settings.loaded;
          addTearDown(settings.dispose);
          final config = ProviderConfig(
            id: 'codex',
            name: 'Codex',
            enabled: true,
            apiKey: '',
            baseUrl: oauth
                ? OAuthProvider.chatgpt.baseUrl
                : 'https://gateway.example/v1',
            useResponseApi: true,
            providerType: ProviderKind.openai,
            oauthProvider: oauth ? OAuthProvider.chatgpt : null,
            oauthCredentials: oauth
                ? ProviderOAuthCredentials(
                    accessToken: 'fixture',
                    refreshToken: 'fixture',
                    expiresAt: DateTime(2099),
                    sessionId: 'session',
                  )
                : null,
            models: const ['gpt-6-astra'],
            modelOverrides: const {
              'gpt-6-astra': {
                'name': 'GPT-6 Astra',
                'abilities': ['reasoning'],
                'reasoning': {
                  'levels': ['low', 'high', 'max'],
                  'canDisable': false,
                  'defaultLevel': 'high',
                  'dialect': 'openaiResponsesReasoning',
                },
                'oauthServiceTierSessionId': 'session',
                'oauthServiceTiers': ['fast'],
              },
            },
          );
          await settings.setProviderConfig(config.id, config);
          await settings.setReasoningChoice(
            config.id,
            'gpt-6-astra',
            const ReasoningRequest(ReasoningLevel.max),
          );
          final chat = _Chat();
          addTearDown(chat.dispose);
          final anchor = GlobalKey();
          var conversation = 'one';
          await tester.pumpWidget(
            MultiProvider(
              providers: [
                ChangeNotifierProvider<SettingsProvider>.value(value: settings),
                ChangeNotifierProvider<ChatService>.value(value: chat),
              ],
              child: MaterialApp(
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(disableAnimations: true),
                  child: child!,
                ),
                home: Scaffold(
                  body: Align(
                    alignment: Alignment.bottomCenter,
                    child: SizedBox(
                      key: anchor,
                      width: 360,
                      height: 48,
                      child: Builder(
                        builder: (context) => TextButton(
                          onPressed: () {
                            if (desktop) {
                              showDesktopReasoningLevelPopover(
                                context,
                                anchorKey: anchor,
                                config: config,
                                modelId: 'gpt-6-astra',
                                conversationId: conversation,
                              );
                            } else {
                              showReasoningLevelSheet(
                                context,
                                config: config,
                                modelId: 'gpt-6-astra',
                                conversationId: conversation,
                              );
                            }
                          },
                          child: const Text('open'),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.tap(find.text('open'));
          await tester.pumpAndSettle();
          expect(find.byType(EffortSlider), findsOneWidget);
          expect(find.byType(EffortSliderLabelPill), findsOneWidget);
          if (desktop) {
            final panel = tester.getRect(find.byType(DesktopGlassPanel));
            final trigger = tester.getRect(find.byKey(anchor));
            expect(panel.width, 260);
            expect(panel.center.dx, closeTo(trigger.center.dx, 0.1));
            expect(panel.bottom, closeTo(trigger.top - 8, 0.1));
          }
          final speedButton = find.byKey(
            const ValueKey('response-speed-toggle'),
          );
          Future<void> toggle() async {
            await tester.tap(speedButton);
            await tester.pumpAndSettle();
            expect(find.byType(PopupMenuItem<ResponseSpeed>), findsNothing);
          }

          String? speedLabel() =>
              tester.widget<IosIconButton>(speedButton).semanticLabel;
          final label = tester.widget<EffortSliderLabelPill>(
            find.byType(EffortSliderLabelPill),
          );
          if (label.subtitle != null) {
            expect(
              find.text(label.subtitle!),
              desktop ? findsNothing : findsOneWidget,
            );
          }
          if (desktop) {
            final animation = tester.widget<AnimatedSwitcher>(
              find.descendant(
                of: find.byType(EffortSliderLabelPill),
                matching: find.byType(AnimatedSwitcher),
              ),
            );
            expect(animation.duration, const Duration(milliseconds: 180));
          }
          await toggle();
          expect(
            ConversationResponseSpeed.selected(
              chat.getConversation('one'),
              config.id,
              'gpt-6-astra',
            ),
            ResponseSpeed.fast,
          );
          expect(
            ConversationResponseSpeed.selected(
              chat.getConversation('two'),
              config.id,
              'gpt-6-astra',
            ),
            isNull,
          );
          expect(
            settings.reasoningChoiceFor(config.id, 'gpt-6-astra'),
            const ReasoningRequest(ReasoningLevel.max),
          );
          expect(speedLabel(), 'Response speed: Fast');
          expect(
            tester
                .widget<EffortSlider>(find.byType(EffortSlider))
                .animatedTrack,
            isTrue,
          );
          expect(find.byKey(const ValueKey('reasoning-reset')), findsNothing);
          expect(find.text('GPT-6 Astra'), findsNothing);
          await toggle();
          if (!oauth) {
            expect(speedLabel(), 'Response speed: UltraFast');
            expect(
              ConversationResponseSpeed.selected(
                chat.getConversation('one'),
                config.id,
                'gpt-6-astra',
              ),
              ResponseSpeed.ultrafast,
            );
            await toggle();
          }
          expect(
            ConversationResponseSpeed.selected(
              chat.getConversation('one'),
              config.id,
              'gpt-6-astra',
            ),
            ResponseSpeed.standard,
          );
          expect(
            settings.reasoningChoiceFor(config.id, 'gpt-6-astra'),
            const ReasoningRequest(ReasoningLevel.max),
          );
          await toggle();
          await tester.tapAt(const Offset(10, 10));
          await tester.pumpAndSettle();
          expect(find.byType(EffortSlider), findsNothing);
          await tester.tap(find.text('open'));
          await tester.pumpAndSettle();
          expect(speedLabel(), 'Response speed: Fast');
          await tester.tapAt(const Offset(10, 10));
          await tester.pumpAndSettle();
          conversation = 'two';
          await tester.tap(find.text('open'));
          await tester.pumpAndSettle();
          expect(speedLabel(), 'Response speed: Standard');
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
