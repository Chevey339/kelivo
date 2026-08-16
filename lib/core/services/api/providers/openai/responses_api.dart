import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../../../models/token_usage.dart';
import '../../../../providers/settings_provider.dart';
import '../../../../../utils/app_directories.dart';
import '../../../../../utils/sandbox_path_resolver.dart';
import '../../chat_api_helpers.dart';
import '../../generation/tool_loop_runner.dart';
import '../../stream/sse_decode_loop.dart';
import '../../stream/sse_framing.dart';
import '../../stream/stream_chunk.dart';
import '../../stream/stream_chunk_emit.dart';
import '../../stream/stream_chunk_ids.dart';
import 'openai_vendor_compat.dart';
import 'responses_decoder.dart';

List<Map<String, dynamic>> toResponsesToolsFormat(
  List<Map<String, dynamic>> tools,
) {
  return tools.map((tool) {
    // Keep non-function tools (e.g., web_search) unchanged
    if ((tool['type'] ?? '').toString() != 'function') {
      return Map<String, dynamic>.from(tool);
    }

    // If already flattened (no nested 'function'), return as-is
    if (tool['function'] is! Map) {
      return Map<String, dynamic>.from(tool);
    }

    final fn = Map<String, dynamic>.from(tool['function'] as Map);
    final out = <String, dynamic>{
      'type': 'function',
      if (fn['name'] != null) 'name': fn['name'],
      if (fn['description'] != null) 'description': fn['description'],
    };
    final params = fn['parameters'];
    if (params is Map<String, dynamic>) {
      // Ensure parameters stays as-is (schema)
      out['parameters'] = params;
    }
    // Preserve strict flag if present (either at tool-level or function-level)
    final strict = (tool['strict'] ?? fn['strict']);
    if (strict is bool) {
      out['strict'] = strict;
    }
    return out;
  }).toList();
}

List<Map<String, dynamic>> withResponsesFunctionCallItems(
  List<Map<String, dynamic>> outputItems,
  Iterable<EmitToolCall> calls,
) {
  final replayItems = <Map<String, dynamic>>[
    for (final item in outputItems) Map<String, dynamic>.from(item),
  ];
  final presentCallIds = replayItems
      .where((item) => item['type'] == 'function_call')
      .map((item) => (item['call_id'] ?? '').toString())
      .where((callId) => callId.isNotEmpty)
      .toSet();

  for (final call in calls) {
    if (call.id.isEmpty || presentCallIds.contains(call.id)) continue;
    var argumentsJson = '{}';
    try {
      argumentsJson = jsonEncode(call.arguments);
    } catch (_) {}
    replayItems.add({
      'type': 'function_call',
      'call_id': call.id,
      'name': call.name,
      'arguments': argumentsJson,
    });
    presentCallIds.add(call.id);
  }

  return replayItems;
}

Future<({String uri, String mimeType})?> saveResponsesImageGeneration(
  String imageData, {
  String? outputFormat,
}) async {
  final normalizedFormat = (outputFormat ?? '').trim().toLowerCase();
  var mime = switch (normalizedFormat) {
    'jpeg' || 'jpg' => 'image/jpeg',
    'webp' => 'image/webp',
    _ => 'image/png',
  };
  var imageBase64 = imageData.trim();
  if (imageBase64.startsWith('data:')) {
    final commaIndex = imageBase64.indexOf(',');
    if (commaIndex < 0) return null;
    mime = mimeFromDataUrl(imageBase64);
    imageBase64 = imageBase64.substring(commaIndex + 1);
  }
  final savedPath = await AppDirectories.saveBase64Image(mime, imageBase64);
  if (savedPath == null || savedPath.isEmpty) return null;
  return (uri: SandboxPathResolver.canonicalize(savedPath), mimeType: mime);
}

Future<String> saveResponsesImageGenerationMarkdown(
  String imageData, {
  String? outputFormat,
}) async {
  final saved = await saveResponsesImageGeneration(
    imageData,
    outputFormat: outputFormat,
  );
  if (saved == null) return '';
  return '\n![image](${saved.uri})\n';
}

bool isResponsesImageGenerationType(dynamic type) {
  return type == 'image_generation_call' ||
      type == 'openrouter:image_generation';
}

List<EmitToolCall> responsesCallsFromIndexMap(
  Map<int, Map<String, String>> byIndex,
) {
  final calls = <EmitToolCall>[];
  final sorted = byIndex.keys.toList()..sort();
  for (final idx in sorted) {
    final m = byIndex[idx]!;
    Map<String, dynamic> args;
    try {
      args = (jsonDecode(m['args'] ?? '{}') as Map).cast<String, dynamic>();
    } catch (_) {
      args = <String, dynamic>{};
    }
    calls.add(
      emitToolCall(
        id: effectiveToolCallId(m['call_id'], 'call', idx),
        name: (m['name'] ?? '').toString(),
        arguments: args,
      ),
    );
  }
  return calls;
}

String responsesReasoningText(dynamic rawOutput) {
  if (rawOutput is! List) return '';

  final buffer = StringBuffer();
  for (final item in rawOutput) {
    if (item is! Map || item['type'] != 'reasoning') continue;
    final content = item['content'];
    if (content is String) {
      buffer.write(content);
      continue;
    }
    if (content is! List) continue;
    for (final part in content) {
      if (part is String) {
        buffer.write(part);
      } else if (part is Map &&
          (part['type'] == 'reasoning_text' || part['type'] == 'text')) {
        buffer.write((part['text'] ?? part['content'] ?? '').toString());
      }
    }
  }
  return buffer.toString();
}

Stream<StreamChunk> runOpenAIResponsesToolFollowUps({
  required http.Client client,
  required ProviderConfig config,
  required String modelId,
  required String upstreamModelId,
  required Uri url,
  required OpenAIProviderInfo info,
  required List<Map<String, dynamic>> initialInput,
  required List<Map<String, dynamic>> firstOutputItems,
  required List<EmitToolCall> initialCalls,
  required List<Map<String, dynamic>> responsesToolsSpec,
  required String responsesInstructions,
  required List<dynamic>? responsesIncludeParam,
  required ToolCallHandler onToolCall,
  required Map<String, String>? extraHeaders,
  required Map<String, dynamic>? extraBody,
  required double? temperature,
  required double? topP,
  required int? maxTokens,
  required bool isReasoning,
  required String effort,
  required int? thinkingBudget,
  required TokenUsage? initialUsage,
  required int streamRound,
  required int approxPromptTokens,
  required int approxCompletionChars,
}) async* {
  var usage = initialUsage;
  var chars = approxCompletionChars;
  var round = streamRound;
  var currentInput = <Map<String, dynamic>>[...initialInput];
  var outputItemsForAppend = firstOutputItems;
  var lastCalls = const <EmitToolCall>[];
  String? lastToolSignature;
  var consecutiveDupeCount = 0;

  yield* runClientToolFollowUps(
    initialCalls: initialCalls,
    onToolCall: onToolCall,
    append: (executed) {
      currentInput = [
        ...currentInput,
        ...withResponsesFunctionCallItems(outputItemsForAppend, [
          for (final item in executed) item.call,
        ]),
        for (final item in executed)
          <String, dynamic>{
            'type': 'function_call_output',
            'call_id': item.call.id,
            'output': item.content,
          },
      ];
    },
    sendFollowUp: () async* {
      final body2 = <String, dynamic>{
        'model': upstreamModelId,
        'input': currentInput,
        'stream': true,
        if (responsesToolsSpec.isNotEmpty) 'tools': responsesToolsSpec,
        if (responsesToolsSpec.isNotEmpty) 'tool_choice': 'auto',
        if (responsesInstructions.isNotEmpty)
          'instructions': responsesInstructions,
        if (temperature != null) 'temperature': temperature,
        if (topP != null) 'top_p': topP,
        if (maxTokens != null) 'max_output_tokens': maxTokens,
        if (isReasoning && effort != 'off')
          'reasoning': {
            'summary': 'auto',
            if (effort != 'auto') 'effort': effort,
          },
        if (responsesIncludeParam != null) 'include': responsesIncludeParam,
      };
      applyCompatibleResponsesReasoning(
        body2,
        config: config,
        modelId: modelId,
        upstreamModelId: upstreamModelId,
        isReasoning: isReasoning,
        thinkingBudget: thinkingBudget,
      );
      final extraCfg = customBody(config, modelId, assistantBody: extraBody);
      if (extraCfg.isNotEmpty) body2.addAll(extraCfg);
      try {
        if (body2['tools'] is List) {
          final raw = (body2['tools'] as List).cast<dynamic>();
          body2['tools'] = toResponsesToolsFormat(
            raw.map((e) => (e as Map).cast<String, dynamic>()).toList(),
          );
        }
      } catch (_) {}
      sanitizeOpenAIGpt5SamplingParams(
        body2,
        upstreamModelId,
        fallbackEffort: effort,
        isOpenRouter: info.isOpenRouter,
      );

      final req2 = http.Request('POST', url);
      req2.headers.addAll(
        customHeaders(
          config,
          modelId,
          baseHeaders: <String, String>{
            'Authorization': 'Bearer ${apiKeyForRequest(config, modelId)}',
            'Content-Type': 'application/json',
            'Accept': 'text/event-stream',
          },
          assistantHeaders: extraHeaders,
        ),
      );
      req2.body = jsonEncode(body2);
      final http.StreamedResponse resp2;
      try {
        resp2 = await client.send(req2);
        if (resp2.statusCode < 200 || resp2.statusCode >= 300) {
          final errorBody = await resp2.stream.bytesToString();
          throw HttpException('HTTP ${resp2.statusCode}: $errorBody');
        }
      } on HttpException {
        rethrow;
      } catch (e) {
        throw HttpException('Follow-up request failed: $e');
      }
      final s2 = rethrowFollowUpStreamErrors(
        resp2.stream.transform(utf8.decoder),
      );
      final followUpDecoder = ResponsesStreamDecoder(
        initialUsage: usage,
        sourceId: 'round-${round++}',
      );
      yield* decodeSseEvents(parseSseEventStrings(s2), followUpDecoder);
      usage = followUpDecoder.usage ?? usage;
      chars += followUpDecoder.approxCompletionChars;
      outputItemsForAppend = followUpDecoder.outputItems;
      final respCalls2 = <int, Map<String, String>>{
        for (final call in followUpDecoder.takeFunctionCalls())
          call.index: <String, String>{
            'call_id': call.callId,
            'name': call.name,
            'args': call.args,
          },
      };
      lastCalls = responsesCallsFromIndexMap(respCalls2);
      if (lastCalls.isEmpty) return;
      final sorted2 = respCalls2.keys.toList()..sort();
      final currentSig = [
        for (final idx2 in sorted2)
          '${respCalls2[idx2]!['name'] ?? ''}:${respCalls2[idx2]!['args'] ?? ''}',
      ].join('|');
      if (currentSig == lastToolSignature) {
        consecutiveDupeCount += 1;
        if (consecutiveDupeCount >= 3) {
          lastCalls = const <EmitToolCall>[];
        }
      } else {
        lastToolSignature = currentSig;
        consecutiveDupeCount = 1;
      }
    },
    takeCallsAfterRound: () => lastCalls,
    finish: () {
      final approxTotal = approxPromptTokens + (chars / 4).round();
      return emitDone(
        ids: StreamChunkIds('finish'),
        usage: usage,
        totalTokens: usage?.totalTokens ?? approxTotal,
      );
    },
    usageOf: () => usage,
  );
}
