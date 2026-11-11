import 'dart:convert';

import 'chat_message.dart';
import 'token_usage.dart';

const nativeCompactionArtifactKind = 'openai_native_compaction';
const nativeCompactionMessageKey = '_kelivo_native_compaction';
const nativeCompactionWireKey = '_kelivo_native_compaction_item';

enum NativeCompactionProtocol { compact, codex }

/// Remembers manual native choices; each chat owns its automatic policy.
class NativeCompressionPreferences {
  const NativeCompressionPreferences({
    this.enabled = false,
    this.allHistory = false,
    this.keepUserTurns = 6,
    this.newConversation = false,
  });
  final bool enabled;
  final bool allHistory;
  final int keepUserTurns;
  final bool newConversation;

  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'allHistory': allHistory,
    'keepUserTurns': keepUserTurns,
    'newConversation': newConversation,
  };

  factory NativeCompressionPreferences.fromJson(Map<String, dynamic> json) {
    final keep = json['keepUserTurns'] as int? ?? 6;
    if (keep < 0 || keep > 10000) {
      throw const FormatException('Invalid retained turn count');
    }
    return NativeCompressionPreferences(
      enabled: json['enabled'] == true,
      allHistory: json['allHistory'] == true,
      keepUserTurns: keep,
      newConversation: json['newConversation'] == true,
    );
  }
}

/// Opaque provider state. Never run text/attachment normalization on its items.
class NativeCompactionPayload {
  NativeCompactionPayload({
    required this.protocol,
    required this.scope,
    required this.modelId,
    required List<Map<String, dynamic>> output,
    this.usage,
  }) : output = (jsonDecode(jsonEncode(output)) as List)
           .map((item) => Map<String, dynamic>.unmodifiable(item as Map))
           .toList(growable: false) {
    if (!this.output.any(
      (item) =>
          item['type'] == 'compaction' &&
          item['encrypted_content'] is String &&
          (item['encrypted_content'] as String).isNotEmpty,
    )) {
      throw const FormatException('native_compaction_missing');
    }
  }

  final NativeCompactionProtocol protocol;
  final String scope;
  final String modelId;
  final List<Map<String, dynamic>> output;
  final TokenUsage? usage;

  Map<String, dynamic> toJson() => {
    'protocol': protocol.name,
    'scope': scope,
    'modelId': modelId,
    'output': output,
    if (usage != null) 'usage': usage!.toJson(),
  };

  factory NativeCompactionPayload.fromJson(Map<String, dynamic> json) =>
      NativeCompactionPayload(
        protocol: NativeCompactionProtocol.values.byName(
          json['protocol'] as String,
        ),
        scope: json['scope'] as String,
        modelId: json['modelId'] as String,
        output: (json['output'] as List)
            .map((item) => Map<String, dynamic>.from(item as Map))
            .toList(),
        usage: json['usage'] is Map
            ? TokenUsage.fromJson(
                Map<String, dynamic>.from(json['usage'] as Map),
              )
            : null,
      );

  static NativeCompactionPayload? forMessage(ChatMessage message) {
    final stored =
        message.providerArtifactSnapshot[nativeCompactionArtifactKind];
    return stored == null
        ? null
        : NativeCompactionPayload.fromJson(
            Map<String, dynamic>.from(jsonDecode(stored) as Map),
          );
  }
}
