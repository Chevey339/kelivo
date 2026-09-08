import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/models/workspace.dart';
import 'package:Kelivo/core/models/workspace_binding.dart';
import 'package:Kelivo/core/services/api/chat_api_service.dart';
import 'package:Kelivo/core/services/workspace/desktop_process_runtime.dart';
import 'package:Kelivo/core/services/workspace/workspace_paths.dart';
import 'package:Kelivo/core/services/workspace/workspace_runtime.dart';
import 'package:Kelivo/core/services/workspace/workspace_tools_service.dart';

class ObservedRuntime extends DesktopProcessRuntime {
  final runIds = <String>[];
  final started = Completer<void>();
  final exited = Completer<void>();
  @override
  Stream<CommandEvent> run(CommandRequest request) async* {
    runIds.add(request.runId);
    await for (final event in super.run(request)) {
      if (event is CommandStarted && !started.isCompleted) started.complete();
      yield event;
    }
    if (!exited.isCompleted) exited.complete();
  }
}

void main() {
  test(
    'cancelling generation terminates its active shell side effects',
    () async {
      final temp = await Directory.systemTemp.createTemp(
        'kelivo-cancel-review-',
      );
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final runtime = ObservedRuntime();
      addTearDown(() async {
        for (final id in runtime.runIds) {
          await runtime.cancel(id);
        }
        await server.close(force: true);
        await temp.delete(recursive: true);
      });
      var requests = 0;
      server.listen((request) async {
        await request.drain<void>();
        requests++;
        request.response.headers.contentType = ContentType(
          'text',
          'event-stream',
        );
        final delta = requests == 1
            ? {
                'role': 'assistant',
                'tool_calls': [
                  {
                    'index': 0,
                    'id': 'review-tool',
                    'type': 'function',
                    'function': {
                      'name': 'shell',
                      'arguments': jsonEncode({
                        'command': 'sleep 2; printf wrote > after-stop.txt',
                      }),
                    },
                  },
                ],
              }
            : {'content': 'done'};
        request.response.write(
          'data: ${jsonEncode({
            'choices': [
              {'index': 0, 'delta': delta, 'finish_reason': requests == 1 ? 'tool_calls' : 'stop'},
            ],
          })}\n\n',
        );
        request.response.write('data: [DONE]\n\n');
        await request.response.close();
      });
      final paths = WorkspacePaths.native(
        workspaceHostRoot: temp.path,
        sessionHostDir: '${temp.path}/session',
        skillsHostDir: '${temp.path}/skills',
      );
      await Directory(paths.sessionHostDir).create();
      final now = DateTime.utc(2026);
      final ctx = WorkspaceToolContext(
        workspace: Workspace(
          id: 'review',
          name: 'Review',
          kind: WorkspaceKind.managed,
          createdAt: now,
          updatedAt: now,
        ),
        binding: const WorkspaceBinding(workspaceId: 'review', allowAll: true),
        paths: paths,
        sessionDir: Directory(paths.sessionHostDir),
        outputsDir: Directory('${paths.sessionHostDir}/outputs'),
        conversationId: 'review-conv',
        runtimeStatus: await runtime.status(),
        runtimeRegistered: true,
      );
      final service = WorkspaceToolsService(
        runtimeProvider: WorkspaceRuntimeProvider()..register(runtime),
      );
      final subscription = ChatApiService.sendMessageStream(
        config: ProviderConfig(
          id: 'LocalReview',
          enabled: true,
          name: 'Review',
          apiKey: 'local-test',
          baseUrl: 'http://127.0.0.1:${server.port}/v1',
          providerType: ProviderKind.openai,
        ),
        modelId: 'gpt-4o',
        requestId: 'review-conv',
        messages: const [
          {'role': 'user', 'content': 'Run a local command'},
        ],
        tools: service.buildToolDefinitions(ctx),
        onToolCall: (name, args, {toolCallId}) =>
            service.handle(ctx, name, args, toolCallId: toolCallId!),
      ).listen((_) {}, onError: (Object _) {});
      await runtime.started.future.timeout(const Duration(seconds: 10));
      final other = service.handle(
        ctx,
        'shell',
        {'command': 'sleep 1; printf preserved > other-conversation.txt'},
        toolCallId: 'review-tool',
        conversationId: 'other-conversation',
      );
      ChatApiService.cancelRequest('review-conv');
      final cancellation = subscription.cancel();
      await runtime.exited.future.timeout(const Duration(seconds: 10));
      await cancellation;
      expect(await File('${temp.path}/after-stop.txt').exists(), isFalse);
      await other;
      expect(
        await File('${temp.path}/other-conversation.txt').readAsString(),
        'preserved',
      );
    },
    skip: !(Platform.isMacOS || Platform.isLinux),
  );
}
