import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'package:Kelivo/core/models/workspace_directory_access.dart';

const String kWorkspaceMethodChannel = 'app.workspace';
const String kWorkspaceEventChannel = 'app.workspace/events';

/// Thin typed client over the workspace method/event channels.
///
/// Android (proot) and iOS (iSH) register the same channel names. Callers omit
/// platform-specific keys (e.g. [ExecArgs.rootfsDir] on iOS) rather than
/// sending nulls.
class WorkspaceChannel {
  WorkspaceChannel({
    MethodChannel? methodChannel,
    EventChannel? eventChannel,
    BinaryMessenger? messenger,
  }) : _methods =
           methodChannel ??
           MethodChannel(
             kWorkspaceMethodChannel,
             const StandardMethodCodec(),
             messenger,
           ),
       _events =
           eventChannel ??
           EventChannel(
             kWorkspaceEventChannel,
             const StandardMethodCodec(),
             messenger,
           );

  final MethodChannel _methods;
  final EventChannel _events;
  Stream<Map<String, Object?>>? _eventStream;

  static bool get isSupportedPlatform =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  Stream<Map<String, Object?>> get events {
    return _eventStream ??= _events.receiveBroadcastStream().map(_asEventMap);
  }

  Future<ProbeResult> probe() async {
    try {
      final raw = await _methods.invokeMethod<Object?>('probe');
      return ProbeResult.fromMap(_asStringKeyedMap(raw, 'probe'));
    } on MissingPluginException {
      return const ProbeResult(
        supported: false,
        abi: '',
        reason: 'missing_plugin',
      );
    }
  }

  Future<void> exec(ExecArgs args) async {
    await _invoke('exec', args.toMap());
  }

  Future<bool> cancel(String runId) async {
    final raw = await _invoke('cancel', {'runId': runId});
    return raw == true;
  }

  Future<int?> ptyOpen({
    required String sessionId,
    String? rootfsDir,
    String? tmpDir,
    required String cwd,
    Map<String, String> env = const <String, String>{},
    List<BindMount> binds = const <BindMount>[],
    required int cols,
    required int rows,
  }) async {
    final raw = await _invoke('ptyOpen', {
      'sessionId': sessionId,
      if (rootfsDir != null) 'rootfsDir': rootfsDir,
      if (tmpDir != null) 'tmpDir': tmpDir,
      'cwd': cwd,
      'env': env,
      'binds': [for (final bind in binds) bind.toMap()],
      'cols': cols,
      'rows': rows,
    });
    if (raw is Map) {
      return _readInt(_asStringKeyedMap(raw, 'ptyOpen')['pid']);
    }
    return _readInt(raw);
  }

  Future<void> ptyWrite({
    required String sessionId,
    required Uint8List data,
  }) async {
    await _invoke('ptyWrite', {'sessionId': sessionId, 'data': data});
  }

  Future<void> ptyResize({
    required String sessionId,
    required int cols,
    required int rows,
  }) async {
    await _invoke('ptyResize', {
      'sessionId': sessionId,
      'cols': cols,
      'rows': rows,
    });
  }

  Future<void> ptyClose(String sessionId) async {
    await _invoke('ptyClose', {'sessionId': sessionId});
  }

  Future<WorkspaceOkResult> installRootfs() async {
    final raw = await _invoke('installRootfs');
    return WorkspaceOkResult.fromMap(_asStringKeyedMap(raw, 'installRootfs'));
  }

  Future<WorkspaceOkResult> resetRootfs() async {
    final raw = await _invoke('resetRootfs');
    return WorkspaceOkResult.fromMap(_asStringKeyedMap(raw, 'resetRootfs'));
  }

  Future<void> boot() async {
    await _invoke('boot');
  }

  Future<void> beginBackgroundTask() async {
    await _invoke('beginBackgroundTask');
  }

  Future<void> endBackgroundTask() async {
    await _invoke('endBackgroundTask');
  }

  Future<void> extractRootfs({
    required String archivePath,
    required String destDir,
    String format = 'tar.gz',
  }) async {
    await _invoke('extractRootfs', {
      'archivePath': archivePath,
      'destDir': destDir,
      'format': format,
    });
  }

  Future<void> patchRootfs({
    required String rootfsDir,
    String? aptMirrorBaseUrl,
    required String arch,
    List<int> gids = const <int>[3003, 9997],
    String ubuntuCodename = 'noble',
    List<String>? dnsServers,
    String? hostname,
  }) async {
    await _invoke('patchRootfs', {
      'rootfsDir': rootfsDir,
      if (aptMirrorBaseUrl != null) 'aptMirrorBaseUrl': aptMirrorBaseUrl,
      'arch': arch,
      'gids': gids,
      'ubuntuCodename': ubuntuCodename,
      if (dnsServers != null) 'dnsServers': dnsServers,
      if (hostname != null) 'hostname': hostname,
    });
  }

  Future<String> sha256File(String path) async {
    final raw = await _invoke('sha256File', {'path': path});
    if (raw is String && raw.isNotEmpty) return raw;
    throw WorkspaceChannelException(
      code: 'workspace',
      message: 'sha256File returned no digest',
    );
  }

  Future<FreeSpace> freeSpace(String path) async {
    final raw = await _invoke('freeSpace', {'path': path});
    return FreeSpace.fromMap(_asStringKeyedMap(raw, 'freeSpace'));
  }

  Future<void> keepScreenOn(bool enabled) async {
    await _invoke('keepScreenOn', {'enabled': enabled});
  }

  Future<bool> hasDirectoryStorageAccess() async =>
      await _invoke('hasDirectoryStorageAccess') == true;

  Future<void> setExternalMounts(List<BindMount> mounts) async {
    await _invoke('setExternalMounts', {
      'mounts': [for (final mount in mounts) mount.toMap()],
    });
  }

  Future<bool> requestDirectoryStorageAccess() async =>
      await _invoke('requestDirectoryStorageAccess') == true;

  Future<WorkspaceDirectory?> pickDirectory() async {
    final raw = await _invoke('pickDirectory');
    return raw == null ? null : _directoryResult(raw);
  }

  Future<WorkspaceDirectory> resolveDirectory(
    WorkspaceDirectoryAccess access,
  ) async {
    _checkDirectoryPlatform(access);
    return _directoryResult(
      await _invoke('resolveDirectory', {'token': access.token}),
    );
  }

  Future<void> releaseDirectory(WorkspaceDirectoryAccess access) async {
    if (!isSupportedPlatform || access.platform != defaultTargetPlatform.name) {
      return;
    }
    await _invoke('releaseDirectory', {'token': access.token});
  }

  void _checkDirectoryPlatform(WorkspaceDirectoryAccess access) {
    if (!isSupportedPlatform || access.platform != defaultTargetPlatform.name) {
      throw const WorkspaceChannelException(
        code: 'external_folder_unavailable',
      );
    }
  }

  WorkspaceDirectory _directoryResult(Object? raw) {
    final map = _asStringKeyedMap(raw, 'directory');
    final path = map['path'] as String?;
    final token = map['token'] as String?;
    if (path == null || path.isEmpty || token == null || token.isEmpty) {
      throw const WorkspaceChannelException(
        code: 'external_folder_unavailable',
      );
    }
    return WorkspaceDirectory(
      path: path,
      access: WorkspaceDirectoryAccess(
        platform: defaultTargetPlatform.name,
        token: token,
      ),
    );
  }

  Future<Object?> _invoke(String method, [Map<String, Object?>? args]) async {
    try {
      return await _methods.invokeMethod<Object?>(method, args);
    } on MissingPluginException catch (error) {
      throw WorkspaceChannelException(
        code: 'missing_plugin',
        message: error.message,
      );
    } on PlatformException catch (error) {
      throw WorkspaceChannelException(
        code: error.code,
        message: error.message,
        details: error.details,
      );
    }
  }
}

class WorkspaceChannelException implements Exception {
  const WorkspaceChannelException({
    required this.code,
    this.message,
    this.details,
  });

  final String code;
  final String? message;
  final Object? details;

  @override
  String toString() => 'WorkspaceChannelException($code, $message)';
}

class WorkspaceOkResult {
  const WorkspaceOkResult({required this.ok, this.needsRestart = false});

  final bool ok;
  final bool needsRestart;

  factory WorkspaceOkResult.fromMap(Map<String, Object?> map) {
    return WorkspaceOkResult(
      ok: map['ok'] == true,
      needsRestart: map['needsRestart'] == true,
    );
  }
}

class ProbeResult {
  const ProbeResult({
    required this.supported,
    required this.abi,
    this.prootPath,
    this.loaderPath,
    this.nativeLibDir,
    this.reason,
    this.uid,
    this.engine,
    this.installed,
    this.booted,
    this.needsRestart,
    this.rootfsVersion,
    this.bundledVersion,
    this.rootfsDir,
  });

  final bool supported;
  final String abi;
  final String? prootPath;
  final String? loaderPath;
  final String? nativeLibDir;
  final String? reason;

  /// Present when a future plugin reports the app uid. Android probe does not.
  final int? uid;

  /// iOS reports `ish`. Android omits this.
  final String? engine;
  final bool? installed;
  final bool? booted;
  final bool? needsRestart;
  final String? rootfsVersion;
  final String? bundledVersion;
  final String? rootfsDir;

  factory ProbeResult.fromMap(Map<String, Object?> map) {
    return ProbeResult(
      supported: map['supported'] == true,
      abi: _readString(map['abi']) ?? '',
      prootPath: _readString(map['prootPath']),
      loaderPath: _readString(map['loaderPath']),
      nativeLibDir: _readString(map['nativeLibDir']),
      reason: _readString(map['reason']),
      uid: _readInt(map['uid']),
      engine: _readString(map['engine']),
      installed: _readBool(map['installed']),
      booted: _readBool(map['booted']),
      needsRestart: _readBool(map['needsRestart']),
      rootfsVersion: _readString(map['rootfsVersion']),
      bundledVersion: _readString(map['bundledVersion']),
      rootfsDir: _readString(map['rootfsDir']),
    );
  }
}

class ExecArgs {
  const ExecArgs({
    required this.runId,
    this.rootfsDir,
    this.tmpDir,
    required this.cwd,
    required this.command,
    this.timeoutMs = 60000,
    this.env = const <String, String>{},
    this.binds = const <BindMount>[],
  });

  final String runId;
  final String? rootfsDir;
  final String? tmpDir;
  final String cwd;
  final String command;
  final int timeoutMs;
  final Map<String, String> env;
  final List<BindMount> binds;

  Map<String, Object?> toMap() => {
    'runId': runId,
    if (rootfsDir != null) 'rootfsDir': rootfsDir,
    if (tmpDir != null) 'tmpDir': tmpDir,
    'cwd': cwd,
    'command': command,
    'timeoutMs': timeoutMs,
    'env': env,
    'binds': [for (final bind in binds) bind.toMap()],
  };
}

class BindMount {
  const BindMount({
    required this.host,
    required this.guest,
    this.readOnly = false,
  });

  final String host;
  final String guest;
  final bool readOnly;

  Map<String, Object?> toMap() => {
    'host': host,
    'guest': guest,
    if (readOnly) 'readOnly': true,
  };
}

class FreeSpace {
  const FreeSpace({required this.freeBytes, required this.totalBytes});

  final int freeBytes;
  final int totalBytes;

  factory FreeSpace.fromMap(Map<String, Object?> map) {
    return FreeSpace(
      freeBytes: _readInt(map['freeBytes']) ?? 0,
      totalBytes: _readInt(map['totalBytes']) ?? 0,
    );
  }
}

Map<String, Object?> _asEventMap(dynamic event) {
  return _asStringKeyedMap(event, 'event');
}

Map<String, Object?> _asStringKeyedMap(Object? raw, String label) {
  if (raw is Map) {
    return <String, Object?>{
      for (final entry in raw.entries) entry.key.toString(): entry.value,
    };
  }
  throw WorkspaceChannelException(
    code: 'workspace',
    message: '$label result is not a map',
  );
}

String? _readString(Object? value) {
  if (value == null) return null;
  final text = value.toString();
  return text.isEmpty ? null : text;
}

int? _readInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}

bool? _readBool(Object? value) {
  if (value is bool) return value;
  return null;
}
