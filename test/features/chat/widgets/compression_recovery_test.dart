import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/core/models/compress_context_options.dart';
import 'package:Kelivo/core/models/context_compression_task.dart';
import 'package:Kelivo/core/providers/assistant_provider.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/chat/chat_service.dart';
import 'package:Kelivo/features/chat/widgets/compress_context_options_dialog.dart';
import 'package:Kelivo/features/chat/widgets/compression_error_notice.dart';
import 'package:Kelivo/features/chat/widgets/context_compression_status.dart';
import 'package:Kelivo/features/chat/widgets/context_operation_actions.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/l10n/app_localizations_en.dart';
import 'package:Kelivo/l10n/app_localizations_zh.dart';
import 'package:Kelivo/shared/widgets/ios_form_text_field.dart';
import 'package:Kelivo/shared/widgets/ios_text_button.dart';
import 'package:Kelivo/theme/theme_factory.dart';

import '../../../support/business_test_harness.dart';
import '../../../support/compression_options_pump.dart';

void check(String name, WidgetTesterCallback body) {
  testWidgets(name, (tester) async {
    try {
      await body(tester);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}

void main() {
  final en = AppLocalizationsEn();
  final zh = AppLocalizationsZh();

  test('empty model output is not treated as a blank summary editor', () {
    for (final l10n in [en, zh]) {
      expect(
        compressionErrorLabel(l10n, StateError('empty_summary').toString()),
        l10n.compressContextEmptySummary,
      );
    }
  });

  test('truncation and refusal have different recovery actions', () {
    var adjusted = false;
    var retried = false;
    for (final reason in ['length', 'max_output_tokens', 'max_tokens']) {
      final actions = compressionRecoveryActions(
        en,
        error: StateError('compression_incomplete:$reason').toString(),
        native: false,
        onRetry: () => retried = true,
        onAdjust: () => adjusted = true,
      );
      expect(actions.first.label, en.compressionOutputBudget);
      actions.first.onTap();
    }
    expect(adjusted, isTrue);
    expect(retried, isFalse);
    for (final reason in [
      'refusal',
      'content_filter',
      'safety',
      'tool_calls',
    ]) {
      expect(
        compressionRecoveryTarget('Bad state: compression_incomplete:$reason'),
        CompressionRecoveryTarget.model,
      );
    }
  });

  test(
    'timeouts and network failures offer retry before changing settings',
    () {
      for (final error in [
        'request_timeout:120000000',
        'SocketException: connection reset',
      ]) {
        final actions = compressionRecoveryActions(
          en,
          error: error,
          native: false,
          onRetry: () {},
          onAdjust: () {},
        );
        expect(actions.first.label, en.compressTaskRetry);
      }
      expect(
        compressionErrorLabel(zh, 'request_timeout:120000000'),
        zh.compressionRequestTimedOut(2),
      );
    },
  );

  test('server-side failures never point at text-only output settings', () {
    expect(
      compressionErrorLabel(
        en,
        'Bad state: native_compaction_input_overridden',
      ),
      en.compressionNativeInputOverride,
    );
    expect(
      compressionRecoveryTarget('compression_incomplete:length', native: true),
      isNull,
    );
    expect(
      compressionRecoveryTarget('context_budget_exceeded', native: true),
      CompressionRecoveryTarget.range,
    );
  });

  check('unknown error stays in expandable, copyable details', (tester) async {
    const raw = 'HTTP 503\n{"error":"upstream overloaded","request_id":"test"}';
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') copied = call.arguments['text'];
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(body: CompressionErrorNotice(error: raw)),
      ),
    );
    expect(find.text(en.compressContextFailed), findsOneWidget);
    expect(find.text(raw), findsNothing);
    await tester.tap(find.text(en.startupRecoveryShowDetails));
    await tester.pumpAndSettle();
    expect(find.text(raw), findsOneWidget);
    await tester.tap(find.text(en.backupProgressCopyError));
    await tester.pump();
    expect(copied, raw);
    expect(tester.takeException(), isNull);
  });

  for (final platform in [TargetPlatform.android, TargetPlatform.macOS]) {
    for (final entry in [
      (
        error: 'compression_incomplete:max_output_tokens',
        label: zh.compressionOutputBudget,
      ),
      (error: 'compression_request_budget', label: zh.compressionRequests),
      (error: 'request_timeout:120000000', label: zh.compressionRequestTimeout),
    ]) {
      check('failure action opens ${entry.error} setting on $platform', (
        tester,
      ) async {
        debugDefaultTargetPlatformOverride = platform;
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = platform == TargetPlatform.android
            ? const Size(393, 852)
            : const Size(1200, 800);
        late SettingsProvider settings;
        late AssistantProvider assistants;
        final chat = ChatService();
        await tester.runAsync(() async {
          settings = SettingsProvider(createBusinessTestPreferences());
          assistants = AssistantProvider(
            preferences: createBusinessTestPreferences(),
          );
          await Future.wait([settings.loaded, assistants.loaded]);
        });
        addTearDown(() async {
          await tester.pumpWidget(const SizedBox.shrink());
          settings.dispose();
          assistants.dispose();
          chat.dispose();
          debugDefaultTargetPlatformOverride = null;
          tester.view.resetDevicePixelRatio();
          tester.view.resetPhysicalSize();
        });
        final before = settings.compressionDefaults.toJson();
        var retries = 0;
        final task = ContextCompressionTask(
          id: 'failed',
          conversationId: 'chat',
          options: const CompressContextOptions(
            mode: CompressContextLimitMode.keepRecent,
            keepUserMessages: 2,
          ),
          phase: CompressionPhase.failed,
        )..error = StateError(entry.error).toString();
        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider.value(value: settings),
              ChangeNotifierProvider.value(value: assistants),
            ],
            child: MaterialApp(
              locale: const Locale('zh'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              theme: buildLightTheme(null),
              home: Scaffold(
                body: Builder(
                  builder: (context) => Center(
                    child: IosTextButton(
                      label: 'Open',
                      onPressed: () => showContextCompressionMenu(
                        context,
                        chat: chat,
                        task: task,
                        anchor: const Offset(200, 200),
                        onRetry: () => retries++,
                        onAdjust: () => showCompressContextOptions(
                          context: context,
                          builder: (sheet) => CompressContextOptionsDialog(
                            sheet: sheet,
                            initialOptions: task.options,
                            initialError: task.error,
                            loadHistory: () async =>
                                CompressionHistory.fromMessages([
                                  for (var i = 0; i < 10; i++)
                                    ChatMessage(
                                      id: 'u$i',
                                      role: 'user',
                                      content: 'Turn $i',
                                      conversationId: 'chat',
                                    ),
                                ], const []),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        await tester.tap(find.text(zh.ttsServicesDialogErrorTitle));
        await tester.pumpAndSettle();
        expect(find.text(task.error!), findsOneWidget);
        expect(
          find.byType(BottomSheet),
          platform == TargetPlatform.android ? findsOneWidget : findsNothing,
        );
        await tester.tap(find.text(zh.contextTaskDismiss));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        await tester.tap(find.text(entry.label));
        await settleCompressionOptions(tester);
        final field = find.descendant(
          of: find.widgetWithText(IosFormTextField, entry.label),
          matching: find.byType(TextField),
        );
        expect(field.hitTestable(), findsOneWidget);
        expect(settings.compressionDefaults.toJson(), before);
        expect(retries, 0);
        expect(task.phase, CompressionPhase.failed);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
