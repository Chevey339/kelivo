import 'dart:io';

import 'package:Kelivo/core/services/backup/backup_secure_password_store.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'Mac login authorization errors are distinguishable from a missing credential',
    () async {
      const channel = MethodChannel('kelivo/backup_keychain');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'read') return null;
        throw PlatformException(code: 'backup_keychain_auth', details: -25293);
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      const store = BackupSecurePasswordStore(namespace: 'fixture');
      expect(await store.read(), isNull);
      await expectLater(
        store.remember('fixture'),
        throwsA(
          isA<BackupMacKeychainAccessError>().having(
            (e) => e.reason,
            'reason',
            MacBackupAuthorization.denied,
          ),
        ),
      );
    },
    skip: !Platform.isMacOS,
  );

  test(
    'Mac keychain supports process restart, rotation, removal and silent locked reads',
    () async {
      final dir = await Directory.systemTemp.createTemp('kelivo-keychain-');
      addTearDown(() => dir.delete(recursive: true));
      final executable = '${dir.path}/verify';
      final path = '${dir.path}/fixture.keychain';
      final compiler = await Process.run('xcrun', [
        'swiftc',
        'macos/Runner/BackupPasswordKeychain.swift',
        'test/native/backup_password_keychain_test.swift',
        '-o',
        executable,
      ]);
      expect(compiler.exitCode, 0, reason: compiler.stderr.toString());
      Future<void> phase(String name) async {
        final result = await Process.run(executable, [name, path]);
        expect(result.exitCode, 0, reason: '$name: ${result.stderr}');
      }

      try {
        await phase('create');
        await phase('reopen');
        await phase('locked');
      } finally {
        if (await File(path).exists() || await File('$path-db').exists()) {
          await phase('dispose');
        }
      }
    },
    skip: !Platform.isMacOS,
  );
  group('Managed Mac backup keychain', () {
    late Directory binaries;
    late String executable;
    late Directory data;
    late bool hasHardware;
    Future<void> phase(String name) async {
      final result = await Process.run(executable, [name, data.path]);
      expect(
        result.exitCode,
        0,
        reason: '$name: ${result.stdout} ${result.stderr}',
      );
    }

    setUpAll(() async {
      binaries = await Directory.systemTemp.createTemp(
        'kelivo-managed-keychain-bin-',
      );
      executable = '${binaries.path}/verify';
      final result = await Process.run('xcrun', [
        'swiftc',
        'macos/Runner/BackupPasswordKeychain.swift',
        'macos/Runner/MacBackupPasswordStore.swift',
        'test/native/mac_managed_backup_keychain_test.swift',
        '-o',
        executable,
      ]);
      expect(result.exitCode, 0, reason: result.stderr.toString());
      final check = await Process.run(executable, ['capability']);
      expect(check.exitCode, 0);
      hasHardware = check.stdout.toString().trim() == 'supported';
    });
    tearDownAll(() => binaries.delete(recursive: true));
    setUp(() async {
      data = await Directory.systemTemp.createTemp(
        'kelivo-managed-keychain-data-',
      );
    });
    tearDown(() async {
      try {
        await phase('cleanup');
      } finally {
        await data.delete(recursive: true);
      }
    });
    test(
      'legacy read and rotation, and new consent on Macs without device hardware',
      () async {
        await phase('create-login');
      },
    );
    test(
      'one consent survives cold starts and concurrent reads with a broken login keychain',
      () async {
        if (!hasHardware) {
          markTestSkipped('Secure Enclave unavailable');
          return;
        }
        await phase('enroll');
        await phase('check-locked');
        await Future.wait([phase('cold-read'), phase('cold-read')]);
        await phase('check-locked');
        await phase('rotate');
        await phase('revoke');
      },
    );
    test(
      'a revoked private route can enroll on a Mac without usable hardware',
      () async {
        if (!hasHardware) {
          markTestSkipped('Secure Enclave unavailable');
          return;
        }
        await phase('create-login');
        await phase('enroll');
        await phase('rotate');
        await phase('revoke');
        await phase('fallback-from-retired');
      },
    );
    test(
      'an old pending revocation cannot block new enrollment or leave the private password behind',
      () async {
        if (!hasHardware) {
          markTestSkipped('Secure Enclave unavailable');
          return;
        }
        await phase('create-login');
        await phase('pending-enroll');
        await phase('revoke-pending');
      },
    );
  }, skip: !Platform.isMacOS);
}
