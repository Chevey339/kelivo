import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:Kelivo/core/services/backup/restore_trace_service.dart';
import 'package:Kelivo/core/services/backup/restore_workspace_lock.dart';

void main() {
  late Directory root;
  late Directory completedRun;
  const runId = '0123456789abcdef0123456789abcdef';

  setUp(() async {
    root = await Directory.systemTemp.createTemp('kelivo_restore_traces_');
    completedRun = Directory(
      p.join(
        root.path,
        RestoreWorkspaceLock.workspaceRootName,
        RestoreWorkspaceLock.completedRunsDirectoryName,
        'run_$runId',
      ),
    );
    await completedRun.create(recursive: true);
    await File(
      p.join(completedRun.path, 'database.sqlite'),
    ).writeAsString('data');
    final previous = Directory(p.join(completedRun.path, 'previous'));
    await previous.create();
    await File(p.join(previous.path, 'settings.json')).writeAsString('old');
  });

  tearDown(() async {
    if (await root.exists()) await root.delete(recursive: true);
  });

  test('counts and clears only completed restore archives', () async {
    final service = RestoreTraceService(root);

    final before = await service.inspect();
    expect(before.visible, isTrue);
    expect(before.fileCount, 2);
    expect(before.bytes, 7);

    await service.clear();

    expect(await completedRun.exists(), isFalse);
    expect((await service.inspect()).visible, isFalse);
  });

  test(
    'clears local special entries without following archived links',
    () async {
      if (Platform.isWindows) return;
      final external = Directory(p.join(root.path, 'external'));
      await external.create();
      final outside = File(p.join(external.path, 'file'));
      await outside.writeAsString('keep me');
      final previous = Directory(
        p.join(completedRun.path, 'previous', 'workspaces'),
      );
      await previous.create();
      final targets = [outside.path, external.path, 'missing'];
      for (var index = 0; index < targets.length; index++) {
        await Link(p.join(previous.path, 'link$index')).create(targets[index]);
      }
      expect(
        (await Process.run('mkfifo', [p.join(previous.path, 'pipe')])).exitCode,
        0,
      );
      final socketRoot = await Directory.systemTemp.createTemp('ks_');
      final socketPath = p.join(socketRoot.path, 's');
      final socket = await ServerSocket.bind(
        InternetAddress(socketPath, type: InternetAddressType.unix),
        0,
      );
      addTearDown(() async {
        await socket.close();
        await socketRoot.delete(recursive: true);
      });
      await File(socketPath).rename(p.join(previous.path, 'socket'));

      final service = RestoreTraceService(root);
      final before = await service.inspect();
      expect(before.fileCount, 7);
      expect(
        before.bytes,
        7 +
            targets.fold<int>(
              0,
              (sum, target) => sum + utf8.encode(target).length,
            ),
      );
      await service.clear();
      expect(await completedRun.exists(), isFalse);
      expect(await external.exists(), isTrue);
      expect(await outside.readAsString(), 'keep me');
      expect((await service.inspect()).visible, isFalse);
    },
  );

  test('hides and refuses cleanup while a restore run is active', () async {
    final workspace = Directory(
      p.join(root.path, RestoreWorkspaceLock.workspaceRootName),
    );
    await File(
      p.join(workspace.path, RestoreWorkspaceLock.activeRunFileName),
    ).writeAsString(runId);
    final service = RestoreTraceService(root);

    expect((await service.inspect()).visible, isFalse);
    await expectLater(service.clear(), throwsA(isA<StateError>()));
    expect(await completedRun.exists(), isTrue);
  });
}
