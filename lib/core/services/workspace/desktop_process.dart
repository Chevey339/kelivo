import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Starts a native command with an owned process group on Unix. The caller
/// releases the startup gate by writing a newline to stdin after registration.
Future<({Process process, Stream<List<int>> stdout, int? processGroup})>
startDesktopProcess(
  String executable,
  List<String> arguments, {
  String? workingDirectory,
  Map<String, String>? environment,
  bool includeParentEnvironment = true,
}) async {
  final unix = Platform.isMacOS || Platform.isLinux;
  final process = await Process.start(
    unix ? '/bin/bash' : executable,
    unix
        ? [
            '--noprofile',
            '--norc',
            '-p',
            '-c',
            _unixLauncher,
            'kelivo-shell',
            executable,
            ...arguments,
          ]
        : arguments,
    workingDirectory: workingDirectory,
    environment: environment,
    includeParentEnvironment: includeParentEnvironment,
  );
  if (!unix) {
    return (process: process, stdout: process.stdout, processGroup: null);
  }

  final output = StreamController<List<int>>();
  final group = Completer<int>();
  final header = <int>[];
  final subscription = process.stdout.listen(
    (chunk) {
      if (group.isCompleted) {
        output.add(chunk);
        return;
      }
      final newline = chunk.indexOf(10);
      header.addAll(newline < 0 ? chunk : chunk.sublist(0, newline));
      if (header.length <= 20 && newline < 0) return;
      final id = int.tryParse(ascii.decode(header, allowInvalid: true));
      if (newline < 0 || id == null || id <= 1) {
        group.completeError(StateError('Shell process group did not start'));
        return;
      }
      group.complete(id);
      if (newline + 1 < chunk.length) {
        output.add(chunk.sublist(newline + 1));
      }
    },
    onError: (Object error, StackTrace stack) {
      if (!group.isCompleted) {
        group.completeError(error, stack);
      } else {
        output.addError(error, stack);
      }
    },
    onDone: () {
      if (!group.isCompleted) {
        group.completeError(StateError('Shell process group did not start'));
      }
      unawaited(output.close());
    },
  );
  output.onCancel = subscription.cancel;
  output.onPause = subscription.pause;
  output.onResume = subscription.resume;
  try {
    return (
      process: process,
      stdout: output.stream,
      processGroup: await group.future,
    );
  } catch (_) {
    // Closing stdin also releases a child still waiting at the startup gate.
    await process.stdin.close();
    process.kill();
    await subscription.cancel();
    unawaited(output.close());
    await process.stderr.drain<void>();
    await process.exitCode;
    rethrow;
  }
}

// Bash job control creates a separate process group without detaching the
// launcher, so dart:io still reports the selected shell's actual exit code.
// -p keeps BASH_ENV and exported shell options out of this control protocol;
// the selected user shell is launched with its original arguments and env.
const _unixLauncher = r'''
set -m
(
set +m
IFS= read -r _ || exit 125
exec "$@"
) <&0 &
printf '%s\n' "$!"
wait "$!" 2>/dev/null
''';

Future<void> stopDesktopProcessGroup(int group) async {
  if (!Process.killPid(-group, ProcessSignal.sigterm)) return;
  final deadline = DateTime.now().add(const Duration(seconds: 2));
  while (await _desktopProcessGroupAlive(group)) {
    if (!DateTime.now().isBefore(deadline)) {
      Process.killPid(-group, ProcessSignal.sigkill);
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }
}

Future<bool> _desktopProcessGroupAlive(int group) async {
  // -g selects different things on BSD and GNU ps. Read the PGID column on
  // both platforms, excluding zombies that are already unable to run.
  final result = await Process.run('/bin/ps', ['-axo', 'pgid=,stat=']);
  if (result.exitCode != 0) return true;
  for (final line in result.stdout.toString().split('\n')) {
    final fields = line.trim().split(RegExp(r'\s+'));
    if (fields.length >= 2 &&
        fields[0] == '$group' &&
        !fields[1].startsWith('Z')) {
      return true;
    }
  }
  return false;
}
