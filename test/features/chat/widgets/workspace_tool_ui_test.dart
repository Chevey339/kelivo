import 'dart:async';
import 'dart:convert';

import '../../../support/business_test_harness.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/core/providers/assistant_provider.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/providers/tts_provider.dart';
import 'package:Kelivo/core/providers/user_provider.dart';
import 'package:Kelivo/core/services/workspace/tool_run_registry.dart';
import 'package:Kelivo/core/services/workspace/workspace_tool_metadata.dart';
import 'package:Kelivo/features/chat/widgets/chat_message_widget.dart';
import 'package:Kelivo/features/home/services/ask_user_interaction_service.dart';
import 'package:Kelivo/features/chat/widgets/workspace_tool_detail.dart';
import 'package:Kelivo/features/chat/widgets/workspace_tool_ui.dart';
import 'package:Kelivo/features/home/services/tool_approval_service.dart';
import 'package:Kelivo/features/workspace/workspace_navigation.dart';
import 'package:Kelivo/icons/lucide_adapter.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/widgets/custom_bottom_sheet.dart';
import 'package:Kelivo/shared/widgets/ios_form_text_field.dart';

ToolUIPart _uiPart({
  required String tool,
  WorkspaceToolMetadata? meta,
  String id = 'tc-1',
  Map<String, dynamic>? arguments,
  String? content,
  bool loading = false,
  Map<String, dynamic>? extraMetadata,
}) {
  return ToolUIPart(
    id: id,
    toolName: tool,
    arguments: arguments ?? const <String, dynamic>{},
    content: content,
    metadata: meta == null && extraMetadata == null
        ? null
        : <String, dynamic>{...?meta?.toJson(), ...?extraMetadata},
    loading: loading,
  );
}

Widget _harness({
  required List<ToolUIPart> toolParts,
  ToolRunRegistry? registry,
  ToolApprovalService? approval,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(
        create: (_) => SettingsProvider(createBusinessTestPreferences()),
      ),
      ChangeNotifierProvider(
        create: (_) =>
            AssistantProvider(preferences: createBusinessTestPreferences()),
      ),
      ChangeNotifierProvider(
        create: (_) =>
            TtsProvider(preferences: createBusinessTestPreferences()),
      ),
      ChangeNotifierProvider(
        create: (_) =>
            UserProvider(preferences: createBusinessTestPreferences()),
      ),
      ChangeNotifierProvider(create: (_) => registry ?? ToolRunRegistry()),
      ChangeNotifierProvider(create: (_) => approval ?? ToolApprovalService()),
      ChangeNotifierProvider(create: (_) => AskUserInteractionService()),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: ChatMessageWidget(
          showModelIcon: false,
          showToolCards: true,
          message: ChatMessage(
            id: 'm1',
            role: 'assistant',
            conversationId: 'c1',
            content: '',
          ),
          toolParts: toolParts,
        ),
      ),
    ),
  );
}

Finder get _timelineIconColumn =>
    find.byKey(const ValueKey('chatMessageTimelineIconColumn:true:true'));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    WorkspaceNavigation.onOpenEnvironmentPage = null;
    WorkspaceNavigation.onOpenTerminal = null;
    WorkspaceNavigation.onOpenWorkspaceFiles = null;
  });

  testWidgets(
    'each workspace tool renders its title and icon in the timeline',
    (tester) async {
      const cases = <(String, IconData, String)>[
        ('shell', Lucide.Terminal, 'Run command'),
        ('read_file', Lucide.FileText, 'Read file'),
        ('write_file', Lucide.FilePlus, 'Write file'),
        ('edit_file', Lucide.FilePen, 'Edit file'),
        ('list_dir', Lucide.FolderOpen, 'List directory'),
        ('glob', Lucide.FileSearch, 'Glob'),
        ('grep', Lucide.TextSearch, 'Grep'),
      ];
      for (final (tool, icon, title) in cases) {
        await tester.pumpWidget(
          _harness(
            toolParts: [
              _uiPart(
                tool: tool,
                arguments: {
                  'command': 'ls',
                  'path': 'src/app.dart',
                  'pattern': '*.dart',
                  'content': 'a\nb\n',
                },
                meta: WorkspaceToolMetadata(
                  tool: tool,
                  status: 'ok',
                  path: 'src/app.dart',
                  command: 'ls',
                  added: 1,
                  removed: 1,
                  count: 2,
                ),
              ),
            ],
          ),
        );
        await tester.pump();
        expect(_timelineIconColumn, findsOneWidget);
        expect(find.text(title), findsOneWidget);
        expect(find.byIcon(icon), findsWidgets);
        expect(find.byIcon(Lucide.ChevronRight), findsOneWidget);
      }
    },
  );

  testWidgets('status for running / exit 0 / exit 1', (tester) async {
    await tester.pumpWidget(
      _harness(
        toolParts: [
          const ToolUIPart(
            id: 'run-1',
            toolName: 'shell',
            arguments: {'command': 'sleep 1'},
            loading: true,
          ),
        ],
      ),
    );
    await tester.pump();
    expect(find.byType(LoadingIndicator), findsOneWidget);
    expect(find.byKey(WorkspaceStatusBadge.runningKey), findsOneWidget);
    expect(find.text('Running'), findsNothing);

    await tester.pumpWidget(
      _harness(
        toolParts: [
          _uiPart(
            tool: 'shell',
            meta: const WorkspaceToolMetadata(
              tool: 'shell',
              status: 'ok',
              command: 'ls -la',
              exitCode: 0,
              durationMs: 1200,
            ),
          ),
        ],
      ),
    );
    await tester.pump();

    expect(find.text('ls -la'), findsOneWidget);
    expect(find.byKey(WorkspaceStatusBadge.exitZeroKey), findsOneWidget);
    expect(find.textContaining('exit 0'), findsOneWidget);
    expect(find.textContaining('1.2s'), findsOneWidget);
    final exitZero = tester.widget<Text>(
      find.byKey(WorkspaceStatusBadge.exitZeroKey),
    );
    expect(exitZero.style?.color, isNotNull);

    await tester.pumpWidget(
      _harness(
        toolParts: [
          _uiPart(
            tool: 'shell',
            meta: const WorkspaceToolMetadata(
              tool: 'shell',
              status: 'error',
              command: 'false',
              exitCode: 1,
            ),
          ),
        ],
      ),
    );
    await tester.pump();

    expect(find.byKey(WorkspaceStatusBadge.exitErrorKey), findsOneWidget);
    expect(find.textContaining('exit 1'), findsOneWidget);
    final errorStatus = tester.widget<Text>(
      find.byKey(WorkspaceStatusBadge.exitErrorKey),
    );
    final errorContext = tester.element(
      find.byKey(WorkspaceStatusBadge.exitErrorKey),
    );
    expect(errorStatus.style?.color, Theme.of(errorContext).colorScheme.error);
  });

  testWidgets('status for cancelled / timeout', (tester) async {
    await tester.pumpWidget(
      _harness(
        toolParts: [
          _uiPart(
            tool: 'shell',
            meta: const WorkspaceToolMetadata(
              tool: 'shell',
              status: 'cancelled',
              command: 'sleep 99',
              cancelled: true,
            ),
          ),
        ],
      ),
    );
    await tester.pump();
    expect(find.byKey(WorkspaceStatusBadge.cancelledKey), findsOneWidget);
    expect(find.textContaining('cancelled'), findsOneWidget);

    await tester.pumpWidget(
      _harness(
        toolParts: [
          _uiPart(
            tool: 'shell',
            meta: const WorkspaceToolMetadata(
              tool: 'shell',
              status: 'timeout',
              command: 'sleep 99',
              timedOut: true,
            ),
          ),
        ],
      ),
    );
    await tester.pump();
    expect(find.byKey(WorkspaceStatusBadge.timeoutKey), findsOneWidget);
    expect(find.textContaining('timeout'), findsOneWidget);
  });

  testWidgets('shell timeout and denied badges', (tester) async {
    await tester.pumpWidget(
      _harness(
        toolParts: [
          _uiPart(
            tool: 'shell',
            meta: const WorkspaceToolMetadata(
              tool: 'shell',
              status: 'timeout',
              command: 'sleep 99',
              timedOut: true,
            ),
          ),
        ],
      ),
    );
    await tester.pump();
    expect(find.byKey(WorkspaceStatusBadge.timeoutKey), findsOneWidget);
    expect(find.textContaining('timeout'), findsOneWidget);

    await tester.pumpWidget(
      _harness(
        toolParts: [
          _uiPart(
            tool: 'shell',
            meta: const WorkspaceToolMetadata(
              tool: 'shell',
              status: 'denied',
              command: 'rm -rf /',
            ),
          ),
        ],
      ),
    );
    await tester.pump();
    expect(find.byKey(WorkspaceStatusBadge.deniedKey), findsOneWidget);
    expect(find.text('Denied'), findsOneWidget);
  });

  testWidgets('environment_not_ready shows Install and opens environment', (
    tester,
  ) async {
    var opened = 0;
    WorkspaceNavigation.onOpenEnvironmentPage = (_) => opened++;
    await tester.pumpWidget(
      _harness(
        toolParts: [
          _uiPart(
            tool: 'shell',
            meta: const WorkspaceToolMetadata(
              tool: 'shell',
              status: 'error',
              code: 'environment_not_ready',
              command: 'uname',
            ),
          ),
        ],
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('Sandbox environment not installed'), findsOneWidget);
    await tester.tap(find.byKey(WorkspaceToolCardBody.installButtonKey));
    await tester.pump();
    expect(opened, 1);
  });

  testWidgets('edit_file shows path and +N −N without an inline diff', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness(
        toolParts: [
          _uiPart(
            tool: 'edit_file',
            arguments: const {'path': 'src/app.dart'},
            meta: const WorkspaceToolMetadata(
              tool: 'edit_file',
              status: 'ok',
              path: 'src/app.dart',
              added: 4,
              removed: 2,
              strategy: 'line_trimmed',
              diff: '--- a/src/app.dart\n+++ b/src/app.dart\n+ok\n-old\n',
            ),
          ),
        ],
      ),
    );
    await tester.pump();

    expect(find.textContaining('src/app.dart'), findsWidgets);
    expect(find.textContaining('+4'), findsWidgets);
    expect(find.textContaining('−2'), findsWidgets);
    expect(find.text('Expand'), findsNothing);
    expect(find.textContaining('--- a/src/app.dart'), findsNothing);
  });

  testWidgets('write_file / read_file chips; list_dir is path and count', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness(
        toolParts: [
          _uiPart(
            tool: 'write_file',
            arguments: const {
              'path': 'notes/hello.txt',
              'content': 'a\nb\nc\n',
            },
            meta: const WorkspaceToolMetadata(
              tool: 'write_file',
              status: 'ok',
              path: 'notes/hello.txt',
              created: true,
              bytes: 12,
            ),
          ),
          _uiPart(
            id: 'tc-2',
            tool: 'read_file',
            extraMetadata: const {'mcpResult': <String, dynamic>{}},
            meta: const WorkspaceToolMetadata(
              tool: 'read_file',
              status: 'ok',
              path: 'plot.png',
            ),
          ),
          _uiPart(
            id: 'tc-3',
            tool: 'list_dir',
            arguments: const {'path': 'src'},
            content: 'empty.md\nattachments/\noutputs/\n',
            meta: const WorkspaceToolMetadata(
              tool: 'list_dir',
              status: 'ok',
              path: 'src',
              count: 8,
              truncated: true,
              changedFiles: <String>['src/empty.md', 'src/attachments'],
            ),
          ),
        ],
      ),
    );
    await tester.pump();

    expect(find.text('hello.txt'), findsWidgets);
    expect(find.text('plot.png'), findsWidgets);
    expect(find.textContaining('src'), findsWidgets);
    expect(find.textContaining('3 lines'), findsOneWidget);
    expect(find.textContaining('8 items'), findsOneWidget);
    expect(find.text('empty.md'), findsNothing);
    expect(find.text('attachments'), findsNothing);
    expect(find.text('outputs'), findsNothing);
  });

  testWidgets('live tail updates from an injected ToolRun', (tester) async {
    final registry = ToolRunRegistry();
    final run = registry.start('live-1', 'shell', command: 'echo hi');
    await tester.pumpWidget(
      _harness(
        registry: registry,
        toolParts: [
          const ToolUIPart(
            id: 'live-1',
            toolName: 'shell',
            arguments: {'command': 'echo hi'},
            loading: true,
          ),
        ],
      ),
    );
    await tester.pump();
    expect(find.byType(LoadingIndicator), findsOneWidget);
    expect(find.byKey(WorkspaceStatusBadge.runningKey), findsOneWidget);

    run.appendStdout(utf8.encode('alpha\nbeta\ngamma\n'));
    await tester.pump(const Duration(milliseconds: 60));
    expect(find.textContaining('gamma'), findsOneWidget);
    expect(find.textContaining('beta'), findsOneWidget);
  });

  testWidgets('pending workspace approval uses header buttons and allow-all', (
    tester,
  ) async {
    final approval = ToolApprovalService();
    unawaited(
      approval.requestApproval(
        toolCallId: 'pending-1',
        toolName: 'shell',
        arguments: const {'command': 'ls'},
        conversationId: 'c1',
      ),
    );
    await tester.pumpWidget(
      _harness(
        approval: approval,
        toolParts: [
          const ToolUIPart(
            id: 'pending-1',
            toolName: 'shell',
            arguments: {'command': 'ls'},
            loading: true,
          ),
        ],
      ),
    );
    await tester.pump();

    expect(find.byType(ToolApprovalButton), findsNothing);
    expect(find.byKey(WorkspaceStatusBadge.approvalKey), findsOneWidget);
    expect(find.bySemanticsLabel('Deny'), findsOneWidget);
    expect(find.bySemanticsLabel('Approve'), findsOneWidget);
    expect(find.text('Allow all this session'), findsOneWidget);
    expect(find.text('ls'), findsWidgets);
    expect(find.byIcon(Lucide.Terminal), findsWidgets);
  });

  testWidgets('deny dialog contains IosFormTextField', (tester) async {
    final approval = ToolApprovalService();
    unawaited(
      approval.requestApproval(
        toolCallId: 'pending-deny',
        toolName: 'shell',
        arguments: const {'command': 'ls'},
        conversationId: 'c1',
      ),
    );
    await tester.pumpWidget(
      _harness(
        approval: approval,
        toolParts: [
          const ToolUIPart(
            id: 'pending-deny',
            toolName: 'shell',
            arguments: {'command': 'ls'},
            loading: true,
          ),
        ],
      ),
    );
    await tester.pump();

    await tester.tap(find.bySemanticsLabel('Deny'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(IosFormTextField), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('assistant shell tool sits in the timeline card', (tester) async {
    await tester.pumpWidget(
      _harness(
        toolParts: [
          _uiPart(
            tool: 'shell',
            arguments: const {'command': 'uname'},
            content: 'Darwin',
            meta: const WorkspaceToolMetadata(
              tool: 'shell',
              status: 'ok',
              command: 'uname',
              exitCode: 0,
              durationMs: 8,
            ),
          ),
        ],
      ),
    );
    await tester.pump();
    expect(_timelineIconColumn, findsOneWidget);
    expect(find.byType(WorkspaceToolCardBody), findsOneWidget);
    expect(find.text('Tool Call: shell'), findsNothing);
    expect(find.text('uname'), findsWidgets);
  });

  testWidgets('shell tool uses the timeline while running and when completed', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness(
        toolParts: [
          const ToolUIPart(
            id: 'tc-run',
            toolName: 'shell',
            arguments: {'command': 'ls -la'},
            loading: true,
          ),
        ],
      ),
    );
    await tester.pump();
    expect(_timelineIconColumn, findsOneWidget);
    expect(find.text('Tool Call: shell'), findsNothing);
    expect(find.text('ls -la'), findsWidgets);

    await tester.pumpWidget(
      _harness(
        toolParts: [
          _uiPart(
            tool: 'shell',
            arguments: const {'command': 'uname'},
            content: 'Darwin',
            meta: const WorkspaceToolMetadata(
              tool: 'shell',
              status: 'ok',
              command: 'uname',
              exitCode: 0,
            ),
          ),
        ],
      ),
    );
    await tester.pump();
    expect(_timelineIconColumn, findsOneWidget);
    expect(find.text('Tool Call: shell'), findsNothing);
    expect(find.text('uname'), findsWidgets);
  });

  testWidgets('tapping a timeline shell step opens tool detail', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _harness(
        toolParts: [
          _uiPart(
            tool: 'shell',
            arguments: const {'command': 'uname'},
            meta: const WorkspaceToolMetadata(
              tool: 'shell',
              status: 'ok',
              command: 'uname',
              exitCode: 0,
            ),
          ),
        ],
      ),
    );
    await tester.pump();
    await tester.tap(find.text('Run command'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(CustomBottomSheet.panelKey), findsOneWidget);
  });

  testWidgets('detail opens as a bottom sheet on mobile size', (tester) async {
    tester.view.physicalSize = const Size(390, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(
            create: (_) => SettingsProvider(createBusinessTestPreferences()),
          ),
          ChangeNotifierProvider(create: (_) => ToolRunRegistry()),
          ChangeNotifierProvider(create: (_) => ToolApprovalService()),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showWorkspaceToolDetail(
                  context,
                  WorkspaceToolPart(
                    id: 'd1',
                    toolName: 'read_file',
                    metadata: const WorkspaceToolMetadata(
                      tool: 'read_file',
                      status: 'ok',
                      path: 'README.md',
                    ).toJson(),
                  ),
                ),
                child: const Text('open-detail'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open-detail'));
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(CustomBottomSheet.panelKey), findsOneWidget);
    expect(find.byKey(kWorkspaceToolDetailDesktopKey), findsNothing);
    expect(find.text('Path'), findsWidgets);
    expect(find.text('Command'), findsNothing);
  });

  testWidgets(
    'workspace tool cards keep desktop dialogs below the width breakpoint',
    (tester) async {
      tester.view.physicalSize = const Size(1162, 759);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      for (final (tool, title) in const [
        ('list_dir', 'List directory'),
        ('shell', 'Run command'),
      ]) {
        await tester.pumpWidget(
          _harness(
            toolParts: [
              _uiPart(
                tool: tool,
                arguments: const {'path': '/project', 'command': 'ls'},
                content: 'README.md\nlib/',
                meta: WorkspaceToolMetadata(
                  tool: tool,
                  status: 'ok',
                  path: '/project',
                  command: tool == 'shell' ? 'ls' : null,
                  stdoutPreview: 'README.md\nlib/',
                ),
              ),
            ],
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text(title));
        await tester.pumpAndSettle();

        final dialog = find.byKey(kWorkspaceToolDetailDesktopKey);
        expect(dialog, findsOneWidget);
        expect(find.byKey(CustomBottomSheet.panelKey), findsNothing);
        expect(find.text('Output'), findsOneWidget);
        expect(find.text('README.md\nlib/'), findsWidgets);

        tester.view.physicalSize = const Size(800, 500);
        await tester.pumpAndSettle();
        final bounds = tester.getRect(dialog);
        expect(bounds.left, greaterThanOrEqualTo(24));
        expect(bounds.right, lessThanOrEqualTo(776));
        expect(bounds.top, greaterThanOrEqualTo(24));
        expect(bounds.bottom, lessThanOrEqualTo(476));
        expect(tester.takeException(), isNull);

        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
        expect(dialog, findsNothing);
      }
    },
    variant: TargetPlatformVariant({
      TargetPlatform.macOS,
      TargetPlatform.windows,
      TargetPlatform.linux,
    }),
  );

  testWidgets('detail opens as a dialog on desktop size', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(
            create: (_) => SettingsProvider(createBusinessTestPreferences()),
          ),
          ChangeNotifierProvider(create: (_) => ToolRunRegistry()),
          ChangeNotifierProvider(create: (_) => ToolApprovalService()),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showWorkspaceToolDetail(
                  context,
                  WorkspaceToolPart(
                    id: 'd1',
                    toolName: 'read_file',
                    metadata: const WorkspaceToolMetadata(
                      tool: 'read_file',
                      status: 'ok',
                      path: 'README.md',
                    ).toJson(),
                  ),
                ),
                child: const Text('open-detail'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open-detail'));
    await tester.pump();
    expect(find.byKey(kWorkspaceToolDetailDesktopKey), findsOneWidget);
    expect(find.byKey(CustomBottomSheet.panelKey), findsNothing);
  });
}
