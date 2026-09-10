import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:Kelivo/core/providers/mcp_provider.dart';
import 'package:Kelivo/features/mcp/widgets/mcp_json_import.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import '../../../support/business_test_harness.dart';

void main() {
  testWidgets(
    'preview is non-mutating and editing JSON invalidates the preview',
    (tester) async {
      final harness = await createBusinessTestHarness();
      final provider = McpProvider(preferences: harness.preferences);
      addTearDown(provider.dispose);
      await provider.replaceAllFromJson(
        jsonEncode({
          'mcpServers': {
            'saved': {'command': 'sh', 'isActive': false},
          },
        }),
      );
      final before = provider.exportServersAsUiJson();
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: provider,
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('en'),
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => showMcpJsonImport(context, desktop: true),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      final field = find.byKey(const ValueKey('mcp-import-json'));
      await tester.enterText(
        field,
        '{"mcpServers":{"first":{"command":"npx","disabled":true}}}',
      );
      await tester.tap(find.text('Preview'));
      await tester.pumpAndSettle();
      expect(provider.exportServersAsUiJson(), before);
      expect(find.text('first'), findsOneWidget);
      await tester.enterText(
        field,
        '{"mcpServers":{"second":{"url":"https://example.com/mcp","disabled":true}}}',
      );
      await tester.pumpAndSettle();
      expect(find.text('Import'), findsNothing);
      await tester.tap(find.text('Preview'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Import'));
      await tester.pumpAndSettle();
      final saved =
          (jsonDecode(provider.exportServersAsUiJson())['mcpServers'] as Map)
              .values;
      expect(saved.where((server) => server['name'] == 'first'), isEmpty);
      expect(saved.where((server) => server['name'] == 'second'), hasLength(1));
      expect(provider.getById('saved')!.command, 'sh');
      await tester.pumpWidget(const SizedBox.shrink());
    },
    variant: TargetPlatformVariant.only(TargetPlatform.macOS),
  );
}
