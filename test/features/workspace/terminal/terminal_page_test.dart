import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/workspace/workspace_runtime.dart';
import 'package:Kelivo/features/workspace/terminal/terminal_page.dart';
import 'package:Kelivo/features/workspace/terminal/terminal_session_manager.dart';
import 'package:Kelivo/features/workspace/terminal/widgets/system_terminal_card.dart';
import 'package:Kelivo/features/workspace/terminal/widgets/terminal_key_bar.dart';
import 'package:Kelivo/features/workspace/terminal/widgets/terminal_tab_strip.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/responsive/breakpoints.dart';
import 'package:Kelivo/shared/responsive/screen_type_helper.dart';
import 'package:Kelivo/shared/widgets/custom_bottom_sheet.dart';
import 'package:Kelivo/shared/widgets/ios_tile_button.dart';
import 'package:Kelivo/theme/theme_factory.dart';

import '../../../support/business_test_harness.dart';
import 'fake_workspace_runtime.dart';

void main() {
  Future<void> flushIo(WidgetTester tester) async {
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    });
    await tester.pump();
  }

  Future<AppLocalizations> pumpPage(
    WidgetTester tester, {
    required TerminalSessionManager manager,
    required WorkspaceRuntimeProvider runtimeProvider,
    String? hostDir,
    Size size = const Size(400, 900),
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(
            create: (_) => SettingsProvider(createBusinessTestPreferences()),
          ),
          ChangeNotifierProvider<TerminalSessionManager>.value(value: manager),
          ChangeNotifierProvider<WorkspaceRuntimeProvider>.value(
            value: runtimeProvider,
          ),
        ],
        child: MaterialApp(
          theme: buildLightTheme(null),
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: TerminalPage(
            hostDir: hostDir ?? '/tmp/workspace',
            cwd: '/workspace',
            title: 'Demo',
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    return AppLocalizations.of(tester.element(find.byType(TerminalPage)))!;
  }

  testWidgets('renders the key bar and sends Esc and Ctrl+C', (tester) async {
    final locks = <bool>[];
    final runtime = FakeWorkspaceRuntime();
    final runtimeProvider = WorkspaceRuntimeProvider()..register(runtime);
    final manager = TerminalSessionManager(
      setWakelock: (enable) async => locks.add(enable),
    );
    addTearDown(() async {
      await manager.closeAll();
      manager.dispose();
    });

    await manager.open(
      runtime: runtime,
      mounts: const [],
      cwd: '/workspace',
      title: 'Demo',
    );
    await pumpPage(tester, manager: manager, runtimeProvider: runtimeProvider);
    await flushIo(tester);

    expect(find.byKey(TerminalKeyBar.barKey), findsOneWidget);
    expect(find.text('Esc'), findsOneWidget);
    expect(find.text('Ctrl'), findsOneWidget);

    final pty = runtime.lastPty!;
    pty.writes.clear();

    await tester.tap(find.byKey(TerminalKeyBar.escKey));
    await tester.pump();
    await flushIo(tester);
    expect(pty.writtenBytes, contains(0x1b));

    pty.writes.clear();
    await tester.tap(find.byKey(TerminalKeyBar.ctrlKey));
    await tester.pump();
    manager.sessions.first.terminal.textInput('c');
    await tester.pump();
    await flushIo(tester);
    expect(pty.writtenBytes, contains(0x03));
  });

  testWidgets('pinch changes font size within bounds', (tester) async {
    final runtime = FakeWorkspaceRuntime();
    final runtimeProvider = WorkspaceRuntimeProvider()..register(runtime);
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
    expect(session.fontSize, 14);

    await pumpPage(tester, manager: manager, runtimeProvider: runtimeProvider);
    await flushIo(tester);

    final center = tester.getCenter(find.byKey(TerminalPage.pinchAreaKey));
    final pointer1 = await tester.startGesture(center + const Offset(-12, 0));
    final pointer2 = await tester.startGesture(center + const Offset(12, 0));
    await tester.pump(const Duration(milliseconds: 20));
    await pointer1.moveBy(const Offset(-80, 0));
    await pointer2.moveBy(const Offset(80, 0));
    await tester.pump();
    await pointer1.up();
    await pointer2.up();
    await tester.pump();

    expect(session.fontSize, greaterThan(14));
    expect(session.fontSize, lessThanOrEqualTo(28));
    expect(manager.defaultFontSize, session.fontSize);

    final grown = session.fontSize;
    final c2 = tester.getCenter(find.byKey(TerminalPage.pinchAreaKey));
    final p1 = await tester.startGesture(c2 + const Offset(-80, 0));
    final p2 = await tester.startGesture(c2 + const Offset(80, 0));
    await tester.pump(const Duration(milliseconds: 20));
    await p1.moveBy(const Offset(70, 0));
    await p2.moveBy(const Offset(-70, 0));
    await tester.pump();
    await p1.up();
    await p2.up();
    await tester.pump();

    expect(session.fontSize, lessThan(grown));
    expect(session.fontSize, greaterThanOrEqualTo(8));
  });

  testWidgets('desktop fallback renders the system-terminal card', (
    tester,
  ) async {
    final runtime = FakeWorkspaceRuntime(ptySupported: false);
    final runtimeProvider = WorkspaceRuntimeProvider()..register(runtime);
    final manager = TerminalSessionManager(setWakelock: (_) async {});
    addTearDown(() async {
      await manager.closeAll();
      manager.dispose();
    });

    final l10n = await pumpPage(
      tester,
      manager: manager,
      runtimeProvider: runtimeProvider,
      hostDir: '/Users/me/project',
      size: const Size(1280, 800),
    );

    expect(find.byKey(SystemTerminalCard.cardKey), findsOneWidget);
    expect(find.byKey(TerminalKeyBar.barKey), findsNothing);
    expect(find.text(l10n.terminalOpenInSystem), findsOneWidget);
    expect(find.text('/Users/me/project'), findsOneWidget);

    await tester.tap(find.byKey(SystemTerminalCard.openKey));
    await tester.pump();
    expect(runtime.lastSystemDir, '/Users/me/project');
  });

  testWidgets('tab labels are center-aligned', (tester) async {
    final runtime = FakeWorkspaceRuntime();
    final runtimeProvider = WorkspaceRuntimeProvider()..register(runtime);
    final manager = TerminalSessionManager(setWakelock: (_) async {});
    addTearDown(() async {
      await manager.closeAll();
      manager.dispose();
    });

    await manager.open(
      runtime: runtime,
      mounts: const [],
      cwd: '/workspace',
      title: 'Demo',
    );
    await pumpPage(tester, manager: manager, runtimeProvider: runtimeProvider);
    await flushIo(tester);

    final labels = tester.widgetList<Text>(
      find.descendant(
        of: find.byType(TerminalTabStrip),
        matching: find.text('Demo'),
      ),
    );
    expect(labels, isNotEmpty);
    expect(labels.first.textAlign, TextAlign.center);
  });

  testWidgets('alive dot hides after the process exits', (tester) async {
    final runtime = FakeWorkspaceRuntime();
    final runtimeProvider = WorkspaceRuntimeProvider()..register(runtime);
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
    await pumpPage(tester, manager: manager, runtimeProvider: runtimeProvider);
    await flushIo(tester);

    expect(
      find.byKey(TerminalTabStrip.aliveDotKey(session.id)),
      findsOneWidget,
    );
    expect(find.byKey(TerminalTabStrip.exitBadgeKey(session.id)), findsNothing);

    runtime.lastPty!.completeExit(7);
    await flushIo(tester);
    await tester.pump();

    expect(find.byKey(TerminalTabStrip.aliveDotKey(session.id)), findsNothing);
    expect(
      find.byKey(TerminalTabStrip.exitBadgeKey(session.id)),
      findsOneWidget,
    );
  });

  testWidgets('more menu opens as a bottom sheet on mobile', (tester) async {
    final runtime = FakeWorkspaceRuntime();
    final runtimeProvider = WorkspaceRuntimeProvider()..register(runtime);
    final manager = TerminalSessionManager(setWakelock: (_) async {});
    addTearDown(() async {
      await manager.closeAll();
      manager.dispose();
    });

    await manager.open(
      runtime: runtime,
      mounts: const [],
      cwd: '/workspace',
      title: 'Demo',
    );
    final l10n = await pumpPage(
      tester,
      manager: manager,
      runtimeProvider: runtimeProvider,
      size: const Size(400, 900),
    );
    await flushIo(tester);

    final pageContext = tester.element(find.byType(TerminalPage));
    expect(ResponsiveHelper.isMobile(pageContext), isTrue);
    expect(
      MediaQuery.sizeOf(pageContext).width,
      lessThan(AppBreakpoints.tablet),
    );

    await tester.tap(find.byKey(TerminalPage.moreKey));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byKey(CustomBottomSheet.panelKey), findsNothing);
    expect(find.text(l10n.terminalCopyAllOutput), findsOneWidget);
    expect(find.text(l10n.terminalCloseSession), findsOneWidget);
    final error = Theme.of(
      tester.element(find.text(l10n.terminalCloseSession)),
    ).colorScheme.error;
    expect(
      tester.widget<Text>(find.text(l10n.terminalCloseSession)).style?.color,
      error,
    );
  });

  testWidgets('more menu opens as a desktop menu, not a sheet', (tester) async {
    final runtime = FakeWorkspaceRuntime();
    final runtimeProvider = WorkspaceRuntimeProvider()..register(runtime);
    final manager = TerminalSessionManager(setWakelock: (_) async {});
    addTearDown(() async {
      await manager.closeAll();
      manager.dispose();
    });

    await manager.open(
      runtime: runtime,
      mounts: const [],
      cwd: '/workspace',
      title: 'Demo',
    );
    final l10n = await pumpPage(
      tester,
      manager: manager,
      runtimeProvider: runtimeProvider,
      size: const Size(1280, 800),
    );
    await flushIo(tester);

    final pageContext = tester.element(find.byType(TerminalPage));
    expect(ResponsiveHelper.isDesktop(pageContext), isTrue);
    expect(
      MediaQuery.sizeOf(pageContext).width,
      greaterThanOrEqualTo(AppBreakpoints.desktop),
    );

    await tester.tap(find.byKey(TerminalPage.moreKey));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byKey(CustomBottomSheet.panelKey), findsNothing);
    expect(find.text(l10n.terminalCopyAllOutput), findsOneWidget);
    expect(find.text(l10n.terminalCloseSession), findsOneWidget);
  });

  testWidgets('shows the system-terminal card when there is no session', (
    tester,
  ) async {
    final runtime = FakeWorkspaceRuntime();
    final runtimeProvider = WorkspaceRuntimeProvider()..register(runtime);
    final manager = TerminalSessionManager(setWakelock: (_) async {});
    addTearDown(() async {
      await manager.closeAll();
      manager.dispose();
    });

    await pumpPage(tester, manager: manager, runtimeProvider: runtimeProvider);

    expect(find.byKey(SystemTerminalCard.cardKey), findsOneWidget);
    expect(find.byKey(TerminalPage.pinchAreaKey), findsNothing);
    final button = tester.widget<IosTileButton>(
      find.descendant(
        of: find.byKey(SystemTerminalCard.openKey),
        matching: find.byType(IosTileButton),
      ),
    );
    expect(button.enabled, isFalse);
  });

  testWidgets('system-terminal open button is disabled when onOpen is null', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(400, 900);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildLightTheme(null),
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(
          body: SystemTerminalCard(hostDir: '/tmp/workspace'),
        ),
      ),
    );
    await tester.pump();

    final button = tester.widget<IosTileButton>(
      find.descendant(
        of: find.byKey(SystemTerminalCard.openKey),
        matching: find.byType(IosTileButton),
      ),
    );
    expect(button.enabled, isFalse);
  });
}
