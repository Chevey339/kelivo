import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

import 'package:Kelivo/core/services/backup/restore_durability.dart';

const restoreHarnessControlDefine = 'KELIVO_RESTORE_HARNESS_CONTROL';
const restoreHarnessScenario = 'forwardCutoverMatrix';
const restoreTerminalHarnessScenario = 'terminalRecoveryMatrix';
const restoreHarnessFormat = 'kelivo.restore-process-harness';

abstract interface class RestoreHarnessControl {
  int get generation;

  String get matrixRunId;

  String get scenario;

  String get scenarioId;

  String get phaseName;

  String get failpointName;

  String get scenarioRoot;

  String get preferencesPrefix;

  Directory get rootDirectory;

  Directory get appDataDirectory;

  Directory get sourceDirectory;

  Directory get eventsDirectory;

  File get stateFile;

  File get eventFile;

  Map<String, dynamic> toJson();

  static RestoreHarnessControl fromJson(Map<dynamic, dynamic> source) {
    final rawScenario = source['scenario'];
    if (rawScenario is! String) {
      throw const FormatException('restore_harness_control_scenario');
    }
    return switch (rawScenario) {
      restoreHarnessScenario => RestoreProcessHarnessControl.fromJson(source),
      restoreTerminalHarnessScenario =>
        RestoreTerminalProcessHarnessControl.fromJson(source),
      _ => throw const FormatException('restore_harness_control_scenario'),
    };
  }

  static Future<RestoreHarnessControl> readFromEnvironment() async {
    const controlPath = String.fromEnvironment(restoreHarnessControlDefine);
    if (controlPath.isEmpty || !p.isAbsolute(controlPath)) {
      throw StateError('restore_harness_control_define');
    }
    return RestoreHarnessControl.fromJson(
      await readHarnessJson(File(controlPath)),
    );
  }
}

enum RestoreProcessHarnessPhase {
  setup,
  cutoverKill,
  resumeToColdAck,
  coldFinalize,
}

enum RestoreProcessFailpoint {
  cutoverClaimPublished,
  liveDatabaseNormalized,
  previousSettingsPublished,
  previousManifestPublished,
  previousUploadMoved,
  previousImagesMoved,
  previousAvatarsMoved,
  previousFontsMoved,
  previousDatabaseMoved,
  previousPromoted,
  oldRenamedReceiptTempDurable,
  oldRenamedReceiptPublished,
  settingsSecretRemoved,
  settingsFirstSet,
  candidateDatabaseMoved,
  candidateUploadMoved,
  candidateImagesMoved,
  candidateAvatarsMoved,
  candidateFontsMoved,
  newInstalledReceiptTempDurable,
  newInstalledReceiptPublished,
  verifiedReceiptTempDurable,
  verifiedReceiptPublished,
  committedReceiptTempDurable,
  committedReceiptPublished,
}

enum RestoreTerminalProcessHarnessPhase {
  setup,
  commitToColdAck,
  recoverTerminal,
  verifyBusinessReady,
}

enum RestoreTerminalProcessFailpoint {
  coldAckTempDurable,
  coldAckPublished,
  completedRunsRootDurable,
  archivingMarkerPublished,
  terminalRunArchived,
  archivingMarkerRemovedDurable,
}

const restoreProcessSmokeFailpoints = <RestoreProcessFailpoint>[
  RestoreProcessFailpoint.candidateDatabaseMoved,
];

const restoreProcessCoreFailpoints = <RestoreProcessFailpoint>[
  RestoreProcessFailpoint.cutoverClaimPublished,
  RestoreProcessFailpoint.liveDatabaseNormalized,
  RestoreProcessFailpoint.previousSettingsPublished,
  RestoreProcessFailpoint.previousManifestPublished,
  RestoreProcessFailpoint.previousUploadMoved,
  RestoreProcessFailpoint.previousDatabaseMoved,
  RestoreProcessFailpoint.previousPromoted,
  RestoreProcessFailpoint.oldRenamedReceiptTempDurable,
  RestoreProcessFailpoint.oldRenamedReceiptPublished,
  RestoreProcessFailpoint.settingsSecretRemoved,
  RestoreProcessFailpoint.settingsFirstSet,
  RestoreProcessFailpoint.candidateDatabaseMoved,
  RestoreProcessFailpoint.candidateUploadMoved,
  RestoreProcessFailpoint.candidateImagesMoved,
  RestoreProcessFailpoint.candidateAvatarsMoved,
  RestoreProcessFailpoint.candidateFontsMoved,
  RestoreProcessFailpoint.newInstalledReceiptPublished,
  RestoreProcessFailpoint.verifiedReceiptPublished,
  RestoreProcessFailpoint.committedReceiptPublished,
];

const restoreProcessFullFailpoints = RestoreProcessFailpoint.values;

final _scenarioIdPattern = RegExp(r'^[a-f0-9]{32}$');

String restoreProcessPreferencesPrefix({
  required String matrixRunId,
  required String scenarioId,
  required RestoreProcessFailpoint failpoint,
}) {
  _requireIdentifier(matrixRunId, 'matrixRunId');
  _requireIdentifier(scenarioId, 'scenarioId');
  return 'kelivo.restore.harness.$matrixRunId.$scenarioId.'
      '${failpoint.name}.';
}

String restoreTerminalProcessPreferencesPrefix({
  required String matrixRunId,
  required String scenarioId,
  required RestoreTerminalProcessFailpoint failpoint,
}) {
  _requireIdentifier(matrixRunId, 'matrixRunId');
  _requireIdentifier(scenarioId, 'scenarioId');
  return 'kelivo.restore.terminal.harness.$matrixRunId.$scenarioId.'
      '${failpoint.name}.';
}

final class RestoreProcessHarnessControl implements RestoreHarnessControl {
  RestoreProcessHarnessControl({
    required this.generation,
    required this.matrixRunId,
    required this.scenarioId,
    required this.phase,
    required this.failpoint,
    required String scenarioRoot,
    required this.preferencesPrefix,
  }) : scenarioRoot = p.normalize(p.absolute(scenarioRoot)) {
    if (generation < 1 ||
        generation > RestoreProcessHarnessPhase.values.length) {
      throw ArgumentError.value(generation, 'generation');
    }
    if (generation != phase.index + 1) {
      throw ArgumentError.value(generation, 'generation');
    }
    _requireIdentifier(matrixRunId, 'matrixRunId');
    _requireIdentifier(scenarioId, 'scenarioId');
    if (!p.isAbsolute(scenarioRoot) ||
        p.normalize(scenarioRoot) != scenarioRoot ||
        p.basename(scenarioRoot) != 'kelivo_restore_process_$scenarioId') {
      throw ArgumentError.value(scenarioRoot, 'scenarioRoot');
    }
    if (preferencesPrefix !=
        restoreProcessPreferencesPrefix(
          matrixRunId: matrixRunId,
          scenarioId: scenarioId,
          failpoint: failpoint,
        )) {
      throw ArgumentError.value(preferencesPrefix, 'preferencesPrefix');
    }
  }

  static const version = 2;

  @override
  final int generation;
  @override
  final String matrixRunId;
  @override
  final String scenarioId;
  final RestoreProcessHarnessPhase phase;
  final RestoreProcessFailpoint failpoint;
  @override
  final String scenarioRoot;
  @override
  final String preferencesPrefix;

  @override
  String get scenario => restoreHarnessScenario;

  @override
  String get phaseName => phase.name;

  @override
  String get failpointName => failpoint.name;

  @override
  Directory get rootDirectory => Directory(scenarioRoot);
  @override
  Directory get appDataDirectory => Directory(p.join(scenarioRoot, 'app_data'));
  @override
  Directory get sourceDirectory => Directory(p.join(scenarioRoot, 'source'));
  @override
  Directory get eventsDirectory => Directory(p.join(scenarioRoot, 'events'));
  @override
  File get stateFile => File(p.join(scenarioRoot, 'state.json'));
  @override
  File get eventFile => File(
    p.join(
      eventsDirectory.path,
      '${generation.toString().padLeft(2, '0')}_${phase.name}.json',
    ),
  );

  @override
  Map<String, dynamic> toJson() => {
    'format': restoreHarnessFormat,
    'version': version,
    'generation': generation,
    'matrixRunId': matrixRunId,
    'scenario': restoreHarnessScenario,
    'scenarioId': scenarioId,
    'phase': phase.name,
    'failpoint': failpoint.name,
    'scenarioRoot': scenarioRoot,
    'preferencesPrefix': preferencesPrefix,
  };

  factory RestoreProcessHarnessControl.fromJson(Map<dynamic, dynamic> source) {
    const expectedKeys = {
      'format',
      'version',
      'generation',
      'matrixRunId',
      'scenario',
      'scenarioId',
      'phase',
      'failpoint',
      'scenarioRoot',
      'preferencesPrefix',
    };
    if (source.keys.any((key) => key is! String) ||
        source.length != expectedKeys.length ||
        !source.keys.toSet().containsAll(expectedKeys)) {
      throw const FormatException('restore_harness_control_fields');
    }
    final json = source.cast<String, dynamic>();
    if (json['format'] != restoreHarnessFormat ||
        json['version'] != version ||
        json['scenario'] != restoreHarnessScenario ||
        json['generation'] is! int ||
        json['matrixRunId'] is! String ||
        json['scenarioId'] is! String ||
        json['phase'] is! String ||
        json['failpoint'] is! String ||
        json['scenarioRoot'] is! String ||
        json['preferencesPrefix'] is! String) {
      throw const FormatException('restore_harness_control_types');
    }
    final rawPhase = json['phase'] as String;
    final phase = RestoreProcessHarnessPhase.values.firstWhere(
      (candidate) => candidate.name == rawPhase,
      orElse: () =>
          throw const FormatException('restore_harness_control_phase'),
    );
    final rawFailpoint = json['failpoint'] as String;
    final failpoint = RestoreProcessFailpoint.values.firstWhere(
      (candidate) => candidate.name == rawFailpoint,
      orElse: () =>
          throw const FormatException('restore_harness_control_failpoint'),
    );
    try {
      return RestoreProcessHarnessControl(
        generation: json['generation'] as int,
        matrixRunId: json['matrixRunId'] as String,
        scenarioId: json['scenarioId'] as String,
        phase: phase,
        failpoint: failpoint,
        scenarioRoot: json['scenarioRoot'] as String,
        preferencesPrefix: json['preferencesPrefix'] as String,
      );
    } on ArgumentError {
      throw const FormatException('restore_harness_control_value');
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
}

final class RestoreTerminalProcessHarnessControl
    implements RestoreHarnessControl {
  RestoreTerminalProcessHarnessControl({
    required this.generation,
    required this.matrixRunId,
    required this.scenarioId,
    required this.phase,
    required this.failpoint,
    required String scenarioRoot,
    required this.preferencesPrefix,
  }) : scenarioRoot = p.normalize(p.absolute(scenarioRoot)) {
    if (generation < 1 ||
        generation > RestoreTerminalProcessHarnessPhase.values.length) {
      throw ArgumentError.value(generation, 'generation');
    }
    if (generation != phase.index + 1) {
      throw ArgumentError.value(generation, 'generation');
    }
    _requireIdentifier(matrixRunId, 'matrixRunId');
    _requireIdentifier(scenarioId, 'scenarioId');
    if (!p.isAbsolute(scenarioRoot) ||
        p.normalize(scenarioRoot) != scenarioRoot ||
        p.basename(scenarioRoot) != 'kelivo_restore_process_$scenarioId') {
      throw ArgumentError.value(scenarioRoot, 'scenarioRoot');
    }
    if (preferencesPrefix !=
        restoreTerminalProcessPreferencesPrefix(
          matrixRunId: matrixRunId,
          scenarioId: scenarioId,
          failpoint: failpoint,
        )) {
      throw ArgumentError.value(preferencesPrefix, 'preferencesPrefix');
    }
  }

  static const version = 1;

  @override
  final int generation;
  @override
  final String matrixRunId;
  @override
  final String scenarioId;
  final RestoreTerminalProcessHarnessPhase phase;
  final RestoreTerminalProcessFailpoint failpoint;
  @override
  final String scenarioRoot;
  @override
  final String preferencesPrefix;

  @override
  String get scenario => restoreTerminalHarnessScenario;

  @override
  String get phaseName => phase.name;

  @override
  String get failpointName => failpoint.name;

  @override
  Directory get rootDirectory => Directory(scenarioRoot);

  @override
  Directory get appDataDirectory => Directory(p.join(scenarioRoot, 'app_data'));

  @override
  Directory get sourceDirectory => Directory(p.join(scenarioRoot, 'source'));

  @override
  Directory get eventsDirectory => Directory(p.join(scenarioRoot, 'events'));

  @override
  File get stateFile => File(p.join(scenarioRoot, 'state.json'));

  @override
  File get eventFile => File(
    p.join(
      eventsDirectory.path,
      '${generation.toString().padLeft(2, '0')}_${phase.name}.json',
    ),
  );

  @override
  Map<String, dynamic> toJson() => {
    'format': restoreHarnessFormat,
    'version': version,
    'generation': generation,
    'matrixRunId': matrixRunId,
    'scenario': restoreTerminalHarnessScenario,
    'scenarioId': scenarioId,
    'phase': phase.name,
    'failpoint': failpoint.name,
    'scenarioRoot': scenarioRoot,
    'preferencesPrefix': preferencesPrefix,
  };

  factory RestoreTerminalProcessHarnessControl.fromJson(
    Map<dynamic, dynamic> source,
  ) {
    const expectedKeys = {
      'format',
      'version',
      'generation',
      'matrixRunId',
      'scenario',
      'scenarioId',
      'phase',
      'failpoint',
      'scenarioRoot',
      'preferencesPrefix',
    };
    if (source.keys.any((key) => key is! String) ||
        source.length != expectedKeys.length ||
        !source.keys.toSet().containsAll(expectedKeys)) {
      throw const FormatException('restore_terminal_harness_control_fields');
    }
    final json = source.cast<String, dynamic>();
    if (json['format'] != restoreHarnessFormat ||
        json['version'] != version ||
        json['scenario'] != restoreTerminalHarnessScenario ||
        json['generation'] is! int ||
        json['matrixRunId'] is! String ||
        json['scenarioId'] is! String ||
        json['phase'] is! String ||
        json['failpoint'] is! String ||
        json['scenarioRoot'] is! String ||
        json['preferencesPrefix'] is! String) {
      throw const FormatException('restore_terminal_harness_control_types');
    }
    final rawPhase = json['phase'] as String;
    final phase = RestoreTerminalProcessHarnessPhase.values.firstWhere(
      (candidate) => candidate.name == rawPhase,
      orElse: () =>
          throw const FormatException('restore_terminal_harness_control_phase'),
    );
    final rawFailpoint = json['failpoint'] as String;
    final failpoint = RestoreTerminalProcessFailpoint.values.firstWhere(
      (candidate) => candidate.name == rawFailpoint,
      orElse: () => throw const FormatException(
        'restore_terminal_harness_control_failpoint',
      ),
    );
    try {
      return RestoreTerminalProcessHarnessControl(
        generation: json['generation'] as int,
        matrixRunId: json['matrixRunId'] as String,
        scenarioId: json['scenarioId'] as String,
        phase: phase,
        failpoint: failpoint,
        scenarioRoot: json['scenarioRoot'] as String,
        preferencesPrefix: json['preferencesPrefix'] as String,
      );
    } on ArgumentError {
      throw const FormatException('restore_terminal_harness_control_value');
    }
  }

  static Future<RestoreTerminalProcessHarnessControl>
  readFromEnvironment() async {
    const controlPath = String.fromEnvironment(restoreHarnessControlDefine);
    if (controlPath.isEmpty || !p.isAbsolute(controlPath)) {
      throw StateError('restore_harness_control_define');
    }
    return RestoreTerminalProcessHarnessControl.fromJson(
      await readHarnessJson(File(controlPath)),
    );
  }
}

void _requireIdentifier(String value, String name) {
  if (!_scenarioIdPattern.hasMatch(value)) {
    throw ArgumentError.value(value, name);
  }
}

Future<Map<String, dynamic>> readHarnessJson(File file) async {
  if (await FileSystemEntity.type(file.path, followLinks: false) !=
      FileSystemEntityType.file) {
    throw StateError('restore_harness_json_file');
  }
  final length = await file.length();
  if (length <= 0 || length > 1024 * 1024) {
    throw const FormatException('restore_harness_json_size');
  }
  final decoded = jsonDecode(await file.readAsString());
  if (decoded is! Map) {
    throw const FormatException('restore_harness_json_object');
  }
  return decoded.cast<String, dynamic>();
}

Future<void> writeDurableHarnessJson(
  File target,
  Map<String, dynamic> value,
) async {
  final targetType = await FileSystemEntity.type(
    target.path,
    followLinks: false,
  );
  if (targetType != FileSystemEntityType.notFound) {
    throw StateError('restore_harness_json_exists');
  }
  await target.parent.create(recursive: true);
  final durability = RestorePlatformDurability();
  await durability.restrictDirectory(target.parent);
  final encoded = Uint8List.fromList(utf8.encode(jsonEncode(value)));
  final temporary = File(
    '${target.path}.${pid}_${DateTime.now().microsecondsSinceEpoch}.tmp',
  );
  await temporary.create(exclusive: true);
  try {
    await durability.restrictFile(temporary);
    await temporary.writeAsBytes(encoded, flush: true);
    await durability.syncFile(temporary, fullBarrier: true);
    await durability.renameAndSync(source: temporary, targetPath: target.path);
    final published = await target.readAsBytes();
    if (published.length != encoded.length ||
        !_bytesEqual(published, encoded)) {
      throw StateError('restore_harness_json_publish');
    }
  } finally {
    if (await FileSystemEntity.type(temporary.path, followLinks: false) ==
        FileSystemEntityType.file) {
      await temporary.delete();
      await durability.syncDirectory(target.parent, fullBarrier: true);
    }
  }
}

bool _bytesEqual(List<int> left, List<int> right) {
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index++) {
    if (left[index] != right[index]) return false;
  }
  return true;
}
