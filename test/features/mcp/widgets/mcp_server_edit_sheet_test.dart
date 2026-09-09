import 'dart:convert';

import 'package:Kelivo/core/providers/mcp_provider.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/features/mcp/widgets/mcp_server_edit_sheet.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../../../support/business_test_harness.dart';

void main() {
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
      for (final text in ['sh', '--yes', script, cwd, 'SERVER_FLAGS', value]) {
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
    'arguments can be removed, edited across lines, and added empty',
    (tester) async {
      final provider = await _openEditor(tester, ['remove', 'keep', 'last']);
      final remove = find
          .byWidgetPredicate(
            (widget) =>
                widget is Semantics && widget.properties.label == 'Remove',
          )
          .first;
      await tester.ensureVisible(remove);
      await tester.tap(remove);
      await tester.pumpAndSettle();
      const script = 'line one\nline two\n';
      await tester.ensureVisible(_fieldWithText('keep'));
      await tester.enterText(_fieldWithText('keep'), script);
      await tester.ensureVisible(find.text('Add Argument'));
      await tester.tap(find.text('Add Argument'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(provider.getById('guest')!.args, [script, 'last', '']);
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
}) async {
  tester.view.physicalSize = const Size(600, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final harness = await createBusinessTestHarness();
  final provider = McpProvider(preferences: harness.preferences);
  final settings = SettingsProvider(harness.preferences);
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
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () =>
                  showMcpServerEditSheet(context, serverId: 'guest'),
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
