import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';

import 'package:Kelivo/core/models/environment_state.dart';
import 'package:Kelivo/core/providers/environment_provider.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/sandbox/environment_dependencies.dart';
import 'package:Kelivo/core/services/sandbox/environment_installer.dart';
import 'package:Kelivo/core/services/sandbox/environment_manager.dart';
import 'package:Kelivo/core/services/sandbox/mirror_service.dart';
import 'package:Kelivo/core/services/sandbox/mirror_speed_test.dart';
import 'package:Kelivo/core/services/sandbox/rootfs_source.dart';
import 'package:Kelivo/core/services/sandbox/workspace_channel.dart';
import 'package:Kelivo/core/services/workspace/workspace_runtime.dart';
import 'package:Kelivo/features/workspace/pages/environment_download_page.dart';
import 'package:Kelivo/features/workspace/pages/mirror_page.dart';
import 'package:Kelivo/features/workspace/widgets/environment/environment_dependencies_section.dart';
import 'package:Kelivo/features/workspace/widgets/environment/environment_pane.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/theme/theme_factory.dart';
import 'package:Kelivo/shared/widgets/ios_tactile.dart';

import '../../../core/services/sandbox/dependency_test_runtime.dart'
    show DependencyTestRuntime;
import '../../../support/business_test_harness.dart';
import 'environment_test_fakes.dart';

class _Installer extends EnvironmentInstaller {
  _Installer(EnvironmentProvider env)
    : super(
        env: env,
        channel: WorkspaceChannel(),
        source: const RootfsSource(),
        speedTest: MirrorSpeedTest(
          client: MockClient((_) async => http.Response('', 200)),
        ),
      );
  int calls = 0;
  RootfsDownloadSource? usedSource;
  @override
  Future<void> install({void Function(EnvironmentState)? onProgress}) async {
    calls++;
    usedSource = env.downloadSource;
  }
}

class _LogDependencies extends EnvironmentDependencies {
  _LogDependencies({
    required super.env,
    required super.runtime,
    required super.mirrors,
  }) : super(alpine: false) {
    lastAttempt = EnvironmentDependency.python;
  }

  String _log = '';
  @override
  String get log => _log;

  void showLog(String text) {
    _log = text;
    notifyListeners();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('haptic_feedback'),
          (_) async => true,
        );
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('haptic_feedback'), null);
  });
  late EnvironmentProvider env;
  late FakeMirrorService mirrors;
  late DependencyTestRuntime runtime;
  late EnvironmentDependencies service;
  late _Installer installer;

  Future<void> setup(
    WidgetTester tester, {
    bool ready = true,
    bool alpine = false,
    bool logOnly = false,
  }) async {
    await tester.runAsync(() async {
      env = EnvironmentProvider(preferences: createBusinessTestPreferences());
      await env.loaded;
      await env.setState(
        EnvironmentState(
          phase: ready ? EnvironmentPhase.ready : EnvironmentPhase.notInstalled,
        ),
      );
      mirrors = FakeMirrorService(env);
      runtime = DependencyTestRuntime();
      service = logOnly
          ? _LogDependencies(runtime: runtime, env: env, mirrors: mirrors)
          : EnvironmentDependencies(
              runtime: runtime,
              env: env,
              alpine: alpine,
              mirrors: mirrors,
            );
      installer = _Installer(env);
    });
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    EnvironmentPane.debugDiskUsage = () async => 0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      EnvironmentPane.debugDiskUsage = null;
      service.dispose();
      env.dispose();
    });
  }

  Future<void> pump(WidgetTester tester, Widget home) => tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => SettingsProvider(createBusinessTestPreferences()),
        ),
        ChangeNotifierProvider<EnvironmentProvider>.value(value: env),
        ListenableProvider<EnvironmentDependencies?>.value(value: service),
        Provider<EnvironmentManager?>.value(value: installer),
        Provider<MirrorService?>.value(value: mirrors),
        ChangeNotifierProvider(
          create: (_) => WorkspaceRuntimeProvider()..register(runtime),
        ),
      ],
      child: MaterialApp(
        theme: buildLightTheme(null),
        locale: const Locale('zh'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: home,
      ),
    ),
  );

  String logLines(int count) =>
      List.generate(count, (index) => 'Installing package $index').join('\n');

  final logPanel = find.byKey(const ValueKey('environment-dependency-log'));
  ScrollController logController(WidgetTester tester) => tester
      .widget<SingleChildScrollView>(
        find.descendant(
          of: logPanel,
          matching: find.byType(SingleChildScrollView),
        ),
      )
      .controller!;

  Future<_LogDependencies> pumpLog(WidgetTester tester) async {
    await setup(tester, logOnly: true);
    final logs = service as _LogDependencies;
    logs.showLog(logLines(80));
    await pump(
      tester,
      EnvironmentDependencyPage(
        service: logs,
        dependency: EnvironmentDependency.python,
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(logPanel);
    await tester.pumpAndSettle();
    return logs;
  }

  testWidgets(
    'installation log stays bounded and follows new output',
    (tester) async {
      final logs = await pumpLog(tester);
      final height = tester.getSize(logPanel).height;
      final scroll = logController(tester);
      final previousMax = scroll.position.maxScrollExtent;
      final page = tester.state<ScrollableState>(
        find
            .descendant(
              of: find.byType(ListView),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      final pageMax = page.position.maxScrollExtent;
      expect(height, 240);
      expect(previousMax, greaterThan(0));
      expect(scroll.position.extentAfter, closeTo(0, 0.1));

      logs.showLog(logLines(100));
      await tester.pumpAndSettle();
      expect(tester.getSize(logPanel).height, height);
      expect(page.position.maxScrollExtent, pageMax);
      expect(scroll.position.maxScrollExtent, greaterThan(previousMax));
      expect(scroll.position.extentAfter, closeTo(0, 0.1));
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.mobile(),
  );

  testWidgets(
    'scrolling up pauses log following until back at the bottom',
    (tester) async {
      final logs = await pumpLog(tester);
      final scroll = logController(tester);
      await tester.drag(logPanel, const Offset(0, 150));
      await tester.pumpAndSettle();
      final readingOffset = scroll.offset;
      expect(scroll.position.extentAfter, greaterThan(24));

      logs.showLog(logLines(90));
      await tester.pumpAndSettle();
      expect(scroll.offset, closeTo(readingOffset, 0.1));

      await tester.drag(logPanel, const Offset(0, -1500));
      await tester.pumpAndSettle();
      expect(scroll.position.extentAfter, closeTo(0, 0.1));
      logs.showLog(logLines(100));
      await tester.pumpAndSettle();
      expect(scroll.position.extentAfter, closeTo(0, 0.1));

      logs.showLog('');
      await tester.pumpAndSettle();
      expect(logPanel, findsNothing);
      logs.showLog(logLines(80));
      await tester.pumpAndSettle();
      expect(logController(tester).position.extentAfter, closeTo(0, 0.1));
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.mobile(),
  );

  testWidgets(
    'Android install opens source selection before any download',
    (tester) async {
      await setup(tester, ready: false);
      await pump(tester, const Scaffold(body: EnvironmentPane()));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(EnvironmentPane.installKey));
      await tester.pumpAndSettle();
      expect(find.byType(EnvironmentDownloadPage), findsOneWidget);
      expect(installer.calls, 0);
      await tester.tap(find.byKey(const ValueKey('download-source-tuna')));
      expect(installer.calls, 0);
      final save = find.byKey(const ValueKey('download-source-save'));
      await tester.ensureVisible(save);
      await tester.tap(save);
      await tester.runAsync(
        () async => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await tester.pumpAndSettle();
      expect(installer.calls, 1);
      expect(installer.usedSource, RootfsDownloadSource.tuna);
      expect(mirrors.autoDetectCalls, 0);
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets(
    'custom source validates URL and saves the exact archive link',
    (tester) async {
      await setup(tester);
      await pump(
        tester,
        Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => EnvironmentDownloadPage(installer: installer),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('download-source-custom')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextField),
        'file:///tmp/rootfs.tar.gz',
      );
      final save = find.byKey(const ValueKey('download-source-save'));
      await tester.ensureVisible(save);
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(env.downloadSource, RootfsDownloadSource.automatic);
      expect(find.text('请输入有效的 HTTP 或 HTTPS 链接。'), findsOneWidget);
      await tester.enterText(
        find.byType(TextField),
        'https://mirror.test/image.tar.gz?token=x%2Fy',
      );
      await tester.ensureVisible(save);
      await tester.tap(save);
      await tester.runAsync(
        () async => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await tester.pumpAndSettle();
      expect(env.downloadUrl, 'https://mirror.test/image.tar.gz?token=x%2Fy');
      expect(find.byType(EnvironmentDownloadPage), findsNothing);
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets(
      '$platform presets install and expose the platform package source',
      (tester) async {
        await setup(tester, alpine: platform == TargetPlatform.iOS);
        await tester.runAsync(service.refresh);
        await pump(
          tester,
          Scaffold(
            body: ListView(
              children: [
                EnvironmentDependenciesSection(service: service, enabled: true),
              ],
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Python'), findsOneWidget);
        expect(find.text('Node.js'), findsOneWidget);
        expect(find.text('SSH'), findsOneWidget);
        await tester.tap(
          find.byKey(const ValueKey('environment-dependency-python')),
        );
        await tester.pumpAndSettle();
        final category = platform == TargetPlatform.iOS ? 'APK' : 'APT';
        expect(find.text(category), findsOneWidget);
        expect(find.text('pip'), findsOneWidget);
        await tester.tap(find.text(category));
        await tester.pumpAndSettle();
        expect(find.byType(MirrorPage), findsOneWidget);
        final mirrorCategory = platform == TargetPlatform.iOS
            ? MirrorCategory.apk
            : MirrorCategory.apt;
        final toggle = find.byKey(EnvironmentPane.useMirrorKey(mirrorCategory));
        await tester.tap(toggle);
        await tester.runAsync(
          () async => Future<void>.delayed(const Duration(milliseconds: 30)),
        );
        await tester.pumpAndSettle();
        expect(env.mirrors[mirrorCategory]?.useMirror, isTrue);
        expect(
          env.mirrors[mirrorCategory]?.mirrorId,
          platform == TargetPlatform.iOS ? 'alpine.tuna' : 'apt.tuna',
        );
        await tester.tap(toggle);
        await tester.runAsync(
          () async => Future<void>.delayed(const Duration(milliseconds: 30)),
        );
        await tester.pumpAndSettle();
        expect(env.mirrors[mirrorCategory]?.useMirror, isFalse);
        await tester.pump(const Duration(seconds: 4));
        await tester.pumpAndSettle();
        await tester.tap(
          find
              .descendant(
                of: find.byType(MirrorPage),
                matching: find.byType(IosIconButton),
              )
              .first,
        );
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const ValueKey('environment-dependency-install')),
        );
        await tester.runAsync(
          () async => Future<void>.delayed(const Duration(milliseconds: 30)),
        );
        await tester.pumpAndSettle();
        expect(
          service.status(EnvironmentDependency.python),
          DependencyStatus.installed,
        );
        expect(find.text('已安装'), findsOneWidget);
        expect(find.text('安装日志'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
      variant: TargetPlatformVariant.only(platform),
    );
  }
}
