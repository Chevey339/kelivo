import 'dart:convert';

import 'package:Kelivo/core/services/auth/codex_request.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

void main() {
  String token(Map<String, dynamic> claims) =>
      'e30.${base64UrlEncode(utf8.encode(jsonEncode({'https://api.openai.com/auth': claims})))}.signature';

  test(
    'Codex routes with workspace residency and keeps explicit overrides',
    () {
      for (final claim in [
        'chatgpt_data_residency',
        'chatgpt_compute_residency',
      ]) {
        final headers = http.Request(
          'POST',
          Uri.parse('https://chatgpt.com'),
        ).headers..addAll({'session_id': 'conversation', 'X-API-Key': 'wrong'});
        final body = <String, dynamic>{
          'model': 'subscription-model',
          'service_tier': 'priority',
        };
        applyCodexRequest(body, headers, token({claim: ' eu '}));
        expect(headers['x-openai-internal-codex-residency'], 'eu');
        expect(
          headers['x-codex-routing-hint'],
          'model=subscription-model;tier=priority',
        );
        expect(headers.containsKey('x-api-key'), false);
        expect(body['prompt_cache_key'], 'conversation');
        headers['X-OpenAI-Internal-Codex-Residency'] = 'custom-region';
        applyCodexRequest(body, headers, token({claim: 'eu'}));
        expect(headers['x-openai-internal-codex-residency'], 'custom-region');
      }
    },
  );

  test(
    'interrupted tools and orphan outputs remain usable as Codex history',
    () {
      final matchedCall = <String, dynamic>{
        'type': 'function_call',
        'call_id': 'matched',
        'name': 'read_file',
        'arguments': '{}',
      };
      final matchedOutput = {
        'type': 'function_call_output',
        'call_id': 'matched',
        'output': 'actual result',
      };
      final body = <String, dynamic>{
        'input': [
          {'type': 'item_reference', 'id': 'server-only'},
          {
            'type': 'reasoning',
            'id': 'rs_old',
            'encrypted_content': 'opaque',
            'summary': [],
          },
          {...matchedCall, 'id': 'fc_old'},
          matchedOutput,
          {
            'type': 'function_call',
            'call_id': 'interrupted',
            'name': 'read_file',
            'arguments': '{}',
          },
          {
            'type': 'function_call_output',
            'call_id': 'orphan',
            'output': 'retained result',
          },
        ],
      };
      applyCodexRequest(body, {}, 'token');
      final items = (body['input'] as List).cast<Map>();
      expect(items.any((item) => item.containsKey('id')), false);
      expect(items.first['encrypted_content'], 'opaque');
      expect(items, contains(equals(matchedCall)));
      expect(items, contains(equals(matchedOutput)));
      expect(
        items
            .where(
              (item) =>
                  item['type'] == 'function_call_output' &&
                  item['call_id'] == 'interrupted',
            )
            .single['output'],
        contains('interrupted'),
      );
      expect(items.last['type'], 'message');
      expect(items.last['content'], contains('retained result'));
      expect(
        items.where((item) => item['type'] == 'function_call_output').length,
        2,
      );
    },
  );

  test(
    'instruction-only utility requests gain the visible input Codex requires',
    () {
      final body = <String, dynamic>{
        'instructions': 'Generate a title',
        'input': [],
      };
      applyCodexRequest(body, {}, 'token');
      expect(body['instructions'], 'Generate a title');
      expect(body['input'], [
        {
          'type': 'message',
          'role': 'user',
          'content': [
            {'type': 'input_text', 'text': 'Generate a title'},
          ],
        },
      ]);
      final withUser = <String, dynamic>{
        'instructions': 'System prompt',
        'input': [
          {'role': 'user', 'content': 'Real question'},
        ],
      };
      applyCodexRequest(withUser, {}, 'token');
      expect(withUser['input'], [
        {'role': 'user', 'content': 'Real question'},
      ]);
    },
  );
}
