import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import '../database/app_database.dart';
import 'backup/restore_durability.dart';

final class DatabaseV2RolloutDecision {
  const DatabaseV2RolloutDecision({
    required this.cohort,
    required this.enabledBasisPoints,
  });

  final int cohort;
  final int enabledBasisPoints;

  bool get enabled => cohort < enabledBasisPoints;
}

final class DatabaseV2RetirementEligibility {
  const DatabaseV2RetirementEligibility({
    required this.tracked,
    required this.successfulColdStarts,
    required this.retentionAge,
  });

  final bool tracked;
  final int successfulColdStarts;
  final Duration retentionAge;

  bool get eligible =>
      tracked && successfulColdStarts >= 3 && retentionAge.inDays >= 30;
}

/// Compatibility contract used by a rollback build after v2 has written data.
///
/// A rollback build must retain the v2 reader/writer and use this same schema
/// window. It must never attempt a down migration or reopen the retained Hive
/// files as the live writer.
abstract final class DatabaseV2RollbackCompatibility {
  static const storageContractVersion = 2;
  static const minimumReadableSchema = 8;
  static const maximumReadableSchema = AppDatabase.currentSchemaVersion;

  static bool supportsSchema(int schemaVersion) =>
      schemaVersion >= minimumReadableSchema &&
      schemaVersion <= maximumReadableSchema;

  static Map<String, Object> manifest() => {
    'storageContractVersion': storageContractVersion,
    'minimumReadableSchema': minimumReadableSchema,
    'maximumReadableSchema': maximumReadableSchema,
    'downMigrationAllowed': false,
    'hiveWriterAllowed': false,
  };
}

final class DatabaseV2RolloutSnapshot {
  const DatabaseV2RolloutSnapshot({
    required this.sequence,
    required this.previousChecksum,
    required this.checksum,
    required this.migrationRunId,
    required this.sourceKind,
    required this.sourceHash,
    required this.migratedAtUtc,
    required this.databaseSchemaVersion,
    required this.conversationCount,
    required this.messageCount,
    required this.issueCounts,
    required this.successfulColdStarts,
    required this.lastSuccessfulColdStartAtUtc,
    required this.coldStartIds,
  });

  final int sequence;
  final String? previousChecksum;
  final String checksum;
  final String migrationRunId;
  final String sourceKind;
  final String sourceHash;
  final DateTime migratedAtUtc;
  final int databaseSchemaVersion;
  final int conversationCount;
  final int messageCount;
  final Map<String, int> issueCounts;
  final int successfulColdStarts;
  final DateTime? lastSuccessfulColdStartAtUtc;
  final List<String> coldStartIds;

  Map<String, Object?> toDiagnosticJson() => {
    'format': DatabaseV2RolloutLedger.format,
    'formatVersion': DatabaseV2RolloutLedger.formatVersion,
    'sequence': sequence,
    'migrationRunId': migrationRunId,
    'sourceKind': sourceKind,
    'sourceHash': sourceHash,
    'migratedAtUtc': migratedAtUtc.toIso8601String(),
    'databaseSchemaVersion': databaseSchemaVersion,
    'conversationCount': conversationCount,
    'messageCount': messageCount,
    'issueCounts': issueCounts,
    'successfulColdStarts': successfulColdStarts,
    'lastSuccessfulColdStartAtUtc': lastSuccessfulColdStartAtUtc
        ?.toIso8601String(),
    'rollbackCompatibility': DatabaseV2RollbackCompatibility.manifest(),
  };
}

/// Local, secret-free rollout evidence for Hive -> database v2 migrations.
///
/// Every update is an immutable, checksummed receipt. This avoids in-place
/// JSON replacement and lets support distinguish a complete latest receipt
/// from an interrupted write without collecting message text, IDs or paths.
final class DatabaseV2RolloutLedger {
  DatabaseV2RolloutLedger(
    this.appDataDirectory, {
    RestoreDurability? durability,
  }) : durability = durability ?? RestorePlatformDurability();

  static const format = 'kelivo.database-v2-rollout';
  static const formatVersion = 1;
  static const _directoryName = '.database_v2_rollout';
  static const _maximumReceiptBytes = 64 * 1024;
  static const _rememberedColdStarts = 16;
  static final _receiptPattern = RegExp(r'^ledger_(\d{8})\.json$');
  static final _sha256Pattern = RegExp(r'^[0-9a-f]{64}$');
  static final _runIdPattern = RegExp(r'^[a-z0-9][a-z0-9_-]{0,95}$');

  final Directory appDataDirectory;
  final RestoreDurability durability;

  Directory get directory =>
      Directory(p.join(appDataDirectory.path, _directoryName));

  static DatabaseV2RolloutDecision rolloutDecision({
    required String installationId,
    required int enabledBasisPoints,
  }) {
    if (installationId.isEmpty) {
      throw ArgumentError.value(installationId, 'installationId');
    }
    if (enabledBasisPoints < 0 || enabledBasisPoints > 10000) {
      throw RangeError.range(enabledBasisPoints, 0, 10000);
    }
    final digest = sha256.convert(utf8.encode('database-v2:$installationId'));
    final cohort = ((digest.bytes[0] << 8) | digest.bytes[1]) * 10000 ~/ 65536;
    return DatabaseV2RolloutDecision(
      cohort: cohort,
      enabledBasisPoints: enabledBasisPoints,
    );
  }

  Future<void> recordMigrationCompleted({
    required String migrationRunId,
    required String sourceKind,
    required String sourceHash,
    required DateTime migratedAtUtc,
    required int conversationCount,
    required int messageCount,
    required Map<String, int> issueCounts,
  }) async {
    if (!_runIdPattern.hasMatch(migrationRunId) ||
        sourceKind != 'hive' ||
        !_sha256Pattern.hasMatch(sourceHash) ||
        conversationCount < 0 ||
        messageCount < 0) {
      throw ArgumentError('database_v2_rollout_migration');
    }
    final normalizedIssues = _normalizeIssueCounts(issueCounts);
    final existing = await read();
    if (existing != null) {
      if (existing.migrationRunId == migrationRunId &&
          existing.sourceHash == sourceHash) {
        return;
      }
      throw StateError('database_v2_rollout_already_tracked');
    }
    await _publish(
      sequence: 1,
      previousChecksum: null,
      migrationRunId: migrationRunId,
      sourceKind: sourceKind,
      sourceHash: sourceHash,
      migratedAtUtc: migratedAtUtc.toUtc(),
      databaseSchemaVersion: AppDatabase.currentSchemaVersion,
      conversationCount: conversationCount,
      messageCount: messageCount,
      issueCounts: normalizedIssues,
      successfulColdStarts: 0,
      lastSuccessfulColdStartAtUtc: null,
      coldStartIds: const [],
    );
  }

  Future<void> recordSuccessfulColdStart({
    required String coldStartId,
    required DateTime atUtc,
  }) async {
    if (coldStartId.isEmpty || coldStartId.length > 128) {
      throw ArgumentError.value(coldStartId, 'coldStartId');
    }
    final latest = await read();
    if (latest == null || latest.coldStartIds.contains(coldStartId)) return;
    final ids = [...latest.coldStartIds, coldStartId];
    await _publish(
      sequence: latest.sequence + 1,
      previousChecksum: latest.checksum,
      migrationRunId: latest.migrationRunId,
      sourceKind: latest.sourceKind,
      sourceHash: latest.sourceHash,
      migratedAtUtc: latest.migratedAtUtc,
      databaseSchemaVersion: latest.databaseSchemaVersion,
      conversationCount: latest.conversationCount,
      messageCount: latest.messageCount,
      issueCounts: latest.issueCounts,
      successfulColdStarts: latest.successfulColdStarts + 1,
      lastSuccessfulColdStartAtUtc: atUtc.toUtc(),
      coldStartIds: ids.length <= _rememberedColdStarts
          ? ids
          : ids.sublist(ids.length - _rememberedColdStarts),
    );
  }

  Future<DatabaseV2RetirementEligibility> retirementEligibility({
    required DateTime atUtc,
  }) async {
    final latest = await read();
    if (latest == null) {
      return const DatabaseV2RetirementEligibility(
        tracked: false,
        successfulColdStarts: 0,
        retentionAge: Duration.zero,
      );
    }
    final age = atUtc.toUtc().difference(latest.migratedAtUtc);
    return DatabaseV2RetirementEligibility(
      tracked: true,
      successfulColdStarts: latest.successfulColdStarts,
      retentionAge: age.isNegative ? Duration.zero : age,
    );
  }

  Future<DatabaseV2RolloutSnapshot?> read() async {
    if (await FileSystemEntity.type(directory.path, followLinks: false) ==
        FileSystemEntityType.notFound) {
      return null;
    }
    if (await FileSystemEntity.type(directory.path, followLinks: false) !=
        FileSystemEntityType.directory) {
      throw StateError('database_v2_rollout_directory');
    }
    final receipts = <({int sequence, File file})>[];
    await for (final entity in directory.list(followLinks: false)) {
      if (entity is! File) {
        throw StateError('database_v2_rollout_topology');
      }
      final match = _receiptPattern.firstMatch(p.basename(entity.path));
      if (match == null) {
        if (p.basename(entity.path).startsWith('.ledger_')) continue;
        throw StateError('database_v2_rollout_topology');
      }
      receipts.add((sequence: int.parse(match.group(1)!), file: entity));
    }
    if (receipts.isEmpty) return null;
    receipts.sort((a, b) => a.sequence.compareTo(b.sequence));
    String? previousChecksum;
    DatabaseV2RolloutSnapshot? latest;
    for (var index = 0; index < receipts.length; index++) {
      final receipt = receipts[index];
      if (receipt.sequence != index + 1) {
        throw StateError('database_v2_rollout_sequence');
      }
      final decoded = await _readFile(receipt.file);
      if (decoded.sequence != receipt.sequence ||
          decoded.previousChecksum != previousChecksum) {
        throw StateError('database_v2_rollout_chain');
      }
      previousChecksum = decoded.checksum;
      latest = decoded;
    }
    return latest;
  }

  Future<void> _publish({
    required int sequence,
    required String? previousChecksum,
    required String migrationRunId,
    required String sourceKind,
    required String sourceHash,
    required DateTime migratedAtUtc,
    required int databaseSchemaVersion,
    required int conversationCount,
    required int messageCount,
    required Map<String, int> issueCounts,
    required int successfulColdStarts,
    required DateTime? lastSuccessfulColdStartAtUtc,
    required List<String> coldStartIds,
  }) async {
    if (!await directory.exists()) {
      await directory.create(recursive: true);
      await durability.restrictDirectory(directory);
      await durability.syncDirectory(appDataDirectory, fullBarrier: true);
    }
    final body = <String, Object?>{
      'format': format,
      'formatVersion': formatVersion,
      'sequence': sequence,
      'previousChecksum': previousChecksum,
      'migrationRunId': migrationRunId,
      'sourceKind': sourceKind,
      'sourceHash': sourceHash,
      'migratedAtUtc': migratedAtUtc.toIso8601String(),
      'databaseSchemaVersion': databaseSchemaVersion,
      'conversationCount': conversationCount,
      'messageCount': messageCount,
      'issueCounts': issueCounts,
      'successfulColdStarts': successfulColdStarts,
      'lastSuccessfulColdStartAtUtc': lastSuccessfulColdStartAtUtc
          ?.toIso8601String(),
      'coldStartIds': coldStartIds,
    };
    final checksum = sha256.convert(utf8.encode(jsonEncode(body))).toString();
    final encoded = utf8.encode(jsonEncode({...body, 'checksum': checksum}));
    if (encoded.length > _maximumReceiptBytes) {
      throw StateError('database_v2_rollout_size');
    }
    final target = File(
      p.join(
        directory.path,
        'ledger_${sequence.toString().padLeft(8, '0')}.json',
      ),
    );
    if (await target.exists()) {
      throw StateError('database_v2_rollout_collision');
    }
    final temporary = File(
      p.join(
        directory.path,
        '.ledger_${sequence}_${pid}_${DateTime.now().microsecondsSinceEpoch}.tmp',
      ),
    );
    try {
      await temporary.create(exclusive: true);
      await durability.restrictFile(temporary);
      await temporary.writeAsBytes(encoded, flush: true);
      await durability.syncFile(temporary, fullBarrier: true);
      final staged = await _readFile(temporary);
      if (staged.checksum != checksum) {
        throw StateError('database_v2_rollout_staging');
      }
      await durability.renameAndSync(
        source: temporary,
        targetPath: target.path,
      );
      final published = await _readFile(target);
      if (published.checksum != checksum) {
        throw StateError('database_v2_rollout_publish');
      }
    } finally {
      if (await temporary.exists()) {
        await temporary.delete();
        await durability.syncDirectory(directory, fullBarrier: true);
      }
    }
  }

  static Future<DatabaseV2RolloutSnapshot> _readFile(File file) async {
    final length = await file.length();
    if (length <= 0 || length > _maximumReceiptBytes) {
      throw const FormatException('database_v2_rollout_size');
    }
    final value = jsonDecode(await file.readAsString());
    if (value is! Map<String, dynamic>) {
      throw const FormatException('database_v2_rollout_json');
    }
    const expectedKeys = {
      'format',
      'formatVersion',
      'sequence',
      'previousChecksum',
      'migrationRunId',
      'sourceKind',
      'sourceHash',
      'migratedAtUtc',
      'databaseSchemaVersion',
      'conversationCount',
      'messageCount',
      'issueCounts',
      'successfulColdStarts',
      'lastSuccessfulColdStartAtUtc',
      'coldStartIds',
      'checksum',
    };
    if (value.keys.toSet().difference(expectedKeys).isNotEmpty ||
        expectedKeys.difference(value.keys.toSet()).isNotEmpty) {
      throw const FormatException('database_v2_rollout_fields');
    }
    final checksum = value['checksum'];
    final body = Map<String, dynamic>.from(value)..remove('checksum');
    final expectedChecksum = sha256
        .convert(utf8.encode(jsonEncode(body)))
        .toString();
    if (checksum is! String ||
        !_sha256Pattern.hasMatch(checksum) ||
        checksum != expectedChecksum) {
      throw const FormatException('database_v2_rollout_checksum');
    }
    final sequence = value['sequence'];
    final previousChecksum = value['previousChecksum'];
    final migrationRunId = value['migrationRunId'];
    final sourceKind = value['sourceKind'];
    final sourceHash = value['sourceHash'];
    final databaseSchemaVersion = value['databaseSchemaVersion'];
    final conversationCount = value['conversationCount'];
    final messageCount = value['messageCount'];
    final successfulColdStarts = value['successfulColdStarts'];
    final rawIssues = value['issueCounts'];
    final rawIds = value['coldStartIds'];
    final migratedAt = DateTime.tryParse(
      value['migratedAtUtc']?.toString() ?? '',
    );
    final lastAtRaw = value['lastSuccessfulColdStartAtUtc'];
    final lastAt = lastAtRaw == null
        ? null
        : DateTime.tryParse(lastAtRaw.toString());
    if (value['format'] != format ||
        value['formatVersion'] != formatVersion ||
        sequence is! int ||
        sequence <= 0 ||
        (previousChecksum != null &&
            (previousChecksum is! String ||
                !_sha256Pattern.hasMatch(previousChecksum))) ||
        migrationRunId is! String ||
        !_runIdPattern.hasMatch(migrationRunId) ||
        sourceKind != 'hive' ||
        sourceHash is! String ||
        !_sha256Pattern.hasMatch(sourceHash) ||
        migratedAt == null ||
        !migratedAt.isUtc ||
        databaseSchemaVersion is! int ||
        conversationCount is! int ||
        conversationCount < 0 ||
        messageCount is! int ||
        messageCount < 0 ||
        successfulColdStarts is! int ||
        successfulColdStarts < 0 ||
        (lastAtRaw != null && (lastAt == null || !lastAt.isUtc)) ||
        rawIssues is! Map ||
        rawIds is! List ||
        rawIds.length > _rememberedColdStarts ||
        rawIds.any((id) => id is! String || id.isEmpty || id.length > 128)) {
      throw const FormatException('database_v2_rollout_values');
    }
    final issueCounts = _normalizeIssueCounts(
      rawIssues.map(
        (key, value) => MapEntry(key.toString(), value is int ? value : -1),
      ),
    );
    return DatabaseV2RolloutSnapshot(
      sequence: sequence,
      previousChecksum: previousChecksum as String?,
      checksum: checksum,
      migrationRunId: migrationRunId,
      sourceKind: sourceKind as String,
      sourceHash: sourceHash,
      migratedAtUtc: migratedAt,
      databaseSchemaVersion: databaseSchemaVersion,
      conversationCount: conversationCount,
      messageCount: messageCount,
      issueCounts: issueCounts,
      successfulColdStarts: successfulColdStarts,
      lastSuccessfulColdStartAtUtc: lastAt,
      coldStartIds: List<String>.unmodifiable(rawIds.cast<String>()),
    );
  }

  static Map<String, int> _normalizeIssueCounts(Map<String, int> values) {
    const keys = ['warning', 'recovered', 'rejected'];
    if (values.keys.any((key) => !keys.contains(key)) ||
        values.values.any((value) => value < 0)) {
      throw ArgumentError('database_v2_rollout_issue_counts');
    }
    return Map.unmodifiable({for (final key in keys) key: values[key] ?? 0});
  }
}
