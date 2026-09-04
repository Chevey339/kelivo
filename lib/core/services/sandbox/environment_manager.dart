import 'dart:async';
import 'dart:io';

import 'package:Kelivo/core/models/environment_state.dart';
import 'package:Kelivo/core/providers/environment_provider.dart';
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
  }) : _alpineRootfsDir = alpineRootfsDir ?? iosAlpineRootfsDir;

  final WorkspaceChannel channel;
  final Future<Directory> Function() _alpineRootfsDir;

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
  }) async {
    _onProgress = onProgress;
    try {
      final probe = await channel.probe();
      final bundled = probe.bundledVersion;
      final installed = probe.installed == true;
      final sameVersion = probe.rootfsVersion == probe.bundledVersion;
      if (!force && installed && sameVersion) {
        if (probe.needsRestart == true) {
          await _set(
            EnvironmentState(
              phase: EnvironmentPhase.needsRestart,
              distro: 'alpine',
              version: bundled,
              arch: 'arm64',
            ),
          );
        } else {
          await _setReady(bundled, probe.rootfsDir);
        }
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
