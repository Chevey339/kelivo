import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import 'backup/restore_durability.dart';
import 'database_v2_rollout_ledger.dart';

final class LegacyRetirementAuthorization {
  const LegacyRetirementAuthorization({
    required this.confirmation,
    required this.diagnosticSha256,
    required this.authorizedAtUtc,
  });

  static const requiredConfirmation = 'DELETE_RETAINED_LEGACY_DATA';

  final String confirmation;
  final String diagnosticSha256;
  final DateTime authorizedAtUtc;
}

final class LegacyArtifactDiagnostic {
  const LegacyArtifactDiagnostic({
    required this.name,
    required this.bytes,
    required this.sha256,
  });

  final String name;
  final int bytes;
  final String sha256;

  Map<String, Object> toJson() => {
    'name': name,
    'bytes': bytes,
    'sha256': sha256,
  };
}

final class LegacyRetirementDiagnostic {
  const LegacyRetirementDiagnostic({
    required this.createdAtUtc,
    required this.eligible,
    required this.successfulColdStarts,
    required this.retentionDays,
    required this.artifacts,
    required this.completedRestoreRuns,
    required this.rollout,
  });

  final DateTime createdAtUtc;
  final bool eligible;
  final int successfulColdStarts;
  final int retentionDays;
  final List<LegacyArtifactDiagnostic> artifacts;
  final int completedRestoreRuns;
  final Map<String, Object?> rollout;

  Map<String, Object?> toJson() => {
    'format': 'kelivo.database-v2-retirement-diagnostic',
    'formatVersion': 1,
    'createdAtUtc': createdAtUtc.toIso8601String(),
    'eligible': eligible,
    'successfulColdStarts': successfulColdStarts,
    'retentionDays': retentionDays,
    'artifacts': artifacts.map((artifact) => artifact.toJson()).toList(),
    'completedRestoreRuns': completedRestoreRuns,
    'rollout': rollout,
    'rollbackCompatibility': DatabaseV2RollbackCompatibility.manifest(),
  };
}

enum LegacyRetirementState { deleting, completed }

final class LegacyRetirementReceipt {
  const LegacyRetirementReceipt({
    required this.sequence,
    required this.state,
    required this.previousChecksum,
    required this.checksum,
    required this.authorizedAtUtc,
    required this.completedAtUtc,
    required this.diagnosticSha256,
    required this.rolloutChecksum,
    required this.deletedArtifacts,
  });

  final int sequence;
  final LegacyRetirementState state;
  final String? previousChecksum;
  final String checksum;
  final DateTime authorizedAtUtc;
  final DateTime? completedAtUtc;
  final String diagnosticSha256;
  final String rolloutChecksum;
  final List<LegacyArtifactDiagnostic> deletedArtifacts;
}

/// Enforces PD-10 before deleting the exact released Hive artifact family.
///
/// Restore `.previous` evidence and adapters are deliberately not deleted by
/// this per-installation service. Their release-wide removal still requires
/// completed five-platform rollout evidence and an explicitly authorized
/// cleanup release.
final class LegacyDataRetirementService {
  LegacyDataRetirementService(
    this.appDataDirectory, {
    DatabaseV2RolloutLedger? ledger,
    RestoreDurability? durability,
    this.afterDeletingReceiptPublished,
    this.clock,
  }) : ledger = ledger ?? DatabaseV2RolloutLedger(appDataDirectory),
       durability = durability ?? RestorePlatformDurability();

  static const hiveArtifactNames = <String>{
    'conversations.hive',
    'messages.hive',
    'tool_events_v1.hive',
  };
  static const _retentionDirectoryName = '.database_v2_retention';
  static final _sha256Pattern = RegExp(r'^[0-9a-f]{64}$');
  static final _receiptPattern = RegExp(r'^receipt_(\d{8})\.json$');

  final Directory appDataDirectory;
  final DatabaseV2RolloutLedger ledger;
  final RestoreDurability durability;

  /// Deterministic failpoint used by the retention recovery test harness.
  final Future<void> Function()? afterDeletingReceiptPublished;
  final DateTime Function()? clock;

  Directory get _retentionDirectory =>
      Directory(p.join(appDataDirectory.path, _retentionDirectoryName));

  Future<LegacyRetirementDiagnostic> exportDiagnostic(
    File destination, {
    required DateTime atUtc,
  }) async {
    final snapshot = await ledger.read();
    if (snapshot == null) throw StateError('legacy_retirement_untracked');
    final eligibility = await ledger.retirementEligibility(atUtc: atUtc);
    final report = LegacyRetirementDiagnostic(
      createdAtUtc: atUtc.toUtc(),
      eligible: eligibility.eligible,
      successfulColdStarts: eligibility.successfulColdStarts,
      retentionDays: eligibility.retentionAge.inDays,
      artifacts: await _inspectHiveArtifacts(),
      completedRestoreRuns: await _completedRestoreRunCount(),
      rollout: snapshot.toDiagnosticJson(),
    );
    await destination.parent.create(recursive: true);
    await destination.writeAsString(jsonEncode(report.toJson()), flush: true);
    return report;
  }

  Future<LegacyRetirementReceipt> retireHiveArtifacts({
    required LegacyRetirementAuthorization authorization,
    File? diagnosticFile,
  }) async {
    final existing = await readReceipt();
    if (existing?.state == LegacyRetirementState.completed) return existing!;

    LegacyRetirementReceipt deleting;
    if (existing == null) {
      final nowUtc = (clock?.call() ?? DateTime.now()).toUtc();
      final authorizationSkew = nowUtc.difference(
        authorization.authorizedAtUtc,
      );
      if (authorization.confirmation !=
              LegacyRetirementAuthorization.requiredConfirmation ||
          !_sha256Pattern.hasMatch(authorization.diagnosticSha256) ||
          !authorization.authorizedAtUtc.isUtc ||
          authorizationSkew.abs() > const Duration(minutes: 5) ||
          diagnosticFile == null ||
          !await diagnosticFile.exists()) {
        throw StateError('legacy_retirement_authorization');
      }
      final diagnosticHash = await _hashFile(diagnosticFile);
      if (diagnosticHash != authorization.diagnosticSha256) {
        throw StateError('legacy_retirement_diagnostic');
      }
      final snapshot = await ledger.read();
      if (snapshot == null) throw StateError('legacy_retirement_untracked');
      final eligibility = await ledger.retirementEligibility(atUtc: nowUtc);
      if (!eligibility.eligible) {
        throw StateError('legacy_retirement_retention');
      }
      final diagnosticArtifacts = _decodeDiagnosticArtifacts(
        jsonDecode(await diagnosticFile.readAsString()),
      );
      final currentArtifacts = await _inspectHiveArtifacts();
      if (!_sameArtifacts(diagnosticArtifacts, currentArtifacts)) {
        throw StateError('legacy_retirement_artifacts_changed');
      }
      deleting = await _publishReceipt(
        sequence: 1,
        state: LegacyRetirementState.deleting,
        previousChecksum: null,
        authorizedAtUtc: authorization.authorizedAtUtc,
        completedAtUtc: null,
        diagnosticSha256: diagnosticHash,
        rolloutChecksum: snapshot.checksum,
        artifacts: currentArtifacts,
      );
      await afterDeletingReceiptPublished?.call();
    } else {
      deleting = existing;
      if (deleting.state != LegacyRetirementState.deleting) {
        throw StateError('legacy_retirement_state');
      }
    }

    for (final artifact in deleting.deletedArtifacts) {
      final file = File(p.join(appDataDirectory.path, artifact.name));
      final type = await FileSystemEntity.type(file.path, followLinks: false);
      if (type == FileSystemEntityType.notFound) continue;
      if (type != FileSystemEntityType.file ||
          await file.length() != artifact.bytes ||
          await _hashFile(file) != artifact.sha256) {
        throw StateError('legacy_retirement_artifact_changed');
      }
      await file.delete();
      await durability.syncDirectory(appDataDirectory, fullBarrier: true);
    }
    return _publishReceipt(
      sequence: deleting.sequence + 1,
      state: LegacyRetirementState.completed,
      previousChecksum: deleting.checksum,
      authorizedAtUtc: deleting.authorizedAtUtc,
      completedAtUtc: (clock?.call() ?? DateTime.now()).toUtc(),
      diagnosticSha256: deleting.diagnosticSha256,
      rolloutChecksum: deleting.rolloutChecksum,
      artifacts: deleting.deletedArtifacts,
    );
  }

  Future<LegacyRetirementReceipt?> readReceipt() async {
    final type = await FileSystemEntity.type(
      _retentionDirectory.path,
      followLinks: false,
    );
    if (type == FileSystemEntityType.notFound) return null;
    if (type != FileSystemEntityType.directory) {
      throw StateError('legacy_retirement_receipt_directory');
    }
    final files = <({int sequence, File file})>[];
    await for (final entity in _retentionDirectory.list(followLinks: false)) {
      if (entity is! File) {
        throw StateError('legacy_retirement_receipt_topology');
      }
      final name = p.basename(entity.path);
      final match = _receiptPattern.firstMatch(name);
      if (match == null) {
        if (name.startsWith('.receipt_')) continue;
        throw StateError('legacy_retirement_receipt_topology');
      }
      files.add((sequence: int.parse(match.group(1)!), file: entity));
    }
    if (files.isEmpty) return null;
    files.sort((a, b) => a.sequence.compareTo(b.sequence));
    String? previousChecksum;
    LegacyRetirementReceipt? latest;
    for (var index = 0; index < files.length; index++) {
      if (files[index].sequence != index + 1) {
        throw StateError('legacy_retirement_receipt_sequence');
      }
      final receipt = await _readReceiptFile(files[index].file);
      if (receipt.sequence != files[index].sequence ||
          receipt.previousChecksum != previousChecksum) {
        throw StateError('legacy_retirement_receipt_chain');
      }
      previousChecksum = receipt.checksum;
      latest = receipt;
    }
    return latest;
  }

  Future<List<LegacyArtifactDiagnostic>> _inspectHiveArtifacts() async {
    final artifacts = <LegacyArtifactDiagnostic>[];
    for (final name in hiveArtifactNames.toList()..sort()) {
      final file = File(p.join(appDataDirectory.path, name));
      final type = await FileSystemEntity.type(file.path, followLinks: false);
      if (type == FileSystemEntityType.notFound) continue;
      if (type != FileSystemEntityType.file) {
        throw StateError('legacy_retirement_artifact_type');
      }
      artifacts.add(
        LegacyArtifactDiagnostic(
          name: name,
          bytes: await file.length(),
          sha256: await _hashFile(file),
        ),
      );
    }
    return List.unmodifiable(artifacts);
  }

  Future<int> _completedRestoreRunCount() async {
    final completed = Directory(
      p.join(appDataDirectory.path, '.kelivo_restore', 'completed'),
    );
    if (!await completed.exists()) return 0;
    var count = 0;
    await for (final entity in completed.list(followLinks: false)) {
      if (entity is Directory &&
          RegExp(r'^run_[a-f0-9]{32}$').hasMatch(p.basename(entity.path))) {
        count++;
      }
    }
    return count;
  }

  Future<LegacyRetirementReceipt> _publishReceipt({
    required int sequence,
    required LegacyRetirementState state,
    required String? previousChecksum,
    required DateTime authorizedAtUtc,
    required DateTime? completedAtUtc,
    required String diagnosticSha256,
    required String rolloutChecksum,
    required List<LegacyArtifactDiagnostic> artifacts,
  }) async {
    if (!await _retentionDirectory.exists()) {
      await _retentionDirectory.create(recursive: true);
      await durability.restrictDirectory(_retentionDirectory);
      await durability.syncDirectory(appDataDirectory, fullBarrier: true);
    }
    final body = <String, Object?>{
      'format': 'kelivo.database-v2-retention-receipt',
      'formatVersion': 1,
      'sequence': sequence,
      'state': state.name,
      'previousChecksum': previousChecksum,
      'authorizedAtUtc': authorizedAtUtc.toIso8601String(),
      'completedAtUtc': completedAtUtc?.toIso8601String(),
      'diagnosticSha256': diagnosticSha256,
      'rolloutChecksum': rolloutChecksum,
      'artifacts': artifacts.map((artifact) => artifact.toJson()).toList(),
    };
    final checksum = sha256.convert(utf8.encode(jsonEncode(body))).toString();
    final target = File(
      p.join(
        _retentionDirectory.path,
        'receipt_${sequence.toString().padLeft(8, '0')}.json',
      ),
    );
    if (await target.exists()) throw StateError('legacy_retirement_collision');
    final temporary = File(
      p.join(
        _retentionDirectory.path,
        '.receipt_${sequence}_${pid}_${DateTime.now().microsecondsSinceEpoch}.tmp',
      ),
    );
    try {
      await temporary.create(exclusive: true);
      await durability.restrictFile(temporary);
      await temporary.writeAsString(
        jsonEncode({...body, 'checksum': checksum}),
        flush: true,
      );
      await durability.syncFile(temporary, fullBarrier: true);
      await durability.renameAndSync(
        source: temporary,
        targetPath: target.path,
      );
      return _readReceiptFile(target);
    } finally {
      if (await temporary.exists()) await temporary.delete();
    }
  }

  static Future<LegacyRetirementReceipt> _readReceiptFile(File file) async {
    final value = jsonDecode(await file.readAsString());
    if (value is! Map<String, dynamic>) {
      throw const FormatException('legacy_retirement_receipt');
    }
    final checksum = value['checksum'];
    final body = Map<String, dynamic>.from(value)..remove('checksum');
    if (checksum is! String ||
        !_sha256Pattern.hasMatch(checksum) ||
        sha256.convert(utf8.encode(jsonEncode(body))).toString() != checksum ||
        value['format'] != 'kelivo.database-v2-retention-receipt' ||
        value['formatVersion'] != 1) {
      throw const FormatException('legacy_retirement_receipt');
    }
    final sequence = value['sequence'];
    final state = LegacyRetirementState.values
        .where((candidate) => candidate.name == value['state'])
        .firstOrNull;
    final previousChecksum = value['previousChecksum'];
    final authorizedAt = DateTime.tryParse(
      value['authorizedAtUtc']?.toString() ?? '',
    );
    final completedRaw = value['completedAtUtc'];
    final completedAt = completedRaw == null
        ? null
        : DateTime.tryParse(completedRaw.toString());
    final diagnosticSha256 = value['diagnosticSha256'];
    final rolloutChecksum = value['rolloutChecksum'];
    final artifacts = _decodeArtifacts(value['artifacts']);
    if (sequence is! int ||
        sequence <= 0 ||
        state == null ||
        (previousChecksum != null &&
            (previousChecksum is! String ||
                !_sha256Pattern.hasMatch(previousChecksum))) ||
        authorizedAt == null ||
        !authorizedAt.isUtc ||
        (completedRaw != null && (completedAt == null || !completedAt.isUtc)) ||
        diagnosticSha256 is! String ||
        !_sha256Pattern.hasMatch(diagnosticSha256) ||
        rolloutChecksum is! String ||
        !_sha256Pattern.hasMatch(rolloutChecksum) ||
        (state == LegacyRetirementState.deleting && completedAt != null) ||
        (state == LegacyRetirementState.completed && completedAt == null)) {
      throw const FormatException('legacy_retirement_receipt');
    }
    return LegacyRetirementReceipt(
      sequence: sequence,
      state: state,
      previousChecksum: previousChecksum as String?,
      checksum: checksum,
      authorizedAtUtc: authorizedAt,
      completedAtUtc: completedAt,
      diagnosticSha256: diagnosticSha256,
      rolloutChecksum: rolloutChecksum,
      deletedArtifacts: artifacts,
    );
  }

  static List<LegacyArtifactDiagnostic> _decodeDiagnosticArtifacts(
    Object? value,
  ) {
    if (value is! Map<String, dynamic> ||
        value['format'] != 'kelivo.database-v2-retirement-diagnostic' ||
        value['formatVersion'] != 1) {
      throw const FormatException('legacy_retirement_diagnostic');
    }
    return _decodeArtifacts(value['artifacts']);
  }

  static List<LegacyArtifactDiagnostic> _decodeArtifacts(Object? value) {
    if (value is! List) {
      throw const FormatException('legacy_retirement_artifacts');
    }
    final artifacts = <LegacyArtifactDiagnostic>[];
    final names = <String>{};
    for (final item in value) {
      if (item is! Map ||
          item['name'] is! String ||
          !hiveArtifactNames.contains(item['name']) ||
          !names.add(item['name'] as String) ||
          item['bytes'] is! int ||
          (item['bytes'] as int) < 0 ||
          item['sha256'] is! String ||
          !_sha256Pattern.hasMatch(item['sha256'] as String)) {
        throw const FormatException('legacy_retirement_artifacts');
      }
      artifacts.add(
        LegacyArtifactDiagnostic(
          name: item['name'] as String,
          bytes: item['bytes'] as int,
          sha256: item['sha256'] as String,
        ),
      );
    }
    artifacts.sort((a, b) => a.name.compareTo(b.name));
    return List.unmodifiable(artifacts);
  }

  static bool _sameArtifacts(
    List<LegacyArtifactDiagnostic> left,
    List<LegacyArtifactDiagnostic> right,
  ) {
    if (left.length != right.length) return false;
    for (var index = 0; index < left.length; index++) {
      final a = left[index];
      final b = right[index];
      if (a.name != b.name || a.bytes != b.bytes || a.sha256 != b.sha256) {
        return false;
      }
    }
    return true;
  }

  static Future<String> _hashFile(File file) async =>
      (await sha256.bind(file.openRead()).first).toString();
}
