import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';

import 'package:Kelivo/core/models/environment_state.dart';
import 'package:Kelivo/core/providers/environment_provider.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/sandbox/rootfs_disk_usage.dart';
import 'package:Kelivo/features/workspace/pages/rootfs_browser_page.dart';
import 'package:Kelivo/features/workspace/widgets/environment/environment_labels.dart';
import 'package:Kelivo/features/workspace/widgets/files/file_browser.dart';
import 'package:Kelivo/l10n/app_localizations.dart';

import '../../../support/business_test_harness.dart';

void main() {
  test('resolveRootfsBrowserDir appends data on iOS', () async {
    final alpine = Directory('/tmp/alpine-rootfs');
    final usage = await resolveRootfsUsageDir(
      rootfsDir: '/tmp/Documents/environment/rootfs',
      platform: TargetPlatform.iOS,
      iosAlpineRootfsDirOverride: () async => alpine,
    );
    final dir = Directory(p.join(usage.path, 'data'));
    expect(dir.path, p.join(alpine.path, 'data'));
    expect(p.basename(dir.path), 'data');
    expect(p.basename(p.dirname(dir.path)), 'alpine-rootfs');
  });

  test('resolveRootfsBrowserDir keeps the host rootfs on Android', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final dir = await resolveRootfsBrowserDir(
      rootfsDir: '/tmp/environment/rootfs',
    );
    expect(dir.path, '/tmp/environment/rootfs');
  });

  test('workspaceEnvGuestPath maps host files onto guest /', () {
    expect(workspaceEnvGuestPath('/host/rootfs', '/host/rootfs'), '/');
    expect(
      workspaceEnvGuestPath('/host/rootfs/etc/apk', '/host/rootfs'),
      '/etc/apk',
    );
  });

  testWidgets('rootfs browser puts sort and hidden in the AppBar', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final root = Directory.systemTemp.createTempSync('kelivo_rootfs_ui_');
    addTearDown(() {
      if (root.existsSync()) {
        root.deleteSync(recursive: true);
      }
    });
    Directory(p.join(root.path, 'etc')).createSync();

    late EnvironmentProvider env;
    await tester.runAsync(() async {
      env = EnvironmentProvider(preferences: createBusinessTestPreferences());
      await env.loaded;
      await env.setState(
        EnvironmentState(phase: EnvironmentPhase.ready, rootfsDir: root.path),
      );
    });

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(
            create: (_) => SettingsProvider(createBusinessTestPreferences()),
          ),
          ChangeNotifierProvider<EnvironmentProvider>.value(value: env),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: RootfsBrowserPage(),
        ),
      ),
    );
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 40)),
    );
    await tester.pump();
    await tester.pump();

    final browser = find.byType(FileBrowser);
    expect(browser, findsOneWidget);
    await tester.runAsync(
      tester.state<FileBrowserState>(browser).refreshEntries,
    );
    await tester.pump();

    expect(find.byType(AppBar), findsOneWidget);
    expect(find.byKey(FileBrowser.sortButtonKey), findsOneWidget);
    expect(find.byKey(FileBrowser.hiddenToggleKey), findsOneWidget);
    expect(find.byKey(FileBrowser.newKey), findsNothing);
    expect(find.byKey(FileBrowser.moreKey), findsNothing);
    expect(find.byKey(FileBrowser.importKey), findsNothing);
    expect(find.byKey(FileBrowser.exportKey), findsNothing);

    final appBarBottom = tester.getRect(find.byType(AppBar)).bottom;
    expect(
      tester.getCenter(find.byKey(FileBrowser.sortButtonKey)).dy,
      lessThan(appBarBottom),
    );
    expect(
      tester.getCenter(find.byKey(FileBrowser.hiddenToggleKey)).dy,
      lessThan(appBarBottom),
    );
    expect(find.byKey(FileBrowser.breadcrumbKey('/')), findsOneWidget);
    expect(find.byKey(FileBrowser.itemKey('etc')), findsOneWidget);
  });
}
