import 'dart:convert';

import '../../utils/token_estimator.dart';
import '../memory/memory_block_builder.dart';
import 'log_payload_elider.dart';

/// Internal per-message key. Stripped before the request is sent.
const String kelivoContextSegmentsKey = '_kelivo_ctx_segments';

enum ContextSource {
  systemPrompt,
  memoryRules,
  searchPrompt,
  instructionInjection,
  worldBook,
  memorySnapshot,
  chatHistory,
  toolCall,
  toolResult,
  runtimeContext,
  workspace,
  skills,
}

extension ContextSourceWire on ContextSource {
  String get wireName => name;

  static ContextSource fromWire(Object? raw) {
    final name = (raw ?? '').toString();
    for (final value in ContextSource.values) {
      if (value.name == name) return value;
    }
    return ContextSource.chatHistory;
  }
}

class ContextSegment {
  const ContextSegment({
    required this.source,
    required this.text,
    required this.tokens,
    this.meta,
  });

  final ContextSource source;
  final String text;
  final int tokens;
  final Map<String, dynamic>? meta;

  Map<String, dynamic> toJson() => {
    'source': source.wireName,
    'text': text,
    'tokens': tokens,
    if (meta != null && meta!.isNotEmpty) 'meta': meta,
  };

  factory ContextSegment.fromJson(Map<String, dynamic> json) {
    final metaRaw = json['meta'];
    return ContextSegment(
      source: ContextSourceWire.fromWire(json['source']),
      text: (json['text'] ?? '').toString(),
      tokens: (json['tokens'] as num?)?.toInt() ?? 0,
      meta: metaRaw is Map ? Map<String, dynamic>.from(metaRaw) : null,
    );
  }
}

class ContextLogMessage {
  const ContextLogMessage({required this.role, required this.segments});

  final String role;
  final List<ContextSegment> segments;

  int get tokens => segments.fold(0, (sum, s) => sum + s.tokens);

  Map<String, dynamic> toJson() => {
    'role': role,
    'segments': [for (final s in segments) s.toJson()],
  };

  factory ContextLogMessage.fromJson(Map<String, dynamic> json) {
    final raw = json['segments'];
    return ContextLogMessage(
      role: (json['role'] ?? '').toString(),
      segments: splitMemorySnapshotUserText([
        if (raw is List)
          for (final item in raw)
            if (item is Map)
              ContextSegment.fromJson(Map<String, dynamic>.from(item)),
      ]),
    );
  }
}

class ContextLogSnapshot {
  const ContextLogSnapshot({
    required this.timestamp,
    required this.conversationId,
    required this.assistantName,
    required this.provider,
    required this.model,
    required this.messages,
    required this.totalTokens,
  });

  final DateTime timestamp;
  final String conversationId;
  final String assistantName;
  final String provider;
  final String model;
  final List<ContextLogMessage> messages;
  final int totalTokens;

  Map<String, dynamic> toJson() => {
    'timestamp': timestamp.toIso8601String(),
    'conversationId': conversationId,
    'assistantName': assistantName,
    'provider': provider,
    'model': model,
    'totalTokens': totalTokens,
    'messages': [for (final m in messages) m.toJson()],
  };

  factory ContextLogSnapshot.fromJson(Map<String, dynamic> json) {
    final raw = json['messages'];
    final messages = <ContextLogMessage>[
      if (raw is List)
        for (final item in raw)
          if (item is Map)
            ContextLogMessage.fromJson(Map<String, dynamic>.from(item)),
    ];
    final storedTotal = (json['totalTokens'] as num?)?.toInt();
    return ContextLogSnapshot(
      timestamp:
          DateTime.tryParse((json['timestamp'] ?? '').toString()) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      conversationId: (json['conversationId'] ?? '').toString(),
      assistantName: (json['assistantName'] ?? '').toString(),
      provider: (json['provider'] ?? '').toString(),
      model: (json['model'] ?? '').toString(),
      messages: messages,
      totalTokens: storedTotal ?? messages.fold(0, (sum, m) => sum + m.tokens),
    );
  }
}

/// Length-only tags stored on api message maps during assembly.
class ContextSegmentTags {
  static Map<String, dynamic> item({
    required ContextSource source,
    required int length,
    Map<String, dynamic>? meta,
  }) {
    return {
      'source': source.wireName,
      'length': length,
      if (meta != null && meta.isNotEmpty) 'meta': meta,
    };
  }

  static List<Map<String, dynamic>> read(Map<String, dynamic> message) {
    final raw = message[kelivoContextSegmentsKey];
    if (raw is! List) return const <Map<String, dynamic>>[];
    return [
      for (final e in raw)
        if (e is Map) Map<String, dynamic>.from(e),
    ];
  }

  static void write(
    Map<String, dynamic> message,
    List<Map<String, dynamic>> tags,
  ) {
    if (tags.isEmpty) {
      message.remove(kelivoContextSegmentsKey);
      return;
    }
    message[kelivoContextSegmentsKey] = tags;
  }

  static void replaceWithSingle(
    Map<String, dynamic> message, {
    required ContextSource source,
    required int length,
    Map<String, dynamic>? meta,
  }) {
    write(message, [item(source: source, length: length, meta: meta)]);
  }

  static void append(
    Map<String, dynamic> message, {
    required ContextSource source,
    required int length,
    Map<String, dynamic>? meta,
  }) {
    final tags = List<Map<String, dynamic>>.from(read(message));
    tags.add(item(source: source, length: length, meta: meta));
    write(message, tags);
  }

  static void prepend(
    Map<String, dynamic> message, {
    required ContextSource source,
    required int length,
    Map<String, dynamic>? meta,
  }) {
    final tags = List<Map<String, dynamic>>.from(read(message));
    tags.insert(0, item(source: source, length: length, meta: meta));
    write(message, tags);
  }
}

String extractApiMessageText(dynamic content) {
  if (content == null) return '';
  if (content is String) return content;
  if (content is List) {
    final buf = StringBuffer();
    for (final part in content) {
      if (part is Map) {
        final text = part['text'] ?? part['content'];
        if (text != null) buf.write(text);
      } else if (part != null) {
        buf.write(part);
      }
    }
    return buf.toString();
  }
  return content.toString();
}

/// Elide binary data URIs and large typed base64 JSON values in inspection only.
String elideContextPayload(String text) => LogPayloadElider.elide(text);

ContextSource inferContextSource(Map<String, dynamic> message) {
  final role = (message['role'] ?? '').toString();
  if (role == 'system') return ContextSource.systemPrompt;
  if (role == 'tool') return ContextSource.toolResult;
  if (role == 'assistant' && message['tool_calls'] != null) {
    return ContextSource.toolCall;
  }
  return ContextSource.chatHistory;
}

/// Rebuild display segments from the tagged api message (post-trim, pre-strip).
List<ContextSegment> segmentsFromTaggedMessage(Map<String, dynamic> message) {
  var content = extractApiMessageText(message['content']);
  final toolCalls = message['tool_calls'];
  if (toolCalls != null) {
    String encoded;
    try {
      encoded = jsonEncode(toolCalls);
    } catch (_) {
      encoded = toolCalls.toString();
    }
    content = content.isEmpty ? encoded : '$content\n$encoded';
  }

  final tags = ContextSegmentTags.read(message);
  if (tags.isEmpty) {
    final text = elideContextPayload(content);
    return [
      ContextSegment(
        source: inferContextSource(message),
        text: text,
        tokens: estimateTokens(text),
      ),
    ];
  }

  final out = <ContextSegment>[];
  var offset = 0;
  for (var i = 0; i < tags.length; i++) {
    final tag = tags[i];
    final source = ContextSourceWire.fromWire(tag['source']);
    final metaRaw = tag['meta'];
    final meta = metaRaw is Map ? Map<String, dynamic>.from(metaRaw) : null;
    final String slice;
    if (i == tags.length - 1) {
      slice = offset <= content.length ? content.substring(offset) : '';
    } else {
      final length = (tag['length'] as num?)?.toInt() ?? 0;
      final end = (offset + length).clamp(0, content.length);
      slice = content.substring(offset, end);
      offset = end;
    }
    final text = elideContextPayload(slice);
    out.add(
      ContextSegment(
        source: source,
        text: text,
        tokens: estimateTokens(text),
        meta: meta,
      ),
    );
  }
  return splitMemorySnapshotUserText(out);
}

/// If a memory-snapshot segment still contains the user turn, split it.
List<ContextSegment> splitMemorySnapshotUserText(
  List<ContextSegment> segments,
) {
  final out = <ContextSegment>[];
  for (final segment in segments) {
    if (segment.source != ContextSource.memorySnapshot) {
      out.add(segment);
      continue;
    }
    final split = MemoryBlockBuilder.splitInjectedPrefix(segment.text);
    if (split == null || split.rest.isEmpty) {
      out.add(segment);
      continue;
    }
    out.add(
      ContextSegment(
        source: ContextSource.memorySnapshot,
        text: split.prefix,
        tokens: estimateTokens(split.prefix),
        meta: {...?segment.meta, 'kind': split.kind},
      ),
    );
    out.add(
      ContextSegment(
        source: ContextSource.chatHistory,
        text: split.rest,
        tokens: estimateTokens(split.rest),
      ),
    );
  }
  return out;
}
