import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

import 'package:Kelivo/core/services/backup/restore_durability.dart';

const restoreHarnessControlDefine = 'KELIVO_RESTORE_HARNESS_CONTROL';
const restoreHarnessFormat = 'kelivo.restore-process-harness';

enum RestoreProcessHarnessPhase { setup, interrupt, resume, verify }

enum RestoreProcessFailpoint {
  cutoverClaimPublished,
  liveDatabaseNormalized,
  previousManifestPublished,
  previousAssetsMoved,
  previousDatabaseMoved,
  previousPromoted,
  oldRenamedReceiptPublished,
  candidateDatabaseMoved,
  candidateAssetsMoved,
  newInstalledReceiptPublished,
  verifiedReceiptPublished,
  committedReceiptPublished,
  rollingBackReceiptPublished,
  newDatabaseReturnedToCandidate,
  previousDatabaseRestoredToLive,
  newAssetsReturnedToCandidate,
  previousAssetsRestoredToLive,
  rolledBackReceiptPublished,
  terminalRunArchived,
  archivingMarkerRemovedDurable,
  publishingMarkerWithoutRun,
}

const restoreProcessSmokeFailpoints = <RestoreProcessFailpoint>[
  RestoreProcessFailpoint.candidateDatabaseMoved,
  RestoreProcessFailpoint.newDatabaseReturnedToCandidate,
  RestoreProcessFailpoint.terminalRunArchived,
  RestoreProcessFailpoint.publishingMarkerWithoutRun,
];

const restoreProcessCoreFailpoints = <RestoreProcessFailpoint>[
  RestoreProcessFailpoint.cutoverClaimPublished,
  RestoreProcessFailpoint.previousManifestPublished,
  RestoreProcessFailpoint.previousAssetsMoved,
  RestoreProcessFailpoint.previousDatabaseMoved,
  RestoreProcessFailpoint.previousPromoted,
  RestoreProcessFailpoint.oldRenamedReceiptPublished,
  RestoreProcessFailpoint.candidateDatabaseMoved,
  RestoreProcessFailpoint.candidateAssetsMoved,
  RestoreProcessFailpoint.newInstalledReceiptPublished,
  RestoreProcessFailpoint.committedReceiptPublished,
  RestoreProcessFailpoint.rollingBackReceiptPublished,
  RestoreProcessFailpoint.newDatabaseReturnedToCandidate,
  RestoreProcessFailpoint.previousDatabaseRestoredToLive,
  RestoreProcessFailpoint.newAssetsReturnedToCandidate,
  RestoreProcessFailpoint.previousAssetsRestoredToLive,
  RestoreProcessFailpoint.rolledBackReceiptPublished,
  RestoreProcessFailpoint.terminalRunArchived,
  RestoreProcessFailpoint.archivingMarkerRemovedDurable,
  RestoreProcessFailpoint.publishingMarkerWithoutRun,
];

const restoreProcessFullFailpoints = RestoreProcessFailpoint.values;

const _rollbackFailpoints = <RestoreProcessFailpoint>{
  RestoreProcessFailpoint.rollingBackReceiptPublished,
  RestoreProcessFailpoint.newDatabaseReturnedToCandidate,
  RestoreProcessFailpoint.previousDatabaseRestoredToLive,
  RestoreProcessFailpoint.newAssetsReturnedToCandidate,
  RestoreProcessFailpoint.previousAssetsRestoredToLive,
  RestoreProcessFailpoint.rolledBackReceiptPublished,
};

const _terminalFailpoints = <RestoreProcessFailpoint>{
  RestoreProcessFailpoint.terminalRunArchived,
  RestoreProcessFailpoint.archivingMarkerRemovedDurable,
};

extension RestoreProcessFailpointContract on RestoreProcessFailpoint {
  bool get triggersRollback => _rollbackFailpoints.contains(this);

  bool get isTerminalBoundary => _terminalFailpoints.contains(this);

  bool get isPartialMarker =>
      this == RestoreProcessFailpoint.publishingMarkerWithoutRun;

  String get scenario => isPartialMarker
      ? 'partial-marker'
      : triggersRollback
      ? 'rollback'
      : isTerminalBoundary
      ? 'terminal'
      : 'commit';
}

final class RestoreProcessHarnessControl {
  RestoreProcessHarnessControl({
    required this.generation,
    required this.matrixRunId,
    required this.scenarioId,
    required this.phase,
    required this.failpoint,
    required this.scenarioRoot,
  }) {
    _validate(parsed: false);
  }

  static const version = 1;
  static final _identifierPattern = RegExp(r'^[a-f0-9]{32}$');

  final int generation;
  final String matrixRunId;
  final String scenarioId;
  final RestoreProcessHarnessPhase phase;
  final RestoreProcessFailpoint failpoint;
  final String scenarioRoot;

  String get scenario => failpoint.scenario;
  String get phaseName => phase.name;
  String get failpointName => failpoint.name;
  Directory get rootDirectory => Directory(scenarioRoot);
  Directory get appDataDirectory => Directory(p.join(scenarioRoot, 'app_data'));
  Directory get sourceDirectory => Directory(p.join(scenarioRoot, 'source'));
  Directory get eventsDirectory => Directory(p.join(scenarioRoot, 'events'));
  File get stateFile => File(p.join(scenarioRoot, 'state.json'));
  File get eventFile => File(
    p.join(
      eventsDirectory.path,
      '${generation.toString().padLeft(2, '0')}_${phase.name}.json',
    ),
  );

  Map<String, dynamic> toJson() => {
    'format': restoreHarnessFormat,
    'version': version,
    'generation': generation,
    'matrixRunId': matrixRunId,
    'scenarioId': scenarioId,
    'scenario': scenario,
    'phase': phase.name,
    'failpoint': failpoint.name,
    'scenarioRoot': scenarioRoot,
  };

  factory RestoreProcessHarnessControl.fromJson(Map<dynamic, dynamic> source) {
    const keys = {
      'format',
      'version',
      'generation',
      'matrixRunId',
      'scenarioId',
      'scenario',
      'phase',
      'failpoint',
      'scenarioRoot',
    };
    if (source.keys.any((key) => key is! String) ||
        source.length != keys.length ||
        !source.keys.toSet().containsAll(keys)) {
      throw const FormatException('restore_harness_control_fields');
    }
    final json = source.cast<String, dynamic>();
    if (json['format'] != restoreHarnessFormat ||
        json['version'] != version ||
        json['generation'] is! int ||
        json['matrixRunId'] is! String ||
        json['scenarioId'] is! String ||
        json['scenario'] is! String ||
        json['phase'] is! String ||
        json['failpoint'] is! String ||
        json['scenarioRoot'] is! String) {
      throw const FormatException('restore_harness_control_types');
    }
    try {
      final phase = RestoreProcessHarnessPhase.values.firstWhere(
        (value) => value.name == json['phase'],
      );
      final failpoint = RestoreProcessFailpoint.values.firstWhere(
        (value) => value.name == json['failpoint'],
      );
      final control = RestoreProcessHarnessControl(
        generation: json['generation'] as int,
        matrixRunId: json['matrixRunId'] as String,
        scenarioId: json['scenarioId'] as String,
        phase: phase,
        failpoint: failpoint,
        scenarioRoot: json['scenarioRoot'] as String,
      );
      if (json['scenario'] != control.scenario) {
        throw const FormatException('restore_harness_control_scenario');
      }
      control._validate(parsed: true);
      return control;
    } on FormatException {
      rethrow;
    } catch (_) {
      throw const FormatException('restore_harness_control');
    }
  }

  static Future<RestoreProcessHarnessControl> readFromEnvironment() async {
    const controlPath = String.fromEnvironment(restoreHarnessControlDefine);
    if (controlPath.isEmpty || !p.isAbsolute(controlPath)) {
      throw StateError('restore_harness_control_define');
    }
    return RestoreProcessHarnessControl.fromJson(
      await readHarnessJson(File(controlPath)),
    );
  }

  void _validate({required bool parsed}) {
    final valid =
        generation == phase.index + 1 &&
        _identifierPattern.hasMatch(matrixRunId) &&
        _identifierPattern.hasMatch(scenarioId) &&
        p.isAbsolute(scenarioRoot) &&
        p.equals(p.normalize(scenarioRoot), scenarioRoot) &&
        p.basename(scenarioRoot) == scenarioId &&
        p.basename(p.dirname(scenarioRoot)) == matrixRunId;
    if (valid) return;
    if (parsed) throw const FormatException('restore_harness_control_binding');
    throw ArgumentError('restore_harness_control_binding');
  }
}

Future<Map<String, dynamic>> readHarnessJson(File file) async {
  if (await FileSystemEntity.type(file.path, followLinks: false) !=
      FileSystemEntityType.file) {
    throw const FormatException('restore_harness_json_file');
  }
  final bytes = await file.readAsBytes();
  if (bytes.isEmpty || bytes.length > 1024 * 1024) {
    throw const FormatException('restore_harness_json_size');
  }
  final decoded = jsonDecode(utf8.decode(bytes));
  if (decoded is! Map || decoded.keys.any((key) => key is! String)) {
    throw const FormatException('restore_harness_json');
  }
  return decoded.cast<String, dynamic>();
}

Future<void> writeDurableHarnessJson(
  File file,
  Map<String, dynamic> value, {
  RestoreDurability? durability,
}) async {
  final resolved = durability ?? RestorePlatformDurability();
  await file.parent.create(recursive: true);
  await resolved.restrictDirectory(file.parent);
  final bytes = utf8.encode(jsonEncode(value));
  final temporary = File('${file.path}.$pid.tmp');
  if (await FileSystemEntity.type(temporary.path, followLinks: false) !=
      FileSystemEntityType.notFound) {
    throw StateError('restore_harness_json_temp');
  }
  await temporary.writeAsBytes(bytes, flush: true);
  await resolved.restrictFile(temporary);
  await resolved.syncFile(temporary, fullBarrier: true);
  await resolved.renameAndSync(source: temporary, targetPath: file.path);
  final persisted = await readHarnessJson(file);
  if (jsonEncode(persisted) != jsonEncode(value)) {
    throw StateError('restore_harness_json_readback');
  }
}

Uint8List canonicalHarnessJsonBytes(Map<String, dynamic> value) =>
    Uint8List.fromList(utf8.encode(jsonEncode(value)));
