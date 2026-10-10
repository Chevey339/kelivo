import 'package:Kelivo/core/services/workspace/workspace_runtime.dart';

/// Runs [script] in [runtime] and returns the process exit code.
Future<int> runGuestScript(
  WorkspaceRuntime runtime,
  String script, {
  String? runId,
  Duration timeout = const Duration(seconds: 60),
  Map<String, String> environment = const {},
  bool Function()? isCancelled,
}) async {
  CommandExited? exit;
  await for (final event in runtime.run(
    CommandRequest(
      runId: runId ?? 'guest-${DateTime.now().microsecondsSinceEpoch}',
      command: script,
      cwd: '/',
      timeout: timeout,
      env: environment,
      isCancelled: isCancelled,
    ),
  )) {
    if (event is CommandExited) {
      exit = event;
    }
  }
  return exit?.exitCode ?? -1;
}
