import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../database/business_preferences.dart';
import '../models/environment_state.dart';
import '../services/sandbox/rootfs_source.dart';

class EnvironmentProvider extends ChangeNotifier {
  static const String stateKey = 'environment_state_v1';
  static const String mirrorsKey = 'environment_mirrors_v1';
  static const String downloadSourceKey = 'environment_download_source_v1';
  static const String downloadUrlKey = 'environment_download_url_v1';
  static const String diskUsageKey = 'environment_disk_usage_v1';

  EnvironmentProvider({required this.preferences}) {
    loaded = _load();
  }

  final BusinessPreferences preferences;
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

  Future<void> setDownloadSource(
    RootfsDownloadSource source, {
    String? customUrl,
  }) async {
    final url = customUrl?.trim() ?? _downloadUrl;
    if (source == RootfsDownloadSource.custom) {
      RootfsSource.customTarballUri(url, 'arm64');
    }
    await preferences.setString(downloadUrlKey, url);
    await preferences.setString(downloadSourceKey, source.name);
    _downloadSource = source;
    _downloadUrl = url;
    notifyListeners();
  }

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
    final sourceName = preferences.getString(downloadSourceKey);
    _downloadSource =
        RootfsDownloadSource.values
            .where((s) => s.name == sourceName)
            .firstOrNull ??
        RootfsDownloadSource.automatic;
    _downloadUrl = preferences.getString(downloadUrlKey) ?? '';
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
