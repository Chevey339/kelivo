import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:Kelivo/core/models/environment_variable.dart';
import 'package:Kelivo/core/services/workspace/environment_output_redactor.dart';
import 'package:Kelivo/core/services/workspace/workspace_tool_metadata.dart';
import 'package:Kelivo/utils/mcp_structured_image.dart';

void main() {
  test(
    'redacts nested escaped JSON without damaging the payload or local preview',
    () {
      const secret = '密钥"abc\\xyz\nsecond-line';
      final redactor = EnvironmentOutputRedactor(
        EnvironmentExecutionConfig(variables: {'TOKEN': secret}),
      );
      final input = ClientToolResult(
        jsonEncode({
          'stdout': secret,
          'nested': [
            {'error': secret},
          ],
          'exit_code': 1,
        }),
        metadata: const WorkspaceToolMetadata(
          tool: 'shell',
          status: 'ok',
          stdoutPreview: secret,
        ).toJson(),
      );
      final output = redactor.redact(input);
      final payload = jsonDecode(output.content) as Map;
      expect(payload['stdout'], '[REDACTED]');
      expect(payload['nested'], [
        {'error': '[REDACTED]'},
      ]);
      expect(payload['exit_code'], 1);
      expect(payload['privacy_notice'], contains('redacted'));
      expect(
        WorkspaceToolMetadata.fromJson(output.metadata!).stdoutPreview,
        secret,
      );
    },
  );

  test(
    'matches overlapping literal values once, including regex characters',
    () {
      final redactor = EnvironmentOutputRedactor(
        EnvironmentExecutionConfig(
          variables: {'A': 'abcde', 'B': 'abcdefghi', 'C': r'a.b[c]$'},
        ),
      );
      final result = redactor.redact(
        const ClientToolResult(r'abcdefghi abcde a.b[c]$'),
      );
      expect(result.content, startsWith('[REDACTED] [REDACTED] [REDACTED]'));
      expect(result.content, isNot(contains('fghi')));
    },
  );

  test(
    'masks numbered multiline read_file output while keeping a raw local preview',
    () {
      final redactor = EnvironmentOutputRedactor(
        EnvironmentExecutionConfig(
          variables: {'KEY': 'first-secret\nsecond-secret'},
        ),
      );
      const raw = '1: first-secret\n2: second-secret';
      final result = redactor.redact(
        ClientToolResult(
          raw,
          metadata: const WorkspaceToolMetadata(
            tool: 'read_file',
            status: 'ok',
          ).toJson(),
        ),
      );
      expect(result.content, startsWith('1: [REDACTED]\n2: [REDACTED]'));
      expect(
        WorkspaceToolMetadata.fromJson(result.metadata!).stdoutPreview,
        raw,
      );
    },
  );

  test('privacy off and short values leave results untouched', () {
    const input = ClientToolResult('secret true 1234');
    for (final config in [
      EnvironmentExecutionConfig(
        variables: {'TOKEN': 'secret'},
        privacyMode: false,
      ),
      EnvironmentExecutionConfig(
        variables: {'BOOL': 'true', 'PORT': '1234', 'EMPTY': ''},
      ),
    ]) {
      expect(EnvironmentOutputRedactor(config).redact(input), same(input));
    }
  });
}
