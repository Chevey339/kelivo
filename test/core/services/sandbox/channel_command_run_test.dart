import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:Kelivo/core/services/sandbox/channel_command_run.dart';
import 'package:Kelivo/core/services/sandbox/workspace_channel.dart';
import 'package:Kelivo/core/services/workspace/workspace_runtime.dart';
import 'sandbox_channel_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SandboxChannelHarness harness;
  setUp(() {
    harness = SandboxChannelHarness()..install();
  });
  tearDown(() => harness.dispose());
  const args = ExecArgs(runId: 'cancel-me', command: 'true', cwd: '/');

  test(
    'cancel during background setup prevents exec and releases background task',
    () async {
      final setup = Completer<void>();
      var cancelled = false;
      var released = false;
      final result = runChannelCommand(
        channel: harness.channel,
        request: CommandRequest(
          runId: args.runId,
          command: args.command,
          cwd: args.cwd,
          isCancelled: () => cancelled,
        ),
        args: args,
        before: () => setup.future,
        after: () async {
          released = true;
        },
      );
      final expectation = expectLater(result, emitsError(isA<StateError>()));
      cancelled = true;
      setup.complete();
      await expectation;
      expect(harness.methods, isNot(contains('exec')));
      expect(released, isTrue);
    },
  );

  test('cancel is repeated after delayed native registration', () async {
    final entered = Completer<void>();
    final registered = Completer<void>();
    var cancelled = false;
    harness.handler = (call) {
      if (call.method == 'exec') {
        entered.complete();
        return registered.future;
      }
      if (call.method == 'cancel') {
        harness.emit({
          'type': 'exit',
          'runId': args.runId,
          'exitCode': -1,
          'cancelled': true,
        });
        return true;
      }
      return null;
    };
    final result = runChannelCommand(
      channel: harness.channel,
      request: CommandRequest(
        runId: args.runId,
        command: args.command,
        cwd: '/',
        isCancelled: () => cancelled,
      ),
      args: args,
    ).toList();
    await entered.future;
    cancelled = true;
    registered.complete();
    final events = await result.timeout(const Duration(seconds: 3));
    expect(harness.methods, contains('cancel'));
    expect(events.whereType<CommandExited>().single.cancelled, isTrue);
  });

  test(
    'cancelling subscription during setup releases it without starting exec',
    () async {
      final setup = Completer<void>();
      var released = false;
      final subscription = runChannelCommand(
        channel: harness.channel,
        request: const CommandRequest(
          runId: 'cancel-me',
          command: 'true',
          cwd: '/',
        ),
        args: args,
        before: () => setup.future,
        after: () async {
          released = true;
        },
      ).listen((_) {});
      final cancellation = subscription.cancel();
      setup.complete();
      await cancellation.timeout(const Duration(seconds: 3));
      expect(harness.methods, isNot(contains('exec')));
      expect(released, isTrue);
    },
  );
}
