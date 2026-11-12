import 'dart:convert';

import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/api/provider_request_headers.dart';
import 'package:Kelivo/core/models/provider_oauth.dart';
import 'package:Kelivo/core/services/auth/codex_request.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

void main() {
  String token(Map<String, dynamic> claims) =>
      'e30.${base64UrlEncode(utf8.encode(jsonEncode({'https://api.openai.com/auth': claims})))}.signature';

  test('replay strips only backend metadata and preserves opaque items', () {
    final input = <Map<String, dynamic>>[
      for (final type in [
        'message',
        'reasoning',
        'compaction',
        'computer_call',
      ])
        {
          'type': type,
          'id': '$type-id',
          if (type == 'computer_call') 'call_id': 'computer-1',
          if (type == 'message') ...{
            'role': 'assistant',
            'content': [
              {'type': 'output_text', 'text': 'hello'},
            ],
          },
          if (type == 'reasoning' || type == 'compaction')
            'encrypted_content': 'opaque-$type',
          'metadata': {
            'content_token_count': 12,
            'internal_chat_message_metadata_passthrough': 'user data',
          },
          'internal_chat_message_metadata_passthrough': {
            'content_token_count': 7,
          },
        },
      {
        'type': 'computer_call_output',
        'call_id': 'computer-1',
        'output': {
          'type': 'computer_screenshot',
          'image_url': 'data:image/png;base64,YQ==',
        },
      },
    ];
    final original = jsonEncode(input);
    final body = <String, dynamic>{'input': input};
    applyCodexRequest(body, {}, 'token');
    final sent = (body['input'] as List).cast<Map>();
    expect(sent, hasLength(input.length));
    for (var i = 0; i < 4; i++) {
      final expected = Map<String, dynamic>.from(input[i])
        ..remove('internal_chat_message_metadata_passthrough');
      if (i < 2) expected.remove('id');
      expect(sent[i], expected);
    }
    expect(sent.last, input.last);
    expect(jsonEncode(input), original);
    final once = jsonEncode(body);
    applyCodexRequest(body, {}, 'token');
    expect(jsonEncode(body), once);
  });

  test('Codex session headers and automatic cache key stay stable', () {
    final config = ProviderConfig(
      id: 'codex',
      enabled: true,
      name: 'Codex',
      apiKey: '',
      baseUrl: 'https://chatgpt.com/backend-api/codex',
      oauthProvider: OAuthProvider.chatgpt,
    );
    final headers = providerSessionHeaders(config, conversationId: ' chat-1 ')!;
    expect(headers, {
      'session-id': 'chat-1',
      'thread-id': 'chat-1',
      'x-client-request-id': 'chat-1',
    });
    for (var round = 0; round < 3; round++) {
      final body = <String, dynamic>{'model': 'gpt-5.4'};
      applyCodexRequest(body, headers, 'token');
      expect(body['prompt_cache_key'], 'chat-1');
    }
    final generated = providerSessionHeaders(config)!;
    expect(generated['session-id'], isNotEmpty);
    expect(generated['thread-id'], generated['session-id']);
    expect(
      providerSessionHeaders(config)!['session-id'],
      isNot(generated['session-id']),
    );
  });

  test('Codex honors canonical overrides and drops obsolete wire headers', () {
    final headers =
        http.Request('POST', Uri.parse('https://chatgpt.com')).headers..addAll({
          'Session-Id': 'custom-session',
          'Thread-Id': 'custom-thread',
          'SESSION_ID': 'obsolete',
          'conversation_id': 'obsolete',
          'thread_id': 'obsolete',
        });
    final body = <String, dynamic>{};
    applyCodexRequest(body, headers, 'token');
    expect(body['prompt_cache_key'], 'custom-session');
    expect(headers['thread-id'], 'custom-thread');
    for (final name in ['session_id', 'conversation_id', 'thread_id']) {
      expect(headers, isNot(contains(name)));
    }
    body['prompt_cache_key'] = 'explicit-cache';
    applyCodexRequest(body, headers, 'token');
    expect(body['prompt_cache_key'], 'explicit-cache');
  });

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
        ).headers..addAll({'session-id': 'conversation', 'X-API-Key': 'wrong'});
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
    'Codex omits unconstrained residency without falling through to compute',
    () {
      for (final claims in [
        {'chatgpt_data_residency': 'no_constraint'},
        {'chatgpt_compute_residency': ' NO_CONSTRAINT '},
        {
          'chatgpt_data_residency': 'no_constraint',
          'chatgpt_compute_residency': 'us',
        },
      ]) {
        final headers = <String, String>{};
        applyCodexRequest({}, headers, token(claims));
        expect(headers, isNot(contains('x-openai-internal-codex-residency')));
        headers['x-openai-internal-codex-residency'] = 'eu';
        applyCodexRequest({}, headers, token(claims));
        expect(headers['x-openai-internal-codex-residency'], 'eu');
      }
      final headers = <String, String>{};
      applyCodexRequest(
        {},
        headers,
        token({
          'chatgpt_data_residency': ' ',
          'chatgpt_compute_residency': 'us',
        }),
      );
      expect(headers['x-openai-internal-codex-residency'], 'us');
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
