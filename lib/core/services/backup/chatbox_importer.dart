import 'dart:convert';
import 'dart:io';

import '../../models/backup.dart';
import '../../models/chat_message.dart';
import '../../models/conversation.dart';
import '../chat/chat_service.dart';

class ChatboxImportResult {
  final int conversations;
  final int messages;
  const ChatboxImportResult({
    required this.conversations,
    required this.messages,
  });
}

class ChatboxImporter {
  ChatboxImporter._();

  static Future<ChatboxImportResult> importFromChatbox({
    required File file,
    required RestoreMode mode,
    required ChatService chatService,
  }) async {
    final root = await _readChatboxBackupJson(file);

    if (!chatService.initialized) {
      await chatService.init();
    }
    if (mode == RestoreMode.overwrite) {
      await chatService.clearAllData();
    }

    // Existing conversations
    final existingConvs = chatService.getAllConversations();
    final existingConvIds = existingConvs.map((c) => c.id).toSet();

    // Build per-conversation message id sets for merge, and global taken ids to avoid Hive key collision.
    final existingMsgIdsByConv = <String, Set<String>>{};
    final takenMsgIds = <String>{};
    if (mode == RestoreMode.merge) {
      for (final c in existingConvs) {
        final msgs = chatService.getMessages(c.id);
        final set = <String>{};
        for (final m in msgs) {
          set.add(m.id);
          takenMsgIds.add(m.id);
        }
        existingMsgIdsByConv[c.id] = set;
      }
    }

    final sessions = _extractSessions(root);
    int convCount = 0;
    int msgCount = 0;

    for (final s in sessions) {
      final sid = (s['id'] ?? '').toString();
      if (sid.isEmpty) continue;
      final name = (s['name'] ?? 'Imported').toString();
      final starred = s['starred'] as bool? ?? false;

      final mergingIntoExisting = mode == RestoreMode.merge && existingConvIds.contains(sid);
      final existingInThisConv = mergingIntoExisting ? (existingMsgIdsByConv[sid] ?? const <String>{}) : const <String>{};

      final rawMessages = (s['messages'] as List?) ?? const <dynamic>[];
      final messages = <ChatMessage>[];

      int localIndex = 0;
      for (final m in rawMessages) {
        if (m is! Map) continue;
        final mm = m.map((k, v) => MapEntry(k.toString(), v));
        final rawId = (mm['id'] ?? '').toString();
        if (rawId.isEmpty) continue;
        // Only skip duplicates within the conversation being merged into.
        if (mergingIntoExisting && existingInThisConv.contains(rawId)) {
          takenMsgIds.add(rawId);
          continue;
        }
        final mid = _uniqueMessageId(rawId, sid: sid, index: localIndex, taken: takenMsgIds);
        takenMsgIds.add(mid);

        final role = _mapRole((mm['role'] ?? 'user').toString());
        final content = _extractContent(mm);
        final ts = _extractTimestamp(mm['timestamp']);

        messages.add(ChatMessage(
          id: mid,
          role: role,
          content: content,
          timestamp: ts,
          conversationId: sid,
          modelId: _extractModelId(mm),
          providerId: _extractProviderId(mm),
          totalTokens: _extractTotalTokens(mm),
        ));
        localIndex += 1;
      }

      DateTime createdAt = DateTime.now();
      DateTime updatedAt = createdAt;
      if (messages.isNotEmpty) {
        final times = messages.map((m) => m.timestamp).toList()..sort();
        createdAt = times.first;
        updatedAt = times.last;
      }

      if (messages.isEmpty) {
        continue;
      }

      if (mode == RestoreMode.merge && existingConvIds.contains(sid)) {
        for (final m in messages) {
          await chatService.addMessageDirectly(sid, m);
          msgCount += 1;
        }
      } else {
        final conv = Conversation(
          id: sid,
          title: name,
          createdAt: createdAt,
          updatedAt: updatedAt,
          isPinned: starred,
        );
        await chatService.restoreConversation(conv, messages);
        convCount += 1;
        msgCount += messages.length;
      }
    }

    return ChatboxImportResult(conversations: convCount, messages: msgCount);
  }

  static Future<Map<String, dynamic>> _readChatboxBackupJson(File file) async {
    final text = await file.readAsString();
    final obj = jsonDecode(text);
    if (obj is Map) {
      return obj.map((k, v) => MapEntry(k.toString(), v));
    }
    throw Exception('Invalid Chatbox backup JSON');
  }

  static List<Map<String, dynamic>> _extractSessions(Map<String, dynamic> root) {
    final out = <Map<String, dynamic>>[];

    void addSession(dynamic cand) {
      if (cand is! Map) return;
      final m = cand.map((k, v) => MapEntry(k.toString(), v));
      final id = (m['id'] ?? '').toString();
      if (id.isEmpty) return;
      // If no messages, try to resolve from session:{id}
      if (m['messages'] is! List) {
        final k = 'session:$id';
        final full = root[k];
        if (full is Map) {
          out.add(full.map((k, v) => MapEntry(k.toString(), v)));
          return;
        }
      }
      out.add(m);
    }

    final rawSessions = root['chat-sessions'];
    if (rawSessions is List) {
      for (final s in rawSessions) {
        addSession(s);
      }
    }

    final rawList = root['chat-sessions-list'];
    if (rawList is List) {
      for (final meta in rawList) {
        if (meta is! Map) continue;
        final mm = meta.map((k, v) => MapEntry(k.toString(), v));
        final id = (mm['id'] ?? '').toString();
        if (id.isEmpty) continue;
        final k = 'session:$id';
        final full = root[k];
        if (full is Map) {
          out.add(full.map((k, v) => MapEntry(k.toString(), v)));
        } else {
          // best-effort: keep meta (may include messages in older exports)
          out.add(mm);
        }
      }
    }

    if (out.isEmpty) {
      for (final e in root.entries) {
        if (!e.key.startsWith('session:')) continue;
        addSession(e.value);
      }
    }

    // Deduplicate by id
    final byId = <String, Map<String, dynamic>>{};
    for (final s in out) {
      final id = (s['id'] ?? '').toString();
      if (id.isEmpty) continue;
      byId[id] = s;
    }
    return byId.values.toList();
  }

  static String _mapRole(String role) {
    final r = role.toLowerCase();
    if (r == 'user') return 'user';
    return 'assistant';
  }

  static DateTime _extractTimestamp(dynamic ts) {
    try {
      if (ts is num) {
        final v = ts.toInt();
        if (v >= 1000000000000) {
          return DateTime.fromMillisecondsSinceEpoch(v);
        }
        if (v >= 1000000000) {
          return DateTime.fromMillisecondsSinceEpoch(v * 1000);
        }
      }
    } catch (_) {}
    return DateTime.now();
  }

  static String _uniqueMessageId(
    String rawId, {
    required String sid,
    required int index,
    required Set<String> taken,
  }) {
    if (!taken.contains(rawId)) return rawId;
    int n = 1;
    while (true) {
      final cand = '${rawId}__dup__${sid}__${index}__$n';
      if (!taken.contains(cand)) return cand;
      n += 1;
    }
  }

  static String _extractContent(Map<String, dynamic> msg) {
    final parts = msg['contentParts'];
    if (parts is List) {
      final sb = StringBuffer();
      for (final p in parts) {
        if (p is! Map) continue;
        final pm = p.map((k, v) => MapEntry(k.toString(), v));
        final type = (pm['type'] ?? '').toString();
        if (type == 'text') {
          final t = pm['text'];
          if (t != null) {
            if (sb.isNotEmpty) sb.write('\n');
            sb.write(t.toString());
          }
        } else if (type == 'info') {
          final t = pm['text'];
          if (t != null) {
            if (sb.isNotEmpty) sb.write('\n');
            sb.write(t.toString());
          }
        } else if (type == 'reasoning') {
          // ignore
        } else if (type == 'tool-call') {
          // ignore
        } else if (type == 'image') {
          // ignore
        }
      }
      final s = sb.toString().trimRight();
      if (s.isNotEmpty) return s;
    }

    final c = msg['content'];
    if (c is String) return c;
    if (c != null) return c.toString();
    return '';
  }

  static String? _extractModelId(Map<String, dynamic> msg) {
    final m = msg['model'];
    if (m is String && m.trim().isNotEmpty) return m.trim();
    return null;
  }

  static String? _extractProviderId(Map<String, dynamic> msg) {
    final ap = msg['aiProvider'];
    if (ap is String && ap.trim().isNotEmpty) return ap.trim();
    if (ap is Map) {
      final m = ap.map((k, v) => MapEntry(k.toString(), v));
      final id = (m['id'] ?? m['name'] ?? '').toString().trim();
      return id.isEmpty ? null : id;
    }
    return null;
  }

  static int? _extractTotalTokens(Map<String, dynamic> msg) {
    final tc = msg['tokenCount'];
    if (tc is num) return tc.toInt();
    final usage = msg['usage'];
    if (usage is Map) {
      final u = usage.map((k, v) => MapEntry(k.toString(), v));
      final total = u['totalTokens'] ?? u['total_tokens'];
      if (total is num) return total.toInt();
    }
    final tu = msg['tokensUsed'];
    if (tu is num) return tu.toInt();
    return null;
  }
}


