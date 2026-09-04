import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import 'package:Kelivo/core/models/environment_state.dart';
import 'package:Kelivo/core/providers/environment_provider.dart';
import 'package:Kelivo/core/services/sandbox/channel_command_run.dart';
import 'package:Kelivo/core/services/sandbox/channel_pty_session.dart';
import 'package:Kelivo/core/services/sandbox/environment_installer.dart';
import 'package:Kelivo/core/services/sandbox/rootfs_source.dart';
import 'package:Kelivo/core/services/sandbox/workspace_channel.dart';
import 'package:Kelivo/core/services/workspace/workspace_runtime.dart';

/// Android proot [WorkspaceRuntime] over [WorkspaceChannel].
class AndroidProotRuntime implements WorkspaceRuntime {
  AndroidProotRuntime({
    required this.channel,
    required this.env,
    required this.rootfsDir,
    required this.tmpDir,
  });

  final WorkspaceChannel channel;
  final EnvironmentProvider env;
  final Directory rootfsDir;
  final Directory tmpDir;

  @override
  bool get supportsPty => true;

  @override
  bool get supportsSystemTerminal => false;

  @override
  Future<RuntimeStatus> status() async {
    await _adoptOnDiskInstall();
    if (env.state.phase != EnvironmentPhase.ready ||
        !await rootfsDir.exists()) {
      return const RuntimeStatus(
        ready: false,
        reason: 'environment_not_installed',
        engine: 'proot',
        sandboxed: true,
      );
    }
    final probe = await channel.probe();
    if (!probe.supported) {
      final native = probe.reason;
      return RuntimeStatus(
        ready: false,
        reason: native == null || native.isEmpty
            ? 'proot_missing'
            : 'proot_missing: $native',
        engine: 'proot',
        sandboxed: true,
      );
    }
    return const RuntimeStatus(ready: true, engine: 'proot', sandboxed: true);
  }

  @override
  Stream<CommandEvent> run(CommandRequest request) {
    return runChannelCommand(
      channel: channel,
      request: request,
      args: _execArgs(request),
    );
  }

  @override
  Future<void> cancel(String runId) async {
    await channel.cancel(runId);
  }

  @override
  Future<PtySession> openPty({
    required List<Mount> mounts,
    required String cwd,
    required Map<String, String> env,
    required int cols,
    required int rows,
  }) async {
    // Unique per open, never a counter: the native session map lives on the
    // platform side and outlives the Dart isolate, so a hot restart would hand
    // out ids that are still registered there — iSH rejects the open, proot
    // silently kills the older session.
    final sessionId = 'pty-${const Uuid().v4()}';
    final session = ChannelPtySession(channel: channel, sessionId: sessionId);
    await channel.ptyOpen(
      sessionId: sessionId,
      rootfsDir: rootfsDir.path,
      tmpDir: tmpDir.path,
      cwd: cwd,
      env: env,
      binds: _binds(mounts),
      cols: cols,
      rows: rows,
    );
    return session;
  }

  @override
  Future<void> openInSystemTerminal(String hostDir) {
    throw UnsupportedError('System terminal is not supported by this runtime');
  }

  @override
  Future<void> revealInFileManager(String hostPath) {
    throw UnsupportedError(
      'Reveal in file manager is not supported by this runtime',
    );
  }

  ExecArgs _execArgs(CommandRequest request) {
    return ExecArgs(
      runId: request.runId,
      rootfsDir: rootfsDir.path,
      tmpDir: tmpDir.path,
      cwd: request.cwd,
      command: request.command,
      timeoutMs: request.timeout.inMilliseconds,
      env: request.env,
      binds: _binds(request.mounts),
    );
  }

  List<BindMount> _binds(List<Mount> mounts) {
    return [
      for (final mount in mounts)
        BindMount(host: mount.host, guest: mount.guest),
    ];
  }

  /// Prefs can be empty after a reinstall while the Ubuntu rootfs is still on
  /// disk. Adopt that install so Settings and `shell` see `ready`.
  Future<void> _adoptOnDiskInstall() async {
    await env.loaded;
    if (env.state.phase == EnvironmentPhase.ready) return;
    final versionFile = File(p.join(rootfsDir.path, kKelivoVersionFile));
    if (!await versionFile.exists()) return;
    final parts = (await versionFile.readAsString()).trim().split(
      RegExp(r'\s+'),
    );
    await env.setState(
      EnvironmentState(
        phase: EnvironmentPhase.ready,
        distro: parts.isNotEmpty ? parts[0] : kUbuntuDistro,
        version: parts.length > 1 ? parts[1] : kUbuntuBaseVersion,
        arch: parts.length > 2 ? parts[2] : 'arm64',
        installedAt: DateTime.now().toUtc(),
        rootfsDir: rootfsDir.path,
        lastMirrorBase: env.state.lastMirrorBase,
      ),
    );
  }
}
