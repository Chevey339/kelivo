import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import 'restore_bundle_staging.dart';
import 'restore_workspace_lock.dart';

enum RestoreComponent { settings, database, assets }

const restoreWorkspaceRootName = RestoreWorkspaceLock.workspaceRootName;

enum RestoreReceiptState {
  prepared,
  oldRenamed,
  newInstalled,
  verified,
  committed,
  rolledBack,
}

const _componentOrder = [
  RestoreComponent.settings,
  RestoreComponent.database,
  RestoreComponent.assets,
];
final _runIdPattern = RegExp(r'^[a-f0-9]{32}$');
final _sha256Pattern = RegExp(r'^[a-f0-9]{64}$');
const _maximumReceiptBytes = 64 * 1024;
const _maximumReceiptCount = 5;

final class RestoreReceipt {
  RestoreReceipt._({
    required this.runId,
    required this.sequence,
    required this.state,
    required this.previousChecksum,
    required this.selectedComponents,
    required this.createdAtUtc,
    required this.candidateManifestSha256,
    required this.previousManifestSha256,
  });

  static const format = 'kelivo.restore-receipt';
  static const formatVersion = 1;
  static const candidateManifestPath = 'candidate/manifest.json';
  static const previousManifestPath = 'previous/manifest.json';

  final String runId;
  final int sequence;
  final RestoreReceiptState state;
  final String? previousChecksum;
  final Set<RestoreComponent> selectedComponents;
  final DateTime createdAtUtc;
  final String candidateManifestSha256;
  final String? previousManifestSha256;

  factory RestoreReceipt.prepared({
    required String runId,
    required DateTime createdAtUtc,
    required bool restoreChats,
    required bool restoreFiles,
    required String candidateManifestSha256,
  }) {
    _validateRunId(runId, parsed: false);
    _validateHash(candidateManifestSha256, 'candidateManifestSha256');
    if (!createdAtUtc.isUtc) {
      throw ArgumentError.value(createdAtUtc, 'createdAtUtc', 'must be UTC');
    }
    return RestoreReceipt._(
      runId: runId,
      sequence: 1,
      state: RestoreReceiptState.prepared,
      previousChecksum: null,
      selectedComponents: Set.unmodifiable({
        RestoreComponent.settings,
        if (restoreChats) RestoreComponent.database,
        if (restoreFiles) RestoreComponent.assets,
      }),
      createdAtUtc: createdAtUtc,
      candidateManifestSha256: candidateManifestSha256,
      previousManifestSha256: null,
    );
  }

  factory RestoreReceipt.fromJson(Map<dynamic, dynamic> source) {
    const expectedKeys = {
      'format',
      'formatVersion',
      'runId',
      'sequence',
      'state',
      'previousChecksum',
      'selectedComponents',
      'createdAtUtc',
      'candidateManifestPath',
      'candidateManifestSha256',
      'previousManifestPath',
      'previousManifestSha256',
      'checksum',
    };
    try {
      if (source.keys.any((key) => key is! String) ||
          source.length != expectedKeys.length ||
          !source.keys.toSet().containsAll(expectedKeys)) {
        throw const FormatException('restore_receipt_fields');
      }
      final json = source.cast<String, dynamic>();
      if (json['format'] != format ||
          json['formatVersion'] != formatVersion ||
          json['candidateManifestPath'] != candidateManifestPath ||
          json['previousManifestPath'] != previousManifestPath) {
        throw const FormatException('restore_receipt_format');
      }

      final runId = json['runId'];
      final sequence = json['sequence'];
      final rawState = json['state'];
      final rawPreviousChecksum = json['previousChecksum'];
      final rawComponents = json['selectedComponents'];
      final rawCreatedAt = json['createdAtUtc'];
      final candidateHash = json['candidateManifestSha256'];
      final rawPreviousManifestHash = json['previousManifestSha256'];
      final rawChecksum = json['checksum'];
      if (runId is! String ||
          sequence is! int ||
          rawState is! String ||
          (rawPreviousChecksum != null && rawPreviousChecksum is! String) ||
          rawComponents is! List ||
          rawComponents.any((value) => value is! String) ||
          rawCreatedAt is! String ||
          candidateHash is! String ||
          (rawPreviousManifestHash != null &&
              rawPreviousManifestHash is! String) ||
          rawChecksum is! String) {
        throw const FormatException('restore_receipt_types');
      }

      _validateRunId(runId, parsed: true);
      _validateHash(candidateHash, 'candidateManifestSha256');
      if (rawPreviousChecksum != null) {
        _validateHash(rawPreviousChecksum, 'previousChecksum');
      }
      if (rawPreviousManifestHash != null) {
        _validateHash(rawPreviousManifestHash, 'previousManifestSha256');
      }
      _validateHash(rawChecksum, 'checksum');

      final state = RestoreReceiptState.values.firstWhere(
        (value) => value.name == rawState,
        orElse: () => throw const FormatException('restore_receipt_state'),
      );
      final components = <RestoreComponent>{};
      for (final raw in rawComponents.cast<String>()) {
        final component = RestoreComponent.values.firstWhere(
          (value) => value.name == raw,
          orElse: () =>
              throw const FormatException('restore_receipt_component'),
        );
        if (!components.add(component)) {
          throw const FormatException('restore_receipt_components');
        }
      }
      final canonicalComponents = _orderedComponentNames(components);
      if (!_sameStrings(rawComponents.cast<String>(), canonicalComponents) ||
          !components.contains(RestoreComponent.settings)) {
        throw const FormatException('restore_receipt_components');
      }

      final createdAtUtc = DateTime.parse(rawCreatedAt);
      if (!createdAtUtc.isUtc ||
          createdAtUtc.toIso8601String() != rawCreatedAt) {
        throw const FormatException('restore_receipt_created_at');
      }
      _validateStateFields(
        sequence: sequence,
        state: state,
        previousChecksum: rawPreviousChecksum,
        previousManifestSha256: rawPreviousManifestHash,
      );
      final receipt = RestoreReceipt._(
        runId: runId,
        sequence: sequence,
        state: state,
        previousChecksum: rawPreviousChecksum,
        selectedComponents: Set.unmodifiable(components),
        createdAtUtc: createdAtUtc,
        candidateManifestSha256: candidateHash,
        previousManifestSha256: rawPreviousManifestHash,
      );
      if (receipt.checksum != rawChecksum) {
        throw const FormatException('restore_receipt_checksum');
      }
      return receipt;
    } on FormatException {
      rethrow;
    } catch (_) {
      throw const FormatException('restore_receipt');
    }
  }

  String get checksum {
    return sha256.convert(utf8.encode(jsonEncode(_payloadJson()))).toString();
  }

  Map<String, dynamic> toJson() => {..._payloadJson(), 'checksum': checksum};

  RestoreReceipt advance(
    RestoreReceiptState nextState, {
    String? previousManifestSha256,
  }) {
    if (!_canAdvanceTo(nextState)) {
      throw StateError('restore_receipt_transition:${state.name}');
    }
    final nextPreviousManifest =
        previousManifestSha256 ?? this.previousManifestSha256;
    if (nextState == RestoreReceiptState.oldRenamed) {
      if (this.previousManifestSha256 != null ||
          previousManifestSha256 == null) {
        throw StateError('restore_receipt_previous_manifest');
      }
      _validateHash(previousManifestSha256, 'previousManifestSha256');
    } else if (previousManifestSha256 != null &&
        previousManifestSha256 != this.previousManifestSha256) {
      throw StateError('restore_receipt_previous_manifest');
    }
    _validateStateFields(
      sequence: sequence + 1,
      state: nextState,
      previousChecksum: checksum,
      previousManifestSha256: nextPreviousManifest,
    );
    return RestoreReceipt._(
      runId: runId,
      sequence: sequence + 1,
      state: nextState,
      previousChecksum: checksum,
      selectedComponents: selectedComponents,
      createdAtUtc: createdAtUtc,
      candidateManifestSha256: candidateManifestSha256,
      previousManifestSha256: nextPreviousManifest,
    );
  }

  bool _canAdvanceTo(RestoreReceiptState nextState) {
    return switch (state) {
      RestoreReceiptState.prepared =>
        nextState == RestoreReceiptState.oldRenamed,
      RestoreReceiptState.oldRenamed =>
        nextState == RestoreReceiptState.newInstalled ||
            nextState == RestoreReceiptState.rolledBack,
      RestoreReceiptState.newInstalled =>
        nextState == RestoreReceiptState.verified ||
            nextState == RestoreReceiptState.rolledBack,
      RestoreReceiptState.verified =>
        nextState == RestoreReceiptState.committed ||
            nextState == RestoreReceiptState.rolledBack,
      RestoreReceiptState.committed || RestoreReceiptState.rolledBack => false,
    };
  }

  Map<String, dynamic> _payloadJson() => {
    'format': format,
    'formatVersion': formatVersion,
    'runId': runId,
    'sequence': sequence,
    'state': state.name,
    'previousChecksum': previousChecksum,
    'selectedComponents': _orderedComponentNames(selectedComponents),
    'createdAtUtc': createdAtUtc.toIso8601String(),
    'candidateManifestPath': candidateManifestPath,
    'candidateManifestSha256': candidateManifestSha256,
    'previousManifestPath': previousManifestPath,
    'previousManifestSha256': previousManifestSha256,
  };

  static void _validateStateFields({
    required int sequence,
    required RestoreReceiptState state,
    required String? previousChecksum,
    required String? previousManifestSha256,
  }) {
    if (sequence < 1) throw const FormatException('restore_receipt_sequence');
    if (state == RestoreReceiptState.prepared) {
      if (sequence != 1 ||
          previousChecksum != null ||
          previousManifestSha256 != null) {
        throw const FormatException('restore_receipt_prepared');
      }
      return;
    }
    if (sequence < 2 ||
        previousChecksum == null ||
        previousManifestSha256 == null) {
      throw const FormatException('restore_receipt_continuation');
    }
  }
}

final class RestoreReceiptStore {
  RestoreReceiptStore({required this.appDataDirectory, required this.runId})
    : _workspaceLock = RestoreWorkspaceLock(
        appDataDirectory: appDataDirectory,
      ) {
    _validateRunId(runId, parsed: false);
  }

  static const workspaceRootName = restoreWorkspaceRootName;

  final Directory appDataDirectory;
  final String runId;
  final RestoreWorkspaceLock _workspaceLock;

  Directory get workspaceRoot => _workspaceLock.workspaceRoot;

  Directory get runDirectory =>
      Directory(p.join(workspaceRoot.path, 'run_$runId'));

  Directory get receiptDirectory =>
      Directory(p.join(runDirectory.path, 'receipts'));

  Future<RestoreReceipt?> readLatest() =>
      _workspaceLock.synchronized(_readLatestUnlocked);

  Future<void> publish(RestoreReceipt receipt) async {
    if (receipt.runId != runId) throw StateError('restore_receipt_run_id');
    await _workspaceLock.synchronized(() async {
      await _requireExclusiveRunWorkspace();
      final initialReceiptDirectoryType = await FileSystemEntity.type(
        receiptDirectory.path,
        followLinks: false,
      );
      final latest = await _readLatestUnlocked();
      if (latest != null && latest.sequence == receipt.sequence) {
        if (receipt.sequence == 1) {
          await _validatePreparedCandidate(receipt);
        }
        if (latest.checksum == receipt.checksum) return;
        throw StateError('restore_receipt_collision');
      }
      if (latest == null) {
        if (receipt.sequence != 1 ||
            receipt.state != RestoreReceiptState.prepared) {
          throw StateError('restore_receipt_initial_sequence');
        }
        if (initialReceiptDirectoryType != FileSystemEntityType.notFound) {
          throw StateError('restore_receipt_initial_directory');
        }
        await _validateInitialRunTopology();
        await _validatePreparedCandidate(receipt);
      } else {
        _validateContinuation(latest, receipt);
      }

      if (!await _validateExistingDirectory(runDirectory)) {
        throw StateError('restore_receipt_run_directory');
      }
      await _ensureSafeDirectory(receiptDirectory);
      final target = File(
        p.join(receiptDirectory.path, _receiptFileName(receipt.sequence)),
      );
      if (await FileSystemEntity.type(target.path, followLinks: false) !=
          FileSystemEntityType.notFound) {
        throw StateError('restore_receipt_collision');
      }
      final temporary = File(
        '${target.path}.${DateTime.now().microsecondsSinceEpoch}_$pid.tmp',
      );
      try {
        final encoded = utf8.encode(jsonEncode(receipt.toJson()));
        if (encoded.length > _maximumReceiptBytes) {
          throw StateError('restore_receipt_size');
        }
        await temporary.writeAsBytes(encoded, flush: true);
        final staged = await _readReceiptFile(temporary);
        if (staged.checksum != receipt.checksum) {
          throw StateError('restore_receipt_staging');
        }

        // Reserve the final sequence atomically instead of renaming over an
        // existing record. A crash during the following write deliberately
        // leaves a corrupt final record so startup fails closed rather than
        // falling back to an older state. Directory fsync remains part of the
        // five-platform crash-durability acceptance work.
        await target.create(exclusive: true);
        await target.writeAsBytes(encoded, flush: true);
        final published = await _readReceiptFile(target);
        if (published.checksum != receipt.checksum) {
          throw StateError('restore_receipt_publish');
        }
      } finally {
        if (await temporary.exists()) await temporary.delete();
      }
    });
  }

  Future<void> _requireExclusiveRunWorkspace() async {
    var foundRun = false;
    var foundActiveRun = false;
    await for (final entity in workspaceRoot.list(followLinks: false)) {
      final name = p.basename(entity.path);
      final type = await FileSystemEntity.type(entity.path, followLinks: false);
      if (name == RestoreWorkspaceLock.lockFileName) {
        if (type != FileSystemEntityType.file) {
          throw StateError('restore_receipt_lock');
        }
        continue;
      }
      if (name == RestoreWorkspaceLock.activeRunFileName &&
          type == FileSystemEntityType.file) {
        final activeRunFile = File(entity.path);
        if (foundActiveRun ||
            await activeRunFile.length() != 32 ||
            await activeRunFile.readAsString() != runId) {
          throw StateError('restore_receipt_active_run');
        }
        foundActiveRun = true;
        continue;
      }
      if (name == 'run_$runId' && type == FileSystemEntityType.directory) {
        if (foundRun) throw StateError('restore_receipt_run_directory');
        foundRun = true;
        continue;
      }
      throw StateError('restore_receipt_workspace_entry');
    }
    if (!foundRun) throw StateError('restore_receipt_run_directory');
    if (!foundActiveRun) throw StateError('restore_receipt_active_run');
  }

  Future<void> _validatePreparedCandidate(RestoreReceipt receipt) async {
    final candidateDirectory = Directory(
      p.join(runDirectory.path, 'candidate'),
    );
    final candidate = await RestoreBundleStaging.validateExistingCandidate(
      candidateDirectory: candidateDirectory,
      expectedManifestSha256: receipt.candidateManifestSha256,
    );
    if ((receipt.selectedComponents.contains(RestoreComponent.database) &&
            !candidate.includeChats) ||
        (receipt.selectedComponents.contains(RestoreComponent.assets) &&
            !candidate.includeFiles)) {
      throw StateError('restore_receipt_candidate_selection');
    }
  }

  Future<void> _validateInitialRunTopology() async {
    var foundCandidate = false;
    await for (final entity in runDirectory.list(followLinks: false)) {
      final name = p.basename(entity.path);
      final type = await FileSystemEntity.type(entity.path, followLinks: false);
      if (name == 'candidate' && type == FileSystemEntityType.directory) {
        if (foundCandidate) {
          throw StateError('restore_receipt_initial_run');
        }
        foundCandidate = true;
        continue;
      }
      throw StateError('restore_receipt_initial_run');
    }
    if (!foundCandidate) throw StateError('restore_receipt_initial_run');
  }

  Future<RestoreReceipt?> _readLatestUnlocked() async {
    if (!await _validateExistingDirectory(workspaceRoot) ||
        !await _validateExistingDirectory(runDirectory) ||
        !await _validateExistingDirectory(receiptDirectory)) {
      return null;
    }

    final receiptFiles = <({File file, int sequence})>[];
    await for (final entity in receiptDirectory.list(followLinks: false)) {
      final entityType = await FileSystemEntity.type(
        entity.path,
        followLinks: false,
      );
      final name = p.basename(entity.path);
      if (entityType == FileSystemEntityType.file && name.endsWith('.tmp')) {
        continue;
      }
      final match = RegExp(r'^receipt_(\d{16})\.json$').firstMatch(name);
      if (entityType != FileSystemEntityType.file || match == null) {
        throw const FormatException('restore_receipt_directory_entry');
      }
      receiptFiles.add((
        file: File(entity.path),
        sequence: int.parse(match[1]!),
      ));
      if (receiptFiles.length > _maximumReceiptCount) {
        throw const FormatException('restore_receipt_count');
      }
    }
    if (receiptFiles.isEmpty) return null;
    receiptFiles.sort((a, b) => a.sequence.compareTo(b.sequence));

    RestoreReceipt? previous;
    for (var index = 0; index < receiptFiles.length; index++) {
      final entry = receiptFiles[index];
      final expectedSequence = index + 1;
      if (entry.sequence != expectedSequence) {
        throw StateError('restore_receipt_sequence_gap');
      }
      final receipt = await _readReceiptFile(entry.file);
      if (receipt.sequence != entry.sequence || receipt.runId != runId) {
        throw const FormatException('restore_receipt_identity');
      }
      if (previous == null) {
        if (receipt.state != RestoreReceiptState.prepared ||
            receipt.previousChecksum != null) {
          throw const FormatException('restore_receipt_initial');
        }
      } else {
        _validateContinuation(previous, receipt);
      }
      previous = receipt;
    }
    return previous;
  }

  void _validateContinuation(RestoreReceipt previous, RestoreReceipt next) {
    if (next.sequence != previous.sequence + 1 ||
        next.previousChecksum != previous.checksum ||
        !previous._canAdvanceTo(next.state) ||
        next.runId != previous.runId ||
        next.createdAtUtc != previous.createdAtUtc ||
        next.candidateManifestSha256 != previous.candidateManifestSha256 ||
        !_sameComponents(
          next.selectedComponents,
          previous.selectedComponents,
        ) ||
        (previous.previousManifestSha256 != null &&
            next.previousManifestSha256 != previous.previousManifestSha256) ||
        (previous.previousManifestSha256 == null &&
            next.state != RestoreReceiptState.oldRenamed)) {
      throw StateError('restore_receipt_chain');
    }
  }

  static Future<void> _ensureSafeDirectory(Directory directory) async {
    final type = await FileSystemEntity.type(
      directory.path,
      followLinks: false,
    );
    if (type == FileSystemEntityType.link ||
        (type != FileSystemEntityType.notFound &&
            type != FileSystemEntityType.directory)) {
      throw StateError('restore_receipt_directory');
    }
    if (type == FileSystemEntityType.notFound) {
      await directory.create(recursive: true);
    }
    if (await FileSystemEntity.type(directory.path, followLinks: false) !=
        FileSystemEntityType.directory) {
      throw StateError('restore_receipt_directory');
    }
  }

  static Future<bool> _validateExistingDirectory(Directory directory) async {
    final type = await FileSystemEntity.type(
      directory.path,
      followLinks: false,
    );
    if (type == FileSystemEntityType.notFound) return false;
    if (type != FileSystemEntityType.directory) {
      throw StateError('restore_receipt_directory');
    }
    return true;
  }

  static String _receiptFileName(int sequence) {
    final digits = sequence.toString().padLeft(16, '0');
    if (digits.length != 16) throw StateError('restore_receipt_sequence');
    return 'receipt_$digits.json';
  }
}

Future<RestoreReceipt> _readReceiptFile(File file) async {
  final handle = await file.open(mode: FileMode.read);
  final bytes = <int>[];
  try {
    while (bytes.length <= _maximumReceiptBytes) {
      final chunk = await handle.read(_maximumReceiptBytes + 1 - bytes.length);
      if (chunk.isEmpty) break;
      bytes.addAll(chunk);
    }
  } finally {
    await handle.close();
  }
  if (bytes.isEmpty || bytes.length > _maximumReceiptBytes) {
    throw const FormatException('restore_receipt_size');
  }
  final decoded = jsonDecode(utf8.decode(bytes));
  if (decoded is! Map) throw const FormatException('restore_receipt_json');
  return RestoreReceipt.fromJson(decoded);
}

void _validateRunId(String value, {required bool parsed}) {
  if (_runIdPattern.hasMatch(value)) return;
  if (parsed) throw const FormatException('restore_receipt_run_id');
  throw ArgumentError.value(value, 'runId');
}

void _validateHash(String value, String field) {
  if (!_sha256Pattern.hasMatch(value)) {
    throw FormatException('restore_receipt_hash:$field');
  }
}

List<String> _orderedComponentNames(Set<RestoreComponent> components) => [
  for (final component in _componentOrder)
    if (components.contains(component)) component.name,
];

bool _sameStrings(Iterable<String> left, List<String> right) {
  final values = left.toList(growable: false);
  if (values.length != right.length) return false;
  for (var index = 0; index < values.length; index++) {
    if (values[index] != right[index]) return false;
  }
  return true;
}

bool _sameComponents(Set<RestoreComponent> left, Set<RestoreComponent> right) =>
    left.length == right.length && left.containsAll(right);
