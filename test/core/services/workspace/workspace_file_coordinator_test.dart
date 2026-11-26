import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:Kelivo/core/services/api/tool_call_cancellation.dart';
import 'package:Kelivo/core/services/workspace/workspace_file_coordinator.dart';

void main() {
  late Directory temp;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('kelivo_file_coordination_');
  });
  tearDown(() => temp.delete(recursive: true));

  for (final directoryFirst in [true, false]) {
    test('overlapping scopes wait, directory first: $directoryFirst', () async {
      final root = p.join(temp.path, 'workspace');
      final file = p.join(root, 'nested', 'new.txt');
      final started = Completer<void>();
      final release = Completer<void>();
      final first = WorkspaceFileCoordinator.run(
        directoryFirst ? root : file,
        () async {
          started.complete();
          await release.future;
        },
      );
      await started.future;
      var secondStarted = false;
      final second = WorkspaceFileCoordinator.run(
        directoryFirst ? file : root,
        () async => secondStarted = true,
      );
      try {
        await WorkspaceFileCoordinator.run(
          p.join(temp.path, 'workspace-other'),
          () async {},
        ).timeout(const Duration(seconds: 3));
        await Future<void>.delayed(const Duration(milliseconds: 20));
        expect(secondStarted, isFalse);
      } finally {
        release.complete();
        await Future.wait([first, second]);
      }
      expect(secondStarted, isTrue);
    });
  }

  test('symbolic aliases share the same scope', () async {
    if (Platform.isWindows) return;
    final root = await Directory(p.join(temp.path, 'real')).create();
    final alias = await Link(p.join(temp.path, 'alias')).create(root.path);
    final started = Completer<void>();
    final release = Completer<void>();
    final first = WorkspaceFileCoordinator.run(root.path, () async {
      started.complete();
      await release.future;
    });
    await started.future;
    var secondStarted = false;
    final second = WorkspaceFileCoordinator.run(
      p.join(alias.path, 'missing', 'new.txt'),
      () async => secondStarted = true,
    );
    try {
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(secondStarted, isFalse);
    } finally {
      release.complete();
      await Future.wait([first, second]);
    }
    expect(secondStarted, isTrue);
  });

  test('cancelled waiter cannot release a running predecessor', () async {
    final root = temp.path;
    final entered = Completer<void>();
    final release = Completer<void>();
    final first = WorkspaceFileCoordinator.run(root, () async {
      entered.complete();
      await release.future;
    });
    await entered.future;
    final cancelled = Completer<void>();
    final cancellation = ToolCallCancellation(
      isCancelled: () => cancelled.isCompleted,
      cancelled: cancelled.future,
    );
    var cancelledStarted = false;
    final second = cancellation.run(
      () => WorkspaceFileCoordinator.run(
        root,
        () async => cancelledStarted = true,
      ),
    );
    final secondCheck = expectLater(second, throwsA(isA<StateError>()));
    try {
      await Future.doWhile(() async {
        await Future<void>.delayed(const Duration(milliseconds: 1));
        return cancellation.listenerCount == 0;
      }).timeout(const Duration(seconds: 3));
      cancelled.complete();
      await secondCheck.timeout(const Duration(seconds: 3));
      expect(cancelledStarted, isFalse);
      expect(cancellation.listenerCount, 0);
      var thirdStarted = false;
      final third = WorkspaceFileCoordinator.run(
        p.join(root, 'new.txt'),
        () async => thirdStarted = true,
      );
      try {
        await Future<void>.delayed(const Duration(milliseconds: 20));
        expect(thirdStarted, isFalse);
      } finally {
        release.complete();
        await Future.wait([first, third]);
      }
      expect(thirdStarted, isTrue);
    } finally {
      if (!release.isCompleted) release.complete();
      if (!cancelled.isCompleted) cancelled.complete();
      await first;
      await secondCheck;
    }
  });

  test('multiple scopes acquire together and release after failure', () async {
    final workspace = p.join(temp.path, 'workspace');
    final session = p.join(temp.path, 'session');
    final started = Completer<void>();
    final release = Completer<void>();
    final first = WorkspaceFileCoordinator.runAll(
      [workspace, session],
      () async {
        started.complete();
        await release.future;
        throw StateError('command failed');
      },
    );
    final firstCheck = expectLater(first, throwsStateError);
    await started.future;
    var secondStarted = false;
    final second = WorkspaceFileCoordinator.runAll(
      [session, workspace],
      () async {
        secondStarted = true;
      },
    );
    try {
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(secondStarted, isFalse);
    } finally {
      release.complete();
      await firstCheck;
      await second.timeout(const Duration(seconds: 3));
    }
    expect(secondStarted, isTrue);
  });

  test('timed-out wait never runs later or releases its predecessor', () async {
    final started = Completer<void>();
    final release = Completer<void>();
    final first = WorkspaceFileCoordinator.run(temp.path, () async {
      started.complete();
      await release.future;
    });
    await started.future;
    var timedOutStarted = false;
    try {
      await expectLater(
        WorkspaceFileCoordinator.run(
          temp.path,
          () async => timedOutStarted = true,
          waitTimeout: const Duration(milliseconds: 20),
        ),
        throwsA(isA<TimeoutException>()),
      );
      var thirdStarted = false;
      final third = WorkspaceFileCoordinator.run(
        p.join(temp.path, 'new.txt'),
        () async => thirdStarted = true,
      );
      try {
        await Future<void>.delayed(const Duration(milliseconds: 20));
        expect(thirdStarted, isFalse);
      } finally {
        release.complete();
        await Future.wait([first, third]);
      }
      expect(timedOutStarted, isFalse);
      expect(thirdStarted, isTrue);
    } finally {
      if (!release.isCompleted) release.complete();
      await first;
    }
  });
}
