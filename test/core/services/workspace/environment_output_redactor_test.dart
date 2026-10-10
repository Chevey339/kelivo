import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:Kelivo/core/models/environment_variable.dart';
import 'package:Kelivo/core/services/workspace/environment_output_redactor.dart';
import 'package:Kelivo/core/services/workspace/workspace_tool_metadata.dart';
import 'package:Kelivo/utils/mcp_structured_image.dart';

void main() {
  test('empty proxy authentication does not mask ordinary punctuation', () {
    final result = EnvironmentOutputRedactor(
      EnvironmentExecutionConfig(
        variables: {'http_proxy': 'http://:@proxy.test:8080'},
      ),
    ).redact(const ClientToolResult('status: ok; path: /workspace'));
    expect(result.content, 'status: ok; path: /workspace');
  });

  test('masks proxy credential forms from the execution snapshot', () {
    const user = 'proxy@user';
    const password = 'pass:word/秘密';
    final userInfo =
        '${Uri.encodeComponent(user)}:${Uri.encodeComponent(password)}';
    final auth = base64Encode(utf8.encode('$user:$password'));
    final config = EnvironmentExecutionConfig(
      variables: {'HTTPS_PROXY': 'http://$userInfo@proxy.test:8080'},
    );
    final text =
        'Proxy-Authorization: Basic $auth\n$userInfo\n$user\n$password';
    final result = EnvironmentOutputRedactor(
      config,
    ).redact(ClientToolResult(text));
    for (final value in [auth, userInfo, user, password]) {
      expect(result.content, isNot(contains(value)));
    }
    final visible = EnvironmentOutputRedactor(
      EnvironmentExecutionConfig(
        variables: config.variables,
        privacyMode: false,
      ),
    ).redact(ClientToolResult(text));
    expect(visible.content, text);
  });

  test(
    'short proxy auth tokens are masked without masking every short word',
    () {
      final config = EnvironmentExecutionConfig(
        variables: {'http_proxy': 'http://a:b@proxy.test:8080'},
      );
      final result = EnvironmentOutputRedactor(
        config,
      ).redact(const ClientToolResult('Proxy-Authorization: Basic YTpi\nabc'));
      expect(
        result.content,
        startsWith('Proxy-Authorization: Basic [REDACTED]\nabc'),
      );
    },
  );

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
