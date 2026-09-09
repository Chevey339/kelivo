import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:Kelivo/core/services/sandbox/environment_dependencies.dart';
import 'package:Kelivo/core/services/workspace/workspace_runtime.dart';

class DependencyTestRuntime extends WorkspaceRuntime {
  final requests = <CommandRequest>[];
  final installed = <EnvironmentDependency>{};
  Completer<void>? installGate;
  bool failInstall = false;
  bool incompleteProbe = false;
  bool cancelled = false;
  String? cancelledId;

  @override
  Future<RuntimeStatus> status() async =>
      const RuntimeStatus(ready: true, engine: 'fake', sandboxed: true);
  @override
  Stream<CommandEvent> run(CommandRequest request) async* {
    requests.add(request);
    if (request.command.contains('__kelivo_dep_')) {
      final body = incompleteProbe
          ? '__kelivo_dep_python=1\n'
          : [
              for (final dependency in EnvironmentDependency.values)
                '__kelivo_dep_${dependency.name}=${installed.contains(dependency) ? 1 : 0}\n',
            ].join();
      yield CommandOutput(
        OutputStreamKind.stdout,
        Uint8List.fromList(utf8.encode(body)),
      );
    } else {
      yield CommandOutput(
        OutputStreamKind.stdout,
        Uint8List.fromList(utf8.encode('Installing packages…\n')),
      );
      await installGate?.future;
      if (!failInstall && !cancelled) {
        for (final dependency in EnvironmentDependency.values) {
          if (request.command.contains(
            dependency.packages(alpine: request.command.contains('apk ')),
          )) {
            installed.add(dependency);
          }
        }
      }
    }
    yield CommandExited(
      exitCode: failInstall ? 1 : 0,
      timedOut: false,
      cancelled: cancelled,
      interrupted: false,
      duration: Duration.zero,
    );
  }

  @override
  Future<void> cancel(String runId) async {
    cancelledId = runId;
    cancelled = true;
    if (installGate?.isCompleted == false) installGate!.complete();
  }
}
