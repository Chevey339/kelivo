import 'dart:convert';
import 'dart:io';

import 'package:Kelivo/core/database/app_database.dart';
import 'package:Kelivo/core/models/message_part.dart';
import 'package:Kelivo/core/models/quote_ref.dart';
import 'package:Kelivo/core/models/workspace.dart';
import 'package:Kelivo/core/models/workspace_binding.dart';
import 'package:Kelivo/core/providers/workspace_provider.dart';
import 'package:Kelivo/core/services/chat/chat_service.dart';
import 'package:Kelivo/core/services/storage/attachment_file_lock.dart';
import 'package:Kelivo/core/services/workspace/file_link_resolver.dart';
import 'package:Kelivo/core/services/workspace/workspace_paths.dart';
import 'package:Kelivo/core/services/workspace/workspace_session_sync.dart';
import 'package:Kelivo/core/services/workspace/workspace_tool_context.dart';
import 'package:Kelivo/shared/markdown/markdown_image_sources.dart';
import 'package:Kelivo/utils/app_directories.dart';
import 'package:Kelivo/utils/sandbox_path_resolver.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart' as sqlite;
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import '../../../support/claude_test_api.dart' show FakePathProviderPlatform;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  late ChatService chat;
  late FileLinkResolver resolver;
  late Workspace workspace;
  late String workspaceRoot;
  late PathProviderPlatform originalPaths;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('kelivo_fork_session_');
    originalPaths = PathProviderPlatform.instance;
    PathProviderPlatform.instance = FakePathProviderPlatform(root.path);
    SandboxPathResolver.debugSetDirs(docsDir: root.path, supportDir: root.path);
    chat = ChatService();
    await chat.init();
    await chat.runAssetReferenceMaintenance();
    await chat.runAssetMaintenance();
    final workspaces = WorkspaceProvider(
      store: chat.chatRepositoryOrNull!.compression.store,
    );
    workspace = await workspaces.create(name: 'Project');
    workspaceRoot = await workspaces.hostRootFor(workspace);
    chat.newConversationExtras = (_) =>
        WorkspaceBinding(workspaceId: workspace.id).applyTo({});
    resolver = FileLinkResolver(workspaces: workspaces);
  });

  tearDown(() async {
    await chat.close();
    await Hive.close();
    PathProviderPlatform.instance = originalPaths;
    SandboxPathResolver.debugSetDirs();
    await root.delete(recursive: true);
  });

  Future<File> resolve(String href, String conversationId) async =>
      (await resolver.resolveToHostFile(
        KelivoLink.tryParse(href)!,
        conversationId: conversationId,
        binding: WorkspaceBinding(workspaceId: workspace.id),
      ))!;

  WorkspaceToolContext context(Directory session) => WorkspaceToolContext(
    workspace: workspace,
    binding: WorkspaceBinding(workspaceId: workspace.id),
    paths: WorkspacePaths.sandboxed(
      workspaceHostRoot: workspaceRoot,
      sessionHostDir: session.path,
      skillsHostDir: '${root.path}/skills',
    ),
    sessionDir: session,
    outputsDir: Directory('${session.path}/outputs'),
  );

  for (final mode in ['selected versions', 'all versions', 'duplicate']) {
    test(
      '$mode inherits exactly the referenced session files as independent copies',
      () async {
        final source = await chat.createConversation(title: 'Source');
        final session = await AppDirectories.sessionDir(source.id);
        Future<File> write(String path) async {
          final file = File('${session.path}/$path');
          await file.parent.create(recursive: true);
          return file.writeAsString(path);
        }

        const relative = 'outputs/reports/报告 1.txt';
        final report = await write(relative);
        const href = 'kelivo://chat/outputs/reports/%E6%8A%A5%E5%91%8A%201.txt';
        final upload = File('${root.path}/upload/input.txt');
        await upload.parent.create();
        await upload.writeAsString('upload');
        final user = await chat.addMessage(
          conversationId: source.id,
          role: 'user',
          parts: [
            FilePart(
              uri: SandboxPathResolver.canonicalize(upload.path),
              name: 'tool.txt',
            ),
          ],
        );
        await syncAttachments(context(session), [user]);
        final previous = await chat.addMessage(
          conversationId: source.id,
          role: 'assistant',
          content: '[previous](kelivo://chat/outputs/old.txt)',
        );
        final anchor = (await chat.appendMessageVersion(
          messageId: previous.id,
          content:
              '[report]($href) [explicit](kelivo://chat/${source.id}/outputs/explicit.txt) '
              '`kelivo://chat/${source.id}/outputs/explicit.txt` '
              '[by reference][r] [other](kelivo://chat/another/outputs/file.txt) '
              '[missing](kelivo://chat/outputs/missing.txt) '
              '`[sample](kelivo://chat/outputs/sample.txt)`\n\n[r]: kelivo://chat/${source.id}/outputs/ref.txt',
        ))!;
        final reasoning =
            '[reason](kelivo://chat/${source.id}/outputs/thinking.txt)';
        final segment = '[segment](kelivo://session/segment.txt)';
        final offsets = [anchor.content.indexOf('[other]')];
        await chat.updateMessage(
          anchor.id,
          translation:
              '[翻译](kelivo://chat/${source.id}/outputs/translation.txt)',
          reasoningText: reasoning,
          reasoningSegmentsJson: jsonEncode({
            'v': 2,
            'segments': [
              {'text': segment},
            ],
            'contentSplits': {
              'offsets': offsets,
              'reasoningCounts': [1],
              'toolCounts': [0],
            },
          }),
        );
        final providerMetadata = {
          'assistant_blocks': [
            {
              'type': 'thinking',
              'thinking': reasoning,
              'signature': 'preserved',
            },
          ],
        };
        await chat.setToolEvents(anchor.id, [
          {
            'id': 'tool',
            'name': 'write',
            'arguments': {},
            'content': jsonEncode({
              'link': 'kelivo://session/notes/result.txt',
              'description':
                  'Saved kelivo://chat/${source.id}/outputs/tool-log.txt',
              'markdown':
                  '[raw](/chat/outputs/raw.txt) [file](kelivo://chat/outputs/one.txt)',
            }),
            'metadata': {
              'anthropic': providerMetadata,
              'workspace': {
                'files': [
                  {
                    'link': 'kelivo://chat/attachments/tool.txt',
                    'path': '/chat/attachments/tool.txt',
                    'role': 'created',
                  },
                ],
              },
            },
          },
        ]);
        await chat.addMessage(
          conversationId: source.id,
          role: 'user',
          content: '[later](kelivo://chat/outputs/later.txt)',
        );
        for (final path in [
          'outputs/old.txt',
          'outputs/explicit.txt',
          'outputs/translation.txt',
          'outputs/tool-log.txt',
          'outputs/raw.txt',
          'outputs/thinking.txt',
          'segment.txt',
          'outputs/one.txt',
          'outputs/one.txt)',
          'outputs/ref.txt',
          'outputs/later.txt',
          'outputs/sample.txt',
          'outputs/unrelated.txt',
          'notes/result.txt',
        ]) {
          await write(path);
        }

        final uploadUri = SandboxPathResolver.canonicalize(upload.path);
        final index = File('${session.path}/$sessionAttachmentIndexName');
        final sourceIndex =
            jsonDecode(await index.readAsString()) as Map<String, dynamic>;
        final record = sourceIndex[uploadUri];
        sourceIndex['other-upload'] = {'name': 'other.txt'};
        await index.writeAsString(jsonEncode(sourceIndex));
        final target = mode == 'duplicate'
            ? (await chat.duplicateConversation(source.id))!
            : await chat.forkConversationAtRevision(
                sourceConversationId: source.id,
                sourceRevisionId: anchor.id,
                preserveVersions: mode == 'all versions',
              );
        final targetRoot = await AppDirectories.sessionDir(target.id);
        expect(
          jsonDecode(
            await File(
              '${targetRoot.path}/$sessionAttachmentIndexName',
            ).readAsString(),
          ),
          {uploadUri: record},
        );
        final messages = await chat.loadMessages(target.id);
        final copiedMessage = messages.singleWhere(
          (m) => m.content.contains('[report]'),
        );
        final body = copiedMessage.content;
        expect(body.indexOf('[other]'), offsets.single);
        expect(body, contains('[by reference][r]'));
        expect(
          body,
          contains('[r]: kelivo://chat/${target.id}/outputs/ref.txt'),
        );
        expect(
          copiedMessage.reasoningText,
          contains('kelivo://chat/${target.id}/outputs/thinking.txt'),
        );
        expect(
          await File(
            p.join(targetRoot.path, 'outputs', 'thinking.txt'),
          ).exists(),
          isTrue,
        );
        expect(
          await File(p.join(targetRoot.path, 'segment.txt')).exists(),
          isTrue,
        );
        expect(
          await File(p.join(targetRoot.path, 'outputs', 'one.txt')).exists(),
          isTrue,
        );
        expect(
          await File(p.join(targetRoot.path, 'outputs', 'one.txt)')).exists(),
          isFalse,
        );
        final translated = markdownImageSources(
          copiedMessage.translation!,
          includeLinks: true,
        ).single;
        expect(
          p.equals(
            (await resolve(translated, target.id)).path,
            p.join(targetRoot.path, 'outputs', 'translation.txt'),
          ),
          isTrue,
        );
        final event = chat.getToolEventsForMessage(copiedMessage).single;
        expect(event['metadata']['anthropic'], providerMetadata);
        expect(
          jsonDecode(event['content'] as String)['description'],
          'Saved kelivo://chat/${target.id}/outputs/tool-log.txt',
        );
        expect(
          await File('${targetRoot.path}/outputs/raw.txt').readAsString(),
          'outputs/raw.txt',
        );
        final explicitHref = markdownImageSources(
          body,
          includeLinks: true,
        ).singleWhere((href) => href.endsWith('/explicit.txt'));
        expect(
          await (await resolve(explicitHref, target.id)).readAsString(),
          'outputs/explicit.txt',
        );
        expect(
          p.isWithin(
            targetRoot.path,
            (await resolve(explicitHref, target.id)).path,
          ),
          isTrue,
        );
        expect(
          body,
          contains('`kelivo://chat/${source.id}/outputs/explicit.txt`'),
        );
        expect(body, contains('kelivo://chat/another/outputs/file.txt'));
        final targetReport = await resolve(href, target.id);
        expect(await targetReport.readAsString(), relative);
        await targetReport.writeAsString('changed in copy');
        expect(await report.readAsString(), relative);
        expect(
          await File('${targetRoot.path}/notes/result.txt').readAsString(),
          'notes/result.txt',
        );
        expect(
          await File('${targetRoot.path}/attachments/tool.txt').readAsString(),
          'upload',
        );
        final synced = await syncAttachments(context(targetRoot), messages);
        expect(synced.single.name, 'tool.txt');
        expect(
          await Directory('${targetRoot.path}/attachments').list().length,
          1,
        );
        for (final name in ['sample', 'unrelated', 'missing']) {
          expect(
            await File('${targetRoot.path}/outputs/$name.txt').exists(),
            isFalse,
          );
        }
        expect(
          await File('${targetRoot.path}/outputs/old.txt').exists(),
          mode != 'selected versions',
        );
        expect(
          await File('${targetRoot.path}/outputs/later.txt').exists(),
          mode == 'duplicate',
        );

        await chat.deleteConversation(source.id);
        await AttachmentFileLock.synchronized(() async {
          if (await session.exists()) await session.delete(recursive: true);
        });
        expect(
          await (await resolve(href, target.id)).readAsString(),
          'changed in copy',
        );
        expect(
          await (await resolve(explicitHref, target.id)).readAsString(),
          'outputs/explicit.txt',
        );
        final copiedUpload = messages.first.parts.whereType<FilePart>().single;
        expect(
          await File(SandboxPathResolver.fix(copiedUpload.uri)).readAsString(),
          'upload',
        );
      },
    );
  }

  test(
    'failed file transfer rolls back copied rows and files and permits retry',
    () async {
      final source = await chat.createConversation(title: 'Source');
      final session = await AppDirectories.sessionDir(source.id);
      final file = File('${session.path}/outputs/explicit.txt');
      await file.writeAsString('source data');
      await chat.addMessage(
        conversationId: source.id,
        role: 'assistant',
        content: '[result](kelivo://chat/${source.id}/outputs/explicit.txt)',
      );
      final db = sqlite.sqlite3.open(
        '${root.path}/${AppDatabase.databaseFileName}',
      );
      addTearDown(db.close);
      db.execute("""
      CREATE TRIGGER fail_session_copy BEFORE UPDATE OF payload ON message_part_rows
      WHEN NEW.payload LIKE '%explicit.txt%' BEGIN
        SELECT RAISE(ABORT, 'injected session copy failure');
      END
    """);
      await expectLater(
        chat.duplicateConversation(source.id),
        throwsA(anything),
      );
      expect(
        db.select('SELECT id FROM conversation_rows').map((r) => r['id']),
        [source.id],
      );
      expect(
        p.equals((await session.parent.list().single).path, session.path),
        isTrue,
      );
      expect(await file.readAsString(), 'source data');
      db.execute('DROP TRIGGER fail_session_copy');
      final copy = (await chat.duplicateConversation(source.id))!;
      expect(
        await (await resolve(
          'kelivo://chat/outputs/explicit.txt',
          copy.id,
        )).readAsString(),
        'source data',
      );
    },
  );

  test(
    'quoted text and timeline splits follow rewritten non-UUID identifiers',
    () async {
      const source = 'imported';
      final reply = await chat.addMessage(
        conversationId: source,
        role: 'assistant',
        parts: const [
          TextPart('😀 preface\n'),
          TextPart(
            '[file][ref]\n\n[ref]: kelivo://chat/imported/outputs/tmp.txt\n\nquoted text',
          ),
        ],
      );
      final start = reply.content.indexOf('quoted text');
      await chat.updateMessage(
        reply.id,
        reasoningSegmentsJson: jsonEncode({
          'v': 2,
          'segments': [],
          'contentSplits': {
            'offsets': [start],
            'reasoningCounts': [1],
            'toolCounts': [0],
          },
        }),
      );
      await chat.addMessage(
        conversationId: source,
        role: 'user',
        content: quotePlaceholder,
        quotes: [
          QuoteRef(
            id: 'q',
            messageId: reply.id,
            start: start,
            end: start + 'quoted text'.length,
            text: 'quoted text',
            model: null,
            createdAt: DateTime.utc(2026),
          ),
        ],
      );
      final copy = (await chat.duplicateConversation(source))!;
      final messages = await chat.loadMessages(copy.id);
      final body = messages.first;
      final quote = messages.last.quotes.single;
      expect(
        body.content,
        reply.content.replaceFirst('/imported/', '/${copy.id}/'),
      );
      expect(quote.messageId, body.id);
      expect(body.content.substring(quote.start, quote.end), quote.text);
      expect(
        jsonDecode(body.reasoningSegmentsJson!)['contentSplits']['offsets'],
        [quote.start],
      );
    },
  );

  test(
    'joins split links, keeps Markdown escapes and matches complete tool addresses',
    () async {
      final source = await chat.createConversation(title: 'Split links');
      final session = await AppDirectories.sessionDir(source.id);
      for (final name in [
        'one',
        'two',
        'three',
        'four',
        'native',
        'foreign',
        'first',
        'second',
      ]) {
        await File(
          p.join(session.path, 'outputs', '$name.txt'),
        ).writeAsString(name);
      }
      final uri = 'kelivo://chat/${source.id}/outputs/';
      final escaped = uri.replaceFirst(':', r'\:');
      final entity = uri.replaceFirst(':', '&#58;');
      final native = File(
        p.join(session.path, 'outputs', 'native.txt'),
      ).uri.toString();
      final parts = [
        const TextPart('[one][r]\n\n'),
        TextPart(
          '[r]: ${uri}one.txt\n\n[two](${escaped}two.txt) [three](${entity}three.txt) [four](kel',
        ),
        TextPart('ivo://chat/${source.id}/outputs/four.txt)'),
      ];
      final msg = await chat.addMessage(
        conversationId: source.id,
        role: 'assistant',
        parts: parts,
      );
      await chat.setToolEvents(msg.id, [
        {
          'id': 'tool',
          'name': 'read',
          'arguments': {},
          'content':
              '${uri}first.txt#page=2\n${uri}second.txt\nSaved to $native. External kelivo://workspace/chat/outputs/foreign.txt',
          'metadata': {
            'workspace': {'link': '  ${uri}first.txt '},
          },
        },
      ]);
      final copy = (await chat.duplicateConversation(source.id))!;
      final copied = (await chat.loadMessages(copy.id)).single;
      expect(copied.content, msg.content.replaceAll(source.id, copy.id));
      expect(
        copied.parts.whereType<TextPart>().map((part) => part.text),
        parts.map((part) => part.text.replaceAll(source.id, copy.id)),
      );
      final dir = await AppDirectories.sessionDir(copy.id);
      for (final name in ['one', 'two', 'three', 'four', 'native']) {
        expect(
          await File(p.join(dir.path, 'outputs', '$name.txt')).readAsString(),
          name,
        );
      }
      expect(
        await File(p.join(dir.path, 'outputs', 'foreign.txt')).exists(),
        isFalse,
      );
      expect(
        await File(p.join(dir.path, 'outputs', 'second.txt')).readAsString(),
        'second',
      );
      expect(
        chat
            .getToolEventsForMessage(copied)
            .single['metadata']['workspace']['link'],
        '  ${uri.replaceFirst(source.id, copy.id)}first.txt ',
      );
      final result =
          chat.getToolEventsForMessage(copied).single['content'] as String;
      expect(
        result,
        '${uri.replaceFirst(source.id, copy.id)}first.txt#page=2\n${uri.replaceFirst(source.id, copy.id)}second.txt\nSaved to ${native.replaceFirst(source.id, copy.id)}. External kelivo://workspace/chat/outputs/foreign.txt',
      );
    },
  );

  test(
    'separates Markdown blocks at tool cards and copies space-containing native paths',
    () async {
      final source = await chat.createConversation(title: 'Tool blocks');
      final session = await AppDirectories.sessionDir(source.id);
      final first = File(
        p.join(session.path, 'outputs', 'space dir', 'report one.txt'),
      );
      await first.parent.create(recursive: true);
      await first.writeAsString('one');
      final second = File(p.join(first.parent.path, 'report two.txt'));
      await second.writeAsString('two');
      await File(
        p.join(session.path, 'outputs', 'visible.txt'),
      ).writeAsString('visible');
      final event = {
        'id': 'x',
        'name': 'write',
        'arguments': {},
        'content': first.path,
        'metadata': {
          'workspace': {'stdoutPreview': 'Saved to "${second.path}"'},
        },
      };
      await chat.addMessage(
        conversationId: source.id,
        role: 'assistant',
        parts: [
          const TextPart('```txt\npartial\n'),
          ToolCallPart(jsonEncode(event)),
          const TextPart('[visible](kelivo://chat/outputs/visible.txt)'),
        ],
      );
      final copy = (await chat.duplicateConversation(source.id))!;
      final copied = (await chat.loadMessages(copy.id)).single;
      final output = chat.getToolEventsForMessage(copied).single;
      final target = await AppDirectories.sessionDir(copy.id);
      expect(
        await File(
          p.join(target.path, 'outputs', 'visible.txt'),
        ).readAsString(),
        'visible',
      );
      expect(await File(output['content'] as String).readAsString(), 'one');
      final other = p.join(
        target.path,
        'outputs',
        'space dir',
        'report two.txt',
      );
      expect(await File(other).readAsString(), 'two');
      expect(
        output['metadata']['workspace']['stdoutPreview'],
        'Saved to "${second.path.replaceFirst(source.id, copy.id)}"',
      );
      expect(p.isWithin(target.path, output['content'] as String), isTrue);
    },
  );

  test(
    'explicit missing links keep their new owner even without a source session',
    () async {
      final original = await chat.createConversation(title: 'No session');
      final link = 'kelivo://chat/${original.id}/outputs/later.txt';
      await chat.addMessage(
        conversationId: original.id,
        role: 'assistant',
        content: '[later]($link)',
      );
      final fork = (await chat.duplicateConversation(original.id))!;
      final copied = (await chat.loadMessages(fork.id)).single;
      expect(
        copied.content,
        '[later](kelivo://chat/${fork.id}/outputs/later.txt)',
      );
      final source = await AppDirectories.sessionDir(original.id);
      await File(
        p.join(source.path, 'outputs', 'later.txt'),
      ).writeAsString('original only');
      final href = markdownImageSources(
        copied.content,
        includeLinks: true,
      ).single;
      expect(
        await resolver.resolveToHostFile(
          KelivoLink.tryParse(href)!,
          conversationId: fork.id,
          binding: const WorkspaceBinding(),
        ),
        isNull,
      );
    },
  );

  test(
    'session file copies stay inside the source directory',
    () async {
      final source = await chat.createConversation(title: 'Source');
      final session = await AppDirectories.sessionDir(source.id);
      final elsewhere = File('${root.path}/external/data.txt');
      await elsewhere.parent.create();
      await elsewhere.writeAsString('external');
      await Link(
        '${session.path}/outputs/external',
      ).create(elsewhere.parent.path);
      await chat.addMessage(
        conversationId: source.id,
        role: 'assistant',
        content: '[link](kelivo://chat/outputs/external/data.txt)',
      );
      final copy = (await chat.duplicateConversation(source.id))!;
      final target = await AppDirectories.sessionDir(copy.id);
      expect(
        await File('${target.path}/outputs/external/data.txt').exists(),
        isFalse,
      );
    },
    skip: Platform.isWindows
        ? 'Creating symbolic links may require administrator privileges.'
        : false,
  );
}
