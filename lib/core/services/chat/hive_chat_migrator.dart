import 'package:hive_flutter/hive_flutter.dart';

import '../../models/chat_message.dart';
import '../../models/conversation.dart';
import 'chat_sqlite_store.dart';

class HiveChatMigrator {
  HiveChatMigrator({required this.store});

  static const String conversationsBoxName = 'conversations';
  static const String messagesBoxName = 'messages';
  static const String toolEventsBoxName = 'tool_events_v1';
  static const String activeStreamingKey = '_active_streaming_ids';
  static const String _signaturePrefix = 'sig_';

  final ChatSqliteStore store;

  Future<void> migrateIfNeeded(String appDataPath) async {
    if (store.hasCompletedHiveMigration) return;

    await Hive.initFlutter(appDataPath);
    _registerAdapters();

    if (!await _hasLegacyChatBoxes()) {
      store.markHiveMigrationComplete();
      return;
    }

    final conversationsBox = await Hive.openBox<Conversation>(
      conversationsBoxName,
    );
    final messagesBox = await Hive.openBox<ChatMessage>(messagesBoxName);
    final toolEventsBox = await Hive.openBox(toolEventsBoxName);

    try {
      store.transaction(() {
        final migratedMessageIds = <String>{};
        for (final conversation in conversationsBox.values) {
          final messages = <ChatMessage>[];
          for (final messageId in conversation.messageIds) {
            final message = messagesBox.get(messageId);
            if (message == null) continue;
            messages.add(
              message.isStreaming
                  ? message.copyWith(isStreaming: false)
                  : message,
            );
          }
          store.restoreConversation(conversation, messages);
          migratedMessageIds.addAll(messages.map((message) => message.id));
        }

        for (final key in toolEventsBox.keys) {
          final keyString = key.toString();
          if (keyString == activeStreamingKey) continue;

          final value = toolEventsBox.get(key);
          if (keyString.startsWith(_signaturePrefix)) {
            final messageId = keyString.substring(_signaturePrefix.length);
            if (!migratedMessageIds.contains(messageId)) continue;
            if (value is String && value.trim().isNotEmpty) {
              store.setGeminiThoughtSignature(messageId, value);
            }
            continue;
          }

          if (!migratedMessageIds.contains(keyString)) continue;
          if (value is List) {
            final events = value
                .whereType<Map>()
                .map((e) => e.map((k, v) => MapEntry(k.toString(), v)))
                .toList();
            if (events.isNotEmpty) {
              store.setToolEvents(keyString, events);
            }
          }
        }

        store.markHiveMigrationComplete();
      });
    } finally {
      await toolEventsBox.close();
      await messagesBox.close();
      await conversationsBox.close();
    }
  }

  Future<bool> _hasLegacyChatBoxes() async {
    return await Hive.boxExists(conversationsBoxName) ||
        await Hive.boxExists(messagesBoxName) ||
        await Hive.boxExists(toolEventsBoxName);
  }

  void _registerAdapters() {
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(ChatMessageAdapter());
    }
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(ConversationAdapter());
    }
  }
}
