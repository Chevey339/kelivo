import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:Kelivo/core/models/compression_config.dart';
import 'package:Kelivo/core/models/conversation.dart';
import 'package:Kelivo/core/providers/assistant_provider.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/chat/chat_service.dart';
import 'package:Kelivo/features/chat/widgets/compression_controls.dart';
import 'package:Kelivo/features/chat/widgets/context_dialog.dart';
import 'package:Kelivo/features/home/widgets/chat_input_bar.dart';
import 'package:Kelivo/icons/lucide_adapter.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/widgets/ios_switch.dart';
import 'package:Kelivo/shared/widgets/ios_tactile.dart';

import '../../../support/business_test_harness.dart';

class _Chat extends ChatService {
  final conversations = {
    'chat': Conversation(id: 'chat', title: 'Chat'),
    'other': Conversation(id: 'other', title: 'Other chat'),
  };

  @override
  Conversation? getConversation(String id) => conversations[id];
}

void main() {
  Future<({SettingsProvider settings, _Chat chat})> pumpControls(
    WidgetTester tester, {
    required bool desktop,
    bool inheritedAuto = false,
  }) async {
    const haptics = MethodChannel('haptic_feedback');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      haptics,
      (_) async => true,
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        haptics,
        null,
      ),
    );
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = desktop
        ? const Size(1200, 800)
        : const Size(393, 852);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    late SettingsProvider settings;
    late AssistantProvider assistants;
    final chat = _Chat();
    await tester.runAsync(() async {
      final preferences = createBusinessTestPreferences();
      settings = SettingsProvider(preferences);
      assistants = AssistantProvider(preferences: preferences);
      await Future.wait([settings.loaded, assistants.loaded]);
      await settings.setCompressionDefaults(
        CompressionConfig(
          mode: inheritedAuto
              ? AutoCompressionMode.auto
              : AutoCompressionMode.off,
        ),
      );
      await chat.setCompressionOverrides('chat', {
        'templateId': 'code',
        'summaryTokens': 8192,
        'keepRecentUserTurns': 2,
      });
    });
    addTearDown(settings.dispose);
    addTearDown(assistants.dispose);
    addTearDown(chat.dispose);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: settings),
          ChangeNotifierProvider.value(value: assistants),
          ChangeNotifierProvider<ChatService>.value(value: chat),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Align(
              alignment: Alignment.bottomCenter,
              child: desktop
                  ? ChatInputBar(conversationId: 'chat', onClearContext: () {})
                  : const AutoCompressionControl(conversationId: 'chat'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return (settings: settings, chat: chat);
  }

  for (final inheritedAuto in [false, true]) {
    testWidgets(
      'desktop menu directly toggles current chat with inherited auto=$inheritedAuto',
      (tester) async {
        final fixture = await pumpControls(
          tester,
          desktop: true,
          inheritedAuto: inheritedAuto,
        );
        final l10n = AppLocalizations.of(
          tester.element(find.byType(ChatInputBar)),
        )!;
        Future<void> openMenu(bool expectedChecked) async {
          await tester.tap(find.byTooltip(l10n.contextManagement));
          await tester.pumpAndSettle();
          final entry = find.ancestor(
            of: find.text(l10n.compressionAutoTitle),
            matching: find.byType(IosCardPress),
          );
          expect(entry, findsOneWidget);
          expect(
            find.descendant(of: entry, matching: find.byIcon(Lucide.Check)),
            expectedChecked ? findsOneWidget : findsNothing,
          );
        }

        for (final enabled in [!inheritedAuto, inheritedAuto]) {
          await openMenu(!enabled);
          await tester.tap(find.text(l10n.compressionAutoTitle));
          await tester.pumpAndSettle();
          expect(find.byType(ContextDialog), findsNothing);
          expect(find.byType(AutoCompressionControl), findsNothing);
          expect(find.text(l10n.compressionAutoTitle), findsNothing);
          expect(await fixture.chat.compressionOverrides('chat'), {
            'templateId': 'code',
            'summaryTokens': 8192,
            'keepRecentUserTurns': 2,
            'mode': enabled ? 'auto' : 'off',
          });
          expect(await fixture.chat.compressionOverrides('other'), isEmpty);
          expect(
            fixture.settings.compressionDefaults.mode,
            inheritedAuto ? AutoCompressionMode.auto : AutoCompressionMode.off,
          );
        }
        await openMenu(inheritedAuto);
        await tester.tapAt(const Offset(5, 5));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      },
      variant: TargetPlatformVariant({
        TargetPlatform.macOS,
        TargetPlatform.windows,
        TargetPlatform.linux,
      }),
    );
  }

  testWidgets(
    'mobile switch enables on its first tap without confirmation',
    (tester) async {
      final fixture = await pumpControls(tester, desktop: false);
      final l10n = AppLocalizations.of(
        tester.element(find.byType(AutoCompressionControl)),
      )!;
      await tester.tap(find.byType(IosSwitch));
      await tester.pumpAndSettle();
      expect(find.byType(ContextDialog), findsNothing);
      expect(tester.widget<IosSwitch>(find.byType(IosSwitch)).value, isTrue);
      expect((await fixture.chat.compressionOverrides('chat'))['mode'], 'auto');
      await tester.tap(find.text(l10n.compressionAutoTitle));
      await tester.pumpAndSettle();
      expect(tester.widget<IosSwitch>(find.byType(IosSwitch)).value, isFalse);
      expect((await fixture.chat.compressionOverrides('chat'))['mode'], 'off');
      expect(
        (await fixture.chat.compressionOverrides('chat'))['summaryTokens'],
        8192,
      );
      expect(await fixture.chat.compressionOverrides('other'), isEmpty);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
    variant: TargetPlatformVariant({
      TargetPlatform.iOS,
      TargetPlatform.android,
    }),
  );
}
