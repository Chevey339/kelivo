import '../../../network/provider_http_exception.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

import '../../../../models/native_compaction.dart';
import '../../../../models/provider_oauth.dart';
import '../../../../providers/settings_provider.dart';
import '../../chat_api_helpers.dart';
import '../../native_compaction_context.dart';
import '../../request_history_context.dart';
import '../../request_image_context.dart';
import '../../request_token_estimate.dart';
import '../../stream/sse_framing.dart';
import '../../stream/sse_event.dart';
import 'openai_request_shaping.dart';
import 'responses_decoder.dart';

/// Native support is an explicit user choice, never inferred from a model name.
Future<NativeCompactionPayload> requestNativeCompaction(
  http.Client client,
  ProviderConfig config,
  String modelId,
  Map<String, dynamic> prepared, {
  Map<String, String>? extraHeaders,
  String? conversationId,
}) async {
  final codex = config.oauthProvider == OAuthProvider.chatgpt;
  final clean = RequestHistoryContext.stripSources(prepared);
  final body = codex
      ? <String, dynamic>{
          ...clean,
          'input': [
            ...clean['input'] as List,
            {'type': 'compaction_trigger'},
          ],
          'stream': true,
          'store': false,
        }
      : <String, dynamic>{
          'model': clean['model'],
          'input': clean['input'],
          if (clean['instructions'] != null)
            'instructions': clean['instructions'],
        };
  if (conversationId?.isNotEmpty == true && config.promptCacheKeyEnabled) {
    body['prompt_cache_key'] = conversationId;
  }
  final request =
      http.Request('POST', nativeResponsesEndpoint(config, compact: !codex))
        ..headers.addAll(
          customHeaders(
            config,
            modelId,
            baseHeaders: {
              'Authorization': 'Bearer ${apiKeyForRequest(config, modelId)}',
              'Content-Type': 'application/json',
              'Accept': codex ? 'text/event-stream' : 'application/json',
              if (codex) 'x-codex-beta-features': 'remote_compaction_v2',
            },
            assistantHeaders: extraHeaders,
          ),
        )
        ..body = jsonEncode(body);
  RequestImageContext.current?.validateBodyBytes(request.bodyBytes.length);
  final response = await client.send(request);
  if (response.statusCode < 200 || response.statusCode >= 300) {
    throw ProviderHttpException(
      response,
      await response.stream.bytesToString(),
    );
  }
  if (!codex) {
    final data = Map<String, dynamic>.from(
      jsonDecode(await response.stream.bytesToString()) as Map,
    );
    throwIfInBandStreamError(jsonEncode(data));
    return NativeCompactionPayload(
      protocol: NativeCompactionProtocol.compact,
      scope: nativeCompactionScope(config),
      modelId: modelId,
      // The entire returned window is canonical, including unknown item types.
      output: (data['output'] as List? ?? const [])
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList(),
      usage: openaiUsageFromObj(data),
    );
  }
  final decoder = ResponsesStreamDecoder();
  await for (final event in parseSseEvents(response.stream)) {
    if (event.data.trim().isEmpty || event.data.trim() == '[DONE]') continue;
    final value = Map<String, dynamic>.from(jsonDecode(event.data) as Map);
    final rawType = value['type'] ?? event.event;
    final type = rawType == 'response.done' ? 'response.completed' : rawType;
    throwIfInBandStreamError(
      jsonEncode({...value, if (type != null) 'type': type}),
    );
    if (type == 'response.failed' ||
        type == 'response.incomplete' ||
        type == 'error' ||
        (type == 'response.completed' &&
            value['response'] is Map &&
            value['response']['status'] != null &&
            value['response']['status'] != 'completed')) {
      throw StateError('native_compaction_incomplete');
    }
    decoder.accept(
      SseEvent(data: jsonEncode({...value, if (type != null) 'type': type})),
    );
    if (decoder.completed) break;
  }
  final items = decoder.outputItems
      .where((item) => item['type'] == 'compaction')
      .toList();
  if (!decoder.completed || items.length != 1) {
    throw StateError('native_compaction_incomplete');
  }
  // Codex V2 returns a compaction item, not the V1 replacement array. Keep
  // real user items from the covered prefix within its 64K retention budget.
  // The user-selected recent tail never enters this request or this budget.
  final retained = <Map<String, dynamic>>[];
  var tokens = 0;
  for (final item
      in (prepared['input'] as List).whereType<Map>().toList().reversed) {
    final source = item[historySourceKey];
    if (item['role'] != 'user' ||
        (source is String && source.startsWith('reference:'))) {
      continue;
    }
    final count = estimateRequestInput({
      'input': [item],
    }, ProviderKind.openai);
    if (tokens + count > 64000) break;
    tokens += count;
    retained.insert(0, Map<String, dynamic>.from(item));
  }
  final retainedWire =
      RequestHistoryContext.stripSources({'input': retained})['input'] as List;
  return NativeCompactionPayload(
    protocol: NativeCompactionProtocol.codex,
    scope: nativeCompactionScope(config),
    modelId: modelId,
    output: [...retainedWire.cast<Map<String, dynamic>>(), items.single],
    usage: decoder.usage,
  );
}
