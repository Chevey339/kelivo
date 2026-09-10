import 'package:uuid/uuid.dart';
import '../workspace/workspace_runtime.dart';
import 'stdio_arguments.dart';

/// Resolve the executable in the guest, not in the host app's PATH. This keeps
/// a missing runtime from surfacing as an unrelated stdin/handshake error.
Future<void> requireWorkspaceStdioCommand({
  required WorkspaceRuntime runtime,
  required String command,
  required String cwd,
  required Map<String, String> environment,
  required Duration timeout,
  required bool Function() isCancelled,
}) async {
  if (command.trim().isEmpty) throw StateError('STDIO command is empty');
  final id = 'mcp-probe-${const Uuid().v4()}';
  CommandExited? exit;
  try {
    await for (final event
        in runtime
            .run(
              CommandRequest(
                runId: id,
                command:
                    'command -v ${StdioArguments.format([command])} >/dev/null 2>&1',
                cwd: cwd,
                env: environment,
                timeout: timeout,
                isCancelled: isCancelled,
              ),
            )
            .timeout(timeout)) {
      if (event is CommandExited) exit = event;
    }
  } catch (_) {
    await runtime.cancel(id);
    rethrow;
  }
  if (isCancelled()) throw StateError('STDIO startup cancelled');
  if (exit?.exitCode == 0) return;
  if (exit == null ||
      exit.timedOut ||
      exit.cancelled ||
      exit.interrupted ||
      ![1, 127].contains(exit.exitCode)) {
    throw StateError(
      'Could not check the STDIO command in the workspace environment',
    );
  }
  final hint = switch (command) {
    'node' ||
    'npm' ||
    'npx' => 'Install Node.js and npm in Environment settings.',
    'uv' || 'uvx' => 'Install Python and uv in the workspace environment.',
    'python' || 'python3' => 'Install Python in Environment settings.',
    _ => 'Install it in the workspace environment or check the command path.',
  };
  throw StateError(
    'Command "$command" is unavailable in the workspace environment. $hint',
  );
}
