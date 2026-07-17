import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import 'restore_durability.dart';

enum RestoreSettingsColdAckExpected { target, before }

final _runIdPattern = RegExp(r'^[a-f0-9]{32}$');
final _sha256Pattern = RegExp(r'^[a-f0-9]{64}$');

/// Durable coordination token requiring a different native process and lease
/// instance to confirm terminal settings before business persistence can open.
final class RestoreSettingsColdAck {
  RestoreSettingsColdAck({
    required this.runId,
    required this.terminalReceiptChecksum,
    required this.expected,
    required this.leaseInstanceId,
    required this.processId,
  }) {
    _validateRunId(runId, parsed: false);
    _validateSha256(terminalReceiptChecksum, parsed: false);
    _validateLeaseInstanceId(leaseInstanceId, parsed: false);
    _validateProcessId(processId, parsed: false);
  }

  RestoreSettingsColdAck._parsed({
    required this.runId,
    required this.terminalReceiptChecksum,
    required this.expected,
    required this.leaseInstanceId,
    required this.processId,
  });

  static const version = 1;

  final String runId;
  final String terminalReceiptChecksum;
  final RestoreSettingsColdAckExpected expected;
  final String leaseInstanceId;
  final int processId;

  String get checksum =>
      sha256.convert(utf8.encode(jsonEncode(_payloadJson()))).toString();

  Map<String, dynamic> toJson() => {..._payloadJson(), 'checksum': checksum};

  factory RestoreSettingsColdAck.fromJson(Map<dynamic, dynamic> source) {
    const expectedKeys = {
      'version',
      'runId',
      'terminalReceiptChecksum',
      'expected',
      'leaseInstanceId',
      'processId',
      'checksum',
    };
    try {
      if (source.keys.any((key) => key is! String) ||
          source.length != expectedKeys.length ||
          !source.keys.toSet().containsAll(expectedKeys)) {
        throw const FormatException('restore_settings_cold_ack_fields');
      }
      final json = source.cast<String, dynamic>();
      final rawVersion = json['version'];
      final runId = json['runId'];
      final receiptChecksum = json['terminalReceiptChecksum'];
      final rawExpected = json['expected'];
      final leaseInstanceId = json['leaseInstanceId'];
      final processId = json['processId'];
      final rawChecksum = json['checksum'];
      if (rawVersion is! int ||
          rawVersion != version ||
          runId is! String ||
          receiptChecksum is! String ||
          rawExpected is! String ||
          leaseInstanceId is! String ||
          processId is! int ||
          rawChecksum is! String) {
        throw const FormatException('restore_settings_cold_ack_types');
      }
      _validateRunId(runId, parsed: true);
      _validateSha256(receiptChecksum, parsed: true);
      _validateLeaseInstanceId(leaseInstanceId, parsed: true);
      _validateProcessId(processId, parsed: true);
      _validateSha256(rawChecksum, parsed: true);
      final expected = RestoreSettingsColdAckExpected.values.firstWhere(
        (value) => value.name == rawExpected,
        orElse: () =>
            throw const FormatException('restore_settings_cold_ack_expected'),
      );
      final ack = RestoreSettingsColdAck._parsed(
        runId: runId,
        terminalReceiptChecksum: receiptChecksum,
        expected: expected,
        leaseInstanceId: leaseInstanceId,
        processId: processId,
      );
      if (ack.checksum != rawChecksum) {
        throw const FormatException('restore_settings_cold_ack_checksum');
      }
      return ack;
    } on FormatException {
      rethrow;
    } catch (_) {
      throw const FormatException('restore_settings_cold_ack');
    }
  }

  Map<String, dynamic> _payloadJson() => {
    'version': version,
    'runId': runId,
    'terminalReceiptChecksum': terminalReceiptChecksum,
    'expected': expected.name,
    'leaseInstanceId': leaseInstanceId,
    'processId': processId,
  };
}

/// Owns the canonical `settings_cold_ack.json` inside one restore run.
///
/// Replacement first durably removes the old coordination token, then
/// publishes a new one. Ack absence is deliberately safe: the terminal run
/// remains active and the startup gate requires another cold verification.
final class RestoreSettingsColdAckStore {
  RestoreSettingsColdAckStore({
    required Directory runDirectory,
    RestoreDurability? durability,
  }) : runDirectory = Directory(p.normalize(p.absolute(runDirectory.path))),
       durability = durability ?? RestorePlatformDurability(),
       runId = _runIdFromPath(runDirectory.path);

  static const fileName = 'settings_cold_ack.json';
  static const _maximumBytes = 16 * 1024;
  static final _temporaryPattern = RegExp(
    r'^settings_cold_ack\.json\.[0-9]+_[0-9]+_[0-9]+\.tmp$',
  );

  final Directory runDirectory;
  final RestoreDurability durability;
  final String runId;

  File get file => File(p.join(runDirectory.path, fileName));

  Future<RestoreSettingsColdAck?> read() async {
    await _requireRunDirectory();
    final hasAck = await _discardUnpublishedTemporaries();
    if (!hasAck) return null;
    return _readAckFile(file);
  }

  Future<RestoreSettingsColdAck> writeOrReplace({
    required String terminalReceiptChecksum,
    required RestoreSettingsColdAckExpected expected,
    required String leaseInstanceId,
    required int processId,
  }) async {
    final requested = RestoreSettingsColdAck(
      runId: runId,
      terminalReceiptChecksum: terminalReceiptChecksum,
      expected: expected,
      leaseInstanceId: leaseInstanceId,
      processId: processId,
    );
    await _requireRunDirectory();
    final hasAck = await _discardUnpublishedTemporaries();
    final existing = hasAck ? await _readAckFile(file) : null;
    if (existing != null) {
      if (existing.terminalReceiptChecksum != terminalReceiptChecksum ||
          existing.expected != expected) {
        throw StateError('restore_settings_cold_ack_collision');
      }
      if (existing.leaseInstanceId == leaseInstanceId &&
          existing.processId == requested.processId) {
        return existing;
      }
    }

    final encoded = Uint8List.fromList(
      utf8.encode(jsonEncode(requested.toJson())),
    );
    if (encoded.length > _maximumBytes) {
      throw StateError('restore_settings_cold_ack_size');
    }
    final temporary = await _createUniqueTemporary();
    try {
      await durability.restrictFile(temporary);
      await temporary.writeAsBytes(encoded, flush: true);
      await durability.syncFile(temporary, fullBarrier: true);
      final staged = await _readAckFile(temporary);
      if (!_sameAck(staged, requested)) {
        throw StateError('restore_settings_cold_ack_staging');
      }

      if (existing != null) {
        await file.delete();
        await durability.syncDirectory(runDirectory, fullBarrier: true);
      }
      await durability.renameAndSync(source: temporary, targetPath: file.path);
      final published = await _readAckFile(file);
      if (!_sameAck(published, requested)) {
        throw StateError('restore_settings_cold_ack_publish');
      }
      return published;
    } finally {
      if (await FileSystemEntity.type(temporary.path, followLinks: false) ==
          FileSystemEntityType.file) {
        await temporary.delete();
        await durability.syncDirectory(runDirectory, fullBarrier: true);
      }
    }
  }

  Future<void> _requireRunDirectory() async {
    if (await FileSystemEntity.type(runDirectory.path, followLinks: false) !=
        FileSystemEntityType.directory) {
      throw StateError('restore_settings_cold_ack_run_directory');
    }
    if (_runIdFromPath(runDirectory.path) != runId) {
      throw StateError('restore_settings_cold_ack_run_identity');
    }
  }

  Future<bool> _discardUnpublishedTemporaries() async {
    var hasAck = false;
    final temporaries = <File>[];
    await for (final entity in runDirectory.list(followLinks: false)) {
      final name = p.basename(entity.path);
      if (name != fileName && !name.startsWith('$fileName.')) continue;
      final type = await FileSystemEntity.type(entity.path, followLinks: false);
      if (name == fileName) {
        if (hasAck || type != FileSystemEntityType.file) {
          throw StateError('restore_settings_cold_ack_file');
        }
        hasAck = true;
      } else if (_temporaryPattern.hasMatch(name) &&
          type == FileSystemEntityType.file) {
        temporaries.add(File(entity.path));
      } else {
        throw StateError('restore_settings_cold_ack_intermediate');
      }
    }
    for (final temporary in temporaries) {
      await temporary.delete();
    }
    if (temporaries.isNotEmpty) {
      await durability.syncDirectory(runDirectory, fullBarrier: true);
    }
    return hasAck;
  }

  Future<File> _createUniqueTemporary() async {
    for (var attempt = 0; attempt < 16; attempt++) {
      final temporary = File(
        p.join(
          runDirectory.path,
          '$fileName.${DateTime.now().microsecondsSinceEpoch}_${pid}_$attempt.tmp',
        ),
      );
      try {
        await temporary.create(exclusive: true);
        return temporary;
      } on PathExistsException {
        continue;
      } on FileSystemException {
        if (await FileSystemEntity.type(temporary.path, followLinks: false) !=
            FileSystemEntityType.notFound) {
          continue;
        }
        rethrow;
      }
    }
    throw StateError('restore_settings_cold_ack_temp_collision');
  }

  Future<RestoreSettingsColdAck> _readAckFile(File source) async {
    if (await FileSystemEntity.type(source.path, followLinks: false) !=
        FileSystemEntityType.file) {
      throw const FormatException('restore_settings_cold_ack_file');
    }
    final expectedLength = await source.length();
    if (expectedLength <= 0 || expectedLength > _maximumBytes) {
      throw const FormatException('restore_settings_cold_ack_size');
    }
    final handle = await source.open(mode: FileMode.read);
    final builder = BytesBuilder(copy: false);
    try {
      while (builder.length <= _maximumBytes) {
        final chunk = await handle.read(_maximumBytes + 1 - builder.length);
        if (chunk.isEmpty) break;
        builder.add(chunk);
      }
    } finally {
      await handle.close();
    }
    final bytes = builder.takeBytes();
    if (bytes.length != expectedLength || bytes.length > _maximumBytes) {
      throw const FormatException('restore_settings_cold_ack_changed');
    }
    if (await FileSystemEntity.type(source.path, followLinks: false) !=
        FileSystemEntityType.file) {
      throw const FormatException('restore_settings_cold_ack_changed');
    }
    final dynamic decoded;
    try {
      decoded = jsonDecode(utf8.decode(bytes));
    } on FormatException {
      throw const FormatException('restore_settings_cold_ack_json');
    }
    if (decoded is! Map) {
      throw const FormatException('restore_settings_cold_ack_json');
    }
    final ack = RestoreSettingsColdAck.fromJson(decoded);
    if (ack.runId != runId) {
      throw const FormatException('restore_settings_cold_ack_identity');
    }
    final canonical = utf8.encode(jsonEncode(ack.toJson()));
    if (!_sameBytes(bytes, canonical)) {
      throw const FormatException('restore_settings_cold_ack_canonical');
    }
    return ack;
  }
}

String _runIdFromPath(String path) {
  final match = RegExp(
    r'^run_([a-f0-9]{32})$',
  ).firstMatch(p.basename(p.normalize(p.absolute(path))));
  if (match == null) throw ArgumentError.value(path, 'runDirectory');
  return match[1]!;
}

void _validateRunId(String value, {required bool parsed}) {
  if (_runIdPattern.hasMatch(value)) return;
  if (parsed) throw const FormatException('restore_settings_cold_ack_run_id');
  throw ArgumentError.value(value, 'runId');
}

void _validateSha256(String value, {required bool parsed}) {
  if (_sha256Pattern.hasMatch(value)) return;
  if (parsed) {
    throw const FormatException('restore_settings_cold_ack_hash');
  }
  throw ArgumentError.value(value, 'terminalReceiptChecksum');
}

void _validateLeaseInstanceId(String value, {required bool parsed}) {
  if (_runIdPattern.hasMatch(value)) return;
  if (parsed) {
    throw const FormatException('restore_settings_cold_ack_lease');
  }
  throw ArgumentError.value(value, 'leaseInstanceId');
}

void _validateProcessId(int value, {required bool parsed}) {
  if (value > 0) return;
  if (parsed) {
    throw const FormatException('restore_settings_cold_ack_process');
  }
  throw ArgumentError.value(value, 'processId');
}

bool _sameAck(RestoreSettingsColdAck left, RestoreSettingsColdAck right) =>
    left.checksum == right.checksum;

bool _sameBytes(List<int> left, List<int> right) {
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index++) {
    if (left[index] != right[index]) return false;
  }
  return true;
}
