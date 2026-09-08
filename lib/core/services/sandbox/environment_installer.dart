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
  static const architectureMismatch = 'architecture_mismatch';
  static const prootMissing = 'proot_missing';
  static const insufficientDisk = 'insufficient_disk';
  static const network = 'network';
  static const checksumMismatch = 'checksum_mismatch';
  static const extractFailed = 'extract_failed';
  static const patchFailed = 'patch_failed';
  static const cancelled = 'cancelled';
  static const invalidRootfs = 'invalid_rootfs';
}

/// Android grants the app network via GID 3003 (inet) and 9997 (everybody).
/// [WorkspaceChannel.probe] does not currently expose the app uid, so we send
/// these two groups and let the native patcher also inject `/proc/self`
/// supplementary groups.
const List<int> kAndroidNetworkGids = <int>[3003, 9997];

const int kMinFreeBytes = 600 * 1024 * 1024;
const String kKelivoVersionFile = '.kelivo-version';

/// APK ABI changes preserve app data, including the previous guest system.
/// Reject an incompatible install without deleting it or changing its metadata.
Future<bool> validateInstalledRootfsArchitecture({
  required EnvironmentProvider env,
  required Directory rootfsDir,
  required String abi,
}) async {
  var installedArch = env.state.arch;
  final marker = File(p.join(rootfsDir.path, kKelivoVersionFile));
  if (await marker.exists()) {
    final parts = (await marker.readAsString()).trim().split(RegExp(r'\s+'));
    if (parts.length >= 3) installedArch = parts[2];
  }
  if (installedArch == null) return true;
  final arch = RootfsSource.archForAbi(abi);
  if (installedArch == arch) return true;
  final error = arch == null
      ? EnvironmentError.unsupportedAbi
      : EnvironmentError.architectureMismatch;
  if (env.state.phase != EnvironmentPhase.error ||
      env.state.errorMessage != error) {
    await env.setState(
      env.state.copyWith(
        phase: EnvironmentPhase.error,
        errorMessage: error,
        clearProgress: true,
      ),
    );
  }
  return false;
}

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
  Set<MirrorCategory> get mirrorCategories => {
    if (env.state.distro == 'alpine')
      MirrorCategory.apk
    else if (env.state.distro == 'ubuntu' ||
        env.state.distro == 'debian' ||
        env.state.distro == null)
      MirrorCategory.apt,
    MirrorCategory.pip,
    MirrorCategory.npm,
  };
  final RootfsSource source;
  EnvironmentState? _previousState;
  int _minFreeBytes = kMinFreeBytes;
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
      await _validateInstalledArchitecture();
      _previousState =
          await File(p.join(rootfsDir.path, kKelivoVersionFile)).exists()
          ? env.state
          : null;
      await channel.setEnvironmentBusy(true);
      await channel.keepScreenOn(true);
      await _installBody();
    } on _InstallStopped {
      // State already persisted by [_fail] or [_throwIfCancelled].
    } catch (_) {
      await _fail(EnvironmentError.extractFailed);
    } finally {
      _onProgress = null;
      _downloadSub = null;
      if (_abortDownload?.isCompleted == false) _abortDownload!.complete();
      _abortDownload = null;
      _downloadDone = null;
      if (_resolvedEnvDir != null) {
        // Keep resumable downloads, but never retain a half-extracted image.
        try {
          await _deleteIfExists(stagingRootfsDir);
        } catch (_) {}
      }
      _previousState = null;
      try {
        await channel.setEnvironmentBusy(false);
        await channel.keepScreenOn(false);
      } catch (_) {}
      _installing = false;
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
    if (_installing) return;
    await env.loaded;
    await _resolveEnvDir();
    _cancelled = false;
    try {
      if (!await _validateInstalledArchitecture()) return;
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
        ubuntuCodename: env.state.codename ?? '',
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
    if (_installing) return;
    await channel.setEnvironmentBusy(true);
    try {
      // Remove recovery data first so a later startup cannot resurrect it
      // after the current rootfs has been deleted.
      await _deleteIfExists(
        Directory(p.join(_requireEnvDir().path, 'previous-rootfs')),
      );
      await _deleteIfExists(rootfsDir);
      await _deleteIfExists(
        Directory(p.join(_requireEnvDir().path, 'staging')),
      );
      await _deleteIfExists(downloadsDir);
      await _setPhase(const EnvironmentState());
    } finally {
      await channel.setEnvironmentBusy(false);
    }
  }

  @override
  Future<bool> checkForUpdate() async {
    await _resolveEnvDir();
    final installed = await _readVersionFile();
    if (installed == null) return false;
    final versions = RootfsCatalog.forDistro(installed.distro);
    if (versions.isEmpty) return false;
    final latest = versions.first;
    if (!_newerVersion(latest.version, installed.version)) {
      if (env.state.availableVersion != null) {
        await _setPhase(env.state.copyWith(clearAvailableVersion: true));
      }
      return false;
    }
    await _setPhase(env.state.copyWith(availableVersion: latest.version));
    return true;
  }

  @override
  Future<void> ensureInstalled() async {
    await env.loaded;
    await _resolveEnvDir();
    if (await File(p.join(rootfsDir.path, kKelivoVersionFile)).exists()) {
      if (!await _validateInstalledArchitecture()) return;
      if (env.state.phase != EnvironmentPhase.ready) {
        final parsed = await _readVersionFile();
        await _setPhase(
          EnvironmentState(
            phase: EnvironmentPhase.ready,
            distro: parsed?.distro ?? 'custom',
            version: parsed?.version ?? 'local',
            arch: parsed?.arch ?? 'arm64',
            codename: parsed?.codename,
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

  static bool _newerVersion(String candidate, String installed) {
    final a = candidate.split('.').map(int.tryParse).toList();
    final b = installed.split('.').map(int.tryParse).toList();
    if (a.contains(null) || b.contains(null)) return false;
    for (var i = 0; i < max(a.length, b.length); i++) {
      final comparison = (i < a.length ? a[i]! : 0).compareTo(
        i < b.length ? b[i]! : 0,
      );
      if (comparison != 0) return comparison > 0;
    }
    return false;
  }

  Future<void> _installBody() async {
    final selectedSource = env.downloadSource;
    final source = this.source.forImage(env.rootfsImage);
    final image = source.image;
    final local = selectedSource == RootfsDownloadSource.local;
    final customUrl = env.downloadUrl;
    final localPath = env.localArchivePath;
    _minFreeBytes = local ? 64 * 1024 * 1024 : image.minFreeBytes;
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
        phase: local
            ? EnvironmentPhase.verifying
            : EnvironmentPhase.downloading,
        distro: local ? 'custom' : image.distro,
        version: local ? null : image.version,
        codename: local ? null : image.codename,
        arch: arch,
        rootfsDir: rootfsDir.path,
      ),
    );
    final space = await _safeFreeSpace(_requireEnvDir().path);
    if (space.freeBytes < _minFreeBytes) {
      await _fail(EnvironmentError.insufficientDisk);
      return;
    }

    final File archive;
    final String format;
    if (local) {
      archive = File(localPath);
      final detected = RootfsSource.archiveFormat(localPath);
      if (detected == null ||
          !await archive.exists() ||
          await archive.length() == 0) {
        await _fail(EnvironmentError.invalidRootfs);
        return;
      }
      format = detected;
      if (space.freeBytes < max(_minFreeBytes, await archive.length() * 4)) {
        await _fail(EnvironmentError.insufficientDisk);
        return;
      }
    } else {
      format = image.format;
      archive = File(
        p.join(downloadsDir.path, '${source.tarballFileName(arch)}.part'),
      );
      Uri downloadUri;
      try {
        downloadUri =
            source.selectedUri(selectedSource, customUrl, arch) ??
            await _pickDownloadUri(source, arch);
      } catch (_) {
        await _fail(EnvironmentError.network);
        return;
      }
      final origin = File('${archive.path}.url');
      if (await archive.exists() &&
          (!await origin.exists() ||
              await origin.readAsString() != downloadUri.toString())) {
        await archive.delete();
      }
      await origin.parent.create(recursive: true);
      await origin.writeAsString(downloadUri.toString(), flush: true);
      await _throwIfCancelled();
      await _setPhase(
        env.state.copyWith(
          lastMirrorBase: downloadUri.toString(),
          progress: 0,
          bytesDownloaded: 0,
        ),
      );
      try {
        await _download(uri: downloadUri, partFile: archive);
      } on _InstallStopped {
        rethrow;
      } catch (_) {
        await _fail(
          _cancelled ? EnvironmentError.cancelled : EnvironmentError.network,
        );
        return;
      }
      await _throwIfCancelled();
      await _setPhase(
        env.state.copyWith(phase: EnvironmentPhase.verifying, progress: 1),
      );
      final digest = (await channel.sha256File(archive.path)).toLowerCase();
      if (digest != source.checksums[arch]!.toLowerCase()) {
        await archive.delete();
        await _fail(EnvironmentError.checksumMismatch);
        return;
      }
    }

    await _throwIfCancelled();
    final staging = stagingRootfsDir;
    await _deleteIfExists(staging);
    await staging.create(recursive: true);
    await tmpDir.create(recursive: true);
    await _setPhase(
      env.state.copyWith(
        phase: EnvironmentPhase.extracting,
        clearProgress: true,
        clearBytesDownloaded: true,
        clearBytesTotal: true,
      ),
    );
    final extractSub = channel.events.listen((event) {
      if (event['type'] != 'extract' ||
          event['destDir']?.toString() != staging.path) {
        return;
      }
      final bytes = _asInt(event['bytes']);
      if (bytes != null) {
        unawaited(_setPhase(env.state.copyWith(bytesDownloaded: bytes)));
      }
    });
    try {
      await channel.extractRootfs(
        archivePath: archive.path,
        destDir: staging.path,
        format: format,
      );
    } catch (_) {
      await _fail(EnvironmentError.extractFailed);
      return;
    } finally {
      await extractSub.cancel();
    }
    await _throwIfCancelled();
    Map<String, Object?> info;
    try {
      info = await channel.inspectRootfs(staging.path, arch);
      if (!local && info['distro'] != image.distro) {
        throw const FormatException('Image distribution mismatch');
      }
    } catch (_) {
      await _fail(EnvironmentError.invalidRootfs);
      return;
    }
    final distro = info['distro']! as String;
    final version = local ? info['version']! as String : image.version;
    final codename = info['codename'] as String? ?? '';
    await _setPhase(env.state.copyWith(phase: EnvironmentPhase.patching));
    try {
      await channel.patchRootfs(
        rootfsDir: staging.path,
        arch: arch,
        gids: patchGids,
        ubuntuCodename: codename,
      );
    } catch (_) {
      await _fail(EnvironmentError.patchFailed);
      return;
    }
    await _throwIfCancelled();
    final versionPath = p.join(staging.path, kKelivoVersionFile);
    // Imported archives can contain guest-absolute links. Remove the link
    // itself, including a dangling one, before writing this app-owned marker.
    final versionLink = Link(versionPath);
    if (await versionLink.exists()) await versionLink.delete();
    await File(
      versionPath,
    ).writeAsString('$distro $version $arch $codename\n', flush: true);
    // Keep the previous rootfs until the new one has been fully prepared.
    final previous = Directory(
      p.join(_requireEnvDir().path, 'previous-rootfs'),
    );
    await _deleteIfExists(previous);
    final hadPrevious = await rootfsDir.exists();
    if (hadPrevious) await rootfsDir.rename(previous.path);
    try {
      await staging.rename(rootfsDir.path);
    } catch (_) {
      if (hadPrevious) await previous.rename(rootfsDir.path);
      rethrow;
    }
    await _setPhase(
      EnvironmentState(
        phase: EnvironmentPhase.ready,
        distro: distro,
        version: version,
        codename: codename,
        arch: arch,
        installedAt: DateTime.now().toUtc(),
        rootfsDir: rootfsDir.path,
        lastMirrorBase: env.state.lastMirrorBase,
      ),
    );
    _previousState = null;
    await env.clearCachedDiskUsage();
    await _deleteIfExists(previous);
    if (!local) await _deleteIfExists(downloadsDir);
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

  Future<Uri> _pickDownloadUri(RootfsSource source, String arch) async {
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
      final needed = max(total * 4, _minFreeBytes);
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
      (_previousState ?? env.state).copyWith(
        phase: _previousState?.phase == EnvironmentPhase.ready
            ? EnvironmentPhase.ready
            : EnvironmentPhase.error,
        errorMessage: code,
        clearProgress: true,
      ),
    );
  }

  Future<void> _setPhase(EnvironmentState state) async {
    await env.setState(state);
    _onProgress?.call(state);
  }

  Future<bool> _validateInstalledArchitecture() async {
    if (!await rootfsDir.exists()) return true;
    return validateInstalledRootfsArchitecture(
      env: env,
      rootfsDir: rootfsDir,
      abi: (await channel.probe()).abi,
    );
  }

  /// Recover a process exit between the two directory renames on replacement.
  Future<void> recoverInterruptedInstall() async {
    await env.loaded;
    await _resolveEnvDir();
    if ({
      EnvironmentPhase.downloading,
      EnvironmentPhase.verifying,
      EnvironmentPhase.extracting,
      EnvironmentPhase.patching,
    }.contains(env.state.phase)) {
      final installed = await _readVersionFile();
      await env.setState(
        installed == null
            ? const EnvironmentState()
            : EnvironmentState(
                phase: EnvironmentPhase.ready,
                distro: installed.distro,
                version: installed.version,
                arch: installed.arch,
                codename: installed.codename,
                rootfsDir: rootfsDir.path,
              ),
      );
    }
    await _validateInstalledArchitecture();
  }

  Future<Directory> _resolveEnvDir() async {
    if (_resolvedEnvDir != null) return _resolvedEnvDir!;
    final dir =
        environmentDir ?? await AppDirectories.getEnvironmentDirectory();
    final root = Directory(p.join(dir.path, 'rootfs'));
    final previous = Directory(p.join(dir.path, 'previous-rootfs'));
    if (!await root.exists() && await previous.exists()) {
      await previous.rename(root.path);
    }
    return _resolvedEnvDir = dir;
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

  Future<({String distro, String version, String arch, String? codename})?>
  _readVersionFile() async {
    final file = File(p.join(rootfsDir.path, kKelivoVersionFile));
    if (!await file.exists()) return null;
    final parts = (await file.readAsString()).trim().split(RegExp(r'\s+'));
    if (parts.length < 3) return null;
    return (
      distro: parts[0],
      version: parts[1],
      arch: parts[2],
      codename: parts.length > 3 ? parts[3] : null,
    );
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
