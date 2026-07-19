import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import 'restore_receipt.dart';

const _componentOrder = [RestoreComponent.database, RestoreComponent.assets];
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

final class RestorePreviousDatabasePlan {
  const RestorePreviousDatabasePlan._({
    required this.state,
    required this.descriptor,
  });

  static const databasePath = 'database/kelivo.db';

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
    required this.database,
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
    if (!this.selectedComponents.contains(RestoreComponent.database) ||
        this.selectedComponents.contains(RestoreComponent.assets) !=
            (assets != null)) {
      throw ArgumentError('restore_previous_components');
    }
  }

  static const format = 'kelivo.restore-previous-plan';
  static const formatVersion = 2;

  final String runId;
  final String preparedReceiptChecksum;
  final String candidateManifestSha256;
  final Set<RestoreComponent> selectedComponents;
  final DateTime createdAtUtc;
  final RestorePreviousDatabasePlan database;
  final RestorePreviousAssetsPlan? assets;

  factory RestorePreviousPlan.forPreparedReceipt({
    required RestoreReceipt receipt,
    required RestorePreviousDatabasePlan database,
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
    'database': database.toJson(),
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
        database: RestorePreviousDatabasePlan.fromJson(json['database']),
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
