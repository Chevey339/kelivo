import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:Kelivo/core/services/mcp/workspace_stdio_transport.dart';
import 'package:Kelivo/core/services/workspace/workspace_runtime.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mcp_client/mcp_client.dart' as mcp;

import '../../../support/fake_workspace_runtime.dart';

class StdioTestRuntime extends FakeWorkspaceRuntime
    implements WorkspaceStdioRuntime {
  final events = StreamController<CommandEvent>();
  final writes = <String>[];
  bool started = true;
  bool cancelled = false;
  Future<void> Function(String)? onWrite;

  @override
  Stream<CommandEvent> run(CommandRequest request) {
    requests.add(request);
    if (started) events.add(const CommandStarted());
    return events.stream;
  }

  @override
  Future<void> writeStdin(String runId, Uint8List data) async {
    final text = utf8.decode(data);
    writes.add(text);
    await onWrite?.call(text);
  }

  void output(String text, {bool stderr = false}) => events.add(
    CommandOutput(
      stderr ? OutputStreamKind.stderr : OutputStreamKind.stdout,
      Uint8List.fromList(utf8.encode(text)),
    ),
  );

  @override
  Future<void> cancel(String runId) async {
    cancelled = true;
  }
}

void main() {
  test(
    'preserves argv, cwd, env and decodes split UTF-8 without stderr',
    () async {
      final runtime = StdioTestRuntime();
      final transport = await WorkspaceStdioTransport.start(
        runtime: runtime,
        command: 'npx',
        arguments: ['-y', 'a b', "it's", r'$(touch injected)'],
        cwd: '/root/project',
        environment: {'TOKEN': 'secret'},
      );
      final request = runtime.requests.single;
      expect(
        request.command,
        r"exec 'npx' '-y' 'a b' 'it'\''s' '$(touch injected)'",
      );
      expect(request.cwd, '/root/project');
      expect(request.env, {'TOKEN': 'secret'});
      expect(request.keepStdinOpen, isTrue);
      expect(request.timeout, Duration.zero);
      final messages = <dynamic>[];
      final sub = transport.onMessage.listen(messages.add);
      runtime.output('ordinary log\n', stderr: true);
      final data = utf8.encode('{"text":"你好"}\n{"id":2}\n');
      for (final byte in data) {
        runtime.events.add(
          CommandOutput(OutputStreamKind.stdout, Uint8List.fromList([byte])),
        );
      }
      await Future<void>.delayed(Duration.zero);
      expect(messages, [
        {'text': '你好'},
        {'id': 2},
      ]);
      transport.close();
      await transport.onClose;
      await sub.cancel();
      expect(runtime.cancelled, isTrue);
    },
  );

  test('serializes writes and can cancel a queued send', () async {
    final runtime = StdioTestRuntime();
    final release = Completer<void>();
    runtime.onWrite = (_) => release.future;
    final transport = await WorkspaceStdioTransport.start(
      runtime: runtime,
      command: 'server',
    );
    final first = transport.send({'id': 1});
    final second = transport.send({'id': 2});
    second.cancel();
    await Future<void>.delayed(Duration.zero);
    expect(runtime.writes, ['{"id":1}\n']);
    release.complete();
    await Future.wait([first.done, second.done]);
    expect(runtime.writes.length, 1);
    transport.close();
    await transport.onClose;
  });

  test(
    'startup timeout cancels guest and marks request cancellation',
    () async {
      final runtime = StdioTestRuntime()..started = false;
      await expectLater(
        WorkspaceStdioTransport.start(
          runtime: runtime,
          command: 'server',
          startupTimeout: const Duration(milliseconds: 10),
        ),
        throwsA(isA<TimeoutException>()),
      );
      expect(runtime.cancelled, isTrue);
      expect(runtime.requests.single.isCancelled!(), isTrue);
    },
  );

  test('delivers final buffered response before process close', () async {
    final runtime = StdioTestRuntime();
    final transport = await WorkspaceStdioTransport.start(
      runtime: runtime,
      command: 'server',
    );
    final messages = transport.onMessage.toList();
    runtime.output('{"id":1,"result":{}}\n');
    runtime.events.add(
      const CommandExited(
        exitCode: 0,
        timedOut: false,
        cancelled: false,
        interrupted: false,
        duration: Duration.zero,
      ),
    );
    await runtime.events.close();
    await transport.onClose;
    expect(await messages, [
      {'id': 1, 'result': {}},
    ]);
  });

  test(
    'existing MCP client initializes, lists and calls tools over guest pipes',
    () async {
      final runtime = StdioTestRuntime();
      runtime.onWrite = (line) async {
        final request = jsonDecode(line) as Map<String, dynamic>;
        if (!request.containsKey('id')) return;
        final result = switch (request['method']) {
          'initialize' => {
            'protocolVersion': '2025-03-26',
            'capabilities': {'tools': {}},
            'serverInfo': {'name': 'guest', 'version': '1'},
          },
          'tools/list' => {
            'tools': [
              {
                'name': 'echo',
                'description': 'Echo',
                'inputSchema': {'type': 'object'},
              },
            ],
          },
          'tools/call' => {
            'content': [
              {'type': 'text', 'text': 'guest result'},
            ],
          },
          _ => <String, dynamic>{},
        };
        runtime.output(
          '${jsonEncode({'jsonrpc': '2.0', 'id': request['id'], 'result': result})}\n',
        );
      };
      final transport = await WorkspaceStdioTransport.start(
        runtime: runtime,
        command: 'server',
      );
      final client = mcp.McpClient.createClient(
        mcp.McpClient.simpleConfig(name: 'test', version: '1'),
      );
      await client.connect(transport);
      expect((await client.listTools()).single.name, 'echo');
      final result = await client.callTool('echo', {});
      expect(result.content.single.toJson()['text'], 'guest result');
      client.dispose();
      await transport.onClose;
    },
  );

  test(
    'raw shell process receives literal arguments and JSON through stdin',
    () async {
      final runtime = _ProcessRuntime();
      final transport = await WorkspaceStdioTransport.start(
        runtime: runtime,
        command: '/bin/sh',
        cwd: Directory.systemTemp.path,
        arguments: [
          '-c',
          r'''printf '{"argument":"%s"}\n' "$1"; cat''',
          'stdio-test',
          'space and apostrophe\'s',
        ],
      );
      final messages = <dynamic>[];
      final sub = transport.onMessage.listen(messages.add);
      await transport.send({'id': 42, 'text': '你好'}).done;
      for (var i = 0; i < 100 && messages.length < 2; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      expect(messages, [
        {'argument': "space and apostrophe's"},
        {'id': 42, 'text': '你好'},
      ]);
      transport.close();
      await transport.onClose;
      await sub.cancel();
    },
    skip: !(Platform.isMacOS || Platform.isLinux),
  );
}

class _ProcessRuntime extends FakeWorkspaceRuntime
    implements WorkspaceStdioRuntime {
  Process? process;
  @override
  Stream<CommandEvent> run(CommandRequest request) async* {
    final child = await Process.start('/bin/sh', [
      '-c',
      request.command,
    ], workingDirectory: request.cwd);
    process = child;
    yield const CommandStarted();
    yield* child.stdout.map(
      (bytes) =>
          CommandOutput(OutputStreamKind.stdout, Uint8List.fromList(bytes)),
    );
  }

  @override
  Future<void> writeStdin(String runId, Uint8List data) async {
    process!.stdin.add(data);
    await process!.stdin.flush();
  }

  @override
  Future<void> cancel(String runId) async {
    process?.kill();
  }
}
