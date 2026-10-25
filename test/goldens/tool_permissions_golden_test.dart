import 'dart:io';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/core/models/conversation.dart';
import 'package:Kelivo/core/models/tool_permission_mode.dart';
import 'package:Kelivo/core/providers/assistant_provider.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/providers/tts_provider.dart';
import 'package:Kelivo/core/providers/user_provider.dart';
import 'package:Kelivo/core/services/chat/chat_service.dart';
import 'package:Kelivo/core/services/workspace/tool_run_registry.dart';
import 'package:Kelivo/core/services/workspace/workspace_tool_metadata.dart';
import 'package:Kelivo/features/chat/widgets/chat_message_widget.dart';
import 'package:Kelivo/features/chat/widgets/tool_permission_widgets.dart';
import 'package:Kelivo/features/home/services/ask_user_interaction_service.dart';
import 'package:Kelivo/features/home/services/tool_approval_service.dart';
import 'package:Kelivo/icons/lucide_adapter.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/theme/theme_factory.dart';
import '../support/business_test_harness.dart';
import '../support/mcp_golden_fonts.dart';

class _Chat extends ChatService {
  _Chat(ToolPermissionMode mode)
    : conversation = Conversation(
        id: 'c1',
        title: 'Permissions',
        extras: mode.applyTo({'workspace.id': 'ws'}),
      );
  Conversation conversation;
  @override
  Conversation? getConversation(String id) => id == 'c1' ? conversation : null;
  @override
  Future<void> updateConversationExtras(
    String id,
    Map<String, dynamic> Function(Map<String, dynamic>) update, {
    Conversation? expectedOwner,
  }) async {
    conversation = conversation.copyWith(extras: update(conversation.extras));
    notifyListeners();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await loadMcpGoldenFonts();
    await (FontLoader('monospace')..addFont(
          Future.value(
            ByteData.sublistView(
              File(
                'test/fixtures/fonts/JetBrainsMono-Regular.ttf',
              ).readAsBytesSync(),
            ),
          ),
        ))
        .load();
    for (final channel in [
      'xyz.luan/audioplayers.global',
      'xyz.luan/audioplayers.global/events',
      'xyz.luan/audioplayers',
      'xyz.luan/audioplayers/events',
      'haptic_feedback',
      'flutter_tts',
    ]) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(MethodChannel(channel), (_) async => null);
    }
  });
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('flutter_tts'),
          (call) async => switch (call.method) {
            'getLanguages' => ['en-US'],
            'getEngines' => <String>[],
            'getVoices' => <Object>[],
            'isLanguageAvailable' => true,
            _ => null,
          },
        );
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
  });
  for (final mobile in [false, true]) {
    for (final dark in [false, true]) {
      for (final full in [false, true]) {
        final name =
            '${mobile ? 'mobile' : 'desktop'}_${dark ? 'dark' : 'light'}_${full ? 'full' : 'ask'}';
        testWidgets(
          'permission controls and approvals $name',
          (tester) async {
            tester.view.physicalSize = Size(mobile ? 390 : 760, 1050);
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.reset);
            final chat = _Chat(
              full
                  ? ToolPermissionMode.fullAccess
                  : ToolPermissionMode.requestApproval,
            );
            final approvals = ToolApprovalService();
            final parts = <ToolUIPart>[];
            for (final tool in ['read_file', 'shell', 'mcp_example']) {
              final id = 'pending-$tool';
              final args = tool == 'shell'
                  ? {'command': 'flutter test'}
                  : {'path': '/workspace/report.txt'};
              if (!full) {
                unawaited(
                  approvals.requestApproval(
                    toolCallId: id,
                    toolName: tool,
                    arguments: args,
                    conversationId: 'c1',
                    workspaceId: tool == 'mcp_example' ? null : 'ws',
                    requestedPath: tool == 'read_file'
                        ? '/workspace/report.txt'
                        : null,
                    realTarget: tool == 'read_file'
                        ? '/home/user/reports/report.txt'
                        : null,
                  ),
                );
              }
              parts.add(
                ToolUIPart(
                  id: id,
                  toolName: tool,
                  arguments: args,
                  loading: !full,
                  content: full ? 'Done' : null,
                  metadata: full
                      ? {
                          'toolPermission': 'fullAccess',
                          if (tool != 'mcp_example')
                            ...WorkspaceToolMetadata(
                              tool: tool,
                              status: 'ok',
                              exitCode: tool == 'shell' ? 0 : null,
                            ).toJson(),
                        }
                      : null,
                ),
              );
            }
            parts.add(
              ToolUIPart(
                id: 'hard-deny',
                toolName: 'write_file',
                arguments: const {'path': '/skills/SKILL.md'},
                metadata: const WorkspaceToolMetadata(
                  tool: 'write_file',
                  status: 'denied',
                  code: 'skills_readonly',
                  path: '/skills/SKILL.md',
                ).toJson(),
              ),
            );
            parts.add(
              const ToolUIPart(
                id: 'deny',
                toolName: 'mcp_example',
                arguments: {},
                metadata: {'toolPermissionError': 'approval_denied'},
              ),
            );
            final settings = SettingsProvider(createBusinessTestPreferences());
            await settings.loaded;
            final key = GlobalKey();
            await tester.pumpWidget(
              MultiProvider(
                providers: [
                  ChangeNotifierProvider<ChatService>.value(value: chat),
                  ChangeNotifierProvider.value(value: settings),
                  ChangeNotifierProvider(
                    create: (_) => AssistantProvider(
                      preferences: createBusinessTestPreferences(),
                    ),
                  ),
                  ChangeNotifierProvider(
                    create: (_) => TtsProvider(
                      preferences: createBusinessTestPreferences(),
                    ),
                  ),
                  ChangeNotifierProvider(
                    create: (_) => UserProvider(
                      preferences: createBusinessTestPreferences(),
                    ),
                  ),
                  ChangeNotifierProvider.value(value: approvals),
                  ChangeNotifierProvider(create: (_) => ToolRunRegistry()),
                  ChangeNotifierProvider(
                    create: (_) => AskUserInteractionService(),
                  ),
                ],
                child: MaterialApp(
                  debugShowCheckedModeBanner: false,
                  theme: (dark ? buildDarkTheme(null) : buildLightTheme(null))
                      .copyWith(
                        textTheme:
                            (dark
                                    ? buildDarkTheme(null)
                                    : buildLightTheme(null))
                                .textTheme
                                .apply(fontFamily: 'Roboto'),
                      ),
                  locale: const Locale('en'),
                  localizationsDelegates:
                      AppLocalizations.localizationsDelegates,
                  supportedLocales: AppLocalizations.supportedLocales,
                  home: Scaffold(
                    body: RepaintBoundary(
                      key: key,
                      child: Container(
                        color:
                            (dark
                                    ? buildDarkTheme(null)
                                    : buildLightTheme(null))
                                .scaffoldBackgroundColor,
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            ToolPermissionRow(
                              conversationId: 'c1',
                              ensureConversationId: () async => 'c1',
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                const Text('Conversation'),
                                const ToolPermissionBadge(conversationId: 'c1'),
                                const Spacer(),
                                ToolPermissionDot(
                                  conversationId: 'c1',
                                  child: Padding(
                                    padding: const EdgeInsets.all(8),
                                    child: Icon(
                                      mobile
                                          ? Lucide.ToolCase
                                          : Lucide.FolderCode,
                                      size: 24,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Expanded(
                              child: SingleChildScrollView(
                                child: ChatMessageWidget(
                                  showModelIcon: false,
                                  showToolCards: true,
                                  message: ChatMessage(
                                    id: 'm1',
                                    timestamp: DateTime(2026, 10, 24, 9, 41),
                                    role: 'assistant',
                                    conversationId: 'c1',
                                    content: '',
                                  ),
                                  toolParts: parts,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
            await tester.pump(const Duration(milliseconds: 400));
            expect(tester.takeException(), isNull);
            await expectLater(
              find.byKey(key),
              matchesGoldenFile('baselines/tool_permissions/$name.png'),
            );
            await tester.tap(find.byKey(ToolPermissionRow.rowKey));
            await tester.pump();
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 400));
            expect(find.byIcon(Lucide.Check), findsWidgets);
            await expectLater(
              find.byType(MaterialApp),
              matchesGoldenFile('baselines/tool_permissions/${name}_menu.png'),
            );
            approvals.cancelAll();
            await tester.pumpWidget(const SizedBox.shrink());
            await tester.pump();
            approvals.dispose();
            chat.dispose();
            settings.dispose();
          },
          variant: TargetPlatformVariant.only(
            mobile ? TargetPlatform.iOS : TargetPlatform.macOS,
          ),
        );
      }
    }
  }
}
