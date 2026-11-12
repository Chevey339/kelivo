import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import 'package:Kelivo/core/models/environment_state.dart';
import 'package:Kelivo/core/providers/environment_provider.dart';
import 'package:Kelivo/core/services/logging/flutter_logger.dart';
import 'package:Kelivo/core/services/sandbox/ios_ish_runtime.dart';
import 'package:Kelivo/core/services/sandbox/rootfs_disk_usage.dart';
import 'package:Kelivo/core/services/sandbox/workspace_channel.dart';
import 'package:Kelivo/core/services/workspace/workspace_runtime.dart';

abstract class EnvironmentManager {
  EnvironmentProvider get env;
  Set<MirrorCategory> get mirrorCategories;
  Future<void> install({void Function(EnvironmentState)? onProgress});
  Future<void> cancel();
  Future<void> repair();
  Future<void> reset();
  Future<bool> checkForUpdate();
  Future<void> ensureInstalled();
}

/// iOS Alpine rootfs installer over [WorkspaceChannel].
class IosRootfsManager implements EnvironmentManager {
  IosRootfsManager({
    required this.channel,
    required this.env,
    Future<Directory> Function()? alpineRootfsDir,
    this._runInGuest,
    this.repairTimeout = const Duration(minutes: 10),
    this.repairCancelTimeout = const Duration(seconds: 5),
  }) : _alpineRootfsDir = alpineRootfsDir ?? iosAlpineRootfsDir;

  final WorkspaceChannel channel;
  final Future<Directory> Function() _alpineRootfsDir;
  final Future<int> Function(String script)? _runInGuest;
  final Duration repairTimeout;
  final Duration repairCancelTimeout;
  Future<void>? _installFuture;
  Completer<void>? _repairCancellation;

  static const _repairErrors = {
    'patch_failed',
    'patch_interrupted',
    'patch_timeout',
  };

  @override
  final EnvironmentProvider env;

  @override
  Set<MirrorCategory> get mirrorCategories => const {
    MirrorCategory.apk,
    MirrorCategory.pip,
    MirrorCategory.npm,
  };

  void Function(EnvironmentState)? _onProgress;

  @override
  Future<void> install({void Function(EnvironmentState)? onProgress}) {
    return _install(onProgress: onProgress, force: false);
  }

  @override
  Future<void> cancel() async {
    final cancellation = _repairCancellation;
    if (cancellation == null) return;
    if (!cancellation.isCompleted) cancellation.complete();
    await _installFuture;
  }

  /// Called once during startup, before exposing the manager to callers.
  /// A persisted repair phase does not imply a live package transaction.
  Future<void> recoverInterruptedInstall() async {
    await env.loaded;
    final state = env.state;
    if (state.phase == EnvironmentPhase.patching ||
        (state.phase == EnvironmentPhase.needsRestart &&
            _repairErrors.contains(state.errorMessage))) {
      await _set(
        state.copyWith(
          phase: EnvironmentPhase.error,
          errorMessage: 'patch_interrupted',
          clearProgress: true,
        ),
      );
      return;
    }
    if (!{
      EnvironmentPhase.downloading,
      EnvironmentPhase.verifying,
      EnvironmentPhase.extracting,
      EnvironmentPhase.needsRestart,
    }.contains(state.phase)) {
      return;
    }
    try {
      final probe = await channel.probe().timeout(const Duration(seconds: 10));
      if (probe.needsRestart == true) {
        await _set(
          state.copyWith(
            phase: EnvironmentPhase.needsRestart,
            clearProgress: true,
          ),
        );
        return;
      }
      if (probe.installed == true) {
        await _setReady(probe.rootfsVersion, probe.rootfsDir);
      } else {
        await _set(const EnvironmentState());
      }
    } catch (error, stack) {
      FlutterLogger.log('$error\n$stack', tag: 'iOS sandbox recovery');
      await _set(
        state.copyWith(
          phase: EnvironmentPhase.error,
          errorMessage: 'patch_interrupted',
          clearProgress: true,
        ),
      );
    }
  }

  @override
  Future<void> repair() {
    return _install(force: true);
  }

  @override
  Future<void> reset() async {
    final result = await channel.resetRootfs();
    if (result.needsRestart) {
      await _set(const EnvironmentState(phase: EnvironmentPhase.needsRestart));
    } else {
      await _set(const EnvironmentState());
    }
  }

  @override
  Future<bool> checkForUpdate() async {
    final probe = await channel.probe();
    if (probe.rootfsVersion != probe.bundledVersion) {
      await _set(env.state.copyWith(availableVersion: probe.bundledVersion));
      return true;
    }
    if (env.state.availableVersion != null) {
      await _set(env.state.copyWith(clearAvailableVersion: true));
    }
    return false;
  }

  @override
  Future<void> ensureInstalled() async {
    if (env.state.phase == EnvironmentPhase.ready) return;
    await install();
  }

  Future<void> _install({
    void Function(EnvironmentState)? onProgress,
    required bool force,
  }) => _installFuture ??= _performInstall(
    onProgress: onProgress,
    force: force,
  ).whenComplete(() => _installFuture = null);

  Future<void> _performInstall({
    void Function(EnvironmentState)? onProgress,
    required bool force,
  }) async {
    _onProgress = onProgress;
    try {
      await env.loaded;
      // An unresponsive native command must not overlap a second repair.
      // Startup recovery clears this gate after the process has restarted.
      if (env.state.phase == EnvironmentPhase.needsRestart &&
          _repairErrors.contains(env.state.errorMessage)) {
        return;
      }
      final probe = await channel.probe();
      final bundled = probe.bundledVersion;
      final installed = probe.installed == true;
      final sameVersion = probe.rootfsVersion == probe.bundledVersion;
      final requiresRepair =
          force ||
          env.state.phase == EnvironmentPhase.patching ||
          _repairErrors.contains(env.state.errorMessage);
      if (probe.needsRestart == true) {
        await _set(env.state.copyWith(phase: EnvironmentPhase.needsRestart));
        return;
      }
      if (!requiresRepair && installed && sameVersion) {
        await _setReady(bundled, probe.rootfsDir);
        return;
      }
      if (installed) {
        await _repairInstalled(probe);
        return;
      }
      if (requiresRepair) {
        // Failed health probes are not permission to replace the user's
        // existing filesystem with a fresh image.
        await _set(
          env.state.copyWith(
            phase: EnvironmentPhase.error,
            errorMessage: 'patch_failed',
            clearProgress: true,
          ),
        );
        return;
      }

      final progressWrites = <Future<void>>[];
      final sub = channel.events.listen((event) {
        if (event['type'] != 'install') return;
        final progress = event['progress'];
        progressWrites.add(
          _set(
            EnvironmentState(
              phase: EnvironmentPhase.extracting,
              progress: progress is num ? progress.toDouble() : null,
              distro: 'alpine',
              version: bundled,
              arch: 'arm64',
            ),
          ),
        );
      });
      try {
        final result = await channel.installRootfs();
        await Future.wait(progressWrites);
        if (!result.ok && result.needsRestart) {
          await _set(
            EnvironmentState(
              phase: EnvironmentPhase.needsRestart,
              distro: 'alpine',
              version: bundled,
              arch: 'arm64',
            ),
          );
          return;
        }
        final after = await channel.probe();
        await _setReady(bundled, after.rootfsDir);
      } finally {
        await sub.cancel();
      }
    } finally {
      _onProgress = null;
    }
  }

  Future<void> _repairInstalled(ProbeResult probe) async {
    final dir = probe.rootfsDir ?? (await _alpineRootfsDir()).path;
    final version = probe.bundledVersion;
    final runId = 'ios-repair-${const Uuid().v4()}';
    final cancellation = Completer<void>();
    _repairCancellation = cancellation;
    var settled = false;
    Future<int>? execution;
    try {
      await _set(
        env.state.copyWith(
          phase: EnvironmentPhase.patching,
          distro: 'alpine',
          version: probe.rootfsVersion,
          arch: 'arm64',
          rootfsDir: dir,
          availableVersion: version,
          clearErrorMessage: true,
          clearProgress: true,
          clearBytesDownloaded: true,
          clearBytesTotal: true,
        ),
      );
      if (cancellation.isCompleted) throw const _RepairInterrupted();
      execution = _runRepairCommand(runId, cancellation).whenComplete(() {
        settled = true;
      });
      // Boot applies the bundled script through the guest VFS, including to
      // existing environments. apk keeps the user's world and installed tools.
      final exitCode = await Future.any([
        execution,
        cancellation.future.then<int>((_) => throw const _RepairInterrupted()),
      ]).timeout(repairTimeout);
      _repairCancellation = null;
      if (exitCode != 0 || version == null || version.isEmpty) {
        throw StateError('rootfs repair failed (exit $exitCode)');
      }
      // This app-owned marker is outside fakefs data/. Publish it only after
      // the guest transaction and release-file checks have succeeded.
      final pending = File(p.join(dir, '.version.pending'));
      await pending.writeAsString('$version\n', flush: true);
      await pending.rename(p.join(dir, '.version'));
      await _setReady(version, dir);
    } catch (error, stack) {
      FlutterLogger.log('$error\n$stack', tag: 'iOS sandbox repair');
      final aborted = error is TimeoutException || error is _RepairInterrupted;
      var needsRestart = error is _RepairTerminationUnconfirmed;
      final running = execution;
      if (aborted && running != null && !settled) {
        if (!cancellation.isCompleted) cancellation.complete();
        // Cancellation also reaches execs still queued behind native boot.
        unawaited(
          channel
              .cancel(runId)
              .then<void>(
                (_) {},
                onError: (Object error, StackTrace stack) {
                  FlutterLogger.log(
                    '$error\n$stack',
                    tag: 'iOS sandbox cancel',
                  );
                },
              ),
        );
        needsRestart = !await running
            .then<bool>(
              (_) => true,
              onError: (Object error, StackTrace _) =>
                  error is! _RepairTerminationUnconfirmed,
            )
            .timeout(repairCancelTimeout, onTimeout: () => false);
      }
      await _set(
        env.state.copyWith(
          phase: needsRestart
              ? EnvironmentPhase.needsRestart
              : EnvironmentPhase.error,
          errorMessage: error is TimeoutException
              ? 'patch_timeout'
              : error is _RepairInterrupted ||
                    error is _RepairTerminationUnconfirmed
              ? 'patch_interrupted'
              : 'patch_failed',
          clearProgress: true,
        ),
      );
    } finally {
      _repairCancellation = null;
    }
  }

  Future<int> _runRepairCommand(
    String runId,
    Completer<void> cancellation,
  ) async {
    const script = '/bin/sh /usr/local/bin/kelivo-repair-rootfs';
    if (cancellation.isCompleted) throw const _RepairInterrupted();
    final override = _runInGuest;
    if (override != null) return override(script);
    final config = await env.loadExecutionConfig();
    if (cancellation.isCompleted) throw const _RepairInterrupted();
    CommandExited? exit;
    await for (final event in IosIshRuntime(channel: channel).run(
      CommandRequest(
        runId: runId,
        command: script,
        cwd: '/',
        timeout: repairTimeout,
        env: config.variables,
        isCancelled: () => cancellation.isCompleted,
      ),
    )) {
      if (event is CommandOutput) {
        FlutterLogger.log(
          utf8.decode(event.bytes, allowMalformed: true),
          tag: 'iOS sandbox repair',
        );
      } else if (event is CommandExited) {
        exit = event;
      }
    }
    if (exit?.terminationConfirmed != true) {
      throw const _RepairTerminationUnconfirmed();
    }
    if (exit?.timedOut == true) {
      throw TimeoutException('rootfs repair timed out');
    }
    if (exit?.cancelled == true || exit?.interrupted == true) {
      throw const _RepairInterrupted();
    }
    return exit?.exitCode ?? -1;
  }

  Future<void> _setReady(String? version, [String? rootfsDir]) async {
    final dir = rootfsDir ?? (await _alpineRootfsDir()).path;
    return _set(
      EnvironmentState(
        phase: EnvironmentPhase.ready,
        distro: 'alpine',
        version: version,
        arch: 'arm64',
        installedAt: DateTime.now().toUtc(),
        rootfsDir: dir,
      ),
    );
  }

  Future<void> _set(EnvironmentState state) async {
    await env.setState(state);
    _onProgress?.call(state);
  }
}

class _RepairInterrupted implements Exception {
  const _RepairInterrupted();
}

class _RepairTerminationUnconfirmed implements Exception {
  const _RepairTerminationUnconfirmed();
}
