// Opt-in widget captures; requires CARD_PREVIEW_FONT pointing to a local CJK font.
// flutter test test/perf/browser_page_card_preview.dart --dart-define=CARD_PREVIEW_FONT=... --dart-define=CARD_PREVIEW_OUTPUT=...
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/core/models/message_part.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/providers/tts_provider.dart';
import 'package:Kelivo/features/chat/widgets/chat_message_widget.dart';
import 'package:Kelivo/features/home/services/ask_user_interaction_service.dart';
import 'package:Kelivo/features/home/services/local_tools_service.dart';
import 'package:Kelivo/features/home/services/tool_approval_service.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/theme/palettes.dart';
import '../support/business_test_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    for (final name in [
      'xyz.luan/audioplayers.global',
      'xyz.luan/audioplayers.global/events',
      'xyz.luan/audioplayers',
    ]) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(MethodChannel(name), (_) async => null);
    }
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('xyz.luan/audioplayers'),
          (call) async {
            if (call.method == 'create') {
              final id = (call.arguments as Map)['playerId'];
              TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
                  .setMockMethodCallHandler(
                    MethodChannel('xyz.luan/audioplayers/events/$id'),
                    (_) async => null,
                  );
            }
            return null;
          },
        );
    final font = const String.fromEnvironment('CARD_PREVIEW_FONT');
    if (font.isEmpty) {
      throw StateError('Set CARD_PREVIEW_FONT to a local CJK font');
    }
    final text = FontLoader('CardPreview')
      ..addFont(
        File(font).readAsBytes().then((bytes) => ByteData.sublistView(bytes)),
      );
    await text.load();
    final icons = FontLoader('packages/lucide_icons_flutter/Lucide')
      ..addFont(
        rootBundle.load('packages/lucide_icons_flutter/assets/lucide.ttf'),
      );
    await icons.load();
  });
  ToolCallPart tool(
    String id,
    String action, {
    bool loading = false,
    bool failed = false,
  }) => ToolCallPart(
    jsonEncode({
      'id': id,
      'name': LocalToolNames.browser,
      'arguments': {
        'action': action,
        'url': 'https://github.com/Chevey339/kelivo',
        'ref': 'e1',
      },
      if (!loading)
        'content': jsonEncode(
          failed
              ? {'ok': false, 'error': 'stale_ref'}
              : {
                  'ok': true,
                  'page': {
                    'tab_id': 'preview-tab',
                    'url': 'https://github.com/Chevey339/kelivo',
                    'title': 'Kelivo — 开源 AI 助手与 Agent 客户端',
                    'elements': [
                      {'ref': 'e1', 'name': 'Releases'},
                    ],
                    'content': '字' * 3200,
                  },
                },
        ),
    }),
  );
  for (final scene in ['phone-light', 'phone-dark', 'desktop']) {
    testWidgets('browser message capture $scene', (tester) async {
      final desktop = scene == 'desktop';
      final dark = scene == 'phone-dark';
      tester.view.physicalSize = Size(desktop ? 1100 : 390, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      late BusinessTestHarness harness;
      late SettingsProvider settings;
      await tester.runAsync(() async {
        harness = await createBusinessTestHarness();
        settings = SettingsProvider(harness.preferences);
        await settings.loaded;
        await settings.setCollapseThinkingSteps(false);
      });
      final boundary = GlobalKey();
      Widget message(String id, List<MessagePart> parts) => ChatMessageWidget(
        message: ChatMessage(
          id: id,
          conversationId: 'preview',
          role: 'assistant',
          parts: parts,
          timestamp: DateTime(2026, 10, 21, 10),
          modelId: 'Kelivo',
        ),
        showModelIcon: false,
        showTokenStats: false,
        useAssistantName: true,
        assistantName: 'Kelivo',
      );
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: settings),
            ChangeNotifierProvider(create: (_) => ToolApprovalService()),
            ChangeNotifierProvider(create: (_) => AskUserInteractionService()),
            ChangeNotifierProvider(
              create: (_) => TtsProvider(preferences: harness.preferences),
            ),
          ],
          child: MaterialApp(
            locale: const Locale('zh'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: ThemeData(
              colorScheme: dark
                  ? ThemePalettes.defaultPalette.dark
                  : ThemePalettes.defaultPalette.light,
              brightness: dark ? Brightness.dark : Brightness.light,
              fontFamily: 'CardPreview',
              platform: desktop ? TargetPlatform.macOS : TargetPlatform.iOS,
            ),
            home: MediaQuery(
              data: MediaQueryData(
                size: Size(desktop ? 1100 : 390, 1000),
                disableAnimations: true,
              ),
              child: RepaintBoundary(
                key: boundary,
                child: Scaffold(
                  body: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: desktop ? 190 : 12,
                      vertical: 24,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        message('complete', [
                          const ReasoningPart('先查看项目页面，再确认更新内容。'),
                          tool('a', 'open'),
                          tool('b', 'snapshot'),
                          tool('c', 'click'),
                          tool('d', 'extract'),
                          const TextPart('已经整理好了页面中的主要内容。'),
                        ]),
                        const SizedBox(height: 24),
                        message('partial', [
                          tool('e', 'open'),
                          tool('f', 'snapshot'),
                          tool('g', 'click', failed: true),
                        ]),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(tester.takeException(), isNull);
      await tester.runAsync(() async {
        final image =
            await (boundary.currentContext!.findRenderObject()
                    as RenderRepaintBoundary)
                .toImage(pixelRatio: 2);
        final bytes = (await image.toByteData(format: ui.ImageByteFormat.png))!;
        final output = const String.fromEnvironment(
          'CARD_PREVIEW_OUTPUT',
          defaultValue: 'build/browser-card-preview',
        );
        await Directory(output).create(recursive: true);
        await File(
          '$output/$scene.png',
        ).writeAsBytes(bytes.buffer.asUint8List());
        image.dispose();
      });
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      settings.dispose();
    });
  }
}
