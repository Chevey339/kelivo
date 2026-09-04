import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:Kelivo/core/services/workspace/workspace_paths.dart';
import 'package:Kelivo/core/services/workspace/workspace_runtime.dart';

void main() {
  late Directory tmp;
  late Directory workspace;
  late Directory session;
  late Directory skills;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('kelivo_ws_paths_');
    workspace = Directory(p.join(tmp.path, 'ws'))..createSync();
    session = Directory(p.join(tmp.path, 'session'))..createSync();
    skills = Directory(p.join(tmp.path, 'skills'))..createSync();
  });

  tearDown(() async {
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  group('sandboxed', () {
    late WorkspacePaths paths;

    setUp(() {
      paths = WorkspacePaths.sandboxed(
        workspaceHostRoot: workspace.path,
        sessionHostDir: session.path,
        skillsHostDir: skills.path,
      );
    });

    test('maps guest prefixes and relative paths', () {
      expect(paths.sandboxed, isTrue);
      expect(paths.modelRoot, '/workspace');
      expect(paths.modelSessionDir, '/chat');
      expect(paths.modelSkillsDir, '/skills');
      expect(paths.mounts, [
        Mount(host: p.canonicalize(workspace.path), guest: '/workspace'),
        Mount(host: p.canonicalize(session.path), guest: '/chat'),
        Mount(host: p.canonicalize(skills.path), guest: '/skills'),
      ]);

      final file = paths.resolve('src/main.dart', cwd: '/workspace');
      expect(file.zone, WorkspaceZone.workspace);
      expect(file.modelPath, '/workspace/src/main.dart');
      expect(
        file.hostPath,
        p.canonicalize(p.join(workspace.path, 'src', 'main.dart')),
      );

      final chat = paths.resolve('/chat/outputs/x.txt', cwd: '/workspace');
      expect(chat.zone, WorkspaceZone.chat);
      expect(
        chat.hostPath,
        p.canonicalize(p.join(session.path, 'outputs', 'x.txt')),
      );

      final skill = paths.resolve('/skills/foo', cwd: '/workspace');
      expect(skill.zone, WorkspaceZone.skills);
      expect(skill.modelPath, '/skills/foo');

      final tmpPath = paths.resolve('/tmp/scratch', cwd: '/workspace');
      expect(tmpPath.zone, WorkspaceZone.tmp);
      expect(WorkspacePaths.isWritableZone(tmpPath.zone), isTrue);
      expect(WorkspacePaths.isWritableZone(WorkspaceZone.skills), isFalse);

      expect(
        paths.toModelPath(p.join(workspace.path, 'src', 'main.dart')),
        '/workspace/src/main.dart',
      );
    });

    test('rejects NUL and zone-escaping ..', () {
      expect(
        () => paths.resolve('/workspace/foo\u0000', cwd: '/workspace'),
        throwsA(isA<PathResolutionException>()),
      );
      expect(
        () => paths.resolve('/workspace/../etc/passwd', cwd: '/workspace'),
        throwsA(isA<PathResolutionException>()),
      );
      expect(
        () => paths.resolve('../../etc/passwd', cwd: '/workspace'),
        throwsA(isA<PathResolutionException>()),
      );
    });

    test('normalizeCwd defaults to modelRoot and stays in-zone', () {
      expect(paths.normalizeCwd(null), '/workspace');
      expect(paths.normalizeCwd(''), '/workspace');
      expect(paths.normalizeCwd('/chat/attachments'), '/chat/attachments');
      expect(paths.normalizeCwd('/workspace/../etc'), '/workspace');
    });

    test('rejects .. that crosses from workspace into tmp', () {
      expect(
        () => paths.resolve('/workspace/../tmp/x', cwd: '/workspace'),
        throwsA(isA<PathResolutionException>()),
      );
    });

    test('allows .. that stays inside the workspace zone', () {
      final resolved = paths.resolve('/workspace/a/../b', cwd: '/workspace');
      expect(resolved.zone, WorkspaceZone.workspace);
      expect(resolved.modelPath, '/workspace/b');
      expect(resolved.hostPath, p.canonicalize(p.join(workspace.path, 'b')));
    });

    test('absolute tmp prefix without .. resolves to tmp', () {
      final resolved = paths.resolve('/tmp/x', cwd: '/workspace');
      expect(resolved.zone, WorkspaceZone.tmp);
      expect(resolved.modelPath, '/tmp/x');
      expect(resolved.hostPath, p.canonicalize(p.join(paths.tmpHostRoot, 'x')));
    });
  });

  group('native', () {
    late WorkspacePaths paths;

    setUp(() {
      paths = WorkspacePaths.native(
        workspaceHostRoot: workspace.path,
        sessionHostDir: session.path,
        skillsHostDir: skills.path,
      );
    });

    test('uses real host paths and classifies zones', () {
      expect(paths.sandboxed, isFalse);
      expect(paths.modelRoot, p.canonicalize(workspace.path));
      expect(paths.mounts, isEmpty);

      final inside = paths.resolve('lib/a.dart', cwd: workspace.path);
      expect(inside.zone, WorkspaceZone.workspace);
      expect(
        inside.hostPath,
        p.canonicalize(p.join(workspace.path, 'lib', 'a.dart')),
      );
      expect(inside.modelPath, inside.hostPath);

      final chat = paths.resolve(
        p.join(session.path, 'outputs', 'x.txt'),
        cwd: workspace.path,
      );
      expect(chat.zone, WorkspaceZone.chat);

      final skill = paths.resolve(
        p.join(skills.path, 'x'),
        cwd: workspace.path,
      );
      expect(skill.zone, WorkspaceZone.skills);

      final outside = paths.resolve('/etc/passwd', cwd: workspace.path);
      expect(outside.zone, WorkspaceZone.outside);
      expect(WorkspacePaths.isWritableZone(outside.zone), isFalse);
    });

    test('rejects .. that escapes every zone', () {
      final climb = List<String>.filled(24, '..').join('/');
      expect(
        () => paths.resolve('$climb/etc/passwd', cwd: workspace.path),
        throwsA(isA<PathResolutionException>()),
      );
    });

    test('normalizeCwd falls back when the path leaves the zones', () {
      expect(paths.normalizeCwd(null), p.canonicalize(workspace.path));
      expect(
        paths.normalizeCwd(p.join(session.path, 'out')),
        p.canonicalize(p.join(session.path, 'out')),
      );
      final climb = List<String>.filled(24, '..').join('/');
      expect(paths.normalizeCwd('$climb/etc'), p.canonicalize(workspace.path));
    });

    test('rejects .. that leaves workspace even when landing in tmp', () {
      expect(paths.tmpHostRoot, p.canonicalize(Directory.systemTemp.path));
      expect(
        p.isWithin(paths.tmpHostRoot, paths.workspaceHostRoot) ||
            p.equals(paths.tmpHostRoot, paths.workspaceHostRoot),
        isTrue,
      );
      expect(
        () => paths.resolve('../x.txt', cwd: workspace.path),
        throwsA(isA<PathResolutionException>()),
      );
    });

    test('allows .. that stays inside the workspace zone', () {
      final resolved = paths.resolve('sub/../file.txt', cwd: workspace.path);
      expect(resolved.zone, WorkspaceZone.workspace);
      expect(
        resolved.hostPath,
        p.canonicalize(p.join(workspace.path, 'file.txt')),
      );
    });

    test('absolute tmp-zone path without .. resolves to tmp', () {
      final tmpFile = p.join(tmp.path, 'scratch.txt');
      final resolved = paths.resolve(tmpFile, cwd: workspace.path);
      expect(resolved.zone, WorkspaceZone.tmp);
      expect(resolved.hostPath, p.canonicalize(tmpFile));
    });
  });

  test(
    'resolveReal reclassifies a symlink that escapes the workspace',
    () async {
      // /tmp (≠ Directory.systemTemp on macOS) is outside the zone roots.
      final outsideDir = Directory('/tmp');
      final outsideFile = File(
        p.join(outsideDir.path, 'kelivo_ws_secret_${tmp.path.hashCode}.txt'),
      );
      await outsideFile.writeAsString('secret');
      addTearDown(() async {
        if (await outsideFile.exists()) await outsideFile.delete();
      });

      final link = Link(p.join(workspace.path, 'escape'));
      await link.create(outsideFile.path);

      final paths = WorkspacePaths.native(
        workspaceHostRoot: workspace.path,
        sessionHostDir: session.path,
        skillsHostDir: skills.path,
      );

      final lexical = paths.resolve('escape', cwd: workspace.path);
      expect(lexical.zone, WorkspaceZone.workspace);

      final real = await paths.resolveReal('escape', cwd: workspace.path);
      expect(real.zone, WorkspaceZone.outside);
      expect(
        p.canonicalize(real.hostPath),
        p.canonicalize(await outsideFile.resolveSymbolicLinks()),
      );

      // Same escape through the sandboxed guest path.
      final sandboxed = WorkspacePaths.sandboxed(
        workspaceHostRoot: workspace.path,
        sessionHostDir: session.path,
        skillsHostDir: skills.path,
      );
      final sandboxedLexical = sandboxed.resolve(
        '/workspace/escape',
        cwd: '/workspace',
      );
      expect(sandboxedLexical.zone, WorkspaceZone.workspace);
      final sandboxedReal = await sandboxed.resolveReal(
        '/workspace/escape',
        cwd: '/workspace',
      );
      expect(sandboxedReal.zone, WorkspaceZone.outside);
    },
  );
}
