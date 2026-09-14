import 'dart:convert';

import '../../models/provider_oauth.dart';

/// Codex full Responses contract, matching OMP's request transformer and wire
/// headers. Kept here so custom overrides and every tool round pass through it.
void applyCodexRequest(
  Map<String, dynamic> body,
  Map<String, String> headers,
  String accessToken,
) {
  headers.remove('x-api-key');
  final auth = oauthTokenClaims(accessToken)['https://api.openai.com/auth'];
  if (auth is Map) {
    for (final name in [
      'chatgpt_data_residency',
      'chatgpt_compute_residency',
    ]) {
      final region = auth[name];
      if (region is! String || region.trim().isEmpty) continue;
      headers.putIfAbsent(
        'x-openai-internal-codex-residency',
        () => region.trim(),
      );
      break;
    }
  }
  if (body['model'] case final String model) {
    final tier = body['service_tier'];
    headers['x-codex-routing-hint'] =
        'model=$model${tier is String && tier.isNotEmpty ? ';tier=$tier' : ''}';
  }
  if (headers['session_id'] case final session?) {
    body.putIfAbsent('prompt_cache_key', () => session);
  }

  body['store'] = false;
  body['stream'] = true;
  body.putIfAbsent('instructions', () => '');
  for (final name in [
    'max_output_tokens',
    'max_completion_tokens',
    'temperature',
    'top_p',
    'top_k',
    'min_p',
    'presence_penalty',
    'repetition_penalty',
    'frequency_penalty',
    'stop',
  ]) {
    body.remove(name);
  }
  final include = body['include'];
  body['include'] = {
    if (include is List) ...include.whereType<String>(),
    'reasoning.encrypted_content',
  }.toList();

  final input = body['input'];
  if (input is List) {
    body['input'] = _repairToolPairs([
      for (final item in input)
        if (item is! Map || item['type'] != 'item_reference')
          item is Map && item['type'] != 'computer_call'
              ? (Map<String, dynamic>.from(item)..remove('id'))
              : item,
    ]);
  }

  // Title/summary requests can contain only instructions. Codex still needs
  // visible input, so OMP repeats the last developer instruction as user input.
  final items = body['input'];
  if (items != null && items is! List) return;
  final messages = items as List? ?? const [];
  if (messages.any((item) => item is! Map || item['role'] != 'developer')) {
    return;
  }
  String? instruction;
  for (final item in messages.reversed.whereType<Map>()) {
    final content = item['content'];
    if (content is! List) continue;
    for (final part in content.reversed.whereType<Map>()) {
      final text = part['text'];
      if (part['type'] == 'input_text' &&
          text is String &&
          text.trim().isNotEmpty) {
        instruction = text;
        break;
      }
    }
    if (instruction != null) break;
  }
  if (instruction == null && body['instructions'] is String) {
    final text = body['instructions'] as String;
    if (text.trim().isNotEmpty) instruction = text;
  }
  if (instruction != null) {
    body['input'] = [
      ...messages,
      {
        'type': 'message',
        'role': 'user',
        'content': [
          {'type': 'input_text', 'text': instruction},
        ],
      },
    ];
  }
}

const _toolTypes = {
  'function_call': 'function_call_output',
  'custom_tool_call': 'custom_tool_call_output',
  'computer_call': 'computer_call_output',
};

List<dynamic> _repairToolPairs(List<dynamic> input) {
  final calls = <String, String>{};
  final outputs = <String, String>{};
  for (final item in input.whereType<Map>()) {
    final id = item['call_id'];
    if (id is! String) continue;
    if (_toolTypes[item['type']] case final outputType?) calls[id] = outputType;
    if (_toolTypes.containsValue(item['type'])) {
      outputs[id] = item['type'] as String;
    }
  }
  final result = <dynamic>[];
  for (final item in input) {
    final id = item is Map ? item['call_id'] : null;
    if (item is! Map || id is! String) {
      result.add(item);
      continue;
    }
    final type = item['type'];
    if (_toolTypes.containsValue(type) && calls[id] != type) {
      var text = item['output'] is String
          ? item['output'] as String
          : jsonEncode(item['output']);
      if (text.length > 16000) {
        text = '${text.substring(0, 16000)}\n...[truncated]';
      }
      result.add({
        'type': 'message',
        'role': 'assistant',
        'content':
            '[Previous ${item['name'] ?? 'tool'} result; call_id=$id]: $text',
      });
    } else if (_toolTypes.containsKey(type) &&
        outputs[id] != _toolTypes[type]) {
      if (type == 'computer_call') {
        result.add({
          'type': 'message',
          'role': 'assistant',
          'content':
              '[Computer call interrupted before a screenshot was recorded; call_id=$id]',
        });
      } else {
        result.addAll([
          item,
          {
            'type': _toolTypes[type],
            'call_id': id,
            'output':
                '[No tool output recorded: the tool call was interrupted before it produced a result.]',
          },
        ]);
      }
    } else {
      result.add(item);
    }
  }
  return result;
}
