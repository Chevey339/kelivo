import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:Kelivo/core/services/backup/restore_startup_gate.dart';
import 'package:Kelivo/core/services/backup/restore_workspace_lock.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('RestoreStartupGate.hasPendingWork', () {
    late Directory root;
    late Directory appData;
    late Directory workspace;

    setUp(() async {
      root = await Directory.systemTemp.createTemp('kelivo_pending_work_test_');
      appData = Directory(p.join(root.path, 'app_data'));
      await appData.create();
      workspace = Directory(
        p.join(appData.path, RestoreWorkspaceLock.workspaceRootName),
      );
    });

    tearDown(() async {
      if (await root.exists()) await root.delete(recursive: true);
    });

    test('reports nothing pending without a workspace', () async {
      expect(
        await RestoreStartupGate.hasPendingWork(appDataDirectory: appData),
        isFalse,
      );
    });

    test('reports nothing pending for archived evidence alone', () async {
      await Directory(
        p.join(
          workspace.path,
          RestoreWorkspaceLock.completedRunsDirectoryName,
          'run_0123456789abcdef0123456789abcdef',
        ),
      ).create(recursive: true);
      await File(
        p.join(workspace.path, RestoreWorkspaceLock.lockFileName),
      ).writeAsString('', flush: true);

      expect(
        await RestoreStartupGate.hasPendingWork(appDataDirectory: appData),
        isFalse,
      );
    });

    test('reports pending work for a marker file', () async {
      await workspace.create(recursive: true);
      await File(
        p.join(workspace.path, RestoreWorkspaceLock.activeRunFileName),
      ).writeAsString('0123456789abcdef0123456789abcdef', flush: true);

      expect(
        await RestoreStartupGate.hasPendingWork(appDataDirectory: appData),
        isTrue,
      );
    });

    test('reports pending work for a run directory', () async {
      await Directory(
        p.join(workspace.path, 'run_0123456789abcdef0123456789abcdef'),
      ).create(recursive: true);

      expect(
        await RestoreStartupGate.hasPendingWork(appDataDirectory: appData),
        isTrue,
      );
    });
  });
}
