import 'dart:io';

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
