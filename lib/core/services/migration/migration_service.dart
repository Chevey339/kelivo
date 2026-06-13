import 'dart:convert';
import 'dart:io';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;
import '../../database/kelivo_database.dart';
import '../../database/mappers/chat_message_mapper.dart';
import '../../database/mappers/conversation_mapper.dart';
import '../../models/chat_message.dart';
import '../../models/conversation.dart';
import '../../../utils/app_directories.dart';

enum MigrationStep { readingHive, writingSqlite, verifying, completed, error }

class MigrationProgress {
  final MigrationStep step;
  final double progress; // 0.0 - 1.0
  final String message;
  final int? currentConversation;
  final int? totalConversations;
  final String? error;

  const MigrationProgress({
    required this.step,
    required this.progress,
    required this.message,
    this.currentConversation,
    this.totalConversations,
    this.error,
  });
}

class MigrationResult {
  final bool success;
  final int conversationsMigrated;
  final int messagesMigrated;
  final int toolEventsMigrated;
  final String? error;

  const MigrationResult({
    required this.success,
    this.conversationsMigrated = 0,
    this.messagesMigrated = 0,
    this.toolEventsMigrated = 0,
    this.error,
  });
}

class MigrationService {
  static const String _conversationsBoxName = 'conversations';
  static const String _messagesBoxName = 'messages';
  static const String _toolEventsBoxName = 'tool_events_v1';

  static Future<bool> isMigrationRequired() async {
    final dir = await AppDirectories.getAppDataDirectory();
    final dbFile = File(p.join(dir.path, 'kelivo.sqlite'));

    if (await dbFile.exists()) {
      final db = KelivoDatabase();
      try {
        final completed = await db.migrationCompleted();
        return !completed;
      } finally {
        await db.close();
      }
    }

    final hiveFile = File(p.join(dir.path, '$_messagesBoxName.hive'));
    return await hiveFile.exists();
  }

  static Future<MigrationResult> run({
    required void Function(MigrationProgress) onProgress,
  }) async {
    try {
      // Step 1: Read Hive data
      onProgress(
        const MigrationProgress(
          step: MigrationStep.readingHive,
          progress: 0.0,
          message: '正在读取 Hive 数据…',
        ),
      );

      final hiveData = await _readHiveData(onProgress);

      if (hiveData == null) {
        // No Hive boxes found — create empty SQLite and mark done
        final db = KelivoDatabase();
        try {
          await db.markMigrationCompleted();
        } finally {
          await db.close();
        }
        return const MigrationResult(success: true);
      }

      final conversations = hiveData.$1;
      final messages = hiveData.$2;
      final toolEvents = hiveData.$3;

      // Step 2: Write to SQLite
      onProgress(
        MigrationProgress(
          step: MigrationStep.writingSqlite,
          progress: 0.0,
          message: '正在写入 SQLite…',
          totalConversations: conversations.length,
        ),
      );

      final db = KelivoDatabase();
      try {
        await db.runMigration(conversations, messages, toolEvents, onProgress);
      } finally {
        await db.close();
      }

      // Step 3: Verify
      onProgress(
        const MigrationProgress(
          step: MigrationStep.verifying,
          progress: 0.0,
          message: '正在一致性校验…',
        ),
      );

      final verifyDb = KelivoDatabase();
      try {
        final verified = await _verify(verifyDb, conversations, messages);
        if (!verified) {
          return const MigrationResult(success: false, error: '一致性校验失败，请重试');
        }
        await verifyDb.markMigrationCompleted();
      } finally {
        await verifyDb.close();
      }

      return MigrationResult(
        success: true,
        conversationsMigrated: conversations.length,
        messagesMigrated: messages.length,
        toolEventsMigrated: toolEvents.length,
      );
    } catch (e, s) {
      return MigrationResult(success: false, error: '迁移失败: $e\n$s');
    }
  }

  static Future<
    (List<Conversation>, List<ChatMessage>, Map<String, Map<String, dynamic>>)?
  >
  _readHiveData(void Function(MigrationProgress) onProgress) async {
    final appDataDir = await AppDirectories.getAppDataDirectory();
    final messagesHive = File(
      p.join(appDataDir.path, '$_messagesBoxName.hive'),
    );
    if (!await messagesHive.exists()) return null;

    await Hive.initFlutter(appDataDir.path);

    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(ChatMessageAdapter());
    }
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(ConversationAdapter());
    }

    final conversationsBox = await Hive.openBox<Conversation>(
      _conversationsBoxName,
    );
    final messagesBox = await Hive.openBox<ChatMessage>(_messagesBoxName);
    final toolEventsBox = await Hive.openBox(_toolEventsBoxName);

    try {
      final allConversations = conversationsBox.values.toList();
      final allMessages = messagesBox.values.toList();
      final toolEventData = <String, Map<String, dynamic>>{};

      for (final key in toolEventsBox.keys) {
        final k = key.toString();
        final v = toolEventsBox.get(key);
        if (v != null) {
          toolEventData[k] = {'data': v};
        }
        final sigKey = 'sig_$k';
        final sig = toolEventsBox.get(sigKey);
        if (sig != null && sig is String) {
          toolEventData.putIfAbsent(k, () => {});
          toolEventData[k]!['gemini_thought_sig'] = sig;
        }
      }

      return (allConversations, allMessages, toolEventData);
    } finally {
      await conversationsBox.close();
      await messagesBox.close();
      await toolEventsBox.close();
    }
  }

  static Future<bool> _verify(
    KelivoDatabase db,
    List<Conversation> conversations,
    List<ChatMessage> messages,
  ) async {
    final dbConversationCount = await db
        .customSelect('SELECT COUNT(*) AS c FROM conversations')
        .getSingle()
        .then((r) => r.read<int>('c'));
    if (dbConversationCount != conversations.length) return false;

    final dbMessageCount = await db
        .customSelect('SELECT COUNT(*) AS c FROM messages')
        .getSingle()
        .then((r) => r.read<int>('c'));
    if (dbMessageCount != messages.length) return false;

    return true;
  }
}

extension _MigrationDatabase on KelivoDatabase {
  Future<void> runMigration(
    List<Conversation> convList,
    List<ChatMessage> msgList,
    Map<String, Map<String, dynamic>> toolEvents,
    void Function(MigrationProgress) onProgress,
  ) async {
    final total = convList.length;

    for (var i = 0; i < total; i++) {
      final conv = convList[i];

      await into(
        conversations,
      ).insert(conversationToCompanion(conv), mode: InsertMode.replace);

      final convMessages = msgList
          .where((m) => m.conversationId == conv.id)
          .toList();
      for (final msg in convMessages) {
        await into(
          messages,
        ).insert(chatMessageToCompanion(msg), mode: InsertMode.replace);
      }

      final progress = (i + 1) / total;
      onProgress(
        MigrationProgress(
          step: MigrationStep.writingSqlite,
          progress: progress,
          message: '正在写入 SQLite…',
          currentConversation: i + 1,
          totalConversations: total,
        ),
      );
    }

    for (final entry in toolEvents.entries) {
      final data = entry.value['data'] != null
          ? jsonEncode(entry.value['data'] as List)
          : '[]';
      final sig = entry.value['gemini_thought_sig'] as String?;
      await into(this.toolEvents).insert(
        ToolEventsCompanion(
          messageId: Value(entry.key),
          data: Value(data),
          geminiThoughtSig: Value(sig),
        ),
        mode: InsertMode.replace,
      );
    }
  }
}
