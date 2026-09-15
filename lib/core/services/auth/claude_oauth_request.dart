import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:hashlib/hashlib.dart' show XXHash64;

import '../../models/provider_oauth.dart';
import '../../providers/settings_provider.dart';

// OMP 6f2c14b3, providers/claude-code-fingerprint.ts and anthropic.ts.
const claudeCodeVersion = '2.1.257';
const claudeCodeSdkVersion = '0.112.1';
const claudeCodeSystemInstruction =
    "You are Claude Code, Anthropic's official CLI for Claude.";
const claudeOAuthBetas = [
  'claude-code-20250219',
  'oauth-2025-04-20',
  'interleaved-thinking-2025-05-14',
  'thinking-token-count-2026-05-13',
  'context-management-2025-06-27',
  'prompt-caching-scope-2026-01-05',
  'mid-conversation-system-2026-04-07',
  'effort-2025-11-24',
  'fallback-credit-2026-06-01',
];

Map<String, String> claudeOAuthHeaders(ProviderOAuthCredentials credentials) =>
    {
      'Authorization': 'Bearer ${credentials.accessToken}',
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      'anthropic-version': '2023-06-01',
      'anthropic-beta': claudeOAuthBetas.join(','),
      'anthropic-dangerous-direct-browser-access': 'true',
      'User-Agent': 'claude-cli/$claudeCodeVersion (external, cli)',
      'x-app': 'cli',
      'X-Stainless-Arch': Abi.current().toString().contains('arm64')
          ? 'arm64'
          : 'x64',
      'X-Stainless-Lang': 'js',
      'X-Stainless-OS': Platform.isMacOS || Platform.isIOS
          ? 'MacOS'
          : Platform.isWindows
          ? 'Windows'
          : 'Linux',
      'X-Stainless-Package-Version': claudeCodeSdkVersion,
      'X-Stainless-Retry-Count': '0',
      'X-Stainless-Runtime': 'node',
      'X-Stainless-Runtime-Version': 'v26.3.0',
      'X-Stainless-Timeout': '600',
      // Let the native HTTP transport use an encoding it can actually decode.
      'Accept-Encoding': 'gzip',
    };

String claudeOAuthDeviceId(String installId, String? accountId) => sha256
    .convert(
      utf8.encode(
        accountId?.isNotEmpty == true
            ? 'omp-claude-device-id-v2\u0000$installId\u0000$accountId'
            : 'omp-claude-device-id-v1:$installId',
      ),
    )
    .toString();

String encodeClaudeOAuthToolName(String name) =>
    const {
      'web_search',
      'code_execution',
      'text_editor',
      'computer',
    }.contains(name.toLowerCase())
    ? name
    : '_$name';

String decodeClaudeOAuthToolName(String name) =>
    name.startsWith('_') ? name.substring(1) : name;

String? _header(Map<String, String> headers, String name) {
  for (final entry in headers.entries) {
    if (entry.key.toLowerCase() == name.toLowerCase()) return entry.value;
  }
  return null;
}

void setClaudeOAuthHeader(
  Map<String, String> headers,
  String name,
  String value,
) {
  headers.removeWhere((key, _) => key.toLowerCase() == name.toLowerCase());
  headers[name] = value;
}

// OMP fingerprints the first text block of the first user turn.
String _firstUserText(List messages) {
  for (final message in messages.whereType<Map>()) {
    if (message['role'] != 'user') continue;
    final content = message['content'];
    if (content is String) return content;
    if (content is List) {
      for (final block in content.whereType<Map>()) {
        if (block['type'] == 'text') return block['text'] as String? ?? '';
      }
    }
    return '';
  }
  return '';
}

String _billingHeader(String text) {
  final seed = [
    4,
    7,
    20,
  ].map((index) => index < text.length ? text[index] : '0').join();
  final fingerprint = sha256
      .convert(utf8.encode('59cf53e54c78$seed$claudeCodeVersion'))
      .toString()
      .substring(0, 3);
  return 'x-anthropic-billing-header: cc_version=$claudeCodeVersion.$fingerprint; cc_entrypoint=cli; cch=00000;';
}

/// Final OAuth transport shaping runs on a newly decoded payload each send, so
/// retries and tool continuations cannot add a second prefix or mutate history.
String encodeClaudeOAuthRequest(
  Map<String, dynamic> body,
  ProviderConfig config,
  Map<String, String> headers,
  String fallbackSessionId,
) {
  final credentials = config.oauthCredentials!;
  final messages = body['messages'] is List
      ? body['messages'] as List
      : <dynamic>[];
  final cache = config.claudePromptCachingEnabled == true
      ? ProviderConfig.claudePromptCacheControl(config.claudePromptCachingTtl)
      : null;
  final originalSystem = body['system'];
  final system = <Map<String, dynamic>>[
    {'type': 'text', 'text': _billingHeader(_firstUserText(messages))},
    {
      'type': 'text',
      'text': claudeCodeSystemInstruction,
      if (cache != null) 'cache_control': {...cache},
    },
    if (originalSystem is String && originalSystem.trim().isNotEmpty)
      {'type': 'text', 'text': originalSystem},
    if (originalSystem is List)
      ...originalSystem.whereType<Map>().map(
        (block) => block.cast<String, dynamic>(),
      ),
  ];
  body['system'] = system;
  body.remove('cache_control');
  body.putIfAbsent('tools', () => <dynamic>[]);
  final tools = (body['tools'] is List ? body['tools'] as List : const [])
      .whereType<Map>()
      .toList();
  for (final tool in tools) {
    if (tool['input_schema'] is Map && tool['name'] is String) {
      tool['name'] = encodeClaudeOAuthToolName(tool['name'] as String);
    }
  }
  for (final message in messages.whereType<Map>()) {
    final content = message['content'];
    if (content is! List) continue;
    for (final block in content.whereType<Map>()) {
      if (block['type'] == 'tool_use' && block['name'] is String) {
        block['name'] = encodeClaudeOAuthToolName(block['name'] as String);
      }
    }
  }
  final choice = body['tool_choice'];
  if (choice is Map && choice['type'] == 'tool' && choice['name'] is String) {
    choice['name'] = encodeClaudeOAuthToolName(choice['name'] as String);
  }
  final metadata = body['metadata'] is Map
      ? Map<String, dynamic>.from(body['metadata'] as Map)
      : <String, dynamic>{};
  var sessionId =
      _header(headers, 'X-Claude-Code-Session-Id') ?? fallbackSessionId;
  final userId = metadata['user_id'];
  var validUserId = false;
  if (userId is String) {
    try {
      final decoded = jsonDecode(userId);
      if (decoded is Map &&
          decoded['session_id'] is String &&
          (decoded['session_id'] as String).isNotEmpty) {
        validUserId = true;
        sessionId = decoded['session_id'] as String;
      }
    } catch (_) {
      /* Also accept the legacy attribution shape OMP accepts. */
    }
    final match = RegExp(
      r'^user_[0-9a-fA-F]{64}_account_[0-9a-f-]{36}_session_([0-9a-f-]{36})$',
    ).firstMatch(userId);
    if (match != null) {
      validUserId = true;
      sessionId = match.group(1)!;
    }
  }
  if (!validUserId) {
    metadata['user_id'] = jsonEncode({
      'device_id':
          credentials.deviceId ??
          claudeOAuthDeviceId(config.id, credentials.accountId),
      'session_id': sessionId,
      if (credentials.accountId != null) 'account_uuid': credentials.accountId,
    });
  }
  body['metadata'] = metadata;
  setClaudeOAuthHeader(headers, 'X-Claude-Code-Session-Id', sessionId);
  final betas = <String>{
    ...claudeOAuthBetas,
    ...?_header(headers, 'anthropic-beta')
        ?.split(',')
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty),
    if (cache?['ttl'] == '1h') 'extended-cache-ttl-2025-04-11',
  }..remove('context-1m-2025-08-07');
  setClaudeOAuthHeader(headers, 'anthropic-beta', betas.join(','));
  final maxTokens = body['max_tokens'];
  body['max_tokens'] = maxTokens is num
      ? maxTokens.toInt().clamp(1, 64000)
      : 64000;
  final thinking = body['thinking'];
  if (thinking is Map &&
      thinking['type'] == 'enabled' &&
      thinking['budget_tokens'] is num &&
      (thinking['budget_tokens'] as num) > 0) {
    // OMP reserves 4,000 output tokens beyond an explicit thinking budget.
    final budget = (thinking['budget_tokens'] as num).toInt();
    final raised = (budget + 4000).clamp(body['max_tokens'] as int, 64000);
    body['max_tokens'] = raised;
    if (budget + 4000 > raised) thinking['budget_tokens'] = raised - 4000;
  }
  if (cache != null) _cacheClaudeRequest(system, tools, messages, cache);
  // Match the Claude Code/OMP serialization order before computing cch.
  const order = [
    'model',
    'messages',
    'system',
    'tools',
    'metadata',
    'max_tokens',
    'thinking',
    'context_management',
    'output_config',
    'stream',
  ];
  final ordered = <String, dynamic>{
    for (final key in order)
      if (body.containsKey(key)) key: body[key],
    for (final entry in body.entries)
      if (!order.contains(entry.key)) entry.key: entry.value,
  };
  final encoded = jsonEncode(ordered);
  final digest = const XXHash64(
    0x4d659218e32a3268,
  ).convert(utf8.encode(encoded)).hex();
  final cch = digest.substring(digest.length - 5);
  final marker = encoded.indexOf(
    '"system":[{"type":"text","text":"x-anthropic-billing-header:',
  );
  final index = encoded.indexOf('cch=00000', marker);
  return encoded.replaceRange(index + 4, index + 9, cch);
}

void _cacheClaudeRequest(
  List<Map<String, dynamic>> system,
  List<Map> tools,
  List messages,
  Map<String, dynamic> cache,
) {
  if (tools.isNotEmpty && !tools.any((tool) => tool['cache_control'] != null)) {
    for (final tool in tools.reversed) {
      if (tool['defer_loading'] != true) {
        tool['cache_control'] = {...cache};
        break;
      }
    }
  }
  var count =
      system.where((block) => block['cache_control'] != null).length +
      tools.where((tool) => tool['cache_control'] != null).length;
  for (final message in messages.whereType<Map>()) {
    final content = message['content'];
    if (content is List) {
      count += content
          .whereType<Map>()
          .where((block) => block['cache_control'] != null)
          .length;
    }
  }
  var budget = 4 - count;
  if (budget <= 0) return;
  final userIndices = <int>[];
  for (var index = 0; index < messages.length; index++) {
    final message = messages[index];
    if (message is! Map ||
        message['role'] != 'user' ||
        message['clear_at'] == 'next_user_message') {
      continue;
    }
    final content = message['content'];
    if (content is String ||
        content is List &&
            content.whereType<Map>().any(
              (block) => block['type'] != 'tool_result',
            )) {
      userIndices.add(index);
    }
  }
  final trailing = [
    for (var index = messages.length - 1; index >= 0; index--)
      if (messages[index] is Map &&
          messages[index]['clear_at'] != 'next_user_message')
        index,
  ].take(2).toList();
  final candidates = <int>{
    if (trailing.isNotEmpty) trailing.first,
    for (var ordinal = userIndices.length - 1; ordinal >= 0; ordinal--)
      if ((ordinal + 1) % 15 == 0) userIndices[ordinal],
    ...trailing,
  };
  for (final index in candidates) {
    if (budget <= 0) break;
    final message = messages[index];
    if (message is! Map) continue;
    final content = message['content'];
    if (content is String && content.isNotEmpty) {
      message['content'] = [
        {
          'type': 'text',
          'text': content,
          'cache_control': {...cache},
        },
      ];
      budget--;
    } else if (content is List) {
      for (final block in content.whereType<Map>().toList().reversed) {
        if (const {
              'thinking',
              'redacted_thinking',
              'fallback',
              'tool_addition',
              'tool_removal',
            }.contains(block['type']) ||
            block['type'] == 'text' &&
                (block['text'] as String? ?? '').isEmpty) {
          continue;
        }
        if (block['cache_control'] == null) {
          block['cache_control'] = {...cache};
          budget--;
        }
        break;
      }
    }
  }
}
