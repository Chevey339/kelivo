part of 'mcp_provider.dart';

/// A known conversation with a null workspace uses the unmounted guest.
typedef McpWorkspaceScope = ({String serverId, String? workspaceId});

class _WorkspaceConnection extends _ServerConnection {
  _WorkspaceConnection(this.scope);
  final McpWorkspaceScope scope;
  List<McpToolConfig>? tools;
  WorkspaceStdioTransport? transport;
  int users = 0;
  Timer? idleTimer;
  Future<void>? closing;
}

/// Owns only on-demand mobile processes. Map order is least recently used first.
class _WorkspaceMcpPool {
  _WorkspaceMcpPool(this.owner);
  final McpProvider owner;
  final entries = <McpWorkspaceScope, _WorkspaceConnection>{};
  Completer<void>? _changed;

  Future<T> use<T>(
    McpWorkspaceScope scope,
    Future<T> Function(_WorkspaceConnection) operation,
  ) async {
    final version = owner.workspaceConfigurationFor(scope);
    while (true) {
      final server = owner.getById(scope.serverId);
      if (owner._disposed ||
          server?.enabled != true ||
          server?.followConversationWorkspace != true ||
          !owner.supportsStdioWorkspaceBinding ||
          !owner.supportsStdio ||
          owner._connections[scope.serverId]?.manuallyDisconnected == true ||
          owner.workspaceConfigurationFor(scope) != version) {
        throw StateError('Workspace MCP server is unavailable.');
      }
      final existing = entries[scope];
      if (existing?.closing case final closing?) {
        await closing;
        continue;
      }
      if (existing == null &&
          entries.length >= McpProvider.workspaceProcessLimit) {
        final idle = entries.values
            .where(
              (entry) =>
                  entry.users == 0 &&
                  entry.closing == null &&
                  entry.refreshFuture == null,
            )
            .firstOrNull;
        if (idle == null) {
          await (_changed ??= Completer<void>()).future;
        } else {
          await close(idle);
        }
        continue;
      }

      final entry = entries.remove(scope) ?? _WorkspaceConnection(scope);
      entries[scope] = entry;
      entry.idleTimer?.cancel();
      entry.users++;
      try {
        return await operation(entry);
      } finally {
        entry.users--;
        if (entry.users == 0 &&
            entry.closing == null &&
            identical(entries[scope], entry)) {
          entry.idleTimer = Timer(
            owner.workspaceIdleTimeout,
            () => unawaited(close(entry)),
          );
        }
        signal();
      }
    }
  }

  void signal() {
    _changed?.complete();
    _changed = null;
  }

  Future<void> close(_WorkspaceConnection entry) {
    final closing = entry.closing;
    if (closing != null) return closing;
    final done = Completer<void>();
    entry.closing = done.future;
    entry.idleTimer?.cancel();
    final transport = entry.transport;
    transport?.close();
    final detached = owner._detachState(entry);
    done.complete(() async {
      try {
        await owner._finishDisconnect(detached, terminateSession: true);
        await transport?.onClose;
      } finally {
        entries.remove(entry.scope);
        signal();
        owner._notify();
      }
    }());
    return done.future;
  }

  Future<void> closeServer(String id) => Future.wait([
    for (final entry in entries.values.toList())
      if (entry.scope.serverId == id) close(entry),
  ]);

  Iterable<_WorkspaceConnection> forServer(String id) =>
      entries.values.where((e) => e.scope.serverId == id && e.closing == null);
}
