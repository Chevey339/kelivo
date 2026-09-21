import 'package:flutter/foundation.dart';

/// Classification of a resolved path relative to the workspace zones.
enum WorkspaceZone { workspace, chat, skills, tmp, external, outside }

/// Which pipe a [CommandOutput] chunk came from.
enum OutputStreamKind { stdout, stderr }

/// A host directory exposed to the guest at [guest].
class Mount {
  const Mount({
    required this.host,
    required this.guest,
    this.readOnly = false,
    this.externalId,
  });

  final String? externalId;
  final String host;
  final String guest;
  final bool readOnly;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Mount &&
          other.externalId == externalId &&
          other.host == host &&
          other.guest == guest &&
          other.readOnly == readOnly;

  @override
  int get hashCode => Object.hash(host, guest, readOnly, externalId);

  @override
  String toString() => 'Mount(host: $host, guest: $guest)';
}

/// Process request. Every `shell` call is a fresh process; protocol servers
/// can keep stdin open and use Duration.zero for an unlimited lifetime.
class CommandRequest {
  const CommandRequest({
    required this.runId,
    required this.command,
    required this.cwd,
    this.timeout = const Duration(seconds: 60),
    this.env = const <String, String>{},
    this.mounts = const <Mount>[],
    this.isCancelled,
    this.keepStdinOpen = false,
  });

  final String runId;
  final String command;

  /// Keep a raw stdin pipe open for a persistent protocol process.
  final bool keepStdinOpen;

  /// Resolved path in the runtime's vocabulary (guest path when sandboxed,
  /// host path when native).
  final String cwd;
  final Duration timeout;
  final Map<String, String> env;
  final List<Mount> mounts;

  /// Rechecked after asynchronous platform startup, before issuing exec.
  final bool Function()? isCancelled;
}

sealed class CommandEvent {
  const CommandEvent();
}

class CommandStarted extends CommandEvent {
  const CommandStarted({this.pid});

  final int? pid;
}

class CommandOutput extends CommandEvent {
  CommandOutput(this.kind, this.bytes);

  final OutputStreamKind kind;
  final Uint8List bytes;
}

class CommandExited extends CommandEvent {
  const CommandExited({
    required this.exitCode,
    required this.timedOut,
    required this.cancelled,
    required this.interrupted,
    required this.duration,
  });

  final int exitCode;
  final bool timedOut;
  final bool cancelled;
  final bool interrupted;
  final Duration duration;
}

class RuntimeStatus {
  const RuntimeStatus({
    required this.ready,
    this.reason,
    required this.engine,
    required this.sandboxed,
  });

  final bool ready;
  final String? reason;

  /// One of `proot`, `ish`, `process`, `fake`.
  final String engine;
  final bool sandboxed;
}

abstract class PtySession {
  Stream<Uint8List> get output;
  Future<void> write(Uint8List data);
  Future<void> resize(int cols, int rows);
  Future<int> get exitCode;
  Future<void> close();
}

/// Process / PTY backend. Implementations live in later work; this type is
/// the contract they implement.
abstract class WorkspaceRuntime {
  Future<RuntimeStatus> status();
  Stream<CommandEvent> run(CommandRequest request);
  Future<void> cancel(String runId);

  bool get supportsPty => false;
  bool get supportsSystemTerminal => false;

  Future<PtySession> openPty({
    required List<Mount> mounts,
    required String cwd,
    required Map<String, String> env,
    required int cols,
    required int rows,
  }) {
    throw UnsupportedError('PTY is not supported by this runtime');
  }

  Future<void> openInSystemTerminal(String hostDir) {
    throw UnsupportedError('System terminal is not supported by this runtime');
  }

  Future<void> revealInFileManager(String hostPath) {
    throw UnsupportedError(
      'Reveal in file manager is not supported by this runtime',
    );
  }
}

/// Runtime with a writable raw stdin pipe (separate from terminal/PTY input).
abstract interface class WorkspaceStdioRuntime implements WorkspaceRuntime {
  Future<void> writeStdin(String runId, Uint8List data);
}

/// Holds the process-wide [WorkspaceRuntime] once a later agent registers it.
class WorkspaceRuntimeProvider extends ChangeNotifier {
  /// Platform bootstrap, awaited by unattended work before resolving tools.
  Future<void>? initialization;
  WorkspaceRuntime? runtime;
  RuntimeStatus? lastStatus;

  void register(WorkspaceRuntime runtime) {
    this.runtime = runtime;
    notifyListeners();
  }

  Future<RuntimeStatus> refresh() async {
    final current = runtime;
    if (current == null) {
      lastStatus = const RuntimeStatus(
        ready: false,
        reason: 'no runtime registered',
        engine: 'none',
        sandboxed: false,
      );
    } else {
      lastStatus = await current.status();
    }
    notifyListeners();
    return lastStatus!;
  }
}
