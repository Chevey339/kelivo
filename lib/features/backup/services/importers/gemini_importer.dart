import 'dart:convert' show jsonDecode;

import '../../../core/models/unified_thread.dart';
import '../../../core/models/unified_message.dart';
import '../../../core/models/message_attachment.dart';

/// Imports threads from Google Gemini (Google Takeout) export JSON.
class GeminiImporter {
  /// Parse a Gemini export JSON string into a list of [UnifiedThread].
  List<UnifiedThread> importFromJson(String jsonString) {
    final dynamic decoded;
    try {
      decoded = jsonDecode(jsonString);
    } catch (e) {
      throw FormatException('Gemini JSON parse error: $e');
    }

    final List<dynamic> sessions;
    if (decoded is List) {
      sessions = decoded;
    } else if (decoded is Map) {
      sessions = (decoded['sessions'] ?? decoded['items'] ?? []) as List<dynamic>;
    } else {
      sessions = [];
    }

    final threads = <UnifiedThread>[];
    for (final raw in sessions) {
      if (raw is! Map) continue;
      try {
        final thread = _parseSession(raw as Map<String, dynamic>);
        if (thread != null) threads.add(thread);
      } catch (_) {
        continue;
      }
    }
    return threads;
  }

  UnifiedThread? _parseSession(Map<String, dynamic> json) {
    final title = json['title'] as String? ?? '';
    final cleanTitle = title.trim().isEmpty ? 'Gemini Chat' : title.trim();
    final createTime = _parseTimestamp(json['createTime']);
    final rawMessages = json['messages'] as List<dynamic>? ?? [];

    if (rawMessages.isEmpty) return null;

    final messages = <UnifiedMessage>[];
    for (final raw in rawMessages) {
      if (raw is! Map) continue;
      final msg = _parseMessage(raw as Map<String, dynamic>);
      if (msg != null) messages.add(msg);
    }

    if (messages.isEmpty) return null;

    final effectiveUpdateTime = messages.last.timestamp;
    final threadId =
        'gemini_${createTime.millisecondsSinceEpoch}_${messages.length}';

    return UnifiedThread(
      id: threadId,
      source: 'gemini',
      originalId: threadId,
      title: cleanTitle,
      createdAt: createTime,
      updatedAt: effectiveUpdateTime,
      messages: messages,
      metadata: <String, dynamic>{
        'original_source': 'gemini',
      },
    );
  }

  UnifiedMessage? _parseMessage(Map<String, dynamic> json) {
    final author = json['author'] as String? ?? 'user';
    final role = (author.toLowerCase() == 'user') ? 'user' : 'assistant';
    final rawContent = json['content'];
    final timestamp = _parseTimestamp(json['timestamp']);

    String textContent = '';
    final attachments = <MessageAttachment>[];

    if (rawContent is String) {
      textContent = rawContent;
    } else if (rawContent is List) {
      for (final part in rawContent) {
        if (part is Map) {
          final partMap = part as Map<String, dynamic>;
          if (partMap['text'] != null) {
            textContent += '${partMap['text']}\n';
          }
          final inlineData = partMap['inlineData'] as Map<String, dynamic>?;
          if (inlineData != null) {
            final mimeType = inlineData['mimeType'] as String? ?? 'image/png';
            final data = inlineData['data'] as String?;
            if (data != null) {
              attachments.add(MessageAttachment(
                type: 'image',
                content: data,
                mimeType: mimeType,
                name: 'inline_image',
              ));
            }
          }
        }
      }
    }

    textContent = textContent.trim();
    if (textContent.isEmpty && attachments.isEmpty) return null;

    return UnifiedMessage(
      role: role,
      content: textContent,
      timestamp: timestamp,
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
}
