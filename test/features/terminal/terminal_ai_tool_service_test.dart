import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:Kelivo/features/terminal/services/terminal_ai_tool_service.dart';
import 'package:Kelivo/features/terminal/services/terminal_native_bridge.dart';

class _FakeTerminalBridge extends TerminalNativeBridge {
  final commands = <String>[];
  final results = <TerminalCommandResult>[];

  @override
  Future<TerminalCommandResult> runCommand({
    required String command,
    Duration timeout = const Duration(seconds: 20),
    int maxOutputBytes = 65536,
  }) async {
    commands.add(command);
    if (results.isNotEmpty) {
      return results.removeAt(0);
    }
    return const TerminalCommandResult(
      output: 'kelivo\n',
      exitCode: 0,
      timedOut: false,
      truncated: false,
    );
  }
}

void main() {
  group('TerminalAiToolService', () {
    test('defines the four terminal tools', () {
      final names = TerminalAiToolService.toolDefinitions
          .map((tool) => tool['function'] as Map<String, dynamic>)
          .map((function) => function['name'])
          .toList();

      expect(names, [
        'terminal_read',
        'terminal_exec',
        'terminal_edit',
        'terminal_write',
      ]);
    });

    test('executes terminal_exec and returns structured JSON', () async {
      final bridge = _FakeTerminalBridge();
      final service = TerminalAiToolService(bridge: bridge);

      final raw = await service.handleToolCall('terminal_exec', {
        'command': 'printf kelivo',
        'timeout': 3,
      });
      final json = jsonDecode(raw) as Map<String, dynamic>;

      expect(bridge.commands.single, contains('printf kelivo'));
      expect(json['type'], 'terminal_exec_result');
      expect(json['exitCode'], 0);
      expect(json['output'], 'kelivo\n');
    });

    test('rejects terminal_edit when oldText is not unique', () async {
      final bridge = _FakeTerminalBridge()
        ..results.add(
          const TerminalCommandResult(
            output: 'alpha\nalpha\n',
            exitCode: 0,
            timedOut: false,
            truncated: false,
          ),
        );
      final service = TerminalAiToolService(bridge: bridge);

      final raw = await service.handleToolCall('terminal_edit', {
        'path': '/tmp/demo.txt',
        'edits': [
          {'oldText': 'alpha', 'newText': 'beta'},
        ],
      });
      final json = jsonDecode(raw) as Map<String, dynamic>;

      expect(json['type'], 'tool_error');
      expect(json['error'], 'old_text_not_unique');
      expect(bridge.commands, hasLength(1));
    });
  });
}
