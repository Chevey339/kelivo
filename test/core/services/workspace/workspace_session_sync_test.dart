import 'dart:io';
import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/core/models/message_part.dart';
import 'package:Kelivo/core/models/workspace.dart';
import 'package:Kelivo/core/models/workspace_binding.dart';
import 'package:Kelivo/core/services/workspace/workspace_paths.dart';
import 'package:Kelivo/core/services/workspace/workspace_session_sync.dart';
import 'package:Kelivo/core/services/workspace/workspace_tool_context.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'same-name same-size files stay distinct and retry keeps their paths',
    () async {
      final root = Directory.systemTemp.createTempSync('share_collision_');
      addTearDown(() => root.deleteSync(recursive: true));
      final ctx = _context(root);
      final a = File('${root.path}/a')..writeAsStringSync('AAAA');
      final b = File('${root.path}/b')..writeAsStringSync('BBBB');
      final messages = [_message(a, '报告.txt'), _message(b, '报告.txt')];
      final first = await syncAttachments(ctx, messages);
      expect(first.map((f) => f.name).toSet(), hasLength(2));
      expect(
        File(
          '${ctx.sessionDir.path}/attachments/${first[0].name}',
        ).readAsStringSync(),
        'AAAA',
      );
      expect(
        File(
          '${ctx.sessionDir.path}/attachments/${first[1].name}',
        ).readAsStringSync(),
        'BBBB',
      );
      final again = await syncAttachments(ctx, messages.reversed.toList());
      expect(
        again.map((f) => f.modelPath).toList(),
        first.reversed.map((f) => f.modelPath).toList(),
      );
      expect(
        Directory('${ctx.sessionDir.path}/attachments').listSync(),
        hasLength(2),
      );
    },
  );

  test(
    'changed source refreshes its own copy; filenames cannot escape attachments',
    () async {
      final root = Directory.systemTemp.createTempSync('share_changed_');
      addTearDown(() => root.deleteSync(recursive: true));
      final ctx = _context(root);
      final source = File('${root.path}/source')..writeAsStringSync('old');
      final messages = [_message(source, '../../inside.txt')];
      final first = await syncAttachments(ctx, messages);
      expect(first.single.name, 'inside.txt');
      source.writeAsStringSync('new');
      source.setLastModifiedSync(DateTime(2030));
      final again = await syncAttachments(ctx, messages);
      expect(again.single.modelPath, first.single.modelPath);
      expect(
        File(
          '${ctx.sessionDir.path}/attachments/inside.txt',
        ).readAsStringSync(),
        'new',
      );
      expect(File('${root.path}/inside.txt').existsSync(), isFalse);
    },
  );

  test(
    'missing new files surface failure and a repaired source can be retried',
    () async {
      final root = Directory.systemTemp.createTempSync('share_missing_');
      addTearDown(() => root.deleteSync(recursive: true));
      final ctx = _context(root);
      final source = File('${root.path}/missing.zip');
      final messages = [_message(source, 'missing.zip')];
      await expectLater(
        syncAttachments(ctx, messages, requiredMessageId: messages.single.id),
        throwsA(isA<FileSystemException>()),
      );
      source.writeAsBytesSync([1, 2, 3]);
      expect(
        await syncAttachments(
          ctx,
          messages,
          requiredMessageId: messages.single.id,
        ),
        hasLength(1),
      );
      // A previous index must not hide a missing file on a new submission.
      await source.delete();
      await expectLater(
        syncAttachments(ctx, messages, requiredMessageId: messages.single.id),
        throwsA(isA<FileSystemException>()),
      );
      expect(await syncAttachments(ctx, messages), isEmpty);
    },
  );

  test(
    'deleted names reserve case variants on case-insensitive volumes',
    () async {
      final root = Directory.systemTemp.createTempSync('share_case_names_');
      addTearDown(() => root.deleteSync(recursive: true));
      final ctx = _context(root);
      final a = File('${root.path}/a')..writeAsStringSync('AAAA');
      final b = File('${root.path}/b')..writeAsStringSync('BBBB');
      final first = await syncAttachments(ctx, [_message(a, 'Report.txt')]);
      await File(
        '${ctx.sessionDir.path}/attachments/${first.single.name}',
      ).delete();
      final second = await syncAttachments(ctx, [_message(b, 'report.txt')]);
      expect(
        second.single.name.toLowerCase(),
        isNot(first.single.name.toLowerCase()),
      );
    },
  );

  test(
    'shared binary files reach the session folder without touching their source',
    () async {
      final root = Directory.systemTemp.createTempSync('share_session_');
      try {
        final source = File('${root.path}/source.apk')
          ..writeAsBytesSync([0x50, 0x4b, 0, 1]);
        final session = Directory('${root.path}/session')..createSync();
        final now = DateTime.now();
        final context = WorkspaceToolContext(
          workspace: Workspace(
            id: 'work',
            name: 'Work',
            kind: WorkspaceKind.managed,
            createdAt: now,
            updatedAt: now,
          ),
          binding: const WorkspaceBinding(),
          paths: WorkspacePaths.sandboxed(
            workspaceHostRoot: root.path,
            sessionHostDir: session.path,
            skillsHostDir: '${root.path}/skills',
          ),
          sessionDir: session,
          outputsDir: Directory('${session.path}/outputs'),
          conversationId: 'chat',
        );
        final messages = [
          ChatMessage(
            role: 'user',
            conversationId: 'chat',
            parts: [
              FilePart(
                uri: source.path,
                name: '应用.apk',
                mime: 'application/vnd.android.package-archive',
              ),
            ],
          ),
        ];
        final files = await syncAttachments(context, messages);
        expect(files, hasLength(1));
        expect(files.single.modelPath, contains('应用.apk'));
        expect(
          File('${session.path}/attachments/应用.apk').readAsBytesSync(),
          source.readAsBytesSync(),
        );
        expect(source.existsSync(), isTrue);
        expect(await syncAttachments(context, messages), hasLength(1));
        expect(
          Directory('${session.path}/attachments').listSync(),
          hasLength(1),
        );
      } finally {
        root.deleteSync(recursive: true);
      }
    },
  );
}

ChatMessage _message(File file, String name) => ChatMessage(
  role: 'user',
  conversationId: 'chat',
  parts: [FilePart(uri: file.path, name: name)],
);

WorkspaceToolContext _context(Directory root) {
  final session = Directory('${root.path}/session')..createSync();
  return WorkspaceToolContext(
    workspace: Workspace(
      id: 'work',
      name: 'Work',
      kind: WorkspaceKind.managed,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    ),
    binding: const WorkspaceBinding(workspaceId: 'work'),
    paths: WorkspacePaths.sandboxed(
      workspaceHostRoot: root.path,
      sessionHostDir: session.path,
      skillsHostDir: '${root.path}/skills',
    ),
    sessionDir: session,
    outputsDir: Directory('${session.path}/outputs'),
    conversationId: 'chat',
  );
}
