import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/core/models/message_part.dart';
import 'package:Kelivo/core/models/workspace.dart';
import 'package:Kelivo/core/models/workspace_binding.dart';
import 'package:Kelivo/core/services/storage/storage_usage_service.dart';
import 'package:Kelivo/core/services/workspace/workspace_paths.dart';
import 'package:Kelivo/core/services/workspace/workspace_session_sync.dart';
import 'package:Kelivo/core/services/workspace/workspace_tool_context.dart';
import 'package:Kelivo/utils/sandbox_path_resolver.dart';

class _Paths extends PathProviderPlatform {
  _Paths(this.root);
  final String root;
  @override
  Future<String?> getApplicationDocumentsPath() async => root;
  @override
  Future<String?> getApplicationSupportPath() async => root;
  @override
  Future<String?> getApplicationCachePath() async => '$root-system-cache';
  @override
  Future<String?> getTemporaryPath() async => '$root-temp';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  late PathProviderPlatform previousPaths;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('storage_attachments_');
    previousPaths = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _Paths(root.path);
    SandboxPathResolver.debugSetDirs(docsDir: root.path);
  });
  tearDown(() async {
    PathProviderPlatform.instance = previousPaths;
    SandboxPathResolver.debugSetDirs();
    await root.delete(recursive: true);
  });

  test(
    'image and file totals match their lists, including nested files',
    () async {
      await _write(root, 'upload/nested/user.png', 'image');
      await _write(root, 'images/generated.png', 'generated');
      await _write(root, 'images/extra.txt', 'text');
      await _write(root, 'upload/user.pdf', 'document');
      final report = await StorageUsageService.computeReport();
      for (final images in [true, false]) {
        final entries = await StorageUsageService.listUploadEntries(
          images: images,
        );
        final category = report.categories.singleWhere(
          (c) =>
              c.key ==
              (images
                  ? StorageUsageCategoryKey.images
                  : StorageUsageCategoryKey.files),
        );
        expect(entries, hasLength(2));
        expect(category.stats.fileCount, entries.length);
        expect(
          category.stats.bytes,
          entries.fold<int>(0, (sum, e) => sum + e.bytes),
        );
      }
      expect(
        report.categories.fold<int>(0, (sum, c) => sum + c.stats.bytes),
        report.totalBytes,
      );
      expect(
        await StorageUsageService.deleteUploadFiles([
          '${root.path}/images/extra.txt',
        ], images: false),
        1,
      );
    },
  );

  test(
    'cleanup deletes indexed copies across sessions and preserves independent files',
    () async {
      final source = await _write(root, 'upload/报告.txt', 'AAAA');
      final other = await _write(root, 'upload/other.txt', 'BBBB');
      final messages = [
        _message('kelivo-file:///upload/%E6%8A%A5%E5%91%8A.txt'),
        _message(other.path),
      ];
      final contexts = [_context(root, 'a'), _context(root, 'b')];
      for (final ctx in contexts) {
        final copies = await syncAttachments(ctx, messages);
        expect(copies.map((c) => c.name).toSet(), hasLength(2));
        await _write(ctx.sessionDir, 'outputs/报告.txt', 'AAAA');
      }
      final independent = await _write(
        root,
        'workspaces/ws/files/报告.txt',
        'AAAA',
      );
      expect(
        await StorageUsageService.deleteUploadFiles([
          source.path,
        ], images: false),
        1,
      );
      expect(await source.exists(), isFalse);
      expect(await independent.readAsString(), 'AAAA');
      for (final ctx in contexts) {
        expect(
          await File('${ctx.sessionDir.path}/attachments/报告.txt').exists(),
          isFalse,
        );
        expect(
          await File(
            '${ctx.sessionDir.path}/attachments/报告 (2).txt',
          ).readAsString(),
          'BBBB',
        );
        expect(
          await File('${ctx.sessionDir.path}/outputs/报告.txt').readAsString(),
          'AAAA',
        );
        // Historical parts remain in the conversation after a storage cleanup.
        final remaining = await syncAttachments(ctx, messages);
        expect(remaining, hasLength(1));
        expect(remaining.single.sourceUri, other.path);
      }
      await source.writeAsString('restored');
      expect(await syncAttachments(contexts.first, messages), hasLength(2));
    },
  );

  test('deleting an image also removes its ImagePart copy', () async {
    final source = await _write(root, 'upload/picture.png', 'image');
    final ctx = _context(root, 'images');
    await syncAttachments(ctx, [
      ChatMessage(
        role: 'user',
        conversationId: 'images',
        parts: [ImagePart(uri: source.path)],
      ),
    ]);
    expect(
      await StorageUsageService.deleteUploadFiles([source.path], images: true),
      1,
    );
    expect(
      await File('${ctx.sessionDir.path}/attachments/picture.png').exists(),
      isFalse,
    );
  });

  test('cleanup waits for an in-flight attachment copy', () async {
    final source = await _write(root, 'upload/report.txt', 'original');
    final ctx = _context(root, 'busy');
    final copied = Completer<void>();
    final finishCopy = Completer<void>();
    final outside = Zone.current;
    final pending = IOOverrides.runZoned(
      () => syncAttachments(ctx, [_message(source.path)]),
      createFile: (path) {
        final file = outside.run(() => File(path));
        return path == source.path
            ? _PausedCopy(file, copied, finishCopy)
            : file;
      },
    );
    await copied.future;
    final deletion = StorageUsageService.deleteUploadFiles([
      source.path,
    ], images: false);
    finishCopy.complete();
    await pending;
    expect(await deletion, 1);
    expect(
      await File('${ctx.sessionDir.path}/attachments/报告.txt').exists(),
      isFalse,
    );
    expect(await syncAttachments(ctx, [_message(source.path)]), isEmpty);
  });

  test(
    'cleanup matches persisted iOS paths after the app container changes',
    () async {
      final source = await _write(root, 'upload/report.txt', 'report');
      final ctx = _context(root, 'restored');
      const uri =
          '/var/mobile/Containers/Data/Application/12345678-1234-1234-1234-123456789012/Documents/upload/report.txt';
      await syncAttachments(ctx, [_message(uri)]);
      expect(
        await StorageUsageService.deleteUploadFiles([
          source.path,
        ], images: false),
        1,
      );
      expect(
        await File('${ctx.sessionDir.path}/attachments/报告.txt').exists(),
        isFalse,
      );
    },
  );

  test(
    'cleanup ignores paths outside uploads and unsafe index names',
    () async {
      final outside = await _write(root, 'private.txt', 'keep');
      final source = await _write(root, 'upload/source.txt', 'remove');
      final ctx = _context(root, 'unsafe');
      await Directory(
        '${ctx.sessionDir.path}/attachments',
      ).create(recursive: true);
      final sibling = await _write(ctx.sessionDir, 'keep.txt', 'keep');
      await _write(
        ctx.sessionDir,
        '.attachment-index.json',
        jsonEncode({
          source.path: {'name': '../keep.txt'},
        }),
      );
      expect(
        await StorageUsageService.deleteUploadFiles([
          outside.path,
          source.path,
        ], images: false),
        1,
      );
      expect(await outside.readAsString(), 'keep');
      expect(await sibling.readAsString(), 'keep');
    },
  );

  test(
    'an external upload folder is not mistaken for an app attachment source',
    () async {
      final source = await _write(root, 'upload/same.txt', 'remove');
      final ctx = _context(root, 'external');
      final independent = await _write(
        ctx.sessionDir,
        'attachments/keep.txt',
        'keep',
      );
      await _write(
        ctx.sessionDir,
        '.attachment-index.json',
        jsonEncode({
          '/tmp/external-project/upload/same.txt': {'name': 'keep.txt'},
        }),
      );
      expect(
        await StorageUsageService.deleteUploadFiles([
          source.path,
        ], images: false),
        1,
      );
      expect(await independent.readAsString(), 'keep');
    },
  );

  test('cleanup cannot follow a symlinked upload directory', () async {
    final outside = await _write(root, 'external/private.txt', 'keep');
    await Directory('${root.path}/upload').create();
    await Link('${root.path}/upload/link').create(outside.parent.path);
    expect(
      await StorageUsageService.deleteUploadFiles([
        '${root.path}/upload/link/private.txt',
      ], images: false),
      0,
    );
    expect(await outside.readAsString(), 'keep');
  }, skip: Platform.isWindows);

  test(
    'root scan prunes environment and continues after an unreadable directory',
    () async {
      await _write(root, 'environment/rootfs/bin/sh', 'shell');
      await _write(root, 'blocked/private', 'secret');
      await _write(root, 'upload/report.pdf', 'report');
      final visited = <String>[];
      final outside = Zone.current;
      Directory wrap(Directory dir) =>
          _GuardedDirectory(dir, root.path, visited, wrap);
      final report = await IOOverrides.runZoned(
        () => StorageUsageService.computeReport(),
        createDirectory: (path) => wrap(outside.run(() => Directory(path))),
      );
      expect(
        visited.any(
          (path) =>
              p.isWithin('${root.path}/environment', path) ||
              path == '${root.path}/environment',
        ),
        isFalse,
      );
      expect(
        report.categories
            .singleWhere((c) => c.key == StorageUsageCategoryKey.files)
            .stats
            .bytes,
        6,
      );
      expect(
        report.categories
            .singleWhere(
              (c) => c.key == StorageUsageCategoryKey.sandboxEnvironment,
            )
            .stats
            .bytes,
        5,
      );
    },
  );
}

Future<File> _write(Directory root, String relative, String contents) async {
  final file = File(p.join(root.path, relative));
  await file.parent.create(recursive: true);
  await file.writeAsString(contents);
  return file;
}

ChatMessage _message(String uri) => ChatMessage(
  role: 'user',
  conversationId: 'chat',
  parts: [FilePart(uri: uri, name: '报告.txt')],
);

WorkspaceToolContext _context(Directory root, String id) {
  final session = Directory('${root.path}/sessions/$id');
  return WorkspaceToolContext(
    workspace: Workspace(
      id: 'ws',
      name: 'Work',
      kind: WorkspaceKind.managed,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    ),
    binding: const WorkspaceBinding(workspaceId: 'ws'),
    paths: WorkspacePaths.sandboxed(
      workspaceHostRoot: '${root.path}/workspaces/ws/files',
      sessionHostDir: session.path,
      skillsHostDir: '${root.path}/skills',
    ),
    sessionDir: session,
    outputsDir: Directory('${session.path}/outputs'),
    conversationId: id,
  );
}

class _PausedCopy implements File {
  _PausedCopy(this.file, this.copied, this.finish);
  final File file;
  final Completer<void> copied;
  final Completer<void> finish;
  @override
  Future<FileStat> stat() => file.stat();
  @override
  Future<File> copy(String path) async {
    final result = await file.copy(path);
    copied.complete();
    await finish.future;
    return result;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _GuardedDirectory implements Directory {
  _GuardedDirectory(this.dir, this.root, this.visited, this.wrap);
  final Directory dir;
  final String root;
  final List<String> visited;
  final Directory Function(Directory) wrap;
  @override
  String get path => dir.path;
  @override
  Directory get absolute => wrap(dir.absolute);
  @override
  Future<bool> exists() => dir.exists();
  @override
  Future<Directory> create({bool recursive = false}) async =>
      dir.create(recursive: recursive);
  @override
  Stream<FileSystemEntity> list({
    bool recursive = false,
    bool followLinks = true,
  }) {
    visited.add(path);
    if (recursive || path == '$root/blocked' || path == '$root/environment') {
      return Stream.error(FileSystemException('unreadable', path));
    }
    return dir
        .list(followLinks: followLinks)
        .map((e) => e is Directory ? wrap(e) : e);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
