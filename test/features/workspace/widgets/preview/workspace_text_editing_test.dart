import 'dart:async';
import 'dart:io';

import 'package:Kelivo/core/database/extension_entity_store.dart';
import 'package:Kelivo/core/models/workspace.dart';
import 'package:Kelivo/core/models/workspace_file_owner.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/providers/workspace_provider.dart';
import 'package:Kelivo/core/services/browser/browser_service.dart';
import 'package:Kelivo/core/services/workspace/workspace_file_coordinator.dart';
import 'package:Kelivo/desktop/widgets/desktop_menu.dart';
import 'package:Kelivo/features/side_panel/desktop_side_panel_controller.dart';
import 'package:Kelivo/features/side_panel/widgets/desktop_side_panel.dart';
import 'package:Kelivo/features/workspace/widgets/files/file_browser.dart';
import 'package:Kelivo/features/workspace/widgets/preview/code_file_preview.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/utils/platform_utils.dart';
import 'package:Kelivo/shared/widgets/long_message_editor.dart';
import 'package:Kelivo/shared/widgets/snackbar.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:re_editor/re_editor.dart' show CodeEditor;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';

import '../../../../support/business_test_harness.dart';
import '../../../side_panel/side_panel_test_support.dart';

void main() {
  late Directory root;
  late WorkspaceProvider workspaces;
  late WorkspaceFileOwner owner;
  late BusinessTestHarness database;
  TestWidgetsFlutterBinding.ensureInitialized();
  const haptics = MethodChannel('haptic_feedback');
  setUp(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(haptics, (_) async => true);
    root = Directory.systemTemp.createTempSync('kelivo-text-ui-');
    database = await BusinessTestHarness.create();
    workspaces = WorkspaceProvider(
      store: ExtensionEntityStore(database.database),
    );
    final ws = await workspaces.create(
      name: 'Notes',
      kind: WorkspaceKind.linked,
      hostPath: root.path,
    );
    owner = (kind: WorkspaceFileOwnerKind.workspace, id: ws.id);
  });
  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(haptics, null);
    workspaces.dispose();
    await database.close();
    root.deleteSync(recursive: true);
  });

  Widget harness(Widget child) => MultiProvider(
    providers: [
      ChangeNotifierProvider<WorkspaceProvider>.value(value: workspaces),
      ChangeNotifierProvider(
        create: (_) => SettingsProvider(database.preferences),
      ),
    ],
    child: MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (_, child) => AppSnackBarOverlay(child: child!),
      home: Scaffold(body: child),
    ),
  );
  void size(WidgetTester tester, Size value) {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = value;
    addTearDown(tester.view.reset);
  }

  Future<void> waitFor(WidgetTester tester, Finder finder) async {
    for (var i = 0; i < 100; i++) {
      await tester.pump(const Duration(milliseconds: 20));
      if (finder.evaluate().isNotEmpty) return;
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
    }
    expect(finder, findsWidgets);
  }

  Future<void> finishTransition(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();
  }

  Future<void> saveShortcut(WidgetTester tester) async {
    final modifier = defaultTargetPlatform == TargetPlatform.macOS
        ? LogicalKeyboardKey.metaLeft
        : LogicalKeyboardKey.controlLeft;
    await tester.sendKeyDownEvent(modifier);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyS);
    await tester.sendKeyUpEvent(modifier);
  }

  Future<void> openFromBrowser(
    WidgetTester tester,
    String name, {
    bool readOnly = false,
  }) async {
    size(
      tester,
      PlatformUtils.isDesktopTarget
          ? const Size(1240, 800)
          : const Size(390, 844),
    );
    await tester.pumpWidget(
      harness(
        FileBrowser(
          root: root,
          rootLabel: 'Notes',
          modelPathOf: (path) => path,
          owner: owner,
          readOnly: readOnly,
        ),
      ),
    );
    final item = find.byKey(FileBrowser.itemKey(name));
    await waitFor(tester, item);
    await tester.tap(item);
  }

  final editor = find.byType(LongMessageEditor);
  final input = find.descendant(
    of: editor,
    matching: find.byType(EditableText),
  );
  testWidgets(
    'phone edits the source and refreshes the selected Markdown preview on save',
    (tester) async {
      final file = File(p.join(root.path, 'notes.md'))
        ..writeAsStringSync('# Before\n');
      await openFromBrowser(tester, 'notes.md');
      await waitFor(tester, find.byTooltip('Edit'));
      await finishTransition(tester);
      await tester.tap(find.byTooltip('More'));
      await waitFor(tester, find.byType(BottomSheet));
      expect(find.text('Copy path'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await finishTransition(tester);
      await tester.tap(find.text('Source'));
      await finishTransition(tester);
      await tester.tap(find.byTooltip('Edit'));
      await waitFor(tester, input);
      await tester.pump();
      expect(tester.widget<EditableText>(input).focusNode.hasFocus, isTrue);
      await tester.enterText(input, '# After  \n');
      await tester.pump();
      expect(file.readAsStringSync(), '# Before\n');
      await tester.tap(find.text('Save'));
      await waitFor(tester, find.byTooltip('Edit'));
      await waitFor(
        tester,
        find.byWidgetPredicate(
          (w) => w is CodeFilePreview && w.document?.source == '# After  \n',
        ),
      );
      expect(file.readAsStringSync(), '# After  \n');
      expect(
        tester
            .widget<CodeFilePreview>(find.byType(CodeFilePreview))
            .document!
            .source,
        '# After  \n',
      );
      await tester.tap(find.byTooltip('Edit'));
      await waitFor(tester, input);
      await tester.enterText(input, 'Discard me');
      await tester.binding.handlePopRoute();
      await waitFor(tester, find.text('Keep editing'));
      await tester.tap(find.text('Keep editing'));
      await finishTransition(tester);
      expect(tester.widget<EditableText>(input).controller.text, 'Discard me');
      file.writeAsStringSync('# On disk\n');
      await tester.binding.handlePopRoute();
      await waitFor(tester, find.text('Discard changes'));
      await tester.tap(find.text('Discard changes'));
      await waitFor(tester, find.byTooltip('Edit'));
      await waitFor(
        tester,
        find.byWidgetPredicate(
          (w) => w is CodeFilePreview && w.document?.source == '# On disk\n',
        ),
      );
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets('new workspace text files immediately accept a first line', (
    tester,
  ) async {
    size(tester, const Size(390, 844));
    await tester.pumpWidget(
      harness(
        FileBrowser(
          root: root,
          rootLabel: 'Notes',
          modelPathOf: (path) => path,
          owner: owner,
        ),
      ),
    );
    await tester.tap(find.byKey(FileBrowser.newKey));
    await finishTransition(tester);
    await tester.tap(find.byKey(FileBrowser.newFileKey));
    await finishTransition(tester);
    await waitFor(tester, find.byType(TextField));
    await tester.enterText(find.byType(TextField), 'first.md');
    await tester.pump();
    final create = find
        .descendant(
          of: find.byKey(const ValueKey('workspace-prompt-confirm')),
          matching: find.byType(GestureDetector),
        )
        .last;
    await tester.ensureVisible(create);
    await tester.pump();
    await tester.tap(create);
    await waitFor(tester, input);
    expect(tester.widget<EditableText>(input).controller.text, isEmpty);
    await tester.enterText(input, '# 第一行\n');
    await tester.pump();
    await tester.tap(find.text('Save'));
    await waitFor(tester, find.byTooltip('Edit'));
    expect(File(p.join(root.path, 'first.md')).readAsStringSync(), '# 第一行\n');
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets(
    'failed writes retain text and can be retried',
    (tester) async {
      final file = File(p.join(root.path, 'notes.txt'))
        ..writeAsStringSync('before');
      await openFromBrowser(tester, 'notes.txt');
      await waitFor(tester, find.byTooltip('Edit'));
      await finishTransition(tester);
      await tester.tap(find.byTooltip('Edit'));
      await waitFor(tester, input);
      await tester.enterText(input, '保留草稿\n');
      await tester.pump();
      await tester.runAsync(() => Process.run('chmod', ['400', file.path]));
      await tester.tap(find.text('Save'));
      await waitFor(tester, find.text('Read-only location'));
      expect(file.readAsStringSync(), 'before');
      expect(tester.widget<EditableText>(input).controller.text, '保留草稿\n');
      await tester.runAsync(() => Process.run('chmod', ['600', file.path]));
      await tester.tap(find.text('Save'));
      await waitFor(tester, find.byTooltip('Edit'));
      expect(file.readAsStringSync(), '保留草稿\n');
      await tester.pump(const Duration(seconds: 5));
      await finishTransition(tester);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
    skip: Platform.isWindows,
  );

  testWidgets(
    'long multiline text uses the line editor and preserves the remaining lines',
    (tester) async {
      final text = '一段长文本。abcdefghijklmno\n' * 450;
      final file = File(p.join(root.path, 'long.txt'))..writeAsStringSync(text);
      await openFromBrowser(tester, 'long.txt');
      await waitFor(tester, find.byTooltip('Edit'));
      await finishTransition(tester);
      await tester.tap(find.byTooltip('Edit'));
      final lineEditor = find.byType(CodeEditor);
      await waitFor(tester, lineEditor);
      tester
          .widget<CodeEditor>(lineEditor)
          .controller!
          .replaceSelection('已改\n');
      await tester.pump();
      if (PlatformUtils.isDesktopTarget) {
        await saveShortcut(tester);
      } else {
        await tester.tap(find.text('Save'));
      }
      await waitFor(tester, find.byTooltip('Edit'));
      expect(file.readAsStringSync(), '已改\n$text');
    },
    variant: TargetPlatformVariant({
      TargetPlatform.android,
      TargetPlatform.macOS,
      TargetPlatform.windows,
    }),
  );

  testWidgets('reload keeps a draft until the latest preview can be read', (
    tester,
  ) async {
    final file = File(p.join(root.path, 'notes.txt'))
      ..writeAsStringSync('before');
    await openFromBrowser(tester, 'notes.txt');
    await waitFor(tester, find.byTooltip('Edit'));
    await finishTransition(tester);
    await tester.tap(find.byTooltip('Edit'));
    await waitFor(tester, input);
    await tester.enterText(input, 'my draft');
    await tester.pump();
    file.deleteSync();
    await tester.tap(find.text('Save'));
    await waitFor(tester, find.text('Load latest version'));
    await tester.tap(find.text('Load latest version'));
    await waitFor(tester, find.text('File no longer exists'));
    expect(tester.widget<EditableText>(input).controller.text, 'my draft');
    expect(file.existsSync(), isFalse);
    await tester.pump(const Duration(seconds: 5));
    await finishTransition(tester);
    // The replacement is too large for editing, but its preview can be reloaded.
    final handle = file.openSync(mode: FileMode.write);
    handle.truncateSync(1 << 30);
    handle.closeSync();
    await tester.tap(find.text('Save'));
    await waitFor(tester, find.text('Load latest version'));
    await tester.tap(find.text('Load latest version'));
    await waitFor(tester, find.byKey(CodeFilePreview.plainTextListKey));
    expect(editor, findsNothing);
    expect(
      tester
          .widget<CodeFilePreview>(find.byType(CodeFilePreview))
          .document!
          .source,
      isNull,
    );
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets(
    'a writable workspace opens a 1 GiB log in the existing paged reader',
    (tester) async {
      final file = File(
        p.join(root.path, 'large.log'),
      ).openSync(mode: FileMode.write);
      file.truncateSync(1 << 30);
      file.closeSync();
      await openFromBrowser(tester, 'large.log');
      await waitFor(tester, find.byKey(CodeFilePreview.plainTextListKey));
      final document = tester
          .widget<CodeFilePreview>(find.byType(CodeFilePreview))
          .document!;
      expect(document.source, isNull);
      expect(document.lines, isEmpty);
      expect(find.byTooltip('Edit'), findsNothing);
      expect(editor, findsNothing);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets('a read-only browser never opens an editor for a text file', (
    tester,
  ) async {
    File(p.join(root.path, 'note.txt')).writeAsStringSync('Hello');
    await openFromBrowser(tester, 'note.txt', readOnly: true);
    await waitFor(tester, find.text('Read-only location'));
    expect(find.byTooltip('Edit'), findsNothing);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets(
    'desktop tab retains its draft across tabs, guards close and saves a conflict copy',
    (tester) async {
      size(tester, const Size(1240, 800));
      final file = File(p.join(root.path, 'notes.txt'))
        ..writeAsStringSync('08:30');
      final browser = BrowserService(
        store: SidePanelMemoryStore(),
        supported: false,
      );
      final panel = DesktopSidePanelController(browser: browser);
      await tester.pumpWidget(
        harness(
          DesktopSidePanel(
            controller: panel,
            conversationId: 'chat',
            topicsOnRight: false,
            filesBuilder: (_) => const SizedBox(),
            topicsBuilder: (_, _) => const SizedBox(),
            child: const SizedBox(),
          ),
        ),
      );
      panel.openPreview(file.path, owner: owner);
      final tab = panel.activeTab as PreviewTab;
      await waitFor(tester, find.byTooltip('Edit'));
      await tester.tap(find.byTooltip('More'));
      await waitFor(tester, find.byType(DesktopMenuSurface));
      expect(find.widgetWithText(DesktopMenuRow, 'Copy path'), findsOneWidget);
      expect(find.byType(BottomSheet), findsNothing);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await finishTransition(tester);
      expect(find.byType(DesktopMenuSurface), findsNothing);
      expect(panel.activeTab.id, tab.id);
      String? copied;
      final messenger = tester.binding.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String;
        }
        return null;
      });
      addTearDown(
        () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
      );
      await tester.tap(find.byTooltip('More'));
      await waitFor(tester, find.widgetWithText(DesktopMenuRow, 'Copy path'));
      await tester.tap(find.widgetWithText(DesktopMenuRow, 'Copy path'));
      await finishTransition(tester);
      expect(copied, file.path);
      expect(find.byType(DesktopMenuSurface), findsNothing);
      await tester.pump(const Duration(seconds: 5));
      await finishTransition(tester);
      await tester.tap(find.byTooltip('Edit'));
      await waitFor(tester, input);
      await tester.enterText(input, '09:00');
      const range = TextSelection(baseOffset: 0, extentOffset: 2);
      tester.testTextInput.updateEditingValue(
        const TextEditingValue(text: '09:00', selection: range),
      );
      await tester.pump();
      panel.activate('files');
      await tester.pump();
      expect(editor, findsNothing);
      panel.activate(tab.id);
      await waitFor(tester, input);
      expect(tester.widget<EditableText>(input).controller.text, '09:00');
      expect(tester.widget<EditableText>(input).controller.selection, range);
      panel.closeTab(tab.id);
      await waitFor(tester, find.text('Keep editing'));
      await tester.tap(find.text('Keep editing'));
      await finishTransition(tester);
      expect(panel.activeTab.id, tab.id);
      file.writeAsStringSync('09:15');
      await tester.tap(input);
      await saveShortcut(tester);
      await waitFor(tester, find.text('Save a copy'));
      await tester.tap(find.text('Save a copy'));
      await waitFor(tester, find.byTooltip('Edit'));
      expect(file.readAsStringSync(), '09:15');
      expect(File(tab.path).readAsStringSync(), '09:00');
      expect(p.basename(tab.path), 'notes (1).txt');
      await tester.pumpWidget(const SizedBox());
      panel.dispose();
      browser.dispose();
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant({
      TargetPlatform.macOS,
      TargetPlatform.windows,
      TargetPlatform.linux,
    }),
  );

  testWidgets(
    'desktop reuses a tab for a recreated file and reports an offscreen conflict',
    (tester) async {
      size(tester, const Size(1240, 800));
      final file = File(p.join(root.path, 'notes.txt'))
        ..writeAsStringSync('old');
      final browser = BrowserService(
        store: SidePanelMemoryStore(),
        supported: false,
      );
      final panel = DesktopSidePanelController(browser: browser);
      await tester.pumpWidget(
        harness(
          DesktopSidePanel(
            controller: panel,
            conversationId: 'chat',
            topicsOnRight: false,
            filesBuilder: (_) => const SizedBox(),
            topicsBuilder: (_, _) => const SizedBox(),
            child: const SizedBox(),
          ),
        ),
      );
      panel.openPreview(file.path, owner: owner);
      await waitFor(tester, find.byTooltip('Edit'));
      final originalId = panel.activeTab.id;
      file.deleteSync();
      file.createSync();
      panel.openPreview(file.path, owner: owner, startEditing: true);
      await waitFor(tester, input);
      final tab = panel.activeTab as PreviewTab;
      expect(tab.id, originalId);
      expect(tester.widget<EditableText>(input).controller.text, isEmpty);
      await tester.enterText(input, 'local draft');
      await tester.pump();
      late Completer<void> release;
      late Future<void> blocker;
      await tester.runAsync(() async {
        final locked = Completer<void>();
        release = Completer<void>();
        blocker = WorkspaceFileCoordinator.run(file.path, () async {
          locked.complete();
          await release.future;
        });
        await locked.future;
      });
      await tester.tap(find.byTooltip('Save'));
      panel.activate('files');
      await tester.pump();
      file.writeAsStringSync('external');
      release.complete();
      await tester.runAsync(() => blocker);
      panel.activate(tab.id);
      await waitFor(tester, find.text('File changed on disk'));
      expect(tester.widget<EditableText>(input).controller.text, 'local draft');
      await tester.pump(const Duration(seconds: 5));
      await finishTransition(tester);
      await tester.pumpWidget(const SizedBox());
      panel.dispose();
      browser.dispose();
    },
    variant: TargetPlatformVariant.only(TargetPlatform.macOS),
  );
}
