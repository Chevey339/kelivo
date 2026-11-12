import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

import 'package:Kelivo/core/database/database_installation_gate.dart';
import 'package:Kelivo/core/database/private_data_storage.dart';
import 'package:Kelivo/core/services/storage/device_storage_probe.dart';
import 'package:Kelivo/core/services/storage/storage_space.dart';

import 'generated_schema/schema_v3.dart' as v3;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root, documents, target;
  late File source;
  late String originalHash;
  Future<String> hash(File file) async =>
      (await sha256.bind(file.openRead()).first).toString();

  setUp(() async {
    root = await Directory.systemTemp.createTemp('upgrade-space-');
    documents = await Directory('${root.path}/Documents').create();
    target = Directory('${root.path}/Support/kelivo-data');
    source = File('${documents.path}/kelivo.db');
    final old = v3.DatabaseAtV3(NativeDatabase(source));
    try {
      await old.customStatement('PRAGMA user_version = 3');
      await old.customStatement(
        'INSERT INTO conversation_rows '
        '(id,title,created_at,updated_at,is_pinned,truncate_index,'
        'version_selections_json,last_summarized_message_count,'
        'chat_suggestions_json,last_memory_extracted_order) '
        "VALUES ('retained','Legacy chat',1,2,0,-1,'{}',0,'[]',-1)",
      );
    } finally {
      await old.close();
    }
    originalHash = await hash(source);
  });
  tearDown(() async {
    DeviceStorageProbe.debugOverride = null;
    await root.delete(recursive: true);
  });

  test(
    'iOS activation reserves the later schema backup before copying',
    () async {
      final bytes = await source.length();
      DeviceStorageProbe.debugOverride = () async =>
          bytes + 64 * 1024 * 1024 + 4096;
      await expectLater(
        PrivateDataStorage.prepare(source: documents, target: target),
        throwsA(isA<InsufficientStorageSpace>()),
      );
      expect(await target.exists(), isFalse);
      expect(await hash(source), originalHash);
      expect(
        await target.parent
            .list()
            .where((e) => e.path.contains('staging'))
            .isEmpty,
        isTrue,
      );
    },
  );

  test(
    'an already activated old schema stays intact until space returns',
    () async {
      DeviceStorageProbe.debugOverride = () async => 1024 * 1024 * 1024;
      await PrivateDataStorage.prepare(source: documents, target: target);
      final installed = File('${target.path}/kelivo.db');
      final before = await hash(installed);
      DeviceStorageProbe.debugOverride = () async =>
          await installed.length() + 64 * 1024 * 1024 + 4096;
      await expectLater(
        DatabaseInstallationGate.ensureReady(appDataDirectory: target),
        throwsA(isA<InsufficientStorageSpace>()),
      );
      expect(await hash(source), originalHash);
      expect(await hash(installed), before);
      expect(await File('${installed.path}.premigrate-v3').exists(), isFalse);
      DeviceStorageProbe.debugOverride = () async => 1024 * 1024 * 1024;
      await DatabaseInstallationGate.ensureReady(appDataDirectory: target);
      final db = sqlite.sqlite3.open(
        installed.path,
        mode: sqlite.OpenMode.readOnly,
      );
      try {
        expect(db.userVersion, 5);
        expect(
          db.select('SELECT id FROM conversation_rows').single['id'],
          'retained',
        );
      } finally {
        db.close();
      }
      expect(await hash(source), originalHash);
    },
  );
}
