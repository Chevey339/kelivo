import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/workspace/tool_run_registry.dart';
import 'package:Kelivo/core/services/workspace/workspace_tool_metadata.dart';
import 'package:Kelivo/features/chat/widgets/workspace_tool_detail.dart';
import 'package:Kelivo/features/chat/widgets/workspace_tool_ui.dart';
import 'package:Kelivo/icons/lucide_adapter.dart';
import 'package:Kelivo/l10n/app_localizations.dart';

import '../../../support/business_test_harness.dart';

WorkspaceToolPart _shellPart({
  required String command,
  required String stdout,
  String stderr = '',
}) {
  return WorkspaceToolPart(
    id: 'tc-shell',
    toolName: 'shell',
    arguments: {'command': command},
    content: stdout,
    metadata: WorkspaceToolMetadata(
      tool: 'shell',
      status: 'ok',
      command: command,
      stdoutPreview: stdout,
      stderrPreview: stderr,
      exitCode: 0,
    ).toJson(),
  );
}

Widget _harness({required Widget child}) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: SizedBox(height: 640, width: 390, child: child)),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('long shell output lives in a single scrollable', (tester) async {
    final stdout = List<String>.generate(
      200,
      (index) => 'output-line-$index',
    ).join('\n');

    await tester.pumpWidget(
      _harness(
        child: WorkspaceToolDetailBody(
          part: _shellPart(command: 'yes | head', stdout: stdout),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(Scrollable), findsOneWidget);
    expect(find.text('Command'), findsOneWidget);
    expect(find.text('Output'), findsOneWidget);
    expect(find.textContaining('output-line-0'), findsOneWidget);
  });

  testWidgets('section copy icons copy command and output', (tester) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map<Object?, Object?>)['text'] as String?;
          return null;
        }
        return null;
      },
    );
    addTearDown(() {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      );
    });

    const command = 'echo hello';
    const stdout = 'hello\nworld';

    await tester.pumpWidget(
      _harness(
        child: WorkspaceToolDetailBody(
          part: _shellPart(command: command, stdout: stdout),
        ),
      ),
    );
    await tester.pump();

    expect(find.byIcon(Lucide.Copy), findsNWidgets(2));

    await tester.tap(find.byTooltip('Copy command'));
    await tester.pump();
    expect(copied, command);

    await tester.tap(find.byTooltip('Copy output'));
    await tester.pump();
    expect(copied, stdout);

    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
  });

  testWidgets('stored progress displays and copies its final line', (
    tester,
  ) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String;
        }
        return null;
      },
    );
    addTearDown(() {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      );
    });
    await tester.pumpWidget(
      _harness(
        child: WorkspaceToolDetailBody(
          part: _shellPart(
            command: 'download',
            stdout: 'starting\r\n10%\r\x1b[32m100%\x1b[0m\r\n',
          ),
        ),
      ),
    );
    expect(find.text('starting\n100%\n'), findsOneWidget);
    await tester.tap(find.byTooltip('Copy output'));
    await tester.pump();
    expect(copied, 'starting\n100%\n');
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
  });

  for (final live in [false, true]) {
    testWidgets(
      '${live ? 'live' : 'stored'} shell copies both streams and preserves whitespace',
      (tester) async {
        tester.view.physicalSize = const Size(1000, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        String? copied;
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          (call) async {
            if (call.method == 'Clipboard.setData') {
              copied = (call.arguments as Map)['text'] as String;
            }
            return null;
          },
        );
        addTearDown(() {
          tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            SystemChannels.platform,
            null,
          );
        });
        final registry = ToolRunRegistry();
        final run = live
            ? registry.start('tc-shell', 'shell', command: 'download')
            : null;
        addTearDown(() {
          for (final run in registry.all) {
            run.dispose();
          }
          registry.dispose();
        });
        final part = _shellPart(
          command: 'download',
          stdout: '10%\r\x1b[32m 100%  \x1b[0m\r\n',
          stderr: 'warning\rfixed\r\n',
        );
        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider.value(value: registry),
              ChangeNotifierProvider(
                create: (_) =>
                    SettingsProvider(createBusinessTestPreferences()),
              ),
            ],
            child: _harness(
              child: Builder(
                builder: (context) => TextButton(
                  onPressed: () => showWorkspaceToolDetail(context, part),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('open'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        if (run != null) {
          expect(find.text('No output'), findsOneWidget);
          run.appendStdout(utf8.encode('10%\r\x1b['));
          await tester.pump(const Duration(milliseconds: 60));
          expect(find.text('10%'), findsOneWidget);
          await tester.tap(find.byTooltip('Copy output'));
          await tester.pump();
          expect(copied, '10%');
          run.appendStdout(utf8.encode('32m 100%  \x1b[0m\r'));
          run.appendStderr(utf8.encode('warning\rfixed\r\n'));
          run.appendStdout(utf8.encode('\n'));
          await tester.pump(const Duration(milliseconds: 60));
        }
        expect(find.text(' 100%  \n'), findsOneWidget);
        await tester.tap(find.byTooltip('Copy output'));
        await tester.pump();
        expect(copied, ' 100%  \n');

        await tester.tap(find.text('stderr'));
        await tester.pump();
        expect(find.text('fixed\n'), findsOneWidget);
        await tester.tap(find.byTooltip('Copy output'));
        await tester.pump();
        expect(copied, 'fixed\n');
        await tester.tap(find.byTooltip('Copy'));
        await tester.pump();
        expect(copied, 'download\n 100%  \n\nfixed\n');

        run?.complete(status: ToolRunStatus.succeeded, exitCode: 0);
        await tester.pump();
        await tester.tap(find.byTooltip('Copy'));
        await tester.pump();
        expect(copied, 'download\n 100%  \n\nfixed\n');
        expect(copied, isNot(contains('\r')));
        expect(copied, isNot(contains('\x1b')));
        await tester.pump(const Duration(seconds: 4));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
      variant: TargetPlatformVariant({TargetPlatform.macOS}),
    );
  }
}
