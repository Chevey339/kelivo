import '../../../core/models/unified_thread.dart';
import '../../../core/models/unified_message.dart';
import '../../../core/models/message_attachment.dart';

/// Imports threads from Claude (Anthropic) export JSON.
///
/// Claude export format is a JSON array of conversation objects.
/// Each conversation has:
/// - uuid: String
/// - name: String
/// - created_at: String (ISO 8601)
/// - updated_at: String (ISO 8601)
/// - chat_messages: [{ uuid, sender: 'human' | 'assistant', text: String, created_at: String }]
/// - Files/artifacts may be included as separate fields
class ClaudeImporter {
  /// Parse a Claude export JSON string into a list of [UnifiedThread].
  List<UnifiedThread> importFromJson(String jsonString) {
    final dynamic decoded;
    try {
      decoded = _parseJson(jsonString);
    } catch (e) {
      throw FormatException('Claude JSON parse error: $e');
    }

    final List<dynamic> conversations;
    if (decoded is List) {
      conversations = decoded;
    } else if (decoded is Map) {
      conversations = (decoded['conversations'] ??
              decoded['accounts'] ??
              []) as List<dynamic>;
      // Some exports nest conversations inside an accounts array
      if (conversations.isEmpty && decoded.containsKey('accounts')) {
        final accounts = decoded['accounts'] as List<dynamic>? ?? [];
        conversations = [];
        for (final account in accounts) {
          if (account is Map) {
            final convos = (account as Map<String, dynamic>)['conversations']
                as List<dynamic>?;
            if (convos != null) conversations.addAll(convos);
          }
        }
      }
    } else {
      conversations = [];
    }

    final result = <UnifiedThread>[];
    for (final raw in conversations) {
      if (raw is! Map) continue;
      try {
        final thread = _parseConversation(raw as Map<String, dynamic>);
        if (thread != null) result.add(thread);
      } catch (_) {
        continue;
      }
    }
    return result;
  }

  UnifiedThread? _parseConversation(Map<String, dynamic> json) {
    final uuid = json['uuid'] as String?;
    final name = (json['name'] as String? ?? '').trim();
    final title = name.isNotEmpty ? name : 'Claude Chat';
    final createdAt = _parseTimestamp(
      json['created_at'] ?? json['createdAt'],
    );
    final updatedAt = _parseTimestamp(
      json['updated_at'] ?? json['updatedAt'],
    );

    final rawMessages = json['chat_messages'] as List<dynamic>? ?? [];
    if (rawMessages.isEmpty) return null;

    final messages = <UnifiedMessage>[];
    for (final raw in rawMessages) {
      if (raw is! Map) continue;
      final msg = _parseMessage(raw as Map<String, dynamic>);
      if (msg != null) messages.add(msg);
    }

    if (messages.isEmpty) return null;

    final threadId = 'claude_${uuid ?? createdAt.millisecondsSinceEpoch}';

    return UnifiedThread(
      id: threadId,
      source: 'claude',
      originalId: uuid,
      title: title,
      createdAt: createdAt,
      updatedAt: updatedAt,
      messages: messages,
      metadata: <String, dynamic>{
        'original_source': 'claude',
      },
    );
  }

  UnifiedMessage? _parseMessage(Map<String, dynamic> json) {
    final sender = json['sender'] as String? ?? 'human';
    final role = sender.toLowerCase() == 'human' ? 'user' : 'assistant';
    final text = json['text'] as String? ?? '';
    final createdAt = _parseTimestamp(
      json['created_at'] ?? json['createdAt'],
    );

    if (text.trim().isEmpty) return null;

    // Check for artifacts / files attached to this message
    final attachments = <MessageAttachment>[];
    final files = json['files'] as List<dynamic>?;
    if (files != null) {
      for (final f in files) {
        if (f is Map) {
          final fMap = f as Map<String, dynamic>;
          final fileName = fMap['file_name'] as String? ?? 'attachment';
          final fileContent = fMap['content'] as String?;
          final mimeType = fMap['mime_type'] as String?;
          attachments.add(MessageAttachment(
            type: 'file',
            name: fileName,
            content: fileContent,
            mimeType: mimeType,
          ));
        }
      }
    }

    // Check for artifacts (Claude code / markdown artifacts)
    final artifacts = json['artifacts'] as List<dynamic>?;
    if (artifacts != null) {
      for (final a in artifacts) {
        if (a is Map) {
          final aMap = a as Map<String, dynamic>;
          attachments.add(MessageAttachment(
            type: 'code',
            name: aMap['title'] as String? ?? 'artifact',
            content: aMap['content'] as String?,
            mimeType: aMap['type'] as String? ?? 'text/markdown',
          ));
        }
      }
    }

    return UnifiedMessage(
      originalId: json['uuid'] as String?,
      role: role,
      content: text.trim(),
      timestamp: createdAt,
      attachments: attachments.isNotEmpty ? attachments : null,
    );
  }

  DateTime _parseTimestamp(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is String) {
      return DateTime.tryParse(value) ?? DateTime.now();
    }
    if (value is num) {
      if (value > 1e11) {
        return DateTime.fromMillisecondsSinceEpoch(value.toInt());
      }
      return DateTime.fromMillisecondsSinceEpoch((value * 1000).toInt());
    }
    return DateTime.now();
  }

  dynamic _parseJson(String jsonString) {
    import 'dart:convert' show jsonDecode;
    return jsonDecode(jsonString);
  }
}
