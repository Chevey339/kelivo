import 'dart:convert';
import 'dart:typed_data';

import 'package:Kelivo/core/database/extension_entity_store.dart';
import 'package:Kelivo/core/models/environment_state.dart';
import 'package:Kelivo/core/providers/mcp_provider.dart';
import 'package:Kelivo/core/providers/environment_provider.dart';
import 'package:Kelivo/core/models/environment_variable.dart';
import 'package:Kelivo/core/services/mcp/stdio_arguments.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/providers/workspace_provider.dart';
import 'package:Kelivo/core/services/workspace/workspace_runtime.dart';
import 'package:Kelivo/features/mcp/widgets/mcp_server_edit_sheet.dart';
import 'package:Kelivo/desktop/setting/mcp_edit_dialog.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../../../support/business_test_harness.dart';
import '../../../support/fake_workspace_runtime.dart';

void main() {
  for (final brightness in Brightness.values) {
    testWidgets(
      'select, save, reopen and unbind a workspace (${brightness.name})',
      (tester) async {
        final provider = await _openEditor(
          tester,
          ['./mcp_server.py'],
          withWorkspaces: true,
          brightness: brightness,
          size: const Size(320, 740),
        );
        final binding = find.byKey(const ValueKey('mcp-workspace-binding'));
        await tester.ensureVisible(binding);
        expect(find.text('None'), findsOneWidget);
        await tester.tap(binding);
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const ValueKey('workspace-section-pick-scripts')),
        );
        await tester.pumpAndSettle();
        expect(find.text('MCP scripts'), findsOneWidget);
        expect(
          find.byWidgetPredicate(
            (widget) =>
                widget is TextField &&
                widget.decoration?.hintText == '/workspace',
          ),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('Save'));
        await tester.pumpAndSettle();
        expect(provider.getById('guest')!.workspaceId, 'scripts');
        expect(provider.getById('guest')!.workingDirectory, isNull);

        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        expect(find.text('MCP scripts'), findsOneWidget);
        await tester.ensureVisible(
          find.byKey(const ValueKey('mcp-workspace-unbind')),
        );
        await tester.tap(find.byKey(const ValueKey('mcp-workspace-unbind')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Save'));
        await tester.pumpAndSettle();
        expect(provider.getById('guest')!.workspaceId, isNull);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
      variant: TargetPlatformVariant.only(TargetPlatform.iOS),
    );
  }

  testWidgets(
    'a deleted binding remains visible and can be cleared',
    (tester) async {
      final provider = await _openEditor(
        tester,
        [],
        withWorkspaces: true,
        workspaceId: 'scripts',
      );
      await provider.workspaces!.delete('scripts', deleteFiles: false);
      await tester.pumpAndSettle();
      expect(find.text('Workspace not found'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('mcp-workspace-unbind')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(provider.getById('guest')!.workspaceId, isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets(
    'desktop can clear a mobile binding without selecting a new one',
    (tester) async {
      final provider = await _openEditor(
        tester,
        [],
        workspaceId: 'scripts',
        desktop: true,
      );
      expect(
        find.text(
          'Workspace binding is available in the mobile Linux environment. Unbind it to run this server on desktop.',
        ),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('mcp-workspace-unbind')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(provider.getById('guest')!.workspaceId, isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
    variant: TargetPlatformVariant.only(TargetPlatform.macOS),
  );

  testWidgets(
    'iOS stdio fields send literal input configuration to the keyboard',
    (tester) async {
      const script = "printf \"hello\"\nprintf 'world'";
      const value = '--flag="literal"';
      const cwd = '/root/my--folder';
      await _openEditor(
        tester,
        ['--yes', script],
        environment: {'SERVER_FLAGS': value},
        workingDirectory: cwd,
      );
      for (final text in [
        'sh',
        StdioArguments.format(['--yes', script]),
        cwd,
        'SERVER_FLAGS',
        value,
      ]) {
        final field = _fieldWithText(text);
        await tester.ensureVisible(field);
        await tester.showKeyboard(field);
        final config = tester.testTextInput.setClientArgs!;
        expect(
          config['smartDashesType'],
          SmartDashesType.disabled.index.toString(),
          reason: text,
        );
        expect(
          config['smartQuotesType'],
          SmartQuotesType.disabled.index.toString(),
          reason: text,
        );
        expect(config['autocorrect'], isFalse, reason: text);
        expect(config['enableSuggestions'], isFalse, reason: text);
      }
      await tester.pumpWidget(const SizedBox.shrink());
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets(
    'renaming imported stdio preserves every argument exactly',
    (tester) async {
      const arguments = [
        '-c',
        'printf "hello"\nprintf "world"\n',
        '',
        '  spaced  ',
        '\r\n',
        '',
      ];
      final provider = await _openEditor(tester, arguments);
      await tester.enterText(_fieldWithText('Imported server'), 'Renamed');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(provider.getById('guest')!.name, 'Renamed');
      expect(provider.getById('guest')!.args, arguments);
      expect(
        jsonDecode(
          provider.exportServersAsUiJson(),
        )['mcpServers']['guest']['args'],
        arguments,
      );
      await tester.pumpWidget(const SizedBox.shrink());
    },
    variant: TargetPlatformVariant.only(TargetPlatform.macOS),
  );

  testWidgets(
    'space separated arguments preserve quotes, empty strings and scripts',
    (tester) async {
      final provider = await _openEditor(tester, ['--yes']);
      final field = _fieldWithText('--yes');
      await tester.ensureVisible(field);
      await tester.enterText(
        field,
        "--yes \"two words\" '' \"line one\nline two\"",
      );
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(provider.getById('guest')!.args, [
        '--yes',
        'two words',
        '',
        'line one\nline two',
      ]);
      await tester.pumpWidget(const SizedBox.shrink());
    },
    variant: TargetPlatformVariant.only(TargetPlatform.macOS),
  );

  testWidgets(
    'unclosed argument quotes prevent saving',
    (tester) async {
      final provider = await _openEditor(tester, ['--yes']);
      await tester.enterText(_fieldWithText('--yes'), '"unterminated');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(provider.getById('guest')!.args, ['--yes']);
      expect(
        find.text(
          'Check for an unclosed quote or trailing escape in arguments.',
        ),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox.shrink());
    },
    variant: TargetPlatformVariant.only(TargetPlatform.macOS),
  );

  testWidgets(
    'imports an environment variable into the server override',
    (tester) async {
      final provider = await _openEditor(tester, []);
      await tester.ensureVisible(find.text('Import from Environment'));
      await tester.tap(find.text('Import from Environment'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('API_TOKEN'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(provider.getById('guest')!.env, {'API_TOKEN': 'test-token'});
      await tester.pumpWidget(const SizedBox.shrink());
    },
    variant: TargetPlatformVariant.only(TargetPlatform.macOS),
  );
}

Finder _fieldWithText(String text) => find.byWidgetPredicate(
  (widget) => widget is TextField && widget.controller?.text == text,
);

Future<McpProvider> _openEditor(
  WidgetTester tester,
  List<String> arguments, {
  Map<String, String> environment = const {},
  String? workingDirectory,
  String? workspaceId,
  bool withWorkspaces = false,
  bool desktop = false,
  Brightness brightness = Brightness.light,
  Size size = const Size(600, 1600),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final harness = await createBusinessTestHarness();
  final settings = SettingsProvider(harness.preferences);
  final env = EnvironmentProvider(preferences: harness.preferences);
  await env.loaded;
  await env.saveVariable(
    const EnvironmentVariable(name: 'API_TOKEN', value: 'test-token'),
  );
  WorkspaceProvider? workspaces;
  WorkspaceRuntimeProvider? runtime;
  if (withWorkspaces) {
    final store = ExtensionEntityStore(harness.database);
    await store.upsert(ExtensionEntityStore.kindWorkspace, 'scripts', {
      'id': 'scripts',
      'name': 'MCP scripts',
      'kind': 'managed',
      'createdAt': '2026-09-13T00:00:00Z',
      'updatedAt': '2026-09-13T00:00:00Z',
    });
    workspaces = WorkspaceProvider(store: store);
    await workspaces.loaded;
    runtime = WorkspaceRuntimeProvider()..register(_StdioRuntime());
    await runtime.refresh();
    await env.setState(const EnvironmentState(phase: EnvironmentPhase.ready));
    addTearDown(workspaces.dispose);
    addTearDown(runtime.dispose);
  }
  final provider = McpProvider(
    preferences: harness.preferences,
    environment: env,
    workspaces: workspaces,
    workspaceRuntime: runtime,
  );
  addTearDown(env.dispose);
  addTearDown(provider.dispose);
  addTearDown(settings.dispose);
  await provider.replaceAllFromJson(
    jsonEncode({
      'mcpServers': {
        'guest': {
          'name': 'Imported server',
          'command': 'sh',
          'args': arguments,
          'env': environment,
          if (workingDirectory != null) 'workingDirectory': workingDirectory,
          if (workspaceId != null) 'workspaceId': workspaceId,
          'isActive': false,
        },
      },
    }),
  );
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: provider),
        ChangeNotifierProvider.value(value: settings),
        ChangeNotifierProvider.value(value: env),
        if (workspaces != null) ChangeNotifierProvider.value(value: workspaces),
      ],
      child: MaterialApp(
        theme: ThemeData(brightness: brightness),
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => desktop
                  ? showDesktopMcpEditDialog(context, serverId: 'guest')
                  : showMcpServerEditSheet(context, serverId: 'guest'),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
  return provider;
}

class _StdioRuntime extends FakeWorkspaceRuntime
    implements WorkspaceStdioRuntime {
  @override
  Future<void> writeStdin(String runId, Uint8List data) async {}
}
