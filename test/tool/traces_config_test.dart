import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/src/traces_config.dart';

void main() {
  test('parses the first-batch traces.yaml without storing keys', () {
    final config = loadTracesYaml(File('tool/traces.yaml'));
    expect(config.traces.map((t) => '${t.provider}/${t.name}').toList(), [
      'claude/thinking-tools-search',
      'google/thinking-image',
      'openai-chat/reasoning-parallel-tools',
      'openai-responses/server-tool-incomplete',
    ]);
    expect(
      config.traces.every(
        (t) => t.apiKeyEnv.isNotEmpty && t.bodyFile.isNotEmpty,
      ),
      isTrue,
    );
    final yaml = File('tool/traces.yaml').readAsStringSync();
    expect(yaml.toLowerCase(), isNot(contains('sk-')));
    expect(yaml, isNot(contains('AIza')));
  });

  test('parses optional auth header overrides for OpenRouter-style Claude', () {
    final config = parseTracesYaml('''
traces:
  - name: thinking-tools-search
    provider: claude
    baseUrl: https://openrouter.ai/api/v1
    endpoint: /messages
    apiKeyEnv: OPENROUTER_API_KEY
    authHeader: Authorization
    authScheme: Bearer
    model: anthropic/claude-sonnet-4
    bodyFile: tool/trace-bodies/claude-thinking-tools-search.json
''');
    final trace = config.traces.single;
    expect(trace.authHeader, 'Authorization');
    expect(trace.authScheme, 'Bearer');
    expect(
      traceRequestUri(trace).toString(),
      'https://openrouter.ai/api/v1/messages',
    );
  });

  test('joins OpenAI-style /v1 bases without dropping the version segment', () {
    expect(
      traceRequestUri(
        const TraceCase(
          name: 'n',
          provider: 'openai-chat',
          baseUrl: 'https://openrouter.ai/api/v1',
          endpoint: '/chat/completions',
          apiKeyEnv: 'OPENROUTER_API_KEY',
          model: 'x',
          bodyFile: 'x.json',
        ),
      ).toString(),
      'https://openrouter.ai/api/v1/chat/completions',
    );
    expect(
      traceRequestUri(
        const TraceCase(
          name: 'n',
          provider: 'openai-responses',
          baseUrl: 'https://api.openai.com/v1',
          endpoint: '/responses',
          apiKeyEnv: 'OPENAI_API_KEY',
          model: 'x',
          bodyFile: 'x.json',
        ),
      ).toString(),
      'https://api.openai.com/v1/responses',
    );
    expect(
      traceRequestUri(
        const TraceCase(
          name: 'n',
          provider: 'google',
          baseUrl: 'https://generativelanguage.googleapis.com/v1beta',
          apiKeyEnv: 'GEMINI_API_KEY',
          model: 'gemini-2.5-flash-image',
          bodyFile: 'x.json',
        ),
      ).toString(),
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-image:streamGenerateContent?alt=sse',
    );
  });
}
