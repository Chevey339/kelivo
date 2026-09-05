import 'dart:io';

import 'package:file_picker/file_picker.dart';

import 'package:flutter/services.dart';
import 'package:Kelivo/core/models/workspace.dart';
import 'package:Kelivo/features/workspace/widgets/files/file_browser.dart';
import 'package:Kelivo/features/workspace/pages/workspace_files_desktop_layout.dart';
import 'package:Kelivo/features/workspace/widgets/workspace_tools_pane.dart';
import 'package:Kelivo/shared/widgets/ios_switch.dart';

import 'package:Kelivo/core/database/app_database.dart';
import 'package:Kelivo/core/database/extension_entity_store.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/providers/workspace_provider.dart';
import 'package:Kelivo/features/workspace/pages/workspaces_page.dart';
import 'package:Kelivo/icons/lucide_adapter.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/widgets/form_sheet.dart';
import 'package:Kelivo/shared/widgets/ios_settings_rows.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:provider/provider.dart';

import '../../../support/business_test_harness.dart';

class _FolderPicker extends FilePicker {
  String? folder;

  @override
  Future<String?> getDirectoryPath({
    String? dialogTitle,
    bool lockParentWindow = false,
    String? initialDirectory,
  }) async => folder;
}

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

Future<void> _pumpUi(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 350));
}

Future<void> _settleSheet(WidgetTester tester) async {
  await tester.pump();
  await tester.pumpAndSettle(const Duration(milliseconds: 50));
}

Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
}

Future<void> _tapFormConfirm(WidgetTester tester, Key key) async {
  final confirm = find
      .descendant(of: find.byKey(key), matching: find.byType(GestureDetector))
      .last;
  await tester.ensureVisible(confirm);
  await tester.pump();
  await tester.tap(confirm);
}

Future<void> _awaitIo(WidgetTester tester, bool Function() ready) async {
  for (var i = 0; i < 80 && !ready(); i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 25)),
    );
    await tester.pump();
  }
  await _pumpUi(tester);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late PathProviderPlatform previousPathProvider;
  late AppDatabase database;
  late WorkspaceProvider workspaces;

  setUp(() async {
    FilePicker.platform = _FolderPicker();
    tempDir = Directory.systemTemp.createTempSync('kelivo_workspaces_pane_');
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

  Widget harness() {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => SettingsProvider(createBusinessTestPreferences()),
        ),
        ChangeNotifierProvider<WorkspaceProvider>.value(value: workspaces),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(
          body: Padding(padding: EdgeInsets.all(16), child: WorkspacesPane()),
        ),
      ),
    );
  }

  for (final platform in [
    TargetPlatform.android,
    TargetPlatform.iOS,
    TargetPlatform.macOS,
  ]) {
    testWidgets(
      'workspace tools persist independently on $platform',
      (tester) async {
        const haptics = MethodChannel('haptic_feedback');
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(haptics, (_) async => true);
        addTearDown(
          () => TestDefaultBinaryMessengerBinding
              .instance
              .defaultBinaryMessenger
              .setMockMethodCallHandler(haptics, null),
        );
        final desktop = platform == TargetPlatform.macOS;
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = desktop
            ? const Size(1100, 800)
            : const Size(390, 844);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        late Workspace first;
        late Workspace second;
        await tester.runAsync(() async {
          first = await workspaces.create(name: 'First');
          second = await workspaces.create(name: 'Second');
          final root = await workspaces.hostRootFor(first);
          await File(p.join(root, 'README.txt')).writeAsString('hello');
        });
        await tester.pumpWidget(harness());
        await _pumpUi(tester);
        await tester.tap(find.byKey(WorkspacesPane.itemKey(first.id)));
        await _awaitIo(
          tester,
          () => find.text('README.txt').evaluate().isNotEmpty,
        );
        final tabs = find.byKey(const ValueKey('workspace-detail-tabs'));
        final l10n = AppLocalizations.of(tester.element(tabs))!;
        Future<void> selectTab(String title) async {
          await tester.tap(
            find.descendant(of: tabs, matching: find.text(title)),
          );
          await tester.pumpAndSettle();
        }

        await selectTab(l10n.workspaceToolsTitle);
        final toggle = find.byKey(WorkspaceToolsPane.toggleKey('read_file'));
        expect(tester.widget<IosSwitch>(toggle).value, isTrue);
        await tester.tap(toggle);
        await _awaitIo(
          tester,
          () => !workspaces.byId(first.id)!.isToolEnabled('read_file'),
        );
        expect(tester.widget<IosSwitch>(toggle).value, isFalse);
        expect(workspaces.byId(second.id)!.isToolEnabled('read_file'), isTrue);
        await tester.runAsync(() async {
          final reloaded = WorkspaceProvider(
            store: ExtensionEntityStore(database),
          );
          await reloaded.loaded;
          expect(reloaded.byId(first.id)!.isToolEnabled('read_file'), isFalse);
          expect(reloaded.byId(second.id)!.isToolEnabled('read_file'), isTrue);
          reloaded.dispose();
        });
        await selectTab(l10n.workspaceEntryFiles);
        expect(find.text('README.txt'), findsOneWidget);
        await selectTab(l10n.workspaceToolsTitle);
        expect(tester.widget<IosSwitch>(toggle).value, isFalse);
        await tester.tap(toggle);
        await _awaitIo(
          tester,
          () => workspaces.byId(first.id)!.isToolEnabled('read_file'),
        );
        expect(tester.widget<IosSwitch>(toggle).value, isTrue);
        expect(tester.takeException(), isNull);
      },
      variant: TargetPlatformVariant.only(platform),
    );
  }

  testWidgets(
    'native desktop creates a managed workspace below the desktop breakpoint',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(900, 620);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(harness());
      await _pumpUi(tester);
      await tester.tap(find.byKey(WorkspacesPane.createKey));
      await _settleSheet(tester);
      expect(find.byType(BottomSheet), findsNothing);
      await tester.enterText(find.byType(TextField), 'Native workspace');
      await tester.pump();
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await _awaitIo(tester, () => workspaces.workspaces.isNotEmpty);
      expect(workspaces.workspaces.single.name, 'Native workspace');
      expect(find.byType(DesktopWorkspaceFiles), findsOneWidget);
      await _awaitIo(
        tester,
        () => find.byType(FileBrowser).evaluate().isNotEmpty,
      );
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.macOS),
  );

  testWidgets(
    'desktop links an existing folder and keeps invalid input editable',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1000, 660);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final folder = Directory(p.join(tempDir.path, 'Linked project'))
        ..createSync();
      File(
        p.join(folder.path, 'existing.txt'),
      ).writeAsStringSync('keep this file');
      await tester.pumpWidget(harness());
      await _pumpUi(tester);
      await tester.tap(find.byKey(WorkspacesPane.createKey));
      await _settleSheet(tester);
      await tester.enterText(find.byType(TextField), 'Linked project');
      await tester.tap(
        find.byKey(const ValueKey('workspace-desktop-kind-linked')),
      );
      await tester.pump();
      final pathField = find.descendant(
        of: find.byKey(const ValueKey('workspace-desktop-path')),
        matching: find.byType(TextField),
      );
      await tester.enterText(pathField, 'missing-relative-folder');
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('workspaces-create-confirm')));
      await _pumpUi(tester);
      expect(
        find.byKey(const ValueKey('workspace-desktop-create-error')),
        findsOneWidget,
      );
      expect(workspaces.workspaces, isEmpty);
      await tester.enterText(pathField, folder.path);
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('workspaces-create-confirm')));
      await _awaitIo(tester, () => workspaces.workspaces.isNotEmpty);
      expect(workspaces.workspaces.single.kind, WorkspaceKind.linked);
      expect(workspaces.workspaces.single.hostPath, folder.path);
      await _awaitIo(
        tester,
        () => find
            .byKey(FileBrowser.itemKey('existing.txt'))
            .evaluate()
            .isNotEmpty,
      );
      expect(find.byKey(FileBrowser.itemKey('existing.txt')), findsOneWidget);
      expect(
        File(p.join(folder.path, 'existing.txt')).readAsStringSync(),
        'keep this file',
      );
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.macOS),
  );

  testWidgets(
    'desktop folder picker can cancel and then link using the folder name',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1000, 700);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final previousPicker = FilePicker.platform;
      final picker = _FolderPicker();
      FilePicker.platform = picker;
      addTearDown(() => FilePicker.platform = previousPicker);
      await tester.pumpWidget(harness());
      await _pumpUi(tester);
      await tester.tap(find.byKey(WorkspacesPane.createKey));
      await _settleSheet(tester);
      await tester.tap(
        find.byKey(const ValueKey('workspace-desktop-kind-linked')),
      );
      await tester.pump();
      await tester.tap(find.text('Link folder'));
      await _pumpUi(tester);
      expect(
        find.byKey(const ValueKey('workspace-desktop-create-error')),
        findsNothing,
      );
      expect(workspaces.workspaces, isEmpty);
      final folder = Directory(p.join(tempDir.path, 'Picked folder'))
        ..createSync();
      picker.folder = folder.path;
      await tester.tap(find.text('Link folder'));
      await _pumpUi(tester);
      expect(find.text('Picked folder'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('workspaces-create-confirm')));
      await _awaitIo(tester, () => workspaces.workspaces.isNotEmpty);
      expect(workspaces.workspaces.single.hostPath, folder.path);
      expect(workspaces.workspaces.single.name, 'Picked folder');
    },
    variant: TargetPlatformVariant.only(TargetPlatform.macOS),
  );

  testWidgets(
    'desktop create actions remain visible in a short window and Escape cancels',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(820, 420);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(harness());
      await _pumpUi(tester);
      await tester.tap(find.byKey(WorkspacesPane.createKey));
      await _settleSheet(tester);
      await tester.enterText(find.byType(TextField), 'Short window');
      await tester.pump();
      final confirm = find.byKey(const ValueKey('workspaces-create-confirm'));
      expect(confirm.hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await _settleSheet(tester);
      expect(confirm, findsNothing);
      expect(workspaces.workspaces, isEmpty);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.macOS),
  );

  testWidgets(
    'desktop manager filters and switches files without pushing a page',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1280, 800);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      late Workspace alpha;
      late Workspace beta;
      await tester.runAsync(() async {
        alpha = await workspaces.create(name: 'App redesign');
        beta = await workspaces.create(name: 'Research notes');
        final root = await workspaces.hostRootFor(alpha);
        Directory(p.join(root, 'src')).createSync();
        File(p.join(root, 'README.md')).writeAsStringSync('# App redesign');
        File(p.join(root, 'package.json')).writeAsStringSync('{}');
        final secondRoot = await workspaces.hostRootFor(beta);
        File(p.join(secondRoot, 'notes.md')).writeAsStringSync('# Research');
      });
      await tester.pumpWidget(harness());
      await _awaitIo(
        tester,
        () =>
            find.byKey(FileBrowser.itemKey('README.md')).evaluate().isNotEmpty,
      );
      expect(find.byKey(FileBrowser.itemKey('README.md')), findsOneWidget);
      await tester.runAsync(
        () => workspaces.update(alpha.copyWith(name: 'Z app redesign')),
      );
      await tester.pump();
      expect(
        tester
            .widget<DesktopWorkspaceFiles>(find.byType(DesktopWorkspaceFiles))
            .workspace
            .id,
        alpha.id,
      );
      await tester.tap(find.byKey(WorkspacesPane.itemKey(beta.id)));
      await _awaitIo(
        tester,
        () => find.byKey(FileBrowser.itemKey('notes.md')).evaluate().isNotEmpty,
      );
      expect(find.byKey(FileBrowser.itemKey('notes.md')), findsOneWidget);
      expect(find.byKey(FileBrowser.itemKey('README.md')), findsNothing);
      expect(find.byType(Scaffold), findsOneWidget);
      final search = find.descendant(
        of: find.byKey(const ValueKey('workspace-desktop-search')),
        matching: find.byType(TextField),
      );
      await tester.enterText(search, 'research');
      await tester.pump();
      expect(find.byKey(WorkspacesPane.itemKey(alpha.id)), findsNothing);
      expect(find.byKey(WorkspacesPane.itemKey(beta.id)), findsOneWidget);
      tester.view.physicalSize = const Size(600, 650);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('workspace-desktop-select')),
        findsOneWidget,
      );
      expect(find.byKey(FileBrowser.itemKey('notes.md')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.macOS),
  );

  testWidgets('creates renames and deletes a workspace', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(400, 900);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(harness());
    await _pumpUi(tester);

    expect(find.byKey(WorkspacesPane.emptyKey), findsOneWidget);

    await tester.tap(find.byKey(WorkspacesPane.createKey));
    await _settleSheet(tester);
    expect(find.byType(FormSheet), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(
      tester.widget<FormSheetActions>(find.byType(FormSheetActions)).onConfirm,
      isNull,
    );
    await tester.enterText(find.byType(TextField), 'Alpha');
    await tester.pump();
    final createConfirm = find.byKey(
      const ValueKey<String>('workspaces-create-confirm'),
    );
    expect(tester.widget<FormSheetActions>(createConfirm).onConfirm, isNotNull);
    await _tapFormConfirm(
      tester,
      const ValueKey<String>('workspaces-create-confirm'),
    );
    await _awaitIo(tester, () => workspaces.workspaces.isNotEmpty);

    expect(workspaces.workspaces, hasLength(1));
    expect(workspaces.workspaces.single.name, 'Alpha');
    final id = workspaces.workspaces.single.id;
    expect(find.byKey(WorkspacesPane.itemKey(id)), findsOneWidget);
    expect(find.byType(IosNavRow), findsWidgets);

    final iconFinder = find.descendant(
      of: find.byKey(WorkspacesPane.itemKey(id)),
      matching: find.byIcon(Lucide.FolderCode),
    );
    expect(iconFinder, findsOneWidget);
    expect(tester.widget<Icon>(iconFinder).size, 20);
    final wellBox = tester.widget<SizedBox>(
      find.ancestor(of: iconFinder, matching: find.byType(SizedBox)).first,
    );
    expect(wellBox.width, 36);
    expect(wellBox.child, isA<Icon>());
    expect(wellBox.child, isNot(isA<Container>()));
    expect(wellBox.child, isNot(isA<DecoratedBox>()));

    await tester.ensureVisible(find.byKey(WorkspacesPane.itemMoreKey(id)));
    await tester.tap(find.byKey(WorkspacesPane.itemMoreKey(id)));
    await _settleSheet(tester);
    await _tapVisible(tester, find.text('Rename'));
    await _pumpUi(tester);
    await tester.enterText(find.byType(TextField), 'Beta');
    await tester.pump();
    await _tapFormConfirm(
      tester,
      const ValueKey<String>('workspace-prompt-confirm'),
    );
    await _awaitIo(tester, () => workspaces.byId(id)?.name == 'Beta');

    expect(workspaces.byId(id)?.name, 'Beta');
    expect(find.text('Beta'), findsWidgets);

    await tester.ensureVisible(find.byKey(WorkspacesPane.itemMoreKey(id)));
    await tester.tap(find.byKey(WorkspacesPane.itemMoreKey(id)));
    await _settleSheet(tester);
    await _tapVisible(tester, find.text('Delete'));
    await _pumpUi(tester);
    await tester.tap(
      find.byKey(const ValueKey<String>('workspace-confirm-accept')),
    );
    await _awaitIo(
      tester,
      () => find.byKey(WorkspacesPane.emptyKey).evaluate().isNotEmpty,
    );

    expect(workspaces.workspaces, isEmpty);
    expect(find.byKey(WorkspacesPane.emptyKey), findsOneWidget);
  });

  testWidgets('ellipsis menu exposes rename settings and delete', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(400, 900);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(harness());
    await _pumpUi(tester);
    await tester.tap(find.byKey(WorkspacesPane.createKey));
    await _settleSheet(tester);
    await tester.enterText(find.byType(TextField), 'Alpha');
    await tester.pump();
    await _tapFormConfirm(
      tester,
      const ValueKey<String>('workspaces-create-confirm'),
    );
    await _awaitIo(tester, () => workspaces.workspaces.isNotEmpty);

    final id = workspaces.workspaces.single.id;
    await tester.ensureVisible(find.byKey(WorkspacesPane.itemMoreKey(id)));
    await tester.tap(find.byKey(WorkspacesPane.itemMoreKey(id)));
    await _settleSheet(tester);

    final l10n = AppLocalizations.of(
      tester.element(find.byKey(WorkspacesPane.listKey)),
    )!;
    expect(find.text(l10n.workspaceFilesRename), findsOneWidget);
    expect(find.text(l10n.workspacesSettings), findsOneWidget);
    expect(find.text(l10n.workspaceFilesDelete), findsOneWidget);
  });

  testWidgets('showHeader false hides the in-pane create button', (
    tester,
  ) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(
            create: (_) => SettingsProvider(createBusinessTestPreferences()),
          ),
          ChangeNotifierProvider<WorkspaceProvider>.value(value: workspaces),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(
            body: Padding(
              padding: EdgeInsets.all(16),
              child: WorkspacesPane(showHeader: false),
            ),
          ),
        ),
      ),
    );
    await _pumpUi(tester);

    expect(find.byKey(WorkspacesPane.createKey), findsNothing);
    expect(find.byKey(WorkspacesPane.emptyKey), findsOneWidget);
  });

  testWidgets('create sheet height follows content and shifts with insets', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(400, 900);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(harness());
    await _pumpUi(tester);

    await tester.tap(find.byKey(WorkspacesPane.createKey));
    await _settleSheet(tester);

    final closed = tester.getSize(find.byType(FormSheet)).height;
    expect(closed, lessThanOrEqualTo(900 * 0.9 + 1));
    expect(closed, greaterThan(120));

    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(tester.view.resetViewInsets);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    final open = tester.getSize(find.byType(FormSheet)).height;
    expect(open - closed, closeTo(300, 2));

    const keyboardTop = 600.0;
    expect(
      tester.getRect(find.byType(TextField)).bottom,
      lessThan(keyboardTop),
    );
    expect(
      tester.getRect(find.byType(FormSheetActions)).bottom,
      lessThanOrEqualTo(keyboardTop + 0.5),
    );
  });

  testWidgets('workspaces dialog shows empty-state title when none exist', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1280, 800);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(
            create: (_) => SettingsProvider(createBusinessTestPreferences()),
          ),
          ChangeNotifierProvider<WorkspaceProvider>.value(value: workspaces),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) {
              return Scaffold(
                body: Center(
                  child: GestureDetector(
                    onTap: () => openWorkspacesPage(context),
                    child: const Text('open-workspaces'),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
    await _pumpUi(tester);
    await tester.tap(find.text('open-workspaces'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    final l10n = AppLocalizations.of(
      tester.element(find.text('open-workspaces')),
    )!;
    expect(find.byKey(WorkspacesPane.emptyKey), findsOneWidget);
    expect(find.text(l10n.workspacesEmpty), findsOneWidget);
    expect(find.text(l10n.workspaceMgmtEmptyHint), findsOneWidget);
    expect(find.text(l10n.workspaceMgmtNewWorkspace), findsWidgets);
    expect(
      tester.getSize(find.byKey(WorkspacesPane.emptyKey)).height,
      greaterThan(80),
    );
  });

  testWidgets('workspace settings row uses default working directory label', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(400, 900);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(harness());
    await _pumpUi(tester);
    await tester.tap(find.byKey(WorkspacesPane.createKey));
    await _settleSheet(tester);
    await tester.enterText(find.byType(TextField), 'Alpha');
    await tester.pump();
    await _tapFormConfirm(
      tester,
      const ValueKey<String>('workspaces-create-confirm'),
    );
    await _awaitIo(tester, () => workspaces.workspaces.isNotEmpty);

    final id = workspaces.workspaces.single.id;
    await tester.ensureVisible(find.byKey(WorkspacesPane.itemMoreKey(id)));
    await tester.tap(find.byKey(WorkspacesPane.itemMoreKey(id)));
    await _settleSheet(tester);
    await _tapVisible(tester, find.text('Settings'));
    await _settleSheet(tester);

    final l10n = AppLocalizations.of(
      tester.element(find.byKey(WorkspacesPane.listKey)),
    )!;
    expect(l10n.workspacesDefaultCwd, l10n.workspaceMgmtPickCwdTitle);
    expect(find.text(l10n.workspacesDefaultCwd), findsOneWidget);
  });

  test('WorkspaceMgmtIconWell symbol is gone', () {
    final page = File(
      'lib/features/workspace/pages/workspaces_page.dart',
    ).readAsStringSync();
    final settings = File(
      'lib/features/workspace/pages/workspace_settings_page.dart',
    ).readAsStringSync();
    final basic = File(
      'lib/features/assistant/pages/assistant_settings_edit_basic_tab.dart',
    ).readAsStringSync();
    expect(page.contains('WorkspaceMgmtIconWell'), isFalse);
    expect(settings.contains('WorkspaceMgmtIconWell'), isFalse);
    expect(basic.contains('WorkspaceMgmtIconWell'), isFalse);
    expect(page.contains('showWorkspaceSheetOrDialog'), isFalse);
  });
}
