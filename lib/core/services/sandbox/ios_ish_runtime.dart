import 'package:uuid/uuid.dart';
import 'package:flutter/foundation.dart';

import 'package:Kelivo/core/services/sandbox/channel_command_run.dart';
import 'package:Kelivo/core/services/sandbox/channel_pty_session.dart';
import 'package:Kelivo/core/services/sandbox/workspace_channel.dart';
import 'package:Kelivo/core/services/workspace/workspace_runtime.dart';

/// iOS iSH [WorkspaceRuntime] over [WorkspaceChannel].
class IosIshRuntime implements WorkspaceStdioRuntime {
  IosIshRuntime({required this.channel});

  final WorkspaceChannel channel;

  @override
  bool get supportsPty => true;

  @override
  bool get supportsSystemTerminal => false;

  @override
  Future<RuntimeStatus> status() async {
    final probe = await channel.probe();
    if (!probe.supported) {
      return RuntimeStatus(
        ready: false,
        reason: probe.reason,
        engine: 'ish',
        sandboxed: true,
      );
    }
    if (probe.needsRestart == true) {
      return const RuntimeStatus(
        ready: false,
        reason: 'needs_restart',
        engine: 'ish',
        sandboxed: true,
      );
    }
    if (probe.installed != true) {
      return const RuntimeStatus(
        ready: false,
        reason: 'rootfs_not_installed',
        engine: 'ish',
        sandboxed: true,
      );
    }
    return const RuntimeStatus(ready: true, engine: 'ish', sandboxed: true);
  }

  @override
  Stream<CommandEvent> run(CommandRequest request) {
    return runChannelCommand(
      channel: channel,
      request: request,
      args: ExecArgs(
        runId: request.runId,
        cwd: request.cwd,
        command: request.command,
        timeoutMs: request.timeout.inMilliseconds,
        keepStdinOpen: request.keepStdinOpen,
        env: request.env,
        binds: [
          for (final mount in request.mounts)
            BindMount(
              host: mount.host,
              guest: mount.guest,
              readOnly: mount.readOnly,
            ),
        ],
      ),
      before: channel.beginBackgroundTask,
      after: channel.endBackgroundTask,
    );
  }

  @override
  Future<void> writeStdin(String runId, Uint8List data) =>
      channel.stdinWrite(runId, data);

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
      cwd: cwd,
      env: env,
      binds: [
        for (final mount in mounts)
          BindMount(
            host: mount.host,
            guest: mount.guest,
            readOnly: mount.readOnly,
          ),
      ],
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
}
