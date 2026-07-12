import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/services/database_v2_rollout_ledger.dart';
import 'package:Kelivo/core/services/legacy_data_retirement_service.dart';

void main() {
  late Directory directory;
  late DatabaseV2RolloutLedger ledger;
  final migratedAt = DateTime.utc(2026, 6, 1);

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('kelivo_retirement_');
    ledger = DatabaseV2RolloutLedger(directory);
    await ledger.recordMigrationCompleted(
      migrationRunId: 'hive-0123456789abcdef0123456789abcdef',
      sourceKind: 'hive',
      sourceHash: List.filled(64, 'a').join(),
      migratedAtUtc: migratedAt,
      conversationCount: 2,
      messageCount: 4,
      issueCounts: const {},
    );
  });

  tearDown(() async {
    if (await directory.exists()) await directory.delete(recursive: true);
  });

  test('fails closed before both retention conditions are met', () async {
    final service = LegacyDataRetirementService(directory, ledger: ledger);
    final diagnostic = File('${directory.path}/diagnostic.json');
    await service.exportDiagnostic(diagnostic, atUtc: migratedAt);
    final diagnosticHash = sha256
        .convert(await diagnostic.readAsBytes())
        .toString();

    expect(
      () => service.retireHiveArtifacts(
        authorization: LegacyRetirementAuthorization(
          confirmation: LegacyRetirementAuthorization.requiredConfirmation,
          diagnosticSha256: diagnosticHash,
          authorizedAtUtc: migratedAt.add(const Duration(days: 30)),
        ),
      ),
      throwsA(isA<StateError>()),
    );
  });

  test(
    'deletes only frozen Hive artifacts after diagnostic and authorization',
    () async {
      for (final name in LegacyDataRetirementService.hiveArtifactNames) {
        await File('${directory.path}/$name').writeAsString('legacy-$name');
      }
      final unrelated = File('${directory.path}/keep.me');
      await unrelated.writeAsString('keep');
      for (var index = 0; index < 3; index++) {
        await ledger.recordSuccessfulColdStart(
          coldStartId: 'process-$index',
          atUtc: migratedAt.add(Duration(days: index + 1)),
        );
      }
      final atUtc = migratedAt.add(const Duration(days: 31));
      final service = LegacyDataRetirementService(
        directory,
        ledger: ledger,
        clock: () => atUtc,
      );
      final diagnostic = File('${directory.path}/diagnostic.json');
      final report = await service.exportDiagnostic(diagnostic, atUtc: atUtc);
      expect(report.eligible, isTrue);
      expect(report.artifacts, hasLength(3));
      final diagnosticHash = sha256
          .convert(await diagnostic.readAsBytes())
          .toString();

      final receipt = await service.retireHiveArtifacts(
        authorization: LegacyRetirementAuthorization(
          confirmation: LegacyRetirementAuthorization.requiredConfirmation,
          diagnosticSha256: diagnosticHash,
          authorizedAtUtc: atUtc,
        ),
        diagnosticFile: diagnostic,
      );

      expect(receipt.deletedArtifacts, hasLength(3));
      expect(await unrelated.exists(), isTrue);
      for (final name in LegacyDataRetirementService.hiveArtifactNames) {
        expect(await File('${directory.path}/$name').exists(), isFalse);
      }
      expect(await service.readReceipt(), isNotNull);
    },
  );

  test(
    'resumes an operation-ahead deleting receipt after interruption',
    () async {
      for (final name in LegacyDataRetirementService.hiveArtifactNames) {
        final content = 'legacy-$name';
        await File('${directory.path}/$name').writeAsString(content);
      }
      for (var index = 0; index < 3; index++) {
        await ledger.recordSuccessfulColdStart(
          coldStartId: 'process-$index',
          atUtc: migratedAt.add(Duration(days: index + 1)),
        );
      }
      final atUtc = migratedAt.add(const Duration(days: 31));
      var interrupt = true;
      final service = LegacyDataRetirementService(
        directory,
        ledger: ledger,
        clock: () => atUtc,
        afterDeletingReceiptPublished: () async {
          if (interrupt) throw StateError('simulated_kill');
        },
      );
      final diagnostic = File('${directory.path}/diagnostic.json');
      await service.exportDiagnostic(diagnostic, atUtc: atUtc);
      final diagnosticHash = sha256
          .convert(await diagnostic.readAsBytes())
          .toString();
      await expectLater(
        service.retireHiveArtifacts(
          authorization: LegacyRetirementAuthorization(
            confirmation: LegacyRetirementAuthorization.requiredConfirmation,
            diagnosticSha256: diagnosticHash,
            authorizedAtUtc: atUtc,
          ),
          diagnosticFile: diagnostic,
        ),
        throwsA(isA<StateError>()),
      );
      expect(
        (await service.readReceipt())!.state,
        LegacyRetirementState.deleting,
      );
      expect(
        await File('${directory.path}/conversations.hive').exists(),
        isTrue,
      );

      interrupt = false;
      final completed = await service.retireHiveArtifacts(
        authorization: LegacyRetirementAuthorization(
          confirmation: '',
          diagnosticSha256: '',
          authorizedAtUtc: DateTime.utc(2000),
        ),
      );
      expect(completed.state, LegacyRetirementState.completed);
      expect(await File('${directory.path}/messages.hive').exists(), isFalse);
    },
  );
}
