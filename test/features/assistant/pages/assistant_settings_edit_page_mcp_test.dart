import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:Kelivo/core/models/assistant.dart';
import 'package:Kelivo/core/providers/assistant_provider.dart';
import 'package:Kelivo/core/providers/memory_provider.dart';
import 'package:Kelivo/core/providers/quick_phrase_provider.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/features/assistant/pages/assistant_settings_edit_page.dart';
import 'package:Kelivo/l10n/app_localizations.dart';

const _assistantId = 'assistant-mcp-test';

void _seedPreferences() {
  SharedPreferences.setMockInitialValues({
    'assistants_v1': Assistant.encodeList(const [
      Assistant(id: _assistantId, name: 'Test Assistant', temperature: 0.6),
    ]),
  });
}

Future<AssistantProvider> _createAssistantProvider() async {
  final provider = AssistantProvider();
  for (var i = 0; i < 25; i++) {
    if (provider.getById(_assistantId) != null) return provider;
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  return provider;
}

Widget _buildHarness({
  required AssistantProvider assistantProvider,
  required Widget child,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => SettingsProvider()),
      ChangeNotifierProvider.value(value: assistantProvider),
      ChangeNotifierProvider(create: (_) => MemoryProvider()),
      ChangeNotifierProvider(create: (_) => QuickPhraseProvider()),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: child,
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('assistant edit page shows MCP tab on mobile', (tester) async {
    _seedPreferences();
    final assistantProvider = await _createAssistantProvider();

    await tester.pumpWidget(
      _buildHarness(
        assistantProvider: assistantProvider,
        child: const AssistantSettingsEditPage(assistantId: _assistantId),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('MCP'), findsOneWidget);
  });

  testWidgets('assistant desktop dialog shows MCP menu item', (tester) async {
    _seedPreferences();
    final assistantProvider = await _createAssistantProvider();

    await tester.pumpWidget(
      _buildHarness(
        assistantProvider: assistantProvider,
        child: Scaffold(
          body: Builder(
            builder: (context) {
              return TextButton(
                onPressed: () => showAssistantDesktopDialog(
                  context,
                  assistantId: _assistantId,
                ),
                child: const Text('open'),
              );
            },
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('MCP'), findsOneWidget);
  });
}
