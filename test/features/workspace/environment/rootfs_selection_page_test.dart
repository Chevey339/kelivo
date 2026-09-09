import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:Kelivo/core/providers/environment_provider.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/sandbox/environment_installer.dart';
import 'package:Kelivo/core/services/sandbox/rootfs_source.dart';
import 'package:Kelivo/core/services/sandbox/mirror_speed_test.dart';
import 'package:Kelivo/core/services/sandbox/workspace_channel.dart';
import 'package:Kelivo/features/workspace/pages/environment_download_page.dart';
import 'package:Kelivo/features/workspace/pages/proot_options_page.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/widgets/form_sheet.dart';
import '../../../support/business_test_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late EnvironmentProvider env;
  setUp(() async {
    env = EnvironmentProvider(preferences: createBusinessTestPreferences());
    await env.loaded;
  });
  tearDown(() => env.dispose());

  Future<void> show(WidgetTester tester, Widget page) async {
    tester.view.physicalSize = const Size(430, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: env),
          ChangeNotifierProvider(
            create: (_) => SettingsProvider(createBusinessTestPreferences()),
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: page,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> settleWrites(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 20));
    }
    await tester.pumpAndSettle();
  }

  testWidgets(
    'defaults to 24.04.3 and offers other versions in the app picker',
    (tester) async {
      final installer = EnvironmentInstaller(
        channel: WorkspaceChannel(),
        env: env,
        source: const RootfsSource(),
        speedTest: MirrorSpeedTest(),
      );
      await show(tester, EnvironmentDownloadPage(installer: installer));
      expect(env.rootfsImage.id, 'ubuntu-24.04.3');
      expect(find.text('24.04.3'), findsOneWidget);
      expect(find.byType(DropdownButton<String>), findsNothing);
      await tester.tap(find.byKey(const ValueKey('rootfs-version')));
      await tester.pumpAndSettle();
      expect(find.byType(FormSheet), findsOneWidget);
      expect(find.text('24.04.4'), findsOneWidget);
      expect(find.text('22.04.5'), findsOneWidget);
      await tester.tap(find.text('24.04.4'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('rootfs-distro')));
      await tester.pumpAndSettle();
      // Re-selecting the same distribution must keep the explicit version.
      await tester.tap(find.text('Ubuntu').last);
      await tester.pumpAndSettle();
      expect(find.text('24.04.4'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('download-source-save')));
      await settleWrites(tester);
      expect(env.rootfsImage.id, 'ubuntu-24.04.4');
    },
  );

  testWidgets('distribution and version select the matching download sources', (
    tester,
  ) async {
    final installer = EnvironmentInstaller(
      channel: WorkspaceChannel(),
      env: env,
      source: const RootfsSource(),
      speedTest: MirrorSpeedTest(),
    );
    await show(tester, EnvironmentDownloadPage(installer: installer));
    await tester.tap(find.byKey(const ValueKey('rootfs-distro')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Debian').last);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('download-source-tuna')), findsNothing);
    expect(find.text('13'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('rootfs-distro')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ubuntu').last);
    await tester.pumpAndSettle();
    expect(find.text('24.04.3'), findsOneWidget);
    expect(find.byKey(const ValueKey('download-source-tuna')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('rootfs-distro')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Debian').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('rootfs-version')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('12').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('download-source-save')));
    await settleWrites(tester);
    expect(env.rootfsImage.id, 'debian-12');
    expect(env.downloadSource, RootfsDownloadSource.automatic);
  });

  testWidgets('local archive mode does not pretend to select a distribution', (
    tester,
  ) async {
    final installer = EnvironmentInstaller(
      channel: WorkspaceChannel(),
      env: env,
      source: const RootfsSource(),
      speedTest: MirrorSpeedTest(),
    );
    await show(tester, EnvironmentDownloadPage(installer: installer));
    await tester.ensureVisible(
      find.byKey(const ValueKey('download-source-local')),
    );
    await tester.tap(find.byKey(const ValueKey('download-source-local')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('rootfs-distro')), findsNothing);
    expect(find.byKey(const ValueKey('rootfs-local-file')), findsOneWidget);
    await tester.ensureVisible(
      find.byKey(const ValueKey('download-source-save')),
    );
    await tester.tap(find.byKey(const ValueKey('download-source-save')));
    await settleWrites(tester);
    expect(
      find.textContaining('Select a valid rootfs archive'),
      findsOneWidget,
    );
    expect(env.downloadSource, RootfsDownloadSource.automatic);
  });

  testWidgets('shell and exact PRoot argv persist from the editor', (
    tester,
  ) async {
    await show(tester, const ProotOptionsPage());
    final fields = find.byType(EditableText);
    await tester.enterText(fields.at(0), '/bin/sh');
    await tester.enterText(
      fields.at(1),
      '-k\n5.10.0\n-b\n/path with spaces:/mnt',
    );
    await tester.ensureVisible(
      find.byKey(const ValueKey('proot-options-save')),
    );
    await tester.tap(find.byKey(const ValueKey('proot-options-save')));
    await settleWrites(tester);
    expect(env.prootShell, '/bin/sh');
    expect(env.prootArguments, [
      '-k',
      '5.10.0',
      '-b',
      '/path with spaces:/mnt',
    ]);
  });
}
