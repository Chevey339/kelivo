import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'package:Kelivo/core/models/environment_state.dart';
import 'package:Kelivo/core/providers/environment_provider.dart';
import 'package:Kelivo/core/services/sandbox/guest_script_runner.dart';
import 'package:Kelivo/core/services/sandbox/ios_ish_runtime.dart';
import 'package:Kelivo/core/services/sandbox/rootfs_disk_usage.dart';
import 'package:Kelivo/core/services/sandbox/workspace_channel.dart';

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
    Future<int> Function(String script)? runInGuest,
  }) : _alpineRootfsDir = alpineRootfsDir ?? iosAlpineRootfsDir,
       _runInGuest =
           runInGuest ??
           ((script) => runGuestScript(
             IosIshRuntime(channel: channel),
             script,
             timeout: const Duration(minutes: 10),
           ));

  final WorkspaceChannel channel;
  final Future<Directory> Function() _alpineRootfsDir;
  final Future<int> Function(String script) _runInGuest;
  Future<void>? _installFuture;

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
  Future<void> cancel() async {}

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
      final probe = await channel.probe();
      final bundled = probe.bundledVersion;
      final installed = probe.installed == true;
      final sameVersion = probe.rootfsVersion == probe.bundledVersion;
      final requiresRepair = force || env.state.errorMessage == 'patch_failed';
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
    await _set(
      env.state.copyWith(
        phase: EnvironmentPhase.patching,
        distro: 'alpine',
        version: probe.rootfsVersion,
        arch: 'arm64',
        rootfsDir: dir,
        availableVersion: version,
        clearErrorMessage: true,
      ),
    );
    try {
      // Boot applies the bundled script through the guest VFS, including to
      // existing environments. apk keeps the user's world and installed tools.
      final exitCode = await _runInGuest(
        '/bin/sh /usr/local/bin/kelivo-repair-rootfs',
      );
      if (exitCode != 0 || version == null || version.isEmpty) {
        throw StateError('rootfs repair failed');
      }
      // This app-owned marker is outside fakefs data/. Publish it only after
      // the guest transaction and release-file checks have succeeded.
      final pending = File(p.join(dir, '.version.pending'));
      await pending.writeAsString('$version\n', flush: true);
      await pending.rename(p.join(dir, '.version'));
      await _setReady(version, dir);
    } catch (_) {
      await _set(
        env.state.copyWith(
          phase: EnvironmentPhase.error,
          errorMessage: 'patch_failed',
          clearProgress: true,
        ),
      );
    }
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
