import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:Kelivo/core/services/backup/restore_business_lease.dart';
import 'package:Kelivo/core/services/backup/restore_durability.dart';

final class _FailingOwnerDurability implements RestoreDurability {
  _FailingOwnerDurability(this.delegate);

  final RestoreDurability delegate;

  @override
  Future<void> renameAndSync({
    required FileSystemEntity source,
    required String targetPath,
  }) => delegate.renameAndSync(source: source, targetPath: targetPath);

  @override
  Future<void> restrictDirectory(Directory directory) =>
      delegate.restrictDirectory(directory);

  @override
  Future<void> restrictFile(File file) {
    if (p.basename(file.path).startsWith('owner_')) {
      throw FileSystemException('injected_owner_restrict', file.path);
    }
    return delegate.restrictFile(file);
  }

  @override
  Future<void> syncDirectory(Directory directory, {bool fullBarrier = false}) =>
      delegate.syncDirectory(directory, fullBarrier: fullBarrier);

  @override
  Future<void> syncFile(File file, {bool fullBarrier = false}) =>
      delegate.syncFile(file, fullBarrier: fullBarrier);
}

void main() {
  group('RestoreBusinessLease', () {
    late Directory root;
    late Directory appData;

    setUp(() async {
      root = await Directory.systemTemp.createTemp(
        'kelivo_restore_business_lease_test_',
      );
      appData = Directory(p.join(root.path, 'app_data'));
    });

    tearDown(() async {
      if (await root.exists()) await root.delete(recursive: true);
    });

    test(
      'rejects a duplicate process-local acquire and allows reacquire',
      () async {
        final first = await RestoreBusinessLease.acquire(
          appDataDirectory: appData,
        );
        addTearDown(first.close);

        await expectLater(
          RestoreBusinessLease.acquire(appDataDirectory: appData),
          throwsA(isA<RestoreBusinessLeaseUnavailable>()),
        );
        expect(first.isClosed, isFalse);
        expect(first.instanceId, matches(RegExp(r'^[a-f0-9]{32}$')));
        expect(first.processId, pid);

        final leaseDirectory = Directory(
          p.join(appData.path, RestoreBusinessLease.leaseDirectoryName),
        );
        expect(
          await FileSystemEntity.type(leaseDirectory.path, followLinks: false),
          FileSystemEntityType.directory,
        );
        expect(
          await FileSystemEntity.type(first.lockFile.path, followLinks: false),
          FileSystemEntityType.file,
        );
        final ownerFiles = await leaseDirectory
            .list(followLinks: false)
            .where((entry) => p.basename(entry.path).startsWith('owner_'))
            .toList();
        expect(ownerFiles, hasLength(1));
        final ownerIdentity =
            jsonDecode(await File(ownerFiles.single.path).readAsString())
                as Map<String, dynamic>;
        expect(ownerIdentity['instanceId'], first.instanceId);
        expect(ownerIdentity['probePort'], isA<int>());
        if (!Platform.isWindows) {
          expect((await leaseDirectory.stat()).mode & 0x1ff, 0x1c0);
          expect((await first.lockFile.stat()).mode & 0x1ff, 0x180);
        }

        await first.close();
        expect(first.isClosed, isTrue);
        await first.close();

        final second = await RestoreBusinessLease.acquire(
          appDataDirectory: appData,
        );
        expect(second.instanceId, isNot(first.instanceId));
        expect(second.processId, first.processId);
        await second.close();
      },
    );

    test('fails immediately while another process owns the lease', () async {
      final helper = File(p.join(root.path, 'business_lease_helper.dart'));
      await helper.writeAsString(_helperSource, flush: true);
      final packageConfig = p.join(
        Directory.current.path,
        '.dart_tool',
        'package_config.json',
      );
      final releaseFile = File(p.join(root.path, 'release_helper'));
      final process = await Process.start('dart', [
        '--packages=$packageConfig',
        helper.path,
        appData.path,
        releaseFile.path,
      ], workingDirectory: Directory.current.path);
      addTearDown(() async {
        process.kill();
        await process.stdin.close();
      });
      final errors = StringBuffer();
      final errorSubscription = process.stderr
          .transform(utf8.decoder)
          .listen(errors.write);
      addTearDown(errorSubscription.cancel);
      final ready = await process.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .first
          .timeout(const Duration(seconds: 15));
      expect(ready, 'ready', reason: errors.toString());

      final stopwatch = Stopwatch()..start();
      await expectLater(
        RestoreBusinessLease.acquire(appDataDirectory: appData),
        throwsA(isA<RestoreBusinessLeaseUnavailable>()),
      );
      stopwatch.stop();
      expect(stopwatch.elapsed, lessThan(const Duration(seconds: 2)));

      expect(process.kill(), isTrue);
      await process.exitCode.timeout(const Duration(seconds: 15));

      final lease = await RestoreBusinessLease.acquire(
        appDataDirectory: appData,
      );
      await lease.close();
    });

    test(
      'reclaims an orphaned same-process owner in every build mode',
      () async {
        final leaseDirectory = Directory(
          p.join(appData.path, RestoreBusinessLease.leaseDirectoryName),
        );
        await leaseDirectory.create(recursive: true);
        final staleOwner = File(p.join(leaseDirectory.path, 'owner_$pid'));
        await staleOwner.writeAsString('stale-debug-isolate');

        final lease = await RestoreBusinessLease.acquire(
          appDataDirectory: appData,
        );

        expect(lease.processId, pid);
        final ownerIdentity =
            jsonDecode(await staleOwner.readAsString()) as Map<String, dynamic>;
        expect(ownerIdentity['instanceId'], lease.instanceId);
        await lease.close();
      },
    );

    test('rejects a duplicate acquire from another isolate', () async {
      final lease = await RestoreBusinessLease.acquire(
        appDataDirectory: appData,
      );
      addTearDown(lease.close);
      final appDataPath = appData.path;

      final rejected = await Isolate.run(() async {
        try {
          final duplicate = await RestoreBusinessLease.acquire(
            appDataDirectory: Directory(appDataPath),
          );
          await duplicate.close();
          return false;
        } on RestoreBusinessLeaseUnavailable {
          return true;
        }
      });

      expect(rejected, isTrue);
      expect(lease.isClosed, isFalse);
    });

    test(
      'propagates owner durability failure and removes its marker',
      () async {
        await expectLater(
          RestoreBusinessLease.acquire(
            appDataDirectory: appData,
            durability: _FailingOwnerDurability(RestorePlatformDurability()),
          ),
          throwsA(
            isA<FileSystemException>().having(
              (error) => error.message,
              'message',
              'injected_owner_restrict',
            ),
          ),
        );

        final leaseDirectory = Directory(
          p.join(appData.path, RestoreBusinessLease.leaseDirectoryName),
        );
        expect(
          await leaseDirectory
              .list(followLinks: false)
              .where((entry) => p.basename(entry.path).startsWith('owner_'))
              .toList(),
          isEmpty,
        );
        final lease = await RestoreBusinessLease.acquire(
          appDataDirectory: appData,
        );
        await lease.close();
      },
    );

    test('rejects a directory at the fixed lock-file path', () async {
      final lockPath = p.join(
        appData.path,
        RestoreBusinessLease.leaseDirectoryName,
        RestoreBusinessLease.lockFileName,
      );
      await Directory(lockPath).create(recursive: true);

      await expectLater(
        RestoreBusinessLease.acquire(appDataDirectory: appData),
        throwsA(isA<StateError>()),
      );

      await Directory(lockPath).delete();
      final lease = await RestoreBusinessLease.acquire(
        appDataDirectory: appData,
      );
      await lease.close();
    });

    test(
      'rejects a link at the fixed lock-file path',
      () async {
        final leaseDirectory = Directory(
          p.join(appData.path, RestoreBusinessLease.leaseDirectoryName),
        );
        await leaseDirectory.create(recursive: true);
        final target = File(p.join(root.path, 'target.lock'));
        await target.create();
        await Link(
          p.join(leaseDirectory.path, RestoreBusinessLease.lockFileName),
        ).create(target.path);

        await expectLater(
          RestoreBusinessLease.acquire(appDataDirectory: appData),
          throwsA(isA<StateError>()),
        );
      },
      skip: Platform.isWindows
          ? 'Symlink setup is not portable on Windows.'
          : false,
    );
  });
}

const _helperSource = r'''
import 'dart:io';

import 'package:Kelivo/core/services/backup/restore_business_lease.dart';

Future<void> main(List<String> arguments) async {
  final lease = await RestoreBusinessLease.acquire(
    appDataDirectory: Directory(arguments[0]),
  );
  stdout.writeln('ready');
  await stdout.flush();
  final releaseFile = File(arguments[1]);
  while (!await releaseFile.exists()) {
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  await lease.close();
}
''';
