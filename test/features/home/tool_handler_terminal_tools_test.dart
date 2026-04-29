import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:Kelivo/core/providers/assistant_provider.dart';
import 'package:Kelivo/core/providers/mcp_provider.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/mcp/mcp_tool_service.dart';
import 'package:Kelivo/features/home/services/tool_handler_service.dart';
import 'package:Kelivo/features/terminal/providers/terminal_ai_tool_provider.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('injects terminal tools only when iOS switch is enabled', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    final terminalTools = TerminalAiToolProvider(initialEnabled: true);
    late List<Map<String, dynamic>> toolDefs;

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => SettingsProvider()),
          ChangeNotifierProvider(create: (_) => McpToolService()),
          ChangeNotifierProvider(create: (_) => McpProvider()),
          ChangeNotifierProvider(create: (_) => AssistantProvider()),
          ChangeNotifierProvider.value(value: terminalTools),
        ],
        child: Builder(
          builder: (context) {
            final settings = context.read<SettingsProvider>();
            toolDefs = ToolHandlerService(contextProvider: context)
                .buildToolDefinitions(
                  settings,
                  null,
                  settings.currentModelProvider ?? 'openai',
                  settings.currentModelId ?? 'gpt-4o',
                  false,
                  isToolModel: (_, _) => true,
                );
            return const SizedBox();
          },
        ),
      ),
    );

    final names = toolDefs
        .map((tool) => tool['function'] as Map<String, dynamic>)
        .map((function) => function['name'])
        .toSet();
    expect(
      names,
      containsAll([
        'terminal_read',
        'terminal_exec',
        'terminal_edit',
        'terminal_write',
      ]),
    );

    await terminalTools.setEnabled(false);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => SettingsProvider()),
          ChangeNotifierProvider(create: (_) => McpToolService()),
          ChangeNotifierProvider(create: (_) => McpProvider()),
          ChangeNotifierProvider(create: (_) => AssistantProvider()),
          ChangeNotifierProvider.value(value: terminalTools),
        ],
        child: Builder(
          builder: (context) {
            final settings = context.read<SettingsProvider>();
            toolDefs = ToolHandlerService(contextProvider: context)
                .buildToolDefinitions(
                  settings,
                  null,
                  settings.currentModelProvider ?? 'openai',
                  settings.currentModelId ?? 'gpt-4o',
                  false,
                  isToolModel: (_, _) => true,
                );
            return const SizedBox();
          },
        ),
      ),
    );

    final disabledNames = toolDefs
        .map((tool) => tool['function'] as Map<String, dynamic>)
        .map((function) => function['name'])
        .toSet();
    expect(disabledNames, isNot(contains('terminal_exec')));
    debugDefaultTargetPlatformOverride = null;
  });
}
