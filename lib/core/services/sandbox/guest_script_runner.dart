import 'package:Kelivo/core/services/workspace/workspace_runtime.dart';

/// Runs [script] in [runtime] and returns the process exit code.
Future<int> runGuestScript(
  WorkspaceRuntime runtime,
  String script, {
  String? runId,
  Duration timeout = const Duration(seconds: 60),
}) async {
  CommandExited? exit;
  await for (final event in runtime.run(
    CommandRequest(
      runId: runId ?? 'guest-${DateTime.now().microsecondsSinceEpoch}',
      command: script,
      cwd: '/',
      timeout: timeout,
    ),
  )) {
    if (event is CommandExited) {
      exit = event;
    }
  }
  return exit?.exitCode ?? -1;
}
