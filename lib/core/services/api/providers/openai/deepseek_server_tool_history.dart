import 'dart:convert';

import '../../../../providers/settings_provider.dart';
import '../../../../utils/provider_url.dart';
import '../../stream/stream_chunk.dart';

const deepSeekServerToolArtifactKind = 'deepseek_server_tool_history';
const deepSeekServerToolHistoryKey = '_deepseek_server_tool_history';
const deepSeekServerToolCallsField = 'server_tool_calls';

Map<String, String>? _scope(ProviderConfig config, String upstreamModelId) {
  if (config.useResponseApi == true) return null;
  final endpoint = Uri.tryParse(resolveRequestUrl(config));
  if (endpoint == null ||
      endpoint.scheme != 'https' ||
      endpoint.host != 'api.deepseek.com' ||
      !endpoint.path.endsWith('/chat/completions')) {
    return null;
  }
  return {
    'provider': config.id,
    'endpoint': endpoint.toString(),
    'model': upstreamModelId,
  };
}

bool isOfficialDeepSeekChat(ProviderConfig config) =>
    _scope(config, '') != null;

class DeepSeekServerToolRecorder {
  DeepSeekServerToolRecorder(ProviderConfig config, String upstreamModelId)
    : _wireScope = _scope(config, upstreamModelId);

  final Map<String, String>? _wireScope;
  final Map<String, List<dynamic>> _rounds = {};

  ProviderArtifact? record(Object? calls, {String clientCallId = ''}) {
    final scope = _wireScope;
    if (scope == null || calls is! List || calls.isEmpty) return null;
    _rounds[clientCallId] = calls;
    return ProviderArtifact(
      kind: deepSeekServerToolArtifactKind,
      payload: jsonEncode({...scope, 'rounds': _rounds}),
    );
  }
}

List<dynamic>? replayDeepSeekServerToolCalls(
  Object? payload,
  ProviderConfig config,
  String upstreamModelId,
  Object? clientCalls,
) {
  final scope = _scope(config, upstreamModelId);
  if (scope == null || payload is! String) return null;
  try {
    final data = jsonDecode(payload);
    if (data is! Map || scope.entries.any((e) => data[e.key] != e.value)) {
      return null;
    }
    final rounds = data['rounds'];
    if (rounds is! Map) return null;
    if (clientCalls is List && clientCalls.isNotEmpty) {
      for (final call in clientCalls.whereType<Map>()) {
        final blocks = rounds[call['id']];
        if (blocks is List && blocks.isNotEmpty) return blocks;
      }
      return null;
    }
    final blocks = rounds[''];
    return blocks is List && blocks.isNotEmpty ? blocks : null;
  } catch (_) {
    return null;
  }
}
