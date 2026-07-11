import 'dart:io';

import 'package:Kelivo/core/database/app_database.dart';
import 'package:Kelivo/core/database/chat_database_repository.dart';
import 'package:Kelivo/core/database/database_installation_gate.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart' as sqlite;

void main() {
  group('DatabaseInstallationGate', () {
    late Directory directory;

    setUp(() async {
      directory = await Directory.systemTemp.createTemp(
        'kelivo_database_installation_',
      );
    });

    tearDown(() async {
      if (await directory.exists()) await directory.delete(recursive: true);
    });

    File databaseFile(Directory root) =>
        File(p.join(root.path, AppDatabase.databaseFileName));

    test('首次安装创建带 identity 的数据库与 receipt', () async {
      final receipt = await DatabaseInstallationGate.ensureReady(
        appDataDirectory: directory,
      );

      expect(await databaseFile(directory).exists(), isTrue);
      final info = ChatDatabaseRepository.inspectInstalledDatabase(
        databaseFile(directory),
      );
      expect(info.databaseId, receipt.databaseId);
      expect(
        (await DatabaseInstallationGate.read(
          appDataDirectory: directory,
        ))?.installationId,
        receipt.installationId,
      );
    });

    test('identity 一致的重复启动不改 receipt', () async {
      final first = await DatabaseInstallationGate.ensureReady(
        appDataDirectory: directory,
      );
      final second = await DatabaseInstallationGate.ensureReady(
        appDataDirectory: directory,
      );

      expect(second.installationId, first.installationId);
      expect(second.databaseId, first.databaseId);
    });

    test('升级时 adoption 已有有效数据库且不清空数据', () async {
      final repository = ChatDatabaseRepository.open(
        file: databaseFile(directory),
      );
      try {
        await repository.ensureReady();
      } finally {
        await repository.close();
      }
      final before = sqlite.sqlite3.open(databaseFile(directory).path);
      before.execute(
        'INSERT INTO chat_storage_meta_rows (key, value) VALUES (?, ?);',
        ['upgrade_sentinel', 'keep'],
      );
      before.close();

      final receipt = await DatabaseInstallationGate.ensureReady(
        appDataDirectory: directory,
      );

      expect(receipt.databaseId, isNotEmpty);
      expect(
        ChatDatabaseRepository.inspectInstalledDatabase(
          databaseFile(directory),
        ).databaseId,
        receipt.databaseId,
      );
      final after = sqlite.sqlite3.open(
        databaseFile(directory).path,
        mode: sqlite.OpenMode.readOnly,
      );
      try {
        expect(
          after.select(
            'SELECT value FROM chat_storage_meta_rows WHERE key = ?;',
            ['upgrade_sentinel'],
          ).single['value'],
          'keep',
        );
      } finally {
        after.close();
      }
    });

    test('已有 receipt 但数据库缺失时拒绝且不创建空库', () async {
      await DatabaseInstallationGate.ensureReady(appDataDirectory: directory);
      await databaseFile(directory).delete();

      await expectLater(
        DatabaseInstallationGate.ensureReady(appDataDirectory: directory),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            'database_missing',
          ),
        ),
      );
      expect(await databaseFile(directory).exists(), isFalse);
    });

    test('损坏数据库在无 receipt 升级场景也拒绝且不覆盖', () async {
      final file = databaseFile(directory);
      await file.writeAsString('not a sqlite database');

      await expectLater(
        DatabaseInstallationGate.ensureReady(appDataDirectory: directory),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            'database_corrupt',
          ),
        ),
      );
      expect(await file.readAsString(), 'not a sqlite database');
    });

    test('高于当前 schema 的数据库拒绝 down migration', () async {
      final file = databaseFile(directory);
      final raw = sqlite.sqlite3.open(file.path);
      raw.userVersion = AppDatabase.currentSchemaVersion + 1;
      raw.close();

      await expectLater(
        DatabaseInstallationGate.ensureReady(appDataDirectory: directory),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            'database_schema_too_new',
          ),
        ),
      );
    });

    test('损坏 installation receipt 时拒绝打开数据库', () async {
      await DatabaseInstallationGate.ensureReady(appDataDirectory: directory);
      final receipt = directory.listSync().whereType<File>().singleWhere(
        (file) =>
            p.basename(file.path).startsWith('database_installation_receipt_'),
      );
      await receipt.writeAsString('{broken');

      await expectLater(
        DatabaseInstallationGate.ensureReady(appDataDirectory: directory),
        throwsA(isA<FormatException>()),
      );
    });

    test('未授权的数据库 identity 替换被拒绝', () async {
      await DatabaseInstallationGate.ensureReady(appDataDirectory: directory);
      final originalReceipt = await DatabaseInstallationGate.read(
        appDataDirectory: directory,
      );
      final replacementRoot = await Directory.systemTemp.createTemp(
        'kelivo_database_replacement_',
      );
      addTearDown(() async {
        if (await replacementRoot.exists()) {
          await replacementRoot.delete(recursive: true);
        }
      });
      await DatabaseInstallationGate.ensureReady(
        appDataDirectory: replacementRoot,
      );
      await databaseFile(directory).delete();
      await databaseFile(replacementRoot).copy(databaseFile(directory).path);

      await expectLater(
        DatabaseInstallationGate.ensureReady(appDataDirectory: directory),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            'database_identity_mismatch',
          ),
        ),
      );
      expect(
        File(
          p.join(
            directory.path,
            'database_installation_receipt_${originalReceipt!.databaseId}.json',
          ),
        ).existsSync(),
        isTrue,
      );
    });

    test('已验证 restore 可轮换 database identity 并保留 installation', () async {
      final original = await DatabaseInstallationGate.ensureReady(
        appDataDirectory: directory,
      );
      final replacementRoot = await Directory.systemTemp.createTemp(
        'kelivo_database_restore_',
      );
      addTearDown(() async {
        if (await replacementRoot.exists()) {
          await replacementRoot.delete(recursive: true);
        }
      });
      final replacement = await DatabaseInstallationGate.ensureReady(
        appDataDirectory: replacementRoot,
      );
      await databaseFile(directory).delete();
      await databaseFile(replacementRoot).copy(databaseFile(directory).path);

      final updated = await DatabaseInstallationGate.ensureReady(
        appDataDirectory: directory,
        allowDatabaseIdentityChange: true,
      );

      expect(updated.installationId, original.installationId);
      expect(updated.databaseId, replacement.databaseId);
    });
  });
}
