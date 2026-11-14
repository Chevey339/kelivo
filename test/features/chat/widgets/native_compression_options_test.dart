import '../../../support/compression_options_pump.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/core/models/conversation.dart';
import 'package:Kelivo/core/models/compress_context_options.dart';
import 'package:Kelivo/core/models/compression_config.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/providers/assistant_provider.dart';
import 'package:Kelivo/core/database/chat_database_repository.dart';
import 'package:Kelivo/core/services/chat/chat_service.dart';
import 'package:Kelivo/desktop/widgets/desktop_select_dropdown.dart';
import 'package:Kelivo/features/chat/widgets/compress_context_options_dialog.dart';
import 'package:Kelivo/shared/widgets/ios_switch.dart';
import 'package:Kelivo/shared/widgets/ios_form_text_field.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import '../../../support/business_test_harness.dart';

class _NativeOptionsChat extends ChatService {
  _NativeOptionsChat({required super.existingRepository});
  bool temporary = false;
  @override
  bool isTemporaryConversation(String? id) =>
      temporary || super.isTemporaryConversation(id);
  final _conversations = {
    'c': Conversation(id: 'c', title: 'Current'),
    'other': Conversation(id: 'other', title: 'Other'),
  };
  @override
  Conversation? getConversation(String id) => _conversations[id];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('haptic_feedback'),
          (_) async => null,
        );
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('haptic_feedback'), null);
  });
  for (final mobile in [false, true]) {
    testWidgets('native choice is unrestricted and independent mobile=$mobile', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = mobile
          ? TargetPlatform.iOS
          : TargetPlatform.macOS;
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = mobile
          ? const Size(393, 852)
          : const Size(1200, 900);
      late SettingsProvider settings;
      late AssistantProvider assistants;
      late ChatService chat;
      late String conversationId;
      await tester.runAsync(() async {
        final harness = await createBusinessTestHarness();
        settings = SettingsProvider(harness.preferences);
        await settings.loaded;
        assistants = AssistantProvider(preferences: harness.preferences);
        await assistants.loaded;
        chat = _NativeOptionsChat(
          existingRepository: ChatDatabaseRepository(harness.database),
        );
        conversationId = 'c';
        await settings.setProviderConfig(
          'private',
          ProviderConfig(
            id: 'private',
            name: 'Self hosted',
            enabled: true,
            baseUrl: 'https://self-hosted.example/api',
            apiKey: 'test',
            models: const ['unknown-model'],
            useResponseApi: false,
          ),
        );
        await settings.setCurrentModel('private', 'unknown-model');
        await settings.setCompressionDefaults(
          const CompressionConfig(
            mode: AutoCompressionMode.auto,
            keepRecentUserTurns: 2,
            templateId: 'code',
            summaryTokens: 8192,
            requestTimeoutMinutes: 7,
          ),
        );
      });
      addTearDown(() {
        settings.dispose();
        assistants.dispose();
        chat.dispose();
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        debugDefaultTargetPlatformOverride = null;
      });
      final original = settings.compressionDefaults.toJson();
      CompressContextOptions? result;
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: settings),
            ChangeNotifierProvider.value(value: assistants),
            ChangeNotifierProvider.value(value: chat),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  child: const Text('Open'),
                  onPressed: () async {
                    result = await showCompressContextOptions(
                      context: context,
                      builder: (sheet) => CompressContextOptionsDialog(
                        sheet: sheet,
                        conversationId: conversationId,
                        loadHistory: () async =>
                            CompressionHistory.fromMessages([
                              for (var i = 0; i < 10; i++)
                                ChatMessage(
                                  id: 'u$i',
                                  role: 'user',
                                  content: 'Turn $i',
                                  conversationId: conversationId,
                                ),
                            ], const []),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      );
      Future<void> open() async {
        await tester.tap(find.text('Open'));
        await settleCompressionOptions(tester);
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await settleCompressionOptions(tester);
      }

      await open();
      final l10n = AppLocalizations.of(
        tester.element(find.byType(CompressContextOptionsDialog)),
      )!;
      final toggle = find.byWidgetPredicate(
        (w) => w is IosSwitch && w.semanticLabel == l10n.compressionNativeTitle,
      );
      Finder keep() => find.descendant(
        of: find.widgetWithText(IosFormTextField, l10n.compressionKeepTurns),
        matching: find.byType(TextField),
      );
      Future<void> flip() async {
        FocusManager.instance.primaryFocus?.unfocus();
        await settleCompressionOptions(tester);
        await tester.ensureVisible(toggle);
        await settleCompressionOptions(tester);
        await tester.tap(toggle);
        await settleCompressionOptions(tester);
      }

      expect(tester.widget<IosSwitch>(toggle).value, isFalse);
      await flip();
      expect(find.text(l10n.compressionManage), findsNothing);
      expect(find.text(l10n.compressionMore), findsOneWidget);
      expect(find.text('unknown-model'), findsOneWidget);
      await tester.ensureVisible(keep());
      await tester.enterText(keep(), '');
      await flip(); // Invalid native draft must still allow returning to text.
      expect(tester.widget<TextField>(keep()).controller!.text, '2');
      await flip();
      await tester.ensureVisible(keep());
      await tester.enterText(keep(), '3');
      await tester.ensureVisible(find.text(l10n.compressionMore));
      await tester.tap(find.text(l10n.compressionMore));
      await settleCompressionOptions(tester);
      final trigger = find.descendant(
        of: find.widgetWithText(IosFormTextField, l10n.compressionTrigger),
        matching: find.byType(TextField),
      );
      await tester.ensureVisible(trigger);
      await tester.enterText(trigger, '50');
      final timeout = find.descendant(
        of: find.widgetWithText(
          IosFormTextField,
          l10n.compressionRequestTimeout,
        ),
        matching: find.byType(TextField),
      );
      expect(tester.widget<TextField>(timeout).controller!.text, '7');
      expect(find.text(l10n.compressionAdvancedOptions), findsNothing);
      await tester.ensureVisible(timeout);
      await tester.enterText(timeout, '0');
      await tester.tap(find.text(l10n.multiKeyPageSave));
      await settleCompressionOptions(tester);
      expect(find.text(l10n.compressionInvalidSettings), findsOneWidget);
      await tester.ensureVisible(timeout);
      await tester.enterText(timeout, '10.5');
      await tester.tap(find.text(l10n.multiKeyPageSave));
      for (var i = 0; i < 100 && trigger.evaluate().isNotEmpty; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await tester.pump();
      }
      await settleCompressionOptions(tester);
      expect(find.text(l10n.compressionInvalidSettings), findsNothing);
      expect(trigger, findsNothing);
      final scope = find.byWidgetPredicate(
        (w) => w is DesktopSelectDropdown<CompressContextLimitMode>,
      );
      await tester.ensureVisible(scope);
      await settleCompressionOptions(tester);
      await tester.tap(scope);
      await settleCompressionOptions(tester);
      expect(find.text(l10n.compressionScopeKeepHint), findsNothing);
      expect(find.text(l10n.compressionNativeScopeHint), findsWidgets);
      expect(
        find.text(l10n.compressContextKeepRecent).hitTestable(),
        findsNothing,
      );
      await tester.tap(find.text(l10n.compressContextUnlimited).last);
      await settleCompressionOptions(tester);
      await tester.tap(find.text(l10n.compressContextStartButton));
      for (var i = 0; i < 100 && result == null; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await tester.pump();
      }
      await settleCompressionOptions(tester);
      expect(result!.native, isTrue);
      expect(result!.mode, CompressContextLimitMode.unlimited);
      expect(settings.nativeCompression.enabled, isTrue);
      expect(settings.nativeCompression.allHistory, isTrue);
      expect(settings.nativeCompression.keepUserTurns, 3);
      expect(settings.compressionDefaults.toJson(), original);
      await tester.runAsync(() async {
        final config = await chat.compressionConfig(
          conversationId,
          settings.compressionDefaults,
        );
        expect(config.nativeEnabled, isTrue);
        expect(config.nativeKeepRecentUserTurns, 3);
        expect(config.nativeTriggerInputRatio, .5);
        expect(config.requestTimeout, const Duration(minutes: 10, seconds: 30));
        expect(config.triggerInputRatio, .8);
        expect(config.targetInputRatio, .6);
        expect(config.keepRecentUserTurns, 2);
        expect(
          (await chat.compressionConfig(
            'other',
            settings.compressionDefaults,
          )).nativeEnabled,
          isFalse,
        );
      });
      expect(settings.compressLimitMode, CompressContextLimitMode.keepRecent);
      await open();
      expect(tester.widget<IosSwitch>(toggle).value, isTrue);
      expect(keep(), findsNothing);
      await flip();
      expect(tester.widget<TextField>(keep()).controller!.text, '2');
      expect(find.text(l10n.compressionManage), findsOneWidget);
      await tester.ensureVisible(find.text(l10n.compressionMore));
      await tester.tap(find.text(l10n.compressionMore));
      await settleCompressionOptions(tester);
      expect(tester.widget<TextField>(trigger).controller!.text, '80');
      expect(tester.widget<TextField>(timeout).controller!.text, '10.5');
      expect(find.text(l10n.compressionAdvancedOptions), findsOneWidget);
      await tester.ensureVisible(timeout);
      await tester.enterText(timeout, '');
      await tester.tap(find.text(l10n.multiKeyPageSave));
      await tester.runAsync(() async {
        for (var i = 0; i < 100; i++) {
          final values = await chat.compressionOverrides(conversationId);
          if (values.containsKey('requestTimeoutMinutes') &&
              values['requestTimeoutMinutes'] == null) {
            return;
          }
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
        fail('cleared timeout was not saved');
      });
      await settleCompressionOptions(tester);
      await tester.runAsync(() async {
        final config = await chat.compressionConfig(
          conversationId,
          settings.compressionDefaults,
        );
        expect(config.requestTimeout, isNull);
        expect(settings.compressionDefaults.requestTimeoutMinutes, 7);
      });
      expect(tester.takeException(), isNull);
      await tester.tap(find.text(l10n.homePageCancel));
      await settleCompressionOptions(tester);
      conversationId = 'other';
      (chat as _NativeOptionsChat).temporary = true;
      await open();
      expect(tester.widget<IosSwitch>(toggle).value, isFalse);
      await flip();
      final newChat = find.byWidgetPredicate(
        (w) =>
            w is IosSwitch && w.semanticLabel == l10n.compressNewConversation,
      );
      await tester.ensureVisible(newChat);
      await tester.tap(newChat);
      await settleCompressionOptions(tester);
      expect(
        find.text(l10n.compressionNativeTemporaryCopyHint),
        findsOneWidget,
      );
      expect(find.text(l10n.compressionNativeCopyHint), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      debugDefaultTargetPlatformOverride = null;
    });
  }
}
