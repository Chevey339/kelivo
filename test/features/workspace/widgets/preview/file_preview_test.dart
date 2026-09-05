import 'dart:async';
import 'dart:io';

import 'package:Kelivo/core/database/app_database.dart';
import 'package:Kelivo/core/database/extension_entity_store.dart';
import 'package:Kelivo/core/models/conversation.dart';
import 'package:Kelivo/core/models/workspace_binding.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/providers/workspace_provider.dart';
import 'package:Kelivo/core/services/chat/chat_service.dart';
import 'package:Kelivo/core/services/workspace/file_link_resolver.dart';
import 'package:Kelivo/features/chat/pages/image_viewer_page.dart';
import 'package:Kelivo/features/settings/widgets/custom_theme_widgets.dart';
import 'package:Kelivo/features/workspace/widgets/preview/code_file_preview.dart';
import 'package:Kelivo/features/workspace/widgets/preview/file_preview.dart';
import 'package:Kelivo/icons/lucide_adapter.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/widgets/custom_bottom_sheet.dart';
import 'package:Kelivo/shared/widgets/ios_tile_button.dart';
import 'package:Kelivo/shared/widgets/markdown_with_highlight.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image_lib;
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';

import '../../../../support/business_test_harness.dart';

const _pngBytes = <int>[
  0x89,
  0x50,
  0x4E,
  0x47,
  0x0D,
  0x0A,
  0x1A,
  0x0A,
  0x00,
  0x00,
  0x00,
  0x0D,
  0x49,
  0x48,
  0x44,
  0x52,
  0x00,
  0x00,
  0x00,
  0x01,
  0x00,
  0x00,
  0x00,
  0x01,
  0x08,
  0x06,
  0x00,
  0x00,
  0x00,
  0x1F,
  0x15,
  0xC4,
  0x89,
  0x00,
  0x00,
  0x00,
  0x0D,
  0x49,
  0x44,
  0x41,
  0x54,
  0x78,
  0xDA,
  0x63,
  0x64,
  0xFE,
  0xCF,
  0x50,
  0x0F,
  0x00,
  0x03,
  0x86,
  0x01,
  0x80,
  0x5A,
  0x34,
  0x7D,
  0x6B,
  0x00,
  0x00,
  0x00,
  0x00,
  0x49,
  0x45,
  0x4E,
  0x44,
  0xAE,
  0x42,
  0x60,
  0x82,
];

class _FakeChatService extends ChatService {
  _FakeChatService(this.conversation);

  final Conversation? conversation;

  @override
  String? get currentConversationId => conversation?.id;

  @override
  Conversation? getConversation(String id) {
    if (conversation == null) return null;
    return conversation!.id == id ? conversation : null;
  }
}

class _RecordingResolver extends FileLinkResolver {
  _RecordingResolver(WorkspaceProvider workspaces)
    : super(workspaces: workspaces);

  final List<KelivoLink> calls = <KelivoLink>[];
  File? result;

  @override
  Future<File?> resolveToHostFile(
    KelivoLink link, {
    required String conversationId,
    required WorkspaceBinding binding,
  }) async {
    calls.add(link);
    return result;
  }
}

Future<void> _pumpAsyncUi(WidgetTester tester) async {
  await tester.pump();
  await tester.runAsync(() async {
    await Future<void>.delayed(const Duration(milliseconds: 50));
  });
  await tester.pump();
}

Future<void> _loadCodePreview(WidgetTester tester) async {
  final state = tester.state<CodeFilePreviewState>(
    find.byType(CodeFilePreview),
  );
  await tester.runAsync(state.load);
  await tester.pump();
}

Future<void> _loadMarkdownPreview(WidgetTester tester) async {
  final state = tester.state<MarkdownFilePreviewState>(
    find.byType(MarkdownFilePreview),
  );
  await tester.runAsync(state.load);
  await tester.pump();
}

Future<void> _loadImagePreview(WidgetTester tester) async {
  final state = tester.state<ImageFilePreviewState>(
    find.byType(ImageFilePreview),
  );
  await tester.runAsync(state.load);
  await tester.pump();
}

List<int> _png2x2Bytes() {
  final image = image_lib.Image(width: 2, height: 2, numChannels: 4)
    ..clear(image_lib.ColorRgba8(255, 80, 160, 255));
  return image_lib.encodePng(image);
}

List<int> _pngBytesOf({required int width, required int height}) {
  final image = image_lib.Image(width: width, height: height, numChannels: 4)
    ..clear(image_lib.ColorRgba8(255, 80, 160, 255));
  return image_lib.encodePng(image);
}

void _setDesktopView(WidgetTester tester) {
  tester.view.physicalSize = const Size(1400, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _openPreview(
  WidgetTester tester,
  File file, {
  required FilePreviewKind kind,
}) async {
  await tester.pumpWidget(
    _previewHarness(
      child: Builder(
        builder: (context) {
          return TextButton(
            onPressed: () {
              unawaited(
                showFilePreview(context, file, kind: kind, autoLoad: false),
              );
            },
            child: const Text('open-preview'),
          );
        },
      ),
    ),
  );
  await tester.tap(find.text('open-preview'));
  await tester.pump();
  await tester.pump();
}

Widget _previewHarness({required Widget child}) {
  return ChangeNotifierProvider(
    create: (_) => SettingsProvider(createBusinessTestPreferences()),
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('kelivo_preview_');
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  test('classifies preview kind by extension and content sniff', () async {
    final image = File(p.join(tempDir.path, 'pic.png'))
      ..writeAsBytesSync(_pngBytes);
    expect(await classifyFilePreview(image), FilePreviewKind.image);

    final markdown = File(p.join(tempDir.path, 'note.md'))
      ..writeAsStringSync('# Hello preview');
    expect(await classifyFilePreview(markdown), FilePreviewKind.markdown);

    final code = File(p.join(tempDir.path, 'main.dart'))
      ..writeAsStringSync('void main() {}\n');
    expect(await classifyFilePreview(code), FilePreviewKind.code);

    final pdf = File(p.join(tempDir.path, 'doc.pdf'))
      ..writeAsBytesSync(const [0x25, 0x50, 0x44, 0x46, 0x2D, 0x00, 0x01]);
    expect(await classifyFilePreview(pdf), FilePreviewKind.binary);

    final sniffed = File(p.join(tempDir.path, 'unknown.dat'))
      ..writeAsStringSync('plain text without nuls');
    expect(await classifyFilePreview(sniffed), FilePreviewKind.code);
  });

  testWidgets('showFilePreview opens code files in CodeFilePreview', (
    tester,
  ) async {
    final code = File(p.join(tempDir.path, 'main.dart'))
      ..writeAsStringSync('void main() {}\n');
    await _openPreview(tester, code, kind: FilePreviewKind.code);
    expect(find.byType(CodeFilePreview), findsOneWidget);
  });

  testWidgets('code preview renders the line count', (tester) async {
    final file = File(p.join(tempDir.path, 'lines.txt'))
      ..writeAsStringSync('one\ntwo\nthree\n');

    await tester.pumpWidget(
      _previewHarness(child: CodeFilePreview(file: file, autoLoad: false)),
    );
    await _loadCodePreview(tester);

    expect(find.byKey(CodeFilePreview.lineCountKey), findsOneWidget);
    expect(find.textContaining('4'), findsWidgets);
  });

  testWidgets('code preview shows the large-file state', (tester) async {
    final file = File(p.join(tempDir.path, 'huge.txt'))
      ..writeAsStringSync('0123456789' * 20);

    await tester.pumpWidget(
      _previewHarness(
        child: CodeFilePreview(file: file, maxBytes: 16, autoLoad: false),
      ),
    );
    await _loadCodePreview(tester);

    expect(find.byKey(CodeFilePreview.tooLargeKey), findsOneWidget);
    expect(
      find.text(
        'This file is too large to preview. Open it externally instead.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('showFilePreview opens markdown with a source/rendered toggle', (
    tester,
  ) async {
    final markdown = File(p.join(tempDir.path, 'note.md'))
      ..writeAsStringSync('# Hello preview');

    await _openPreview(tester, markdown, kind: FilePreviewKind.markdown);
    expect(find.byType(MarkdownFilePreview), findsOneWidget);
    await _loadMarkdownPreview(tester);
    expect(find.byType(MarkdownWithCodeHighlight), findsOneWidget);
    expect(find.text('Rendered'), findsOneWidget);
    expect(find.text('Source'), findsOneWidget);
  });

  testWidgets('markdown preview builds MarkdownWithCodeHighlight', (
    tester,
  ) async {
    final markdown = File(p.join(tempDir.path, 'readme.md'))
      ..writeAsStringSync('# Title\n\nHello **world**.');

    await tester.pumpWidget(
      _previewHarness(
        child: MarkdownFilePreview(file: markdown, autoLoad: false),
      ),
    );
    await _loadMarkdownPreview(tester);

    expect(find.byType(MarkdownWithCodeHighlight), findsOneWidget);
  });

  testWidgets('showFilePreview opens unknown binaries as an info card', (
    tester,
  ) async {
    final pdf = File(p.join(tempDir.path, 'doc.pdf'))
      ..writeAsBytesSync(const [0x25, 0x50, 0x44, 0x46, 0x2D, 0x00, 0x01]);

    await _openPreview(tester, pdf, kind: FilePreviewKind.binary);
    expect(find.byKey(BinaryFilePreview.cardKey), findsOneWidget);
    expect(find.text('doc.pdf'), findsWidgets);
    expect(find.byType(IosTileButton), findsNWidgets(3));
    expect(find.byKey(BinaryFilePreview.openWithKey), findsOneWidget);
    expect(find.byKey(BinaryFilePreview.shareKey), findsOneWidget);
    expect(find.byKey(BinaryFilePreview.exportKey), findsOneWidget);
    expect(find.byKey(BinaryFilePreview.revealKey), findsNothing);
    expect(find.byKey(FilePreviewFrame.exportActionKey), findsOneWidget);
    expect(find.byIcon(Lucide.Copy), findsNothing);
    expect(find.text('Copy path'), findsNothing);
  });

  testWidgets('binary card exposes open/share/export on mobile', (
    tester,
  ) async {
    final pdf = File(p.join(tempDir.path, 'report.pdf'))
      ..writeAsBytesSync(const [0x25, 0x50, 0x44, 0x46, 0x2D, 0x00, 0x01]);

    await tester.pumpWidget(
      _previewHarness(child: BinaryFilePreview(file: pdf)),
    );

    expect(find.byType(IosTileButton), findsNWidgets(3));
    expect(find.text('Open with…'), findsOneWidget);
    expect(find.text('Share'), findsOneWidget);
    expect(find.text('Export'), findsOneWidget);
    expect(find.byIcon(Lucide.FileText), findsOneWidget);
    final typeIcon = tester.widget<Icon>(
      find.byKey(BinaryFilePreview.typeIconKey),
    );
    expect(typeIcon.size, 48);
    final iconParent = tester.widget(
      find
          .ancestor(
            of: find.byKey(BinaryFilePreview.typeIconKey),
            matching: find.byWidgetPredicate(
              (widget) => widget is Column || widget is Container,
            ),
          )
          .first,
    );
    expect(iconParent, isA<Column>());
  });

  testWidgets('binary zip preview uses an archive glyph and desktop actions', (
    tester,
  ) async {
    _setDesktopView(tester);
    final zip = File(p.join(tempDir.path, 'archive.zip'))
      ..writeAsBytesSync(const [0x50, 0x4B, 0x03, 0x04]);

    await tester.pumpWidget(
      _previewHarness(child: BinaryFilePreview(file: zip)),
    );

    expect(find.byIcon(Lucide.FileArchive), findsOneWidget);
    expect(find.byKey(BinaryFilePreview.openWithKey), findsOneWidget);
    expect(find.byKey(BinaryFilePreview.shareKey), findsOneWidget);
    expect(find.byKey(BinaryFilePreview.exportKey), findsOneWidget);
    expect(find.byKey(BinaryFilePreview.revealKey), findsOneWidget);
    expect(find.text('Open with…'), findsOneWidget);
    expect(find.text('Share'), findsOneWidget);
    expect(find.text('Export'), findsOneWidget);
    expect(find.text('Show in Finder'), findsOneWidget);
    final openRect = tester.getRect(find.byKey(BinaryFilePreview.openWithKey));
    final shareRect = tester.getRect(find.byKey(BinaryFilePreview.shareKey));
    final exportRect = tester.getRect(find.byKey(BinaryFilePreview.exportKey));
    final revealRect = tester.getRect(find.byKey(BinaryFilePreview.revealKey));
    expect(openRect.top, closeTo(shareRect.top, 1));
    expect(exportRect.top, closeTo(revealRect.top, 1));
    expect(openRect.left, lessThan(shareRect.left));
    expect(exportRect.left, lessThan(revealRect.left));
    expect(exportRect.top, greaterThan(openRect.bottom));
  });

  testWidgets('html preview has export and one browser action', (tester) async {
    final html = File(p.join(tempDir.path, '2048.html'))
      ..writeAsStringSync('<html><body>2048</body></html>');

    await tester.pumpWidget(
      _previewHarness(
        child: FilePreviewPage(
          file: html,
          title: '2048.html',
          kind: FilePreviewKind.html,
          child: HtmlFilePreview(file: html, autoLoad: false),
        ),
      ),
    );

    expect(find.byKey(FilePreviewFrame.exportActionKey), findsOneWidget);
    expect(find.byKey(FilePreviewFrame.openInBrowserActionKey), findsOneWidget);
    expect(find.byIcon(Lucide.Globe), findsOneWidget);
    expect(find.byIcon(Lucide.Download), findsOneWidget);
    expect(find.byIcon(Lucide.Copy), findsNothing);
    expect(find.byIcon(Lucide.ExternalLink), findsOneWidget);
    expect(find.text('Rendered'), findsOneWidget);
    expect(find.text('Source'), findsOneWidget);
  });

  test('preview browser server binds a loopback http uri', () async {
    final html = File(p.join(tempDir.path, 'page.html'))
      ..writeAsStringSync('<html>ok</html>');
    final uri = await startPreviewFileBrowserServer(html);
    addTearDown(closePreviewFileBrowserServer);
    expect(uri.scheme, 'http');
    expect(uri.host, '127.0.0.1');
    expect(uri.port, greaterThan(0));
    expect(uri.path, '/page.html');
  });

  testWidgets('desktop preview opens via dialog, not a bottom sheet', (
    tester,
  ) async {
    _setDesktopView(tester);

    final code = File(p.join(tempDir.path, 'main.dart'))
      ..writeAsStringSync('void main() {}\n');
    await _openPreview(tester, code, kind: FilePreviewKind.code);
    expect(find.byType(AppDialogHeader), findsOneWidget);
    expect(find.byType(CodeFilePreview), findsOneWidget);
    expect(find.byType(CustomBottomSheet), findsNothing);
    expect(find.byType(BottomSheet), findsNothing);
  });

  testWidgets('showFilePreview opens images in ImageViewerPage', (
    tester,
  ) async {
    final image = File(p.join(tempDir.path, 'pic.png'))
      ..writeAsBytesSync(_pngBytes);

    await _openPreview(tester, image, kind: FilePreviewKind.image);
    expect(find.byType(ImageViewerPage), findsOneWidget);
  });

  testWidgets('desktop image preview has a single close and no page counter', (
    tester,
  ) async {
    _setDesktopView(tester);
    final image = File(p.join(tempDir.path, 'pic.png'))
      ..writeAsBytesSync(_pngBytes);

    await _openPreview(tester, image, kind: FilePreviewKind.image);
    expect(find.byType(AppDialogHeader), findsOneWidget);
    expect(find.byType(ImageFilePreview), findsOneWidget);
    expect(find.byType(ImageViewerPage), findsNothing);
    expect(find.byIcon(Lucide.X), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('image-viewer-counter')),
      findsNothing,
    );
    expect(find.text('1/1'), findsNothing);
  });

  testWidgets('64x64 image stays natural size; large image scales down', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final small = File(p.join(tempDir.path, 'small64.png'))
      ..writeAsBytesSync(_pngBytesOf(width: 64, height: 64));
    await tester.pumpWidget(
      _previewHarness(child: ImageFilePreview(file: small, autoLoad: false)),
    );
    await _loadImagePreview(tester);

    final smallBox = tester.getSize(find.byKey(ImageFilePreview.imageKey));
    expect(smallBox, const Size(64, 64));

    final large = File(p.join(tempDir.path, 'large.png'))
      ..writeAsBytesSync(_pngBytesOf(width: 2000, height: 1000));
    await tester.pumpWidget(
      _previewHarness(child: ImageFilePreview(file: large, autoLoad: false)),
    );
    await _loadImagePreview(tester);

    expect(find.byType(FittedBox), findsOneWidget);
    final fitted = tester.getSize(find.byType(FittedBox));
    expect(fitted.width, lessThanOrEqualTo(800));
    expect(fitted.height, lessThanOrEqualTo(600));
    expect(fitted.width / fitted.height, closeTo(2, 0.05));
    expect(fitted.width, lessThan(2000));
    expect(fitted.height, lessThan(1000));
  });

  testWidgets('tiny 2x2 png renders an Image without an error placeholder', (
    tester,
  ) async {
    final image = File(p.join(tempDir.path, 'tiny.png'))
      ..writeAsBytesSync(_png2x2Bytes());

    await tester.pumpWidget(
      _previewHarness(child: ImageFilePreview(file: image, autoLoad: false)),
    );
    await _loadImagePreview(tester);

    expect(find.byKey(ImageFilePreview.imageKey), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
    expect(find.byIcon(Lucide.ImageOff), findsNothing);
  });

  testWidgets('empty markdown render tab shows the empty-state copy', (
    tester,
  ) async {
    final markdown = File(p.join(tempDir.path, 'README.md'))
      ..writeAsStringSync('');

    await tester.pumpWidget(
      _previewHarness(
        child: MarkdownFilePreview(file: markdown, autoLoad: false),
      ),
    );
    await _loadMarkdownPreview(tester);

    expect(find.text('This file is empty'), findsOneWidget);
    expect(find.text("There's nothing to preview."), findsOneWidget);
    expect(find.byType(MarkdownWithCodeHighlight), findsNothing);
  });

  testWidgets('whitespace-only markdown counts as empty', (tester) async {
    final markdown = File(p.join(tempDir.path, 'blank.md'))
      ..writeAsStringSync('  \n\t  \n');

    await tester.pumpWidget(
      _previewHarness(
        child: MarkdownFilePreview(file: markdown, autoLoad: false),
      ),
    );
    await _loadMarkdownPreview(tester);

    expect(find.text('This file is empty'), findsOneWidget);
    expect(find.byType(MarkdownWithCodeHighlight), findsNothing);
  });

  testWidgets('kelivo://workspace tap calls the injected resolver', (
    tester,
  ) async {
    final previewFile = File(p.join(tempDir.path, 'foo.txt'))
      ..writeAsStringSync('resolved-body\nline-2\n');

    late AppDatabase database;
    late WorkspaceProvider workspaces;
    await tester.runAsync(() async {
      database = AppDatabase(NativeDatabase.memory());
      await database.customSelect('SELECT 1;').getSingle();
      workspaces = WorkspaceProvider(store: ExtensionEntityStore(database));
      await workspaces.loaded;
    });
    addTearDown(() async {
      await database.close();
    });
    final resolver = _RecordingResolver(workspaces)..result = previewFile;

    final conversation = Conversation(
      id: 'conv-workspace',
      title: 'Chat',
      extras: const {WorkspaceBinding.keyId: 'ws-1'},
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(
            create: (_) => SettingsProvider(createBusinessTestPreferences()),
          ),
          ChangeNotifierProvider<ChatService>.value(
            value: _FakeChatService(conversation),
          ),
          ChangeNotifierProvider<WorkspaceProvider>.value(value: workspaces),
          Provider<FileLinkResolver>.value(value: resolver),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(
            body: MarkdownWithCodeHighlight(
              text: '[foo](kelivo://workspace/foo.txt)',
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    final link = find.text('foo');
    final richLink = find.textContaining('foo', findRichText: true);
    await tester.tap(link.evaluate().isNotEmpty ? link : richLink.first);
    await _pumpAsyncUi(tester);
    if (find.byType(CodeFilePreview).evaluate().isNotEmpty) {
      await _loadCodePreview(tester);
    }

    expect(resolver.calls, hasLength(1));
    expect(resolver.calls.single.kind, KelivoLinkKind.workspaceFile);
    expect(resolver.calls.single.relativePath, 'foo.txt');
    expect(find.byType(CodeFilePreview), findsOneWidget);
  });
}
