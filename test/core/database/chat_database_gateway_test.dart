import 'dart:async';
import 'dart:io';

import 'package:Kelivo/core/database/chat_database_gateway.dart';
import 'package:Kelivo/core/database/chat_database_observer.dart';
import 'package:Kelivo/core/database/business_data.dart';
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
      expect(leases.first.chatRepository, same(leases.first.repository));
      expect(
        leases[1].businessRepository,
        same(leases.first.businessRepository),
      );
      await leases.first.repository.getConversationCount();

      await leases.first.businessRepository.upsertEntity(
        BusinessEntityKind.assistant,
        const BusinessEntityValue(
          id: 'assistant-1',
          sortOrder: 0,
          payload: '{"id":"assistant-1"}',
        ),
      );
      expect(
        await leases[2].businessRepository.readEntities(
          BusinessEntityKind.assistant,
        ),
        hasLength(1),
      );

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
        final observer = ChatDatabaseObserver();
        gateway = ChatDatabaseGateway(observer: observer);
        final file = File('${directory.path}/chat.sqlite');
        await file.writeAsString('not sqlite');

        await expectLater(gateway.acquire(file), throwsA(anything));
        expect(await file.readAsString(), 'not sqlite');

        await file.delete();
        final lease = await gateway.acquire(file);
        expect(await lease.repository.getConversationCount(), 0);
        await lease.release();
        final metric = observer
            .snapshot()
            .operations[ChatDatabaseOperation.gatewayOpen]!;
        expect(metric.totalCount, 2);
        expect(metric.failureCount, 1);
      },
    );

    test('database lease lifecycle creates no session receipt', () async {
      final file = File('${directory.path}/chat.sqlite');

      final lease = await gateway.acquire(file);
      await lease.release();

      expect(
        await File('${directory.path}/.database_session_receipt.json').exists(),
        isFalse,
      );
    });

    test('shutdown closes outstanding leases and prevents reopening', () async {
      final file = File('${directory.path}/chat.sqlite');
      final first = await gateway.acquire(file);
      final second = await gateway.acquire(file);
      final shutdown = gateway.shutdown();
      expect(gateway.shutdown(), same(shutdown));
      await shutdown;
      await first.release();
      await second.release();
      await expectLater(first.repository.ensureReady(), throwsStateError);
      await expectLater(gateway.acquire(file), throwsStateError);
    });

    test('shutdown drains an accepted transaction before closing', () async {
      final file = File('${directory.path}/chat.sqlite');
      final lease = await gateway.acquire(file);
      final entered = Completer<void>();
      final finishWrite = Completer<void>();
      final write = lease.repository.genUiStates.transaction(() async {
        entered.complete();
        await finishWrite.future;
        await lease.businessRepository.setPreference('theme_mode_v1', 'dark');
      });
      await entered.future;
      var closed = false;
      final shutdown = gateway.shutdown().then((_) => closed = true);
      await pumpEventQueue();
      expect(closed, isFalse);
      finishWrite.complete();
      await write;
      await shutdown;
      await lease.release();

      final reopened = await ChatDatabaseGateway().acquire(file);
      expect(
        await reopened.businessRepository.getPreference('theme_mode_v1'),
        'dark',
      );
      await reopened.release();
    });

    test('shutdown during admission leaves no usable lease', () async {
      final file = File('${directory.path}/chat.sqlite');
      final acquisition = gateway.acquire(file);
      final rejected = expectLater(acquisition, throwsStateError);
      await gateway.shutdown();
      await rejected;
      await expectLater(gateway.acquire(file), throwsStateError);
    });
  });
}
