import 'package:flutter_test/flutter_test.dart';
import 'package:Kelivo/core/services/mcp/workspace_stdio_command.dart';
import 'package:Kelivo/core/services/workspace/workspace_runtime.dart';
import '../../../support/fake_workspace_runtime.dart';

void main() {
  for (final command in ['npx', 'uvx']) {
    test(
      'missing $command reports installation guidance before opening stdin',
      () async {
        final runtime = FakeWorkspaceRuntime()
          ..enqueueNext([
            const CommandExited(
              exitCode: 1,
              timedOut: false,
              cancelled: false,
              interrupted: false,
              duration: Duration.zero,
            ),
          ]);
        await expectLater(
          requireWorkspaceStdioCommand(
            runtime: runtime,
            command: command,
            cwd: '/root',
            environment: const {},
            timeout: const Duration(seconds: 1),
            isCancelled: () => false,
          ),
          throwsA(
            isA<StateError>().having(
              (error) => error.message,
              'message',
              allOf(contains(command), contains('Install')),
            ),
          ),
        );
        expect(runtime.requests.single.keepStdinOpen, isFalse);
      },
    );
  }
  test('probe uses the same guest cwd and overridden environment', () async {
    final runtime = FakeWorkspaceRuntime();
    await requireWorkspaceStdioCommand(
      runtime: runtime,
      command: '/my tools/node',
      cwd: '/root',
      environment: const {'PATH': '/custom/bin'},
      timeout: const Duration(seconds: 1),
      isCancelled: () => false,
    );
    expect(runtime.requests.single.env, {'PATH': '/custom/bin'});
    expect(
      runtime.requests.single.command,
      "command -v '/my tools/node' >/dev/null 2>&1",
    );
  });
}
