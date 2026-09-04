import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:Kelivo/core/models/environment_state.dart';
import 'package:Kelivo/core/providers/environment_provider.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/sandbox/environment_manager.dart';
import 'package:Kelivo/core/services/sandbox/mirror_service.dart';
import 'package:Kelivo/core/services/workspace/workspace_runtime.dart';
import 'package:Kelivo/features/workspace/pages/mirror_page.dart';
import 'package:Kelivo/features/workspace/widgets/environment/environment_chrome.dart';
import 'package:Kelivo/features/workspace/widgets/environment/environment_dialogs.dart';
import 'package:Kelivo/features/workspace/widgets/environment/environment_labels.dart';
import 'package:Kelivo/features/workspace/widgets/environment/environment_pane.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/widgets/ios_settings_rows.dart';
import 'package:Kelivo/theme/theme_factory.dart';

import '../../../support/business_test_harness.dart';
import 'environment_test_fakes.dart';

class _Harness {
  _Harness(this.env, this.runtime, this.manager, this.mirrors);

  final EnvironmentProvider env;
  final CountingWorkspaceRuntimeProvider runtime;
  final FakeEnvironmentManager manager;
  final FakeMirrorService mirrors;
}

void main() {
  Future<_Harness> createHarness(
    WidgetTester tester, {
    EnvironmentState state = const EnvironmentState(),
    MirrorSelection? aptMirror,
    Future<int?> Function()? diskUsage,
    bool defaultDiskUsage = true,
    String engine = 'proot',
    int? cachedDiskBytes,
  }) async {
    final harness = await tester.runAsync(() async {
      if (diskUsage != null) {
        EnvironmentPane.debugDiskUsage = diskUsage;
      } else if (defaultDiskUsage) {
        EnvironmentPane.debugDiskUsage = () async => 0;
      } else {
        EnvironmentPane.debugDiskUsage = null;
      }
      final env = EnvironmentProvider(
        preferences: createBusinessTestPreferences(),
      );
      await env.loaded;
      await env.setState(state);
      if (cachedDiskBytes != null) {
        await env.setCachedDiskUsage(
          bytes: cachedDiskBytes,
          root: state.rootfsDir,
        );
      }
      if (aptMirror != null) {
        await env.setMirror(MirrorCategory.apt, aptMirror);
      }
      final runtime = CountingWorkspaceRuntimeProvider()
        ..lastStatus = RuntimeStatus(
          ready: true,
          engine: engine,
          sandboxed: true,
        );
      return _Harness(
        env,
        runtime,
        FakeEnvironmentManager(env),
        FakeMirrorService(env),
      );
    });
    return harness!;
  }

  Future<void> flushIo(WidgetTester tester) async {
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  Future<AppLocalizations> pumpPane(
    WidgetTester tester,
    _Harness harness, {
    bool provideManager = true,
    bool provideMirrors = true,
    Size size = const Size(400, 900),
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(() {
      EnvironmentPane.debugDiskUsage = null;
      EnvironmentPane.diskUsageTimeout = const Duration(seconds: 20);
    });

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(
            create: (_) => SettingsProvider(createBusinessTestPreferences()),
          ),
          ChangeNotifierProvider<EnvironmentProvider>.value(value: harness.env),
          ChangeNotifierProvider<WorkspaceRuntimeProvider>.value(
            value: harness.runtime,
          ),
          Provider<EnvironmentManager?>.value(
            value: provideManager ? harness.manager : null,
          ),
          Provider<MirrorService?>.value(
            value: provideMirrors ? harness.mirrors : null,
          ),
        ],
        child: MaterialApp(
          theme: buildLightTheme(null),
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(body: EnvironmentPane()),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    return AppLocalizations.of(tester.element(find.byType(EnvironmentPane)))!;
  }

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

  testWidgets('install refreshes workspace runtime status', (tester) async {
    await withPlatform(TargetPlatform.android, () async {
      final harness = await createHarness(tester);
      await pumpPane(tester, harness);
      expect(harness.runtime.refreshCalls, 0);
      await tester.tap(find.byKey(EnvironmentPane.installKey));
      await flushIo(tester);
      expect(harness.manager.installCalls, 1);
      expect(harness.runtime.refreshCalls, 1);
    });
  });

  testWidgets('notInstalled shows Install', (tester) async {
    await withPlatform(TargetPlatform.android, () async {
      final harness = await createHarness(tester);
      final l10n = await pumpPane(tester, harness);
      expect(find.byKey(EnvironmentPane.installKey), findsOneWidget);
      expect(find.text(l10n.workspaceEnvInstallEnvironment), findsOneWidget);
      expect(
        find.text(l10n.workspaceEnvInstallSubtitleAndroid),
        findsOneWidget,
      );
      expect(find.byKey(EnvironmentPane.retryKey), findsNothing);
      expect(find.byKey(EnvironmentPane.repairKey), findsNothing);
    });
  });

  testWidgets('downloading shows MB, percent, and Cancel', (tester) async {
    await withPlatform(TargetPlatform.android, () async {
      final harness = await createHarness(
        tester,
        state: const EnvironmentState(
          phase: EnvironmentPhase.downloading,
          bytesDownloaded: 13 * 1024 * 1024,
          bytesTotal: 30 * 1024 * 1024,
        ),
      );
      final l10n = await pumpPane(tester, harness);
      expect(find.byKey(EnvironmentPane.cancelKey), findsOneWidget);
      expect(find.byKey(EnvironmentPane.downloadProgressKey), findsOneWidget);
      expect(
        find.text(
          l10n.workspaceEnvDownloadLine(
            '13.00 MB',
            '30.00 MB',
            l10n.workspaceEnvPhaseDownloading,
          ),
        ),
        findsOneWidget,
      );
      await tester.tap(find.byKey(EnvironmentPane.cancelKey));
      await tester.pump();
      expect(harness.manager.cancelCalls, 1);
    });
  });

  testWidgets('verifying and extracting show phase labels', (tester) async {
    await withPlatform(TargetPlatform.android, () async {
      final harness = await createHarness(
        tester,
        state: const EnvironmentState(
          phase: EnvironmentPhase.verifying,
          progress: 0.5,
        ),
      );
      final l10n = await pumpPane(tester, harness);
      expect(find.text(l10n.workspaceEnvPhaseVerifying), findsWidgets);

      await tester.runAsync(() {
        return harness.env.setState(
          const EnvironmentState(
            phase: EnvironmentPhase.extracting,
            progress: 0.7,
          ),
        );
      });
      await tester.pump();
      expect(find.text(l10n.workspaceEnvPhaseExtracting), findsWidgets);

      await tester.runAsync(() {
        return harness.env.setState(
          const EnvironmentState(
            phase: EnvironmentPhase.patching,
            progress: 0.9,
          ),
        );
      });
      await tester.pump();
      expect(find.text(l10n.workspaceEnvPhasePatching), findsWidgets);
      expect(find.byKey(EnvironmentPane.installKey), findsNothing);
    });
  });

  testWidgets('ready shows Repair, Reset, and Check for update', (
    tester,
  ) async {
    await withPlatform(TargetPlatform.android, () async {
      final harness = await createHarness(
        tester,
        state: const EnvironmentState(
          phase: EnvironmentPhase.ready,
          distro: 'ubuntu',
          version: '24.04',
          arch: 'arm64',
        ),
      );
      final l10n = await pumpPane(tester, harness);
      await tester.scrollUntilVisible(
        find.byKey(EnvironmentPane.repairKey),
        80,
      );
      expect(find.byKey(EnvironmentPane.repairKey), findsOneWidget);
      expect(find.byKey(EnvironmentPane.resetKey), findsOneWidget);
      expect(find.byKey(EnvironmentPane.checkUpdateKey), findsOneWidget);
      expect(find.text(l10n.workspaceEnvRepair), findsOneWidget);
      expect(find.byKey(EnvironmentPane.installKey), findsNothing);
    });
  });

  testWidgets('error code shows message and Retry calls install', (
    tester,
  ) async {
    await withPlatform(TargetPlatform.android, () async {
      final harness = await createHarness(
        tester,
        state: const EnvironmentState(
          phase: EnvironmentPhase.error,
          errorMessage: 'network',
        ),
      );
      final l10n = await pumpPane(tester, harness);
      expect(find.text(l10n.workspaceEnvErrorNetwork), findsOneWidget);
      expect(find.byKey(EnvironmentPane.retryKey), findsOneWidget);
      await tester.tap(find.byKey(EnvironmentPane.retryKey));
      await flushIo(tester);
      expect(harness.manager.installCalls, 1);
    });
  });

  testWidgets('insufficient_disk shows free-space hint', (tester) async {
    await withPlatform(TargetPlatform.android, () async {
      final harness = await createHarness(
        tester,
        state: const EnvironmentState(
          phase: EnvironmentPhase.error,
          errorMessage: 'insufficient_disk',
        ),
      );
      final l10n = await pumpPane(tester, harness);
      expect(find.text(l10n.workspaceEnvErrorInsufficientDisk), findsOneWidget);
      expect(
        find.text(l10n.workspaceEnvErrorInsufficientDiskHint),
        findsOneWidget,
      );
    });
  });

  testWidgets('needsRestart shows banner and hides install', (tester) async {
    await withPlatform(TargetPlatform.android, () async {
      final harness = await createHarness(
        tester,
        state: const EnvironmentState(phase: EnvironmentPhase.needsRestart),
      );
      final l10n = await pumpPane(tester, harness);
      expect(find.byKey(EnvironmentPane.restartBannerKey), findsOneWidget);
      expect(find.text(l10n.workspaceEnvRestartDoneBanner), findsOneWidget);
      expect(find.byKey(EnvironmentPane.installKey), findsNothing);
    });
  });

  testWidgets('reset asks for confirmation then calls reset', (tester) async {
    await withPlatform(TargetPlatform.android, () async {
      final harness = await createHarness(
        tester,
        state: const EnvironmentState(phase: EnvironmentPhase.ready),
      );
      final l10n = await pumpPane(tester, harness);
      await tester.scrollUntilVisible(find.byKey(EnvironmentPane.resetKey), 80);
      await tester.tap(find.byKey(EnvironmentPane.resetKey));
      await tester.pump();
      expect(find.text(l10n.workspaceEnvResetConfirmMessage), findsOneWidget);
      expect(harness.manager.resetCalls, 0);

      await tester.tap(find.byKey(EnvironmentDialogKeys.resetCancel));
      await tester.pump();
      expect(harness.manager.resetCalls, 0);

      await tester.scrollUntilVisible(find.byKey(EnvironmentPane.resetKey), 80);
      await tester.tap(find.byKey(EnvironmentPane.resetKey));
      await tester.pump();
      await tester.tap(find.byKey(EnvironmentDialogKeys.resetConfirm));
      await flushIo(tester);
      expect(harness.manager.resetCalls, 1);
    });
  });

  testWidgets('check for update reveals Update that runs install', (
    tester,
  ) async {
    await withPlatform(TargetPlatform.android, () async {
      final harness = await createHarness(
        tester,
        state: const EnvironmentState(phase: EnvironmentPhase.ready),
      );
      harness.manager.updateVersion = '24.04.3';
      final l10n = await pumpPane(tester, harness);
      await tester.scrollUntilVisible(
        find.byKey(EnvironmentPane.checkUpdateKey),
        80,
      );
      await tester.tap(find.byKey(EnvironmentPane.checkUpdateKey));
      await flushIo(tester);
      expect(harness.manager.checkForUpdateCalls, 1);
      await tester.runAsync(() {
        return harness.env.setState(
          harness.env.state.copyWith(availableVersion: '24.04.3'),
        );
      });
      await tester.pump();
      expect(
        find.text(l10n.workspaceEnvUpdateAvailableShort('24.04.3')),
        findsOneWidget,
      );
      expect(find.byKey(EnvironmentPane.updateKey), findsOneWidget);
      await tester.tap(find.byKey(EnvironmentPane.updateKey));
      await flushIo(tester);
      expect(harness.manager.installCalls, 1);
    });
  });

  testWidgets('mirrors section opens MirrorPage with named rows', (
    tester,
  ) async {
    await withPlatform(TargetPlatform.android, () async {
      final harness = await createHarness(
        tester,
        state: const EnvironmentState(phase: EnvironmentPhase.ready),
        aptMirror: const MirrorSelection(
          selectedBaseUrl: 'https://mirrors.example/ubuntu',
          useMirror: true,
        ),
      );
      final l10n = await pumpPane(tester, harness);
      expect(find.text('mirrors.example'), findsOneWidget);
      expect(find.byKey(EnvironmentPane.detectAllKey), findsOneWidget);
      expect(find.byKey(EnvironmentPane.mirrorsSectionKey), findsOneWidget);

      await tester.scrollUntilVisible(
        find.byKey(EnvironmentPane.detectKey(MirrorCategory.apt)),
        80,
      );
      await tester.tap(
        find.byKey(EnvironmentPane.detectKey(MirrorCategory.apt)),
      );
      await tester.pumpAndSettle();

      expect(find.byType(MirrorPage), findsOneWidget);
      expect(find.text(l10n.workspaceEnvUseMirror), findsWidgets);
      expect(
        find.byKey(EnvironmentPane.useMirrorKey(MirrorCategory.apt)),
        findsOneWidget,
      );
      expect(find.byKey(MirrorPageBody.rowKey('apt.official')), findsOneWidget);
      await tester.scrollUntilVisible(
        find.byKey(MirrorPageBody.rowKey('apt.tuna')),
        80,
      );
      expect(find.byKey(MirrorPageBody.rowKey('apt.tuna')), findsOneWidget);
    });
  });

  testWidgets('embedded pane is a Column without its own ListView', (
    tester,
  ) async {
    await withPlatform(TargetPlatform.android, () async {
      final harness = await createHarness(tester);
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(400, 900);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(() {
        EnvironmentPane.debugDiskUsage = null;
        EnvironmentPane.diskUsageTimeout = const Duration(seconds: 20);
      });

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(
              create: (_) => SettingsProvider(createBusinessTestPreferences()),
            ),
            ChangeNotifierProvider<EnvironmentProvider>.value(
              value: harness.env,
            ),
            ChangeNotifierProvider<WorkspaceRuntimeProvider>.value(
              value: harness.runtime,
            ),
            Provider<EnvironmentManager?>.value(value: harness.manager),
            Provider<MirrorService?>.value(value: harness.mirrors),
          ],
          child: MaterialApp(
            theme: buildLightTheme(null),
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(
              body: SingleChildScrollView(
                child: EnvironmentPane(embedded: true),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(
        find.descendant(
          of: find.byType(EnvironmentPane),
          matching: find.byType(ListView),
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: find.byType(EnvironmentPane),
          matching: find.byType(Column),
        ),
        findsWidgets,
      );
    });
  });

  testWidgets('desktop pane shows native explanation and no install', (
    tester,
  ) async {
    await withPlatform(TargetPlatform.macOS, () async {
      final harness = await createHarness(tester);
      final l10n = await pumpPane(
        tester,
        harness,
        provideManager: false,
        provideMirrors: false,
        size: const Size(1280, 900),
      );
      expect(find.byKey(EnvironmentPane.nativeExplanationKey), findsOneWidget);
      expect(find.text(l10n.workspaceEnvNativeExplanation), findsOneWidget);
      expect(find.text(l10n.workspaceEnvEngineLocalShell), findsOneWidget);
      expect(find.byKey(EnvironmentPane.installKey), findsNothing);
      expect(find.byKey(EnvironmentPane.mirrorsSectionKey), findsNothing);
    });
  });

  testWidgets('formats alpine version in title and arch row', (tester) async {
    await withPlatform(TargetPlatform.iOS, () async {
      final harness = await createHarness(
        tester,
        engine: 'ish',
        state: const EnvironmentState(
          phase: EnvironmentPhase.ready,
          distro: 'alpine',
          version: 'alpine-3.21.3-r4',
          arch: 'arm64',
        ),
      );
      final l10n = await pumpPane(tester, harness);
      expect(
        find.text(l10n.workspaceEnvEngineAlpine('3.21.3')),
        findsOneWidget,
      );
      expect(
        find.text(l10n.workspaceEnvArchVersion('arm64', '3.21.3')),
        findsOneWidget,
      );
      expect(find.textContaining('alpine-3.21.3-r4'), findsNothing);
    });
  });

  testWidgets('size cell waits independently of the path row', (tester) async {
    await withPlatform(TargetPlatform.android, () async {
      final hang = Completer<int?>();
      addTearDown(() {
        if (!hang.isCompleted) hang.complete(0);
      });
      final harness = await createHarness(
        tester,
        defaultDiskUsage: false,
        diskUsage: () => hang.future,
        state: const EnvironmentState(
          phase: EnvironmentPhase.ready,
          distro: 'ubuntu',
          version: '24.04.3',
          arch: 'arm64',
          rootfsDir: '/data/local/tmp/ubuntu-rootfs',
        ),
      );
      final l10n = await pumpPane(tester, harness, size: const Size(1280, 900));
      expect(find.byKey(EnvironmentPane.pathRowKey), findsOneWidget);
      expect(find.text(l10n.workspaceEnvPathLabel), findsOneWidget);
      expect(find.byType(EnvironmentInlineSpinner), findsOneWidget);
      expect(find.byKey(EnvironmentPane.sizeTimeoutKey), findsNothing);
    });
  });

  testWidgets('cached size is shown while measurement is in flight', (
    tester,
  ) async {
    await withPlatform(TargetPlatform.android, () async {
      final hang = Completer<int?>();
      addTearDown(() {
        if (!hang.isCompleted) hang.complete(0);
      });
      final harness = await createHarness(
        tester,
        defaultDiskUsage: false,
        diskUsage: () => hang.future,
        cachedDiskBytes: 13 * 1024 * 1024,
        state: const EnvironmentState(
          phase: EnvironmentPhase.ready,
          distro: 'ubuntu',
          version: '24.04.3',
          arch: 'arm64',
          rootfsDir: '/data/local/tmp/ubuntu-rootfs',
        ),
      );
      await pumpPane(tester, harness);
      expect(find.text('13.00 MB'), findsOneWidget);
      expect(find.byType(EnvironmentInlineSpinner), findsNothing);
    });
  });

  testWidgets('size timeout shows em dash instead of a spinner', (
    tester,
  ) async {
    await withPlatform(TargetPlatform.android, () async {
      EnvironmentPane.diskUsageTimeout = const Duration(milliseconds: 40);
      final harness = await createHarness(
        tester,
        defaultDiskUsage: false,
        diskUsage: () async {
          await Future<void>.delayed(EnvironmentPane.diskUsageTimeout);
          throw TimeoutException('disk');
        },
        state: const EnvironmentState(
          phase: EnvironmentPhase.ready,
          distro: 'ubuntu',
          version: '24.04.3',
          arch: 'arm64',
          rootfsDir: '/data/local/tmp/ubuntu-rootfs',
        ),
      );
      final l10n = await pumpPane(tester, harness);
      await tester.pump(const Duration(milliseconds: 80));
      expect(find.byKey(EnvironmentPane.sizeTimeoutKey), findsOneWidget);
      expect(find.text(l10n.workspaceEnvSizeTimeout), findsWidgets);
      expect(find.byType(EnvironmentInlineSpinner), findsNothing);
    });
  });

  testWidgets('mobile hides the path row', (tester) async {
    await withPlatform(TargetPlatform.android, () async {
      final harness = await createHarness(
        tester,
        state: const EnvironmentState(
          phase: EnvironmentPhase.ready,
          distro: 'ubuntu',
          version: '24.04.3',
          arch: 'arm64',
          rootfsDir: '/data/local/tmp/ubuntu-rootfs',
        ),
      );
      final l10n = await pumpPane(tester, harness, size: const Size(400, 900));
      expect(find.byKey(EnvironmentPane.pathRowKey), findsNothing);
      expect(find.text(l10n.workspaceEnvPathLabel), findsNothing);
      expect(find.byKey(EnvironmentPane.sizeRowKey), findsOneWidget);
    });
  });

  testWidgets('pane rows use plain icons, error reset, and mirror detailText', (
    tester,
  ) async {
    await withPlatform(TargetPlatform.android, () async {
      final harness = await createHarness(
        tester,
        state: const EnvironmentState(
          phase: EnvironmentPhase.ready,
          distro: 'ubuntu',
          version: '24.04',
        ),
        aptMirror: const MirrorSelection(
          selectedBaseUrl: 'https://mirrors.aliyun.com/ubuntu',
          useMirror: true,
          mirrorId: 'apt.aliyun',
        ),
      );
      harness.manager.mirrorCategories = {
        MirrorCategory.apt,
        MirrorCategory.pip,
      };
      final l10n = await pumpPane(tester, harness, size: const Size(400, 1600));
      late Color error;
      error = Theme.of(
        tester.element(find.byType(EnvironmentPane)),
      ).colorScheme.error;

      final rows = find.descendant(
        of: find.byType(EnvironmentPane),
        matching: find.byType(IosNavRow),
      );
      expect(rows, findsWidgets);
      for (final element in rows.evaluate()) {
        final row = element.widget as IosNavRow;
        if (row.icon == null) continue;
        final iconFinder = find.descendant(
          of: find.byWidget(row),
          matching: find.byIcon(row.icon!),
        );
        expect(iconFinder, findsOneWidget);
        final icon = tester.widget<Icon>(iconFinder);
        expect(icon.size, 20);
        final sizedBox = tester.widget<SizedBox>(
          find.ancestor(of: iconFinder, matching: find.byType(SizedBox)).first,
        );
        expect(sizedBox.width, 36);
        expect(sizedBox.child, isA<Icon>());
        expect(sizedBox.child, isNot(isA<DecoratedBox>()));
        expect(sizedBox.child, isNot(isA<Container>()));
      }

      final resetRow = tester.widget<IosNavRow>(
        find.descendant(
          of: find.byKey(EnvironmentPane.resetKey),
          matching: find.byType(IosNavRow),
        ),
      );
      expect(resetRow.destructive, isTrue);
      expect(
        tester
            .widget<Icon>(
              find.descendant(
                of: find.byKey(EnvironmentPane.resetKey),
                matching: find.byIcon(resetRow.icon!),
              ),
            )
            .color,
        error,
      );
      expect(
        tester
            .widget<Text>(
              find.descendant(
                of: find.byKey(EnvironmentPane.resetKey),
                matching: find.text(l10n.workspaceEnvReset),
              ),
            )
            .style
            ?.color,
        error,
      );

      final aptRow = tester.widget<IosNavRow>(
        find.descendant(
          of: find.byKey(EnvironmentPane.detectKey(MirrorCategory.apt)),
          matching: find.byType(IosNavRow),
        ),
      );
      expect(
        aptRow.detailText,
        workspaceEnvSelectionLabel(
          l10n,
          harness.env.mirrors[MirrorCategory.apt],
          category: MirrorCategory.apt,
        ),
      );
      expect(aptRow.detailText, isNotNull);
      expect(aptRow.detailText, isNot(l10n.workspaceEnvOfficial));
      expect(find.text(aptRow.detailText!), findsWidgets);

      final pipRow = tester.widget<IosNavRow>(
        find.descendant(
          of: find.byKey(EnvironmentPane.detectKey(MirrorCategory.pip)),
          matching: find.byType(IosNavRow),
        ),
      );
      expect(pipRow.detailText, l10n.workspaceEnvOfficial);
    });
  });
}
