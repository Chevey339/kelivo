import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:Kelivo/core/database/app_database.dart';
import 'package:Kelivo/core/database/extension_entity_store.dart';
import 'package:Kelivo/core/models/workspace_directory_access.dart';
import 'package:Kelivo/core/providers/external_mounts_provider.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import '../../support/business_test_harness.dart';
import 'package:Kelivo/features/workspace/pages/external_mounts_page.dart';
import 'package:Kelivo/features/workspace/widgets/files/file_browser.dart';
import 'package:Kelivo/features/workspace/widgets/files/file_browser_ops.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/widgets/snackbar.dart';
import '../../core/services/sandbox/sandbox_channel_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;
  late SandboxChannelHarness harness;
  late ExternalMountsProvider provider;
  late Directory root;

  setUp(() async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    root = await Directory.systemTemp.createTemp('kelivo_mount_ui_');
    File('${root.path}/note.txt').writeAsStringSync('hello');
    db = AppDatabase(NativeDatabase.memory());
    harness = SandboxChannelHarness();
    harness.handler = (call) {
      if (call.method == 'resolveDirectory' || call.method == 'pickDirectory') {
        return {'path': root.path, 'token': 'folder'};
      }
      if (call.method == 'hasDirectoryStorageAccess') return true;
      return null;
    };
    harness.install();
    provider = ExternalMountsProvider(
      store: ExtensionEntityStore(db),
      channel: harness.channel,
    );
    await provider.loaded;
    await provider.add(
      WorkspaceDirectory(
        path: root.path,
        access: const WorkspaceDirectoryAccess(
          platform: 'android',
          token: 'folder',
        ),
      ),
      name: 'Notes',
      readOnly: true,
    );
  });

  tearDown(() async {
    provider.dispose();
    harness.dispose();
    await db.close();
    await root.delete(recursive: true);
    debugDefaultTargetPlatformOverride = null;
  });

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
    }
    await tester.pumpAndSettle();
  }

  Future<void> showPage(
    WidgetTester tester, {
    Widget home = const ExternalMountsPage(),
  }) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: provider),
          ChangeNotifierProvider(
            create: (_) => SettingsProvider(createBusinessTestPreferences()),
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: home,
        ),
      ),
    );
    await settle(tester);
  }

  testWidgets('edit independent mount name and permission', (tester) async {
    await showPage(tester);
    expect(find.textContaining('/mounts/Notes'), findsOneWidget);
    await tester.tap(find.text('Notes'));
    await settle(tester);
    final field = find.byType(EditableText);
    await tester.enterText(field, 'Vault');
    final l10n = AppLocalizations.of(tester.element(field))!;
    await tester.tap(find.text(l10n.workspaceMountAllowWrite));
    await tester.tap(find.text(l10n.workspaceFilesSave));
    await settle(tester);
    expect(provider.entries.single.name, 'Vault');
    expect(provider.entries.single.readOnly, false);
    debugDefaultTargetPlatformOverride = null;
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'occupied mount target explains refusal and keeps editor usable',
    (tester) async {
      final previousHandler = harness.handler;
      harness.handler = (call) {
        if (call.method == 'setExternalMounts') {
          final mounts = (call.arguments as Map)['mounts'] as List;
          if (mounts.any((mount) => mount['guest'] == '/mounts/Occupied')) {
            throw PlatformException(code: 'external_mount_target_occupied');
          }
        }
        return previousHandler?.call(call);
      };
      await showPage(tester);
      await tester.tap(find.text('Notes'));
      await settle(tester);
      final field = find.byType(EditableText);
      final l10n = AppLocalizations.of(tester.element(field))!;
      await tester.enterText(field, 'Occupied');
      await tester.tap(find.text(l10n.workspaceFilesSave));
      await settle(tester);
      expect(provider.entries.single.name, 'Notes');
      expect(provider.activeMounts.single.guest, '/mounts/Notes');
      expect(find.text(l10n.workspaceMountTargetOccupied), findsOneWidget);
      expect(find.byType(EditableText), findsOneWidget);
      await tester.enterText(field, 'Available');
      await tester.tap(find.text(l10n.workspaceFilesSave));
      await settle(tester);
      expect(provider.entries.single.name, 'Available');
      debugDefaultTargetPlatformOverride = null;
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('browse uses the external source and enforces read-only UI', (
    tester,
  ) async {
    await showPage(tester);
    await tester.tap(find.text('Notes'));
    await settle(tester);
    final l10n = AppLocalizations.of(
      tester.element(find.byType(EditableText)),
    )!;
    await tester.tap(find.text(l10n.workspaceMountBrowse));
    await settle(tester);
    final browser = tester.widget<FileBrowser>(find.byType(FileBrowser));
    expect(browser.root.path, root.path);
    expect(browser.readOnly, true);
    expect(
      browser.modelPathOf('${root.path}/note.txt'),
      '/mounts/Notes/note.txt',
    );
    expect(find.text('note.txt'), findsOneWidget);
    debugDefaultTargetPlatformOverride = null;
    expect(tester.takeException(), isNull);
  });

  for (final externalPage in [true, false]) {
    testWidgets('browser protects readonly aliases, external=$externalPage', (
      tester,
    ) async {
      final writable = Directory.systemTemp.createTempSync(
        'kelivo-mount-browser-',
      );
      addTearDown(() => writable.deleteSync(recursive: true));
      Link('${writable.path}/alias').createSync(root.path);
      harness.handler = (call) {
        if (call.method == 'resolveDirectory') {
          final token = (call.arguments as Map)['token'];
          return {
            'path': token == 'writable' ? writable.path : root.path,
            'token': token,
          };
        }
        return null;
      };
      await tester.runAsync(
        () => provider.add(
          WorkspaceDirectory(
            path: writable.path,
            access: const WorkspaceDirectoryAccess(
              platform: 'android',
              token: 'writable',
            ),
          ),
          name: 'Writable',
          readOnly: false,
        ),
      );
      await showPage(
        tester,
        home: externalPage
            ? const ExternalMountsPage()
            : Scaffold(
                body: FileBrowser(
                  root: writable,
                  rootLabel: 'Workspace',
                  modelPathOf: (path) => path,
                ),
              ),
      );
      if (externalPage) {
        await tester.tap(find.text('Writable'));
        await settle(tester);
        final l10n = AppLocalizations.of(
          tester.element(find.byType(EditableText)),
        )!;
        await tester.tap(find.text(l10n.workspaceMountBrowse));
        await settle(tester);
      }
      await tester.tap(find.text('alias'));
      await settle(tester);
      final l10n = AppLocalizations.of(
        tester.element(find.byType(FileBrowser)),
      )!;
      Future<void> createFile() async {
        await tester.tap(find.byKey(FileBrowser.newKey));
        await settle(tester);
        await tester.tap(find.byKey(FileBrowser.newFileKey));
        await settle(tester);
        await tester.enterText(find.byType(EditableText), 'new.txt');
        await tester.pump();
        final confirm = find
            .descendant(
              of: find.byKey(
                const ValueKey<String>('workspace-prompt-confirm'),
              ),
              matching: find.byType(GestureDetector),
            )
            .last;
        await tester.ensureVisible(confirm);
        await tester.tap(confirm);
        await settle(tester);
      }

      await createFile();
      expect(File('${root.path}/new.txt').existsSync(), isFalse);
      expect(
        AppSnackBarManager().activeToasts.any(
          (toast) =>
              toast.notification.message.contains(l10n.workspaceMountReadOnly),
        ),
        isTrue,
      );
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();

      // Copying OUT of a readonly mount remains allowed.
      await tester.runAsync(() async {
        final copy = CopyIntoMutation(
          rootPath: writable.path,
          sourcePath: '${root.path}/note.txt',
          destDirPath: writable.path,
        );
        await provider.requireWritableHostPaths(copy.writePaths);
        await FileBrowserOps.runMutation(copy);
      });
      expect(File('${writable.path}/note.txt').readAsStringSync(), 'hello');
      await tester.runAsync(
        () => provider.update(
          provider.entries.first.id,
          name: 'Notes',
          readOnly: false,
        ),
      );
      await createFile();
      expect(File('${root.path}/new.txt').existsSync(), isTrue);
      debugDefaultTargetPlatformOverride = null;
      expect(tester.takeException(), isNull);
    });
  }
}
