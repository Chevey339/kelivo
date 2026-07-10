import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import 'backup_settings_validator.dart';
import 'restore_receipt.dart';

const _componentOrder = [
  RestoreComponent.settings,
  RestoreComponent.database,
  RestoreComponent.assets,
];
final _runIdPattern = RegExp(r'^[a-f0-9]{32}$');
final _hashPattern = RegExp(r'^[a-f0-9]{64}$');

enum RestorePreviousDatabaseState { missing, file }

enum RestorePreviousAssetRootState { missing, directory }

final class RestoreFileDescriptor {
  const RestoreFileDescriptor({required this.bytes, required this.sha256});

  final int bytes;
  final String sha256;

  Map<String, dynamic> toJson() => {'bytes': bytes, 'sha256': sha256};
}

final class RestorePreviousSettingsPlan {
  RestorePreviousSettingsPlan({
    required this.snapshot,
    required this.beforeFingerprint,
    required this.targetFingerprint,
    required Set<String> touchedKeys,
    required Set<String> missingKeys,
  }) : touchedKeys = Set.unmodifiable(touchedKeys),
       missingKeys = Set.unmodifiable(missingKeys) {
    _validateDescriptor(snapshot, 'settings');
    _validateHash(beforeFingerprint, 'beforeFingerprint');
    _validateHash(targetFingerprint, 'targetFingerprint');
    if (!this.touchedKeys.containsAll(this.missingKeys) ||
        this.touchedKeys.any(BackupSettingsValidator.isLocalOnly)) {
      throw ArgumentError('restore_previous_settings_keys');
    }
  }

  static const snapshotPath = 'settings.json';

  final RestoreFileDescriptor snapshot;
  final String beforeFingerprint;
  final String targetFingerprint;
  final Set<String> touchedKeys;
  final Set<String> missingKeys;

  static String fingerprintProjection(
    Map<String, dynamic> values,
    Set<String> touchedKeys,
  ) {
    if (!touchedKeys.containsAll(values.keys) ||
        touchedKeys.any(BackupSettingsValidator.isLocalOnly)) {
      throw ArgumentError('restore_previous_settings_projection');
    }
    BackupSettingsValidator.validate(values);
    final keys = _sortedStrings(touchedKeys);
    final projection = {
      'format': 'kelivo.restore-settings-projection',
      'formatVersion': 1,
      'entries': [
        for (final key in keys)
          {
            'key': key,
            'present': values.containsKey(key),
            if (values.containsKey(key)) 'value': values[key],
          },
      ],
    };
    return sha256.convert(utf8.encode(jsonEncode(projection))).toString();
  }

  Map<String, dynamic> validateSnapshotBytes(List<int> bytes) {
    if (bytes.length != snapshot.bytes ||
        sha256.convert(bytes).toString() != snapshot.sha256) {
      throw const FormatException('restore_previous_settings_snapshot');
    }
    final decoded = jsonDecode(utf8.decode(bytes));
    if (decoded is! Map || decoded.keys.any((key) => key is! String)) {
      throw const FormatException('restore_previous_settings_snapshot');
    }
    final decodedValues = decoded.cast<String, dynamic>();
    BackupSettingsValidator.validate(decodedValues);
    final values = <String, dynamic>{
      for (final entry in decodedValues.entries)
        entry.key: entry.value is List
            ? List<String>.unmodifiable((entry.value as List).cast<String>())
            : entry.value,
    };
    final expectedKeys = touchedKeys.difference(missingKeys);
    if (values.length != expectedKeys.length ||
        !values.keys.toSet().containsAll(expectedKeys) ||
        fingerprintProjection(values, touchedKeys) != beforeFingerprint) {
      throw const FormatException('restore_previous_settings_snapshot');
    }
    return Map.unmodifiable(values);
  }

  void validateTargetProjection(Map<String, dynamic> values) {
    if (fingerprintProjection(values, touchedKeys) != targetFingerprint) {
      throw const FormatException('restore_previous_settings_target');
    }
  }

  void validateBeforeProjection(Map<String, dynamic> values) {
    if (fingerprintProjection(values, touchedKeys) != beforeFingerprint) {
      throw const FormatException('restore_previous_settings_before');
    }
  }

  Map<String, dynamic> toJson() => {
    'snapshotPath': snapshotPath,
    'snapshot': snapshot.toJson(),
    'beforeFingerprint': beforeFingerprint,
    'targetFingerprint': targetFingerprint,
    'touchedKeys': _sortedStrings(touchedKeys),
    'missingKeys': _sortedStrings(missingKeys),
  };

  factory RestorePreviousSettingsPlan.fromJson(Object? source) {
    final json = _requireMap(source, const {
      'snapshotPath',
      'snapshot',
      'beforeFingerprint',
      'targetFingerprint',
      'touchedKeys',
      'missingKeys',
    }, 'restore_previous_settings');
    if (json['snapshotPath'] != snapshotPath ||
        json['beforeFingerprint'] is! String ||
        json['targetFingerprint'] is! String) {
      throw const FormatException('restore_previous_settings');
    }
    try {
      return RestorePreviousSettingsPlan(
        snapshot: _parseDescriptor(json['snapshot'], 'settings'),
        beforeFingerprint: json['beforeFingerprint'] as String,
        targetFingerprint: json['targetFingerprint'] as String,
        touchedKeys: _parseCanonicalStringSet(
          json['touchedKeys'],
          'restore_previous_settings_touched',
        ),
        missingKeys: _parseCanonicalStringSet(
          json['missingKeys'],
          'restore_previous_settings_missing',
        ),
      );
    } on FormatException {
      rethrow;
    } catch (_) {
      throw const FormatException('restore_previous_settings');
    }
  }
}

final class RestorePreviousDatabasePlan {
  const RestorePreviousDatabasePlan._({
    required this.state,
    required this.descriptor,
  });

  static const databasePath = 'database/kelivo.sqlite';

  final RestorePreviousDatabaseState state;
  final RestoreFileDescriptor? descriptor;

  factory RestorePreviousDatabasePlan.missing() {
    return const RestorePreviousDatabasePlan._(
      state: RestorePreviousDatabaseState.missing,
      descriptor: null,
    );
  }

  factory RestorePreviousDatabasePlan.file(RestoreFileDescriptor descriptor) {
    _validateDescriptor(descriptor, 'database');
    return RestorePreviousDatabasePlan._(
      state: RestorePreviousDatabaseState.file,
      descriptor: descriptor,
    );
  }

  Map<String, dynamic> toJson() => {
    'state': state.name,
    'path': databasePath,
    'descriptor': descriptor?.toJson(),
  };

  factory RestorePreviousDatabasePlan.fromJson(Object? source) {
    final json = _requireMap(source, const {
      'state',
      'path',
      'descriptor',
    }, 'restore_previous_database');
    if (json['state'] is! String || json['path'] != databasePath) {
      throw const FormatException('restore_previous_database');
    }
    return switch (json['state']) {
      'missing' when json['descriptor'] == null =>
        RestorePreviousDatabasePlan.missing(),
      'file' => RestorePreviousDatabasePlan.file(
        _parseDescriptor(json['descriptor'], 'database'),
      ),
      _ => throw const FormatException('restore_previous_database'),
    };
  }
}

final class RestorePreviousAssetsPlan {
  static const rootNames = ['upload', 'images', 'avatars', 'fonts'];

  RestorePreviousAssetsPlan({
    required Map<String, RestorePreviousAssetRootState> rootStates,
    required Map<String, RestoreFileDescriptor> entries,
  }) : rootStates = Map.unmodifiable({
         for (final root in rootNames)
           if (rootStates.containsKey(root)) root: rootStates[root]!,
       }),
       entries = Map.unmodifiable({
         for (final name in (entries.keys.toList()..sort()))
           name: entries[name]!,
       }) {
    if (rootStates.length != rootNames.length ||
        !rootNames.every(rootStates.containsKey)) {
      throw ArgumentError('restore_previous_asset_roots');
    }
    final foldedNames = <String>{};
    for (final entry in this.entries.entries) {
      final root = _assetRootFor(entry.key);
      if (root == null ||
          this.rootStates[root] != RestorePreviousAssetRootState.directory ||
          !foldedNames.add(entry.key.toLowerCase())) {
        throw ArgumentError('restore_previous_asset_entry:${entry.key}');
      }
      _validateDescriptor(entry.value, entry.key);
    }
  }

  final Map<String, RestorePreviousAssetRootState> rootStates;
  final Map<String, RestoreFileDescriptor> entries;

  Map<String, dynamic> toJson() => {
    'roots': {for (final root in rootNames) root: rootStates[root]!.name},
    'entries': {
      for (final entry in entries.entries) entry.key: entry.value.toJson(),
    },
  };

  factory RestorePreviousAssetsPlan.fromJson(Object? source) {
    final json = _requireMap(source, const {
      'roots',
      'entries',
    }, 'restore_previous_assets');
    final rawRoots = json['roots'];
    final rawEntries = json['entries'];
    if (rawRoots is! Map || rawEntries is! Map) {
      throw const FormatException('restore_previous_assets');
    }
    if (rawRoots.keys.any((key) => key is! String) ||
        rawRoots.length != rootNames.length ||
        !rootNames.every(rawRoots.containsKey)) {
      throw const FormatException('restore_previous_asset_roots');
    }
    final roots = <String, RestorePreviousAssetRootState>{};
    for (final root in rootNames) {
      final rawState = rawRoots[root];
      if (rawState is! String) {
        throw const FormatException('restore_previous_asset_roots');
      }
      roots[root] = RestorePreviousAssetRootState.values.firstWhere(
        (state) => state.name == rawState,
        orElse: () =>
            throw const FormatException('restore_previous_asset_roots'),
      );
    }
    if (rawEntries.keys.any((key) => key is! String)) {
      throw const FormatException('restore_previous_asset_entries');
    }
    final entries = <String, RestoreFileDescriptor>{};
    for (final entry in rawEntries.entries) {
      entries[entry.key as String] = _parseDescriptor(
        entry.value,
        entry.key as String,
      );
    }
    try {
      return RestorePreviousAssetsPlan(rootStates: roots, entries: entries);
    } on FormatException {
      rethrow;
    } catch (_) {
      throw const FormatException('restore_previous_assets');
    }
  }
}

final class RestorePreviousPlan {
  RestorePreviousPlan._({
    required this.runId,
    required this.preparedReceiptChecksum,
    required this.candidateManifestSha256,
    required Set<RestoreComponent> selectedComponents,
    required this.createdAtUtc,
    required this.settings,
    this.database,
    this.assets,
  }) : selectedComponents = Set.unmodifiable(selectedComponents) {
    if (!_runIdPattern.hasMatch(runId)) {
      throw ArgumentError.value(runId, 'runId');
    }
    _validateHash(preparedReceiptChecksum, 'preparedReceiptChecksum');
    _validateHash(candidateManifestSha256, 'candidateManifestSha256');
    if (!createdAtUtc.isUtc) {
      throw ArgumentError.value(createdAtUtc, 'createdAtUtc');
    }
    if (!this.selectedComponents.contains(RestoreComponent.settings) ||
        this.selectedComponents.contains(RestoreComponent.database) !=
            (database != null) ||
        this.selectedComponents.contains(RestoreComponent.assets) !=
            (assets != null)) {
      throw ArgumentError('restore_previous_components');
    }
  }

  static const format = 'kelivo.restore-previous-plan';
  static const formatVersion = 1;

  final String runId;
  final String preparedReceiptChecksum;
  final String candidateManifestSha256;
  final Set<RestoreComponent> selectedComponents;
  final DateTime createdAtUtc;
  final RestorePreviousSettingsPlan settings;
  final RestorePreviousDatabasePlan? database;
  final RestorePreviousAssetsPlan? assets;

  factory RestorePreviousPlan.forPreparedReceipt({
    required RestoreReceipt receipt,
    required RestorePreviousSettingsPlan settings,
    RestorePreviousDatabasePlan? database,
    RestorePreviousAssetsPlan? assets,
  }) {
    if (receipt.state != RestoreReceiptState.prepared ||
        receipt.sequence != 1) {
      throw ArgumentError('restore_previous_receipt');
    }
    return RestorePreviousPlan._(
      runId: receipt.runId,
      preparedReceiptChecksum: receipt.checksum,
      candidateManifestSha256: receipt.candidateManifestSha256,
      selectedComponents: receipt.selectedComponents,
      createdAtUtc: receipt.createdAtUtc,
      settings: settings,
      database: database,
      assets: assets,
    );
  }

  void validatePreparedReceipt(RestoreReceipt receipt) {
    if (receipt.state != RestoreReceiptState.prepared ||
        receipt.sequence != 1 ||
        receipt.runId != runId ||
        receipt.checksum != preparedReceiptChecksum ||
        receipt.candidateManifestSha256 != candidateManifestSha256 ||
        receipt.createdAtUtc != createdAtUtc ||
        !_sameComponents(receipt.selectedComponents, selectedComponents)) {
      throw StateError('restore_previous_receipt');
    }
  }

  String get checksum =>
      sha256.convert(utf8.encode(jsonEncode(_payloadJson()))).toString();

  Map<String, dynamic> toJson() => {..._payloadJson(), 'checksum': checksum};

  Map<String, dynamic> _payloadJson() => {
    'format': format,
    'formatVersion': formatVersion,
    'runId': runId,
    'preparedReceiptChecksum': preparedReceiptChecksum,
    'candidateManifestSha256': candidateManifestSha256,
    'selectedComponents': [
      for (final component in _componentOrder)
        if (selectedComponents.contains(component)) component.name,
    ],
    'createdAtUtc': createdAtUtc.toIso8601String(),
    'settings': settings.toJson(),
    'database': database?.toJson(),
    'assets': assets?.toJson(),
  };

  factory RestorePreviousPlan.fromJson(
    Map<dynamic, dynamic> source, {
    required RestoreReceipt preparedReceipt,
  }) {
    final json = _requireMap(source, const {
      'format',
      'formatVersion',
      'runId',
      'preparedReceiptChecksum',
      'candidateManifestSha256',
      'selectedComponents',
      'createdAtUtc',
      'settings',
      'database',
      'assets',
      'checksum',
    }, 'restore_previous_plan');
    if (json['format'] != format ||
        json['formatVersion'] is! int ||
        json['formatVersion'] != formatVersion ||
        json['runId'] is! String ||
        json['preparedReceiptChecksum'] is! String ||
        json['candidateManifestSha256'] is! String ||
        json['createdAtUtc'] is! String ||
        json['checksum'] is! String) {
      throw const FormatException('restore_previous_plan');
    }
    try {
      final selectedComponents = _parseComponents(json['selectedComponents']);
      final createdAtUtc = DateTime.parse(json['createdAtUtc'] as String);
      if (!createdAtUtc.isUtc ||
          createdAtUtc.toIso8601String() != json['createdAtUtc']) {
        throw const FormatException('restore_previous_created_at');
      }
      final plan = RestorePreviousPlan._(
        runId: json['runId'] as String,
        preparedReceiptChecksum: json['preparedReceiptChecksum'] as String,
        candidateManifestSha256: json['candidateManifestSha256'] as String,
        selectedComponents: selectedComponents,
        createdAtUtc: createdAtUtc,
        settings: RestorePreviousSettingsPlan.fromJson(json['settings']),
        database: json['database'] == null
            ? null
            : RestorePreviousDatabasePlan.fromJson(json['database']),
        assets: json['assets'] == null
            ? null
            : RestorePreviousAssetsPlan.fromJson(json['assets']),
      );
      if (!_hashPattern.hasMatch(json['checksum'] as String) ||
          plan.checksum != json['checksum']) {
        throw const FormatException('restore_previous_checksum');
      }
      plan.validatePreparedReceipt(preparedReceipt);
      return plan;
    } on FormatException {
      rethrow;
    } catch (_) {
      throw const FormatException('restore_previous_plan');
    }
  }
}

Map<String, dynamic> _requireMap(
  Object? source,
  Set<String> expectedKeys,
  String error,
) {
  if (source is! Map ||
      source.keys.any((key) => key is! String) ||
      source.length != expectedKeys.length ||
      !source.keys.toSet().containsAll(expectedKeys)) {
    throw FormatException(error);
  }
  return source.cast<String, dynamic>();
}

RestoreFileDescriptor _parseDescriptor(Object? source, String field) {
  final json = _requireMap(source, const {
    'bytes',
    'sha256',
  }, 'restore_previous_descriptor:$field');
  if (json['bytes'] is! int || json['sha256'] is! String) {
    throw FormatException('restore_previous_descriptor:$field');
  }
  final descriptor = RestoreFileDescriptor(
    bytes: json['bytes'] as int,
    sha256: json['sha256'] as String,
  );
  try {
    _validateDescriptor(descriptor, field);
  } catch (_) {
    throw FormatException('restore_previous_descriptor:$field');
  }
  return descriptor;
}

void _validateDescriptor(RestoreFileDescriptor descriptor, String field) {
  if (descriptor.bytes < 0 || !_hashPattern.hasMatch(descriptor.sha256)) {
    throw ArgumentError('restore_previous_descriptor:$field');
  }
}

void _validateHash(String value, String field) {
  if (!_hashPattern.hasMatch(value)) {
    throw ArgumentError.value(value, field);
  }
}

Set<String> _parseCanonicalStringSet(Object? source, String error) {
  if (source is! List || source.any((value) => value is! String)) {
    throw FormatException(error);
  }
  final values = source.cast<String>();
  final canonical = values.toSet().toList()..sort();
  if (canonical.length != values.length) throw FormatException(error);
  for (var index = 0; index < values.length; index++) {
    if (values[index] != canonical[index]) throw FormatException(error);
  }
  return canonical.toSet();
}

Set<RestoreComponent> _parseComponents(Object? source) {
  if (source is! List || source.any((value) => value is! String)) {
    throw const FormatException('restore_previous_components');
  }
  final raw = source.cast<String>();
  final expected = <String>[];
  final components = <RestoreComponent>{};
  for (final component in _componentOrder) {
    if (raw.contains(component.name)) {
      expected.add(component.name);
      components.add(component);
    }
  }
  if (raw.length != expected.length) {
    throw const FormatException('restore_previous_components');
  }
  for (var index = 0; index < raw.length; index++) {
    if (raw[index] != expected[index]) {
      throw const FormatException('restore_previous_components');
    }
  }
  return components;
}

List<String> _sortedStrings(Iterable<String> values) => values.toList()..sort();

String? _assetRootFor(String entryName) {
  if (entryName.contains('\\') ||
      p.posix.isAbsolute(entryName) ||
      p.posix.normalize(entryName) != entryName) {
    return null;
  }
  final segments = p.posix.split(entryName);
  if (segments.length < 2 || segments.any((segment) => segment.isEmpty)) {
    return null;
  }
  final root = segments.first;
  return RestorePreviousAssetsPlan.rootNames.contains(root) ? root : null;
}

bool _sameComponents(Set<RestoreComponent> left, Set<RestoreComponent> right) =>
    left.length == right.length && left.containsAll(right);
