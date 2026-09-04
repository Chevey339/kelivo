import 'dart:async';
import 'dart:io';

import 'package:Kelivo/core/database/app_database.dart';
import 'package:Kelivo/core/database/extension_entity_store.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/providers/workspace_provider.dart';
import 'package:Kelivo/core/services/chat/chat_service.dart';
import 'package:Kelivo/core/services/workspace/workspace_runtime.dart';
import 'package:Kelivo/features/workspace/terminal/open_terminal.dart';
import 'package:Kelivo/features/workspace/terminal/terminal_page.dart';
import 'package:Kelivo/features/workspace/terminal/terminal_session_manager.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/widgets/snackbar.dart';
import 'package:Kelivo/theme/theme_factory.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:provider/provider.dart';

import '../../../support/business_test_harness.dart';
import 'fake_workspace_runtime.dart';

class _FakePathProviderPlatform extends PathProviderPlatform {
  _FakePathProviderPlatform(this.path);

  final String path;

  @override
  Future<String?> getApplicationDocumentsPath() async => path;

  @override
  Future<String?> getApplicationSupportPath() async => path;

  @override
  Future<String?> getApplicationCachePath() async => p.join(path, 'cache');

  @override
  Future<String?> getTemporaryPath() async => p.join(path, 'tmp');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late PathProviderPlatform previousPathProvider;
  late AppDatabase database;
  late WorkspaceProvider workspaces;

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync('kelivo_open_terminal_');
    previousPathProvider = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _FakePathProviderPlatform(tempDir.path);
    database = AppDatabase(NativeDatabase.memory());
    await database.customSelect('SELECT 1;').getSingle();
    workspaces = WorkspaceProvider(store: ExtensionEntityStore(database));
    await workspaces.loaded;
  });

  tearDown(() async {
    PathProviderPlatform.instance = previousPathProvider;
    await database.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  Future<BuildContext> pumpShell(
    WidgetTester tester, {
    required WorkspaceRuntimeProvider runtimeProvider,
    required TerminalSessionManager manager,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(400, 900);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(
            create: (_) => SettingsProvider(createBusinessTestPreferences()),
          ),
          ChangeNotifierProvider<WorkspaceProvider>.value(value: workspaces),
          ChangeNotifierProvider<ChatService>(create: (_) => ChatService()),
          ChangeNotifierProvider<WorkspaceRuntimeProvider>.value(
            value: runtimeProvider,
          ),
          ChangeNotifierProvider<TerminalSessionManager>.value(value: manager),
        ],
        child: MaterialApp(
          theme: buildLightTheme(null),
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const AppSnackBarOverlay(child: Scaffold(body: SizedBox())),
        ),
      ),
    );
    await tester.pump();
    return tester.element(find.byType(Scaffold));
  }

  testWidgets('stale not-ready cache still opens when status() is ready', (
    tester,
  ) async {
    final workspace = await tester.runAsync(
      () => workspaces.create(name: 'Verify'),
    );
    if (workspace == null) fail('workspace create failed');

    final runtime = FakeWorkspaceRuntime(ready: true);
    final runtimeProvider = WorkspaceRuntimeProvider()
      ..register(runtime)
      ..lastStatus = const RuntimeStatus(
        ready: false,
        reason: 'rootfs_not_installed',
        engine: 'ish',
        sandboxed: true,
      );
    final manager = TerminalSessionManager(setWakelock: (_) async {});
    addTearDown(() async {
      await manager.closeAll();
      manager.dispose();
    });

    final context = await pumpShell(
      tester,
      runtimeProvider: runtimeProvider,
      manager: manager,
    );
    // openTerminal awaits Navigator.push; do not wait for the route to pop.
    await tester.runAsync(() async {
      unawaited(openTerminal(context, workspaceId: workspace.id));
      await Future<void>.delayed(const Duration(milliseconds: 80));
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(runtime.statusCalls, greaterThan(0));
    expect(runtimeProvider.lastStatus?.ready, isTrue);
    expect(find.byType(TerminalPage), findsOneWidget);

    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await tester.pump();
  });

  testWidgets('genuinely not-ready status shows a snackbar', (tester) async {
    final workspace = await tester.runAsync(
      () => workspaces.create(name: 'Verify'),
    );
    if (workspace == null) fail('workspace create failed');

    final runtime = FakeWorkspaceRuntime(
      ready: false,
      reason: 'rootfs_not_installed',
    );
    final runtimeProvider = WorkspaceRuntimeProvider()
      ..register(runtime)
      ..lastStatus = const RuntimeStatus(
        ready: true,
        engine: 'ish',
        sandboxed: true,
      );
    final manager = TerminalSessionManager(setWakelock: (_) async {});
    addTearDown(() async {
      await manager.closeAll();
      manager.dispose();
    });

    final context = await pumpShell(
      tester,
      runtimeProvider: runtimeProvider,
      manager: manager,
    );
    await tester.runAsync(() {
      return openTerminal(context, workspaceId: workspace.id);
    });
    await tester.pump();
    await tester.pump(const Duration(seconds: 4));

    expect(find.byType(TerminalPage), findsNothing);
    expect(runtimeProvider.lastStatus?.ready, isFalse);
    expect(find.text('rootfs_not_installed'), findsOneWidget);
  });
}
