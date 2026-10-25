import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';
import 'package:Kelivo/core/database/app_database.dart';
import 'package:Kelivo/core/database/business_preferences.dart';
import 'package:Kelivo/core/database/extension_entity_store.dart';
import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/core/models/conversation.dart';
import 'package:Kelivo/core/models/workspace.dart';
import 'package:Kelivo/core/providers/assistant_provider.dart';
import 'package:Kelivo/core/providers/environment_provider.dart';
import 'package:Kelivo/core/providers/mcp_provider.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/providers/tts_provider.dart';
import 'package:Kelivo/core/providers/user_provider.dart';
import 'package:Kelivo/core/providers/workspace_provider.dart';
import 'package:Kelivo/core/services/chat/chat_service.dart';
import 'package:Kelivo/core/services/sandbox/environment_manager.dart';
import 'package:Kelivo/core/services/workspace/tool_run_registry.dart';
import 'package:Kelivo/core/services/workspace/workspace_runtime.dart';
import 'package:Kelivo/desktop/tools_popover.dart';
import 'package:Kelivo/desktop/workspace_dialog.dart';
import 'package:Kelivo/features/chat/widgets/chat_message_widget.dart';
import 'package:Kelivo/features/chat/widgets/chat_tools_sheet.dart';
import 'package:Kelivo/features/home/services/ask_user_interaction_service.dart';
import 'package:Kelivo/features/home/services/tool_approval_service.dart';
import 'package:Kelivo/icons/lucide_adapter.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/widgets/action_sheet.dart';
import 'package:Kelivo/theme/theme_factory.dart';
import '../test/support/business_test_harness.dart';

// Profile-only fixture. It uses in-memory preferences and a private documents
// directory, never the installed user's chats or workspace. This harness also
// compiles on the parent revision for an identical-device before/after run.
class _Paths extends PathProviderPlatform {
  _Paths(this.path);
  final String path;
  @override
  Future<String?> getApplicationDocumentsPath() async => path;
  @override
  Future<String?> getApplicationSupportPath() async => path;
  @override
  Future<String?> getApplicationCachePath() async => p.join(path, 'cache');
  @override
  Future<String?> getTemporaryPath() async => p.join(path, 'tmp');
}

class _Chat extends ChatService {
  _Chat(this.conversation);
  Conversation conversation;
  @override
  Conversation? getConversation(String id) =>
      id == conversation.id ? conversation : null;
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
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  const label = String.fromEnvironment(
    'PERMISSION_PERF_LABEL',
    defaultValue: 'after',
  );
  const capture = bool.fromEnvironment('PERMISSION_CAPTURE');
  const rounds = int.fromEnvironment(
    'PERMISSION_PERF_ROUNDS',
    defaultValue: 30,
  );
  testWidgets('profile conversation scrolling and permission surfaces', (
    tester,
  ) async {
    if (Platform.isMacOS || Platform.isWindows || Platform.isLinux) {
      await windowManager.ensureInitialized();
      await windowManager.setSize(const Size(1100, 800));
      await windowManager.show();
      await windowManager.focus();
    }
    final root = await Directory.systemTemp.createTemp(
      'kelivo_permission_profile_',
    );
    final original = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _Paths(root.path);
    final db = AppDatabase(NativeDatabase.memory());
    final preferences = createBusinessTestPreferences();
    final workspaces = WorkspaceProvider(store: ExtensionEntityStore(db));
    await workspaces.loaded;
    final workspace = await workspaces.create(
      name: 'Permission fixture',
      kind: WorkspaceKind.linked,
      hostPath: root.path,
    );
    final settings = SettingsProvider(preferences);
    await settings.loaded;
    final assistants = AssistantProvider(preferences: preferences);
    await assistants.loaded;
    final assistantId = await assistants.addAssistant(
      name: 'Permission fixture',
    );
    final environment = EnvironmentProvider(preferences: preferences);
    await environment.loaded;
    final chat = _Chat(
      Conversation(
        id: 'permission-profile',
        title: 'Permission fixture',
        assistantId: assistantId,
        extras: {
          'workspace.id': workspace.id,
          'tools.permission_mode': 'requestApproval',
        },
      ),
    );
    final approvals = ToolApprovalService();
    final navigator = GlobalKey<NavigatorState>();
    final anchor = GlobalKey();
    final surface = GlobalKey();
    final scroll = ScrollController();
    late BuildContext hostContext;
    final messages = List.generate(
      180,
      (i) => ChatMessage(
        id: 'message-$i',
        role: i.isEven ? 'user' : 'assistant',
        conversationId: chat.conversation.id,
        timestamp: DateTime(2026, 10, 24, 9, 41),
        content:
            'Message $i\n\nThe permission setting belongs to this conversation.\n\n```dart\nfinal mode = permissions.read(conversationId);\n```',
      ),
    );
    final results = <String, Object?>{
      'label': label,
      'platform': Platform.operatingSystem,
      'rounds': rounds,
    };
    Future<void> screenshot(String name) async {
      if (!capture) return;
      await tester.pump(const Duration(milliseconds: 500));
      final boundary =
          surface.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = boundary.toImageSync(pixelRatio: 1);
      try {
        final bytes = (await image.toByteData(format: ImageByteFormat.png))!;
        results['$name.png'] = base64Encode(
          bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
        );
      } finally {
        image.dispose();
      }
    }

    Future<void> measure(String name, Future<void> Function() exercise) async {
      await exercise();
      await tester.pump(const Duration(milliseconds: 600));
      final frames = <FrameTiming>[];
      void collect(List<FrameTiming> batch) => frames.addAll(batch);
      SchedulerBinding.instance.addTimingsCallback(collect);
      try {
        await exercise();
        await tester.pump(const Duration(milliseconds: 600));
      } finally {
        SchedulerBinding.instance.removeTimingsCallback(collect);
      }
      expect(frames, isNotEmpty);
      Map<String, Object> summary(Iterable<int> values) {
        final sorted = values.toList()..sort();
        return {
          'meanUs': sorted.reduce((a, b) => a + b) / sorted.length,
          'p90Us': sorted[((sorted.length - 1) * .9).round()],
        };
      }

      results[name] = {
        'frames': frames.length,
        'build': summary(frames.map((f) => f.buildDuration.inMicroseconds)),
        'raster': summary(frames.map((f) => f.rasterDuration.inMicroseconds)),
      };
      // ignore: avoid_print
      print('PERMISSION_PROFILE $label $name ${jsonEncode(results[name])}');
    }

    try {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<BusinessPreferences>.value(value: preferences),
            ChangeNotifierProvider.value(value: settings),
            ChangeNotifierProvider.value(value: assistants),
            ChangeNotifierProvider.value(value: workspaces),
            ChangeNotifierProvider.value(value: environment),
            ChangeNotifierProvider<ChatService>.value(value: chat),
            ChangeNotifierProvider.value(value: approvals),
            ChangeNotifierProvider(
              create: (_) => McpProvider(preferences: preferences),
            ),
            ChangeNotifierProvider(
              create: (_) => TtsProvider(preferences: preferences),
            ),
            ChangeNotifierProvider(
              create: (_) => UserProvider(preferences: preferences),
            ),
            ChangeNotifierProvider(create: (_) => ToolRunRegistry()),
            ChangeNotifierProvider(create: (_) => AskUserInteractionService()),
            ChangeNotifierProvider(create: (_) => WorkspaceRuntimeProvider()),
            Provider<EnvironmentManager?>.value(value: null),
          ],
          child: RepaintBoundary(
            key: surface,
            child: MaterialApp(
              navigatorKey: navigator,
              theme: buildLightTheme(null),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              locale: const Locale('en'),
              home: Scaffold(
                body: Builder(
                  builder: (context) {
                    hostContext = context;
                    return Column(
                      children: [
                        IconButton(
                          key: anchor,
                          onPressed: () {},
                          icon: const Icon(Lucide.ToolCase),
                        ),
                        Expanded(
                          child: ListView.builder(
                            controller: scroll,
                            itemCount: messages.length,
                            itemBuilder: (_, i) => ChatMessageWidget(
                              message: messages[i],
                              showModelIcon: false,
                              showToolCards: true,
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 2));
      await measure('long_chat_scroll', () async {
        for (var i = 0; i < rounds; i++) {
          await scroll.animateTo(
            i.isEven ? 2400 : 0,
            duration: const Duration(milliseconds: 300),
            curve: Curves.linear,
          );
          await tester.pump(const Duration(milliseconds: 50));
        }
      });
      await measure('workspace_dialog', () async {
        for (var i = 0; i < rounds; i++) {
          unawaited(
            showDesktopWorkspaceDialog(
              hostContext,
              conversationListenable: chat,
              conversationId: () => chat.conversation.id,
              assistantId: assistantId,
            ),
          );
          await tester.pump(const Duration(milliseconds: 350));
          navigator.currentState!.pop();
          await tester.pump(const Duration(milliseconds: 350));
        }
      });
      await measure('tools_menu', () async {
        for (var i = 0; i < rounds; i++) {
          if (Platform.isMacOS || Platform.isWindows || Platform.isLinux) {
            unawaited(
              showDesktopToolsPopover(
                hostContext,
                anchorKey: anchor,
                assistantId: assistantId,
                supportsModelTools: true,
                conversationId: chat.conversation.id,
              ),
            );
            await tester.pump(const Duration(milliseconds: 350));
            await tester.tapAt(const Offset(2, 2));
          } else {
            unawaited(
              showChatToolsSheet(
                hostContext,
                assistantId: assistantId,
                conversationId: chat.conversation.id,
              ),
            );
            await tester.pump(const Duration(milliseconds: 350));
            navigator.currentState!.pop();
          }
          await tester.pump(const Duration(milliseconds: 350));
        }
      });
      await measure('permission_menu', () async {
        for (var i = 0; i < rounds; i++) {
          final size = MediaQuery.sizeOf(hostContext);
          unawaited(
            showAdaptiveActionMenu(
              hostContext,
              anchor: Offset(size.width * .5, 80),
              title: 'Permissions',
              items: [
                ActionSheetItem(
                  icon: Lucide.Shield,
                  label: 'Ask for approval',
                  onTap: () {},
                ),
                ActionSheetItem(
                  icon: Lucide.Shield,
                  label: 'Full access',
                  onTap: () {},
                ),
              ],
            ),
          );
          await tester.pump(const Duration(milliseconds: 300));
          if (Platform.isMacOS || Platform.isWindows || Platform.isLinux) {
            await tester.tapAt(const Offset(2, 2));
          } else {
            navigator.currentState!.pop();
          }
          await tester.pump(const Duration(milliseconds: 300));
        }
      });
      if (capture) {
        unawaited(
          showDesktopWorkspaceDialog(
            hostContext,
            conversationListenable: chat,
            conversationId: () => chat.conversation.id,
            assistantId: assistantId,
          ),
        );
        await screenshot('workspace_ask');
        await chat.updateConversationExtras(
          chat.conversation.id,
          (extras) => {...extras, 'tools.permission_mode': 'fullAccess'},
        );
        await screenshot('workspace_full');
        navigator.currentState!.pop();
        await tester.pump(const Duration(milliseconds: 400));
      }
      binding.reportData = results;
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 6));
    } finally {
      PathProviderPlatform.instance = original;
      scroll.dispose();
      chat.dispose();
      approvals.dispose();
      workspaces.dispose();
      environment.dispose();
      settings.dispose();
      assistants.dispose();
      await db.close();
      await root.delete(recursive: true);
    }
  }, timeout: const Timeout(Duration(minutes: 12)));
}
