import 'dart:io';
import 'dart:convert';
import 'package:Kelivo/features/chat/widgets/produced_files_row.dart';
import 'package:Kelivo/features/workspace/widgets/files/workspace_file_thumbnail.dart';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';

import 'package:Kelivo/core/database/app_database.dart';
import 'package:Kelivo/core/database/extension_entity_store.dart';
import 'package:Kelivo/core/models/conversation.dart';
import 'package:Kelivo/core/models/workspace.dart';
import 'package:Kelivo/core/models/workspace_binding.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/providers/workspace_provider.dart';
import 'package:Kelivo/core/services/chat/chat_service.dart';
import 'package:Kelivo/core/services/workspace/workspace_tool_metadata.dart';
import 'package:Kelivo/features/chat/widgets/workspace_tool_ui.dart';
import 'package:Kelivo/features/workspace/widgets/files/file_browser.dart';
import 'package:Kelivo/features/workspace/widgets/preview/file_preview.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/widgets/markdown_with_highlight.dart';
import 'package:Kelivo/shared/widgets/snackbar.dart';

import '../../../support/business_test_harness.dart';

class _Chat extends ChatService {
  _Chat(this.conversation);
  final Conversation conversation;
  @override
  Conversation? getConversation(String id) =>
      id == conversation.id ? conversation : null;
}

void main() {
  late Directory root;
  late AppDatabase db;
  late WorkspaceProvider workspaces;
  late Conversation conversation;

  setUp(() async {
    root = Directory.systemTemp.createTempSync('kelivo_file_navigation_');
    File(p.join(root.path, 'note.txt')).writeAsStringSync('preview content');
    Directory(p.join(root.path, 'folder')).createSync();
    File(p.join(root.path, 'folder', 'child.txt')).writeAsStringSync('child');
    db = AppDatabase(NativeDatabase.memory());
    workspaces = WorkspaceProvider(store: ExtensionEntityStore(db));
    await workspaces.loaded;
    final workspace = await workspaces.create(
      name: 'Files',
      kind: WorkspaceKind.linked,
      hostPath: root.path,
    );
    conversation = Conversation(
      id: 'c1',
      title: 'Test',
      extras: WorkspaceBinding(workspaceId: workspace.id).applyTo({}),
    );
  });

  tearDown(() async {
    workspaces.dispose();
    await db.close();
    root.deleteSync(recursive: true);
  });

  Widget harness(Widget child) => MultiProvider(
    providers: [
      ChangeNotifierProvider(
        create: (_) => SettingsProvider(createBusinessTestPreferences()),
      ),
      ChangeNotifierProvider<WorkspaceProvider>.value(value: workspaces),
      ChangeNotifierProvider<ChatService>(create: (_) => _Chat(conversation)),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (_, child) => AppSnackBarOverlay(child: child!),
      home: Scaffold(body: child),
    ),
  );

  Future<void> settle(WidgetTester tester) async {
    // The destination starts disk IO when its route is first built.
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
    }
    if (find.byType(FileBrowser).evaluate().isNotEmpty) {
      await tester.runAsync(
        tester.state<FileBrowserState>(find.byType(FileBrowser)).refreshEntries,
      );
      await tester.pump();
    }
    await tester.pumpAndSettle();
  }

  testWidgets(
    'search file chips open the file preview',
    (tester) async {
      await tester.pumpWidget(
        harness(
          WorkspaceToolCardBody(
            part: WorkspaceToolPart(
              id: 'grep',
              toolName: 'grep',
              metadata: const WorkspaceToolMetadata(
                tool: 'grep',
                status: 'ok',
                files: [
                  WorkspaceToolFile(
                    path: '/workspace/note.txt',
                    link: 'kelivo://workspace/note.txt',
                  ),
                ],
              ).toJson(),
            ),
            conversationId: 'c1',
          ),
        ),
      );
      await tester.tap(find.text('note.txt'));
      await settle(tester);
      expect(find.byType(FilePreviewFrame), findsOneWidget);
      expect(
        tester
            .widget<FilePreviewFrame>(find.byType(FilePreviewFrame))
            .file
            .path,
        p.join(root.path, 'note.txt'),
      );
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant({
      TargetPlatform.android,
      TargetPlatform.macOS,
    }),
  );

  testWidgets(
    'directory chips and markdown links open a read-only file browser',
    (tester) async {
      for (final markdown in [false, true]) {
        await tester.pumpWidget(
          harness(
            markdown
                ? const MarkdownWithCodeHighlight(
                    text: '[folder](kelivo://workspace/folder)',
                    conversationId: 'c1',
                  )
                : const WorkspaceFileChip(
                    path: '/workspace/folder',
                    link: 'kelivo://workspace/folder',
                    isDirectory: true,
                    conversationId: 'c1',
                  ),
          ),
        );
        await tester.tap(find.text('folder').first);
        await settle(tester);
        expect(find.byType(FileBrowser), findsOneWidget);
        final browser = tester.widget<FileBrowser>(find.byType(FileBrowser));
        expect(browser.readOnly, isTrue);
        expect(browser.root.path, p.join(root.path, 'folder'));
        expect(
          browser.modelPathOf(p.join(root.path, 'folder', 'child.txt')),
          p.join(root.path, 'folder', 'child.txt'),
        );
        expect(find.text('child.txt'), findsOneWidget);
        Navigator.of(tester.element(find.byType(FileBrowser))).pop();
        await settle(tester);
      }
    },
    variant: TargetPlatformVariant({
      TargetPlatform.android,
      TargetPlatform.macOS,
    }),
  );

  testWidgets('shell images use the bounded shared thumbnail loader', (
    tester,
  ) async {
    final imageFile = File(p.join(root.path, 'plot.png'));
    await tester.runAsync(
      () => imageFile.writeAsBytes(
        base64Decode(
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/Kz0AAAAASUVORK5CYII=',
        ),
      ),
    );
    await tester.pumpWidget(
      harness(
        ProducedFilesRow(
          conversationId: 'c1',
          parts: [
            WorkspaceToolPart(
              id: 'shell-image',
              toolName: 'shell',
              metadata: const WorkspaceToolMetadata(
                tool: 'shell',
                status: 'ok',
                files: [
                  WorkspaceToolFile(
                    path: '/workspace/plot.png',
                    link: 'kelivo://workspace/plot.png',
                    role: WorkspaceFileRole.created,
                  ),
                ],
              ).toJson(),
            ),
          ],
        ),
      ),
    );
    await settle(tester);
    expect(find.byType(WorkspaceFileThumbnail), findsOneWidget);
    expect(
      tester
          .widget<WorkspaceFileThumbnail>(find.byType(WorkspaceFileThumbnail))
          .entry
          .hostPath,
      imageFile.path,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'missing files report their state instead of silently doing nothing',
    (tester) async {
      await tester.pumpWidget(
        harness(
          const WorkspaceFileChip(
            path: 'missing.txt',
            link: 'kelivo://workspace/missing.txt',
            conversationId: 'c1',
          ),
        ),
      );
      await tester.tap(find.text('missing.txt'));
      await settle(tester);
      expect(find.text('File no longer exists'), findsOneWidget);
      expect(find.byType(FilePreviewFrame), findsNothing);
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
    },
  );
}
