import 'dart:io';

import 'package:Kelivo/core/database/app_database.dart';
import 'package:Kelivo/core/database/extension_entity_store.dart';
import 'package:Kelivo/core/models/conversation.dart';
import 'package:Kelivo/core/models/workspace.dart';
import 'package:Kelivo/core/models/workspace_binding.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/providers/workspace_provider.dart';
import 'package:Kelivo/core/services/chat/chat_service.dart';
import 'package:Kelivo/features/workspace/widgets/files/file_browser.dart';
import 'package:Kelivo/features/workspace/widgets/preview/markdown_file_preview.dart';
import 'package:Kelivo/icons/lucide_adapter.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/markdown/markdown_with_code_highlight.dart';
import 'package:Kelivo/shared/widgets/snackbar.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image_lib;
import 'package:path/path.dart' as p;
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:provider/provider.dart';
// ignore: depend_on_referenced_packages
import 'package:url_launcher_platform_interface/link.dart';
// ignore: depend_on_referenced_packages
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

import '../../support/business_test_harness.dart';
import '../../support/file_browser_test_helpers.dart';
import '../../support/markdown_render_helpers.dart';

class _FakeChat extends ChatService {
  _FakeChat(this.conversation);

  final Conversation? conversation;

  @override
  String? get currentConversationId => conversation?.id;

  @override
  Conversation? getConversation(String id) =>
      conversation?.id == id ? conversation : null;
}

class _FakeUrlLauncher extends UrlLauncherPlatform {
  final List<String> launched = <String>[];

  @override
  LinkDelegate? get linkDelegate => null;

  @override
  Future<bool> canLaunch(String url) async => true;

  @override
  Future<bool> launch(
    String url, {
    required bool useSafariVC,
    required bool useWebView,
    required bool enableJavaScript,
    required bool enableDomStorage,
    required bool universalLinksOnly,
    required Map<String, String> headers,
    String? webOnlyWindowName,
  }) async {
    launched.add(url);
    return true;
  }

  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    launched.add(url);
    return true;
  }
}

List<int> _pngBytes({int width = 8, int height = 8}) {
  final img = image_lib.Image(width: width, height: height, numChannels: 4)
    ..clear(image_lib.ColorRgba8(40, 140, 220, 255));
  return image_lib.encodePng(img);
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late Directory wsRoot;
  late AppDatabase database;
  late WorkspaceProvider workspaces;
  late Workspace workspace;
  late UrlLauncherPlatform previousLauncher;
  late _FakeUrlLauncher launcher;

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync('kelivo_virtual_md_');
    wsRoot = Directory(p.join(tempDir.path, 'ws'))..createSync();
    database = AppDatabase(NativeDatabase.memory());
    await database.customSelect('SELECT 1;').getSingle();
    workspaces = WorkspaceProvider(store: ExtensionEntityStore(database));
    await workspaces.loaded;
    workspace = await workspaces.create(
      name: 'ws',
      kind: WorkspaceKind.linked,
      hostPath: wsRoot.path,
    );
    previousLauncher = UrlLauncherPlatform.instance;
    launcher = _FakeUrlLauncher();
    UrlLauncherPlatform.instance = launcher;
  });

  tearDown(() async {
    UrlLauncherPlatform.instance = previousLauncher;
    workspaces.dispose();
    await database.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  Widget buildChatMarkdown(String text, {String? conversationId = 'conv-1'}) {
    final chat = _FakeChat(
      Conversation(
        id: 'conv-1',
        title: 'Chat',
        extras: {WorkspaceBinding.keyId: workspace.id},
      ),
    );
    addTearDown(chat.dispose);
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => SettingsProvider(createBusinessTestPreferences()),
        ),
        ChangeNotifierProvider<WorkspaceProvider>.value(value: workspaces),
        ChangeNotifierProvider<ChatService>.value(value: chat),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: AppSnackBarOverlay(
          child: Scaffold(
            body: SingleChildScrollView(
              child: MarkdownWithCodeHighlight(
                text: text,
                conversationId: conversationId,
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets(
    'chat renders /workspace markdown and html images, rejects escapes',
    (tester) async {
      File(p.join(wsRoot.path, 'plot.png')).writeAsBytesSync(_pngBytes());
      File(p.join(wsRoot.path, '图片', '图 1.png'))
        ..parent.createSync(recursive: true)
        ..writeAsBytesSync(_pngBytes());
      File(p.join(tempDir.path, 'secret.png')).writeAsBytesSync(_pngBytes());

      await tester.pumpWidget(
        buildChatMarkdown(
          [
            '![plot](/workspace/plot.png)',
            '![cjk](/workspace/图片/图 1.png)',
            '<img src="/workspace/plot.png" width="40" height="40">',
            '![escape1](/workspace/../secret.png)',
            '![escape2](/workspace/%2e%2e/secret.png)',
            '![escape3](/tmp/../secret.png)',
            '![unc](//evil/share/a.png)',
            '![remote-file](file://evil/share/a.png)',
          ].join('\n\n'),
        ),
      );

      for (var i = 0; i < 30; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await tester.pump();
        final decoded = tester
            .widgetList<RawImage>(find.byType(RawImage))
            .where((img) => img.image != null)
            .toList();
        if (decoded.length == 3) break;
      }

      final decoded = tester
          .widgetList<RawImage>(find.byType(RawImage))
          .where((img) => img.image != null)
          .toList();
      expect(decoded, hasLength(3));
      expect(find.byIcon(Lucide.ImageOff), findsNWidgets(5));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('tapping /workspace markdown link opens preview in-app', (
    tester,
  ) async {
    File(p.join(wsRoot.path, 'notes.md')).writeAsStringSync('# Notes\n\nBody');

    await tester.pumpWidget(
      buildChatMarkdown('[open-notes](/workspace/notes.md)'),
    );
    await tester.pump();

    await tester.tapAt(markdownGlyphCenter(tester, 'open-notes'));
    await tester.pump();
    for (var i = 0; i < 10; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
      if (find.byType(MarkdownFilePreview).evaluate().isNotEmpty) break;
    }

    expect(launcher.launched, isEmpty);
    expect(find.byType(MarkdownFilePreview), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('tapping /workspace directory link in chat opens FileBrowser', (
    tester,
  ) async {
    final subdir = Directory(p.join(wsRoot.path, 'subdir'))..createSync();
    File(p.join(subdir.path, 'child.txt')).writeAsStringSync('hello');

    await tester.pumpWidget(
      buildChatMarkdown('[open-subdir](/workspace/subdir)'),
    );
    await tester.pump();

    await tester.tapAt(markdownGlyphCenter(tester, 'open-subdir'));
    await tester.pump();
    for (var i = 0; i < 20; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
      if (find.byType(FileBrowser).evaluate().isNotEmpty) break;
    }

    expect(launcher.launched, isEmpty);
    expect(find.byType(FileBrowser), findsOneWidget);
    await waitForFileBrowserOperation(
      tester,
      tester.state<FileBrowserState>(find.byType(FileBrowser)).refreshEntries(),
    );
    await tester.pump();

    final browser = tester.widget<FileBrowser>(find.byType(FileBrowser));
    expect(browser.root.path, subdir.path);
    expect(find.text('child.txt'), findsOneWidget);
    expect(find.text('File not available'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'chat trailing-slash directory links open FileBrowser and file-with-slash fails closed',
    (tester) async {
      final subdir = Directory(p.join(wsRoot.path, 'subdir'))..createSync();
      File(p.join(subdir.path, 'child.txt')).writeAsStringSync('hello');
      File(p.join(wsRoot.path, 'readme.md')).writeAsStringSync('# Readme');

      await tester.pumpWidget(
        buildChatMarkdown(
          [
            '[with-slash](/workspace/subdir/)',
            '[file-slash](file:///workspace/subdir/)',
            '[kelivo-slash](kelivo://workspace/subdir/)',
            '[file-with-slash](/workspace/readme.md/)',
            '[kelivo-file-slash](kelivo://workspace/readme.md/)',
            '[double-slash](kelivo://workspace/subdir//)',
          ].join('\n\n'),
        ),
      );
      await tester.pump();

      Future<void> tapAndExpectBrowser(String label) async {
        await tester.tapAt(markdownGlyphCenter(tester, label));
        await tester.pump();
        for (var i = 0; i < 20; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 20)),
          );
          await tester.pump();
          if (find.byType(FileBrowser).evaluate().isNotEmpty) break;
        }
        expect(launcher.launched, isEmpty, reason: label);
        expect(find.byType(FileBrowser), findsOneWidget, reason: label);
        expect(
          tester.widget<FileBrowser>(find.byType(FileBrowser)).root.path,
          subdir.path,
        );
        Navigator.of(tester.element(find.byType(FileBrowser))).pop();
        await tester.pumpAndSettle();
      }

      await tapAndExpectBrowser('with-slash');
      await tapAndExpectBrowser('file-slash');
      await tapAndExpectBrowser('kelivo-slash');

      for (final label in [
        'file-with-slash',
        'kelivo-file-slash',
        'double-slash',
      ]) {
        await tester.tapAt(markdownGlyphCenter(tester, label));
        await tester.pump();
        for (var i = 0; i < 20; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 20)),
          );
          await tester.pump(const Duration(milliseconds: 20));
          if (find.text('File not available').evaluate().isNotEmpty) break;
        }
        expect(launcher.launched, isEmpty, reason: label);
        expect(find.byType(FileBrowser), findsNothing, reason: label);
        expect(find.text('File not available'), findsOneWidget, reason: label);
        await tester.pump(const Duration(seconds: 4));
        await tester.pumpAndSettle();
      }

      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('chat fails closed on trailing-slash image references', (
    tester,
  ) async {
    Directory(p.join(wsRoot.path, 'subdir')).createSync();
    File(p.join(wsRoot.path, 'plot.png')).writeAsBytesSync(_pngBytes());

    await tester.pumpWidget(
      buildChatMarkdown(
        [
          '![dir-slash](/workspace/subdir/)',
          '![kelivo-dir](kelivo://workspace/subdir/)',
          '![file-slash](/workspace/plot.png/)',
        ].join('\n\n'),
      ),
    );
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump();

    expect(find.byType(RawImage), findsNothing);
    expect(find.byIcon(Lucide.ImageOff), findsNWidgets(3));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'desktop /tmp renders sanitized, padded, and percent-encoded paths',
    (tester) async {
      final stamp = DateTime.now().microsecondsSinceEpoch;
      final plainName = 'kelivo_tmp_plain_$stamp.png';
      final spaceName = 'kelivo tmp space $stamp.png';
      final encodedName = 'kelivo%20tmp%20space%20$stamp.png';
      final plainFile = File('/tmp/$plainName')
        ..writeAsBytesSync(_pngBytes(width: 12, height: 12));
      final spaceFile = File('/tmp/$spaceName')
        ..writeAsBytesSync(_pngBytes(width: 14, height: 14));
      addTearDown(() {
        if (plainFile.existsSync()) plainFile.deleteSync();
        if (spaceFile.existsSync()) spaceFile.deleteSync();
      });

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(
              create: (_) => SettingsProvider(createBusinessTestPreferences()),
            ),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: SingleChildScrollView(
                child: MarkdownWithCodeHighlight(
                  text: [
                    '![zw](\u200B/tmp/$plainName)',
                    '![pad]( /tmp/$plainName )',
                    '![enc](/tmp/$encodedName)',
                    '![uri](file:///tmp/$plainName)',
                  ].join('\n\n'),
                ),
              ),
            ),
          ),
        ),
      );

      for (var i = 0; i < 30; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await tester.pump();
        final decoded = tester
            .widgetList<RawImage>(find.byType(RawImage))
            .where((img) => img.image != null)
            .toList();
        if (decoded.length == 4) break;
      }

      final decoded = tester
          .widgetList<RawImage>(find.byType(RawImage))
          .where((img) => img.image != null)
          .toList();
      expect(decoded, hasLength(4));
      expect(find.byIcon(Lucide.ImageOff), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    },
    skip: Platform.isAndroid || Platform.isIOS || Platform.isWindows,
  );

  testWidgets(
    'chat mode prioritizes session tmp over host /tmp when both exist',
    (tester) async {
      final appData = Directory(p.join(tempDir.path, 'app'))..createSync();
      final previousPathProvider = PathProviderPlatform.instance;
      PathProviderPlatform.instance = _FakePathProviderPlatform(appData.path);
      addTearDown(() => PathProviderPlatform.instance = previousPathProvider);

      final stamp = DateTime.now().microsecondsSinceEpoch;
      final fileName = 'kelivo_tmp_precedence_$stamp.png';
      final hostFile = File('/tmp/$fileName')
        ..writeAsBytesSync(_pngBytes(width: 10, height: 10));
      addTearDown(() {
        if (hostFile.existsSync()) hostFile.deleteSync();
      });

      final sessionTmpFile =
          File(p.join(appData.path, 'sessions', 'conv-1', 'tmp', fileName))
            ..parent.createSync(recursive: true)
            ..writeAsBytesSync(_pngBytes(width: 24, height: 24));
      expect(sessionTmpFile.existsSync(), isTrue);

      await tester.pumpWidget(
        buildChatMarkdown(
          [
            '![plain](/tmp/$fileName)',
            '![zw](\u200B/tmp/$fileName)',
            '![uri](file:///tmp/$fileName)',
          ].join('\n\n'),
        ),
      );

      for (var i = 0; i < 30; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await tester.pump();
        final decoded = tester
            .widgetList<RawImage>(find.byType(RawImage))
            .where((img) => img.image != null)
            .toList();
        if (decoded.length == 3) break;
      }

      final decoded = tester
          .widgetList<RawImage>(find.byType(RawImage))
          .where((img) => img.image != null)
          .toList();
      expect(decoded, hasLength(3));
      expect(
        decoded.map((img) => img.image!.height).toList(),
        everyElement(24),
      );
      await tester.pumpWidget(const SizedBox.shrink());
    },
    skip: Platform.isAndroid || Platform.isIOS || Platform.isWindows,
  );
}
