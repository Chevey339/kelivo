import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/features/workspace/terminal/terminal_session_manager.dart';
import 'package:Kelivo/features/workspace/terminal/widgets/terminal_tab_strip.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/responsive/breakpoints.dart';
import 'package:Kelivo/shared/responsive/screen_type_helper.dart';
import 'package:Kelivo/shared/widgets/custom_bottom_sheet.dart';
import 'package:Kelivo/theme/theme_factory.dart';

import 'fake_workspace_runtime.dart';

void main() {
  Future<void> flushIo(WidgetTester tester) async {
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    });
    await tester.pump();
  }

  Future<void> pumpStrip(
    WidgetTester tester, {
    required TerminalSessionManager manager,
    required String? activeId,
    Size size = const Size(400, 900),
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildLightTheme(null),
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: ListenableBuilder(
            listenable: manager,
            builder: (context, _) {
              return TerminalTabStrip(
                sessions: manager.sessions,
                activeId:
                    activeId ??
                    (manager.sessions.isEmpty
                        ? null
                        : manager.sessions.first.id),
                onSelect: (_) {},
                onAdd: () {},
                onRename: (_) {},
                onClose: (_) {},
              );
            },
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
  }

  testWidgets('tab labels are center-aligned', (tester) async {
    final runtime = FakeWorkspaceRuntime();
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
    await pumpStrip(
      tester,
      manager: manager,
      activeId: manager.sessions.first.id,
    );

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
    await pumpStrip(tester, manager: manager, activeId: session.id);
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

  testWidgets('tab long-press opens a bottom sheet on mobile', (tester) async {
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
    await pumpStrip(
      tester,
      manager: manager,
      activeId: session.id,
      size: const Size(400, 900),
    );

    final stripContext = tester.element(find.byType(TerminalTabStrip));
    final l10n = AppLocalizations.of(stripContext)!;
    expect(ResponsiveHelper.isMobile(stripContext), isTrue);
    expect(
      MediaQuery.sizeOf(stripContext).width,
      lessThan(AppBreakpoints.tablet),
    );

    await tester.longPress(find.byKey(TerminalTabStrip.tabKey(session.id)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byKey(CustomBottomSheet.panelKey), findsNothing);
    expect(find.text(l10n.terminalRename), findsOneWidget);
    expect(find.text(l10n.terminalClose), findsOneWidget);
    final error = Theme.of(
      tester.element(find.text(l10n.terminalClose)),
    ).colorScheme.error;
    expect(
      tester.widget<Text>(find.text(l10n.terminalClose)).style?.color,
      error,
    );
  });

  testWidgets('long title chip stays within 180px', (tester) async {
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
      title: 'A' * 40,
    );
    await pumpStrip(tester, manager: manager, activeId: session.id);

    final size = tester.getSize(
      find.byKey(TerminalTabStrip.tabKey(session.id)),
    );
    expect(size.width, lessThanOrEqualTo(180));
    expect(size.width, greaterThanOrEqualTo(96));
  });

  testWidgets('short title chip is at least 96px', (tester) async {
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
      title: 'A',
    );
    await pumpStrip(tester, manager: manager, activeId: session.id);

    final size = tester.getSize(
      find.byKey(TerminalTabStrip.tabKey(session.id)),
    );
    expect(size.width, greaterThanOrEqualTo(96));
    expect(size.width, lessThanOrEqualTo(180));
  });

  testWidgets('first tab is visible at x >= 12 and the strip scrolls', (
    tester,
  ) async {
    final runtime = FakeWorkspaceRuntime();
    final manager = TerminalSessionManager(setWakelock: (_) async {});
    addTearDown(() async {
      await manager.closeAll();
      manager.dispose();
    });

    late TerminalSession first;
    for (var i = 0; i < 8; i++) {
      final session = await manager.open(
        runtime: runtime,
        mounts: const [],
        cwd: '/workspace',
        title: 'Session ${i + 1} with a longer label',
      );
      if (i == 0) first = session;
    }
    await pumpStrip(
      tester,
      manager: manager,
      activeId: first.id,
      size: const Size(390, 844),
    );

    final firstFinder = find.byKey(TerminalTabStrip.tabKey(first.id));
    final start = tester.getRect(firstFinder);
    expect(start.left, greaterThanOrEqualTo(12));
    expect(start.width, lessThanOrEqualTo(180));

    final scrollable = tester.state<ScrollableState>(
      find.descendant(
        of: find.byType(TerminalTabStrip),
        matching: find.byType(Scrollable),
      ),
    );
    expect(scrollable.position.maxScrollExtent, greaterThan(0));

    await tester.drag(
      find.descendant(
        of: find.byType(TerminalTabStrip),
        matching: find.byType(ListView),
      ),
      const Offset(-240, 0),
    );
    await tester.pumpAndSettle();
    expect(scrollable.position.pixels, greaterThan(0));
  });

  testWidgets('tab long-press opens a desktop menu, not a sheet', (
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
    await pumpStrip(
      tester,
      manager: manager,
      activeId: session.id,
      size: const Size(1280, 800),
    );

    final stripContext = tester.element(find.byType(TerminalTabStrip));
    final l10n = AppLocalizations.of(stripContext)!;
    expect(ResponsiveHelper.isDesktop(stripContext), isTrue);
    expect(
      MediaQuery.sizeOf(stripContext).width,
      greaterThanOrEqualTo(AppBreakpoints.desktop),
    );

    await tester.longPress(find.byKey(TerminalTabStrip.tabKey(session.id)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byKey(CustomBottomSheet.panelKey), findsNothing);
    expect(find.text(l10n.terminalRename), findsOneWidget);
    expect(find.text(l10n.terminalClose), findsOneWidget);
  });
}
