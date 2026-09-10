// Run on a disposable simulator, or pass --no-uninstall to flutter test.
// Flutter integration tests otherwise remove the app and its data on exit.
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mcp_client/mcp_client.dart' as mcp;
import 'package:Kelivo/core/services/sandbox/ios_ish_runtime.dart';
import 'package:Kelivo/core/services/sandbox/workspace_channel.dart';
import 'package:Kelivo/core/services/workspace/workspace_runtime.dart';
import 'package:Kelivo/core/services/mcp/workspace_stdio_transport.dart';
import 'package:Kelivo/core/services/mcp/workspace_stdio_command.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Node cache filename entropy differs across processes and honors explicit seeds',
    (tester) async {
      final runtime = IosIshRuntime(channel: WorkspaceChannel());
      final output = StringBuffer();
      await for (final event in runtime.run(
        const CommandRequest(
          runId: 'node-entropy-regression',
          cwd: '/root',
          command:
              r'''node -p 'Math.random()'; node -p 'Math.random()'; node --random-seed=123 -p 'Math.random()'; node --random-seed=123 -p 'Math.random()' ''',
          timeout: Duration(seconds: 30),
        ),
      )) {
        if (event is CommandOutput && event.kind == OutputStreamKind.stdout) {
          output.write(utf8.decode(event.bytes));
        }
        if (event is CommandExited) expect(event.exitCode, 0);
      }
      final values = const LineSplitter().convert(output.toString());
      expect(values, hasLength(4));
      expect(values[0], isNot(values[1]));
      expect(values[2], values[3]);
    },
    skip:
        !Platform.isIOS || !const bool.fromEnvironment('MCP_STDIO_NODE_SMOKE'),
  );
  testWidgets(
    'bundled Node overlay supports fetch without native WebAssembly',
    (tester) async {
      final runtime = IosIshRuntime(channel: WorkspaceChannel());
      final output = StringBuffer();
      await for (final event in runtime.run(
        const CommandRequest(
          runId: 'node-fetch-overlay-regression',
          cwd: '/root',
          command: r'''node -e '
const http = require("http");
const server = http.createServer((req, res) => {
  const body = "kelivo overlay ok";
  res.writeHead(200, {"Content-Type": "text/plain", "Content-Length": Buffer.byteLength(body)});
  res.end(body);
});
server.listen(0, "127.0.0.1", async () => {
  try {
    const response = await fetch("http://127.0.0.1:" + server.address().port);
    console.log(response.status + ":" + await response.text());
  } catch (error) { console.error(error); process.exitCode = 1; }
  finally { server.closeAllConnections(); server.close(); }
});'
''',
          timeout: Duration(seconds: 60),
        ),
      )) {
        if (event is CommandOutput && event.kind == OutputStreamKind.stdout) {
          output.write(utf8.decode(event.bytes));
        }
        if (event is CommandExited) expect(event.exitCode, 0);
      }
      expect(output.toString().trim(), '200:kelivo overlay ok');
    },
    skip:
        !Platform.isIOS || !const bool.fromEnvironment('MCP_STDIO_NODE_SMOKE'),
  );
  // Opt in on a simulator with uv and the server dependencies installed:
  // --no-uninstall --dart-define=MCP_STDIO_UVX_SMOKE=true
  testWidgets(
    'uvx preserves early initialize and survives an idle connection',
    (tester) async {
      final runtime = IosIshRuntime(channel: WorkspaceChannel());
      expect((await runtime.status()).ready, isTrue);
      for (var attempt = 0; attempt < 2; attempt++) {
        final transport = await WorkspaceStdioTransport.start(
          runtime: runtime,
          command: 'uvx',
          arguments: ['mcp-server-time'],
        );
        final client = mcp.McpClient.createClient(
          mcp.McpClient.simpleConfig(
            name: 'stdio-regression',
            version: '1',
            requestTimeout: const Duration(seconds: 60),
          ),
        );
        try {
          // No delay: the launcher must preserve input buffered before exec.
          await client.connect(transport);
          expect(
            (await client.listTools()).map((tool) => tool.name),
            containsAll(['get_current_time', 'convert_time']),
          );
          final result = await client.callTool('get_current_time', {
            'timezone': 'UTC',
          });
          final value = jsonDecode(
            result.content.single.toJson()['text'] as String,
          );
          expect(value['timezone'], 'UTC');
          if (attempt == 0) {
            // Cross both iSH idle-exit heuristics (poll: 60s, futex: 180s).
            await Future<void>.delayed(const Duration(seconds: 200));
            final afterIdle = await client.callTool('get_current_time', {
              'timezone': 'UTC',
            });
            expect(afterIdle.content.single.toJson()['text'], contains('UTC'));
          }
        } finally {
          client.dispose();
          await transport.onClose;
        }
      }
    },
    skip: !Platform.isIOS || !const bool.fromEnvironment('MCP_STDIO_UVX_SMOKE'),
    timeout: const Timeout(Duration(minutes: 6)),
  );
  testWidgets(
    'iOS guest checks dependencies and exchanges MCP over raw pipes',
    (tester) async {
      if (!Platform.isIOS) return;
      final runtime = IosIshRuntime(channel: WorkspaceChannel());
      expect((await runtime.status()).ready, isTrue);
      await for (final event in runtime.run(
        const CommandRequest(
          runId: 'mcp-dependency-diagnostic',
          cwd: '/root',
          command:
              r'for c in node npm npx python3 uv uvx; do if command -v "$c" >/dev/null 2>&1; then echo "$c: installed"; else echo "$c: missing"; fi; done',
        ),
      )) {
        if (event is CommandOutput) {
          debugPrint(utf8.decode(event.bytes, allowMalformed: true));
        }
      }
      await expectLater(
        requireWorkspaceStdioCommand(
          runtime: runtime,
          command: 'kelivo-nonexistent-mcp-command',
          cwd: '/root',
          environment: const {},
          timeout: const Duration(seconds: 10),
          isCancelled: () => false,
        ),
        throwsA(isA<StateError>()),
      );
      final transport = await WorkspaceStdioTransport.start(
        runtime: runtime,
        command: '/bin/sh',
        startupTimeout: const Duration(seconds: 15),
        arguments: [
          '-c',
          r'''
while IFS= read -r line; do
  id=$(printf '%s' "$line" | sed -n 's/.*"id":\([0-9][0-9]*\).*/\1/p')
  [ -n "$id" ] || continue
  case "$line" in
    *'"method":"initialize"'*) result='{"protocolVersion":"2025-03-26","capabilities":{"tools":{}},"serverInfo":{"name":"guest-test","version":"1"}}';;
    *'"method":"tools/list"'*) result='{"tools":[{"name":"echo","description":"Echo","inputSchema":{"type":"object"}}]}';;
    *'"method":"tools/call"'*) result='{"content":[{"type":"text","text":"guest pipe works"}]}';;
    *) result='{}';;
  esac
  printf '{"jsonrpc":"2.0","id":%s,"result":%s}\n' "$id" "$result"
done
''',
        ],
      );
      final client = mcp.McpClient.createClient(
        mcp.McpClient.simpleConfig(
          name: 'stdio-test',
          version: '1',
          requestTimeout: const Duration(seconds: 15),
        ),
      );
      try {
        await client.connect(transport);
        expect((await client.listTools()).single.name, 'echo');
        expect(
          (await client.callTool('echo', {})).content.single.toJson()['text'],
          'guest pipe works',
        );
      } finally {
        client.dispose();
        await transport.onClose;
      }
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
