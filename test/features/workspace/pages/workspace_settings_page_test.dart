import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:Kelivo/core/database/app_database.dart';
import 'package:Kelivo/core/database/extension_entity_store.dart';
import 'package:Kelivo/core/models/environment_state.dart';
import 'package:Kelivo/core/providers/environment_provider.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/providers/workspace_provider.dart';
import 'package:Kelivo/core/services/workspace/workspace_runtime.dart';
import 'package:Kelivo/features/workspace/pages/workspace_settings_page.dart';
import 'package:Kelivo/features/workspace/pages/workspaces_page.dart';
import 'package:Kelivo/icons/lucide_adapter.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/widgets/ios_settings_rows.dart';
import 'package:Kelivo/theme/theme_factory.dart';
import 'package:drift/native.dart';

import '../../../support/business_test_harness.dart';
import '../terminal/fake_workspace_runtime.dart';

class _CountingRuntimeProvider extends WorkspaceRuntimeProvider {
  int refreshCalls = 0;

  @override
  Future<RuntimeStatus> refresh() async {
    refreshCalls += 1;
    return super.refresh();
  }
}

void main() {
  Future<T> withPlatform<T>(
    TargetPlatform platform,
    Future<T> Function() body,
  ) async {
    debugDefaultTargetPlatformOverride = platform;
    try {
      return await body();
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  }

  testWidgets('refresh is called once on mount', (tester) async {
    await withPlatform(TargetPlatform.android, () async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(400, 900);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      late EnvironmentProvider env;
      late _CountingRuntimeProvider runtime;
      late WorkspaceProvider workspaces;
      late AppDatabase database;

      await tester.runAsync(() async {
        env = EnvironmentProvider(preferences: createBusinessTestPreferences());
        await env.loaded;
        await env.setState(const EnvironmentState());
        runtime = _CountingRuntimeProvider()
          ..register(FakeWorkspaceRuntime(ready: true));
        database = AppDatabase(NativeDatabase.memory());
        await database.customSelect('SELECT 1;').getSingle();
        workspaces = WorkspaceProvider(store: ExtensionEntityStore(database));
        await workspaces.loaded;
      });
      addTearDown(database.close);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(
              create: (_) => SettingsProvider(createBusinessTestPreferences()),
            ),
            ChangeNotifierProvider<WorkspaceProvider>.value(value: workspaces),
            ChangeNotifierProvider<EnvironmentProvider>.value(value: env),
            ChangeNotifierProvider<WorkspaceRuntimeProvider>.value(
              value: runtime,
            ),
          ],
          child: MaterialApp(
            theme: buildLightTheme(null),
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const WorkspaceSettingsPage(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(runtime.refreshCalls, 1);
      final l10n = AppLocalizations.of(
        tester.element(find.byType(WorkspaceSettingsPage)),
      )!;
      expect(find.text(l10n.workspaceEnvTitle), findsOneWidget);
      expect(find.text(l10n.workspaceEnvEngineLocalShell), findsOneWidget);
      expect(find.text(l10n.workspaceEnvPhaseReady), findsOneWidget);
      expect(find.text(l10n.workspaceEnvPhaseNotInstalled), findsNothing);
      expect(find.byKey(WorkspacesPane.createKey), findsOneWidget);
    });
  });

  testWidgets('formats alpine hub version the same as the environment page', (
    tester,
  ) async {
    await withPlatform(TargetPlatform.iOS, () async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(400, 900);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      late EnvironmentProvider env;
      late WorkspaceRuntimeProvider runtime;
      late WorkspaceProvider workspaces;
      late AppDatabase database;

      await tester.runAsync(() async {
        env = EnvironmentProvider(preferences: createBusinessTestPreferences());
        await env.loaded;
        await env.setState(
          const EnvironmentState(
            phase: EnvironmentPhase.ready,
            distro: 'alpine',
            version: 'alpine-3.21.3-r4',
          ),
        );
        runtime = WorkspaceRuntimeProvider()
          ..register(FakeWorkspaceRuntime(ready: true));
        database = AppDatabase(NativeDatabase.memory());
        await database.customSelect('SELECT 1;').getSingle();
        workspaces = WorkspaceProvider(store: ExtensionEntityStore(database));
        await workspaces.loaded;
      });
      addTearDown(database.close);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(
              create: (_) => SettingsProvider(createBusinessTestPreferences()),
            ),
            ChangeNotifierProvider<WorkspaceProvider>.value(value: workspaces),
            ChangeNotifierProvider<EnvironmentProvider>.value(value: env),
            ChangeNotifierProvider<WorkspaceRuntimeProvider>.value(
              value: runtime,
            ),
          ],
          child: MaterialApp(
            theme: buildLightTheme(null),
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const WorkspaceSettingsPage(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      final l10n = AppLocalizations.of(
        tester.element(find.byType(WorkspaceSettingsPage)),
      )!;
      expect(
        find.text(l10n.workspaceEnvEngineAlpine('3.21.3')),
        findsOneWidget,
      );
      expect(find.textContaining('alpine-3.21.3-r4'), findsNothing);
      expect(
        tester
            .widget<IosNavRow>(
              find.ancestor(
                of: find.text(l10n.workspaceEnvEngineAlpine('3.21.3')),
                matching: find.byType(IosNavRow),
              ),
            )
            .icon,
        Lucide.Package,
      );
    });
  });
}
