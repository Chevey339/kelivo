import 'dart:io';

import 'package:Kelivo/core/database/app_database.dart';
import 'package:Kelivo/core/database/chat_database_gateway.dart';
import 'package:Kelivo/core/database/database_installation_gate.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ChatDatabaseGateway', () {
    late Directory directory;
    late ChatDatabaseGateway gateway;

    setUp(() async {
      directory = await Directory.systemTemp.createTemp(
        'kelivo_database_gateway_',
      );
      gateway = ChatDatabaseGateway();
    });

    tearDown(() async {
      if (await directory.exists()) await directory.delete(recursive: true);
    });

    test('concurrent acquire shares one single-flight repository', () async {
      final file = File('${directory.path}/chat.sqlite');

      final leases = await Future.wait([
        gateway.acquire(file),
        gateway.acquire(file),
        gateway.acquire(file),
      ]);

      expect(leases[1].repository, same(leases.first.repository));
      expect(leases[2].repository, same(leases.first.repository));
      await leases.first.repository.getConversationCount();

      await leases.first.release();
      await leases[1].repository.getConversationCount();
      await leases[1].release();
      await leases[2].release();
    });

    test('active live lease rejects a different database path', () async {
      final lease = await gateway.acquire(
        File('${directory.path}/first.sqlite'),
      );
      addTearDown(lease.release);

      await expectLater(
        gateway.acquire(File('${directory.path}/second.sqlite')),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            'database_gateway_path_mismatch',
          ),
        ),
      );
    });

    test(
      'failed initialization can be retried after preserving evidence',
      () async {
        final file = File('${directory.path}/chat.sqlite');
        await file.writeAsString('not sqlite');

        await expectLater(gateway.acquire(file), throwsA(anything));
        expect(await file.readAsString(), 'not sqlite');

        await file.delete();
        final lease = await gateway.acquire(file);
        expect(await lease.repository.getConversationCount(), 0);
        await lease.release();
      },
    );

    test(
      'installed database lease publishes and cleanly removes session receipt',
      () async {
        await DatabaseInstallationGate.ensureReady(appDataDirectory: directory);
        final file = File('${directory.path}/${AppDatabase.databaseFileName}');
        final sessionFile = File(
          '${directory.path}/.database_session_receipt.json',
        );

        final lease = await gateway.acquire(file);
        expect(await sessionFile.exists(), isTrue);

        await lease.release();
        expect(await sessionFile.exists(), isFalse);
      },
    );
  });
}
