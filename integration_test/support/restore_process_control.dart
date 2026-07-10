import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

import 'package:Kelivo/core/services/backup/restore_durability.dart';

const restoreHarnessControlDefine = 'KELIVO_RESTORE_HARNESS_CONTROL';
const restoreHarnessScenario = 'candidateDatabaseRenamedToLive';
const restoreHarnessFormat = 'kelivo.restore-process-harness';

enum RestoreProcessHarnessPhase {
  setup,
  cutoverKill,
  resumeToColdAck,
  coldFinalize,
}

final _scenarioIdPattern = RegExp(r'^[a-f0-9]{32}$');
final _preferencePrefixPattern = RegExp(
  r'^kelivo\.restore\.harness\.[a-f0-9]{32}\.$',
);

final class RestoreProcessHarnessControl {
  RestoreProcessHarnessControl({
    required this.generation,
    required this.scenarioId,
    required this.phase,
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
    if (!_scenarioIdPattern.hasMatch(scenarioId)) {
      throw ArgumentError.value(scenarioId, 'scenarioId');
    }
    if (!p.isAbsolute(scenarioRoot) ||
        p.normalize(scenarioRoot) != scenarioRoot) {
      throw ArgumentError.value(scenarioRoot, 'scenarioRoot');
    }
    if (!_preferencePrefixPattern.hasMatch(preferencesPrefix) ||
        preferencesPrefix != 'kelivo.restore.harness.$scenarioId.') {
      throw ArgumentError.value(preferencesPrefix, 'preferencesPrefix');
    }
  }

  static const version = 1;

  final int generation;
  final String scenarioId;
  final RestoreProcessHarnessPhase phase;
  final String scenarioRoot;
  final String preferencesPrefix;

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
    'scenario': restoreHarnessScenario,
    'scenarioId': scenarioId,
    'phase': phase.name,
    'scenarioRoot': scenarioRoot,
    'preferencesPrefix': preferencesPrefix,
  };

  factory RestoreProcessHarnessControl.fromJson(Map<dynamic, dynamic> source) {
    const expectedKeys = {
      'format',
      'version',
      'generation',
      'scenario',
      'scenarioId',
      'phase',
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
        json['scenarioId'] is! String ||
        json['phase'] is! String ||
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
    try {
      return RestoreProcessHarnessControl(
        generation: json['generation'] as int,
        scenarioId: json['scenarioId'] as String,
        phase: phase,
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
