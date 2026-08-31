import 'package:Kelivo/core/models/tool_schema_override.dart';
import 'package:Kelivo/core/services/search/search_tool_service.dart';
import 'package:Kelivo/features/settings/pages/tool_schema_editor_page.dart';
import 'package:Kelivo/icons/lucide_adapter.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/theme/theme_factory.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('prefills default description and pops override after edit', (
    tester,
  ) async {
    ToolSchemaOverride? result;
    await _pumpEditor(tester, onResult: (value) => result = value);

    expect(find.text(SearchToolService.toolDescription), findsWidgets);
    expect(find.text(SearchToolService.toolName), findsOneWidget);

    await tester.enterText(
      find.descendant(
        of: find.byKey(const ValueKey('tool-schema-desc')),
        matching: find.byType(TextField),
      ),
      'Be conservative about search.',
    );
    await tester.pump();

    await tester.tap(find.text('Parameter descriptions (1)'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('tool-schema-param-query')),
      findsOneWidget,
    );

    await tester.tap(find.byIcon(Lucide.Check));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result!.description, 'Be conservative about search.');
  });

  testWidgets('restore default pops an empty override', (tester) async {
    ToolSchemaOverride? result;
    await _pumpEditor(
      tester,
      initialOverride: const ToolSchemaOverride(
        description: 'custom',
        paramDescriptions: {'query': 'custom query'},
      ),
      onResult: (value) => result = value,
    );

    await tester.tap(find.text('Restore default'));
    await tester.pump();
    await tester.tap(find.byIcon(Lucide.Check));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result!.isEmpty, isTrue);
  });
}

Future<void> _pumpEditor(
  WidgetTester tester, {
  ToolSchemaOverride? initialOverride,
  required ValueChanged<ToolSchemaOverride?> onResult,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: buildLightTheme(null),
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () async {
                final value = await Navigator.of(context)
                    .push<ToolSchemaOverride?>(
                      MaterialPageRoute(
                        builder: (_) => ToolSchemaEditorPage(
                          toolName: SearchToolService.toolName,
                          defaultDefinition:
                              SearchToolService.getToolDefinition(),
                          initialOverride: initialOverride,
                        ),
                      ),
                    );
                onResult(value);
              },
              child: const Text('Open editor'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open editor'));
  await tester.pumpAndSettle();
}
