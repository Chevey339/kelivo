import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:Kelivo/core/providers/environment_provider.dart';
import 'package:Kelivo/core/services/workspace/desktop_process_runtime.dart';
import 'package:Kelivo/core/services/workspace/desktop_shell.dart';
import 'package:Kelivo/core/services/workspace/workspace_runtime.dart';
import 'package:Kelivo/features/settings/widgets/custom_theme_widgets.dart';
import 'package:Kelivo/features/workspace/widgets/environment/native_shell_dialog.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/icons/lucide_adapter.dart';
import 'package:Kelivo/shared/widgets/ios_tile_button.dart';

import '../../../support/business_test_harness.dart';

void main() {
  testWidgets('validates, saves, displays, and resets the desktop shell', (
    tester,
  ) async {
    final env = EnvironmentProvider(
      preferences: createBusinessTestPreferences(),
    );
    await tester.runAsync(() => env.loaded);
    final runtime = DesktopProcessRuntime(
      loadShellPath: () async => env.nativeShellPath,
      shellResolver: DesktopShellResolver(
        windows: false,
        environment: const {'SHELL': '/bin/zsh'},
        runProcess: (exe, args) async {
          if (exe == '/missing') throw ProcessException(exe, args);
          return ProcessResult(1, 0, 'kelivo-shell-ready', '');
        },
      ),
    );
    final provider = WorkspaceRuntimeProvider()..register(runtime);
    addTearDown(env.dispose);
    addTearDown(provider.dispose);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: IosTileButton(
              label: 'Open shell settings',
              icon: Lucide.Terminal,
              onTap: () => showAppDialog<void>(
                context,
                child: NativeShellDialog(
                  environment: env,
                  runtime: runtime,
                  runtimeProvider: provider,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open shell settings'));
    await tester.pumpAndSettle();
    final input = find.descendant(
      of: find.byKey(const ValueKey('native-shell-path')),
      matching: find.byType(TextField),
    );
    await tester.enterText(input, '/missing');
    await tester.tap(find.byKey(const ValueKey('native-shell-save')));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Could not start this shell. Check its absolute path and supported command syntax.',
      ),
      findsOneWidget,
    );
    expect(env.nativeShellPath, isEmpty);

    await tester.enterText(input, '/custom/bin/bash');
    await tester.tap(find.byKey(const ValueKey('native-shell-save')));
    await tester.pump();
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();
    expect(env.nativeShellPath, '/custom/bin/bash');
    expect(provider.lastStatus?.shell?.executable, '/custom/bin/bash');
    expect(find.byType(NativeShellDialog), findsNothing);

    await tester.tap(find.text('Open shell settings'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(input).controller?.text,
      '/custom/bin/bash',
    );
    await tester.enterText(input, '');
    await tester.tap(find.byKey(const ValueKey('native-shell-save')));
    await tester.pump();
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();
    expect(env.nativeShellPath, isEmpty);
    expect(provider.lastStatus?.shell?.executable, '/bin/zsh');
    expect(find.byType(NativeShellDialog), findsNothing);
  });
}
