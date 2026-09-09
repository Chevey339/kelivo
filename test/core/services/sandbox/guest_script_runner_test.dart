import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/services/sandbox/guest_script_runner.dart';
import 'package:Kelivo/core/services/workspace/workspace_runtime.dart';

import '../../../support/fake_workspace_runtime.dart';

void main() {
  test('runGuestScript drains output and returns the exit code', () async {
    final runtime = _AnyRunRuntime([
      CommandOutput(OutputStreamKind.stdout, Uint8List.fromList(<int>[1])),
      CommandOutput(OutputStreamKind.stderr, Uint8List.fromList(<int>[2])),
      const CommandExited(
        exitCode: 9,
        timedOut: false,
        cancelled: false,
        interrupted: false,
        duration: Duration(milliseconds: 3),
      ),
    ]);

    final code = await runGuestScript(
      runtime,
      'echo hi',
      timeout: const Duration(seconds: 5),
    );
    expect(code, 9);
    expect(runtime.requests, hasLength(1));
    expect(runtime.requests.single.command, 'echo hi');
    expect(runtime.requests.single.cwd, '/');
    expect(runtime.requests.single.timeout, const Duration(seconds: 5));
  });

  test('runGuestScript uses FakeWorkspaceRuntime default success', () async {
    final runtime = FakeWorkspaceRuntime();
    expect(await runGuestScript(runtime, 'true'), 0);
    expect(runtime.requests.single.command, 'true');
  });
}

class _AnyRunRuntime extends FakeWorkspaceRuntime {
  _AnyRunRuntime(this.scripted);

  final List<CommandEvent> scripted;

  @override
  Stream<CommandEvent> run(CommandRequest request) {
    requests.add(request);
    return Stream<CommandEvent>.fromIterable(scripted);
  }
}
