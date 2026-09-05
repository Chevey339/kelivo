import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

import 'package:Kelivo/core/models/environment_state.dart';
import 'package:Kelivo/core/providers/environment_provider.dart';
import 'package:Kelivo/core/services/sandbox/environment_manager.dart';
import 'package:Kelivo/core/services/sandbox/mirror_speed_test.dart';
import 'package:Kelivo/core/services/sandbox/rootfs_source.dart';
import 'package:Kelivo/core/services/sandbox/workspace_channel.dart';
import 'package:Kelivo/utils/app_directories.dart';

/// Machine-readable [EnvironmentState.errorMessage] codes for UI localization.
abstract final class EnvironmentError {
  static const unsupportedAbi = 'unsupported_abi';
  static const prootMissing = 'proot_missing';
  static const insufficientDisk = 'insufficient_disk';
  static const network = 'network';
  static const checksumMismatch = 'checksum_mismatch';
  static const extractFailed = 'extract_failed';
  static const patchFailed = 'patch_failed';
  static const cancelled = 'cancelled';
}

/// Android grants the app network via GID 3003 (inet) and 9997 (everybody).
/// [WorkspaceChannel.probe] does not currently expose the app uid, so we send
/// these two groups and let the native patcher also inject `/proc/self`
/// supplementary groups.
const List<int> kAndroidNetworkGids = <int>[3003, 9997];

const int kMinFreeBytes = 600 * 1024 * 1024;
const String kKelivoVersionFile = '.kelivo-version';

class EnvironmentInstaller implements EnvironmentManager {
  EnvironmentInstaller({
    required this.channel,
    required this.env,
    required this.source,
    required this.speedTest,
    http.Client? client,
    this.environmentDir,
    this.patchGids = kAndroidNetworkGids,
  }) : _client = client ?? http.Client();

  final WorkspaceChannel channel;

  @override
  final EnvironmentProvider env;

  @override
  Set<MirrorCategory> get mirrorCategories => const {
    MirrorCategory.apt,
    MirrorCategory.pip,
    MirrorCategory.npm,
  };
  final RootfsSource source;
  final MirrorSpeedTest speedTest;
  final http.Client _client;
  final List<int> patchGids;
  final Directory? environmentDir;
  Directory? _resolvedEnvDir;

  bool _cancelled = false;
  bool _installing = false;
  Completer<void>? _abortDownload;
  Completer<void>? _downloadDone;
  StreamSubscription<List<int>>? _downloadSub;
  void Function(EnvironmentState)? _onProgress;

  Directory get rootfsDir => Directory(p.join(_requireEnvDir().path, 'rootfs'));

  Directory get tmpDir => Directory(p.join(_requireEnvDir().path, 'tmp'));

  Directory get stagingRootfsDir =>
      Directory(p.join(_requireEnvDir().path, 'staging', 'rootfs'));

  Directory get downloadsDir =>
      Directory(p.join(_requireEnvDir().path, 'downloads'));

  @override
  Future<void> install({void Function(EnvironmentState)? onProgress}) async {
    if (_installing) return;
    _installing = true;
    _cancelled = false;
    _abortDownload = Completer<void>();
    _onProgress = onProgress;
    try {
      await env.loaded;
      await _resolveEnvDir();
      await channel.keepScreenOn(true);
      await _installBody();
    } on _InstallStopped {
      // State already persisted by [_fail] or [_throwIfCancelled].
    } finally {
      _installing = false;
      _onProgress = null;
      _downloadSub = null;
      if (_abortDownload?.isCompleted == false) _abortDownload!.complete();
      _abortDownload = null;
      _downloadDone = null;
      try {
        await channel.keepScreenOn(false);
      } catch (_) {}
    }
  }

  @override
  Future<void> cancel() async {
    _cancelled = true;
    if (_abortDownload?.isCompleted == false) _abortDownload!.complete();
    if (_downloadDone?.isCompleted == false) _downloadDone!.complete();
    await _downloadSub?.cancel();
    _downloadSub = null;
  }

  @override
  Future<void> repair() async {
    await _resolveEnvDir();
    _cancelled = false;
    try {
      await _setPhase(
        env.state.copyWith(
          phase: EnvironmentPhase.patching,
          clearErrorMessage: true,
        ),
      );
      await channel.patchRootfs(
        rootfsDir: rootfsDir.path,
        arch: env.state.arch ?? 'arm64',
        gids: patchGids,
        ubuntuCodename: kUbuntuCodename,
        aptMirrorBaseUrl: env.mirrors[MirrorCategory.apt]?.selectedBaseUrl,
      );
      await _setPhase(
        env.state.copyWith(
          phase: EnvironmentPhase.ready,
          installedAt: DateTime.now().toUtc(),
          rootfsDir: rootfsDir.path,
          clearErrorMessage: true,
          clearProgress: true,
        ),
      );
    } on WorkspaceChannelException {
      await _fail(EnvironmentError.patchFailed);
    } catch (_) {
      await _fail(EnvironmentError.patchFailed);
    }
  }

  @override
  Future<void> reset() async {
    await _resolveEnvDir();
    await _deleteIfExists(rootfsDir);
    await _deleteIfExists(Directory(p.join(_requireEnvDir().path, 'staging')));
    await _deleteIfExists(downloadsDir);
    await _setPhase(const EnvironmentState());
  }

  @override
  Future<bool> checkForUpdate() async {
    await _resolveEnvDir();
    final installed = await _readVersionFile();
    if (installed == null) return false;
    if (installed.version == kUbuntuBaseVersion) {
      if (env.state.availableVersion != null) {
        await _setPhase(env.state.copyWith(clearAvailableVersion: true));
      }
      return false;
    }
    await _setPhase(env.state.copyWith(availableVersion: kUbuntuBaseVersion));
    return true;
  }

  @override
  Future<void> ensureInstalled() async {
    await env.loaded;
    await _resolveEnvDir();
    if (await File(p.join(rootfsDir.path, kKelivoVersionFile)).exists()) {
      if (env.state.phase != EnvironmentPhase.ready) {
        final parsed = await _readVersionFile();
        await _setPhase(
          EnvironmentState(
            phase: EnvironmentPhase.ready,
            distro: parsed?.distro ?? kUbuntuDistro,
            version: parsed?.version ?? kUbuntuBaseVersion,
            arch: parsed?.arch ?? 'arm64',
            installedAt: DateTime.now().toUtc(),
            rootfsDir: rootfsDir.path,
            lastMirrorBase: env.state.lastMirrorBase,
          ),
        );
      }
      return;
    }
    await install();
  }

  Future<void> _installBody() async {
    final selectedSource = env.downloadSource;
    final customUrl = env.downloadUrl;
    final probe = await _safeProbe();
    if (!probe.supported) {
      await _fail(EnvironmentError.prootMissing);
      return;
    }
    final arch = RootfsSource.archForAbi(probe.abi);
    if (arch == null) {
      await _fail(EnvironmentError.unsupportedAbi);
      return;
    }

    await _setPhase(
      EnvironmentState(
        phase: EnvironmentPhase.downloading,
        distro: kUbuntuDistro,
        version: kUbuntuBaseVersion,
        arch: arch,
        rootfsDir: rootfsDir.path,
        lastMirrorBase: env.state.lastMirrorBase,
      ),
    );

    final space = await _safeFreeSpace(_requireEnvDir().path);
    if (space.freeBytes < kMinFreeBytes) {
      await _fail(EnvironmentError.insufficientDisk);
      return;
    }

    final expectedSha = source.checksums[arch]!;

    final tarballName = RootfsSource.tarballFileName(arch);
    final partFile = File(p.join(downloadsDir.path, '$tarballName.part'));
    Uri downloadUri;
    try {
      downloadUri =
          source.selectedUri(selectedSource, customUrl, arch) ??
          await _pickDownloadUri(arch);
    } catch (_) {
      await _fail(EnvironmentError.network);
      return;
    }
    final originFile = File('${partFile.path}.url');
    if (await partFile.exists() &&
        (!await originFile.exists() ||
            await originFile.readAsString() != downloadUri.toString())) {
      await partFile.delete();
    }
    await originFile.parent.create(recursive: true);
    await originFile.writeAsString(downloadUri.toString(), flush: true);
    await _throwIfCancelled();

    await _setPhase(
      env.state.copyWith(
        phase: EnvironmentPhase.downloading,
        lastMirrorBase: downloadUri.toString(),
        progress: 0,
        bytesDownloaded: 0,
        clearErrorMessage: true,
      ),
    );

    try {
      await _download(uri: downloadUri, partFile: partFile);
    } on _InstallStopped {
      rethrow;
    } catch (error) {
      if (error is _InstallStopped) rethrow;
      await _fail(
        _cancelled ? EnvironmentError.cancelled : EnvironmentError.network,
      );
      return;
    }

    await _throwIfCancelled();
    await _setPhase(
      env.state.copyWith(phase: EnvironmentPhase.verifying, progress: 1),
    );

    String digest;
    try {
      digest = (await channel.sha256File(partFile.path)).toLowerCase();
    } catch (_) {
      await _fail(EnvironmentError.network);
      return;
    }
    if (digest != expectedSha.toLowerCase()) {
      if (await partFile.exists()) await partFile.delete();
      await _fail(EnvironmentError.checksumMismatch);
      return;
    }

    await _throwIfCancelled();
    final staging = stagingRootfsDir;
    if (await staging.exists()) {
      await staging.delete(recursive: true);
    }
    await staging.create(recursive: true);
    await tmpDir.create(recursive: true);

    await _setPhase(env.state.copyWith(phase: EnvironmentPhase.extracting));
    final extractSub = channel.events.listen((event) {
      if (event['type'] != 'extract') return;
      if (event['destDir']?.toString() != staging.path) return;
      final bytes = _asInt(event['bytes']);
      if (bytes == null) return;
      unawaited(
        _setPhase(
          env.state.copyWith(
            phase: EnvironmentPhase.extracting,
            bytesDownloaded: bytes,
            progress: env.state.bytesTotal == null
                ? null
                : (bytes / env.state.bytesTotal!).clamp(0.0, 1.0),
          ),
        ),
      );
    });
    try {
      await channel.extractRootfs(
        archivePath: partFile.path,
        destDir: staging.path,
        format: 'tar.gz',
      );
    } on WorkspaceChannelException {
      await extractSub.cancel();
      await _fail(EnvironmentError.extractFailed);
      return;
    } catch (_) {
      await extractSub.cancel();
      await _fail(EnvironmentError.extractFailed);
      return;
    } finally {
      await extractSub.cancel();
    }

    await _throwIfCancelled();
    await _setPhase(env.state.copyWith(phase: EnvironmentPhase.patching));
    try {
      await channel.patchRootfs(
        rootfsDir: staging.path,
        arch: arch,
        gids: patchGids,
        ubuntuCodename: kUbuntuCodename,
        aptMirrorBaseUrl: env.mirrors[MirrorCategory.apt]?.selectedBaseUrl,
      );
    } on WorkspaceChannelException {
      await _fail(EnvironmentError.patchFailed);
      return;
    } catch (_) {
      await _fail(EnvironmentError.patchFailed);
      return;
    }

    if (await rootfsDir.exists()) {
      await rootfsDir.delete(recursive: true);
    }
    await staging.rename(rootfsDir.path);
    await File(
      p.join(rootfsDir.path, kKelivoVersionFile),
    ).writeAsString('$kUbuntuDistro $kUbuntuBaseVersion $arch\n', flush: true);
    await _setPhase(
      EnvironmentState(
        phase: EnvironmentPhase.ready,
        distro: kUbuntuDistro,
        version: kUbuntuBaseVersion,
        arch: arch,
        installedAt: DateTime.now().toUtc(),
        rootfsDir: rootfsDir.path,
        lastMirrorBase: env.state.lastMirrorBase,
      ),
    );
  }

  Future<ProbeResult> _safeProbe() async {
    try {
      return await channel.probe();
    } on WorkspaceChannelException {
      await _fail(EnvironmentError.prootMissing);
      throw const _InstallStopped();
    }
  }

  Future<FreeSpace> _safeFreeSpace(String path) async {
    try {
      return await channel.freeSpace(path);
    } on WorkspaceChannelException {
      await _fail(EnvironmentError.insufficientDisk);
      throw const _InstallStopped();
    }
  }

  Future<Uri> _pickDownloadUri(String arch) async {
    final official = source.officialTarballUri(arch);
    try {
      final probes = await speedTest.probe(source.tarballCandidates(arch));
      return MirrorSpeedTest.pickFastest(probes, official: official);
    } catch (_) {
      return official;
    }
  }

  Future<void> _download({required Uri uri, required File partFile}) async {
    await partFile.parent.create(recursive: true);
    var existing = 0;
    if (await partFile.exists()) {
      existing = await partFile.length();
    }

    final request = http.AbortableRequest(
      'GET',
      uri,
      abortTrigger: _abortDownload?.future,
    );
    if (existing > 0) {
      request.headers['range'] = 'bytes=$existing-';
      request.headers['Range'] = 'bytes=$existing-';
    }

    final response = await _client
        .send(request)
        .timeout(const Duration(seconds: 30));
    await _throwIfCancelled();

    if (existing > 0 &&
        response.statusCode == 416 &&
        _totalFromResponse(response, 0) == existing) {
      await response.stream.drain<void>();
      return; // A complete cached archive still goes through SHA-256 verification.
    }
    if (existing > 0 && response.statusCode == 200) {
      await partFile.writeAsBytes(const <int>[], flush: true);
      existing = 0;
    } else if (existing > 0 && response.statusCode != 206) {
      throw HttpException('resume HTTP ${response.statusCode}', uri: uri);
    } else if (existing == 0 &&
        response.statusCode != 200 &&
        response.statusCode != 206) {
      throw HttpException('download HTTP ${response.statusCode}', uri: uri);
    }

    final total = _totalFromResponse(response, existing);
    if (total != null) {
      final needed = max(total * 4, kMinFreeBytes);
      final space = await channel.freeSpace(_requireEnvDir().path);
      if (space.freeBytes < needed) {
        await _fail(EnvironmentError.insufficientDisk);
        throw const _InstallStopped();
      }
    }

    final sink = partFile.openWrite(mode: FileMode.append);
    var downloaded = existing;
    try {
      final completer = _downloadDone = Completer<void>();
      _downloadSub = response.stream
          .timeout(const Duration(seconds: 30))
          .listen(
            (chunk) {
              if (_cancelled) {
                if (!completer.isCompleted) completer.complete();
                return;
              }
              sink.add(chunk);
              downloaded += chunk.length;
              unawaited(
                _setPhase(
                  env.state.copyWith(
                    phase: EnvironmentPhase.downloading,
                    bytesDownloaded: downloaded,
                    bytesTotal: total,
                    progress: total == null || total == 0
                        ? null
                        : (downloaded / total).clamp(0.0, 1.0),
                  ),
                ),
              );
            },
            onError: (Object error, StackTrace stack) {
              if (!completer.isCompleted) completer.completeError(error, stack);
            },
            onDone: () {
              if (!completer.isCompleted) completer.complete();
            },
            cancelOnError: true,
          );
      await completer.future;
      await sink.flush();
    } finally {
      await sink.close();
      await _downloadSub?.cancel();
      _downloadSub = null;
    }
    if (_cancelled) {
      await _fail(EnvironmentError.cancelled);
      throw const _InstallStopped();
    }
  }

  static int? _totalFromResponse(http.StreamedResponse response, int existing) {
    final range = response.headers['content-range'];
    if (range != null) {
      final slash = range.lastIndexOf('/');
      if (slash != -1) {
        final total = int.tryParse(range.substring(slash + 1));
        if (total != null && total > 0) return total;
      }
    }
    final length = response.contentLength;
    if (length == null) return null;
    if (response.statusCode == 206) return existing + length;
    return length;
  }

  Future<void> _throwIfCancelled() async {
    if (!_cancelled) return;
    await _fail(EnvironmentError.cancelled);
    throw const _InstallStopped();
  }

  Future<void> _fail(String code) async {
    await _setPhase(
      env.state.copyWith(
        phase: EnvironmentPhase.error,
        errorMessage: code,
        clearProgress: true,
      ),
    );
  }

  Future<void> _setPhase(EnvironmentState state) async {
    await env.setState(state);
    _onProgress?.call(state);
  }

  Future<Directory> _resolveEnvDir() async {
    return _resolvedEnvDir ??=
        environmentDir ?? await AppDirectories.getEnvironmentDirectory();
  }

  Directory _requireEnvDir() {
    final dir = _resolvedEnvDir ?? environmentDir;
    if (dir == null) {
      throw StateError(
        'environment directory not resolved; call install or ensureInstalled first',
      );
    }
    return dir;
  }

  Future<({String distro, String version, String arch})?>
  _readVersionFile() async {
    final file = File(p.join(rootfsDir.path, kKelivoVersionFile));
    if (!await file.exists()) return null;
    final parts = (await file.readAsString()).trim().split(RegExp(r'\s+'));
    if (parts.length < 3) return null;
    return (distro: parts[0], version: parts[1], arch: parts[2]);
  }

  Future<void> _deleteIfExists(FileSystemEntity entity) async {
    if (await entity.exists()) {
      await entity.delete(recursive: true);
    }
  }

  static int? _asInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return null;
  }
}

class _InstallStopped implements Exception {
  const _InstallStopped();
}
