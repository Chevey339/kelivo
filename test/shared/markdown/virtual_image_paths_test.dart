import 'dart:io';

import 'package:Kelivo/core/database/app_database.dart';
import 'package:Kelivo/core/database/extension_entity_store.dart';
import 'package:Kelivo/core/models/conversation.dart';
import 'package:Kelivo/core/models/workspace.dart';
import 'package:Kelivo/core/models/workspace_binding.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/providers/workspace_provider.dart';
import 'package:Kelivo/core/services/chat/chat_service.dart';
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
import 'package:provider/provider.dart';
// ignore: depend_on_referenced_packages
import 'package:url_launcher_platform_interface/link.dart';
// ignore: depend_on_referenced_packages
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

import '../../support/business_test_harness.dart';
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

List<int> _pngBytes() {
  final img = image_lib.Image(width: 8, height: 8, numChannels: 4)
    ..clear(image_lib.ColorRgba8(40, 140, 220, 255));
  return image_lib.encodePng(img);
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
}
