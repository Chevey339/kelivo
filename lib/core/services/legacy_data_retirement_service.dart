import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import 'backup/restore_durability.dart';

final class LegacyHiveArtifact {
  const LegacyHiveArtifact({required this.name, required this.bytes});

  final String name;
  final int bytes;

  Map<String, Object> toJson() => {'name': name, 'bytes': bytes};
}

enum LegacyRetirementState { deleting, completed }

final class LegacyRetirementReceipt {
  const LegacyRetirementReceipt({
    required this.sequence,
    required this.state,
    required this.previousChecksum,
    required this.checksum,
    required this.requestedAtUtc,
    required this.completedAtUtc,
    required this.deletedArtifacts,
  });

  final int sequence;
  final LegacyRetirementState state;
  final String? previousChecksum;
  final String checksum;
  final DateTime requestedAtUtc;
  final DateTime? completedAtUtc;
  final List<LegacyHiveArtifact> deletedArtifacts;
}

/// Deletes only the frozen Hive artifact family after an explicit user action.
///
/// Migration admission is handled before the storage UI is available. The UI
/// decides whether to offer cleanup by combining rollout evidence with
/// [inspectHiveArtifacts]. This service keeps deletion crash-resumable, but it
/// deliberately has no retention-age, diagnostic-export, or rollout threshold:
/// once migration has completed, the retained Hive files belong to the user.
final class LegacyDataRetirementService {
  LegacyDataRetirementService(
    this.appDataDirectory, {
    RestoreDurability? durability,
    this.afterDeletingReceiptPublished,
    this.clock,
  }) : durability = durability ?? RestorePlatformDurability();

  static const hiveArtifactNames = <String>{
    'conversations.hive',
    'messages.hive',
    'tool_events_v1.hive',
  };
  static const _retentionDirectoryName = '.database_v2_retention';
  static final _checksumPattern = RegExp(r'^[0-9a-f]{64}$');
  static final _receiptPattern = RegExp(r'^receipt_(\d{8})\.json$');

  final Directory appDataDirectory;
  final RestoreDurability durability;
  final Future<void> Function()? afterDeletingReceiptPublished;
  final DateTime Function()? clock;

  Directory get _retentionDirectory =>
      Directory(p.join(appDataDirectory.path, _retentionDirectoryName));

  Future<List<LegacyHiveArtifact>> inspectHiveArtifacts() async {
    final artifacts = <LegacyHiveArtifact>[];
    for (final name in hiveArtifactNames.toList()..sort()) {
      final file = File(p.join(appDataDirectory.path, name));
      final type = await FileSystemEntity.type(file.path, followLinks: false);
      if (type == FileSystemEntityType.notFound) continue;
      if (type != FileSystemEntityType.file) {
        throw StateError('legacy_retirement_artifact_type');
      }
      artifacts.add(LegacyHiveArtifact(name: name, bytes: await file.length()));
    }
    return List.unmodifiable(artifacts);
  }

  Future<LegacyRetirementReceipt> retireHiveArtifacts() async {
    final existing = await readReceipt();
    late final LegacyRetirementReceipt deleting;
    if (existing?.state == LegacyRetirementState.deleting) {
      deleting = existing!;
    } else {
      final artifacts = await inspectHiveArtifacts();
      if (artifacts.isEmpty && existing != null) return existing;
      deleting = await _publishReceipt(
        sequence: (existing?.sequence ?? 0) + 1,
        state: LegacyRetirementState.deleting,
        previousChecksum: existing?.checksum,
        requestedAtUtc: (clock?.call() ?? DateTime.now()).toUtc(),
        completedAtUtc: null,
        artifacts: artifacts,
      );
      await afterDeletingReceiptPublished?.call();
    }

    for (final artifact in deleting.deletedArtifacts) {
      final file = File(p.join(appDataDirectory.path, artifact.name));
      final type = await FileSystemEntity.type(file.path, followLinks: false);
      if (type == FileSystemEntityType.notFound) continue;
      if (type != FileSystemEntityType.file ||
          await file.length() != artifact.bytes) {
        throw StateError('legacy_retirement_artifact_changed');
      }
      await file.delete();
      await durability.syncDirectory(appDataDirectory, fullBarrier: true);
    }
    return _publishReceipt(
      sequence: deleting.sequence + 1,
      state: LegacyRetirementState.completed,
      previousChecksum: deleting.checksum,
      requestedAtUtc: deleting.requestedAtUtc,
      completedAtUtc: (clock?.call() ?? DateTime.now()).toUtc(),
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

  Future<LegacyRetirementReceipt> _publishReceipt({
    required int sequence,
    required LegacyRetirementState state,
    required String? previousChecksum,
    required DateTime requestedAtUtc,
    required DateTime? completedAtUtc,
    required List<LegacyHiveArtifact> artifacts,
  }) async {
    if (!await _retentionDirectory.exists()) {
      await _retentionDirectory.create(recursive: true);
      await durability.restrictDirectory(_retentionDirectory);
      await durability.syncDirectory(appDataDirectory, fullBarrier: true);
    }
    final body = <String, Object?>{
      'format': 'kelivo.database-v2-retention-receipt',
      'formatVersion': 2,
      'sequence': sequence,
      'state': state.name,
      'previousChecksum': previousChecksum,
      'requestedAtUtc': requestedAtUtc.toIso8601String(),
      'completedAtUtc': completedAtUtc?.toIso8601String(),
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
        !_checksumPattern.hasMatch(checksum) ||
        sha256.convert(utf8.encode(jsonEncode(body))).toString() != checksum ||
        value['format'] != 'kelivo.database-v2-retention-receipt' ||
        value['formatVersion'] != 2) {
      throw const FormatException('legacy_retirement_receipt');
    }
    final sequence = value['sequence'];
    final state = LegacyRetirementState.values
        .where((candidate) => candidate.name == value['state'])
        .firstOrNull;
    final previousChecksum = value['previousChecksum'];
    final requestedAt = DateTime.tryParse(
      value['requestedAtUtc']?.toString() ?? '',
    );
    final completedRaw = value['completedAtUtc'];
    final completedAt = completedRaw == null
        ? null
        : DateTime.tryParse(completedRaw.toString());
    final artifacts = _decodeArtifacts(value['artifacts']);
    if (sequence is! int ||
        sequence <= 0 ||
        state == null ||
        (previousChecksum != null &&
            (previousChecksum is! String ||
                !_checksumPattern.hasMatch(previousChecksum))) ||
        requestedAt == null ||
        !requestedAt.isUtc ||
        (completedRaw != null && (completedAt == null || !completedAt.isUtc)) ||
        (state == LegacyRetirementState.deleting && completedAt != null) ||
        (state == LegacyRetirementState.completed && completedAt == null)) {
      throw const FormatException('legacy_retirement_receipt');
    }
    return LegacyRetirementReceipt(
      sequence: sequence,
      state: state,
      previousChecksum: previousChecksum as String?,
      checksum: checksum,
      requestedAtUtc: requestedAt,
      completedAtUtc: completedAt,
      deletedArtifacts: artifacts,
    );
  }

  static List<LegacyHiveArtifact> _decodeArtifacts(Object? value) {
    if (value is! List) {
      throw const FormatException('legacy_retirement_artifacts');
    }
    final artifacts = <LegacyHiveArtifact>[];
    final names = <String>{};
    for (final item in value) {
      if (item is! Map ||
          item['name'] is! String ||
          !hiveArtifactNames.contains(item['name']) ||
          !names.add(item['name'] as String) ||
          item['bytes'] is! int ||
          (item['bytes'] as int) < 0) {
        throw const FormatException('legacy_retirement_artifacts');
      }
      artifacts.add(
        LegacyHiveArtifact(
          name: item['name'] as String,
          bytes: item['bytes'] as int,
        ),
      );
    }
    artifacts.sort((a, b) => a.name.compareTo(b.name));
    return List.unmodifiable(artifacts);
  }
}
