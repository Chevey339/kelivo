import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/features/workspace/terminal/terminal_session_manager.dart';
import 'package:Kelivo/features/workspace/terminal/widgets/terminal_key_bar.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/theme/theme_factory.dart';

import 'fake_workspace_runtime.dart';

void main() {
  Future<void> pumpBar(
    WidgetTester tester, {
    required TerminalSession session,
    Size size = const Size(390, 844),
    Locale locale = const Locale('zh'),
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildLightTheme(null),
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Align(
            alignment: Alignment.bottomCenter,
            child: TerminalKeyBar(
              session: session,
              onCopy: () {},
              onPaste: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('copy and paste stay visible at 390px', (tester) async {
    final runtime = FakeWorkspaceRuntime();
    final manager = TerminalSessionManager(setWakelock: (_) async {});
    addTearDown(() async {
      await manager.closeAll();
      manager.dispose();
    });
    final session = await manager.open(
      runtime: runtime,
      mounts: const [],
      cwd: '/workspace',
      title: 'Demo',
    );

    await pumpBar(tester, session: session);

    expect(find.text('复制'), findsOneWidget);
    expect(find.text('粘贴'), findsOneWidget);

    final copy = tester.getRect(find.byKey(TerminalKeyBar.copyKey));
    final paste = tester.getRect(find.byKey(TerminalKeyBar.pasteKey));
    expect(copy.left, greaterThanOrEqualTo(0));
    expect(copy.right, lessThanOrEqualTo(390));
    expect(paste.left, greaterThanOrEqualTo(0));
    expect(paste.right, lessThanOrEqualTo(390));
    expect(paste.left, greaterThan(copy.right));
  });

  testWidgets('Ctrl stays left of pinned copy at 400px English', (
    tester,
  ) async {
    final runtime = FakeWorkspaceRuntime();
    final manager = TerminalSessionManager(setWakelock: (_) async {});
    addTearDown(() async {
      await manager.closeAll();
      manager.dispose();
    });
    final session = await manager.open(
      runtime: runtime,
      mounts: const [],
      cwd: '/workspace',
      title: 'Demo',
    );

    await pumpBar(
      tester,
      session: session,
      size: const Size(400, 900),
      locale: const Locale('en'),
    );

    final ctrlCenter = tester.getCenter(find.byKey(TerminalKeyBar.ctrlKey));
    final copy = tester.getRect(find.byKey(TerminalKeyBar.copyKey));
    expect(ctrlCenter.dx, lessThan(copy.left));

    await tester.tap(find.byKey(TerminalKeyBar.ctrlKey));
    await tester.pump();
    expect(session.ctrlModifier, isTrue);
  });
}
