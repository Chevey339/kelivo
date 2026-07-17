import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/database/app_database.dart';
import 'package:Kelivo/core/services/database_v2_rollout_ledger.dart';

void main() {
  late Directory directory;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('kelivo_rollout_');
  });

  tearDown(() async {
    if (await directory.exists()) await directory.delete(recursive: true);
  });

  test(
    'persists sanitized migration metrics and deduplicates cold starts',
    () async {
      final ledger = DatabaseV2RolloutLedger(directory);
      final migratedAt = DateTime.utc(2026, 6, 1);

      await ledger.recordMigrationCompleted(
        migrationRunId: 'hive-0123456789abcdef0123456789abcdef',
        sourceKind: 'hive',
        sourceHash: List.filled(64, 'a').join(),
        migratedAtUtc: migratedAt,
        conversationCount: 12,
        messageCount: 345,
        issueCounts: const {'warning': 2, 'recovered': 1, 'rejected': 0},
      );
      await ledger.recordSuccessfulColdStart(
        coldStartId: 'process-a',
        atUtc: migratedAt.add(const Duration(days: 1)),
      );
      await ledger.recordSuccessfulColdStart(
        coldStartId: 'process-a',
        atUtc: migratedAt.add(const Duration(days: 1)),
      );
      await ledger.recordSuccessfulColdStart(
        coldStartId: 'process-b',
        atUtc: migratedAt.add(const Duration(days: 2)),
      );

      final snapshot = await ledger.read();
      expect(snapshot, isNotNull);
      expect(snapshot!.successfulColdStarts, 2);
      expect(snapshot.databaseSchemaVersion, AppDatabase.currentSchemaVersion);
      expect(snapshot.issueCounts, const {
        'warning': 2,
        'recovered': 1,
        'rejected': 0,
      });
      expect(
        snapshot.toDiagnosticJson().toString(),
        isNot(contains(directory.path)),
      );
      expect(snapshot.toDiagnosticJson().keys, isNot(contains('coldStartIds')));
    },
  );

  test(
    'freezes deterministic gray cohort and rollback compatibility',
    () async {
      final first = DatabaseV2RolloutLedger.rolloutDecision(
        installationId: 'installation-123',
        enabledBasisPoints: 500,
      );
      final second = DatabaseV2RolloutLedger.rolloutDecision(
        installationId: 'installation-123',
        enabledBasisPoints: 500,
      );

      expect(first.cohort, second.cohort);
      expect(first.enabled, first.cohort < 500);
      expect(
        DatabaseV2RollbackCompatibility.supportsSchema(
          AppDatabase.currentSchemaVersion,
        ),
        isTrue,
      );
      expect(
        DatabaseV2RollbackCompatibility.supportsSchema(
          AppDatabase.currentSchemaVersion + 1,
        ),
        isFalse,
      );
    },
  );

  test(
    'requires both three cold starts and thirty days for retirement',
    () async {
      final ledger = DatabaseV2RolloutLedger(directory);
      final migratedAt = DateTime.utc(2026, 6, 1);
      await ledger.recordMigrationCompleted(
        migrationRunId: 'hive-0123456789abcdef0123456789abcdef',
        sourceKind: 'hive',
        sourceHash: List.filled(64, 'b').join(),
        migratedAtUtc: migratedAt,
        conversationCount: 1,
        messageCount: 2,
        issueCounts: const {},
      );
      for (var index = 0; index < 3; index++) {
        await ledger.recordSuccessfulColdStart(
          coldStartId: 'process-$index',
          atUtc: migratedAt.add(Duration(days: index + 1)),
        );
      }

      expect(
        (await ledger.retirementEligibility(
          atUtc: migratedAt.add(const Duration(days: 29)),
        )).eligible,
        isFalse,
      );
      final eligible = await ledger.retirementEligibility(
        atUtc: migratedAt.add(const Duration(days: 30)),
      );
      expect(eligible.eligible, isTrue);
      expect(eligible.successfulColdStarts, 3);
      expect(eligible.retentionAge.inDays, 30);
    },
  );
}
