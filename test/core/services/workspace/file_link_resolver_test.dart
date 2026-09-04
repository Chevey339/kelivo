import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import 'package:Kelivo/core/database/app_database.dart';
import 'package:Kelivo/core/database/extension_entity_store.dart';
import 'package:Kelivo/core/models/workspace.dart';
import 'package:Kelivo/core/models/workspace_binding.dart';
import 'package:Kelivo/core/providers/workspace_provider.dart';
import 'package:Kelivo/core/services/workspace/file_link_resolver.dart';
import 'package:Kelivo/core/services/workspace/workspace_paths.dart';
import 'package:Kelivo/core/services/workspace/workspace_runtime.dart';
import 'package:Kelivo/core/services/workspace/workspace_tools_service.dart';

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

  group('KelivoLink.tryParse', () {
    test('parses workspace, chat, skill, and terminal kinds', () {
      final workspace = KelivoLink.tryParse(
        'kelivo://workspace/docs/readme.md',
      );
      expect(workspace?.kind, KelivoLinkKind.workspaceFile);
      expect(workspace?.relativePath, 'docs/readme.md');

      final attachment = KelivoLink.tryParse(
        'kelivo://chat/attachments/photo.png',
      );
      expect(attachment?.kind, KelivoLinkKind.chatAttachment);
      expect(attachment?.relativePath, 'photo.png');

      final output = KelivoLink.tryParse('kelivo://chat/outputs/result.json');
      expect(output?.kind, KelivoLinkKind.chatOutput);
      expect(output?.relativePath, 'result.json');

      final skill = KelivoLink.tryParse('kelivo://skills/weather/SKILL.md');
      expect(skill?.kind, KelivoLinkKind.skillFile);
      expect(skill?.relativePath, 'weather/SKILL.md');

      final terminal = KelivoLink.tryParse('kelivo://terminal?cmd=ls%20-la');
      expect(terminal?.kind, KelivoLinkKind.terminal);
      expect(terminal?.terminalCommand, 'ls -la');
      expect(terminal?.relativePath, '');
    });

    test('accepts underscores in workspace paths', () {
      final link = KelivoLink.tryParse(
        'kelivo://workspace/shenyu/daily_sign.py',
      );
      expect(link?.kind, KelivoLinkKind.workspaceFile);
      expect(link?.relativePath, 'shenyu/daily_sign.py');
    });

    test('percent-decodes path segments', () {
      final link = KelivoLink.tryParse('kelivo://workspace/hello%20world.txt');
      expect(link?.kind, KelivoLinkKind.workspaceFile);
      expect(link?.relativePath, 'hello world.txt');
    });

    test('accepts raw UTF-8 and encoded Chinese workspace names', () {
      final raw = KelivoLink.tryParse('kelivo://workspace/员工表.csv');
      expect(raw?.kind, KelivoLinkKind.workspaceFile);
      expect(raw?.relativePath, '员工表.csv');

      final encoded = KelivoLink.tryParse(
        'kelivo://workspace/${Uri.encodeComponent('员工表.csv')}',
      );
      expect(encoded?.kind, KelivoLinkKind.workspaceFile);
      expect(encoded?.relativePath, '员工表.csv');
    });

    test('decodes encoded directory segments', () {
      final link = KelivoLink.tryParse(
        'kelivo://workspace/sub%20dir/a%20b.txt',
      );
      expect(link?.kind, KelivoLinkKind.workspaceFile);
      expect(link?.relativePath, 'sub dir/a b.txt');
    });

    test('parses kelivo://chat/<id>/Chinese filename as chat output', () {
      const conversationId = 'conv-中文';
      final link = KelivoLink.tryParse('kelivo://chat/$conversationId/输出.png');
      expect(link?.kind, KelivoLinkKind.chatOutput);
      expect(link?.conversationId, conversationId);
      expect(link?.relativePath, '输出.png');
    });

    test('rejects .. segments and encoded traversal', () {
      expect(KelivoLink.tryParse('kelivo://workspace/../secret'), isNull);
      expect(
        KelivoLink.tryParse('kelivo://workspace/foo/../../etc/passwd'),
        isNull,
      );
      expect(KelivoLink.tryParse('kelivo://workspace/%2e%2e/secret'), isNull);
      expect(KelivoLink.tryParse('kelivo://workspace/%2e%2e%2fsecret'), isNull);
      expect(KelivoLink.tryParse('kelivo://chat/attachments/../x'), isNull);
      expect(KelivoLink.tryParse('kelivo://skills/foo/../bar'), isNull);
    });

    test('rejects absolute-host and drive paths', () {
      expect(KelivoLink.tryParse('kelivo://workspace//etc/passwd'), isNull);
      expect(
        KelivoLink.tryParse('kelivo://workspace/C:/Windows/win.ini'),
        isNull,
      );
      expect(KelivoLink.tryParse('kelivo:///workspace/foo'), isNull);
    });

    test('rejects unknown hosts and incomplete chat/skill paths', () {
      expect(KelivoLink.tryParse('kelivo://other/foo'), isNull);
      expect(KelivoLink.tryParse('kelivo://chat/attachments'), isNull);
      expect(KelivoLink.tryParse('kelivo://skills/only-id'), isNull);
      expect(KelivoLink.tryParse('https://example.com'), isNull);
      expect(KelivoLink.tryParse(''), isNull);
    });
  });

  group('FileLinkResolver.resolveToHostFile', () {
    late Directory tempDir;
    late Directory workspaceRoot;
    late Directory appData;
    late AppDatabase database;
    late WorkspaceProvider workspaces;
    late FileLinkResolver resolver;
    late Workspace workspace;
    late PathProviderPlatform previousPathProvider;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('kelivo_file_link_');
      workspaceRoot = Directory(p.join(tempDir.path, 'ws'));
      appData = Directory(p.join(tempDir.path, 'app'));
      await workspaceRoot.create(recursive: true);
      await appData.create(recursive: true);

      previousPathProvider = PathProviderPlatform.instance;
      PathProviderPlatform.instance = _FakePathProviderPlatform(appData.path);

      database = AppDatabase(NativeDatabase.memory());
      await database.customSelect('SELECT 1;').getSingle();
      workspaces = WorkspaceProvider(store: ExtensionEntityStore(database));
      await workspaces.loaded;
      workspace = await workspaces.create(
        name: 'tmp',
        kind: WorkspaceKind.linked,
        hostPath: workspaceRoot.path,
      );
      resolver = FileLinkResolver(workspaces: workspaces);
    });

    tearDown(() async {
      PathProviderPlatform.instance = previousPathProvider;
      await database.close();
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    WorkspaceBinding binding() => WorkspaceBinding(workspaceId: workspace.id);

    test('resolves a workspace file under the host root', () async {
      final file = File(p.join(workspaceRoot.path, 'foo.txt'));
      await file.writeAsString('hello');

      final link = KelivoLink.tryParse('kelivo://workspace/foo.txt');
      expect(link, isNotNull);
      final resolved = await resolver.resolveToHostFile(
        link!,
        conversationId: 'conv-1',
        binding: binding(),
      );
      expect(resolved?.path, file.path);
    });

    test('returns null when workspace is unbound', () async {
      final file = File(p.join(workspaceRoot.path, 'foo.txt'));
      await file.writeAsString('hello');
      final link = KelivoLink.tryParse('kelivo://workspace/foo.txt')!;
      final resolved = await resolver.resolveToHostFile(
        link,
        conversationId: 'conv-1',
        binding: const WorkspaceBinding(),
      );
      expect(resolved, isNull);
    });

    test(
      'rejects constructed escape paths even if parse was bypassed',
      () async {
        final secret = File(p.join(tempDir.path, 'secret.txt'));
        await secret.writeAsString('nope');
        final link = KelivoLink(
          kind: KelivoLinkKind.workspaceFile,
          relativePath: '../secret.txt',
        );
        final resolved = await resolver.resolveToHostFile(
          link,
          conversationId: 'conv-1',
          binding: binding(),
        );
        expect(resolved, isNull);
      },
    );

    test('returns null for a missing workspace file', () async {
      final link = KelivoLink.tryParse('kelivo://workspace/missing.txt')!;
      final resolved = await resolver.resolveToHostFile(
        link,
        conversationId: 'conv-1',
        binding: binding(),
      );
      expect(resolved, isNull);
    });

    test(
      'resolves chat attachments and outputs under the session root',
      () async {
        const conversationId = 'conv-42';
        final attach = File(
          p.join(
            appData.path,
            'sessions',
            conversationId,
            'attachments',
            'a.txt',
          ),
        );
        final output = File(
          p.join(appData.path, 'sessions', conversationId, 'outputs', 'b.txt'),
        );
        await attach.parent.create(recursive: true);
        await output.parent.create(recursive: true);
        await attach.writeAsString('attach');
        await output.writeAsString('out');

        final attachResolved = await resolver.resolveToHostFile(
          KelivoLink.tryParse('kelivo://chat/attachments/a.txt')!,
          conversationId: conversationId,
          binding: const WorkspaceBinding(),
        );
        final outputResolved = await resolver.resolveToHostFile(
          KelivoLink.tryParse('kelivo://chat/outputs/b.txt')!,
          conversationId: conversationId,
          binding: const WorkspaceBinding(),
        );
        expect(attachResolved?.path, attach.path);
        expect(outputResolved?.path, output.path);
      },
    );

    test('resolves skill files and rejects skill escapes', () async {
      final skillFile = File(
        p.join(appData.path, 'skills', 'weather', 'SKILL.md'),
      );
      await skillFile.parent.create(recursive: true);
      await skillFile.writeAsString('# skill');

      final resolved = await resolver.resolveToHostFile(
        KelivoLink.tryParse('kelivo://skills/weather/SKILL.md')!,
        conversationId: 'conv-1',
        binding: const WorkspaceBinding(),
      );
      expect(resolved?.path, skillFile.path);

      final escaped = await resolver.resolveToHostFile(
        const KelivoLink(
          kind: KelivoLinkKind.skillFile,
          relativePath: 'weather/../secret.md',
        ),
        conversationId: 'conv-1',
        binding: const WorkspaceBinding(),
      );
      expect(escaped, isNull);
    });

    test(
      'linkFor Chinese filename round-trips to an existing temp file',
      () async {
        final file = File(p.join(workspaceRoot.path, '员工表.csv'));
        await file.writeAsString('name,role\n');
        final paths = WorkspacePaths.sandboxed(
          workspaceHostRoot: workspaceRoot.path,
          sessionHostDir: p.join(appData.path, 'sessions', 'conv-1'),
          skillsHostDir: p.join(appData.path, 'skills'),
        );
        final href = WorkspaceToolsService.linkFor(
          ResolvedPath(
            hostPath: file.path,
            modelPath: '/workspace/员工表.csv',
            zone: WorkspaceZone.workspace,
          ),
          paths: paths,
        );
        expect(href, isNotNull);
        expect(href, contains(Uri.encodeComponent('员工表.csv')));
        expect(href, isNot(contains('员工表')));

        final parsed = KelivoLink.tryParse(href!);
        expect(parsed?.kind, KelivoLinkKind.workspaceFile);
        expect(parsed?.relativePath, '员工表.csv');
        final resolved = await resolver.resolveToHostFile(
          parsed!,
          conversationId: 'conv-1',
          binding: binding(),
        );
        expect(resolved?.path, file.path);
      },
    );

    test('resolves encoded chat output with Chinese name', () async {
      const conversationId = 'conv-42';
      final output = File(
        p.join(appData.path, 'sessions', conversationId, 'outputs', '输出.png'),
      );
      await output.parent.create(recursive: true);
      await output.writeAsString('png');
      final parsed = KelivoLink.tryParse(
        'kelivo://chat/$conversationId/${Uri.encodeComponent('输出.png')}',
      );
      expect(parsed, isNotNull);
      final resolved = await resolver.resolveToHostFile(
        parsed!,
        conversationId: 'other-conv',
        binding: const WorkspaceBinding(),
      );
      expect(resolved?.path, output.path);
    });

    test('terminal links do not resolve to a file', () async {
      final resolved = await resolver.resolveToHostFile(
        KelivoLink.tryParse('kelivo://terminal?cmd=pwd')!,
        conversationId: 'conv-1',
        binding: binding(),
      );
      expect(resolved, isNull);
    });
  });
}
