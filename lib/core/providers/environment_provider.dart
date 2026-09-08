import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../database/business_preferences.dart';
import '../models/environment_state.dart';
import '../models/environment_variable.dart';
import '../services/sandbox/rootfs_source.dart';

class EnvironmentProvider extends ChangeNotifier {
  static const String stateKey = 'environment_state_v1';
  static const String mirrorsKey = 'environment_mirrors_v1';
  static const String diskUsageKey = 'environment_disk_usage_v1';
  static const String variablesKey = 'environment_variables_v1';
  static const String privacyModeKey = 'environment_privacy_mode_v1';
  static const String rootfsSelectionKey = 'environment_rootfs_selection_v1';
  static const String prootOptionsKey = 'environment_proot_options_v1';

  EnvironmentProvider({required this.preferences}) {
    loaded = _load();
  }

  final BusinessPreferences preferences;
  List<EnvironmentVariable> _variables = [];
  bool _privacyMode = true;
  Future<void> _variablesWrite = Future<void>.value();

  List<EnvironmentVariable> get variables => List.unmodifiable(_variables);
  bool get privacyMode => _privacyMode;

  Future<EnvironmentExecutionConfig> loadExecutionConfig() async {
    await loaded;
    return EnvironmentExecutionConfig(
      variables: {
        for (final variable in _variables) variable.name: variable.value,
      },
      privacyMode: _privacyMode,
    );
  }

  Future<void> _writeVariables(Future<void> Function() write) {
    final operation = _variablesWrite.then((_) async {
      await loaded;
      await write();
      notifyListeners();
    });
    _variablesWrite = operation.catchError((Object _) {});
    return operation;
  }

  Future<void> saveVariable(
    EnvironmentVariable variable, {
    String? previousName,
  }) {
    return _writeVariables(() async {
      final name = variable.name.trim();
      if (!EnvironmentVariable.namePattern.hasMatch(name)) {
        throw EnvironmentVariableError.invalidName;
      }
      if (variable.value.isEmpty || variable.value.contains('\u0000')) {
        throw EnvironmentVariableError.invalidValue;
      }
      if (_variables.any((v) => v.name == name && v.name != previousName)) {
        throw EnvironmentVariableError.duplicateName;
      }
      final next = [..._variables];
      final index = next.indexWhere((v) => v.name == previousName);
      final saved = EnvironmentVariable(
        name: name,
        value: variable.value,
        note: variable.note.trim(),
      );
      if (index < 0) {
        next.add(saved);
      } else {
        next[index] = saved;
      }
      await preferences.setString(
        variablesKey,
        jsonEncode(next.map((v) => v.toJson()).toList()),
      );
      _variables = next;
    });
  }

  Future<void> deleteVariable(String name) => _writeVariables(() async {
    final next = _variables.where((v) => v.name != name).toList();
    await preferences.setString(
      variablesKey,
      jsonEncode(next.map((v) => v.toJson()).toList()),
    );
    _variables = next;
  });

  Future<void> setPrivacyMode(bool enabled) => _writeVariables(() async {
    await preferences.setBool(privacyModeKey, enabled);
    _privacyMode = enabled;
  });
  EnvironmentState _state = const EnvironmentState();
  Map<MirrorCategory, MirrorSelection> _mirrors =
      <MirrorCategory, MirrorSelection>{};
  int? _cachedDiskBytes;
  DateTime? _cachedDiskAt;
  String? _cachedDiskRoot;

  RootfsDownloadSource _downloadSource = RootfsDownloadSource.automatic;
  String _downloadUrl = '';
  RootfsDownloadSource get downloadSource => _downloadSource;
  String get downloadUrl => _downloadUrl;
  String _rootfsImageId = RootfsCatalog.defaultImage.id;
  String _localArchivePath = '';
  String _prootShell = '';
  List<String> _prootArguments = [];
  RootfsImage get rootfsImage => RootfsCatalog.byId(_rootfsImageId);
  String get localArchivePath => _localArchivePath;
  String get prootShell => _prootShell;
  List<String> get prootArguments => List.unmodifiable(_prootArguments);

  Future<void> setRootfsSelection({
    required String imageId,
    required RootfsDownloadSource source,
    String customUrl = '',
    String localArchivePath = '',
  }) async {
    final image = RootfsCatalog.byId(imageId);
    final resolver = RootfsSource(image: image);
    if (!resolver.availableSources.contains(source)) {
      throw const FormatException('Download source unavailable');
    }
    if (source == RootfsDownloadSource.custom) {
      RootfsSource.customTarballUri(customUrl, 'arm64', image: image);
    }
    if (source == RootfsDownloadSource.local &&
        RootfsSource.archiveFormat(localArchivePath) == null) {
      throw const FormatException('Select a rootfs tar archive');
    }
    await preferences.setString(
      rootfsSelectionKey,
      jsonEncode({
        'image': imageId,
        'source': source.name,
        'url': customUrl.trim(),
        'archive': localArchivePath,
      }),
    );
    _rootfsImageId = imageId;
    _downloadSource = source;
    _downloadUrl = customUrl.trim();
    _localArchivePath = localArchivePath;
    notifyListeners();
  }

  Future<void> setProotOptions({
    required String shell,
    required String arguments,
  }) async {
    final path = shell.trim();
    final args = const LineSplitter()
        .convert(arguments)
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    if ((path.isNotEmpty &&
            (!path.startsWith('/') || path.split('/').contains('..'))) ||
        path.contains('\u0000') ||
        args.any((arg) => arg.contains('\u0000'))) {
      throw const FormatException('Invalid PRoot options');
    }
    await preferences.setString(
      prootOptionsKey,
      jsonEncode({'shell': path, 'args': args}),
    );
    _prootShell = path;
    _prootArguments = args;
    notifyListeners();
  }

  Future<void> setDownloadSource(
    RootfsDownloadSource source, {
    String? customUrl,
  }) => setRootfsSelection(
    imageId: _rootfsImageId,
    source: source,
    customUrl: customUrl ?? _downloadUrl,
    localArchivePath: _localArchivePath,
  );

  late final Future<void> loaded;

  EnvironmentState get state => _state;
  Map<MirrorCategory, MirrorSelection> get mirrors =>
      Map.unmodifiable(_mirrors);
  int? get cachedDiskBytes =>
      (_cachedDiskBytes == null || _cachedDiskBytes == 0)
      ? null
      : _cachedDiskBytes;
  DateTime? get cachedDiskMeasuredAt => _cachedDiskAt;
  String? get cachedDiskRoot => _cachedDiskRoot;

  int? cachedDiskBytesFor(String? root) {
    final bytes = cachedDiskBytes;
    if (bytes == null) return null;
    if (root != null &&
        root.isNotEmpty &&
        _cachedDiskRoot != null &&
        _cachedDiskRoot!.isNotEmpty &&
        _cachedDiskRoot != root) {
      return null;
    }
    return bytes;
  }

  Future<void> _load() async {
    if (!preferences.isLoaded) {
      await preferences.load();
    }
    _privacyMode = preferences.getBool(privacyModeKey) ?? true;
    final rawVariables = preferences.getString(variablesKey);
    if (rawVariables != null && rawVariables.isNotEmpty) {
      try {
        _variables = (jsonDecode(rawVariables) as List)
            .map(
              (v) => EnvironmentVariable.fromJson(
                (v as Map).cast<String, dynamic>(),
              ),
            )
            .toList();
      } catch (_) {
        // Never print malformed stored values: they may contain credentials.
        debugPrint('Failed to load environment variables');
      }
    }
    final rootfs = preferences.getString(rootfsSelectionKey);
    if (rootfs != null && rootfs.isNotEmpty) {
      final data = jsonDecode(rootfs) as Map<String, dynamic>;
      _rootfsImageId = data['image'] as String;
      _downloadSource = RootfsDownloadSource.values.byName(
        data['source'] as String,
      );
      _downloadUrl = data['url'] as String;
      _localArchivePath = data['archive'] as String;
    }
    final proot = preferences.getString(prootOptionsKey);
    if (proot != null && proot.isNotEmpty) {
      final data = jsonDecode(proot) as Map<String, dynamic>;
      _prootShell = data['shell'] as String;
      _prootArguments = (data['args'] as List).cast<String>();
    }
    final rawState = preferences.getString(stateKey);
    if (rawState != null && rawState.isNotEmpty) {
      try {
        _state = EnvironmentState.fromJson(
          jsonDecode(rawState) as Map<String, dynamic>,
        );
      } catch (e) {
        debugPrint('Failed to load environment state: $e');
      }
    }
    final rawMirrors = preferences.getString(mirrorsKey);
    if (rawMirrors != null && rawMirrors.isNotEmpty) {
      try {
        _mirrors = _decodeMirrors(rawMirrors);
      } catch (e) {
        debugPrint('Failed to load environment mirrors: $e');
      }
    }
    final rawDisk = preferences.getString(diskUsageKey);
    if (rawDisk != null && rawDisk.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawDisk);
        if (decoded is Map) {
          final parsed = (decoded['bytes'] as num?)?.toInt();
          _cachedDiskBytes = (parsed == null || parsed == 0) ? null : parsed;
          final at = decoded['at'] as String?;
          _cachedDiskAt = at == null ? null : DateTime.tryParse(at);
          _cachedDiskRoot = decoded['root'] as String?;
        }
      } catch (e) {
        debugPrint('Failed to load environment disk usage: $e');
      }
    }
    notifyListeners();
  }

  Future<void> setState(EnvironmentState state) async {
    _state = state;
    notifyListeners();
    await preferences.setString(stateKey, jsonEncode(state.toJson()));
  }

  Future<void> setCachedDiskUsage({required int bytes, String? root}) async {
    if (bytes <= 0) {
      await clearCachedDiskUsage();
      return;
    }
    _cachedDiskBytes = bytes;
    _cachedDiskAt = DateTime.now().toUtc();
    _cachedDiskRoot = root;
    notifyListeners();
    await preferences.setString(
      diskUsageKey,
      jsonEncode(<String, dynamic>{
        'bytes': bytes,
        'at': _cachedDiskAt!.toIso8601String(),
        if (root != null) 'root': root,
      }),
    );
  }

  Future<void> clearCachedDiskUsage() async {
    _cachedDiskBytes = null;
    _cachedDiskAt = null;
    _cachedDiskRoot = null;
    notifyListeners();
    await preferences.setString(diskUsageKey, '');
  }

  Future<void> setMirror(
    MirrorCategory category,
    MirrorSelection selection,
  ) async {
    _mirrors = Map<MirrorCategory, MirrorSelection>.of(_mirrors)
      ..[category] = selection;
    notifyListeners();
    await preferences.setString(
      mirrorsKey,
      jsonEncode(_encodeMirrors(_mirrors)),
    );
  }

  static Map<String, dynamic> _encodeMirrors(
    Map<MirrorCategory, MirrorSelection> mirrors,
  ) {
    return <String, dynamic>{
      for (final entry in mirrors.entries) entry.key.name: entry.value.toJson(),
    };
  }

  static Map<MirrorCategory, MirrorSelection> _decodeMirrors(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is! Map) return <MirrorCategory, MirrorSelection>{};
    final result = <MirrorCategory, MirrorSelection>{};
    for (final entry in decoded.entries) {
      final value = entry.value;
      if (value is! Map) continue;
      result[MirrorSelection.categoryFromString(entry.key.toString())] =
          MirrorSelection.fromJson(value.cast<String, dynamic>());
    }
    return result;
  }
}
